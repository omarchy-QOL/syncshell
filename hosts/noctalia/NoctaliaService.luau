local Model = require("./models/PanelModel.luau")
local Frames = require("./transport/Frames.luau")
local SnapshotStore = require("./transport/SnapshotStore.luau")
local JsonFrame = require("./transport/JsonFrame.luau")
local Requests = require("./transport/Requests.luau")
local Settings = require("./controllers/SettingsController.luau")
local Palette = require("./controllers/ThemePaletteController.luau")

local binary = noctalia.pluginDir() .. "/bin/syncshell-core"
local root = noctalia.getenv("XDG_RUNTIME_DIR")
local settings = Settings.read(noctalia)
local directory = noctalia.state.get("workerDirectory")
local epoch, attempt, retryAt = 0, 0, 0
local status, pending, results = {}, nil, {}
local frames = Frames.new()
local jsonFrame
local snapshotStore = SnapshotStore.writer(noctalia)
local pingAt, pingBusy, startedAt = 0, false, 0
local configureNeeded = false
local alive = true
local lastPalette, themeCheckAt, currentTheme = nil, 0, nil
local cleanupReady = false

local function publish()
    noctalia.state.set("status", status)
end

local function result(id, view, ok, data, message, code)
    table.insert(results, { id = id, view = view, generation = status.generation,
        ok = ok, data = data, error = message, code = code })
    while #results > 32 do table.remove(results, 1) end
    noctalia.state.set("results", results)
end

local function control(op, extra, callback)
    if not directory then return false end
    local args = { binary, "native-control", directory, op }
    if extra then table.insert(args, extra) end
    return noctalia.runAsync(args, callback or function() end)
end

local function retire(message)
    epoch += 1
    if pending then
        result(pending.id, pending.view, false, nil,
            "Connection interrupted; the action may have completed. Refresh before trying again.", "uncertain")
        pending = nil
    end
    status.ready, status.busy, status.error = false, nil, message
    publish()
    if directory then control("stop") end
    attempt += 1
    retryAt = noctalia.nowMs() + math.min(60000, 1000 * 2 ^ math.min(attempt, 6))
    pingBusy = false
end

local function dispatch(intent)
    local raw, err = Requests.encode(intent.request, noctalia.json.encode)
    if not raw or #raw >= 8 * 1024 * 1024 or string.find(raw, "[\r\n]") then
        result(intent.id, intent.view, false, nil, err or "Request is too large", "invalid_request")
        return
    end
    local ownEpoch = epoch
    pending = intent
    pending.started = noctalia.nowMs()
    status.busy = intent.id
    publish()
    if not noctalia.writeFile(directory .. "/request-slot.json", raw) then
        retire("Cannot write the private request file")
        return
    end
    local launched = control("request", nil, function(reply)
        if ownEpoch ~= epoch then return end
        if reply.exitCode ~= 0 then retire("Request delivery is uncertain") end
    end)
    if not launched then retire("Cannot launch request forwarding") end
end

local function receive(frame)
    if type(frame) ~= "table" or frame.v ~= 2 then
        retire("Core protocol 2 is required")
    elseif frame.type == "hello" then
        status.build = frame.build
    elseif frame.type == "snapshot" then
        currentTheme = frame.state.webUi and frame.state.webUi.theme
        snapshotStore.commit(frame.revision, noctalia.nowMs())
        noctalia.state.set("summary", { generation = status.generation,
            state = { counts = frame.state.counts, lifecycle = frame.state.lifecycle, connection = frame.state.connection,
                activityActive = (frame.state.activity or {}).current ~= nil, scanningFolders = Model.totals(frame.state).scanning } })
        status.ready, status.error = true, nil
        attempt = 0
        publish()
    elseif frame.type == "result" then
        if pending and pending.id == frame.id then
            if pending.view == "service" then
                local operation = pending.request.action or pending.request.type
                if not frame.ok then
                    status.backgroundError = operation .. ": " .. ((frame.error or {}).message or "Background action failed")
                    status.backgroundOperation = operation
                elseif status.backgroundOperation == operation then
                    status.backgroundError, status.backgroundOperation = nil, nil
                end
            end
            if frame.ok and (pending.request.action == "webui.apply-profile" or pending.request.action == "webui.refresh-profile")
                and pending.request.args.profile == "themed" then
                lastPalette = Palette.signature(pending.request.args.palette)
            end
            result(frame.id, pending.view, frame.ok, frame.data,
                frame.error and frame.error.message, frame.error and frame.error.code)
            pending = nil
            status.busy = nil
            publish()
        end
    elseif frame.type == "end" or frame.type == "fatal" then
        retire(frame.message or "The core worker stopped")
    else
        retire("Unsupported core frame")
    end
end

