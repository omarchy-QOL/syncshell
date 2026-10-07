.pragma library

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
function options(rows, search, filters, sort, fresh) {
    var query = String(search || "").toLowerCase();
    return (rows || []).filter(row => {
        return matchesSearch([label(row), row.path, row.id, row.address].join(" "), query)
            && (filters === null || filters.includes(folderState(row, fresh)));
    }).slice().sort((a, b) => {
        var rank = row => sort === "name" || folderState(row, fresh) === sort ? 0 : 1;
        return rank(a) - rank(b) || label(a).toLowerCase().localeCompare(label(b).toLowerCase())
            || a.id.localeCompare(b.id);
    }).map(row => ({ value: row.id, label: label(row), detail: (row.path || row.address || "") + " · " + row.id }));
}
function selectedId(rows, id) {
    return byId(rows, id) ? id : rows.length ? rows[0].id : "";
}
function initialView() {
    return { tab: "folders", folderId: "", deviceId: "", search: "", filters: ["active", "errors", "paused", "ready", "unknown"],
        sort: "name", more: false, form: "", draft: {}, confirmation: null,
        formAnchor: 0, settingsDraft: null };
}
function toggle(ids, id) { return ids.includes(id) ? ids.filter(x => x !== id) : ids.concat([id]); }
function errorDetails(folder) {
    var s = folder && folder.status || {};
    return [s.error].concat((s.errors || []).map(e => e.path + ": " + e.error)).filter(Boolean).join("\n");
}
function remoteShare(folder, device, fresh) {
    var member = (folder.devices || []).find(d => d.id === device.id);
    return fresh && device.connected && !device.paused && member ? member.remoteState || "unknown" : "unknown";
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
function deviceStatus(device, fresh) {
    if (!device) return "";
    return !fresh ? "Status unknown" : device.paused ? "Paused" : device.connected ? "Connected" : "Disconnected";
}
