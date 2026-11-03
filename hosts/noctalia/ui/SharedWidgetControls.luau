local Ui = require("./UiConstants.luau")
local SharedWidgetControls = {}

function SharedWidgetControls.label(text, color)
    text = tostring(text or "")
    local props = { text = text, color = color or "on_surface", fontSize = Ui.bodySmall, maxLines = 0 }
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
        table.insert(rows, ui.label({ text = string.sub(text, first, last), color = props.color, fontSize = Ui.bodySmall, maxLines = 0 }))
        first = last + 1
    end
    return SharedWidgetControls.column({ gap = 0 }, rows)
end

function SharedWidgetControls.notice(controller, text, color, title)
    text = tostring(text or "")
    local children = { ui.label({ text = text, color = color or "on_surface", fontSize = Ui.bodySmall, maxLines = 3 }) }
    if #text > 180 or select(2, string.gsub(text, "\n", "")) > 2 then
        table.insert(children, SharedWidgetControls.button("Full " .. title, function()
            controller.view.details = { title = title, text = text }; controller:save()
        end, true, "ghost"))
    end
    return ui.column({ gap = 4 }, children)
end

-- The host's separator fades at both ends; Omarchy's is a solid line.
function SharedWidgetControls.separator()
    return ui.row({ height = 1, fill = "outline" }, {})
end

function SharedWidgetControls.button(text, callback, enabled, variant, key, tooltip)
    return ui.button({ text = text, onClick = callback, enabled = enabled ~= false,
        variant = variant or "default", height = Ui.control, fontSize = Ui.body, key = key, tooltip = tooltip })
end

function SharedWidgetControls.caption(text, color)
    return ui.label({ text = text, color = color or "on_surface_variant", fontSize = Ui.caption, fontWeight = "bold", maxLines = 1 })
end

function SharedWidgetControls.hint(text, color)
    return ui.label({ text = text, color = color or "on_surface_variant", fontSize = Ui.caption, maxLines = 0 })
end

-- A native button has one glyph on its left; Omarchy's selector chevron sits right.
function SharedWidgetControls.selectTrigger(key, text, callback, enabled, muted, help, trailing)
    local cells = { ui.label({ text = text, color = muted and "on_surface_variant" or "on_surface", fontSize = Ui.body, maxLines = 1, flexGrow = 1 }) }
    if trailing then table.insert(cells, ui.label({ text = trailing, color = "on_surface_variant", fontSize = Ui.caption, maxLines = 1 })) end
    -- Omarchy dims a row's chevron further when it also has trailing text.
    table.insert(cells, ui.glyph({ name = "chevron-down", size = Ui.bodySmall, color = trailing and "on_surface_variant/0.7" or "on_surface/0.8" }))
    return ui.row({ key = key, gap = 8, align = "center", height = Ui.control, paddingH = 10, radius = 4, border = "outline",
        borderWidth = 1, fill = "on_surface/0.05", flexGrow = 1, minWidth = 0, tooltip = help, onClick = enabled ~= false and callback or nil, opacity = enabled ~= false and 1 or 0.5 }, cells)
end

function SharedWidgetControls.chip(key, glyph, text, callback, enabled, help)
    return ui.row({ key = key, gap = 6, align = "center", height = Ui.cardControl, paddingH = 6, radius = 0, border = "outline", borderWidth = 1,
        minWidth = 0, tooltip = help, onClick = enabled ~= false and callback or nil }, {
        ui.glyph({ name = glyph, size = Ui.body, color = "on_surface" }),
        -- Leaves room for the copy button and state badge beside a long name.
        ui.label({ text = text, fontSize = Ui.body, maxLines = 1, maxWidth = 205 }),
    })
end

-- Native button colors come from the variant; Omarchy tints the outline and text.
function SharedWidgetControls.tinted(key, text, glyph, color, callback, enabled, help, height)
    enabled = enabled ~= false
    local children = {}
    if glyph then table.insert(children, ui.glyph({ name = glyph, size = 12, color = color })) end
    table.insert(children, ui.label({ text = text, color = color, fontSize = Ui.body, maxLines = 1 }))
    return ui.row({ key = key, gap = 4, align = "center", height = height or Ui.cardControl, paddingH = glyph and 12 or 6, radius = 6, border = "outline", borderWidth = 1,
        tooltip = help, opacity = enabled and 1 or 0.5, onClick = enabled and callback or nil }, children)
end

function SharedWidgetControls.badge(key, text, color)
    return ui.row({ key = key, align = "center", height = Ui.cardControl, paddingH = 6, radius = 0, border = "outline", borderWidth = 1 }, {
        ui.label({ text = text, color = color, fontSize = Ui.caption, fontWeight = "bold", maxLines = 1 }),
    })
end

function SharedWidgetControls.field(controller, form, key, label, options)
    options = options or {}
    local input = ui.input({ key = "form-" .. tostring(form.token) .. "-" .. key .. "-" .. tostring(options.revision or 0),
        value = form[key] or "", placeholder = options.placeholder or "", focus = options.focus == true, height = Ui.field, fontSize = Ui.body,
        enabled = options.enabled ~= false and not controller:busy(), flexGrow = options.trailing and 1 or nil,
        onChange = function(value)
            form[key] = value
            if options.onEdited then options.onEdited() end
            controller:save()
        end,
        onSubmit = options.onSubmit })
    return ui.column({ gap = 4 }, {
        SharedWidgetControls.caption(label),
        options.trailing and ui.row({ gap = 6, align = "center" }, { input, options.trailing }) or input,
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
