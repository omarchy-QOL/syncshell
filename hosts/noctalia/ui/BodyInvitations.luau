local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyInvitations = {}

function BodyInvitations.render(controller)
    local children, rows = {}, {}
    local connection = controller.snapshot.connection or {}
    local enabled = not controller:busy() and connection.online == true and connection.fresh == true
    for _, device in controller.snapshot.pendingDevices or {} do table.insert(rows, { device = device }) end
    local ids = {}
    for id in controller.snapshot.pendingFolders or {} do table.insert(ids, id) end
    table.sort(ids)
    for _, id in ids do
        local pending = controller.snapshot.pendingFolders[id]
        local devices = {}
        for deviceId in pending.offeredBy do table.insert(devices, deviceId) end
        table.sort(devices)
        for _, deviceId in devices do table.insert(rows, { id = id, deviceId = deviceId, offer = pending.offeredBy[deviceId] }) end
    end
    if #rows == 0 then return ui.column({}) end
    local v = controller.view
    v.invitationPage = math.clamp(v.invitationPage or 1, 1, math.ceil(#rows / 6))
    local first = (v.invitationPage - 1) * 6 + 1
    table.insert(children, SharedWidgetControls.label(tostring(#rows) .. " invitations | Page " .. tostring(v.invitationPage)))
    for index = first, math.min(first + 5, #rows) do
        local item = rows[index]
        if item.device then
            local device = item.device
            table.insert(children, ui.column({ key = "pending-device-" .. device.id, gap = 6 }, {
                SharedWidgetControls.label("Device invitation: " .. (device.name or device.id) .. "\n" .. device.id),
                ui.row({ gap = 6 }, {
                    SharedWidgetControls.button("Accept", function() controller:openForm("acceptDevice", device) end, enabled),
                    SharedWidgetControls.button("Dismiss", function()
                        controller:confirm("Dismiss the invitation from " .. (device.name or device.id) .. "? It may reappear if the device reconnects.",
                            "device.dismiss-pending", { deviceId = device.id })
                    end, enabled),
                }),
            }))
        else
            local id, deviceId, offer = item.id, item.deviceId, item.offer
            local encrypted = offer.receiveEncrypted or offer.remoteEncrypted
            table.insert(children, ui.column({ key = "offer-" .. id .. "-" .. deviceId, gap = 6 }, {
                SharedWidgetControls.label("Folder invitation: " .. offer.label .. " | " .. id .. "\nFrom " .. deviceId),
                ui.row({ gap = 6 }, {
                    SharedWidgetControls.button(encrypted and "Encrypted: open Web UI" or "Accept", function()
                        if encrypted then controller:send("webui.open", {})
                        else controller:openForm("acceptFolder", { id = id, deviceId = deviceId, label = offer.label }) end
                    end, enabled),
                    SharedWidgetControls.button("Dismiss", function()
                        controller:confirm("Reject the folder invitation for " .. id .. " from " .. deviceId .. "?",
                            "folder.dismiss-pending", { folderId = id, pendingDeviceId = deviceId })
                    end, enabled),
                }),
            }))
        end
    end
    if #rows > 6 then
        table.insert(children, ui.row({ gap = 6 }, {
            SharedWidgetControls.button("Previous invitations", function() v.invitationPage -= 1; controller:save() end, v.invitationPage > 1),
            SharedWidgetControls.button("Next invitations", function() v.invitationPage += 1; controller:save() end, first + 6 <= #rows),
        }))
    end
    return ui.column({ gap = 10 }, children)
end

return BodyInvitations
