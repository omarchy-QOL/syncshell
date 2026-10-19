local Harness = require("./Harness.luau")
local Model = require("../../hosts/noctalia/models/PanelModel.luau")
local failures = 0
local function scenario(name, test)
    local ok, err = pcall(test)
    print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
    if not ok then failures += 1 end
end
local function start(state)
    local h = Harness.new()
    noctalia, panel = h.host, h.panel
    h:load()
    h:snapshot(state)
    return h
end

scenario("P01 confirmed and unconfirmed groups expose acceptance", function()
    local s = Harness.fixture()
    for index = 1, 43 do table.insert(s.folders, { id = "folder-" .. index, path = "/data/" .. index,
        devices = { { id = "REMOTE", remoteState = index == 43 and "paused" or "valid" } }, status = { state = "idle" } }) end
    table.insert(s.folders, { id = "offered", path = "/data/offered", devices = { { id = "REMOTE", remoteState = "notSharing" } }, status = {} })
    local h = start(s)
    h:click("Devices"); h:click("Shared folders")
    assert(string.find(h:text(), "Existing shares", 1, true), "confirmed group missing")
    assert(string.find(h:text(), "Unconfirmed shares", 1, true), "unconfirmed group missing")
    assert(h:find("save-device-folders").props.enabled == false, "no-change removal enabled")
    h:click("shares-unconfirmed")
    assert(string.find(h:text(), "Remote is not sharing back", 1, true))
    h:find("share-offered").props.onChange("false")
    s.folders[44].devices[1].remoteState = "valid"
    h:snapshot(s)
    h:click("Back to form"); h:click("shares-confirmed")
    h:edit("share-search-1-confirmed", "offered")
    assert(h:find("share-offered").props.checked == false, "acceptance reset draft")
    h:edit("share-search-1-confirmed", "Remote folder paused")
    assert(string.find(h:text(), "Remote folder paused", 1, true))
    s.connection.fresh = false
    h:snapshot(s)
    h:click("Back to form")
    assert(string.find(h:text(), "0 confirmed", 1, true), "stale acceptance claimed")
end)

scenario("P02 unselected folder errors remain visible and stale", function()
    local s = Harness.fixture()
    s.folders = { { id = "selected", path = "/clean", devices = {}, status = { state = "idle" } },
        { id = "broken", path = "/other/important", devices = {}, status = { state = "error", pullErrors = 7,
            errors = { { path = "denied.txt", error = "permission denied" } } } } }
    local h = start(s)
    h:click("More")
    assert(string.find(h:text(), "/other/important", 1, true), "unselected error absent")
    assert(string.find(h:text(), "permission denied", 1, true))
    assert(string.find(h:text(), "1 of 7", 1, true), "bounded errors not explained")
    s.connection = { online = false, fresh = false, error = { code = "unauthorized", message = "Authentication failed" } }
    h:snapshot(s)
    assert(string.find(h:text(), "Last reported errors", 1, true))
    h:click("Less")
    assert(string.find(h:text(), "Authentication failed", 1, true), "important failure hidden behind More")
end)

scenario("P03 aggregate totals and timed success preserve failures", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", status = { state = "idle", globalFiles = 5, globalBytes = 1024 }, devices = {} },
        { id = "two", path = "/two", status = { state = "syncing", globalFiles = 7, globalBytes = 2048 }, devices = {} } }
    local h = start(s)
    assert(string.find(h:text(), "12 files", 1, true), "tracked file total missing")
    assert(string.find(h:text(), "3.0 KiB", 1, true), "tracked byte total missing")
    h:click("Refresh")
    assert(string.find(h:text(), "Refreshing", 1, true), "generic busy message")
    h:settle(true)
    h:advance(6000)
    assert(not string.find(h:text(), "Refreshed", 1, true), "success notice did not expire")
    h:click("Refresh"); h:settle(false, "Check credentials", "unauthorized")
    h:advance(60000)
    assert(string.find(h:text(), "Check credentials", 1, true), "timer erased failure")
