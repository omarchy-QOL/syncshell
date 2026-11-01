local BodyTabFoldersCardActivity = require("./BodyTabFoldersCardActivity.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local IdCopyButton = require("./SharedWidgetIdCopyButton.luau")
local Card = {}

function Card.render(controller, folder)
    if not folder then return SharedWidgetControls.label("Select a folder. The previous selection may no longer exist.") end
    local online = (controller.snapshot.connection or {}).online == true
    local state, explanation = Model.folderState(controller.snapshot, folder, controller.view)
    local status = folder.status or {}
    local scanning = controller.view.scanning[folder.id] == true
        or string.sub(status.state or "", 1, 4) == "scan"
    local enabled = online and not controller:busy()
    local open = SharedWidgetControls.button(Model.folderLabel(folder), function()
        controller:openPath(folder.path)
    end, type(folder.path) == "string" and folder.path ~= "", "outline",
        "open-folder-" .. folder.id, "Open " .. (folder.path or "folder"))
    open.props.flexGrow = 1
    local children = {
        ui.row({ gap = 6, align = "center" }, {
            open,
            IdCopyButton.render(controller, folder.id, "copy-folder-" .. folder.id, "Copy folder ID"),
            ui.label({ key = "folder-state-" .. folder.id, text = state,
                color = Palette.roles[Model.folderStateRole(state)], fontWeight = "bold" }),
        }),
        SharedWidgetControls.label(explanation, "on_surface_variant"),
        SharedWidgetControls.label(tostring(status.globalFiles or 0) .. " files | " .. Model.bytes(status.globalBytes)),
        SharedWidgetControls.label(folder.path, "on_surface_variant"),
        ui.row({ gap = 6 }, {
            folder.paused and SharedWidgetControls.button("Forget", function()
                controller:confirm("Forget " .. Model.folderLabel(folder) .. " (" .. folder.id .. ")?\n"
                    .. "Only its Syncthing configuration is removed. Local files remain. "
                    .. (folder.markerName == ".stfolder" and "Syncthing also attempts to remove its internal .stfolder marker. " or "")
                    .. "Keep the ID to rejoin this folder.",
                    "folder.forget", { folderId = folder.id })
            end, enabled, "destructive", nil, "Remove only this unlinked Syncthing configuration; local files remain")
            or SharedWidgetControls.button(controller:actionLabel("folder.rescan",
                scanning and "Scanning..." or "Rescan"), function()
                controller:send("folder.rescan", { folderId = folder.id })
            end, enabled and not scanning, nil, controller:actionKey("rescan-" .. folder.id),
                "Look for local file changes"),
        }),
    }
    if (status.needTotalItems or 0) > 0 or (status.needBytes or 0) > 0 then
        table.insert(children, SharedWidgetControls.label(tostring(status.needTotalItems or 0)
            .. " items remaining | " .. Model.bytes(status.needBytes)))
    end
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
