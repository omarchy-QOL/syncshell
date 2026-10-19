local ViewOptions = require("./FolderViewOptions.luau")
local Model = require("../models/PanelModel.luau")
local Controls = require("./Controls.luau")
local Dropdown = require("./SyncshellDropdown.luau")
local Selector = {}

function Selector.render(controller)
    local v, snapshot = controller.view, controller.snapshot
    local selected = Model.find(snapshot.folders, v.folderId)
    local rows = Model.folderRows(snapshot, v)
    for _, row in rows do row.description = string.upper(row.group) .. " | " .. row.path .. " | " .. row.id end
    return ui.column({ gap = 6 }, {
        Dropdown.render(controller, v, "folder", "Folder", rows, v.folderId, function(id) v.folderId = id end, {
            selectedLabel = selected and Model.folderLabel(selected),
            empty = "No folders match the search and filters", query = v.search, filtered = true, onSearch = function(text) v.search = text end,
            accessory = function() return ViewOptions.render(controller) end,
        }),
        Controls.label(tostring(#rows) .. " of " .. tostring(#(snapshot.folders or {})) .. " folders", "on_surface_variant"),
    })
end

return Selector
