local Settings = require("./SettingsController.luau")
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

-- Omarchy's notice timings: brief for feedback, longer for result sentences.
function Controller:notice(message, kind, visibleMs)
    local v = self.view
    v.message, v.noticeKind = message, kind
    v.noticeUntil = kind == "success" and (self.host.nowMs() + (visibleMs or 5000)) or nil
end

function Controller:needsTicks()
    local connection = self.snapshot.connection or {}
    return self.view.noticeUntil ~= nil or self.view.linkedUntil ~= nil or self.view.refreshUntil ~= nil
        or (self.snapshot.activity or {}).current ~= nil
end

function Controller:tick()
    local v, now = self.view, self.host.nowMs()
    local changed = false
    if v.noticeUntil and now >= v.noticeUntil then
        v.message, v.noticeUntil = "", nil
        changed = true
    end
    if v.linkedUntil and now >= v.linkedUntil then v.recentlyLinked, v.linkedUntil = nil, nil; changed = true end
    if v.refreshUntil and now >= v.refreshUntil then
        v.refreshUntil = nil; changed = true
        if v.refreshSucceeded then
            v.refreshSucceeded = false
            self:notice("Syncthing status refreshed", "success")
        end
    end
    if (self.snapshot.activity or {}).current then
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
    local notice = self.status.notice
    if notice and notice.sequence ~= self.view.noticeSequence then
        self.view.noticeSequence = notice.sequence
        self:notice(notice.text, notice.kind, 10000)
    end
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
    -- As in Omarchy, a selection that no longer exists falls back to the first row.
    if not Model.find(self.snapshot.folders, v.folderId) then
        v.folderId = ((self.snapshot.folders or {})[1] or {}).id
    end
    local devices = Model.remoteDevices(self.snapshot)
    if not Model.find(devices, v.deviceId) then v.deviceId = devices[1] and devices[1].id end
end

function Controller:setResults(results)
    local pending = self.view.pending
    if not pending then return end
    for _, result in results or {} do
        if result.id == pending.id and result.view == self.view.view and result.generation == pending.generation then
            self.view.pending = nil
            if pending.action == "webui.open" and not result.ok then
                -- As in Omarchy, a failed bridge still opens the plain address.
                self:openExternal((self.snapshot.webUi or {}).url or "")
            elseif pending.requestType == "refresh" or pending.action == "folder.recheck-errors" then
                if result.ok then self.view.refreshSucceeded = true
                else self:notice(result.error or "Could not recheck Syncthing errors", "error") end
            elseif pending.action == "folder.suggest-id" then
                local form = self.view.form
                if form and form.token == pending.formToken and not result.ok then
                    form.prepareError = result.error or "Could not generate a folder ID"
                end
            elseif not result.ok then
                self:notice(result.error or "Action failed", result.code == "uncertain" and "uncertain" or "error")
            elseif pending.action ~= "folder.rescan" and pending.action ~= "folder.rescan-all" then
                self:notice(pending.notice, "success", pending.action == "device.add" and 15000 or 10000)
            end
            if result.ok and pending.action == "folder.resume" then
                self.view.recentlyLinked, self.view.linkedUntil = pending.args.folderId, self.host.nowMs() + 10000
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
                -- The dialog answers the error; Omarchy never shows it behind.
                self.view.message, self.view.noticeKind = "", nil
                self.view.confirm = { message = "Create " .. args.path .. " and add the folder?", action = pending.action, args = args,
                    closeForm = true, choice = "cancel", opened = self.host.nowMs() }
            elseif result.ok and pending.closeForm and sameForm then
                self.view.form, self.view.confirm = nil, nil
                if result.data and result.data.folderId then self.view.folderId = result.data.folderId end
            end
            return
        end
    end
end

