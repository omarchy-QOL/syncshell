.pragma library

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function byId(rows, id) {
    return (rows || []).find(function (row) { return row.id === id; }) || null;
}

function basename(path) {
    return String(path || "").replace(/\/+$/, "").split("/").pop() || "/";
}

function folderGroup(folder, fresh) {
    var status = folder.status || {};
    if (!fresh || !status.state || status.state === "unknown") return "unknown";
    if (folder.paused) return "paused";
    if (status.error || status.pullErrors > 0 || (status.errors || []).length
            || status.state === "error") return "errors";
    if (status.state.indexOf("scan") === 0 || status.state === "syncing"
            || status.needTotalItems > 0) return "active";
    return "ready";
}

function folderOptions(folders, fresh, groups, sort, query) {
    var rows = (folders || []).map(function (folder) {
        var label = basename(folder.path) || folder.label || folder.id;
        var duplicate = folders.some(function (other) {
            return other.id !== folder.id && basename(other.path) === label;
        });
        return {
            id: folder.id,
            label: label + (duplicate ? " (" + folder.path + ")" : ""),
            description: [folder.label, folder.path, folder.id].filter(Boolean).join(" · "),
            group: folderGroup(folder, fresh),
            status: folderDisplay(folder, fresh, false).label,
            role: folderDisplay(folder, fresh, false).role,
            help: folderDisplay(folder, fresh, false).help
        };
    });
    rows = rows.filter(function (row) {
        return (!groups || groups.indexOf(row.group) >= 0) && matches(row, query);
    });
    return rows.sort(function (a, b) {
        var priority = (a.group === sort ? 0 : 1) - (b.group === sort ? 0 : 1);
        if ((sort === "active" || sort === "errors") && priority) return priority;
        var left = a.label.toLowerCase(), right = b.label.toLowerCase();
        return left < right ? -1 : left > right ? 1 : a.id.localeCompare(b.id);
    });
}

function matches(row, query) {
    var haystack = [row.label, row.description, row.id].join(" ").toLowerCase();
    return String(query || "").toLowerCase().trim().split(/\s+/).every(function (word) {
        return haystack.indexOf(word) >= 0;
    });
}

function toggle(ids, id) {
    return ids.indexOf(id) < 0 ? ids.concat([id]) : ids.filter(function (value) { return value !== id; });
}

function allState(ids, available) {
    var count = available.filter(function (id) { return ids.indexOf(id) >= 0; }).length;
    return count === 0 ? "none" : count === available.length ? "all" : "mixed";
}

function toggleAll(ids, visible) {
    if (allState(ids, visible) === "all")
        return ids.filter(function (id) { return visible.indexOf(id) < 0; });
    return ids.concat(visible.filter(function (id) { return ids.indexOf(id) < 0; }));
}

function folderDraft(offer) {
    return {folderId: offer ? offer.folderId : "", path: "", label: offer ? offer.label : "",
        deviceIds: offer ? [offer.deviceId] : [], pendingDeviceId: offer ? offer.deviceId : ""};
}

function folderValidation(draft, folders) {
    if (!/^[-A-Za-z0-9._]{1,128}$/.test(draft.folderId)) return "Enter a valid folder ID";
    if (!String(draft.path || "").trim()) return "Choose or enter a directory";
    if (byId(folders, draft.folderId)) return "This folder ID is already configured";
    if (draft.pendingDeviceId && (draft.deviceIds || []).indexOf(draft.pendingDeviceId) < 0)
        return "Keep the offering device selected to accept its invitation";
    return "";
}

function bytes(value) {
    var size = Math.max(0, Number(value || 0)), unit = 0;
    var units = ["B", "KiB", "MiB", "GiB", "TiB"];
    while (size >= 1024 && unit < units.length - 1) { size /= 1024; unit++; }
    return (unit ? size.toFixed(size >= 10 ? 0 : 1) : String(Math.round(size))) + " " + units[unit];
}

