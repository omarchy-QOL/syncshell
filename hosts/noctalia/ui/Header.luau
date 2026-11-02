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
    -- Remembered, as Omarchy keeps showing the identity while offline.
    local v = controller.view
    if identity.deviceId then
        v.knownDeviceId = identity.deviceId
        if localDevice and localDevice.name ~= "" then v.knownDeviceName = localDevice.name end
    end
    local hostname = v.knownDeviceName or "This device"
    local deviceId = v.knownDeviceId
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
                ui.label({ text = string.upper(hostname), color = "on_surface_variant", fontSize = Ui.caption, fontWeight = "bold", maxLines = 1 }),
                -- A native button drops its glyph below the text at this size.
                ui.row({ key = "Copy ID", gap = 3, align = "center", height = 16, paddingH = 4, radius = 2, border = "outline", borderWidth = 1,
                    visible = deviceId ~= nil, tooltip = "Copy device ID", onClick = function() controller:copy(deviceId, "Device ID copied") end }, {
                    ui.glyph({ name = "copy", size = Ui.caption, color = "on_surface" }),
                    ui.label({ text = "device ID", color = "on_surface", fontSize = Ui.caption - 1, maxLines = 1 }),
                }),
            }),
        }),
    }
    -- Omarchy hides the switch when the instance is not ours to control.
    if canToggle then
        table.insert(title, ui.row({ tooltip = lifecycle.active and "Stop syncing" or "Start syncing" }, {
            -- Folder actions do not block the service, as in Omarchy.
            ui.toggle({ key = "service-toggle", checked = lifecycle.active == true,
                enabled = string.sub(controller.status.busyAction or "", 1, 10) ~= "lifecycle.",
                onChange = function(value)
                    controller:send(Model.bool(value) and "lifecycle.start" or "lifecycle.stop", {})
                end }),
        }))
    end
    local children = { ui.row({ gap = 10, align = "center" }, title) }
    -- Omarchy keeps warnings, errors and notices directly under the name, above
    -- the counts; folder error details live in More.
    -- A deliberate stop reports no connection problem.
    local missing = not connection.online and (controller.status.syncthingMissing or (s.installation or {}).available == false)
    local warning
    if missing then warning = "Syncthing is not installed. Open More for installation help."
    elseif not controller.status.ready and not controller.status.error then warning = "Starting native core"
    elseif managedStop then warning = "Syncing stopped"
    elseif truncated(s.truncation) then warning = "Some Syncthing items exceed panel limits; use the Web UI for the hidden entries"
    elseif lifecycle.canControl then
        local decision = Model.driftDecision(controller.host.getConfig("serviceState"), lifecycle)
        if decision.status == "unsupported" and lifecycle.unitFileState ~= "not-found" then warning = decision.reason end
    end
    if warning then
        -- Omarchy dims the expected states and keeps warning color for real ones.
        local quiet = managedStop or warning == "Starting native core"
        table.insert(children, ui.label({ text = warning, color = quiet and "on_surface_variant" or Palette.roles.warning, fontSize = Ui.bodySmall, maxLines = 0 }))
    end
    local actionRunning = string.sub(controller.status.busyAction or "", 1, 10) == "lifecycle."
    local connectionFailure = not managedStop and not missing and not actionRunning and connection.error and connection.error.message
    local v2 = controller.view
    local actionFailure = (v2.noticeKind == "error" or v2.noticeKind == "uncertain") and v2.message ~= "" and v2.message or nil
    -- One row, in Omarchy's priority: actions, settings, then the connection.
    local failure = actionFailure or controller.status.backgroundError or (not missing and controller.status.error) or connectionFailure
    if failure then table.insert(children, SharedWidgetControls.notice(controller, failure, "error", "action details")) end
    if v2.noticeKind == "success" and v2.message ~= "" then
        table.insert(children, SharedWidgetControls.notice(controller, v2.message, Palette.roles.success, "action details"))
    end
    if not compact then
        table.insert(children, InfoPair.render("Folders", counts.folders or 0))
        table.insert(children, InfoPair.render("Devices", tostring(counts.connectedDevices or 0)
            .. " of " .. tostring(counts.devices or 0) .. " connected"))
        table.insert(children, InfoPair.render("Tracked", Model.count(total.files) .. " files · " .. Model.bytes(total.bytes)))
    end
    return ui.column({ gap = 4 }, children)
end

return Header
