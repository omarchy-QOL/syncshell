local Ui = require("./UiConstants.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local BusyIcon = {}

-- Omarchy's busy animations. The host cannot rotate a node, so spinning steps
-- through rotated copies of the icon, one turn per 900 ms.
local frames = 16
local turnMs, pulseMs, pulseScale = 900, 375, 0.18

function BusyIcon.spin(controller, shape, role, fallback, size)
    size = size or Ui.body
    local index = math.floor(controller.host.nowMs() / (turnMs / frames)) % frames
    local path = Palette.spinFrame(controller.host, shape, role, index, frames)
    if path then return ui.image({ path = path, width = size, height = size }) end
    return ui.glyph({ name = fallback, size = size, color = role })
end

-- A fixed cell keeps the label still while the glyph grows.
function BusyIcon.pulse(controller, glyph, role, size)
    size = size or Ui.body
    local t = controller.host.nowMs() % (pulseMs * 2)
    local eased = t < pulseMs and 1 - (1 - t / pulseMs) ^ 3 or 1 - ((t - pulseMs) / pulseMs) ^ 3
    local cell = math.ceil(size * (1 + pulseScale))
    return ui.row({ width = cell, height = cell, align = "center", justify = "center" }, {
        ui.glyph({ name = glyph, size = size * (1 + pulseScale * eased), color = role }),
    })
end

return BusyIcon
