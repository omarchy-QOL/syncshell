.pragma library

function matchesSearch(label, query) {
    var text = String(label || "").toLowerCase();
    var needle = String(query || "").trim().toLowerCase();
    var position = 0;
    for (var index = 0; index < needle.length; index++) {
        position = text.indexOf(needle[index], position);
        if (position < 0)
            return false;
        position++;
    }
    return true;
}

function matchesOption(option, query) {
    return [option.label, option.value, option.description].some(function (text) {
        return matchesSearch(text, query);
    });
}

function folderGroup(folder, fresh) {
    if (!fresh)
        return "unknown";
    if (folder.paused)
        return "paused";
    var status = folder.status || {};
    if (status.error || status.pullErrors > 0 || status.state === "error")
        return "errors";
    if (status.state === "syncing" || String(status.state).indexOf("scan") === 0
            || status.needTotalItems > 0)
        return "active";
    return status.state === "idle" ? "ready" : "unknown";
}

function folderStatus(folder, fresh) {
    var group = folderGroup(folder, fresh);
    if (group === "active")
        return String(folder.status.state).indexOf("scan") === 0 ? "SCANNING" : "SYNCING";
    return { ready: "SYNCED", errors: "ERROR", paused: "UNLINKED",
        unknown: "UNKNOWN" }[group];
}

function folderOptions(folders, fresh, groups, sort) {
    var rows = (folders || []).map(function (folder) {
        var status = folder.status || {};
        return {
            value: folder.id,
            label: String(folder.label || folder.id),
            description: String(folder.path || ""),
            group: folderGroup(folder, fresh),
            status: folderStatus(folder, fresh),
            help: String(status.error || (status.errors || []).map(function (error) {
                return error.path + ": " + error.error;
            }).join("\n"))
        };
    }).filter(function (row) {
        return !groups || groups.indexOf(row.group) >= 0;
    });
    rows.sort(function (left, right) {
        var priority = sort === "active" || sort === "errors" ? sort : "";
        if (priority && (left.group === priority) !== (right.group === priority))
            return left.group === priority ? -1 : 1;
        var a = left.label.toLowerCase();
        var b = right.label.toLowerCase();
        return a < b ? -1 : a > b ? 1
            : left.value < right.value ? -1 : left.value > right.value ? 1 : 0;
    });
    return rows;
}

function deviceStatus(device, fresh) {
    if (!device)
        return "";
    return !fresh ? "UNKNOWN"
        : device.paused ? "PAUSED" : device.connected ? "CONNECTED" : "OFFLINE";
}

function deviceOptions(devices, fresh) {
    return (devices || []).map(function (device) {
        return {
            value: device.id,
            label: String(device.name || device.id),
            description: String(device.address || device.id),
            status: deviceStatus(device, fresh)
        };
    });
}

function retainedSelection(rows, selectedId) {
    for (var index = 0; index < rows.length; index++) {
        if (rows[index].id === selectedId)
            return selectedId;
    }
    return rows.length ? rows[0].id : "";
}

function toggled(ids, id) {
    var result = ids.slice();
    var index = result.indexOf(id);
    if (index < 0)
        result.push(id);
    else
        result.splice(index, 1);
    return result;
}

function removedShares(originalIds, draftIds) {
    return originalIds.filter(function (id) { return draftIds.indexOf(id) < 0; });
}

function bytes(value) {
    var number = Math.max(0, Number(value || 0));
    var units = ["B", "KiB", "MiB", "GiB", "TiB"];
    var unit = 0;
    while (number >= 1024 && unit < units.length - 1) {
        number /= 1024;
        unit++;
    }
    return (unit === 0 ? String(Math.round(number)) : number.toFixed(number >= 10 ? 0 : 1))
        + " " + units[unit];
}

function totals(folders) {
    var result = { files: 0, bytes: 0 };
    for (var index = 0; index < folders.length; index++) {
        var status = folders[index].status || {};
        result.files += Number(status.globalFiles || 0);
        result.bytes += Number(status.globalBytes || 0);
    }
    return result;
}

function sidePlacement(screenWidth, mainX, mainWidth, sideWidth, gap, clearance) {
    var left = mainX - clearance >= sideWidth + gap;
    var right = screenWidth - clearance - mainX - mainWidth >= sideWidth + gap;
    if (left && (!right || mainX + mainWidth / 2 >= screenWidth / 2))
        return "left";
    return right ? "right" : "stack";
}

function paneLayout(mainHeight, formHeight, available, triggerY, sideOpen,
                    stacked, barPosition, mainTop, gap, footerHeight) {
    var main = Math.min(available, mainHeight);
    var form = sideOpen ? Math.min(available, formHeight) : 0;
    if (sideOpen && stacked) {
        form = Math.min(form, Math.max(0, available - footerHeight - gap), available * 0.6);
        main = Math.min(main, Math.max(0, available - form - gap));
        return { height: main + form + gap, mainY: 0, mainHeight: main,
            sideY: main + gap, sideHeight: form, top: 0 };
    }
    var top = barPosition === 0 ? 0 : barPosition === 1 ? available - main
        : Math.max(0, Math.min(available - main, mainTop));
    var formTop = Math.max(0, Math.min(available - form, top + triggerY));
    var first = sideOpen ? Math.min(top, formTop) : top;
    var last = sideOpen ? Math.max(top + main, formTop + form) : top + main;
    return { height: last - first, mainY: top - first, mainHeight: main,
        sideY: formTop - first, sideHeight: form, top: first };
}
