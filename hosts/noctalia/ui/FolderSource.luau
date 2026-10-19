local Controls = require("./Controls.luau")
local Model = require("../models/PanelModel.luau")
local Dropdown = require("./SyncshellDropdown.luau")
local Source = {}

function Source.render(controller, form)
    local rows = { { id = "", label = "New folder identity", description = "Create a folder or enter an existing folder ID" } }
    local offers, encrypted = {}, 0
    for id, pending in controller.snapshot.pendingFolders or {} do
        for deviceId, offer in pending.offeredBy or {} do
            if offer.receiveEncrypted or offer.remoteEncrypted then encrypted += 1
            else
                local key = controller.host.json.encode({ id, deviceId })
                local device = Model.find(controller.snapshot.devices, deviceId)
                offers[key] = { id = id, deviceId = deviceId, label = offer.label or id }
                table.insert(rows, { id = key, label = offer.label ~= "" and offer.label or id,
                    description = id .. " | Offered by " .. (device and device.name or deviceId) .. " | " .. deviceId })
            end
        end
    end
    table.sort(rows, function(a, b) if a.id == "" or b.id == "" then return a.id == "" and b.id ~= "" end; return a.id < b.id end)
    local selected = form.pendingDeviceId and controller.host.json.encode({ form.folderId, form.pendingDeviceId }) or ""
    local children = {}
    if form.kind == "addFolder" then
        table.insert(children, Dropdown.render(controller, form, "folder-source", "Folder source", rows, selected, function(key)
            local offer = offers[key]
            form.selected = {}
            form.pendingDeviceId = offer and offer.deviceId or nil
            form.folderId, form.label = offer and offer.id or "", offer and offer.label or ""
            form.idRevision, form.labelRevision = (form.idRevision or 0) + 1, (form.labelRevision or 0) + 1
            if offer then form.selected[offer.deviceId] = true else controller:send("folder.suggest-id", {}) end
        end))
    end
    if form.pendingDeviceId then
        table.insert(children, Controls.label("Accepting " .. form.folderId .. " from " .. form.pendingDeviceId))
    end
    if encrypted > 0 then
        table.insert(children, Controls.label(tostring(encrypted) .. " encrypted folder offers require the Web UI", "on_surface_variant"))
        table.insert(children, Controls.button("Open encrypted offers in Web UI", function() controller:send("webui.open", {}) end,
            not controller:busy() and (controller.snapshot.connection or {}).online))
    end
    return ui.column({ gap = 6 }, children)
end

return Source