local function start()
    epoch += 1
    local ownEpoch = epoch
    frames, directory, results = Frames.new(), nil, {}
    startedAt, retryAt = noctalia.nowMs(), 0
    configureNeeded = true
    status = { ready = false, generation = "starting-" .. tostring(startedAt) }
    noctalia.state.set("results", results)
    publish()
    if not root or root == "" then
        retire("XDG_RUNTIME_DIR is required for the private worker")
        return
    end
    if not cleanupReady then
        local dataDir = noctalia.pluginDataDir()
        if dataDir then
            local cleanupArgs = { binary, "native-save-cleanup", dataDir }
            for _, arg in Settings.arguments(settings, noctalia.pluginDir()) do table.insert(cleanupArgs, arg) end
            noctalia.runAsync(cleanupArgs, function(reply)
                if ownEpoch ~= epoch then return end
                cleanupReady = reply.exitCode == 0
                noctalia.state.set("cleanup", { ready = cleanupReady,
                    path = dataDir .. "/syncshell-noctalia-cleanup/cleanup.sh" })
            end)
        end
    end
    local args = { binary, "native-stream", root .. "/syncshell-noctalia" }
    for _, arg in Settings.arguments(settings, noctalia.pluginDir()) do table.insert(args, arg) end
    for i, arg in args do args[i] = Requests.quote(arg) end
    local launched = noctalia.runStream("exec " .. table.concat(args, " "), function(line)
        if ownEpoch ~= epoch or not alive then return end
        local part = noctalia.json.decode(line)
        if type(part) == "table" and part.type == "ready" and part.transport == 1 then
            if directory or type(part.directory) ~= "string"
                or not string.match(part.directory, "^" .. string.gsub(root, "(%W)", "%%%1")
                    .. "/syncshell%-noctalia/generation%-%d+$") then
                retire("Invalid worker generation")
                return
            end
            directory = part.directory
            status.generation = directory
            noctalia.state.set("workerDirectory", directory)
            pingAt = 0
            publish()
            return
        end
        if not directory then retire("Core did not publish readiness"); return end
        local complete, err, ack = Frames.push(frames, part, noctalia.nowMs())
        if err then retire(err); return end
        if part.index == 1 then jsonFrame = JsonFrame.new(noctalia.json.decode) end
        local frame, parseError = jsonFrame:feed(part.data, complete == true)
        if parseError then retire(parseError); return end
        if part.index == 1 and (not jsonFrame.root or type(jsonFrame.root.type) ~= "string") then
            retire("Core frame header must precede its payload"); return
        end
        if jsonFrame.root.type == "snapshot" then snapshotStore.push(part, status.generation) end
        if ack and not control("ack", ack, function(reply)
            if ownEpoch == epoch and reply.exitCode ~= 0 then retire("Output acknowledgement failed") end
        end) then
            retire("Cannot acknowledge core output")
            return
        end
        if complete then receive(frame) end
    end)
    if not launched then retire("Cannot start the bundled core worker") end
end

noctalia.state.watch("intent", function(intent)
    if type(intent) ~= "table" or intent.generation ~= status.generation then return end
    if type(intent.id) ~= "string" or #intent.id > 128 or type(intent.view) ~= "string"
        or type(intent.request) ~= "table" or intent.request.id ~= intent.id then return end
    for _, settled in results do if settled.id == intent.id then return end end
    if pending and pending.id == intent.id then return end
    if not status.ready or pending then
        result(intent.id, intent.view, false, nil, "Wait for the current action or reconnect", "busy")
        return
    end
    dispatch(intent)
end)

function update()
    if not alive then return end
    local now = noctalia.nowMs()
    if retryAt > 0 then
        if now >= retryAt then start() end
        return
    end
    if Frames.expired(frames, now) or (not directory and now - startedAt > 10000) then
        retire("Core startup or output timed out")
        return
    end
    if pending and now - pending.started > 180000 then
        retire("Action timed out; its outcome is uncertain")
        return
    end
    if directory and not pingBusy and now >= pingAt then
        local ownEpoch = epoch
        pingBusy, pingAt = true, now + 5000
        if not control("ping", nil, function(reply)
            if ownEpoch ~= epoch then return end
            pingBusy = false
            if reply.exitCode ~= 0 then retire("Core worker is unavailable") end
        end) then
            retire("Cannot check worker liveness")
        end
    end
    if status.ready and not pending and configureNeeded then
        configureNeeded = false
        local id = "configure-" .. tostring(epoch)
        dispatch({ id = id, view = "service", request = { v = 2, type = "configure", id = id,
            config = { refreshIntervalSeconds = settings.refreshSeconds,
                probeIntervalSeconds = settings.probeSeconds, desiredServiceState = settings.serviceState } } })
    end
    if status.ready and not pending and now >= themeCheckAt then
        themeCheckAt = now + 5000
        if currentTheme == "syncshell-noctalia-themed" then
            local colors = Palette.read(noctalia)
            if colors and Palette.signature(colors) ~= lastPalette then
                themeCheckAt = now + 60000
                local id = "palette-" .. tostring(now)
                dispatch({ id = id, view = "service", request = { v = 2, type = "action", id = id,
                    action = "webui.refresh-profile", args = { profile = "themed", palette = colors } } })
            end
        end
    end
end

function onConfigChanged()
    settings = Settings.read(noctalia)
    cleanupReady = false
    retire("Reconnecting with updated settings")
end

function onExit()
    alive = false
    retire("Plugin service stopped")
end

-- A reload may retain the old generation in the host's state store.
if directory then
    status = { generation = directory }
    retire("Replacing the previous worker")
else
    start()
end
