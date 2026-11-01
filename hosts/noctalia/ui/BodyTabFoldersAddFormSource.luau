local Palette = require("../controllers/ThemePaletteController.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Dropdown = require("./SharedWidgetDropdown.luau")
local Source = {}

function Source.render(controller, form)
    local rows = { { id = "", label = "Create a new folder identity", description = "Create a folder or enter an existing folder ID" } }
    local offers, encrypted = {}, 0
    for id, pending in controller.snapshot.pendingFolders or {} do
        local isEncrypted = false
        for _, offer in pending.offeredBy or {} do
            isEncrypted = isEncrypted or offer.receiveEncrypted == true or offer.remoteEncrypted == true
        end
        if isEncrypted then encrypted += 1 end
        for deviceId, offer in pending.offeredBy or {} do
            if isEncrypted then -- counted once below
            else
                local key = controller.host.json.encode({ id, deviceId })
                local device = Model.find(controller.snapshot.devices, deviceId)
                offers[key] = { id = id, deviceId = deviceId, label = offer.label or id }
                table.insert(rows, { id = key, label = (offer.label ~= "" and offer.label or id) .. " (by " .. (device and Model.deviceLabel(device) or "Unknown device") .. ")",
                    description = id .. " | Offered by " .. (device and device.name or deviceId) .. " | " .. deviceId })
            end
        end
    end
    table.sort(rows, function(a, b) if a.id == "" or b.id == "" then return a.id == "" and b.id ~= "" end; return a.id < b.id end)
    local selected = form.pendingDeviceId and controller.host.json.encode({ form.folderId, form.pendingDeviceId }) or ""
    local children = {}
    -- Omarchy offers the source only when an invitation exists.
    if form.kind == "addFolder" and #rows > 1 then
        table.insert(children, Dropdown.render(controller, form, "folder-source", "Folder source", rows, selected, function(key)
            local offer = offers[key]
            form.selected = {}
            form.pendingDeviceId = offer and offer.deviceId or nil
            form.folderId, form.label = offer and offer.id or "", offer and offer.label or (form.labelFromOffer and "" or form.label)
            form.labelFromOffer = offer ~= nil
            form.idRevision, form.labelRevision = (form.idRevision or 0) + 1, (form.labelRevision or 0) + 1
            if offer then form.selected[offer.deviceId] = true else controller:send("folder.suggest-id", {}) end
        end))
    end
    if encrypted > 0 then
        table.insert(children, SharedWidgetControls.hint(tostring(encrypted) .. " encrypted folder offer" .. (encrypted == 1 and " requires" or "s require") .. " the Syncthing Web UI.", Palette.roles.warning))
    end
    if #children == 0 then return ui.column({ visible = false }) end
    return ui.column({ gap = 6 }, children)
end

return Source
