local Model = {}

function Model.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in value do result[key] = Model.copy(item) end
    return result
end

function Model.find(rows, id)
    for _, row in rows or {} do
        if row.id == id then return row end
    end
    return nil
end

function Model.selected(set)
    local result = {}
    for id, checked in set do if checked then table.insert(result, id) end end
    table.sort(result)
    return result
end

function Model.bool(value)
    return value == true or value == "true"
end

function Model.folderProblem(folder)
    local status = folder.status or {}
    return status.state == "error" or (status.error ~= nil and status.error ~= "")
        or (status.pullErrors or 0) > 0 or #(status.errors or {}) > 0
end

function Model.folderSyncing(folder)
    local status = folder.status or {}
    return (status.needTotalItems or 0) > 0 or status.state == "syncing"
end

function Model.folderScanning(folder)
    return string.sub((folder.status or {}).state or "", 1, 4) == "scan"
end

-- Omarchy's rule: scanning is shown for scans this panel asked for.
function Model.folderRescanning(snapshot, folder, rescan)
    if not folder or folder.paused or not rescan then return false end
    if rescan.action == "folder.rescan" then return rescan.folderId == folder.id end
    if rescan.action ~= "folder.rescan-all" then return false end
    if Model.folderScanning(folder) then return true end
    for _, other in snapshot.folders or {} do
        if Model.folderScanning(other) then return false end
    end
    return true
end

function Model.folderStateGroup(state)
    if state == "SYNCING" or state == "SCANNING" or state == "SCAN+SYNC" then return "active" end
    if state == "ERROR" then return "errors" end
    if state == "UNLINKED" then return "paused" end
    return state == "UNKNOWN" and "unknown" or "ready"
end

local stateHelp = {
    LINKED = "LINKED · Newly linked", SYNCING = "SYNCING · Applying changes",
    SCANNING = "SCANNING · Rescanning local files", ["SCAN+SYNC"] = "SCAN+SYNC · Rescanning and syncing",
    UNLINKED = "UNLINKED · Syncing paused", UNKNOWN = "UNKNOWN · Status unavailable",
    ERROR = "ERROR · Needs attention", SYNCED = "SYNCED · Up to date",
}

function Model.folderStateHelp(state)
    return stateHelp[state] or stateHelp.SYNCED
end

-- Subsequence match on the label, as Omarchy's selector searches.
function Model.matchesSearch(label, query)
    local text, needle, position = string.lower(label), string.lower(query), 1
    for index = 1, #needle do
        local char = string.sub(needle, index, index)
        if char ~= " " or index < #needle then
            local found = string.find(text, char, position, true)
            if not found then return false end
            position = found + 1
        end
    end
    return true
end

-- Plain scans instead of patterns: the host's budget hook reads the CPU clock
-- during pattern matching, which made this per-folder helper the hot spot.
function Model.folderLabel(folder)
    local path = folder.path or ""
    local last = #path
    while last > 0 and string.byte(path, last) == 47 do last -= 1 end
    local slash, from = 0, 1
    while true do
        local found = string.find(path, "/", from, true)
        if not found or found > last then break end
        slash, from = found, found + 1
    end
    local name = last > slash and string.sub(path, slash + 1, last) or nil
    return name or (folder.label ~= "" and folder.label) or folder.id
end

function Model.pathParent(path)
    local parent = string.match(string.gsub(path or "", "/+$", ""), "([^/]*)/[^/]*$")
    return parent and parent ~= "" and parent or "/"
end

function Model.folderRows(snapshot, view, rescan)
    local rows, counts = {}, {}
    for _, folder in snapshot.folders or {} do
        local name = Model.folderLabel(folder)
        counts[name] = (counts[name] or 0) + 1
    end
    local query = view.search or ""
    for _, folder in snapshot.folders or {} do
        local state = Model.folderState(snapshot, folder, view, rescan)
        local group = Model.folderStateGroup(state)
        local name = Model.folderLabel(folder)
        if counts[name] > 1 then name ..= " (" .. Model.pathParent(folder.path) .. ")" end
        if view.filters[group] ~= false and Model.matchesSearch(name, query) then
            table.insert(rows, { id = folder.id, label = name, path = folder.path, group = group, state = state })
        end
    end
    -- Lowercase each label once; the sort compares O(n log n) times within
    -- the host's per-callback CPU budget.
    local keys = {}
    for _, row in rows do keys[row] = string.lower(row.label) end
    table.sort(rows, function(a, b)
        if view.sort ~= "name" then
            local ap, bp = a.group == view.sort, b.group == view.sort
            if ap ~= bp then return ap end
        end
        if keys[a] ~= keys[b] then return keys[a] < keys[b] end
        return a.id < b.id
    end)
    return rows
