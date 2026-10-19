local now = 1000
local stored = { intent = encode({ generation = "retired", id = "old", view = "old", request = {} }) }
local values = setmetatable({}, {
    __index = function(_, key) return stored[key] and decode(stored[key]) end,
    __newindex = function(_, key, value) stored[key] = encode(value) end,
})
local watches, commands, writes = {}, {}, {}
local streamCallback
local defaults = { configPath = "", endpoint = "", credentialFile = "", tlsCertificate = "", expectedDeviceId = "",
    insecureTls = false, lifecycleAuthorized = false, lifecycleUnit = "syncthing.service", lifecycleConfig = "",
    serviceState = "enabled", refreshSeconds = 60, probeSeconds = 15, webUi = "default", brandedIcon = true }
local function copy(value) return decode(encode(value)) end
noctalia = {
    pluginDir = function() return "/copied path/package'quote" end,
    pluginDataDir = function() return "/private/plugin-data" end,
    getenv = function() return "/run/user/1000" end,
    nowMs = function() return now end,
    getConfig = function(key) assert(defaults[key] ~= nil, key); return defaults[key] end,
    getColor = function() return "#101010" end,
    json = { encode = encode, decode = decode },
    state = {
        get = function(key) return copy(values[key]) end,
        set = function(key, value)
            values[key] = value
            if watches[key] then watches[key](copy(value)) end
        end,
        watch = function(key, callback) watches[key] = callback end,
    },
    writeFile = function(path, data) writes[path] = data; return true end,
    runAsync = function(args, callback) table.insert(commands, { args = args, callback = callback }); return true end,
    runStream = function(command, callback)
        assert(string.find(command, "exec '", 1, true) == 1)
        assert(string.find(command, "package'\\''quote", 1, true))
        streamCallback = callback
        return true
    end,
}
local service = loadEntry("hosts/noctalia/NoctaliaService.luau")
assert(streamCallback, "entry did not initialize at module load")
assert(next(writes) == nil, "retained intent was replayed")
local oldCallback = streamCallback
local directory = "/run/user/1000/syncshell-noctalia/generation-123"
streamCallback(encode({ transport = 1, type = "ready", directory = directory }))
local sequence = 0
local function receive(frame)
    sequence += 1
    local line = encode({ transport = 1, frame = sequence, index = 1, count = 1,
        data = encode(frame) .. "\n", ack = tostring(sequence) .. ":1" })
    withBudget(function() streamCallback(line) end, 25)
end
receive({ v = 2, type = "hello", build = { version = "test" } })
receive({ v = 2, type = "snapshot", revision = 1, state = { webUi = { theme = "default" } } })
assert(values.status.ready)
local streamMax, readerMax = 0, 0
for iteration = 1, 3 do
    local prefix = '{"v":2,"type":"snapshot","revision":' .. tostring(iteration + 1) .. ',"state":{"padding":"'
    local suffix = '","webUi":{"theme":"default"}}}\n'
    local rawSize = 8 * 1024 * 1024
    sequence += 1
    local count = math.ceil(rawSize / (4 * 1024))
    for index = 1, count do
        local token = (index % 8 == 0 or index == count) and (tostring(sequence) .. ":" .. tostring(index)) or nil
        local first = index == 1 and prefix or ""
        local last = index == count and suffix or ""
        local size = math.min(4 * 1024, rawSize - (index - 1) * 4 * 1024)
        local data = first .. string.rep(string.char(96 + iteration), size - #first - #last) .. last
        local line = encode({ transport = 1, frame = sequence, index = index, count = count,
            data = data, ack = token })
        streamMax = math.max(streamMax, withBudget(function() streamCallback(line) end, 25))
        assert(values.status.ready, values.status.error)
    end
    local SnapshotStore = require("../../hosts/noctalia/transport/SnapshotStore.luau")
    local decoded
    local reading = false
    local reader = SnapshotStore.reader(noctalia, function(value) decoded = value end, function(value) reading = value end)
    reader.select(values.snapshot)
    while reading do readerMax = math.max(readerMax, withBudget(reader.step, 25)) end
    assert(decoded.state.padding, values.status.error or "missing snapshot")
    assert(#decoded.state.padding == 8 * 1024 * 1024 - #prefix - #suffix, "large snapshot was truncated")
end
assert(streamMax < 25 and readerMax < 25, "full-frame callbacks exceeded 25 ms")
print(string.format("Three full 8 MiB snapshots: max stream %.2f ms, reader %.2f ms", streamMax, readerMax))
receive({ v = 2, type = "snapshot", revision = 5, state = { webUi = { theme = "default" } } })
service.update()
local slot = directory .. "/request-slot.json"
local request = decode(writes[slot])
assert(request.type == "configure", "service did not configure operational intervals")
assert(request.config.desiredServiceState == "enabled", "preferred service state was not published")
receive({ v = 2, type = "result", id = request.id, ok = false,
    error = { code = "invalid_config", message = "Invalid interval" } })
assert(string.find(values.status.backgroundError, "Invalid interval", 1, true), "background failure was hidden")
receive({ v = 2, type = "snapshot", revision = 6, state = { webUi = { theme = "default" } } })
assert(values.status.backgroundError, "snapshot erased background failure")
local intent = { id = "view-1", generation = directory, view = "panel-1",
    request = { v = 2, type = "action", id = "view-1", action = "folder.set-sharing", args = { folderId = "a", deviceIds = {} } } }
watches.intent(intent)
assert(values.status.busy == intent.id)
assert(string.find(writes[slot], '"deviceIds":[]', 1, true))
local forwarding = commands[#commands]
assert(forwarding.args[4] == "request")
forwarding.callback({ exitCode = 0 })
assert(values.status.busy == intent.id, "delivery incorrectly settled the action")
local count = #commands
watches.intent(intent)
assert(#commands == count, "pending intent was replayed")
receive({ v = 2, type = "result", id = "unrelated", ok = true })
assert(values.status.busy == intent.id, "unrelated result settled action")
receive({ v = 2, type = "result", id = intent.id, ok = true })
assert(values.status.busy == nil)
count = #commands
watches.intent(intent)
assert(#commands == count, "settled intent was replayed")
for index = 2, 38 do
    intent.id = "view-" .. index
    intent.request.id = intent.id
    watches.intent(copy(intent))
    receive({ v = 2, type = "result", id = intent.id, ok = true })
end
assert(#values.results == 32, "settled results are not bounded")
intent.id, intent.request.id = "uncertain", "uncertain"
watches.intent(copy(intent))
commands[#commands].callback({ exitCode = 1 })
assert(values.status.ready == false and values.status.busy == nil)
assert(values.results[#values.results].code == "uncertain")
local saved = writes[slot]
receive({ v = 2, type = "result", id = "uncertain", ok = true })
assert(values.results[#values.results].code == "uncertain", "late result was accepted after retirement")
now += 3000
service.update()
assert(streamCallback ~= oldCallback, "restart did not install a fresh generation callback")
assert(writes[slot] == saved, "uncertain request was replayed on restart")
oldCallback(encode({ transport = 1, type = "ready", directory = directory }))
assert(values.status.generation ~= directory, "late readiness revived retired generation")
service.onExit()
assert(values.status.ready == false)
print("Noctalia service generation, delivery, settlement and recovery checks passed")