// Each pane is bounded separately; opening a form never moves the main pane.
function geometry(screenWidth, screenHeight, anchor, mainSize, sideSize, edge, gap, padding) {
    var left = edge === "left" ? anchor.x + anchor.width + gap : padding;
    var right = edge === "right" ? anchor.x - gap : screenWidth - padding;
    var top = edge === "top" ? anchor.y + anchor.height + gap : padding;
    var bottom = edge === "bottom" ? anchor.y - gap : screenHeight - padding;
    left = Math.max(padding, Math.min(left, screenWidth - padding - 1));
    right = Math.max(left + 1, Math.min(right, screenWidth - padding));
    top = Math.max(padding, Math.min(top, screenHeight - padding - 1));
    bottom = Math.max(top + 1, Math.min(bottom, screenHeight - padding));
    var width = Math.min(mainSize.width, right - left);
    var height = Math.min(mainSize.height, bottom - top);
    var x = edge === "left" ? left : edge === "right" ? right - width : anchor.x + anchor.width - width;
    var y = edge === "bottom" ? bottom - height : edge === "top" ? top : anchor.y;
    x = Math.max(left, Math.min(x, right - width));
    y = Math.max(top, Math.min(y, bottom - height));
    var sideWidth = Math.min(sideSize.width, right - left);
    var sideHeight = Math.min(sideSize.height, bottom - top);
    var sideX = x + width + gap;
    var sideY = Math.max(top, Math.min(y + (sideSize.offset || 0), bottom - sideHeight));
    var stacked = false;
    if (sideX + sideWidth > right) {
        sideX = x - sideWidth - gap;
        if (sideX < left) {
            stacked = sideSize.visible !== false;
            sideX = Math.max(left, Math.min(x, right - sideWidth));
            if (stacked) {
                sideHeight = Math.min(sideHeight, Math.max(1, (bottom - top - gap) * 0.5));
                height = Math.min(height, Math.max(1, bottom - top - sideHeight - gap));
                y = edge === "bottom" ? bottom - height : top;
                sideY = edge === "bottom" ? y - gap - sideHeight : y + height + gap;
            }
        }
    }
    return {main: {x: x, y: y, width: width, height: height},
        side: {x: sideX, y: sideY, width: sideWidth, height: sideHeight}, stacked: stacked};
}

function deviceFolderOptions(folders, device, fresh, unconfirmed) {
    if (!device) return [];
    return folders.filter(folder => (folder.devices || []).some(member => member.id === device.id))
        .map(function (folder) {
            var member = folder.devices.find(member => member.id === device.id);
            var state = fresh && device.connected && !device.paused ? member.remoteState : "unknown";
            var confirmed = state === "valid" || state === "paused";
            return {id: folder.id, label: folder.label || basename(folder.path) || folder.id,
                confirmed: confirmed, description: folder.id + " · " + (state === "notSharing"
                    ? "Remote is not sharing back" : !confirmed ? "Remote acceptance unconfirmed"
                    : state === "paused" ? "Remote folder paused" : "Shared")};
        }).filter(row => row.confirmed !== unconfirmed);
}

function folderDisplay(folder, fresh, rescanning) {
    var status = folder.status || {};
    var errors = !!status.error || Number(status.pullErrors || 0) > 0
        || (status.errors || []).length > 0 || status.state === "error";
    var scanning = rescanning || String(status.state || "").indexOf("scan") === 0;
    var syncing = status.state === "syncing" || Number(status.needTotalItems || 0) > 0;
    var unknown = !fresh || !status.state || status.state === "unknown";
    var label = unknown ? "Unknown"
        : folder.paused ? "Paused" : errors ? "Errors"
        : scanning && syncing ? "Scanning and syncing" : scanning ? "Scanning"
        : syncing ? "Syncing" : "Up to date";
    return {label: label, hasErrors: errors, scanning: scanning, syncing: syncing,
        role: unknown ? "muted" : folder.paused ? "warning" : errors ? "danger"
            : scanning ? "warning" : syncing ? "accent" : "success",
        help: unknown ? (!fresh ? "Current status unavailable; values are last reported" : "Folder status not yet available")
            : folder.paused ? "Synchronization is paused; files are kept"
            : errors ? "Open diagnostics for affected paths and error reasons"
            : scanning ? "Reading local changes; completion waits for the scan to settle"
            : syncing ? "Changes remain to be synchronized" : "No pending changes reported"};
}

function diagnostics(folders, fresh) {
    return (folders || []).filter(folder => folderDisplay(folder, fresh, false).hasErrors)
        .map(function (folder) {
            var status = folder.status || {}, errors = status.errors || [];
            return {id: folder.id, label: folder.label || basename(folder.path) || folder.id,
                path: folder.path || "", reason: String(status.error || ""),
                errors: errors, shown: errors.length,
                total: Math.max(errors.length, Number(status.pullErrors || 0)), fresh: fresh};
        });
}

function totals(folders) {
    return (folders || []).reduce(function (sum, folder) {
        sum.files += Number((folder.status || {}).globalFiles || 0);
        sum.bytes += Number((folder.status || {}).globalBytes || 0);
        return sum;
    }, {files: 0, bytes: 0});
}

function iconVariant(state) {
    var phase = state.phase || "", lifecycle = state.lifecycle || {};
    if (phase.indexOf("core-") === 0 || phase === "error") return "notify";
    if (!state.online) return lifecycle.canControl && lifecycle.active === false ? "pause" : "notify";
    if (state.folderProblemCount > 0) return "notify";
    if (state.syncingFolderCount > 0 || state.busy) return "sync";
    return "default";
}