-- Only its own request and feedback time block the refresh button, as in Omarchy.
function Controller:canRefresh()
    local pending = self.view.pending
    return (self.snapshot.connection or {}).online == true and self.status.ready == true
        and not (pending and (pending.requestType == "refresh" or pending.action == "folder.recheck-errors"))
        and (self.view.refreshUntil or 0) <= self.host.nowMs()
end

function Controller:refreshing()
    local pending = self.view.pending
    return (pending ~= nil and (pending.requestType == "refresh" or pending.action == "folder.recheck-errors"))
        or (self.view.refreshUntil or 0) > self.host.nowMs()
end

function Controller:refresh()
    self.view.refreshUntil = self.host.nowMs() + 1500
    self.view.refreshSucceeded = false
    -- Pressing refresh clears a shown error, as in Omarchy.
    if self.view.noticeKind == "error" or self.view.noticeKind == "uncertain" then self:notice("", nil) end
    if ((self.snapshot.counts or {}).folderProblems or 0) > 0 then
        return self:send("folder.recheck-errors", {})
    end
    return self:send(nil, nil, false, "refresh")
end

-- Opening the panel or the device form must not lock what the user is reaching for.
function Controller:refreshInBackground()
    if not self.status.ready or self:busy() then return end
    self.view.sequence += 1
    local id = self.view.view .. "-" .. tostring(self.view.sequence)
    self.host.state.set("intent", { id = id, generation = self.status.generation, view = "service",
        request = { v = 2, type = "refresh", id = id } })
end

function Controller:openWebUi()
    local connection, webUi = self.snapshot.connection or {}, self.snapshot.webUi or {}
    if not connection.online then return end
    if Model.ownsWebUiTheme(webUi.theme) then
        return self:send("webui.open", {})
    end
    self:openExternal(webUi.url or "")
end

function Controller:rescanState()
    if self.status.rescan then return self.status.rescan end
    local pending = self.view.pending
    if pending and (pending.action == "folder.rescan" or pending.action == "folder.rescan-all") then
        return { action = pending.action, folderId = (pending.args or {}).folderId }
    end
    return nil
end

-- Omarchy closes these on close; only the folder picker survives there, and
-- this adapter's picker cannot outlive the panel.
-- A press outside Omarchy's list closes it, and the rows beside this one stay usable.
function Controller:closeLists()
    self.view.filtersOpen = false
    for _, item in self.view.selectors or {} do item.open = false end
end

function Controller:resetTransient()
    local v = self.view
    v.more, v.form, v.confirm, v.details, v.filtersOpen, v.actionCursor = false, nil, nil, nil, false, nil
    for _, item in v.selectors or {} do item.open = false end
    self:save()
end

function Controller:canRescan()
    local connection = self.snapshot.connection or {}
    if not self.status.ready or self:busy() or not connection.online then return false end
    for _, folder in self.snapshot.folders or {} do
        if not folder.paused then return true end
    end
    return false
end

function Controller:rescanAll()
    if self:canRescan() then return self:send("folder.rescan-all", {}) end
    return false
end

-- Whatever is on screen with Omarchy's spinning or pulsing busy icon.
local animatedActions = { ["folder.pause"] = true, ["folder.resume"] = true, ["device.pause"] = true, ["device.resume"] = true }

function Controller:animating()
    local pending = self.view.pending
    return self:rescanState() ~= nil or self:refreshing() or (pending ~= nil and animatedActions[pending.action] == true)
end

function Controller:actionKey(action)
    return action .. "-" .. tostring(self.view.sequence)
end

function Controller:actionLabel(action, label, busyLabel)
    local pending = self.view.pending
    return pending and (pending.action or pending.requestType) == action and (busyLabel or Actions.label(action, 2)) or label
end

function Controller:busy()
    local pending = self.view.pending
    if pending and pending.action == "folder.suggest-id" then pending = nil end
    return pending ~= nil or self.status.busy ~= nil or self.status.rescan ~= nil
end

