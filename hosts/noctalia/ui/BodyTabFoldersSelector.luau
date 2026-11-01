local ViewOptions = require("./BodyTabFoldersViewOptions.luau")
local Model = require("../models/PanelModel.luau")
local Dropdown = require("./SharedWidgetDropdown.luau")
local Selector = {}

function Selector.render(controller)
    local v, snapshot = controller.view, controller.snapshot
    local selected = Model.find(snapshot.folders, v.folderId)
    local rows = Model.folderRows(snapshot, v)
    for _, row in rows do
        row.description = string.upper(row.group) .. " | " .. row.path .. " | " .. row.id
        row.role = Model.folderGroupRole(row.group)
    end
    return Dropdown.render(controller, v, "folder", "Folder", rows, v.folderId, function(id) v.folderId = id end, {
        selectedLabel = selected and Model.folderLabel(selected), detached = true,
        placeholder = "To search press '/'",
        empty = "No folders match the search and filters", query = v.search, filtered = true, onSearch = function(text) v.search = text end,
        accessory = function() return ViewOptions.trigger(controller) end,
        below = function() return ViewOptions.render(controller) end,
    })
end

return Selector
