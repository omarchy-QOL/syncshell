local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Checkbox = require("./SharedWidgetCheckbox.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local Options = {}

function Options.trigger(controller, shown, total)
    local v = controller.view
    local children = { ActionButton.render("folder-filters", "adjustments-horizontal", function()
        v.filtersOpen, v.optionsCursor = not v.filtersOpen, 1; controller:save()
    end, true, nil, "Filter and sort folders") }
    if shown < total then
        table.insert(children, ui.row({ key = "folder-filter-count", onClick = v.filtersOpen and function() v.filtersOpen = false; controller:save() end or nil }, {
            SharedWidgetControls.hint("(" .. tostring(shown) .. " of " .. tostring(total) .. ")"),
        }))
    end
    return ui.row({ gap = 6, align = "center" }, children)
end

-- Omarchy's popup keys: j and k change row and wrap, h and l change column in
-- the filter grid. Choices 1-6 form that grid, 7-9 are the sort and 10 is Reset.
local function step(index, move)
    if move == "cursor-left" or move == "cursor-right" then
        if index > 6 then return index end
        return index % 2 == 1 and index + 1 or index - 1
    elseif move == "cursor-down" then
        if index >= 10 then return 1 end
        if index <= 6 then return index + 2 <= 6 and index + 2 or 7 end
        return index + 1
    elseif move == "cursor-up" then
        if index <= 2 then return 10 end
        if index <= 6 then return index - 2 end
        return index == 7 and 5 or index - 1
    end
    return index
end

function Options.render(controller)
    local v = controller.view
    if not v.filtersOpen then return nil end
    local cursor = v.optionsCursor or 1
    local actions, nodes = {}, {}
    local function choice(node, action)
        table.insert(actions, action); table.insert(nodes, node)
        local index = #nodes
        node.props.fill = index == cursor and "on_surface/0.18" or "#00000000"
        node.props.onHover = function(hovered)
            if hovered and v.optionsCursor ~= index then v.optionsCursor = index; controller:save() end
        end
        return node
    end
    local children = { SharedWidgetControls.caption("VIEW OPTIONS") }
    local all, any = true, false
    for _, enabled in v.filters do all = all and enabled; any = any or enabled end
    local help = { ready = "Synced or newly linked", active = "Currently syncing or scanning", errors = "Needs attention",
        paused = "Syncing is paused", unknown = "Current status is unavailable" }
    local function toggleAll()
        for key in v.filters do v.filters[key] = not all end
        controller:save()
    end
    local rows = { { choice(Checkbox.render("filter-all", "All", all, toggleAll, true, "Show every folder", nil, nil, any and not all), toggleAll) } }
    for index, key in { "ready", "active", "errors", "paused", "unknown" } do
        local function toggle() v.filters[key] = not v.filters[key]; controller:save() end
        local cell = choice(Checkbox.render("filter-" .. key, string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2), v.filters[key],
            toggle, true, help[key]), toggle)
        if index % 2 == 1 then table.insert(rows[#rows], cell) else table.insert(rows, { cell }) end
    end
    for _, cells in rows do table.insert(children, ui.row({ gap = 8 }, cells)) end
    table.insert(children, SharedWidgetControls.separator())
    table.insert(children, SharedWidgetControls.caption("SORT"))
    for _, mode in { { "name", "Name A-Z", "Sort folder names alphabetically" }, { "active", "Active first", "Put syncing and scanning folders first" },
        { "errors", "Errors first", "Put folders needing attention first" } } do
        local function pick() v.sort = mode[1]; controller:save() end
        table.insert(children, ui.row({}, { choice(Checkbox.render("sort-" .. mode[1], mode[2], v.sort == mode[1], pick, true, mode[3], true), pick) }))
    end
    local function reset()
        for key in v.filters do v.filters[key] = true end
        v.sort = "name"
        controller:save()
    end
    table.insert(actions, reset)
    table.insert(children, ui.row({ justify = "end" }, {
        SharedWidgetControls.button("Reset defaults", reset, true, cursor == 10 and "default" or "outline", "Reset", "Show all folders\nand sort by name"),
    }))
    controller.navigation = function(chord, raw)
        if chord == "Alt+Left" then v.filtersOpen = false; controller:save(); return true end
        if chord == "Alt+Return" then actions[cursor](); return true end
        local move = raw == "Alt+Down" and "cursor-down" or (raw == "Alt+Up" and "cursor-up" or raw)
        v.optionsCursor = step(cursor, move); controller:save()
        return true
    end
    return ui.column({ key = "view-options", gap = 6, padding = 6, radius = 4, border = "outline", borderWidth = 1 }, children)
end

return Options
