local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local IdCopyButton = {}

function IdCopyButton.render(controller, value, key, help)
    return ActionButton.render(key, "copy", function()
        controller:copy(value)
    end, value ~= nil and value ~= "", nil, help, 26)
end

return IdCopyButton