end

function Model.remoteDevices(snapshot)
    local rows = {}
    for _, device in snapshot.devices or {} do
        if device.id ~= (snapshot.identity or {}).deviceId then table.insert(rows, device) end
    end
    return rows
end

function Model.shares(folder, deviceId)
    for _, member in folder.devices or {} do if member.id == deviceId then return true end end
    return false
end

function Model.bytes(value)
    value = math.max(0, value or 0)
    local units, index = { "B", "KiB", "MiB", "GiB", "TiB" }, 1
    while value >= 1024 and index < #units do value /= 1024; index += 1 end
    if index == 1 then return string.format("%.0f %s", value, units[index]) end
    return string.format(value >= 10 and "%.0f %s" or "%.1f %s", value, units[index])
end

function Model.count(value)
    value = math.max(0, value or 0)
    if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
    if value >= 1000 then return string.format(value >= 10000 and "%.0fk" or "%.1fk", value / 1000) end
    return string.format("%.0f", value)
end

function Model.pathLabel(path)
    local value = string.gsub(path or "", "/+$", "")
    if string.sub(path or "", 1, 1) == "/" and value == "" then return "/" end
    local last = string.match(value, "([^/]+)$")
    return last or "Folder"
end

function Model.shortDeviceId(id)
    return string.match(id or "", "^[^-]*") or ""
end

function Model.deviceLabel(device)
    return device.name ~= nil and device.name ~= "" and device.name or ("Device " .. Model.shortDeviceId(device.id))
end

-- Omarchy resolves "~", "~/x" and relative paths against the home directory.
function Model.resolvePath(path, home)
    if path == "~" then return home end
    if string.sub(path, 1, 2) == "~/" then return home .. string.sub(path, 2) end
    if string.sub(path, 1, 1) == "/" or not home or home == "" then return path end
    return home .. "/" .. path
end

-- Native labels end-elide; Omarchy keeps a path's tail visible.
function Model.shortPath(path, limit)
    path = tostring(path or "")
    limit = limit or 52
    if #path <= limit then return path end
    return "…" .. string.sub(path, -limit)
end

function Model.validDeviceId(value)
    local count = 0
    for part in string.gmatch(value, "[^-]+") do
        if #part ~= 7 or string.find(part, "[^A-Z2-7]") then return false end
        count += 1
    end
    return count == 8 and #value == 63
end

function Model.shareMeaning(snapshot, deviceId, remoteState)
    local device = Model.find(snapshot.devices, deviceId)
    local connection = snapshot.connection or {}
    local known = connection.fresh and device and device.connected and not device.paused
    local state = known and remoteState or "unknown"
    if state == "valid" then return true, "" end
    if state == "paused" then return true, "Remote folder paused" end
    if state == "notSharing" then return false, "Remote is not sharing back" end
    return false, "Remote acceptance unconfirmed"
end

function Model.deviceShares(snapshot, deviceId)
    local groups = { confirmed = {}, unconfirmed = {} }
    for _, folder in snapshot.folders or {} do
        local member = Model.find(folder.devices, deviceId)
        if member then
            local confirmed, description = Model.shareMeaning(snapshot, deviceId, member.remoteState)
            table.insert(groups[confirmed and "confirmed" or "unconfirmed"], {
                id = folder.id, label = Model.folderLabel(folder), description = description, path = folder.path })
        end
    end
    return groups
end

