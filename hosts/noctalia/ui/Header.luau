local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local InfoPair = require("./SharedWidgetInfoPair.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local Header = {}

local function truncated(values)
    for _, key in { "devices", "folders", "folderDevices", "pendingFolders", "pendingOffers", "pendingDevices", "nearbyDevices" } do
        if ((values or {})[key] or 0) > 0 then return true end
    end
    return false
end

function Header.render(controller, compact)
    local s = controller.snapshot
    local identity, lifecycle, counts = s.identity or {}, s.lifecycle or {}, s.counts or {}
    local localDevice = Model.find(s.devices, identity.deviceId)
    local hostname = localDevice and localDevice.name or "This device"
    local connection = s.connection or {}
    local total = Model.totals(s)
    local variant = Model.indicator(s, controller.status)
    local canToggle = Model.lifecycleAvailable(lifecycle)
    local managedStop = canToggle and lifecycle.active ~= true
    local title = {
        ui.image({ path = Palette.statusIcon(controller.host, variant), width = Ui.heroIcon, height = Ui.heroIcon,
            opacity = (connection.online and not managedStop) and 1 or 0.5 }),
        ui.column({ gap = 2, flexGrow = 1, minWidth = 0 }, {
            ui.label({ text = "Syncthing", fontSize = Ui.title, fontWeight = "bold", maxLines = 1 }),
            ui.row({ gap = 6, align = "center" }, {
                ui.label({ text = string.upper(hostname), color = "on_surface_variant", fontSize = Ui.caption, maxLines = 1 }),
                -- A native button drops its glyph below the text at this size.
                ui.row({ key = "Copy ID", gap = 3, align = "center", height = 16, paddingH = 4, radius = 2, border = "outline", borderWidth = 1,
                    tooltip = "Copy device ID", onClick = identity.deviceId and function() controller:copy(identity.deviceId, "ID copied") end or nil }, {
                    ui.glyph({ name = "copy", size = Ui.caption, color = "on_surface_variant" }),
                    ui.label({ text = "device ID", color = "on_surface_variant", fontSize = Ui.caption - 1, maxLines = 1 }),
                }),
            }),
        }),
    }
    -- Omarchy hides the switch when the instance is not ours to control.
    if canToggle then
        table.insert(title, ui.row({ tooltip = lifecycle.active and "Stop syncing" or "Start syncing" }, {
            ui.toggle({ key = "service-toggle", checked = lifecycle.active == true, enabled = not controller:busy(),
                onChange = function(value)
                    controller:send(Model.bool(value) and "lifecycle.start" or "lifecycle.stop", {})
                end }),
        }))
    end
    local children = {
        ui.row({ gap = 10, align = "center" }, title),
    }
    if not compact then
        table.insert(children, InfoPair.render("Folders", counts.folders or 0))
        table.insert(children, InfoPair.render("Devices", tostring(counts.connectedDevices or 0)
            .. " of " .. tostring(counts.devices or 0) .. " connected"))
        table.insert(children, InfoPair.render("Tracked", Model.count(total.files) .. " files · " .. Model.bytes(total.bytes)))
    end
    if controller.status.backgroundError then
        table.insert(children, SharedWidgetControls.notice(controller, controller.status.backgroundError, "error", "background action details"))
    end
    -- Omarchy's warning and error rows; a deliberate stop reports no connection problem.
    local missing = (s.installation or {}).available == false and not connection.online
    local warning
    if missing then warning = "Syncthing is not installed. Open More for installation help."
    elseif managedStop then warning = "Syncing stopped"
    elseif truncated(s.truncation) then warning = "Some Syncthing items exceed panel limits; use the Web UI for the hidden entries"
    elseif lifecycle.canControl then
        local decision = Model.driftDecision(controller.host.getConfig("serviceState"), lifecycle)
        if decision.status == "unsupported" and lifecycle.unitFileState ~= "not-found" then warning = decision.reason end
    end
    if warning then table.insert(children, SharedWidgetControls.hint(warning, Palette.roles.warning)) end
    local failure = controller.status.error or (not managedStop and not missing and connection.error and connection.error.message) or lifecycle.error
    if failure then table.insert(children, SharedWidgetControls.notice(controller, failure, "error", "connection details")) end
    return ui.column({ gap = 4 }, children)
end

return Header
