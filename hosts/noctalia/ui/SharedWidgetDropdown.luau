local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local Model = require("../models/PanelModel.luau")
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
    local trigger = SharedWidgetControls.selectTrigger("select-" .. key, options.selectedLabel or (chosen and chosen.label) or "Choose", function()
        -- Omarchy's selector only opens with something to choose.
        if options.openable == false or (options.openable == nil and #rows <= 1) then return end
        state.open = not state.open
        if state.open then
            state.opens = (state.opens or 0) + 1
            -- Omarchy clears the search with each opening.
            state.query, state.cursor, state.first = "", nil, nil
            if options.onSearch then options.onSearch("") end
            if options.onOpen then options.onOpen() end
            owner.disclosures = {}
            for other, item in owner.selectors do if other ~= key then item.open = false end end
        end
        controller:save()
    end, true, false, options.help, chosen and chosen.trailing)
    if not state.open then return trigger end
    local query = options.query or state.query
    local matches = {}
    for _, row in rows do
        if options.filtered or Model.matchesSearch(row.label, query) then table.insert(matches, row) end
    end
    local cursor = 1
    -- Omarchy returns to the first result as the search changes.
    if state.searchEdited then state.searchEdited = nil
    else for index, row in matches do if row.id == (state.cursor or selected) then cursor = index end end end
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
        -- Omarchy's list stops at both ends.
        local nextIndex = cursor + delta
        while matches[nextIndex] and matches[nextIndex].enabled == false do nextIndex += delta end
        if matches[nextIndex] then state.cursor = matches[nextIndex].id; controller:save() end
        return true
    end
    -- The host grants focus once per key, so each opening needs its own.
    -- A focused field would take the letters an open popup needs, so it steps aside.
    local searching = not (options.holdsKeys and options.holdsKeys())
    local search = ui.input({ key = "search-" .. key .. "-" .. tostring(state.opens or 0) .. (searching and "" or "-held"), value = query, focus = searching, height = Ui.control, fontSize = Ui.body, flexGrow = 1,
        placeholder = options.placeholder or "Search names, paths or IDs",
        onChange = function(text)
            -- The field already has focus, so the key the placeholder names only clears it.
            if text == "/" then
                text, state.opens = "", (state.opens or 0) + 1
            end
            state.query, state.cursor, state.first, state.searchEdited = text, nil, nil, true
            if options.onSearch then options.onSearch(text) end
            controller:save()
        end, onSubmit = activate })
    -- Omarchy offers search only in the folder selector.
    local children = {}
    if options.searchable then
        table.insert(children, ui.row({ gap = 6, align = "center" }, options.accessory and { search, options.accessory() } or { search }))
    end
    if options.below then
        local extra = options.below()
        if extra then table.insert(children, extra) end
    end
    -- Moves only as far as the current row needs, as Omarchy's list scrolls; a page
    -- tied to the cursor would jump under a hovering pointer.
    local first = state.first or math.max(1, cursor - pageSize + 1)
    if cursor < first then first = cursor elseif cursor >= first + pageSize then first = cursor - pageSize + 1 end
    first = math.max(1, math.min(first, #matches - pageSize + 1))
    state.first = first
    local list = {}
    for index = first, math.min(first + pageSize - 1, #matches) do
        local row = matches[index]
        -- Omarchy's highlight is a band across the row, status dot included.
        local enabled = row.enabled ~= false and not controller:busy()
        local cells = { ui.label({ text = row.trailing and (row.label .. " " .. row.trailing) or row.label, fontSize = Ui.body, maxLines = 1, flexGrow = 1 }) }
        if row.role then table.insert(cells, ui.box({ width = 8, height = 8, radius = 4, fill = Palette.roles[row.role], tooltip = row.description })) end
        table.insert(list, ui.row({ key = "option-" .. key .. "-" .. row.id, gap = 8, align = "center", height = Ui.control, paddingH = 10, radius = 4,
            fill = (index == cursor or row.id == selected) and "on_surface/0.18" or "#00000000", opacity = enabled and 1 or 0.5,
            onClick = enabled and function() state.open = false; choose(row.id); controller:save() end or nil,
            onHover = enabled and function(hovered)
                if hovered and state.cursor ~= row.id then state.cursor = row.id; controller:save() end
            end or nil }, cells))
    end
    if #matches == 0 then table.insert(list, SharedWidgetControls.hint(options.empty or (#rows == 0 and "No available items" or "No matching items"))) end
    table.insert(children, ui.column({ key = "results-" .. key, gap = 2 }, list))
    if #matches > pageSize then
        table.insert(children, ui.row({ gap = 6, align = "center" }, {
            ui.button({ key = "Previous", glyph = "chevron-left", text = "", variant = "ghost", height = Ui.control, enabled = first > 1, tooltip = "Previous page",
                onClick = function()
                    state.first = math.max(1, first - pageSize); state.cursor = matches[state.first].id; controller:save()
                end }),
            ui.label({ text = tostring(first) .. "-" .. tostring(math.min(first + pageSize - 1, #matches)) .. " of " .. tostring(#matches),
                color = "on_surface_variant", fontSize = Ui.caption, textAlign = "center", flexGrow = 1 }),
            ui.button({ key = "Next", glyph = "chevron-right", text = "", variant = "ghost", height = Ui.control, enabled = first + pageSize <= #matches, tooltip = "Next page",
                onClick = function()
                    state.first = first + pageSize; state.cursor = matches[state.first].id; controller:save()
                end }),
        }))
    end
    local tree = SharedWidgetControls.column({ key = "list-" .. key, gap = 6, padding = 6, radius = 6, border = "on_surface_variant", borderWidth = 1 }, children)
    -- Omarchy's list floats over the card. This host has no overlay, so a
    -- detached list takes the card's place instead.
    if options.detached then controller.dropdownList = tree; return trigger end
    return ui.column({ gap = 6 }, { trigger, tree })
end

return Dropdown