-- One request travels at a time. A running rescan blocks mutations only.
function Controller:send(action, args, closeForm, requestType)
    local mutation = action and action ~= "webui.open" and action ~= "folder.suggest-id" and action ~= "folder.recheck-errors"
        and string.sub(action, 1, 10) ~= "lifecycle."
    if self.view.pending or self.status.busy or (mutation and self.status.rescan) or not self.status.ready then return false end
    local problem = Form.actionProblem(self.snapshot, action, args or {})
    if problem then self:notice(problem, "error"); self:save(); return false end
    self.view.actionCursor = nil
    self.view.sequence += 1
    local id = self.view.view .. "-" .. tostring(self.view.sequence)
    local frozen = Model.copy(args or {})
    self.view.pending = { id = id, generation = self.status.generation,
        action = action, requestType = requestType or "action", args = frozen, closeForm = closeForm,
        notice = action and Actions.notice(action, frozen, self.snapshot) or "",
        formToken = self.view.form and self.view.form.token }
    -- Omarchy shows progress on the control and only folder and device changes clear the notice.
    if mutation and string.sub(action, 1, 6) ~= "webui." then self:notice("", nil) end
    self:save()
    local request = { v = 2, type = requestType or "action", id = id }
    if request.type == "action" then request.action, request.args = action, frozen end
    self.host.state.set("intent", { id = id, generation = self.status.generation,
        view = self.view.view, request = request, notice = self.view.pending.notice, background = action == "folder.suggest-id" })
    return true
end

function Controller:confirm(message, action, args, closeForm)
    self:closeLists()
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
    elseif self.view.form and self.view.form.page then self.view.form.page = nil
    elseif self.view.form and self.view.form.picker then self.view.form.picker = nil
    else self.view.form = nil end
    self:save()
end

function Controller:openForm(kind, target)
    if self:busy() and kind ~= "settings" then return end
    if self.view.form and self.view.form.kind == kind then return end
    self:closeLists()
    self.view.actionCursor = nil
    self.view.formSequence += 1
    local form = { kind = kind, token = self.view.formSequence, search = "", selected = {},
        folderId = "", deviceId = "", path = "", label = "", name = "", address = "" }
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
        -- Omarchy accepts through the add form with the offer already chosen.
        form.kind = "addFolder"
        form.folderId, form.pendingDeviceId, form.label = target.id, target.deviceId, target.label
        form.labelFromOffer = true
        form.selected[target.deviceId] = true
    end
    Form.reconcile(self.snapshot, form)
    self.view.form, self.view.confirm = form, nil
    if kind == "addFolder" or kind == "acceptFolder" then
        self.view.message, self.view.noticeUntil, self.view.noticeKind = "", nil, nil
    end
    self:save()
    if kind == "addFolder" then self:send("folder.suggest-id", {}) end
    if kind == "addDevice" then self:refreshInBackground() end
end

function Controller:submitForm()
    local form = self.view.form
    if not form or self:busy() then return end
    local kind = form.kind
    local problem = Form.problem(self.snapshot, form)
    if problem then self:notice(problem, "error"); self:save(); return end
    if kind == "addFolder" then
        local path, label = Form.trim(form.path), Form.trim(form.label)
        self:send("folder.add-existing", { folderId = Form.trim(form.folderId), label = label ~= "" and label or Model.pathLabel(path),
            path = Model.resolvePath(path, self.host.getenv("HOME") or ""), deviceIds = Model.selected(form.selected),
            pendingDeviceId = form.pendingDeviceId and form.selected[form.pendingDeviceId] and form.pendingDeviceId or nil }, true)
    elseif kind == "sharing" then
        self:send("folder.set-sharing", { folderId = form.folderId, deviceIds = Model.selected(form.selected) }, true)
    elseif kind == "deviceFolders" then
        local removed = Model.removedShares(self.snapshot, form)
        if #removed == 0 then return end
        self:send("device.remove-folder-shares", { deviceId = form.deviceId, folderIds = removed }, true)
    elseif kind == "addDevice" or kind == "acceptDevice" then
        self:send("device.add", { deviceId = Form.deviceId(form.deviceId), deviceName = Form.trim(form.name) }, true)
    end
