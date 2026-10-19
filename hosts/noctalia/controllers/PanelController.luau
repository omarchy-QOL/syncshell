local Form = require("../models/FormModel.luau")
local Actions = require("../models/ActionModel.luau")
local Model = require("../models/PanelModel.luau")
local Controller = {}
Controller.__index = Controller

function Controller.new(host, changed)
    local self = setmetatable({}, Controller)
    self.host, self.changed = host, changed
    self.view = host.state.get("view") or Model.newView(host.nowMs())
    self.status = host.state.get("status") or {}
    self.snapshot = {}
    host.state.watch("status", function(value) self:setStatus(value); self:save() end)
    host.state.watch("results", function(value) self:setResults(value); self:save() end)
    self:setResults(host.state.get("results"))
    return self
end

function Controller:notice(message, kind)
    local v = self.view
    v.message, v.noticeKind = message, kind
    v.noticeUntil = kind == "success" and (self.host.nowMs() + 5000) or nil
    if kind == "error" or kind == "uncertain" then v.lastFailure = message end
end

function Controller:needsTicks()
    local connection = self.snapshot.connection or {}
    return self.view.noticeUntil ~= nil or self.view.linkedUntil ~= nil
        or (connection.online == true and connection.fresh == true and (self.snapshot.activity or {}).current ~= nil)
end

function Controller:tick()
    local v, now = self.view, self.host.nowMs()
    local changed = false
    if v.noticeUntil and now >= v.noticeUntil then
        v.message, v.noticeUntil = "", nil
        changed = true
    end
    if v.linkedUntil and now >= v.linkedUntil then v.recentlyLinked, v.linkedUntil = nil, nil; changed = true end
    if (self.snapshot.connection or {}).online and (self.snapshot.connection or {}).fresh
        and (self.snapshot.activity or {}).current then
        self.activityPhase = ((self.activityPhase or 0) + 1) % 4
        changed = true
    end
    if changed then self:save() end
end

function Controller:save()
    self.host.state.set("view", self.view)
    self.changed()
end

function Controller:setStatus(status)
    if not status or status.generation ~= self.status.generation then
        self.snapshot, self.received, self.view.profilesRemoved = {}, nil, nil
    end
    self.status = status or {}
    if self.view.pending and self.view.pending.generation ~= self.status.generation then
        self.view.pending = nil
        self:notice("Worker restarted. The previous action may have completed; refresh before retrying.", "uncertain")
    end
end

function Controller:setSnapshot(value)
    if not value or value.generation ~= self.status.generation then return end
    self.snapshot, self.received = value.state, value.received
    local v = self.view
    if v.form then Form.reconcile(self.snapshot, v.form) end
    if not v.folderId and #(self.snapshot.folders or {}) > 0 then v.folderId = self.snapshot.folders[1].id end
    local devices = Model.remoteDevices(self.snapshot)
    if not v.deviceId and #devices > 0 then v.deviceId = devices[1].id end
    for id in v.scanning do
        local folder = Model.find(self.snapshot.folders, id)
        if not folder or string.sub((folder.status or {}).state or "", 1, 4) ~= "scan" then
            v.scanning[id] = nil
        end
    end
end