end)
scenario("P01 unavailable folder sharing cannot become local-only", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", status = { state = "idle" } } }
    local h = start(s)
    h:click("Sharing")
    assert(h:find("Save sharing").props.enabled == false, "unknown shares may be cleared")
    assert(string.find(h:text(), "Sharing data unavailable", 1, true))
    s.folders[1].devices = { { id = "REMOTE" } }
    h:snapshot(s)
    h:click("shares-sharing")
    assert(h:find("share-REMOTE").props.checked, "newly available sharing was not seeded")
    s.connection.fresh = false; h:snapshot(s); h:click("Back to form")
    assert(h:find("Save sharing").props.enabled == false, "stale full replacement allowed")
end)

scenario("P01 disappeared and reappearing shares reset stale removal intent", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", status = {}, devices = { { id = "REMOTE", remoteState = "valid" } } } }
    local h = start(s)
    h:click("Devices"); h:click("Shared folders"); h:click("shares-confirmed")
    h:find("share-one").props.onChange(false)
    s.folders[1].devices = {}; h:snapshot(s)
    s.folders[1].devices = { { id = "REMOTE", remoteState = "valid" } }; h:snapshot(s)
    assert(h:find("share-one").props.checked, "newly restored share inherits stale removal")
    h:click("Back to form")
    assert(h:find("save-device-folders").props.enabled == false)
end)

scenario("P06 device validation normalizes input and rejects local and known IDs", function()
    local s = Harness.fixture()
    local localId = string.rep("AAAAAAA-", 7) .. "AAAAAAA"
    local knownId = string.rep("BBBBBBB-", 7) .. "BBBBBBB"
    local newId = string.rep("CCCCCCC-", 7) .. "CCCCCCC"
    s.identity.deviceId, s.devices[1].id = localId, knownId
    local h = start(s)
    h:click("Devices"); h:click("Add device")
    assert(h:find("submit-device").props.enabled == false, "empty ID can submit")
    h:edit("deviceId", localId)
    assert(h:find("submit-device").props.enabled == false, "local ID can submit")
    h:edit("deviceId", knownId)
    assert(h:find("submit-device").props.enabled == false, "duplicate ID can submit")
    h:edit("deviceId", "  " .. string.lower(newId) .. "  ")
    h:click("submit-device")
    assert(h.host.state.get("intent").request.args.deviceId == newId)
end)

scenario("P06 folder invitation changes invalidate acceptance without erasing draft", function()
    local s = Harness.fixture()
    s.pendingFolders = { offered = { offeredBy = { REMOTE = { label = "Shared project" } } } }
    local h = start(s)
    h:click("Accept"); h:edit("path", "/my/project")
    s.pendingFolders.offered.offeredBy.REMOTE.receiveEncrypted = true; h:snapshot(s)
    assert(h:find("Add folder").props.enabled == false, "newly encrypted offer accepted inline")
    assert(string.find(h:text(), "requires the Web UI", 1, true))
    s.pendingFolders = {}; h:snapshot(s)
    assert(h:find("Add folder").props.enabled == false, "vanished offer accepted")
    assert(h.host.state.get("view").form.path == "/my/project")
end)

scenario("P04 search, directional choice and filter disclosure preserve identity", function()
    local s = Harness.fixture()
    for i = 1, 20 do table.insert(s.folders, { id = string.format("f%02d", i), path = "/data/" .. i .. "/Photos",
        label = "Photos", status = { state = "idle" }, devices = {} }) end
    local h = start(s)
    h:click("select-folder")
    assert(not h:find("folder-sort"), "filters consume space while collapsed")
    h:click("folder-filters"); assert(h:find("folder-sort"))
    h:edit("search-folder", "f19")
    assert(string.find(h:text(), "/data/19/Photos", 1, true))
    h:find("search-folder").props.onSubmit()
    assert(h.host.state.get("view").folderId == "f19")
    h:click("select-folder"); h:edit("search-folder", "")
    h.entry.onKey("Alt+Down", true); h.entry.onKey("Alt+Return", true)
    assert(h.host.state.get("view").folderId == "f20")
    h:click("select-folder"); h:edit("search-folder", "not present")
    assert(h:find("No folders match the search and filters"))
    assert(h.host.state.get("view").folderId == "f20", "search erased hidden selection")
end)

