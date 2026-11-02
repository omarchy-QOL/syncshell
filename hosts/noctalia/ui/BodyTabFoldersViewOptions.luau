local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Checkbox = require("./SharedWidgetCheckbox.luau")
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
    local all = true
    for _, enabled in v.filters do all = all and enabled end
    local help = { ready = "Synced or newly linked", active = "Currently syncing or scanning", errors = "Needs attention",
        paused = "Syncing is paused", unknown = "Current status is unavailable" }
    local rows = { { Checkbox.render("filter-all", "All", all, function()
        for key in v.filters do v.filters[key] = not all end
        controller:save()
    end, true, "Show every folder") } }
    -- Omarchy opens with its cursor on the first choice.
    rows[1][1].props.fill = not v.actionCursor and "on_surface/0.18" or "#00000000"
    for index, key in { "ready", "active", "errors", "paused", "unknown" } do
        local cell = Checkbox.render("filter-" .. key, string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2), v.filters[key],
            function() v.filters[key] = not v.filters[key]; controller:save() end, true, help[key])
        if index % 2 == 1 then table.insert(rows[#rows], cell) else table.insert(rows, { cell }) end
    end
    for _, cells in rows do table.insert(children, ui.row({ gap = 8 }, cells)) end
    table.insert(children, SharedWidgetControls.caption("SORT"))
    for _, mode in { { "name", "Name A-Z", "Sort folder names alphabetically" }, { "active", "Active first", "Put syncing and scanning folders first" },
        { "errors", "Errors first", "Put folders needing attention first" } } do
        table.insert(children, ui.row({}, { Checkbox.render("sort-" .. mode[1], mode[2], v.sort == mode[1],
            function() v.sort = mode[1]; controller:save() end, true, mode[3], true) }))
    end
    table.insert(children, ui.row({ justify = "end" }, {
        SharedWidgetControls.button("Reset defaults", function()
            for key in v.filters do v.filters[key] = true end
            v.sort, v.search = "name", ""
            v.filtersOpen = false
            if v.selectors and v.selectors.folder then
                v.selectors.folder.query, v.selectors.folder.cursor, v.selectors.folder.open = "", nil, false
            end
            controller:save()
        end, true, "outline", "Reset", "Show all folders\nand sort by name"),
    }))
    return ui.column({ key = "view-options", gap = 6, padding = 6, radius = 4, border = "outline", borderWidth = 1 }, children)
end

return Options
