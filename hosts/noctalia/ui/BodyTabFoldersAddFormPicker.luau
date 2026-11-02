local Ui = require("./UiConstants.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Form = require("../models/FormModel.luau")
local Model = require("../models/PanelModel.luau")
local Picker = {}
local pageSize = 8

function Picker.open(controller, path, after, history)
    local form = controller.view.form
    if not form then return end
    local previous = form.picker
    if not history then
        history = previous and table.clone(previous.history) or {}
        if previous then table.insert(history, { path = previous.path, after = previous.after }) end
    end
    path = controller.host.expandPath(Form.trim(path))
    local picker = { path = path, location = path, after = after or "", history = history,
        loading = true, entries = {}, cursor = 1 }
    form.picker = picker
    if string.sub(path, 1, 1) ~= "/" or string.find(path, "%z") then
        picker.loading, picker.error = false, "Enter an absolute directory path"
        controller:save(); return
    end
    controller:save()
    local launched = controller.host.runAsync({ controller.host.pluginDir() .. "/bin/syncshell-core",
        "native-browse", path, picker.after }, function(reply)
        if controller.view.form ~= form or form.picker ~= picker then return end
        picker.loading = false
        local data = reply.exitCode == 0 and controller.host.json.decode(reply.stdout)
        if not data or reply.stdoutTruncated or reply.timedOut then
            picker.error = "Cannot browse this directory. Check the path and permissions, or enter another location."
        else
            picker.path, picker.location, picker.parent = data.path, data.path, data.parent
            picker.entries, picker.next = data.entries or {}, data.next
        end
        controller:save()
    end)
    if not launched then picker.loading = false; picker.error = "Could not start directory browsing"; controller:save() end
end

function Picker.back(controller, picker)
    local history = table.clone(picker.history)
    local previous = table.remove(history)
    if previous then Picker.open(controller, previous.path, previous.after, history) end
end

function Picker.render(controller, form)
    local p = form.picker
    local function go() if not p.loading then Picker.open(controller, p.location) end end
    local function enter()
        local entry = p.entries[p.cursor]
        if entry and not p.loading then Picker.open(controller, entry.path) end
    end
    controller.navigation = function(chord)
        if chord == "Alt+Left" then
            if #p.history > 0 then Picker.back(controller, p) else controller:cancel() end
        elseif chord == "Alt+Return" then enter()
        elseif chord == "Alt+Up" or chord == "Alt+Down" then
            if #p.entries > 0 then
                p.cursor = ((p.cursor - 1 + (chord == "Alt+Down" and 1 or -1)) % #p.entries) + 1
                controller:save()
            end
        else return false end
        return true
    end
    local children = { BodyFormHeader.render(controller, "CHOOSE DIRECTORY"),
        SharedWidgetControls.caption("Location"),
        ui.input({ key = "picker-location-" .. p.path .. "-" .. p.after, value = p.location, focus = true, height = Ui.control, fontSize = Ui.body,
            enabled = not p.loading, onChange = function(value) p.location = value; controller:save() end, onSubmit = go }),
        ui.row({ gap = 6 }, {
            SharedWidgetControls.button("Go", go, not p.loading),
            SharedWidgetControls.button("Back", function() Picker.back(controller, p) end, #p.history > 0, "ghost", "picker-back"),
            SharedWidgetControls.button("Parent directory", function() Picker.open(controller, p.parent) end,
                not p.loading and p.parent ~= nil and p.parent ~= p.path),
        }),
        SharedWidgetControls.hint(Model.shortPath(p.path)),
    }
    if p.loading then table.insert(children, SharedWidgetControls.label("Reading directories...")) end
    if p.error then table.insert(children, SharedWidgetControls.label(p.error, "error")) end
    local list, first = {}, p.cursor
    for index = first, math.min(first + pageSize - 1, #p.entries) do
        local entry = p.entries[index]
        table.insert(list, ui.button({ key = entry.path, text = entry.name, glyph = "folder", glyphSize = Ui.body, fontSize = Ui.body, contentAlign = "start", height = Ui.control,
            variant = index == p.cursor and "default" or "ghost", enabled = not p.loading, onClick = function() Picker.open(controller, entry.path) end }))
    end
    if not p.loading and not p.error and #p.entries == 0 then table.insert(list, SharedWidgetControls.label("No subdirectories")) end
    -- Paged, not scrolled: a scroll area inside the form's own collapses to nothing.
    table.insert(children, ui.column({ key = "directories-" .. tostring(p.cursor), gap = 2 }, list))
    table.insert(children, ui.row({ gap = 6 }, {
        SharedWidgetControls.button("Previous rows", function() p.cursor = math.max(1, first - pageSize); controller:save() end, first > 1),
        SharedWidgetControls.button("Next rows", function() p.cursor = first + pageSize; controller:save() end, first + pageSize <= #p.entries),
    }))
    if p.next and p.next ~= "" then table.insert(children, SharedWidgetControls.button("Next directory page", function()
        Picker.open(controller, p.path, p.next)
    end, not p.loading)) end
    table.insert(children, SharedWidgetControls.button("USE THIS DIRECTORY", function()
        form.path, form.pathRevision, form.picker = p.path, (form.pathRevision or 0) + 1, nil
        controller:save()
    end, not p.loading and not p.error, "outline", "Use this directory"))
    return ui.column({ gap = 8 }, children)
end

return Picker
