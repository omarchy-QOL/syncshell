local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Dropdown = require("./SharedWidgetDropdown.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
-- Both tabs use Omarchy's pending request row: selector, accept, reject.
local BodyInvitations = {}

local function deviceRows(snapshot)
    local rows = {}
    for _, device in snapshot.pendingDevices or {} do
        table.insert(rows, { id = device.id, device = device, label = device.name ~= "" and device.name or string.sub(device.id, 1, 7),
            description = "Remote device " .. (device.name ~= "" and device.name or device.id) .. " attempted to connect." })
    end
    return rows
end

local function folderRows(snapshot)
    local ids, rows = {}, {}
    for id in snapshot.pendingFolders or {} do table.insert(ids, id) end
    table.sort(ids)
    for _, id in ids do
        local pending = snapshot.pendingFolders[id]
        local devices = {}
        for deviceId in pending.offeredBy do table.insert(devices, deviceId) end
        table.sort(devices)
        for _, deviceId in devices do
            local offer, device = pending.offeredBy[deviceId], Model.find(snapshot.devices, deviceId)
            local peer = device and device.name ~= "" and device.name or string.sub(deviceId, 1, 7)
            table.insert(rows, { id = id .. "\n" .. deviceId, folderId = id, deviceId = deviceId, offer = offer,
                name = (offer.label ~= "" and offer.label or id) .. " (by " .. peer .. ")",
                label = (offer.label ~= "" and offer.label or id) .. " (by " .. peer .. ")",
                description = id .. " | " .. deviceId })
        end
    end
    return rows
end

function BodyInvitations.render(controller)
    local snapshot, v = controller.snapshot, controller.view
    local connection = snapshot.connection or {}
    local enabled = not controller:busy() and connection.online == true and connection.fresh == true
    local devices = v.section == "devices"
    local rows = devices and deviceRows(snapshot) or folderRows(snapshot)
    if #rows == 0 then return nil end
    v.invitationSelected = v.invitationSelected or {}
    local selected = rows[1]
    for _, row in rows do if row.id == v.invitationSelected[v.section] then selected = row end end
    local encrypted = selected.offer and (selected.offer.receiveEncrypted or selected.offer.remoteEncrypted)
    return ui.column({ key = "invitations-" .. v.section, gap = 6 }, {
        SharedWidgetControls.caption(devices and "PENDING DEVICE REQUESTS" or "PENDING FOLDER REQUESTS"),
        ui.row({ gap = 6, align = "start" }, {
            ui.column({ flexGrow = 1, minWidth = 0 }, {
                Dropdown.render(controller, v, "invitation-" .. v.section, "Pending request", rows, selected.id,
                    function(id) v.invitationSelected[v.section] = id end, { placeholder = "Find a request..." }),
            }),
            ActionButton.render("Accept", "check", function()
                if devices then controller:openForm("acceptDevice", selected.device)
                elseif encrypted then controller:send("webui.open", {})
                else controller:openForm("acceptFolder", { id = selected.folderId, deviceId = selected.deviceId, label = selected.offer.label }) end
            end, enabled, nil, devices and "Accept remote device connection"
                or (encrypted and "Encrypted: open the Syncthing Web UI" or "Accept folder request"), nil, Palette.roles.success),
            ActionButton.render("Dismiss", "x", function()
                if devices then
                    controller:confirm("Dismiss pending request from " .. selected.label .. "?\n\nIt can reappear if the device connects again.",
                        "device.dismiss-pending", { deviceId = selected.id })
                else
                    controller:confirm("Reject folder request for " .. selected.label .. "?\n\nThis removes the pending announcement without adding the folder.",
                        "folder.dismiss-pending", { folderId = selected.folderId, pendingDeviceId = selected.deviceId })
                end
            end, enabled, nil, devices and "Dismiss incoming device request" or "Reject folder request", nil, "error"),
        }),
    })
end

return BodyInvitations
