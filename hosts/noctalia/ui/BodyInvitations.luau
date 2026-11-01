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
        local short = Model.shortDeviceId(device.id)
        local name = device.name ~= nil and device.name ~= "" and device.name or short
        table.insert(rows, { id = device.id, device = device, confirmName = name,
            label = name .. " (" .. short .. ") wants to connect",
            help = "Remote device " .. name .. " attempted to connect." })
    end
    return rows
end

-- Omarchy leaves encrypted offers to the Web UI and counts them in the add form.
local function folderRows(snapshot)
    local ids, rows = {}, {}
    for id in snapshot.pendingFolders or {} do table.insert(ids, id) end
    table.sort(ids)
    for _, id in ids do
        local offeredBy, encrypted = snapshot.pendingFolders[id].offeredBy or {}, false
        local devices = {}
        for deviceId, offer in offeredBy do
            table.insert(devices, deviceId)
            encrypted = encrypted or offer.receiveEncrypted == true or offer.remoteEncrypted == true
        end
        if not encrypted then
            table.sort(devices)
            for _, deviceId in devices do
                local offer, device = offeredBy[deviceId], Model.find(snapshot.devices, deviceId)
                local label = offer.label ~= nil and offer.label ~= "" and offer.label or id
                local trailing = "(by " .. (device and Model.deviceLabel(device) or "Unknown device") .. ")"
                table.insert(rows, { id = id .. "\n" .. deviceId, folderId = id, deviceId = deviceId, offer = offer, label = label, trailing = trailing,
                    confirmName = label .. " " .. trailing })
            end
        end
    end
    return rows
end

function BodyInvitations.render(controller)
    local snapshot, v = controller.snapshot, controller.view
    local connection = snapshot.connection or {}
    local busy = controller:busy()
    local devices = v.section == "devices"
    local rows = devices and deviceRows(snapshot) or folderRows(snapshot)
    if #rows == 0 then return nil end
    v.invitationSelected = v.invitationSelected or {}
    local selected = rows[1]
    for _, row in rows do if row.id == v.invitationSelected[v.section] then selected = row end end
    return ui.column({ key = "invitations-" .. v.section, gap = 6 }, {
        SharedWidgetControls.caption(devices and "PENDING DEVICE REQUESTS" or "PENDING FOLDER REQUESTS"),
        ui.row({ gap = 6, align = "start" }, {
            ui.column({ flexGrow = 1, minWidth = 0 }, {
                Dropdown.render(controller, v, "invitation-" .. v.section, "Pending request", rows, selected.id,
                    function(id) v.invitationSelected[v.section] = id end, { placeholder = "Find a request...", help = selected.help }),
            }),
            ActionButton.render("Accept", "check", function()
                if devices then controller:openForm("acceptDevice", selected.device)
                else controller:openForm("acceptFolder", { id = selected.folderId, deviceId = selected.deviceId, label = selected.offer.label ~= "" and selected.offer.label or selected.folderId }) end
            end, not busy and (devices or connection.online == true), nil, devices and "Accept remote device connection" or "Accept folder request", nil, Palette.roles.success),
            ActionButton.render("Dismiss", "x", function()
                if devices then
                    controller:confirm("Dismiss pending request from " .. selected.confirmName .. "?\n\nIt can reappear if the device connects again.",
                        "device.dismiss-pending", { deviceId = selected.id })
                else
                    controller:confirm("Reject folder request for " .. selected.confirmName .. "?\n\nThis removes the pending announcement without adding the folder.",
                        "folder.dismiss-pending", { folderId = selected.folderId, pendingDeviceId = selected.deviceId })
                end
            end, not busy and (devices or connection.online == true), nil, devices and "Dismiss incoming device request" or "Reject folder request", nil, "error"),
        }),
    })
end

return BodyInvitations
