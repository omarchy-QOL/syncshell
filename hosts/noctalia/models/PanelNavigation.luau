local Navigation = {}

-- Omarchy marks its keyboard cursor on the control itself, without a caption.
local function caption(node)
    for _, child in node.children do
        if child.type == "label" and child.props.text ~= "" then return child.props.text end
        if child.type == "row" then
            local text = caption(child)
            if text then return text end
        end
    end
    return nil
end

function Navigation.decorate(controller, tree)
    local actions, view = {}, controller.view
    local function visit(node, path, context)
        if node.props.visible == false then return end
        if node.props.key then context = caption(node) or context end
        -- Retained native buttons do not reset an omitted selected prop.
        if node.type == "button" then node.props.selected = false end
        if (node.type == "row" or node.type == "column") and type(node.props.onClick) == "function" and not node.props.fill then node.props.fill = "#00000000" end
        local clickableRow = (node.type == "row" or node.type == "column") and type(node.props.onClick) == "function"
        if clickableRow or (node.type == "button" and node.props.enabled ~= false and type(node.props.onClick) == "function") then
            local label = clickableRow and (caption(node) or node.props.key) or (node.props.text ~= "" and node.props.text or node.props.tooltip)
            local id = path .. ":" .. label
            table.insert(actions, { id = id, node = node, label = label,
                context = context, activate = node.props.onClick })
        end
        for index, child in node.children do
            visit(child, path .. "/" .. (child.props.key or tostring(index)), context)
        end
    end
    local form = view.form
    local context = view.section
    if form then
        context = form.folderId and form.folderId ~= "" and ("Folder: " .. form.folderId)
            or (form.deviceId and form.deviceId ~= "" and ("Device: " .. form.deviceId) or "Form")
    end
    visit(tree, "panel", context)
    local selected
    for index, action in actions do
        if action.id == view.actionCursor then selected = index; 
            if action.node.type == "button" then action.node.props.selected = true else action.node.props.fill = "surface_variant" end
        end
    end
    controller.actionNavigation = function(chord)
        if chord == "Alt+Return" then
            if selected then
                view.actionCursor = nil
                actions[selected].activate()
            end
            return true
        end
        local delta = chord == "Alt+Down" and 1 or (chord == "Alt+Up" and -1 or 0)
        if delta == 0 then return false end
        if #actions > 0 then
            local index = selected and ((selected - 1 + delta) % #actions + 1) or (delta == 1 and 1 or #actions)
            view.actionCursor = actions[index].id; controller:save()
        end
        return true
    end
end

return Navigation
