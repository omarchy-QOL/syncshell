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
            state.query, state.cursor = "", nil
            if options.onSearch then options.onSearch("") end
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
    -- The host grants focus once per key, so each opening needs its own.
    local search = ui.input({ key = "search-" .. key .. "-" .. tostring(state.opens or 0), value = query, focus = true, height = Ui.control, fontSize = Ui.body, flexGrow = 1,
        placeholder = options.placeholder or "Search names, paths or IDs",
        onChange = function(text)
            state.query, state.cursor = text, nil
            if options.onSearch then options.onSearch(text) end
            controller:save()
        end, onSubmit = activate })
    local children = { ui.row({ gap = 6, align = "center" }, options.accessory and { search, options.accessory() } or { search }) }
    if options.below then
        local extra = options.below()
        if extra then table.insert(children, extra) end
    end
    local first = math.max(1, math.floor((cursor - 1) / pageSize) * pageSize + 1)
    local list = {}
    for index = first, math.min(first + pageSize - 1, #matches) do
        local row = matches[index]
        local cells = { ui.button({ key = "option-" .. key .. "-" .. row.id, text = row.trailing and (row.label .. " " .. row.trailing) or row.label, contentAlign = "start", height = Ui.control, fontSize = Ui.body, flexGrow = 1,
            variant = (index == cursor or row.id == selected) and "default" or "ghost", enabled = row.enabled ~= false and not controller:busy(),
            onClick = function() state.open = false; choose(row.id); controller:save() end }) }
        if row.role then table.insert(cells, ui.box({ width = 8, height = 8, radius = 4, fill = Palette.roles[row.role], tooltip = row.description })) end
        table.insert(list, ui.row({ key = row.id, gap = 8, align = "center" }, cells))
    end
    if #matches == 0 then table.insert(list, SharedWidgetControls.hint(options.empty or (#rows == 0 and "No available items" or "No matching items"))) end
    table.insert(children, ui.column({ key = "results-" .. key, gap = 2 }, list))
    if #matches > pageSize then
        table.insert(children, ui.row({ gap = 6, align = "center" }, {
            ui.button({ key = "Previous", glyph = "chevron-left", text = "", variant = "ghost", height = Ui.control, enabled = first > 1, tooltip = "Previous page",
                onClick = function() state.cursor = matches[math.max(1, first - pageSize)].id; controller:save() end }),
            ui.label({ text = tostring(first) .. "-" .. tostring(math.min(first + pageSize - 1, #matches)) .. " of " .. tostring(#matches),
                color = "on_surface_variant", fontSize = Ui.caption, textAlign = "center", flexGrow = 1 }),
            ui.button({ key = "Next", glyph = "chevron-right", text = "", variant = "ghost", height = Ui.control, enabled = first + pageSize <= #matches, tooltip = "Next page",
                onClick = function() state.cursor = matches[first + pageSize].id; controller:save() end }),
        }))
    end
    local tree = SharedWidgetControls.column({ key = "list-" .. key, gap = 6, padding = 6, radius = 6, border = "outline", borderWidth = 1 }, children)
    -- Omarchy's list floats over the card. This host has no overlay, so a
    -- detached list takes the card's place instead.
    if options.detached then controller.dropdownList = tree; return trigger end
    return ui.column({ gap = 6 }, { trigger, tree })
end

return Dropdown