function Controller:setResults(results)
    local pending = self.view.pending
    if not pending then return end
    for _, result in results or {} do
        if result.id == pending.id and result.view == self.view.view and result.generation == pending.generation then
            self.view.pending = nil
            self:notice(result.ok and Actions.label(pending.action or pending.requestType, 3) or (result.error or "Action failed"),
                result.ok and "success" or (result.code == "uncertain" and "uncertain" or "error"))
            if result.ok and pending.action == "folder.resume" then
                self.view.recentlyLinked, self.view.linkedUntil = pending.args.folderId, self.host.nowMs() + 5000
            end
            if result.ok and pending.action == "webui.remove-profile" then self.view.profilesRemoved = true end
            if result.ok and (pending.action == "webui.apply-profile" or pending.action == "webui.set-theme") then
                self.view.profilesRemoved = nil
            end
            local form = self.view.form
            local sameForm = form and form.token == pending.formToken
            if result.ok and pending.action == "folder.suggest-id" and sameForm then
                form.folderId = result.data.folderId
                form.idRevision = (form.idRevision or 0) + 1
            elseif not result.ok and result.code == "path_missing" and pending.action == "folder.add-existing" and sameForm then
                local args = Model.copy(pending.args)
                args.createDirectory = true
                self:confirm("Create " .. args.path .. " and add this folder?", pending.action, args, true)
            elseif result.ok and pending.closeForm and sameForm then
                self.view.form, self.view.confirm = form.returnForm, nil
                if result.data and result.data.folderId then self.view.folderId = result.data.folderId end
            end
            if result.ok and result.data and result.data.runningFolderIds then
                if #result.data.runningFolderIds > 0 then self:notice("Rescan requested; scanning continues until Syncthing reports completion.", "success") end
                for _, id in result.data.runningFolderIds do self.view.scanning[id] = true end
            end
            return
        end
    end
end

function Controller:refresh()
    if (self.snapshot.connection or {}).online and Model.hasProblems(self.snapshot) then
        return self:send("folder.recheck-errors", {})
    end
    return self:send(nil, nil, false, "refresh")
end

function Controller:canRescan()
    local connection = self.snapshot.connection or {}
    if not self.status.ready or self:busy() or not connection.online or not connection.fresh then return false end
    for _, folder in self.snapshot.folders or {} do
        if not folder.paused and not self.view.scanning[folder.id]
            and string.sub((folder.status or {}).state or "", 1, 4) ~= "scan" then return true end
    end
    return false
end

function Controller:rescanAll()
    if self:canRescan() then return self:send("folder.rescan-all", {}) end
    self:notice("Connect to Syncthing and link a folder before rescanning. Folders already scanning must finish first.", "error")
    self:save(); return false
end

function Controller:actionKey(action)
    return action .. "-" .. tostring(self.view.sequence)
end

function Controller:actionLabel(action, label)
    return self.view.pending and self.view.pending.action == action and Actions.label(action, 2) or label
end

function Controller:busy()
    return self.view.pending ~= nil or self.status.busy ~= nil
end

function Controller:send(action, args, closeForm, requestType)
    if self:busy() or not self.status.ready then return false end
    local problem = Form.actionProblem(self.snapshot, action, args or {})
    if problem then self:notice(problem, "error"); self:save(); return false end
    self.view.actionCursor = nil
    self.view.sequence += 1
    local id = self.view.view .. "-" .. tostring(self.view.sequence)
    local frozen = Model.copy(args or {})
    self.view.pending = { id = id, generation = self.status.generation,
        action = action, requestType = requestType or "action", args = frozen, closeForm = closeForm,
        formToken = self.view.form and self.view.form.token }
    self:notice(Actions.label(action or requestType, 2), "progress")
    self:save()
    local request = { v = 2, type = requestType or "action", id = id }
    if request.type == "action" then request.action, request.args = action, frozen end
    self.host.state.set("intent", { id = id, generation = self.status.generation,
        view = self.view.view, request = request })
    return true
end

function Controller:confirm(message, action, args, closeForm)
    if self:busy() then return end
    self.view.confirm = { message = message, action = action, args = Model.copy(args),
        closeForm = closeForm, choice = "cancel", opened = self.host.nowMs() }
    self:save()
end

function Controller:acceptConfirmation()
    local confirm = self.view.confirm
    if not confirm or self:busy() or self.host.nowMs() - confirm.opened < 300 then return end
    self.view.confirm = nil
    self:send(confirm.action, confirm.args, confirm.closeForm)
end

function Controller:cancel()
    if self:busy() then return end
    if self.view.confirm then self.view.confirm = nil
    elseif self.view.form and self.view.form.picker then self.view.form.picker = nil
    else self.view.form = self.view.form and self.view.form.returnForm end
    self:save()
end