function Model.removedShares(snapshot, form)
    local removed = {}
    for _, folder in snapshot.folders or {} do
        if Model.shares(folder, form.deviceId) and form.selected[folder.id] == false then table.insert(removed, folder.id) end
    end
    return removed
end

function Model.hasProblems(snapshot)
    for _, folder in snapshot.folders or {} do
        if Model.folderProblem(folder) then return true end
    end
    return false
end

function Model.problems(snapshot)
    local rows = {}
    for _, folder in snapshot.folders or {} do
        local status = folder.status or {}
        local errors = status.errors or {}
        local count = math.max(status.pullErrors or 0, #errors)
        if status.state == "error" or (status.error and status.error ~= "") or count > 0 then
            table.insert(rows, { id = folder.id, path = folder.path, label = Model.folderLabel(folder),
                count = count, shown = #errors, status = status })
        end
    end
    return rows
end

-- Grouped by reason, as Omarchy lists them.
function Model.errorText(status)
    local order, groups = {}, {}
    for _, err in status.errors or {} do
        if not groups[err.error] then groups[err.error] = {}; table.insert(order, err.error) end
        table.insert(groups[err.error], err.path)
    end
    local detail = {}
    if status.error and status.error ~= "" then table.insert(detail, status.error) end
    for _, reason in order do table.insert(detail, reason .. "\n\n" .. table.concat(groups[reason], "\n")) end
    return #detail > 0 and table.concat(detail, "\n\n") or "Syncthing reported no error details."
end

function Model.totals(snapshot)
    local total = { files = 0, bytes = 0, scanning = 0, paused = 0 }
    for _, folder in snapshot.folders or {} do
        local status = folder.status or {}
        total.files += status.globalFiles or 0
        total.bytes += status.globalBytes or 0
        if string.sub(status.state or "", 1, 4) == "scan" then total.scanning += 1 end
        if folder.paused then total.paused += 1 end
    end
    return total
end

function Model.folderState(snapshot, folder, view, rescan)
    if not (snapshot.connection or {}).online or not folder then return "UNKNOWN" end
    if folder.paused then return "UNLINKED" end
    if Model.folderProblem(folder) then return "ERROR" end
    local activity = (snapshot.activity or {}).current
    local hasActivity = activity ~= nil and activity.folderId == folder.id
    local syncing = Model.folderSyncing(folder) or hasActivity
    if Model.folderRescanning(snapshot, folder, rescan) then return syncing and "SCAN+SYNC" or "SCANNING" end
    if view.recentlyLinked == folder.id then return "LINKED" end
    return syncing and "SYNCING" or "SYNCED"
end

local function folderSuffix(folder)
    return (folder.label or "") ~= "" and folder.label ~= Model.folderLabel(folder) and (" · " .. folder.label) or ""
end

function Model.folderMeta(snapshot, folder, scanning)
    local status = folder.status or {}
    if Model.folderProblem(folder) then
        local first = (status.errors or {})[1]
        return ((status.error ~= nil and status.error ~= "" and status.error) or (first and first.error) or "Folder needs attention") .. folderSuffix(folder)
    end
    local suffix = folderSuffix(folder)
    if folder.paused then return "Syncing paused" .. suffix end
    if scanning then return "Scanning local changes" .. suffix end
    if Model.folderSyncing(folder) then
        local items = status.needTotalItems or 0
        local remaining = Model.count(items) .. " item" .. (items == 1 and "" or "s") .. " remaining"
        return ((status.needBytes or 0) > 0 and (remaining .. " · " .. Model.bytes(status.needBytes)) or remaining) .. suffix
    end
    local shared = 0
    for _, member in folder.devices or {} do
        if member.id ~= (snapshot.identity or {}).deviceId then shared += 1 end
    end
    if shared == 0 then return Model.count(status.globalFiles) .. " files · local only" end
    return Model.count(status.globalFiles) .. " files · " .. Model.bytes(status.globalBytes)
end

function Model.folderGroupRole(group)
    if group == "errors" then return "error" end
    if group == "active" or group == "paused" then return "warning" end
    return group == "ready" and "success" or "muted"
end

function Model.folderStateRole(state)
    if state == "SYNCED" or state == "LINKED" then return "success" end
    if state == "SYNCING" or state == "SCANNING" or state == "SCAN+SYNC" or state == "UNLINKED" then
        return "warning"
    end
    return state == "ERROR" and "error" or "muted"
end

function Model.deviceStateRole(device)
    if device.paused then return "warning" end
    return device.connected and "success" or "muted"
end

function Model.lifecycleAvailable(lifecycle)
    return lifecycle.targetMatch == true and (lifecycle.canControl == true or lifecycle.canStart == true)
end

-- Omarchy's icon variant and tooltip summary.
function Model.indicator(snapshot, status)
    local connection, lifecycle, counts = snapshot.connection or {}, snapshot.lifecycle or {}, snapshot.counts or {}
    local installation = snapshot.installation or {}
    local phase = connection.phase or "discovering"
    local rescanning = status.rescan ~= nil or (status.busyAction == "folder.rescan" or status.busyAction == "folder.rescan-all")
    local activity = snapshot.activityActive or (snapshot.activity or {}).current ~= nil
    local syncInProgress = (counts.syncingFolders or 0) > 0 or activity or rescanning
    local problems = counts.folderProblems or 0
    local serviceOff = Model.lifecycleAvailable(lifecycle) and lifecycle.active ~= true
    local summary = "Up to date"
    if not status.ready then summary = status.error and "Syncthing unavailable" or "Starting Syncshell"
    elseif installation.available == false and not connection.online then summary = "Syncthing is not installed"
    elseif serviceOff then summary = "Syncing stopped"
    elseif phase == "discovering" then summary = "Finding Syncthing"
    elseif phase == "loading" then summary = "Reading status"
    elseif phase == "error" then summary = "Syncthing unavailable"
    elseif problems > 0 then summary = tostring(problems) .. " folder problem" .. (problems == 1 and "" or "s")
    elseif (counts.syncingFolders or 0) > 0 then
        summary = tostring(counts.syncingFolders) .. " folder" .. (counts.syncingFolders == 1 and "" or "s") .. " syncing"
    end
    local variant = "default"
    if not status.ready or (installation.available ~= true and not connection.online) then variant = "notify"
    elseif serviceOff then variant = "pause"
    elseif phase == "error" or problems > 0 then variant = "notify"
    elseif status.busy or syncInProgress then variant = "sync" end
    if variant == "sync" and syncInProgress then summary = "Sync in progress..." end
    return variant, summary
end

-- Omarchy's choice between the saved preference and systemd's autostart state.
function Model.driftDecision(config, lifecycle)
    local unit, active = lifecycle.unitFileState or "", lifecycle.activeState or ""
    if config ~= "enabled" and config ~= "disabled" then
        return { status = "unsupported", reason = "Configured service state is unsupported: " .. (config or "empty") }
    end
    if unit ~= "enabled" and unit ~= "disabled" then
        return { status = "unsupported", reason = "Systemd unit-file state is unsupported: " .. (unit ~= "" and unit or "empty") }
    end
    if config == unit then return { status = "aligned" } end
    if active ~= "active" and active ~= "inactive" then
        return { status = "unsupported", reason = "Systemd runtime state is not settled: " .. (active ~= "" and active or "empty") }
    end
    local preferred = active == "active" and "enabled" or "disabled"
    local system = { side = "system", value = config, label = (config == "enabled" and "Enable" or "Disable") .. " systemd autostart" }
    local host = { side = "config", value = unit, label = "Set Syncthing config to " .. unit }
    if system.value == preferred then system.label ..= " (preferred)" end
    if host.value == preferred then host.label ..= " (preferred)" end
    return { status = "drift", first = system.value == preferred and system or host, second = system.value == preferred and host or system,
        message = "Syncthing config (" .. config .. ") differs from its systemd autostart setting (" .. unit .. ").\n\nPlease choose:" }
end

function Model.newView(now)
    return { view = "panel-" .. tostring(now), sequence = 0, formSequence = 0,
        section = "folders", search = "", sort = "name",
        filters = { ready = true, active = true, errors = true, paused = true, unknown = true },
        more = false, message = "", form = nil, confirm = nil }
end

return Model