end

-- The preference lives in the adapter's settings file; Noctalia's window can override it.
function Controller:chooseDrift(item)
    if item.side == "system" then
        return self:send(item.value == "enabled" and "lifecycle.enable" or "lifecycle.disable", {})
    end
    local path = Settings.filePath(self.host)
    local function write()
        local text = self.host.readFile(path) or Settings.template(self.host)
        local updated, count = string.gsub(text, "\n#? ?serviceState = \"[a-z]*\"", "\nserviceState = \"" .. item.value .. "\"")
        if count == 0 then updated = text .. "\nserviceState = \"" .. item.value .. "\"\n" end
        if not self.host.writeFile(path, updated) then self:notice("Could not update " .. path, "error")
        else self:notice("Syncthing service preference updated", "success", 10000) end
        self:save()
    end
    if self.host.fileExists(path) then return write() end
    self.host.runAsync({ "mkdir", "-p", (string.gsub(path, "/[^/]*$", "")) }, function(reply)
        if reply.exitCode == 0 then write() else self:notice("Could not create " .. path, "error"); self:save() end
    end)
end

function Controller:copy(text, notice)
    local ok = self.host.copyToClipboard(text, "text/plain")
    self:notice(ok and (notice or "Copied") or "Clipboard unavailable", ok and "success" or "error")
    self:save()
end

function Controller:openExternal(target)
    if target == "" then return end
    if not self.host.commandExists("xdg-open") then
        self:notice("Install xdg-utils to open this destination", "error"); self:save(); return
    end
    -- Detached: xdg-open stays alive as long as a starting browser does.
    local launched = self.host.runAsync({ "xdg-open", target })
    if not launched then self:notice("Could not launch the desktop opener", "error"); self:save() end
end

-- As Omarchy opens its settings: the editor in a terminal, with a toast. The
-- desktop's file handler is only the fallback, as its default may be unusable.
function Controller:openInEditor(path)
    local host = self.host
    local editor = host.getenv("VISUAL") or host.getenv("EDITOR")
    if not editor or editor == "" then editor = "nvim" end
    editor = string.match(editor, "^%S+")
    local terminal
    for _, candidate in { "xdg-terminal-exec", host.getenv("TERMINAL") or "", "foot", "kitty", "alacritty", "ghostty" } do
        if candidate ~= "" and host.commandExists(candidate) then terminal = candidate; break end
    end
    host.notify("Editing config file", path)
    if not terminal or not host.commandExists(editor) then return self:openExternal(path) end
    if not host.runAsync({ terminal, "-e", editor, "--", path }) then self:openExternal(path) end
end

function Controller:openSettingsFile()
    local path = Settings.filePath(self.host)
    if self.host.fileExists(path) then return self:openInEditor(path) end
    local launched = self.host.runAsync({ "mkdir", "-p", (string.gsub(path, "/[^/]*$", "")) }, function(reply)
        if reply.exitCode == 0 and self.host.writeFile(path, Settings.template(self.host)) then
            self:openInEditor(path)
        else
            self:notice("Could not create " .. path, "error"); self:save()
        end
    end)
    if not launched then self:notice("Could not create " .. path, "error"); self:save() end
end

function Controller:openDocumentation(topic)
    local urls = { installation = "https://syncthing.net/downloads/",
        startup = "https://docs.syncthing.net/users/autostart.html#linux" }
    self:openExternal(assert(urls[topic], "unknown help topic"))
end

function Controller:openPath(path)
    local expanded = Model.resolvePath(self.host.expandPath(path), self.host.getenv("HOME") or "")
    if string.sub(expanded, 1, 1) ~= "/" or string.find(expanded, "%z") then
        self:notice("Cannot open a non-absolute directory", "error"); self:save(); return
    end
    self:openExternal(expanded)
end

return Controller
