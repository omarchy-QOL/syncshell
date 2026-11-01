local Ui = require("./UiConstants.luau")
local BodyTabFoldersCardActivity = require("./BodyTabFoldersCardActivity.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local IdCopyButton = require("./SharedWidgetIdCopyButton.luau")
local Card = {}

function Card.render(controller, folder)
    if not folder then return SharedWidgetControls.label("Select a folder. The previous selection may no longer exist.") end
    local online = (controller.snapshot.connection or {}).online == true
    local rescan = controller:rescanState()
    local state = Model.folderState(controller.snapshot, folder, controller.view, rescan)
        local scanning = Model.folderRescanning(controller.snapshot, folder, rescan)
    local enabled = online and not controller:busy()
    local problem = state == "ERROR"
    local color = Palette.roles[Model.folderStateRole(state)]
    local action
    if folder.paused then
        action = SharedWidgetControls.tinted("Forget", "FORGET", "circle-x", "error", function()
            controller:confirm("Forget " .. Model.folderLabel(folder) .. " (" .. folder.id .. ")?\n\n"
                .. "This removes only its Syncthing configuration. The directory and data files will not be deleted. "
                .. (folder.markerName == ".stfolder" and "Syncthing will also attempt to remove its internal .stfolder marker. " or "")
                .. "Rejoining the same remote folder requires this exact Folder ID.",
                "folder.forget", { folderId = folder.id })
        end, enabled, "Remove only this unlinked Syncthing configuration")
    elseif scanning then
        action = SharedWidgetControls.tinted("Rescan", "RESCANNING", "refresh", Palette.roles.warning, nil, false, "Rescan this folder for local changes")
    else
        action = ui.button({ key = "Rescan", text = "RESCAN", glyph = "refresh", fontSize = Ui.body, glyphSize = Ui.body, height = Ui.cardControl,
            variant = "outline", enabled = enabled, tooltip = "Rescan this folder for local changes",
            onClick = function() controller:send("folder.rescan", { folderId = folder.id }) end })
    end
    local details = { ui.label({ text = Model.folderMeta(controller.snapshot, folder, scanning), fontSize = Ui.caption, maxLines = 2,
        color = problem and "error" or "on_surface_variant" }) }
    if problem then
        table.insert(details, ui.row({ key = "see-more", onClick = function()
            local v = controller.view
            v.folderId, v.more = folder.id, not v.more
            if v.more then v.scrollRevision = (v.scrollRevision or 0) + 1 end
            controller:save()
        end }, {
            SharedWidgetControls.hint('(see "More" below)', "error"),
        }))
    end
    table.insert(details, ui.label({ text = Model.shortPath(folder.path), color = "on_surface_variant", fontSize = Ui.caption, maxLines = 1 }))
    local children = {
        ui.row({ gap = 4, align = "center" }, {
            SharedWidgetControls.chip("open-folder-" .. folder.id, "folder", Model.folderLabel(folder), function()
                controller:openPath(folder.path)
            end, type(folder.path) == "string" and folder.path ~= "", "Open " .. (folder.path or "folder")),
            IdCopyButton.render(controller, folder.id, "copy-folder-" .. folder.id, "Copy folder ID"),
            ui.spacer({ flexGrow = 1 }),
            SharedWidgetControls.badge("folder-state-" .. folder.id, state, color),
        }),
        ui.row({ gap = 8, align = "end" }, {
            ui.column({ gap = 2, flexGrow = 1, minWidth = 0 }, details),
            action,
        }),
    }
    local activity = not folder.paused and BodyTabFoldersCardActivity.render(controller, folder.id)
    if activity then table.insert(children, activity) end
    return SharedWidgetControls.column({ key = "folder-" .. folder.id, gap = 10, padding = 6, radius = 2,
        border = scanning and Palette.roles.warning or (problem and "error" or (Model.folderSyncing(folder) and "on_surface" or "outline")), borderWidth = 1 }, children)
end

return Card
