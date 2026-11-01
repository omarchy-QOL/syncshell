local Model = require("./hosts/noctalia/models/PanelModel.luau")
local Palette = require("./hosts/noctalia/controllers/ThemePaletteController.luau")
local snapshot = noctalia.state.get("summary")
local status = noctalia.state.get("status") or {}

local function render()
    local state = snapshot and snapshot.generation == status.generation and snapshot.state or {}
    local variant, label = Model.indicator(state, status)
    barWidget.setImage(Palette.statusIcon(noctalia, variant), false, 20, 20)
    barWidget.setTooltip("Syncthing: " .. label .. (status.error and ("\n" .. status.error) or ""))
end

noctalia.state.watch("summary", function(value) snapshot = value; render() end)
noctalia.state.watch("status", function(value) status = value or {}; render() end)

function onClick() noctalia.togglePanel("syncshell/syncshell:panel") end
function onRightClick() noctalia.togglePanel("syncshell/syncshell:panel") end

render()
