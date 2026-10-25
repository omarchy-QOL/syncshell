local BodyTabFoldersCardActivity = require("./BodyTabFoldersCardActivity.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Card = {}

function Card.render(controller, folder)
    if not folder then return SharedWidgetControls.label("Select a folder. The previous selection may no longer exist.") end
    local online = (controller.snapshot.connection or {}).online == true
    local group = Model.folderGroup(folder, online and (controller.snapshot.connection or {}).fresh)
    local colors = { errors = "error", active = "primary", ready = "tertiary", paused = "on_surface_variant", unknown = "on_surface_variant" }
    local state, explanation = Model.folderState(controller.snapshot, folder, controller.view)
    local status = folder.status or {}
    local scanning = controller.view.scanning[folder.id] == true
    local enabled = online and not controller:busy()
    local children = {
        SharedWidgetControls.label(Model.folderLabel(folder)),
        SharedWidgetControls.label(state .. " | " .. explanation, colors[group]),
        SharedWidgetControls.label(folder.path), SharedWidgetControls.label("ID: " .. folder.id, "on_surface_variant"),
        SharedWidgetControls.label(tostring(status.globalFiles or 0) .. " files | " .. Model.bytes(status.globalBytes)),
        SharedWidgetControls.label(tostring(status.needTotalItems or 0) .. " items remaining | " .. Model.bytes(status.needBytes)),
        ui.row({ gap = 6 }, {
            SharedWidgetControls.button("Open folder", function() controller:openPath(folder.path) end),
            SharedWidgetControls.button("Copy ID", function() controller:copy(folder.id) end),
            SharedWidgetControls.button(scanning and "Scanning..." or "Rescan", function() controller:send("folder.rescan", { folderId = folder.id }) end,
                enabled and not folder.paused and not scanning, nil, controller:actionKey("rescan-" .. folder.id), folder.paused and "Link this folder before rescanning" or "Look for local file changes"),
        }),
        ui.row({ gap = 6 }, {
            SharedWidgetControls.button("Sharing", function() controller:openForm("sharing", folder) end, enabled),
            SharedWidgetControls.button(folder.paused and "Link" or "Unlink", function()
                controller:confirm((folder.paused and "Resume synchronization for " or "Pause synchronization for ")
                    .. Model.folderLabel(folder) .. "? Local files remain.",
                    folder.paused and "folder.resume" or "folder.pause", { folderId = folder.id })
            end, enabled),
            SharedWidgetControls.button("Forget", function()
                controller:confirm("Forget " .. Model.folderLabel(folder) .. " (" .. folder.id .. ")?\n"
                    .. "Only its Syncthing configuration is removed. Local files remain. "
                    .. (folder.markerName == ".stfolder" and "Syncthing also attempts to remove its internal .stfolder marker. " or "")
                    .. "Keep the ID to rejoin this folder.",
                    "folder.forget", { folderId = folder.id })
            end, enabled and folder.paused, "destructive", nil, "Unlink first, then remove only this folder configuration; local files remain"),
        }),
    }
    local remoteCount = 0
    for _, member in folder.devices or {} do
        if member.id ~= (controller.snapshot.identity or {}).deviceId then
            remoteCount += 1
            local device = Model.find(controller.snapshot.devices, member.id)
            local _, meaning = Model.shareMeaning(controller.snapshot, member.id, member.remoteState)
            table.insert(children, SharedWidgetControls.label((device and device.name or member.id) .. ": " .. meaning, "on_surface_variant"))
        end
    end
    if not folder.devices then table.insert(children, SharedWidgetControls.label("Sharing state is unavailable", "error"))
    elseif remoteCount == 0 then table.insert(children, SharedWidgetControls.label("Local only", "on_surface_variant")) end
    table.insert(children, BodyTabFoldersCardActivity.render(controller, folder.id))
    if status.error and status.error ~= "" then table.insert(children, SharedWidgetControls.label(status.error, "error")) end
    for _, failure in status.errors or {} do table.insert(children, SharedWidgetControls.label(failure.path .. "\n" .. failure.error, "error")) end
    return SharedWidgetControls.column({ key = "folder-" .. folder.id, gap = 8, padding = 10, fill = "surface_variant" }, children)
end

return Card
