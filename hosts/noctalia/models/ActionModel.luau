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
    ["webui.remove-profile"] = { "Restore and clean up", "Restoring default and removing owned profiles...", "Default restored; Noctalia profiles removed" },
    ["lifecycle.start"] = { "Start service", "Starting authorized service...", "Service started" },
    ["lifecycle.stop"] = { "Stop service", "Stopping authorized service...", "Service stopped" },
    ["lifecycle.enable"] = { "Enable at login", "Enabling authorized service at login...", "Service enabled at login" },
    ["lifecycle.disable"] = { "Disable at login", "Disabling authorized service at login...", "Service disabled at login" },
}

function Actions.label(action, state)
    local row = assert(labels[action], "missing presentation for action " .. tostring(action))
    return row[state or 1]
end

function Actions.destructive(action)
    return action == "folder.forget" or action == "device.remove" or action == "device.remove-folder-shares"
        or action == "webui.remove-profile" or action == "lifecycle.stop" or action == "lifecycle.disable"
end

return Actions
