local Controls = require("./Controls.luau")
local Model = require("../models/PanelModel.luau")
local MultiSelect = {}
local pageSize = 6

function MultiSelect.render(controller, form, rows, help, options)
    options = options or { key = "sharing", label = "Share with devices" }
    form.disclosures, form.queries, form.shareCursors = form.disclosures or {}, form.queries or {}, form.shareCursors or {}
    local key, selected, names = options.key, 0, {}
    for _, row in rows do
        if form.selected[row.id] then selected += 1; table.insert(names, row.name or row.label or row.id) end
    end
    local summary = selected <= 3 and table.concat(names, ", ") or (tostring(selected) .. " selected")
    if summary == "" then summary = #rows == 0 and "No available items" or "None selected" end
    local function close() form.disclosures[key] = false; controller:save() end
    local children = {
        Controls.button(options.label .. " | " .. summary, function()
            form.disclosures = { [key] = not form.disclosures[key] }
            if form.selectors then for _, item in form.selectors do item.open = false end end
            controller:save()
        end, not controller:busy(), "outline", "shares-" .. key),
    }
    if not form.disclosures[key] then return ui.column({ gap = 4 }, children) end
    local query, available, matches, cursor = form.queries[key] or "", {}, {}, 1
    for _, row in rows do
        available[row.id] = true
        local text = (row.name or row.label or row.id) .. "\n" .. (row.path and (row.path .. " | ") or "") .. row.id
            .. "\n" .. (row.description or (row.untrusted and "Encrypted sharing: use Web UI" or "Will receive a folder share offer"))
        if string.find(string.lower(text), string.lower(query), 1, true) then
            table.insert(matches, { row = row, text = text })
            if form.shareCursors[key] == row.id then cursor = #matches end
        end
    end
    form.shareCursors[key] = matches[cursor] and matches[cursor].row.id
    local function toggle()
        local item = matches[cursor]
        if item and not item.row.untrusted and not controller:busy() then
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
            if not matches[index].row.untrusted then form.shareCursors[key] = matches[index].row.id; break end
        end
        controller:save(); return true
    end
    table.insert(children, Controls.label(help, "on_surface_variant"))
    table.insert(children, ui.input({ key = "share-search-" .. tostring(form.token) .. "-" .. key,
        value = query, focus = true, placeholder = "Search names, paths, IDs or status",
        onChange = function(text) form.queries[key], form.shareCursors[key] = text, nil; controller:save() end,
        onSubmit = toggle }))
    local list, first = {}, cursor
    for index = first, math.min(first + pageSize - 1, #matches) do
        local row, text = matches[index].row, matches[index].text
        table.insert(list, ui.row({ key = row.id, gap = 8, align = "center", padding = 4,
            fill = index == cursor and "surface_variant" or "surface" }, {
            ui.toggle({ key = "share-" .. row.id, checked = form.selected[row.id] == true,
                enabled = not controller:busy() and not row.untrusted,
                onChange = function(value) form.selected[row.id] = Model.bool(value); controller:save() end }),
            Controls.label(text),
        }))
    end
    if #matches == 0 then table.insert(list, Controls.label(#rows == 0 and "No available items" or "No matching items")) end
    table.insert(children, ui.scroll({ key = "share-results-" .. key .. "-" .. tostring(form.shareCursors[key]), height = 260, gap = 6 }, list))
    table.insert(children, ui.row({ gap = 6 }, {
        Controls.button("Previous", function() form.shareCursors[key] = matches[math.max(1, first - pageSize)].row.id; controller:save() end, first > 1),
        Controls.button("Next", function() form.shareCursors[key] = matches[first + pageSize].row.id; controller:save() end, first + pageSize <= #matches),
        Controls.button("Back", close, true, "ghost", "back-shares-" .. key),
    }))
    if not options.group then
        for id, checked in form.selected do
            if checked and not available[id] then
                table.insert(children, Controls.label("Selected item is no longer available: " .. id, "error"))
                table.insert(children, Controls.button("Clear unavailable selection", function()
                    form.selected[id] = nil; controller:save()
                end, not controller:busy(), "ghost", "clear-share-" .. id))
            end
        end
    end
    local encrypted = false
    for _, row in rows do if row.untrusted then encrypted = true end end
    if encrypted then table.insert(children, Controls.button("Manage encrypted sharing in Web UI", function()
        controller:send("webui.open", {})
    end, not controller:busy() and (controller.snapshot.connection or {}).online)) end
    table.insert(children, Controls.label(tostring(selected) .. " selected in this group, including hidden rows", "on_surface_variant"))
    table.insert(children, Controls.label("Alt+Up/Down: select | Enter in search: toggle | Alt+Left: back", "on_surface_variant"))
    local tree = Controls.column({ gap = 6 }, children)
    controller.selectionView = { title = options.label, tree = tree, close = close }
    return tree
end

return MultiSelect