scenario("P07 picker location, history, late replies and return preserve draft", function()
    local h = start(Harness.fixture())
    h:click("Add folder"); h:settle(true, nil, nil, { folderId = "new" })
    h:edit("path", "/start"); h:edit("label", "My draft"); h:click("Browse directories")
    local first = h.commands[#h.commands]
    first.callback({ exitCode = 0, stdout = encode({ path = "/start", parent = "/", entries = { { name = "child", path = "/start/child" } }, next = "" }) })
    h:edit("picker-location", "/typed")
    h:find("picker-location-/start-").props.onSubmit()
    local second = h.commands[#h.commands]
    assert(second.args[3] == "/typed")
    second.callback({ exitCode = 0, stdout = encode({ path = "/typed", parent = "/", entries = {}, next = "" }) })
    h:click("picker-back")
    local back = h.commands[#h.commands]
    assert(back.args[3] == "/start")
    back.callback({ exitCode = 0, stdout = encode({ path = "/start", parent = "/", entries = {}, next = "" }) })
    second.callback({ exitCode = 0, stdout = encode({ path = "/late", entries = {} }) })
    h:click("Use this directory")
    local form = h.host.state.get("view").form
    assert(form.path == "/start" and form.label == "My draft" and form.folderId == "new")
    h:click("Browse directories")
    h:click("Cancel")
    h.commands[#h.commands].callback({ exitCode = 1, stdout = "" })
    assert(h.host.state.get("view").form.picker == nil)
    assert(h.host.state.get("view").form.label == "My draft")
end)

scenario("P01 remote pause, disconnect and unknown acceptance stay distinct", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", status = {}, devices = { { id = "REMOTE", remoteState = "paused" } } } }
    local h = start(s)
    h:click("Devices"); h:click("Shared folders"); h:click("shares-confirmed")
    assert(string.find(h:text(), "Remote folder paused", 1, true))
    s.devices[1].paused = true; h:snapshot(s); h:click("Back to form"); h:click("shares-unconfirmed")
    assert(string.find(h:text(), "device paused", 1, true))
    s.devices[1].paused, s.devices[1].connected = false, false; h:snapshot(s)
    assert(string.find(h:text(), "device offline", 1, true))
    s.devices[1].connected = true; s.folders[1].devices[1].remoteState = "unknown"; h:snapshot(s)
    assert(string.find(h:text(), "Remote acceptance unconfirmed", 1, true))
    h.entry.onKey("Alt+Return", true); h:click("Back to form")
    h:click("save-device-folders"); h:advance(301); h:click("confirmation-accept")
    assert(h.host.state.get("intent").request.args.folderIds[1] == "one")
end)

scenario("P02 error copy, folder route, retry, clean and unavailable", function()
    local s = Harness.fixture()
    s.folders = { { id = "broken", path = "/broken", devices = {}, status = { state = "error", error = "Access denied" } } }
    local h = start(s)
    h:click("More"); h:click("Copy error details")
    assert(string.find(h.copied[1], "/broken", 1, true) and string.find(h.copied[1], "Access denied", 1, true))
    h:click("Show folder"); assert(h.host.state.get("view").folderId == "broken")
    h:click("Refresh")
    assert(h.host.state.get("intent").request.action == "folder.recheck-errors", "refresh did not recheck problem folders")
    h:settle(false, "Recheck failed", "request_failed")
    assert(h:find("Recheck folder errors").props.enabled)
    h:click("Recheck folder errors"); h:settle(true)
    s.folders[1].status = { state = "idle" }; h:snapshot(s)
    assert(string.find(h:text(), "Syncthing status: clean", 1, true))
    s.connection.online, s.connection.fresh = false, false; h:snapshot(s)
    assert(string.find(h:text(), "Syncthing status: unavailable", 1, true))
end)

scenario("P03 actual bar and panel distinguish scanning, activity and stopped service", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", devices = {}, status = { state = "scanning" } } }
    local h = start(s)
    local icon, tooltip
    barWidget = { setImage = function(path) icon = path end, setTooltip = function(text) tooltip = text end }
    local bar = loadEntry("hosts/noctalia/NoctaliaBarEntry.luau")
    local function summary()
        h.host.state.set("summary", { generation = "test-generation", state = { counts = s.counts,
            lifecycle = s.lifecycle, connection = s.connection, activityActive = s.activity.current ~= nil,
            scanningFolders = Model.totals(s).scanning } })
    end
    summary()
    assert(string.find(icon, "status-sync.svg", 1, true) and string.find(tooltip, "Scanning", 1, true))
    assert(string.find(h:text(), "SCANNING", 1, true))
    s.activity.current = { folderId = "one", action = "removing", path = "/one/gone", detail = "gone" }
    h:snapshot(s); summary()
    assert(string.find(h:text(), "SCAN+SYNC", 1, true))
    assert(string.find(tooltip, "Scanning and syncing", 1, true))
    assert(h.seconds); h:advance(1000)
    assert(string.find(h:text(), "File syncing.", 1, true))
    s.connection.fresh = false; h:snapshot(s); summary()
    assert(not h.seconds and string.find(h:text(), "Last reported activity", 1, true))
    assert(string.find(icon, "status-notify.svg", 1, true))
    s.lifecycle.active, s.lifecycle.canStart = false, true; h:snapshot(s); summary()
    assert(string.find(icon, "status-pause.svg", 1, true))
    local serviceToggle
    for _, node in h:nodes() do if node.type == "toggle" then serviceToggle = node end end
    assert(serviceToggle.props.enabled, "authorized stopped service cannot start")
    serviceToggle.props.onChange(true); h:advance(301); h:click("confirmation-accept")
    assert(h.host.state.get("intent").request.action == "lifecycle.start")
end)

scenario("P06 in-form folder sources retain offer identity and route encryption", function()
    local s = Harness.fixture()
    s.pendingFolders = { plain = { offeredBy = { REMOTE = { label = "Shared" } } },
        secret = { offeredBy = { REMOTE = { label = "Secret", remoteEncrypted = true } } } }
    local h = start(s)
    h:click("Add folder"); h:settle(true, nil, nil, { folderId = "new-id" })
    assert(string.find(h:text(), "1 encrypted folder offers", 1, true))
    h:click("select-folder-source"); h:edit("search-folder-source", "plain")
    h:find("search-folder-source").props.onSubmit()
    h:edit("path", "/local/shared")
    h:click("Add folder")
    local args = h.host.state.get("intent").request.args
    assert(args.folderId == "plain" and args.pendingDeviceId == "REMOTE" and args.deviceIds[1] == "REMOTE")
end)

scenario("P08 service reconciliation is explicit and cleanup gates removal", function()
    local s = Harness.fixture()
    s.lifecycle = { active = true, activeState = "active", canControl = true, unit = "syncthing.service", unitFileState = "disabled" }
    local h = start(s)
    h:click("Settings")
    assert(not h.host.state.get("intent"), "opening settings changed the service")
    assert(string.find(h:text(), "Preferred: enabled | Actual: disabled", 1, true))
    h:click("Change preference in Noctalia"); assert(h.settingsOpened and not h.host.state.get("intent"))
    h:click("apply-service-state"); h:advance(301); h:click("confirmation-accept")
    assert(h.host.state.get("intent").request.action == "lifecycle.enable")
    h:settle(true)
    h:click("Removal and recovery")
    assert(h:find("remove-in-host").props.enabled == false)
    h:click("cleanup-profiles"); h:advance(301); h:click("confirmation-accept")
    h:settle(false, "Profile is not owned by Noctalia", "not_owned")
    assert(h:find("remove-in-host").props.enabled == false)
    h:click("cleanup-profiles"); h:advance(301); h:click("confirmation-accept"); h:settle(true)
    assert(h:find("remove-in-host").props.enabled)
    h:click("Copy package path"); assert(h.copied[#h.copied] == "/package")
end)

scenario("P08 installation help works when the daemon is missing", function()
    local s = Harness.fixture()
    s.installation.available, s.connection.online, s.connection.fresh = false, false, false
    local h = start(s)
    h:click("More"); h:click("Installation help")
    local command = h.commands[#h.commands]
    assert(command.args[1] == "xdg-open" and command.args[2] == "https://syncthing.net/downloads/")
    command.callback({ exitCode = 1 })
    assert(string.find(h:text(), "Could not open", 1, true))
end)

scenario("P05 confirmation defaults, repeat guard, frozen and vanished targets", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", paused = true, devices = {}, status = { state = "idle" } } }
    local h = start(s)
    h:click("Forget"); h.entry.onKey("Alt+Return", true)
    assert(not h.host.state.get("view").confirm and not h.host.state.get("intent"), "default shortcut did not cancel")
    h:click("Forget"); h.entry.onKey("Alt+Down", true); h.entry.onKey("Alt+Return", true)
    assert(not h.host.state.get("intent"), "opening repeat bypassed guard")
    h:advance(301)
    s.folders = {}; h:snapshot(s)
    h.entry.onKey("Alt+Return", true)
    assert(not h.host.state.get("intent"), "vanished target was submitted")
    assert(string.find(h:text(), "no longer configured", 1, true))
end)

scenario("P07 permissions, directory pages and keyboard browsing stay bounded", function()
    local h = start(Harness.fixture())
    h:click("Add folder"); h:settle(true, nil, nil, { folderId = "new" })
    h:edit("path", "/denied"); h:click("Browse directories")
    h.commands[#h.commands].callback({ exitCode = 1, stdout = "" })
    assert(h:find("Use this directory").props.enabled == false)
    h:edit("picker-location", "/many"); h:click("Go")
    local entries = {}
    for i = 1, 256 do table.insert(entries, { name = tostring(i), path = "/many/" .. i }) end
    h.commands[#h.commands].callback({ exitCode = 0, stdout = encode({ path = "/many", parent = "/", entries = entries, next = "256" }) })
    h:click("Next directory page")
    assert(h.commands[#h.commands].args[4] == "256")
    h.commands[#h.commands].callback({ exitCode = 0, stdout = encode({ path = "/many", parent = "/", entries = { { name = "last", path = "/many/last" } } }) })
    h.entry.onKey("Alt+Return", true)
    assert(h.commands[#h.commands].args[3] == "/many/last")
end)

scenario("P09 long plain-text messages retain full copy and reachable return", function()
    local text = string.rep("路径 <b>literal</b> & \n", 600)
    local s = Harness.fixture()
    local h = start(s)
    h:click("Refresh"); h:settle(false, text, "failed")
    h:click("Full action details")
    h:click("Copy full details"); assert(h.copied[#h.copied] == text)
    assert(h:find("Back"))
    for _, node in h:nodes() do
        if node.type == "label" then assert(#node.props.text <= 2051, "unbounded native label") end
    end
    h:click("Back"); assert(h:find("Refresh"))
end)

scenario("P09 maximum error and invitation collections remain bounded and accessible", function()
    local s = Harness.fixture()
    for i = 1, 128 do
        local errors = {}
        for n = 1, 4 do table.insert(errors, { path = string.rep("p", 4096), error = string.rep("e", 1024) }) end
        table.insert(s.folders, { id = "folder-" .. i, path = "/folder/" .. i, devices = {},
            status = { state = "error", pullErrors = 10, errors = errors } })
    end
    for f = 1, 32 do
        local offers = {}
        for d = 1, 16 do offers["device-" .. d] = { label = "Offer " .. f } end
        s.pendingFolders["offer-" .. f] = { offeredBy = offers }
    end
    local h = start(s)
    h:click("More")
    assert(string.find(h:text(), "128 affected folders", 1, true))
    assert(h:find("Next errors") and h:find("Next invitations"))
    h:click("Next errors"); assert(string.find(h:text(), "/folder/5", 1, true))
    h:click("Next invitations"); assert(string.find(h:text(), "512 invitations | Page 2", 1, true))
    assert(#h:nodes() < 500, "large collections render unbounded control trees")
end)

scenario("P04 mixed filters, all, sorting and reset affect visible results", function()
    local s = Harness.fixture()
    s.folders = {
        { id = "z-error", path = "/z", status = { state = "error" }, devices = {} },
        { id = "a-idle", path = "/a", status = { state = "idle" }, devices = {} },
        { id = "b-paused", path = "/b", paused = true, status = { state = "idle" }, devices = {} },
    }
    local h = start(s)
    h:click("select-folder"); h:click("folder-filters")
    h:find("filter-paused").props.onChange(false)
    assert(h:find("All (mixed)") and not h:find("option-folder-b-paused"))
    h:find("folder-sort").props.onChange("2")
    local first
    for _, node in h:nodes() do
        if node.props.key and string.find(node.props.key, "option-folder-", 1, true) == 1 then first = node; break end
    end
    assert(first.props.key == "option-folder-z-error")
    h:find("filter-all").props.onChange(false)
    assert(h:find("No folders match the search and filters"))
    h:click("Reset")
    local v = h.host.state.get("view")
    assert(v.sort == "name" and v.search == "" and v.filters.paused and v.filters.ready and v.filters.errors)
    h:click("select-folder"); h:click("Previous"); assert(h:find("option-folder-b-paused"))
end)

scenario("P06 pending device acceptance copies its ID and retains edited name", function()
    local s = Harness.fixture()
    local id = string.rep("CCCCCCC-", 7) .. "CCCCCCC"
    s.pendingDevices = { { id = id, name = "Incoming", address = "tcp://192.0.2.1:22000" } }
    local h = start(s)
    h:click("Accept"); h:click("Copy device ID"); assert(h.copied[1] == id)
    h:edit("name", "My laptop")
    s.pendingDevices[1].name = "Changed upstream"; h:snapshot(s)
    h:click("submit-device")
    assert(h.host.state.get("intent").request.args.deviceName == "My laptop")
    h.entry.onClose(); h:settle(true); h.entry.onOpen()
    assert(h.host.state.get("view").form == nil, "settlement while closed left the submitted form")
end)

scenario("P05 owned action cursor skips disabled buttons and activates visible intent", function()
    local s = Harness.fixture()
    local h = start(s)
    assert(h:find("Rescan all").props.enabled == false)
    h.entry.onKey("Alt+Up", true)
    assert(string.find(h:text(), ": Settings", 1, true), "reverse navigation did not wrap")
    h.entry.onKey("Alt+Return", true)
    assert(h.host.state.get("view").form.kind == "settings")
    assert(not h.host.state.get("intent"), "opening settings submitted an action")
    h:click("Cancel")
    for _ = 1, 30 do
        h.entry.onKey("Alt+Down", true)
        assert(not string.find(h:text(), ": Rescan all", 1, true), "disabled action entered keyboard navigation")
    end
end)

scenario("P06 nested settings and device creation preserve the parent draft", function()
    local h = start(Harness.fixture())
    h:click("Add folder"); h:settle(true, nil, nil, { folderId = "new" })
    h:edit("path", "/my/draft"); h:edit("label", "Keep this")
    h:click("Settings"); h:click("Back")
    assert(h.host.state.get("view").form.path == "/my/draft")
    h:click("Add remote device")
    h:edit("deviceId", string.rep("CCCCCCC-", 7) .. "CCCCCCC")
    h:click("submit-device"); h:settle(true)
    local form = h.host.state.get("view").form
    assert(form.kind == "addFolder" and form.path == "/my/draft" and form.label == "Keep this")
end)

assert(failures == 0, tostring(failures) .. " parity regressions failed")
