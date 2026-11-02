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
    local function visit(node, path, context, rowPath)
        if node.props.visible == false then return end
        if node.props.key then context = caption(node) or context end
        -- Retained native buttons do not reset an omitted selected prop.
        if node.type == "button" then node.props.selected = false end
        if (node.type == "row" or node.type == "column") and type(node.props.onClick) == "function" and not node.props.fill then node.props.fill = "#00000000" end
        -- Omarchy's cursor rows leave out the header's device ID.
        local clickableRow = (node.type == "row" or node.type == "column") and type(node.props.onClick) == "function" and node.props.key ~= "Copy ID"
        if clickableRow or (node.type == "button" and node.props.enabled ~= false and type(node.props.onClick) == "function") then
            local label = clickableRow and (caption(node) or node.props.key) or (node.props.text ~= "" and node.props.text or node.props.tooltip)
            -- A key survives the body's own key changing with the tab.
            local id = node.props.key and ("key:" .. node.props.key) or (path .. ":" .. label)
            table.insert(actions, { id = id, node = node, label = label, row = rowPath or path,
                context = context, activate = node.props.onClick })
        end
        for index, child in node.children do
            visit(child, path .. "/" .. (child.props.key or tostring(index)), context, node.type == "row" and path or rowPath)
        end
    end
    local form = view.form
    local context = view.section
    if form then
        context = form.folderId and form.folderId ~= "" and ("Folder: " .. form.folderId)
            or (form.deviceId and form.deviceId ~= "" and ("Device: " .. form.deviceId) or "Form")
    end
    visit(tree, "panel", context, nil)
    local selected
    for index, action in actions do
        if action.id == view.actionCursor then selected = index; 
            if action.node.type == "button" then action.node.props.selected = true
            else action.node.props.border, action.node.props.borderWidth = "primary", 1 end
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
        -- As Omarchy's PanelNavigation: the first press lands on the first control,
        -- rows wrap and the column is kept as far as the new row allows.
        local isMove = chord == "cursor-down" or chord == "cursor-up" or chord == "cursor-left" or chord == "cursor-right"
        if isMove then
            if #actions == 0 then return true end
            if not selected then view.actionCursor = actions[1].id; controller:save(); return true end
            local rows, rowIndex, column = {}, nil, nil
            for index, action in actions do
                if not rows[#rows] or rows[#rows][1].row ~= action.row then table.insert(rows, {}) end
                table.insert(rows[#rows], action)
                if index == selected then rowIndex, column = #rows, #rows[#rows] end
            end
            local current, right = rows[rowIndex], chord == "cursor-right"
            local target
            if chord == "cursor-down" or chord == "cursor-up" then
                local nextRow = rows[(rowIndex - 1 + (chord == "cursor-down" and 1 or -1)) % #rows + 1]
                target = nextRow[math.min(column, #nextRow)]
            elseif current[1].node.props.key == "Folders" then
                -- Omarchy's tabs are one control: left is Folders, right is Devices.
                target = current[right and 2 or 1]
                target.activate()
            else
                target = current[(column - 1 + (right and 1 or -1)) % #current + 1]
            end
            view.actionCursor = target.id; controller:save()
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
