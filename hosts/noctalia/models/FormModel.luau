local Model = require("./PanelModel.luau")
local Form = {}

function Form.trim(value)
    return string.match(value or "", "^%s*(.-)%s*$")
end

function Form.deviceId(value)
    return string.upper(Form.trim(value))
end

function Form.offer(snapshot, form)
    local folder = (snapshot.pendingFolders or {})[form.folderId]
    return folder and (folder.offeredBy or {})[form.pendingDeviceId]
end

function Form.sharingAvailable(snapshot, folder)
    local connection = snapshot.connection or {}
    return folder ~= nil and folder.devices ~= nil and connection.online == true and connection.fresh == true
end

-- New remote configuration is never treated as an unchecked removal.
function Form.reconcile(snapshot, form)
    if form.kind ~= "sharing" and form.kind ~= "deviceFolders" then return end
    local current = {}
    if form.kind == "sharing" then
        local folder = Model.find(snapshot.folders, form.folderId)
        if not Form.sharingAvailable(snapshot, folder) then return end
        for _, device in folder.devices do
            if device.id ~= (snapshot.identity or {}).deviceId then current[device.id] = true end
        end
    else
        if not (snapshot.connection or {}).fresh then return end
        for _, folder in snapshot.folders or {} do
            if folder.devices == nil then return end
            if Model.shares(folder, form.deviceId) then current[folder.id] = true end
        end
    end
    for id in form.original or {} do
        if not current[id] then form.selected[id] = nil end
    end
    for id in current do
        if not (form.original or {})[id] then form.selected[id] = true end
    end
    form.original = current
end

function Form.problem(snapshot, form)
    local connection = snapshot.connection or {}
    if form.kind == "sharing" then
        local folder = Model.find(snapshot.folders, form.folderId)
        if not folder then return "This folder is no longer configured" end
        if not Form.sharingAvailable(snapshot, folder) then
            return "Sharing data unavailable. Refresh before replacing this folder's sharing."
        end
    elseif form.kind == "deviceFolders" then
        if not Model.find(snapshot.devices, form.deviceId) then return "This device is no longer configured" end
        if not connection.online or not connection.fresh then return "Refresh before removing shares" end
        for _, folder in snapshot.folders or {} do
            if folder.devices == nil then return "Sharing data unavailable. Refresh before removing shares." end
        end
        if #Model.removedShares(snapshot, form) == 0 then return "Uncheck a share to review its removal" end
    elseif form.kind == "addDevice" or form.kind == "acceptDevice" then
        local id = Form.deviceId(form.deviceId)
        if not Model.validDeviceId(id) then return "Enter a complete Syncthing device ID" end
        if id == (snapshot.identity or {}).deviceId then return "This is the local device's ID" end
        if Model.find(snapshot.devices, id) then return "This device is already configured" end
        if form.kind == "acceptDevice" and not Model.find(snapshot.pendingDevices, id) then
            return "This invitation is no longer available"
        end
    elseif form.kind == "addFolder" or form.kind == "acceptFolder" then
        if form.pendingDeviceId then
            local offer = Form.offer(snapshot, form)
            if not offer then return "This folder invitation is no longer available" end
            if offer.receiveEncrypted or offer.remoteEncrypted then return "This encrypted invitation requires the Web UI" end
            if not form.selected[form.pendingDeviceId] then return "Keep the offering device selected to accept this invitation" end
        end
        if Form.trim(form.path) == "" or Form.trim(form.folderId) == "" then return "Enter a directory and folder ID" end
        if Model.find(snapshot.folders, Form.trim(form.folderId)) then return "This folder ID is already configured" end
    end
    if not connection.online or not connection.fresh then return "Current configuration unavailable. Refresh before saving." end
    if form.kind == "sharing" or form.kind == "addFolder" or form.kind == "acceptFolder" then
        for id, checked in form.selected do
            if checked and not Model.find(snapshot.devices, id) then return "Selected device is no longer configured: " .. id end
        end
    end
    return nil
end

function Form.actionProblem(snapshot, action, args)
    if not action then return nil end
    if action == "folder.add-existing" or action == "folder.set-sharing" then
        local form = Model.copy(args)
        form.kind = action == "folder.add-existing" and "addFolder" or "sharing"
        form.selected = {}
        for _, id in args.deviceIds or {} do form.selected[id] = true end
        return Form.problem(snapshot, form)
    end
    if args.folderId and action ~= "folder.dismiss-pending" then
        local folder = Model.find(snapshot.folders, args.folderId)
        if not folder then return "This folder is no longer configured" end
        if action == "folder.forget" and not folder.paused then return "Unlink this folder before forgetting its configuration" end
    end
    if args.deviceId and action ~= "device.add" and action ~= "device.dismiss-pending"
        and not Model.find(snapshot.devices, args.deviceId) then return "This device is no longer configured" end
    if action == "folder.dismiss-pending" and not Form.offer(snapshot, args) then return "This folder invitation is no longer available" end
    if action == "device.dismiss-pending" and not Model.find(snapshot.pendingDevices, args.deviceId) then
        return "This device invitation is no longer available"
    end
    if action == "device.add" then return Form.problem(snapshot, { kind = "addDevice", deviceId = args.deviceId }) end
    return nil
end

return Form
