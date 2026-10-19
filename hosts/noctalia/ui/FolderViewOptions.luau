local Model = require("../models/PanelModel.luau")
local Controls = require("./Controls.luau")
local Options = {}

function Options.render(controller)
    local v = controller.view
    local children = { Controls.button(v.filtersOpen and "Hide filters and sort" or "Filters and sort", function()
        v.filtersOpen = not v.filtersOpen; controller:save()
    end, true, "ghost", "folder-filters") }
    if not v.filtersOpen then return ui.column({ gap = 6 }, children) end
    local all, any = true, false
    for _, enabled in v.filters do all = all and enabled; any = any or enabled end
    table.insert(children, ui.row({ gap = 8 }, {
        ui.toggle({ key = "filter-all", checked = all, onChange = function(value)
            for key in v.filters do v.filters[key] = Model.bool(value) end
            controller:save()
        end }), Controls.label(any and not all and "All (mixed)" or "All"),
        Controls.button("Reset", function()
            for key in v.filters do v.filters[key] = true end
            v.sort, v.search = "name", ""
            v.filtersOpen = false
            if v.selectors and v.selectors.folder then
                v.selectors.folder.query, v.selectors.folder.cursor, v.selectors.folder.open = "", nil, false
            end
            controller:save()
        end),
    }))
    for _, key in { "ready", "active", "errors", "paused", "unknown" } do
        table.insert(children, ui.row({ gap = 8 }, {
            ui.toggle({ key = "filter-" .. key, checked = v.filters[key], onChange = function(value) v.filters[key] = Model.bool(value); controller:save() end }),
            Controls.label(string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)),
        }))
    end
    local modes = { "name", "active", "errors" }
    table.insert(children, ui.select({ key = "folder-sort", options = { "Name A-Z", "Active first", "Errors first" },
        selectedIndex = (table.find(modes, v.sort) or 1) - 1,
        onChange = function(index)
            local value = tonumber(index)
            if value and modes[value + 1] then v.sort = modes[value + 1]; controller:save() end
        end }))
    return ui.column({ gap = 8 }, children)
end

return Options
