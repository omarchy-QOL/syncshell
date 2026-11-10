.pragma library

var DefaultIconStyle = "themed";
var DefaultWebUiTheme = "omarchy";
var DefaultServiceState = "enabled";
var DefaultProbeIntervalSeconds = 15;
var MinimumProbeIntervalSeconds = 1;
var MaximumProbeIntervalSeconds = 3600;
var SupportedVersion = 2;
var FolderSorts = ["name", "active-first", "errors-first"];
var FolderGroups = ["ready", "active", "errors", "paused", "unknown"];
var DefaultFolderSort = "name";
var DefaultFolderFilters = FolderGroups.slice();

function stripComment(line) {
    var quote = "";
    for (let i = 0; i < line.length; i++) {
        let character = line.charAt(i);
        if ((character === "\"" || character === "'") && !quote) {
            quote = character;
        } else if (character === quote) {
            quote = "";
        } else if (character === "#" && !quote) {
            return line.slice(0, i);
        }
    }
    return line;
}

function parseValue(raw) {
    var value = String(raw || "").trim();
    var match = value.match(/^(["'])([^"']*)\1$/);
    return match ? match[2] : null;
}

// A quoted value or a one-line list of them; "ready" and ["ready"] are the same.
function parseList(raw) {
    var value = String(raw || "").trim();
    var single = parseValue(value);
    if (single !== null)
        return [single];
    if (!/^\[(\s*(["'])[^"']*\2\s*,)*(\s*(["'])[^"']*\4\s*)?,?\s*\]$/.test(value))
        return null;
    var items = [];
    var item = /(["'])([^"']*)\1/g;
    var found;
    while ((found = item.exec(value)) !== null)
        items.push(found[2]);
    return items;
}

// "all" anywhere in the list, or every group named, shows every group.
function folderGroups(items) {
    if (items.indexOf("all") >= 0)
        return FolderGroups.slice();
    return FolderGroups.filter(group => items.indexOf(group) >= 0);
}

// The plugin always writes a list: ["all"], ["ready"], ["ready", "errors"] or [].
function formatFolderFilters(groups) {
    var shown = FolderGroups.filter(group => (groups || []).indexOf(group) >= 0);
    if (shown.length === FolderGroups.length)
        return '["all"]';
    return "[" + shown.map(group => '"' + group + '"').join(", ") + "]";
}

function parseInteger(raw) {
    var value = String(raw || "").trim();
    return /^(0|[1-9][0-9]*)$/.test(value) ? Number(value) : null;
}

function parse(raw, allowOlder) {
    var values = ({});
    var lines = String(raw || "").split("\n");
    var section = "";
    var version = null;
    function invalid(message) {
        return {
            error: message,
            version: version === null ? 0 : version
        };
    }
    var styleSectionSeen = false;
    var serviceSectionSeen = false;
    var viewSectionSeen = false;
    var rootStyleSetting = false;

    for (let i = 0; i < lines.length; i++) {
        let line = stripComment(lines[i]).trim();
        if (!line)
            continue;
        let header = line.match(/^\[([A-Za-z_][A-Za-z0-9_-]*)\]$/);
        if (header) {
            section = header[1];
            if (section !== "style" && section !== "service" && section !== "view") {
                return invalid("Unknown settings section " + section + " on line " + (i + 1));
            }
            if ((section === "style" && styleSectionSeen) || (section === "service" && serviceSectionSeen) || (section === "view" && viewSectionSeen)) {
                return invalid("Duplicate settings section " + section + " on line " + (i + 1));
            }
            if (section === "style")
                styleSectionSeen = true;
            else if (section === "service")
                serviceSectionSeen = true;
            else
                viewSectionSeen = true;
            continue;
        }
        let assignment = line.match(/^([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*(.+)$/);
        if (!assignment) {
            return invalid("Invalid settings syntax on line " + (i + 1));
        }
        let key = assignment[1];
        if (key === "version" && !section) {
            if (version !== null) {
                return invalid("Duplicate setting version on line " + (i + 1));
            }
            version = parseInteger(assignment[2]);
            if (version === null) {
                return invalid("version must be an integer");
            }
            continue;
        }
        let styleSetting = key === "icon_style" || key === "web_ui_theme";
        let serviceSetting = key === "service_state" || key === "probe_interval_seconds";
        let viewSetting = key === "folder_sort" || key === "folder_filters";
        if ((section === "service" && !serviceSetting) || (section === "view" && !viewSetting) || (section !== "service" && section !== "view" && !styleSetting)) {
            return invalid("Unknown setting " + (section ? section + "." : "") + key + " on line " + (i + 1));
        }
        if (!section && styleSetting)
            rootStyleSetting = true;
        if (values[key] !== undefined) {
            return invalid("Duplicate setting " + key + " on line " + (i + 1));
        }
        if (key === "probe_interval_seconds") {
            let interval = parseInteger(assignment[2]);
            if (interval === null || interval < MinimumProbeIntervalSeconds || interval > MaximumProbeIntervalSeconds) {
                return invalid("probe_interval_seconds must be an integer between " + MinimumProbeIntervalSeconds + " and " + MaximumProbeIntervalSeconds);
            }
            values[key] = interval;
        } else if (key === "folder_filters") {
            let items = parseList(assignment[2]);
            if (items === null)
                return invalid("folder_filters must be a quoted value or a list of them on one line");
            let unknown = items.filter(item => item !== "all" && FolderGroups.indexOf(item) < 0);
            if (unknown.length)
                return invalid("folder_filters accepts all, " + FolderGroups.join(", ") + "; not " + unknown.join(", "));
            values[key] = folderGroups(items);
        } else {
            let value = parseValue(assignment[2]);
            if (value === null) {
                return invalid(key + " must use a quoted value");
            }
            values[key] = value;
        }
    }

    var sourceVersion = version === null ? 0 : version;
    if (sourceVersion !== SupportedVersion && !(allowOlder && (sourceVersion === 0 || sourceVersion === 1))) {
        return invalid("Unsupported settings version " + sourceVersion + "; expected " + SupportedVersion);
    }
    if (version !== null || styleSectionSeen) {
        if (version === null)
            return invalid("Missing setting version");
        if (!styleSectionSeen)
            return invalid("Missing settings section style");
        if (rootStyleSetting) {
            return invalid("Style settings must be inside [style]");
        }
    }

    if (values.icon_style === undefined) {
        return invalid("Missing setting icon_style");
    }
    if (["branded", "themed"].indexOf(values.icon_style) < 0) {
        return invalid("icon_style must be branded or themed");
    }
    if (values.web_ui_theme === undefined) {
        return invalid("Missing setting web_ui_theme");
    }
    if (["default", "modern", "omarchy"].indexOf(values.web_ui_theme) < 0) {
        return invalid("web_ui_theme must be default, modern, or omarchy");
    }
    if (values.service_state === undefined) {
        values.service_state = sourceVersion < 2 ? "enabled" : DefaultServiceState;
    }
    if (["enabled", "disabled"].indexOf(values.service_state) < 0) {
        return invalid("service_state must be enabled or disabled");
    }
    if (values.probe_interval_seconds === undefined) {
        values.probe_interval_seconds = sourceVersion < 2 ? 15 : DefaultProbeIntervalSeconds;
    }
    // [view] is optional: files written before it keep working with the defaults.
    if (values.folder_sort === undefined)
        values.folder_sort = DefaultFolderSort;
    if (FolderSorts.indexOf(values.folder_sort) < 0) {
        return invalid("folder_sort must be " + FolderSorts.join(", ").replace(/, ([^,]*)$/, ", or $1"));
    }
    if (values.folder_filters === undefined)
        values.folder_filters = DefaultFolderFilters.slice();

    return {
        error: "",
        version: sourceVersion,
        iconStyle: values.icon_style,
        webUiTheme: values.web_ui_theme,
        serviceState: values.service_state,
        probeIntervalSeconds: values.probe_interval_seconds,
        folderSort: values.folder_sort,
        folderFilters: values.folder_filters
    };
}

function migrate(raw) {
    var previous = parse(raw, true);
    if (previous.error)
        return {
            error: previous.error
        };
    if (previous.version === SupportedVersion)
        return {
            error: "Settings are current"
        };

    var newline = raw.indexOf("\r\n") >= 0 ? "\r\n" : "\n";
    var output = previous.version === 0 ? ["version = " + SupportedVersion, ""] : [];
    var additions = [];
    var inService = false;
    var serviceSeen = false;
    var styleSeen = false;
    var stateSeen = false;
    var intervalSeen = false;
    function addServiceDefaults() {
        if (!stateSeen) {
            let state = 'service_state = "' + previous.serviceState + '"';
            output.push(state);
            additions.push(state);
        }
        if (!intervalSeen) {
            let interval = "probe_interval_seconds = " + previous.probeIntervalSeconds;
            output.push(interval);
            additions.push(interval);
        }
    }

    raw.split(/\r?\n/).forEach(function (line) {
        var code = stripComment(line).trim();
        if (code === "[style]" || code === "[service]" || code === "[view]") {
            if (inService)
                addServiceDefaults();
            inService = code === "[service]";
            serviceSeen = serviceSeen || inService;
            styleSeen = styleSeen || code === "[style]";
        } else if (/^version\s*=/.test(code)) {
            line = line.replace(/(version\s*=\s*)[0-9]+/, "$1" + SupportedVersion);
        } else if (previous.version === 0 && !styleSeen && /^(icon_style|web_ui_theme)\s*=/.test(code)) {
            output.push("[style]");
            styleSeen = true;
        }
        if (inService) {
            stateSeen = stateSeen || /^service_state\s*=/.test(code);
            intervalSeen = intervalSeen || /^probe_interval_seconds\s*=/.test(code);
        }
        output.push(line);
    });
    if (inService)
        addServiceDefaults();
    if (!serviceSeen) {
        output.push("", "[service]");
        addServiceDefaults();
    }
    var candidate = output.join(newline);
    if (!candidate.endsWith(newline))
        candidate += newline;
    var checked = parse(candidate);
    return checked.error ? {
        error: checked.error
    } : {
        error: "",
        text: candidate,
        additions: additions,
        values: checked
    };
}

function defaults() {
    return {
        iconStyle: DefaultIconStyle,
        webUiTheme: DefaultWebUiTheme,
        serviceState: DefaultServiceState,
        probeIntervalSeconds: DefaultProbeIntervalSeconds,
        folderSort: DefaultFolderSort,
        folderFilters: DefaultFolderFilters.slice()
    };
}