function Controller:openForm(kind, target)
    if self:busy() then return end
    if self.view.form and self.view.form.kind == kind then return end
    local parent = self.view.form
    local nested = parent and (kind == "settings" or (kind == "addDevice"
        and (parent.kind == "sharing" or parent.kind == "addFolder" or parent.kind == "acceptFolder")))
    self.view.actionCursor = nil
    self.view.formSequence += 1
    local form = { kind = kind, token = self.view.formSequence, search = "", selected = {},
        folderId = "", deviceId = "", path = "", label = "", name = "", address = "" }
    form.returnForm = nested and parent or nil
    if kind == "sharing" then
        form.folderId = target.id
        for _, device in target.devices or {} do
            if device.id ~= (self.snapshot.identity or {}).deviceId then form.selected[device.id] = true end
        end
    elseif kind == "deviceFolders" then
        if not Model.find(self.snapshot.devices, target.id) then
            self:notice("This device is no longer configured", "error"); self:save(); return
        end
        form.deviceId = target.id
        for _, folder in self.snapshot.folders or {} do
            if Model.shares(folder, target.id) then form.selected[folder.id] = true end
        end
    elseif kind == "acceptDevice" then
        form.deviceId, form.name, form.address = target.id, target.name or "", target.address or ""
    elseif kind == "acceptFolder" then
        form.folderId, form.pendingDeviceId, form.label = target.id, target.deviceId, target.label
        form.selected[target.deviceId] = true
    end
    Form.reconcile(self.snapshot, form)
    self.view.form, self.view.confirm, self.view.message = form, nil, ""
    self.view.noticeUntil, self.view.noticeKind = nil, nil
    self:save()
    if kind == "addFolder" then self:send("folder.suggest-id", {}) end
end

function Controller:submitForm()
    local form = self.view.form
    if not form or self:busy() then return end
    local kind = form.kind
    local problem = Form.problem(self.snapshot, form)
    if problem then self:notice(problem, "error"); self:save(); return end
    if kind == "addFolder" or kind == "acceptFolder" then
        self:send("folder.add-existing", { folderId = Form.trim(form.folderId), label = Form.trim(form.label),
            path = Form.trim(form.path), deviceIds = Model.selected(form.selected), pendingDeviceId = form.pendingDeviceId }, true)
    elseif kind == "sharing" then
        self:send("folder.set-sharing", { folderId = form.folderId, deviceIds = Model.selected(form.selected) }, true)
    elseif kind == "deviceFolders" then
        local removed = Model.removedShares(self.snapshot, form)
        if #removed == 0 then return end
        self:confirm("Remove the selected shares from this device? Local files remain.",
            "device.remove-folder-shares", { deviceId = form.deviceId, folderIds = removed }, true)
    elseif kind == "addDevice" or kind == "acceptDevice" then
        self:send("device.add", { deviceId = Form.deviceId(form.deviceId), deviceName = Form.trim(form.name) }, true)
    end
end

function Controller:copy(text)
    local ok = self.host.copyToClipboard(text, "text/plain")
    self:notice(ok and "Copied" or "Clipboard unavailable", ok and "success" or "error")
    self:save()
end

function Controller:openExternal(target)
    if not self.host.commandExists("xdg-open") then
        self:notice("Install xdg-utils to open this destination", "error"); self:save(); return
    end
    local launched = self.host.runAsync({ "xdg-open", target }, function(reply)
        if reply.exitCode ~= 0 or reply.timedOut then self:notice("Could not open " .. target, "error"); self:save() end
    end)
    if not launched then self:notice("Could not launch the desktop opener", "error"); self:save() end
end

function Controller:openDocumentation(topic)
    local urls = { installation = "https://syncthing.net/downloads/",
        startup = "https://docs.syncthing.net/users/autostart.html#linux" }
    self:openExternal(assert(urls[topic], "unknown help topic"))
end

function Controller:openPath(path)
    local expanded = self.host.expandPath(path)
    if string.sub(expanded, 1, 1) ~= "/" or string.find(expanded, "%z") then
        self:notice("Cannot open a non-absolute directory", "error"); self:save(); return
    end
    self:openExternal(expanded)
end

return Controller
