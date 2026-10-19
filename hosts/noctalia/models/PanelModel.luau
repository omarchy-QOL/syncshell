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

function Model.folderGroup(folder, online)
    local status = folder.status or {}
    if folder.paused then return "paused" end
    if not online then return "unknown" end
    if status.state == "error" or (status.error and status.error ~= "")
        or (status.pullErrors or 0) > 0 or #(status.errors or {}) > 0 then return "errors" end
    if status.state == "syncing" or string.sub(status.state or "", 1, 4) == "scan"
        or (status.needTotalItems or 0) > 0 then return "active" end
    if status.state == "idle" then return "ready" end
    return "unknown"
end

function Model.folderLabel(folder)
    local path = string.gsub(folder.path or "", "/+$", "")
    local name = string.match(path, "([^/]+)$")
    return name or (folder.label ~= "" and folder.label) or folder.id
end

function Model.folderRows(snapshot, view)
    local rows = {}
    local query = string.lower(view.search or "")
    for _, folder in snapshot.folders or {} do
        local group = Model.folderGroup(folder, snapshot.connection and snapshot.connection.online and snapshot.connection.fresh)
        local name = Model.folderLabel(folder)
        local text = string.lower(name .. " " .. (folder.label or "") .. " " .. folder.id .. " " .. folder.path)
        if view.filters[group] ~= false and string.find(text, query, 1, true) then
            table.insert(rows, { id = folder.id, label = name, path = folder.path, group = group })
        end
    end
    table.sort(rows, function(a, b)
        if view.sort ~= "name" then
            local ap, bp = a.group == view.sort, b.group == view.sort
            if ap ~= bp then return ap end
        end
        if string.lower(a.label) ~= string.lower(b.label) then return string.lower(a.label) < string.lower(b.label) end
        return a.id < b.id
    end)
    return rows
end

function Model.remoteDevices(snapshot)
    local rows = {}
    for _, device in snapshot.devices or {} do
        if device.id ~= (snapshot.identity or {}).deviceId then table.insert(rows, device) end
    end
    table.sort(rows, function(a, b)
        local an, bn = string.lower(a.name or ""), string.lower(b.name or "")
        if an ~= bn then return an < bn end
        return a.id < b.id
    end)
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
    return string.format(index == 1 and "%.0f %s" or "%.1f %s", value, units[index])
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
    if not connection.online or not connection.fresh then return false, "Remote acceptance unconfirmed: current status unavailable" end
    if not device then return false, "Remote acceptance unconfirmed: device unavailable" end
    if device.paused then return false, "Remote acceptance unconfirmed: device paused" end
    if not device.connected then return false, "Remote acceptance unconfirmed: device offline" end
    if remoteState == "valid" then return true, "Remote sharing confirmed" end
    if remoteState == "paused" then return true, "Remote folder paused" end
    if remoteState == "notSharing" then return false, "Remote is not sharing back" end
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
        local status = folder.status or {}
        if status.state == "error" or (status.error and status.error ~= "")
            or (status.pullErrors or 0) > 0 or #(status.errors or {}) > 0 then return true end
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

function Model.errorText(status)
    local detail = {}
    if status.error and status.error ~= "" then table.insert(detail, status.error) end
    for _, err in status.errors or {} do table.insert(detail, err.error .. "\n" .. err.path) end
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

function Model.folderState(snapshot, folder, view)
    if not folder then return "UNKNOWN", "Status unavailable" end
    local status = folder.status or {}
    if folder.paused then return "UNLINKED", "Syncing paused; local files remain" end
    if not (snapshot.connection or {}).online or not (snapshot.connection or {}).fresh then
        return "UNKNOWN", "Current status unavailable; last reported values shown"
    end
    if Model.hasProblems({ folders = { folder } }) then return "ERROR", "Needs attention; open folder errors" end
    local activity = (snapshot.activity or {}).current
    local syncing = status.state == "syncing" or (status.needTotalItems or 0) > 0 or (activity and activity.folderId == folder.id)
    local scanning = string.sub(status.state or "", 1, 4) == "scan" or (view.scanning or {})[folder.id]
    if scanning and syncing then return "SCAN+SYNC", "Scanning local changes and applying synchronization" end
    if scanning then return "SCANNING", "Scanning local changes" end
    if syncing then return "SYNCING", "Applying changes" end
    if view.recentlyLinked == folder.id then return "LINKED", "Newly linked" end
    if status.state == "idle" then return "SYNCED", "Up to date" end
    return "UNKNOWN", "Folder status unavailable"
end

function Model.indicator(snapshot, status)
    local connection, lifecycle, counts = snapshot.connection or {}, snapshot.lifecycle or {}, snapshot.counts or {}
    if not status.ready then return "notify", "Worker unavailable" end
    if (lifecycle.canControl or lifecycle.canStart) and lifecycle.active == false then return "pause", "Service stopped" end
    if not connection.online then return "notify", "Connection unavailable" end
    if not connection.fresh or (counts.folderProblems or 0) > 0 or Model.hasProblems(snapshot) then return "notify", "Needs attention" end
    local scanning = snapshot.scanningFolders or Model.totals(snapshot).scanning
    local activity = snapshot.activityActive or (snapshot.activity or {}).current ~= nil
    if scanning > 0 and ((counts.syncingFolders or 0) > 0 or activity) then return "sync", "Scanning and syncing" end
    if scanning > 0 then return "sync", "Scanning" end
    if (counts.syncingFolders or 0) > 0 or activity then return "sync", "Syncing" end
    return "default", "Up to date"
end

function Model.newView(now)
    return { view = "panel-" .. tostring(now), sequence = 0, formSequence = 0,
        section = "folders", search = "", sort = "name",
        filters = { ready = true, active = true, errors = true, paused = true, unknown = true },
        more = false, scanning = {}, message = "", form = nil, confirm = nil }
end

return Model
