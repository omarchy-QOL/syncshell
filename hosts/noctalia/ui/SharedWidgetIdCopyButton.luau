local Ui = require("./UiConstants.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local IdCopyButton = {}

function IdCopyButton.render(controller, value, key, help, notice)
    return ActionButton.render(key, "copy", function()
        controller:copy(value, notice or "ID copied")
    end, value ~= nil and value ~= "", nil, help, Ui.cardControl)
end

return IdCopyButton
