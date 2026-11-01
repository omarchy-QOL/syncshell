local Model = require("../models/PanelModel.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local Options = {}

function Options.trigger(controller)
    local v = controller.view
    return ActionButton.render("folder-filters", "adjustments-horizontal", function()
        v.filtersOpen = not v.filtersOpen; controller:save()
    end, true, nil, "Filter and sort folders")
end

function Options.render(controller)
    local v = controller.view
    if not v.filtersOpen then return nil end
    local children = { SharedWidgetControls.caption("VIEW OPTIONS") }
    local all, any = true, false
    for _, enabled in v.filters do all = all and enabled; any = any or enabled end
    local function check(key, text, checked, change)
        return ui.row({ gap = 8, align = "center", flexGrow = 1 }, {
            ui.toggle({ key = key, checked = checked, onChange = change }),
            ui.label({ text = text, fontSize = 12, flexGrow = 1 }),
        })
    end
    local rows = { { check("filter-all", any and not all and "All (mixed)" or "All", all, function(value)
        for key in v.filters do v.filters[key] = Model.bool(value) end
        controller:save()
    end) } }
    for index, key in { "ready", "active", "errors", "paused", "unknown" } do
        local cell = check("filter-" .. key, string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2), v.filters[key],
            function(value) v.filters[key] = Model.bool(value); controller:save() end)
        if index % 2 == 1 then table.insert(rows[#rows], cell) else table.insert(rows, { cell }) end
    end
    for _, cells in rows do table.insert(children, ui.row({ gap = 8 }, cells)) end
    table.insert(children, SharedWidgetControls.caption("SORT"))
    local modes = { "name", "active", "errors" }
    table.insert(children, ui.select({ key = "folder-sort", controlSize = "sm", options = { "Name A-Z", "Active first", "Errors first" },
        selectedIndex = (table.find(modes, v.sort) or 1) - 1,
        onChange = function(index)
            local value = tonumber(index)
            if value and modes[value + 1] then v.sort = modes[value + 1]; controller:save() end
        end }))
    table.insert(children, ui.row({ justify = "end" }, {
        SharedWidgetControls.button("Reset defaults", function()
            for key in v.filters do v.filters[key] = true end
            v.sort, v.search = "name", ""
            v.filtersOpen = false
            if v.selectors and v.selectors.folder then
                v.selectors.folder.query, v.selectors.folder.cursor, v.selectors.folder.open = "", nil, false
            end
            controller:save()
        end, true, "outline", "Reset"),
    }))
    return ui.column({ gap = 8 }, children)
end

return Options
