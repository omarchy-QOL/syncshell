local Model = require("./models/PanelModel.luau")
local snapshot = noctalia.state.get("summary")
local status = noctalia.state.get("status") or {}

local function render()
    local state = snapshot and snapshot.generation == status.generation and snapshot.state or {}
    local counts = state.counts or {}
    local variant, label = Model.indicator(state, status)
    local icon = "status-" .. variant .. ".svg"
    local prefix = noctalia.getConfig("brandedIcon") and "/assets/" or "/assets/mono/"
    barWidget.setImage(noctalia.pluginDir() .. prefix .. icon, false, 20, 20)
    barWidget.setTooltip("Syncthing | " .. label .. " | " .. tostring(counts.folders or 0) .. " folders | "
        .. tostring(counts.connectedDevices or 0) .. " devices connected"
        .. (status.error and ("\n" .. status.error) or ""))
end

noctalia.state.watch("summary", function(value) snapshot = value; render() end)
noctalia.state.watch("status", function(value) status = value or {}; render() end)

function onClick() noctalia.togglePanel("syncshell/syncshell:panel") end
function onRightClick() noctalia.togglePanel("syncshell/syncshell:panel") end

render()
