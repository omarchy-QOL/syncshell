local Selector = require("./BodyTabFoldersSelector.luau")
local Card = require("./BodyTabFoldersCard.luau")
local Model = require("../models/PanelModel.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local BodyTabFolders = {}

function BodyTabFolders.render(controller)
    local folders = controller.snapshot.folders or {}
    local folder = Model.find(folders, controller.view.folderId)
    local online = (controller.snapshot.connection or {}).online == true
    local enabled = online and not controller:busy()
    local toolbar = {}
    if #folders > 0 then
        table.insert(toolbar, Selector.render(controller))
    else
        table.insert(toolbar, ui.label({ text = online and "No folders configured."
            or "Folder status is unavailable.", color = "on_surface_variant", flexGrow = 1 }))
    end
    table.insert(toolbar, ActionButton.render("Add folder", "plus", function()
        controller:openForm("addFolder")
    end, enabled, nil, "Add folder (locally)"))
    if #folders > 0 then
        table.insert(toolbar, ActionButton.render("Sharing", "share", function()
            controller:openForm("sharing", folder)
        end, enabled and folder ~= nil, nil, "Share folder\n(other device)"))
        table.insert(toolbar, ActionButton.render(folder and folder.paused and "Link" or "Unlink",
            folder and folder.paused and "link" or "x", function()
                controller:confirm(folder.paused
                    and ("Link " .. Model.folderLabel(folder) .. " (" .. folder.id .. ")?\n\nSyncthing will resume synchronization for this folder.")
                    or ("Unlink " .. Model.folderLabel(folder) .. " (" .. folder.id .. ")?\n\nSyncthing will pause synchronization. Its configuration and local files remain."),
                    folder.paused and "folder.resume" or "folder.pause", { folderId = folder.id })
            end, enabled and folder ~= nil, nil,
            folder and (folder.paused and "Link folder" or "Unlink folder (locally)") or "Select a folder", nil,
            folder and folder.paused and Palette.roles.success or "error"))
    end
    local children = { ui.row({ key = "folder-toolbar", gap = 6, align = "center" }, toolbar) }
    if controller.dropdownList then table.insert(children, controller.dropdownList)
    elseif #folders > 0 then table.insert(children, Card.render(controller, folder)) end
    return ui.column({ key = "folders", gap = 8 }, children)
end

return BodyTabFolders
