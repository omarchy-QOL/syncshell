local SharedWidgetControls = {}

function SharedWidgetControls.label(text, color)
    text = tostring(text or "")
    local props = { text = text, color = color or "on_surface", maxLines = 0 }
    if #text <= 2048 and select(2, string.gsub(text, "\n", "")) < 80 then return ui.label(props) end
    local rows, first = {}, 1
    while first <= #text do
        local last = math.min(first + 2047, #text)
        local nextByte = string.byte(text, last + 1)
        while nextByte and nextByte >= 128 and nextByte < 192 do
            last += 1; nextByte = string.byte(text, last + 1)
        end
        local scan = first
        for line = 1, 80 do
            local newline = string.find(text, "\n", scan, true)
            if not newline or newline > last then break end
            scan = newline + 1
            if line == 80 then last = newline end
        end
        table.insert(rows, ui.label({ text = string.sub(text, first, last), color = props.color, maxLines = 0 }))
        first = last + 1
    end
    return SharedWidgetControls.column({ gap = 0 }, rows)
end

function SharedWidgetControls.notice(controller, text, color, title)
    text = tostring(text or "")
    local children = { ui.label({ text = text, color = color or "on_surface", maxLines = 3 }) }
    if #text > 180 or select(2, string.gsub(text, "\n", "")) > 2 then
        table.insert(children, SharedWidgetControls.button("Full " .. title, function()
            controller.view.details = { title = title, text = text }; controller:save()
        end, true, "ghost"))
    end
    return ui.column({ gap = 4 }, children)
end

function SharedWidgetControls.button(text, callback, enabled, variant, key, tooltip)
    return ui.button({ text = text, onClick = callback, enabled = enabled ~= false,
        variant = variant or "default", controlSize = "sm", key = key, tooltip = tooltip })
end

function SharedWidgetControls.field(controller, form, key, label, options)
    options = options or {}
    return ui.column({ gap = 4 }, {
        SharedWidgetControls.label(label, "on_surface_variant"),
        ui.input({ key = "form-" .. tostring(form.token) .. "-" .. key .. "-" .. tostring(options.revision or 0),
            value = form[key] or "", placeholder = options.placeholder or "", focus = options.focus == true,
            enabled = options.enabled ~= false and not controller:busy(),
            onChange = function(value) form[key] = value; controller:save() end,
            onSubmit = options.onSubmit }),
    })
end

function SharedWidgetControls.formHeader(controller, title)
    return ui.row({ gap = 8, align = "center" }, {
        SharedWidgetControls.button(controller.view.form and controller.view.form.returnForm and "Back" or "Cancel", function() controller:cancel() end, not controller:busy(), "ghost"),
        SharedWidgetControls.label(title),
    })
end

-- Native trees accept at most 256 children per node.
function SharedWidgetControls.column(props, children)
    if #children <= 256 then return ui.column(props, children) end
    local groups = {}
    for first = 1, #children, 128 do
        local rows = {}
        for index = first, math.min(first + 127, #children) do table.insert(rows, children[index]) end
        table.insert(groups, ui.column({ gap = props.gap }, rows))
    end
    return ui.column(props, groups)
end

return SharedWidgetControls
