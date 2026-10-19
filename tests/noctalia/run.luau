local Model = require("../../hosts/noctalia/models/PanelModel.luau")
local Requests = require("../../hosts/noctalia/transport/Requests.luau")
local Frames = require("../../hosts/noctalia/transport/Frames.luau")
local Controller = require("../../hosts/noctalia/controllers/PanelController.luau")

local function equal(actual, expected, description)
    assert(actual == expected, description .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

-- The host codec turns empty tables into objects and null into nil.
equal(encode({}), "{}", "actual empty table encoding")
equal(decode("null"), nil, "actual JSON null")
for _, args in { { deviceIds = {} }, { folderIds = {} }, { deviceIds = {}, folderIds = {} } } do
    local request = { v = 2, type = "action", id = "shares", action = "folder.set-sharing", args = args }
    local raw = assert(Requests.encode(request, encode))
    for name in args do assert(string.find(raw, '"' .. name .. '":[]', 1, true), raw) end
    equal(request.args, args, "encoder does not replace caller arguments")
end
equal(Requests.encode({ args = { deviceIds = { "one", "two" } } }, encode),
    '{"args":{"deviceIds":["one","two"]}}', "nonempty sharing arrays")
equal(Requests.quote("a'$(touch bad)`x`"), "'a'\\''$(touch bad)`x`'", "shell quoting")
equal(Model.bool("false"), false, "toggle false string")

local parts = { '{"v":2,"type":', '"snapshot","state":{}}\n' }
local stream = Frames.new()
for index, data in parts do
    local frame, err, ack = Frames.push(stream, { transport = 1, frame = 1, index = index,
        count = 2, data = data, ack = index == 2 and "1:2" or nil }, index)
    assert(not err, err)
    if index == 2 then equal(frame, true, "frame completion"); equal(ack, "1:2", "batch ack")
    else equal(frame, nil, "partial frame") end
end
assert(select(2, Frames.push(stream, { transport = 1, frame = 1, index = 1, count = 1, data = "{}", ack = "1:1" }, 3)), "duplicate frame accepted")
stream = Frames.new()
Frames.push(stream, { transport = 1, frame = 1, index = 1, count = 3, data = "{" }, 0)
assert(select(2, Frames.push(stream, { transport = 1, frame = 1, index = 3, count = 3, data = "}", ack = "1:3" }, 1)), "missing chunk accepted")
assert(Frames.expired(stream, 30001), "missing chunk did not expire")

local oversized = Frames.new()
for index = 1, 2049 do
    local _, err = Frames.push(oversized, { transport = 1, frame = 1, index = index, count = 2049,
        data = index == 2049 and "x" or string.rep("x", 4096),
        ack = (index % 8 == 0 or index == 2049) and ("1:" .. tostring(index)) or nil }, 0)
    if index < 2049 then assert(not err, "frame below 8 MiB was rejected")
    else assert(err == "Transport frame exceeds the supported limit", "oversized frame was accepted") end
end

local localID = string.rep("AAAAAAA-", 7) .. "AAAAAAA"
local remoteID = string.rep("BBBBBBB-", 7) .. "BBBBBBB"
local snapshot = {
    identity = { deviceId = localID, version = "v2.1.3" }, connection = { online = true, fresh = true },
    lifecycle = { active = true, canControl = false }, counts = { folders = 2, devices = 1, connectedDevices = 1 },
    devices = { { id = localID, name = "Here" }, { id = remoteID, name = "Laptop", connected = true } },
    folders = {
        { id = "b", label = "Work", path = "/home/work/Photos", paused = false,
            devices = { { id = localID, remoteState = "local" }, { id = remoteID, remoteState = "shared" } },
            status = { state = "idle", errors = {}, globalFiles = 5 } },
        { id = "a", label = "Home", path = "/home/me/Photos", paused = true,
            devices = { { id = localID, remoteState = "local" } }, status = { state = "idle", errors = {} } },
    },
    pendingDevices = { { id = string.rep("CCCCCCC-", 7) .. "CCCCCCC", name = "New laptop", address = "tcp://127.0.0.1" } },
    pendingFolders = { offer = { offeredBy = { [remoteID] = { label = "Offered", receiveEncrypted = false, remoteEncrypted = false } } } },
    nearbyDevices = {}, webUi = { theme = "default" }, activity = {}, installation = {}, truncation = {},
}
local view = Model.newView(1)
local rows = Model.folderRows(snapshot, view)
equal(rows[1].id, "a", "duplicate labels retain deterministic IDs")
view.filters.paused = false
equal(#Model.folderRows(snapshot, view), 1, "paused filter")
view.search = "/work/"
equal(Model.folderRows(snapshot, view)[1].id, "b", "path search")
equal(Model.validDeviceId(remoteID), true, "device ID validation")

local values = { status = { ready = true, generation = "generation-1" },
    snapshot = { generation = "generation-1", state = snapshot, revision = 1, received = 1000 } }
local watchers, commands = {}, {}
local now = 1000
local host = {
    nowMs = function() return now end,
    json = { encode = encode, decode = decode },
    state = {
        get = function(key) return Model.copy(values[key]) end,
        set = function(key, value)
            values[key] = Model.copy(value)
            for _, callback in watchers[key] or {} do callback(Model.copy(value)) end
        end,
        watch = function(key, callback)
            watchers[key] = watchers[key] or {}; table.insert(watchers[key], callback)
        end,
    },
    pluginDir = function() return "/copied/package" end,
    pluginDataDir = function() return "/private/plugin-data" end,
    getConfig = function(key) return key == "webUi" and "default" or (key == "serviceState" and "enabled" or true) end,
    getenv = function() return "/home/test" end,
    expandPath = function(path) return path end,
    commandExists = function() return true end,
    copyToClipboard = function() return true end,
    openSettings = function() end,
    getColor = function(role) return role == "surface" and "#111111" or "#eeeeee" end,
    runAsync = function(args, callback) table.insert(commands, { args = args, callback = callback }); return true end,
}

local c = Controller.new(host, function() end)
c:setSnapshot(values.snapshot)
c:openForm("sharing", snapshot.folders[1])
c.view.form.selected[remoteID] = false
c.view.form.search = "hidden"
local token = c.view.form.token
c:setSnapshot({ generation = "generation-1", state = snapshot, revision = 2, received = 1100 })
equal(c.view.form.token, token, "refresh retains form identity")
equal(c.view.form.selected[remoteID], false, "refresh retains sharing draft")
c:submitForm()
local pending = c.view.pending
equal(values.intent.request.action, "folder.set-sharing", "sharing wired to action")
equal(#values.intent.request.args.deviceIds, 0, "remove all sharing")
equal(c:send("folder.rescan-all", {}), false, "repeat submission blocked")
c:setResults({ { id = "late", view = c.view.view, generation = "generation-1", ok = true } })
assert(c.view.pending, "unrelated result settled action")
c:setResults({ { id = pending.id, view = c.view.view, generation = "old", ok = true } })
assert(c.view.pending, "retired generation settled action")
c:setResults({ { id = pending.id, view = c.view.view, generation = "generation-1", ok = true } })
equal(c.view.form, nil, "settled save closes form")

local target = { folderId = "a" }
c:confirm("Forget A?", "folder.forget", target)
target.folderId = "b"
c:acceptConfirmation()
equal(c.view.pending, nil, "opening key cannot immediately confirm")
now += 301
c:acceptConfirmation()
equal(values.intent.request.args.folderId, "a", "confirmation freezes target")
c:setStatus({ generation = "generation-2", ready = true })
equal(c.view.pending, nil, "restart releases uncertain pending action")
assert(string.find(c.view.message, "may have completed", 1, true))
c.status = values.status
c:setSnapshot(values.snapshot)
c:openForm("addFolder")
pending = c.view.pending
c:setResults({ { id = pending.id, view = c.view.view, generation = pending.generation, ok = true, data = { folderId = "generated" } } })
c.view.form.path = "/missing/draft"
c:submitForm()
pending = c.view.pending
c:setResults({ { id = pending.id, view = c.view.view, generation = pending.generation, ok = false,
    code = "path_missing", error = "Directory is missing" } })
assert(c.view.confirm and c.view.confirm.args.createDirectory, "missing directory needs explicit confirmation")
equal(c.view.confirm.args.path, "/missing/draft", "directory creation freezes path")
c:cancel()
equal(c.view.form.path, "/missing/draft", "cancel creation retains draft")

c:openForm("deviceFolders", snapshot.devices[2])
assert(c.view.form.deviceId == remoteID, "configured device form did not open")
c.view.form.selected.b = false
local refreshed = Model.copy(snapshot)
table.insert(refreshed.folders, { id = "new-share", path = "/new", devices = { { id = remoteID } } })
c:setSnapshot({ generation = "generation-1", state = refreshed })
assert(c.view.form.selected["new-share"], "new sharing was marked for removal during refresh")
c:submitForm()
equal(#c.view.confirm.args.folderIds, 1, "refresh removed a newly added share")
equal(c.view.confirm.args.folderIds[1], "b", "explicitly unchecked share lost")
c:cancel()
c.view.form = { kind = "addFolder", path = "/missing/draft", token = 100, selected = {}, search = "" }
c:save()

-- Exercise the actual render functions and callbacks, with the pinned UI prelude.
noctalia = host
local rendered
panel = { setWantsSecondTicks = function() end, setNeedsFrameTick = function() end, render = function(tree) rendered = tree end, close = function() end }
local Store = require("../../hosts/noctalia/transport/SnapshotStore.luau")
local writer = Store.writer(host)
writer.push({ index = 1, count = 1, frame = 1, data = encode({ v = 2, type = "snapshot", state = snapshot }) }, "generation-1")
writer.commit(2, 1000)
local entry = loadEntry("hosts/noctalia/NoctaliaPanel.luau")
entry.onOpen()
entry.onFrameTick()
assert(rendered, "panel did not render")
entry.onClose()
local retained = host.state.get("view")
assert(retained.form and retained.form.path == "/missing/draft", "close discarded draft")
entry.onOpen()

local function validate(node)
    checkTree(node)
    assert(type(node.type) == "string" and type(node.props) == "table", "invalid native node")
    assert(#node.children <= 256, "native child limit exceeded")
    local keys = {}
    for _, child in node.children do
        if child.props.key then assert(not keys[child.props.key], "duplicate sibling key"); keys[child.props.key] = true end
        validate(child)
    end
end
local forms = {
    { "addFolder" }, { "sharing", snapshot.folders[1] }, { "addDevice" },
    { "acceptDevice", snapshot.pendingDevices[1] }, { "deviceFolders", snapshot.devices[2] },
    { "acceptFolder", { id = "offer", deviceId = remoteID, label = "Offered" } }, { "settings" },
}
for _, spec in forms do
    c.view.pending = nil
    c:openForm(spec[1], spec[2])
    c.view.pending = nil
    assert(c.view.form.kind == spec[1], "form failed to open: " .. spec[1])
    c:save()
    local components = {
        addFolder = "AddFolderForm", acceptFolder = "AddFolderForm", sharing = "FolderSharingForm",
        addDevice = "AddRemoteDeviceForm", acceptDevice = "AddRemoteDeviceForm", deviceFolders = "DeviceFoldersForm", settings = "SettingsMenu",
    }
    -- require is intentionally literal, matching the host module contract.
    local modules = {
        AddFolderForm = require("../../hosts/noctalia/ui/AddFolderForm.luau"),
        FolderSharingForm = require("../../hosts/noctalia/ui/FolderSharingForm.luau"),
        AddRemoteDeviceForm = require("../../hosts/noctalia/ui/AddRemoteDeviceForm.luau"),
        DeviceFoldersForm = require("../../hosts/noctalia/ui/DeviceFoldersForm.luau"),
        SettingsMenu = require("../../hosts/noctalia/ui/SettingsMenu.luau"),
    }
    validate(modules[components[spec[1]]].render(c, c.view.form))
end
local Picker = require("../../hosts/noctalia/ui/DirectoryPicker.luau")
c.view.form = { path = "/draft", token = 100 }
Picker.open(c, "/somewhere")
local callback = commands[#commands].callback
c:cancel()
callback({ exitCode = 0, stdout = encode({ path = "/late", parent = "/", entries = {} }) })
equal(c.view.form.path, "/draft", "late picker callback preserves canceled draft")
equal(c.view.form.picker, nil, "late picker callback cannot reopen browser")
print("Noctalia model, controller, JSON, frame and form checks passed")
local MultiSelect = require("../../hosts/noctalia/ui/SyncshellMultiSelect.luau")
local Invitations = require("../../hosts/noctalia/ui/Invitations.luau")
local many = {}
for index = 1, 256 do table.insert(many, { id = tostring(index), name = "Duplicate name" }) end
local manyForm = { token = 200, search = "", selected = { ["unavailable"] = true } }
validate(MultiSelect.render(c, manyForm, many, "Sharing"))
c.snapshot.pendingFolders = {}
for folder = 1, 32 do
    local offered = {}
    for device = 1, 16 do offered[tostring(device)] = { label = "Offer", receiveEncrypted = false, remoteEncrypted = false } end
    c.snapshot.pendingFolders[tostring(folder)] = { offeredBy = offered }
end
local invitationTree
withBudget(function() invitationTree = Invitations.render(c) end, 25)
validate(invitationTree)
c.view.form = { token = 201, picker = { path = "/", location = "/", after = "", history = {}, cursor = 1, parent = "/", entries = {} } }
for index = 1, 256 do table.insert(c.view.form.picker.entries, { name = tostring(index), path = "/" .. tostring(index) }) end
validate(Picker.render(c, c.view.form))
print("Noctalia maximum native list sizes passed")
