.pragma library

var overviewPopout = "syncshell-overview";

function clone(value) { return JSON.parse(JSON.stringify(value)); }
function byId(rows, id) { return (rows || []).find(row => row.id === id) || null; }
function label(row) { return String(row.label || row.name || row.path || row.id || ""); }
function bytes(value) {
    var n = Math.max(0, Number(value || 0)), units = ["B", "KiB", "MiB", "GiB", "TiB"], i = 0;
    while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
    return (i ? n.toFixed(1) : String(Math.round(n))) + " " + units[i];
}
function folderState(folder, fresh) {
    if (!fresh) return "unknown";
    if (folder.paused) return "paused";
    var s = folder.status || {};
    if (s.error || s.pullErrors || (s.errors || []).length || s.state === "error") return "errors";
    if (s.needTotalItems || s.state === "syncing" || String(s.state).indexOf("scan") === 0) return "active";
    return s.state === "idle" ? "ready" : "unknown";
}
function options(rows, search, filters, sort, fresh, presentation) {
    var query = String(search || "").toLowerCase();
    return (rows || []).filter(row => {
        return matchesSearch([label(row), row.path, row.id, row.address].join(" "), query)
            && (filters === null || filters.includes(folderState(row, fresh)));
    }).slice().sort((a, b) => {
        var rank = row => sort === "name" || folderState(row, fresh) === sort ? 0 : 1;
        return rank(a) - rank(b) || label(a).toLowerCase().localeCompare(label(b).toLowerCase())
            || a.id.localeCompare(b.id);
    }).map(row => {
        var state = filters === null ? deviceStatus(row, fresh) : presentation ? presentation(row) : folderStatus(row, fresh);
        return { value: row.id, label: label(row), detail: (row.path || row.address || "") + " · " + row.id,
            status: state, help: filters === null ? state : stateHelp(state), group: filters === null ? "" : folderState(row, fresh) };
    });
}
function selectedId(rows, id) {
    return byId(rows, id) ? id : rows.length ? rows[0].id : "";
}
function initialView() {
    return { tab: "folders", anchorCenter: 0, folderId: "", deviceId: "", search: "", filters: ["active", "errors", "paused", "ready", "unknown"],
        sort: "name", more: false, form: "", draft: {}, confirmation: null,
        formAnchor: 0, settingsDraft: null };
}
function syncInProgress(a) {
    return !!a && a.online && (a.syncingFolderCount > 0 || !!(a.currentActivity && a.currentActivity.detail)
        || (a.busy && String(a._actionName).indexOf("folder.rescan") === 0));
}
// Same precedence as Omarchy's iconVariant.
function statusVariant(a) {
    if (!a || String(a.phase).indexOf("core-") === 0) return "notify";
    if (a.canControlService && a.lifecycle && a.lifecycle.active === false) return "pause";
    if (!a.online) return a.phase === "discovering" || a.phase === "loading" ? "sync" : "notify";
    if (a.folderProblemCount > 0) return "notify";
    if (a.refreshing || syncInProgress(a)) return "sync";
    return "default";
}
function statusIconUrl(bundleRoot, variant, themed) {
    return bundleRoot ? fileUrl(bundleRoot + "/assets/" + (themed ? "mono/" : "") + "status-" + variant + ".svg") : "";
}
function barTooltip(a) {
    if (!a) return "Syncthing unavailable";
    if (a.installation && a.installation.available === false) return "Syncthing: Syncthing is not installed";
    if (a.canControlService && a.lifecycle && a.lifecycle.active === false) return "Syncthing: Syncing stopped";
    if (syncInProgress(a)) return "Syncthing: Sync in progress...";
    return "Syncthing: " + a.summaryText;
}
function formatCount(value) {
    var count = Math.max(0, Number(value || 0));
    if (count >= 1000000) return (count / 1000000).toFixed(1) + "m";
    if (count >= 1000) return (count / 1000).toFixed(count >= 10000 ? 0 : 1) + "k";
    return String(Math.round(count));
}
function plural(count, noun) { return count + " " + noun + (count === 1 ? "" : "s"); }
function toggle(ids, id) { return ids.includes(id) ? ids.filter(x => x !== id) : ids.concat([id]); }


