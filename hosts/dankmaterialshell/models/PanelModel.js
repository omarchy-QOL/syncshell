.pragma library

// Omarchy names folders by their directory; the configured label follows in the meta line.
function folderName(folder) {
    var path = String(folder.path || "");
    var trimmed = path.replace(/\/+$/, "");
    if (path.charAt(0) === "/" && trimmed === "")
        return "/";
    return trimmed.split("/").pop() || String(folder.label || folder.id || "Unnamed folder");
}

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
    return [option.label, option.value, option.description, option.keywords].some(function (text) {
        return matchesSearch(text, query);
    });
}

function folderGroup(folder, fresh) {
    if (!fresh)
        return "unknown";
    if (folder.paused)
        return "paused";
    var status = folder.status || {};
    if (status.error || status.pullErrors > 0 || (status.errors || []).length || status.state === "error")
        return "errors";
    if (status.state === "syncing" || String(status.state).indexOf("scan") === 0
            || status.needTotalItems > 0)
        return "active";
    return status.state === "idle" ? "ready" : "unknown";
}



function folderOptions(folders, fresh, groups, sort, presentation) {
    var rows = (folders || []).map(function (folder) {
        var status = folder.status || {};
        return {
            value: folder.id,
            label: folderName(folder),
            keywords: String(folder.label || ""),
            description: String(folder.path || ""),
            group: folderGroup(folder, fresh),
            status: presentation ? presentation(folder) : folderStatus(folder, fresh),
            help: stateHelp(presentation ? presentation(folder) : folderStatus(folder, fresh)) + "\n" + String(status.error || (status.errors || []).map(function (error) {
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

// The side form is its own surface beside the popout, top-aligned with the
// row that opened it as in Omarchy, and kept inside the usable screen area.
function sideWindowPlacement(screenWidth, screenHeight, popout, formWidth, formHeight, rowY, gap, clearance, usableTop) {
    var side = sidePlacement(screenWidth, popout.x, popout.width, formWidth, gap, clearance);
    var x = side === "left" ? popout.x - gap - formWidth
        : side === "right" ? popout.x + popout.width + gap
        : Math.max(clearance, popout.x + (popout.width - formWidth) / 2);
    var y = Math.max(usableTop, Math.min(screenHeight - clearance - formHeight, popout.y + rowY));
    return { side: side, x: x, y: y };
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
function folderMeta(folder, fresh, localDeviceId, rescanning) {
    if (!folder) return "";
    var s = folder.status || {};
    var suffix = folder.label && folder.label !== folderName(folder) ? " · " + folder.label : "";
    if (!fresh) return "Last reported: " + (s.globalFiles || 0) + " files · " + bytes(s.globalBytes) + suffix;
    if (s.error || s.pullErrors > 0 || (s.errors || []).length || s.state === "error")
        return (s.error || (s.errors || [])[0]?.error || "Folder needs attention") + suffix;
    if (folder.paused) return "Syncing paused" + suffix;
    if (rescanning || String(s.state).indexOf("scan") === 0) return "Scanning local changes" + suffix;
    if (s.needTotalItems > 0 || s.state === "syncing")
        return (s.needTotalItems || 0) + " item" + (s.needTotalItems === 1 ? "" : "s") + " remaining"
            + (s.needBytes > 0 ? " · " + bytes(s.needBytes) : "") + suffix;
    var localOnly = !(folder.devices || []).some(d => d.id && d.id !== localDeviceId);
    return (s.globalFiles || 0) + " files · " + (localOnly ? "local only" : bytes(s.globalBytes)) + suffix;
}
function folderActivity(folder, fresh, activity) {
    return folder && fresh && activity && activity.folderId === folder.id && activity.detail
        ? String(activity.action || "Syncing") + " " + activity.detail : "";
}

function remoteShare(folder, device, fresh) {
    var member = (folder.devices || []).find(d => d.id === device.id);
    return fresh && device.connected && !device.paused && member ? member.remoteState || "unknown" : "unknown";
}
function remoteShareDescription(state) {
    return ({ valid: "Remote share confirmed", paused: "Remote folder paused",
        notSharing: "Remote is not sharing back" })[state] || "Remote acceptance unconfirmed";
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
// Omarchy's confirmation wording; the DMS dialog only supplies the chrome.
function confirmText(action, target) {
    var text = confirmWording(action, target || {});
    return { title: text.title, message: text.message, confirm: text.confirm || "Yes",
        destructive: text.destructive !== false };
}

function confirmWording(action, t) {
    var name = t.name || t.label || t.deviceId || t.id || "";
    if (action === "folder.add-existing")
        return { title: "Create directory?", message: "Create " + t.path + " and add it to Syncthing?",
            confirm: "Create and add", destructive: false };
    if (action === "folder.forget")
        return { title: "Forget " + folderName(t) + " (" + t.id + ")?",
            message: "This removes only its Syncthing configuration. The directory and data files will not be deleted. "
                + (t.markerName === ".stfolder" ? "Syncthing will also attempt to remove its internal .stfolder marker. " : "")
                + "Rejoining the same remote folder requires this exact Folder ID." };
    if (action === "device.remove")
        return { title: "Remove " + name + " from this device?",
            message: "Folder sharing with it will be removed locally. Local folders and files remain. The other device is unchanged." };
    if (action === "device.dismiss-pending")
        return { title: "Dismiss pending request from " + name + "?", message: "It can reappear if the device connects again." };
    if (action.indexOf("lifecycle.") === 0)
        return { title: "Change Syncthing service?", message: "This changes the authorized systemd user service for this Syncthing instance.",
            confirm: "Yes", destructive: false };
    return { title: "Dismiss invitation?", message: "Dismiss this folder invitation from " + name + "? It can reappear if the device offers it again." };
}
