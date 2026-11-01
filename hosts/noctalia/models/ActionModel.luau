local Model = require("./PanelModel.luau")
local Actions = {}
local labels = {
    refresh = { "Refresh", "Refreshing state...", "Refreshed state" },
    ["folder.rescan"] = { "Rescan folder", "Rescanning folder...", "Folder rescan finished" },
    ["folder.rescan-all"] = { "Rescan all", "Rescanning folders...", "Folder rescans finished" },
    ["folder.recheck-errors"] = { "Recheck errors", "Rechecking folder errors...", "Folder errors rechecked" },
    ["folder.suggest-id"] = { "Generate ID", "Generating folder ID...", "Folder ID generated" },
    ["folder.add-existing"] = { "Add folder", "Adding folder...", "Folder added" },
    ["folder.set-sharing"] = { "Save sharing", "Saving folder sharing...", "Folder sharing saved" },
    ["folder.pause"] = { "Unlink folder", "Pausing folder synchronization...", "Folder unlinked; local files remain" },
    ["folder.resume"] = { "Link folder", "Resuming folder synchronization...", "Folder linked" },
    ["folder.forget"] = { "Forget folder", "Removing folder configuration...", "Folder forgotten; local files remain" },
    ["folder.dismiss-pending"] = { "Dismiss invitation", "Dismissing folder invitation...", "Folder invitation dismissed" },
    ["device.add"] = { "Add device", "Adding device...", "Device added" },
    ["device.pause"] = { "Pause device", "Pausing device...", "Device paused" },
    ["device.resume"] = { "Resume device", "Resuming device...", "Device resumed" },
    ["device.remove"] = { "Remove device", "Removing device...", "Device removed; local files remain" },
    ["device.dismiss-pending"] = { "Dismiss invitation", "Dismissing device invitation...", "Device invitation dismissed" },
    ["device.remove-folder-shares"] = { "Remove shares", "Removing selected shares...", "Selected shares removed" },
    ["webui.open"] = { "Open Web UI", "Opening Web UI...", "Web UI opened" },
    ["webui.set-theme"] = { "Apply theme", "Changing Web UI theme...", "Web UI theme changed" },
    ["webui.apply-profile"] = { "Apply profile", "Preparing Web UI profile...", "Web UI profile applied" },
    ["webui.remove-profile"] = { "Clean up profiles", "Removing owned profiles...", "Noctalia profiles removed" },
    ["lifecycle.start"] = { "Start service", "Starting authorized service...", "Service started" },
    ["lifecycle.stop"] = { "Stop service", "Stopping authorized service...", "Service stopped" },
    ["lifecycle.enable"] = { "Enable at login", "Enabling authorized service at login...", "Service enabled at login" },
    ["lifecycle.disable"] = { "Disable at login", "Disabling authorized service at login...", "Service disabled at login" },
}

function Actions.label(action, state)
    local row = assert(labels[action], "missing presentation for action " .. tostring(action))
    return row[state or 1]
end

local function named(items, id)
    for _, item in items or {} do if item.id == id then return item end end
    return nil
end

local function folderName(snapshot, id)
    local folder = named(snapshot.folders, id)
    return folder and Model.folderLabel(folder) or id
end

local function deviceName(snapshot, id)
    local device = named(snapshot.devices, id) or named(snapshot.pendingDevices, id)
    return device and device.name ~= "" and device.name or string.sub(tostring(id), 1, 7)
end

-- Omarchy's result sentences, as in shared/AdapterService.qml. Taken when the
-- action starts: its result may already have changed the snapshot.
function Actions.notice(action, args, snapshot)
    local folder, device = args.folderId, args.deviceId
    if action == "folder.pause" then
        return "Synchronization for " .. folderName(snapshot, folder) .. " paused. The folder ID, device associations, and data remain."
    elseif action == "folder.resume" then
        return "Linked " .. folderName(snapshot, folder) .. ". Syncthing resumed the folder with its existing sharing configuration."
    elseif action == "folder.forget" then
        return "Removed from Syncthing configuration and the plugin view. The directory and its data files were not deleted. Re-add Folder ID "
            .. folder .. " to rejoin the same remote folder."
    elseif action == "folder.add-existing" then
        if #(args.deviceIds or {}) > 0 then return "Remote devices may have to accept the folder." end
        return "Added " .. (args.label ~= "" and args.label or folder) .. " locally. It is linked but not shared with another device."
    elseif action == "folder.set-sharing" then
        local names = {}
        for _, id in args.deviceIds or {} do table.insert(names, deviceName(snapshot, id)) end
        if #names == 0 then return "Folder sharing removed. The local folder remains configured." end
        local list, previous = table.concat(names, ", "), 0
        for _, member in (named(snapshot.folders, folder) or {}).devices or {} do
            if member.id ~= (snapshot.identity or {}).deviceId then previous += 1 end
        end
        if previous == 0 then return folderName(snapshot, folder) .. " shared with " .. list .. "; waiting for " .. list .. " to accept." end
        return "Sharing with " .. list .. " updated."
    elseif action == "folder.dismiss-pending" then
        local offer = ((snapshot.pendingFolders or {})[folder] or { offeredBy = {} }).offeredBy[args.pendingDeviceId]
        return "Rejected folder request for " .. (offer and offer.label ~= "" and offer.label or folder) .. "."
    elseif action == "device.add" then
        local label = args.deviceName ~= "" and args.deviceName or ("Device " .. string.sub(device, 1, 7))
        return label .. " added. Add this device on " .. label .. " to complete connection."
    elseif action == "device.dismiss-pending" then
        return "Dismissed pending request from " .. deviceName(snapshot, device) .. "."
    elseif action == "device.pause" then
        return "Paused synchronization with " .. deviceName(snapshot, device) .. "."
    elseif action == "device.resume" then
        return "Resumed synchronization with " .. deviceName(snapshot, device) .. "."
    elseif action == "device.remove" then
        return deviceName(snapshot, device) .. " removed from this device."
    elseif action == "device.remove-folder-shares" then
        return "Selected folder shares removed from " .. deviceName(snapshot, device) .. "."
    elseif action == "folder.recheck-errors" then return "Folder errors checked"
    elseif action == "webui.set-theme" then return "Web UI theme updated"
    elseif action == "webui.apply-profile" then return "Web UI profile updated"
    elseif action == "webui.remove-profile" then return "Default Web UI restored; this adapter's profiles removed"
    elseif action == "lifecycle.enable" then return "Syncthing enabled"
    elseif action == "lifecycle.disable" then return "Syncthing disabled"
    elseif action == "lifecycle.start" then return "Syncthing started"
    elseif action == "lifecycle.stop" then return "Syncthing stopped"
    end
    -- Omarchy reports rescans and refreshes through state, not a sentence.
    return ""
end

function Actions.destructive(action)
    return action == "folder.forget" or action == "device.remove" or action == "device.remove-folder-shares"
        or action == "webui.remove-profile" or action == "lifecycle.stop" or action == "lifecycle.disable"
end

return Actions