function remoteShare(folder, device, fresh) {
    var member = (folder.devices || []).find(d => d.id === device.id);
    return fresh && device.connected && !device.paused && member ? member.remoteState || "unknown" : "unknown";
}
function remoteShareDescription(state) {
    return ({ valid: "Remote share confirmed", paused: "Remote folder paused",
        notSharing: "Remote is not sharing back" })[state] || "Remote acceptance unconfirmed";
}

// The host anchors the union's center; offset the main pane inside that union.
function geometry(mainWidth, mainHeight, formWidth, formHeight, anchor, availableWidth, availableHeight, center, padding) {
    var maxHeight = Math.max(1, availableHeight - padding * 2);
    var mh = Math.min(mainHeight, maxHeight), fh = Math.min(formHeight, maxHeight);
    var mainTop = Math.max(0, Math.min(center - mh / 2, maxHeight - mh));
    var stacked = formWidth > 0 && mainWidth + formWidth + padding > availableWidth - padding * 2;
    var formTop = Math.max(0, Math.min(mainTop + anchor, maxHeight - fh));
    var top = formWidth > 0 && !stacked ? Math.min(mainTop, formTop) : mainTop;
    var height = formWidth > 0 && !stacked ? Math.max(mainTop + mh, formTop + fh) - top : mh;
    if (stacked) height = Math.min(maxHeight, mh + padding + fh);
    return { width: Math.min(availableWidth - padding * 2, mainWidth + (formWidth && !stacked ? formWidth + padding : 0)),
        height: height, mainY: mainTop - top, formY: stacked ? mh + padding : formTop - top,
        mainHeight: mh, formHeight: fh, stacked: stacked, center: top + height / 2 };
}
function fileUrl(path) { return "file://" + String(path).split("/").map(encodeURIComponent).join("/"); }

function matchesSearch(label, query) {
    var text = String(label || "").toLowerCase();
    var needle = String(query || "").trim().toLowerCase();
    var position = 0;
    for (var i = 0; i < needle.length; i++) {
        position = text.indexOf(needle[i], position);
        if (position < 0) return false;
        position++;
    }
    return true;
}
function matchesOption(option, query) {
    return matchesSearch([option.label, option.value, option.detail].join(" "), query);
}
function deviceStatus(device, fresh) {
    if (!device) return "";
    return !fresh ? "UNKNOWN" : device.paused ? "PAUSED" : device.connected ? "CONNECTED" : "DISCONNECTED";
}

// Omarchy's state meanings (docs/status-colors.md): success when settled,
// warning while moving or paused, error on failure, muted when unknown.
function folderStateRole(state) {
    if (state === "SYNCED" || state === "LINKED")
        return "success";
    if (state === "ERROR")
        return "error";
    if (["UNLINKED", "SCANNING", "SCAN+SYNC", "SYNCING"].indexOf(state) >= 0)
        return "warning";
    return "muted";
}

function deviceStateRole(state) {
    return state === "CONNECTED" ? "success" : state === "PAUSED" ? "warning" : "muted";
}

// Omarchy's activity colours: info while syncing, error removing, success upload.
function activityRole(action) {
    return action === "removing" ? "error" : action === "upload" ? "success" : "info";
}

// Caelestia has no warning or info role, so those keep fixed amber and blue.
var WARNING = "#ff9800";
var INFO = "#2196f3";
function statusColour(palette, role) {
    return role === "success" ? palette.m3success : role === "error" ? palette.m3error
        : role === "warning" ? WARNING : role === "info" ? INFO : palette.m3onSurfaceVariant;
}

