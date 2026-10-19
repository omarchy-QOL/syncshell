local Controls = require("./Controls.luau")
local Dropdown = {}
local pageSize = 6

function Dropdown.render(controller, owner, key, label, rows, selected, choose, options)
    options = options or {}
    owner.selectors = owner.selectors or {}
    local state = owner.selectors[key] or { open = false, query = "" }
    owner.selectors[key] = state
    local chosen
    for _, row in rows do if row.id == selected then chosen = row end end
    local function close() state.open = false; controller:save() end
    local children = { Controls.button(label .. " | " .. (options.selectedLabel or (chosen and chosen.label) or "Choose"), function()
        state.open = not state.open
        if state.open then
            owner.disclosures = {}
            for other, item in owner.selectors do if other ~= key then item.open = false end end
        end
        controller:save()
    end, not controller:busy(), "outline", "select-" .. key) }
    if not state.open then return ui.column({ gap = 6 }, children) end
    local query = options.query or state.query
    local matches = {}
    for _, row in rows do
        local text = row.label .. " " .. row.id .. " " .. (row.description or "")
        if options.filtered or string.find(string.lower(text), string.lower(query), 1, true) then table.insert(matches, row) end
    end
    local cursor = 1
    for index, row in matches do if row.id == (state.cursor or selected) then cursor = index end end
    state.cursor = matches[cursor] and matches[cursor].id
    local function activate()
        local row = matches[cursor]
        if row and row.enabled ~= false and not controller:busy() then
            state.open = false; choose(row.id); controller:save()
        end
    end
    controller.navigation = function(chord)
        if chord == "Alt+Left" then close(); return true end
        if chord == "Alt+Return" then activate(); return true end
        local delta = chord == "Alt+Down" and 1 or (chord == "Alt+Up" and -1 or 0)
        if delta == 0 then return false end
        if #matches > 0 then
            for offset = 1, #matches do
                local nextIndex = ((cursor - 1 + delta * offset) % #matches) + 1
                if matches[nextIndex].enabled ~= false then state.cursor = matches[nextIndex].id; break end
            end
            controller:save()
        end
        return true
    end
    table.insert(children, ui.input({ key = "search-" .. key, value = query, focus = true,
        placeholder = options.placeholder or "Search names, paths or IDs",
        onChange = function(text)
            state.query, state.cursor = text, nil
            if options.onSearch then options.onSearch(text) end
            controller:save()
        end, onSubmit = activate }))
    if options.accessory then table.insert(children, options.accessory()) end
    local first = cursor
    local list = {}
    for index = first, math.min(first + pageSize - 1, #matches) do
        local row = matches[index]
        table.insert(list, ui.column({ key = row.id, gap = 2 }, {
            Controls.button((row.id == selected and "Selected: " or "") .. row.label, function()
                state.open = false; choose(row.id); controller:save()
            end, row.enabled ~= false and not controller:busy(), index == cursor and "primary" or "ghost", "option-" .. key .. "-" .. row.id),
            Controls.label(row.description or row.id, "on_surface_variant"),
        }))
    end
    if #matches == 0 then table.insert(list, Controls.label(options.empty or (#rows == 0 and "No available items" or "No matching items"))) end
    table.insert(children, ui.scroll({ key = "results-" .. key .. "-" .. tostring(state.cursor), height = 260, gap = 4 }, list))
    table.insert(children, ui.row({ gap = 6 }, {
        Controls.button("Previous", function() state.cursor = matches[math.max(1, first - pageSize)].id; controller:save() end, first > 1),
        Controls.button("Next", function() state.cursor = matches[first + pageSize].id; controller:save() end, first + pageSize <= #matches),
        Controls.button("Back", close, true, "ghost", "back-" .. key),
    }))
    table.insert(children, Controls.label(tostring(#matches) .. " results | Alt+Up/Down: select | Enter in search: choose | Alt+Left: back", "on_surface_variant"))
    local tree = Controls.column({ gap = 6 }, children)
    controller.selectionView = { title = label, tree = tree, close = close }
    return tree
end

return Dropdown
