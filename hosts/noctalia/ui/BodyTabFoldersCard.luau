local Ui = require("./UiConstants.luau")
local BodyTabFoldersCardActivity = require("./BodyTabFoldersCardActivity.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local BusyIcon = require("./SharedWidgetBusyIcon.luau")
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
    local color = state == "UNKNOWN" and (Palette.roles.muted .. "/0.6") or Palette.roles[Model.folderStateRole(state)]
    local action
    if folder.paused then
        action = SharedWidgetControls.tinted("Forget", "FORGET", "circle-x-filled", "error", function()
            controller:confirm("Forget " .. Model.folderLabel(folder) .. " (" .. folder.id .. ")?\n\n"
                .. "This removes only its Syncthing configuration. The directory and data files will not be deleted. "
                .. ((folder.markerName or ".stfolder") == ".stfolder" and "Syncthing will also attempt to remove its internal .stfolder marker. " or "")
                .. "Rejoining the same remote folder requires this exact Folder ID.",
                "folder.forget", { folderId = folder.id })
        end, enabled, "Remove only this unlinked Syncthing configuration")
    elseif scanning then
        action = SharedWidgetControls.tinted("Rescan", "RESCANNING", BusyIcon.spin(controller, "rescan", Palette.roles.warning, "rotate-clockwise"), Palette.roles.warning, nil, true, "Rescan this folder for local changes")
    else
        action = ui.button({ key = "Rescan", text = "RESCAN", glyph = "rotate-clockwise", fontSize = Ui.body, glyphSize = Ui.body, height = Ui.cardControl,
            variant = "outline", enabled = enabled, tooltip = "Rescan this folder for local changes",
            onClick = function() controller:send("folder.rescan", { folderId = folder.id }) end })
    end
    local metaRow = { ui.label({ text = Model.folderMeta(controller.snapshot, folder, scanning), fontSize = Ui.caption, maxLines = 1,
        maxWidth = problem and 120 or nil, color = problem and "error" or "on_surface_variant" }) }
    if problem then
        table.insert(metaRow, ui.row({ key = "see-more", onClick = function()
            local v = controller.view
            v.folderId, v.more = folder.id, not v.more
            if v.more then v.scrollRevision = (v.scrollRevision or 0) + 1 end
            controller:save()
        end }, { SharedWidgetControls.hint('(see "More" below)', "error") }))
    end
    -- Omarchy reserves the activity line so the card keeps its height.
    local details = { BodyTabFoldersCardActivity.render(controller, not folder.paused and folder.id or nil),
        ui.row({ gap = 4, align = "center" }, metaRow) }
    table.insert(details, ui.label({ text = Model.shortPath(folder.path, 40), color = "on_surface_variant", fontSize = Ui.caption, maxLines = 1 }))
    local children = {
        ui.row({ gap = 4, align = "center" }, {
            SharedWidgetControls.chip("open-folder-" .. folder.id, "folder-filled", Model.folderLabel(folder), function()
                controller:openPath(folder.path)
            end, type(folder.path) == "string" and folder.path ~= "", "Open " .. (folder.path or "folder")),
            IdCopyButton.render(controller, folder.id, "copy-folder-" .. folder.id, "Copy folder ID", "Folder ID copied"),
            ui.spacer({ flexGrow = 1 }),
            SharedWidgetControls.badge("folder-state-" .. folder.id, state, color),
        }),
        ui.row({ gap = 8, align = "end" }, {
            ui.column({ gap = 2, flexGrow = 1, minWidth = 0, paddingH = 8, paddingV = 4 }, details),
            action,
        }),
    }
    return SharedWidgetControls.column({ key = "folder-" .. folder.id, gap = 2, radius = 0,
        border = "outline", borderWidth = 1 }, children)
end

return Card