function folderStatus(folder, fresh, recentlyLinkedId, activity, rescanning) {
    if (!folder || !fresh) return "UNKNOWN";
    if (folder.paused) return "UNLINKED";
    var s = folder.status || {};
    if (s.error || s.pullErrors > 0 || (s.errors || []).length || s.state === "error") return "ERROR";
    var syncing = s.needTotalItems > 0 || s.state === "syncing" || !!activity;
    if (rescanning || String(s.state).indexOf("scan") === 0)
        return syncing ? "SCAN+SYNC" : "SCANNING";
    if (folder.id === recentlyLinkedId) return "LINKED";
    if (syncing) return "SYNCING";
    return s.state === "idle" ? "SYNCED" : "UNKNOWN";
}
function stateHelp(state) {
    return state + " · " + ({ UNKNOWN: "Status unavailable", UNLINKED: "Syncing paused",
        ERROR: "Needs attention", SCANNING: "Rescanning local files",
        SYNCING: "Applying changes", "SCAN+SYNC": "Rescanning and syncing",
        LINKED: "Newly linked", SYNCED: "Up to date" }[state] || "Status unavailable");
}
// Like Omarchy, the configured label joins only transient states.
function folderMeta(folder, fresh, localDeviceId, rescanning) {
    if (!folder) return "";
    var s = folder.status || {};
    var pathName = String(folder.path || "").replace(/\/+$/, "").split("/").pop();
    var suffix = folder.label && folder.label !== pathName ? " · " + folder.label : "";
    if (!fresh) return "Last reported: " + formatCount(s.globalFiles) + " files · " + bytes(s.globalBytes) + suffix;
    if (s.error || s.pullErrors > 0 || (s.errors || []).length || s.state === "error")
        return (s.error || (s.errors || [])[0]?.error || "Folder needs attention") + suffix;
    if (folder.paused) return "Syncing paused" + suffix;
    if (rescanning || String(s.state).indexOf("scan") === 0) return "Scanning local changes" + suffix;
    if (s.needTotalItems > 0 || s.state === "syncing")
        return formatCount(s.needTotalItems) + " item" + (s.needTotalItems === 1 ? "" : "s") + " remaining"
            + (s.needBytes > 0 ? " · " + bytes(s.needBytes) : "") + suffix;
    var localOnly = !(folder.devices || []).some(d => d.id && d.id !== localDeviceId);
    return formatCount(s.globalFiles) + " files · " + (localOnly ? "local only" : bytes(s.globalBytes));
}
function folderActivity(folder, fresh, activity) {
    return folder && fresh && activity && activity.folderId === folder.id && activity.detail
        ? String(activity.action || "Syncing") + " " + activity.detail : "";
}

function totals(folders) {
    return (folders || []).reduce((sum, f) => ({
        files: sum.files + Number((f.status || {}).globalFiles || 0),
        bytes: sum.bytes + Number((f.status || {}).globalBytes || 0)
    }), { files: 0, bytes: 0 });
}

function hasErrors(folder) {
    var s = folder && folder.status || {};
    return !!(s.error || s.pullErrors > 0 || (s.errors || []).length || s.state === "error");
}
function errorDetails(folder) {
    if (!hasErrors(folder)) return "";
    var s = folder.status || {}, groups = Object.create(null);
    var errors = s.errors || [];
    errors.forEach(e => {
        var reason = e.error || "Unknown error";
        if (!groups[reason]) groups[reason] = [];
        if (e.path) groups[reason].push(e.path);
    });
    var details = Object.keys(groups).map(reason => reason + (groups[reason].length ? "\n" + groups[reason].join("\n") : ""));
    if (s.error) details.unshift(s.error);
    var count = Math.max(Number(s.pullErrors || 0), errors.length);
    var summary = count ? "Showing " + errors.length + " of " + count + " current error" + (count === 1 ? "" : "s") + "." : "";
    if (errors.length < count) summary += " Open Web UI for the full list.";
    return (details.join("\n\n") || "Syncthing reported no error details.") + (summary ? "\n\n" + summary : "");
}
