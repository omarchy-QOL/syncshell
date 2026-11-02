local Palette = require("../controllers/ThemePaletteController.luau")
local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Checkbox = require("./SharedWidgetCheckbox.luau")
local Model = require("../models/PanelModel.luau")
local MultiSelect = {}
local pageSize = 6

local function rowName(row)
    if row.label then return row.label end
    return Model.deviceLabel(row)
end

function MultiSelect.render(controller, form, rows, help, options)
    options = options or { key = "sharing", label = "Share with devices" }
    form.disclosures, form.queries, form.shareCursors = form.disclosures or {}, form.queries or {}, form.shareCursors or {}
    local key, selected, names = options.key, 0, {}
    for _, row in rows do
        if form.selected[row.id] then selected += 1; table.insert(names, rowName(row)) end
    end
    local summary = selected <= 3 and table.concat(names, ", ") or (tostring(selected) .. " selected")
    if summary == "" then summary = options.empty or (options.key == "sharing" and "Local only") or (#rows == 0 and "No available items" or "None selected") end
    local function close() form.disclosures[key] = false; controller:save() end
    local captionRow = { SharedWidgetControls.caption(options.label) }
    if options.note then table.insert(captionRow, SharedWidgetControls.caption(options.note, Palette.roles.warning)) end
    local children = {
        ui.row({ gap = 4, align = "center" }, captionRow),
        SharedWidgetControls.selectTrigger("shares-" .. key, summary, function()
            form.disclosures = { [key] = not form.disclosures[key] }
            if form.selectors then for _, item in form.selectors do item.open = false end end
            controller:save()
        end, not controller:busy(), selected == 0),
    }
    if not form.disclosures[key] then return ui.column({ gap = 4 }, children) end
    local query, available, matches, cursor = form.queries[key] or "", {}, {}, 1
    for _, row in rows do
        available[row.id] = true
        local text = rowName(row) .. "\n" .. (row.path and (row.path .. " | ") or "") .. row.id
            .. "\n" .. (row.description or "")
        if string.find(string.lower(text), string.lower(query), 1, true) then
            table.insert(matches, { row = row, text = text })
            if form.shareCursors[key] == row.id then cursor = #matches end
        end
    end
    form.shareCursors[key] = matches[cursor] and matches[cursor].row.id
    local function toggle()
        local item = matches[cursor]
        if item and not controller:busy() then
            form.selected[item.row.id] = not form.selected[item.row.id]; controller:save()
        end
    end
    controller.navigation = function(chord)
        if chord == "Alt+Left" then close(); return true end
        if chord == "Alt+Return" then toggle(); return true end
        local delta = chord == "Alt+Down" and 1 or (chord == "Alt+Up" and -1 or 0)
        if delta == 0 then return false end
        for offset = 1, #matches do
            local index = ((cursor - 1 + delta * offset) % #matches) + 1
            form.shareCursors[key] = matches[index].row.id; break
        end
        controller:save(); return true
    end
    if help then table.insert(children, SharedWidgetControls.hint(help)) end
    table.insert(children, ui.input({ key = "share-search-" .. tostring(form.token) .. "-" .. key,
        value = query, focus = true, height = Ui.control, fontSize = Ui.body, placeholder = options.placeholder or "Find a device...",
        onChange = function(text) form.queries[key], form.shareCursors[key] = text, nil; controller:save() end,
        onSubmit = toggle }))
    local first = math.max(1, math.floor((cursor - 1) / pageSize) * pageSize + 1)
    local list = {}
    for index = first, math.min(first + pageSize - 1, #matches) do
        local row = matches[index].row
        local description = row.description or (row.untrusted and "Encrypted sharing requires the Web UI")
            or (not row.path and "Will receive a folder share offer") or nil
        table.insert(list, Checkbox.render("share-" .. row.id, rowName(row), form.selected[row.id] == true, function()
            form.selected[row.id] = not form.selected[row.id]; controller:save()
        end, not controller:busy(), row.path and (row.path .. " | " .. row.id) or row.id, false, description))
    end
    if #matches == 0 then table.insert(list, SharedWidgetControls.hint(#rows == 0 and "No available items" or "No matching items")) end
    table.insert(children, ui.column({ key = "share-results-" .. key, gap = 2 }, list))
    if #matches > pageSize then
        table.insert(children, ui.row({ gap = 6, align = "center" }, {
            ui.button({ key = "Previous", glyph = "chevron-left", text = "", variant = "ghost", height = Ui.control, enabled = first > 1, tooltip = "Previous page",
                onClick = function() form.shareCursors[key] = matches[math.max(1, first - pageSize)].row.id; controller:save() end }),
            ui.label({ text = tostring(first) .. "-" .. tostring(math.min(first + pageSize - 1, #matches)) .. " of " .. tostring(#matches),
                color = "on_surface_variant", fontSize = Ui.caption, textAlign = "center", flexGrow = 1 }),
            ui.button({ key = "Next", glyph = "chevron-right", text = "", variant = "ghost", height = Ui.control, enabled = first + pageSize <= #matches, tooltip = "Next page",
                onClick = function() form.shareCursors[key] = matches[first + pageSize].row.id; controller:save() end }),
        }))
    end
    if not options.group then
        for id, checked in form.selected do
            if checked and not available[id] then
                table.insert(children, SharedWidgetControls.label("Selected item is no longer available: " .. id, "error"))
                table.insert(children, SharedWidgetControls.button("Clear unavailable selection", function()
                    form.selected[id] = nil; controller:save()
                end, not controller:busy(), "ghost", "clear-share-" .. id))
            end
        end
    end
    return SharedWidgetControls.column({ gap = 4 }, children)
end

return MultiSelect