function normalizeDeviceId(value) {
    return String(value || "").trim().toUpperCase();
}

function deviceValidation(value, localId, devices) {
    var id = normalizeDeviceId(value);
    if (!id) return "Enter a device ID or choose a nearby device";
    if (!/^[A-Z2-7]{7}(-[A-Z2-7]{7}){7}$/.test(id))
        return "Use eight groups of seven letters A-Z or digits 2-7, separated by hyphens";
    if (id === normalizeDeviceId(localId)) return "This ID belongs to this device";
    if ((devices || []).some(device => normalizeDeviceId(device.id) === id))
        return "This device is already configured";
    return "";
}

function offerKey(offer) {
    return JSON.stringify([String(offer.folderId), String(offer.deviceId)]);
}

function offerOptions(offers, deviceName) {
    return (offers || []).map(offer => ({id: offerKey(offer),
        label: offer.label || offer.folderId,
        description: offer.folderId + " · " + deviceName(offer.deviceId),
        trailing: offer.encrypted ? "Encrypted" : "Invitation",
        role: offer.encrypted ? "warning" : "accent", offer: offer}));
}

function actionDescription(action, args, target) {
    var label = target || args.folderId || args.deviceId || "Syncthing";
    var descriptions = {
        "folder.pause": ["Pause folder", "Pausing", "Paused " + label],
        "folder.resume": ["Resume folder", "Resuming", "Resumed " + label],
        "folder.forget": ["Forget folder", "Forgetting", "Forgot " + label + "; files were kept"],
        "folder.add-existing": [args.createDirectory ? "Create directory and add" : "Add folder", "Adding folder", "Added " + label],
        "folder.set-sharing": ["Save sharing", "Saving sharing", "Updated sharing for " + label],
        "device.add": ["Add device", "Adding device", "Added " + label],
        "device.remove": ["Remove device", "Removing device", "Removed " + label + "; files were kept"],
        "device.pause": ["Pause device", "Pausing device", "Paused " + label],
        "device.resume": ["Resume device", "Resuming device", "Resumed " + label],
        "device.remove-folder-shares": ["Remove selected shares", "Removing shares", "Removed " + (args.folderIds || []).length + " shares from " + label + "; files were kept"],
        "device.dismiss-pending": ["Dismiss invitation", "Dismissing", "Dismissed invitation from " + label],
        "folder.dismiss-pending": ["Dismiss invitation", "Dismissing", "Dismissed " + label + " from " + (args.pendingDeviceId || "")],
        "webui.remove-profile": ["Restore default and clean up", "Cleaning up profiles", "Restored default UI; owned profiles removed"],
        "lifecycle.start": ["Start Syncthing", "Starting Syncthing", "Started Syncthing"],
        "lifecycle.stop": ["Stop Syncthing", "Stopping Syncthing", "Stopped Syncthing"],
        "lifecycle.enable": ["Enable on login", "Enabling service", "Enabled Syncthing on login"],
        "lifecycle.disable": ["Disable on login", "Disabling service", "Disabled Syncthing on login"]
    };
    var value = descriptions[action] || ["Apply", "Applying", "Updated " + label];
    return {label: value[0], busy: value[1], success: value[2],
        destructive: ["folder.forget", "device.remove", "device.remove-folder-shares", "lifecycle.stop", "lifecycle.disable", "webui.remove-profile"].indexOf(action) >= 0};
}

function deviceDisplay(device, fresh) {
    return !fresh ? {label: "Unknown", role: "muted", help: "Current connection unavailable; values are last reported"}
        : device.paused ? {label: "Paused", role: "warning", help: "Connections and synchronization are paused"}
        : device.connected ? {label: "Connected", role: "success", help: "Available for synchronization"}
        : {label: "Disconnected", role: "muted", help: "Waiting for the remote device to connect"};
}

function shareDisplay(member, device, fresh) {
    if (!fresh || !device || !device.connected || device.paused)
        return {label: "Unconfirmed", role: "muted", help: "Remote acceptance is unconfirmed while the peer is unavailable"};
    return member.remoteState === "valid" ? {label: "Shared", role: "success", help: "The remote device is sharing this folder back"}
        : member.remoteState === "paused" ? {label: "Remote folder paused", role: "warning", help: "The remote device has paused this folder"}
        : member.remoteState === "notSharing" ? {label: "Not sharing back", role: "warning", help: "The remote device has not accepted this folder"}
        : {label: "Unconfirmed", role: "muted", help: "Remote acceptance is pending or not yet reported"};
}
