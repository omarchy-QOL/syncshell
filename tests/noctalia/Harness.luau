local Model = require("../../hosts/noctalia/models/PanelModel.luau")
local Store = require("../../hosts/noctalia/transport/SnapshotStore.luau")
local Harness = {}

function Harness.new()
    local h = { now = 1000, frame = 0, commands = {}, copied = {}, ticks = false }
    local values, watches = {}, {}
    h.host = {
        nowMs = function() return h.now end,
        json = { encode = encode, decode = decode },
        state = {
            get = function(key) return values[key] and decode(values[key]) end,
            set = function(key, value)
                values[key] = encode(value)
                for _, callback in watches[key] or {} do callback(decode(values[key])) end
            end,
            watch = function(key, callback)
                watches[key] = watches[key] or {}; table.insert(watches[key], callback)
            end,
        },
        pluginDir = function() return "/package" end,
        pluginDataDir = function() return "/private/plugin-data" end,
        getConfig = function(key) return key == "webUi" and "default" or (key == "serviceState" and "enabled" or false) end,
        getenv = function(key) return key == "HOME" and "/home/fixture" or "fixture" end,
        expandPath = function(path) return path end,
        commandExists = function() return true end,
        copyToClipboard = function(text) table.insert(h.copied, text); return true end,
        openSettings = function() h.settingsOpened = true end,
        getColor = function(role) return role == "surface" and "#101010" or "#eeeeee" end,
        runAsync = function(args, callback) table.insert(h.commands, { args = args, callback = callback }); return true end,
    }
    h.panel = {
        render = function(tree)
            checkTree(tree)
            local function validate(node, depth)
                assert(depth <= 32 and #node.children <= 256, "native tree limit exceeded")
                for _, child in node.children do validate(child, depth + 1) end
            end
            validate(tree, 1)
            h.tree = tree
        end,
        close = function() h.entry.onClose() end,
        setNeedsFrameTick = function(value) h.ticks = value end,
        setWantsSecondTicks = function(value) h.seconds = value end,
    }
    h.host.state.set("status", { generation = "test-generation", ready = true })
    h.writer = Store.writer(h.host)
    return setmetatable(h, { __index = Harness })
end

function Harness:load()
    -- Entry globals are installed by the caller, as in the host VM.
    self.entry = loadEntry("hosts/noctalia/NoctaliaPanel.luau")
    self.entry.onOpen()
end

function Harness:snapshot(state)
    self.frame += 1
    local data = encode({ v = 2, type = "snapshot", state = state })
    local count = math.ceil(#data / 4096)
    for index = 1, count do
        self.writer.push({ index = index, count = count, frame = self.frame,
            data = string.sub(data, (index - 1) * 4096 + 1, index * 4096) }, "test-generation")
    end
    self.writer.commit(self.frame, self.now)
    if self.entry then while self.ticks do withBudget(self.entry.onFrameTick, 25) end end
end

function Harness:nodes()
    local rows = {}
    local function visit(node)
        table.insert(rows, node)
        for _, child in node.children do visit(child) end
    end
    visit(self.tree)
    return rows
end

function Harness:find(value)
    for _, node in self:nodes() do
        if node.props.key == value or node.props.text == value then return node end
    end
    return nil
end

function Harness:click(value)
    local node = assert(self:find(value), "missing control: " .. value)
    assert(node.props.enabled ~= false, "disabled control: " .. value)
    assert(type(node.props.onClick) == "function", "control is not clickable: " .. value)
    local ok, err = pcall(function() withBudget(node.props.onClick, 25) end)
    assert(ok, value .. ": " .. tostring(err))
end

function Harness:edit(field, value)
    for _, node in self:nodes() do
        if node.type == "input" and node.props.key and
            (node.props.key == field or string.find(node.props.key, "-" .. field .. "-", 1, true)
                or string.sub(node.props.key, 1, #field + 1) == field .. "-") then
            assert(node.props.enabled ~= false, "disabled input: " .. field)
            node.props.onChange(value)
            return
        end
    end
    error("missing input: " .. field)
end

function Harness:text()
    local text = {}
    for _, node in self:nodes() do if node.props.text then table.insert(text, node.props.text) end end
    return table.concat(text, "\n")
end

function Harness:settle(ok, message, code, data)
    local intent = assert(self.host.state.get("intent"), "no submitted intent")
    self.host.state.set("results", { { id = intent.id, view = intent.view, generation = intent.generation,
        ok = ok, error = message, code = code, data = data } })
end

function Harness:advance(ms)
    self.now += ms
    if self.seconds then
        assert(self.entry.update, "second ticks require the native update entry")
        self.entry.update()
    end
end

function Harness.fixture()
    return { identity = { deviceId = "LOCAL", version = "v2.1.3" },
        connection = { online = true, fresh = true }, lifecycle = { active = true, canControl = false },
        devices = { { id = "REMOTE", name = "Laptop", connected = true, paused = false } },
        folders = {}, pendingFolders = {}, pendingDevices = {}, nearbyDevices = {},
        counts = { folders = 0, devices = 1, connectedDevices = 1 }, webUi = { theme = "default" },
        installation = { available = true, executablePath = "/usr/bin/syncthing" }, activity = {}, truncation = {} }
end

return Harness
