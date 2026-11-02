local Harness = require("./Harness.luau")
local Model = require("../../hosts/noctalia/models/PanelModel.luau")
local failures = 0
local function scenario(name, test)
    local ok, err = pcall(test)
    print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
    if not ok then failures += 1 end
end
-- The refresh on opening is not a user action.
local function actionIntent(h)
    local intent = h.host.state.get("intent")
    return intent and intent.request.type ~= "refresh" and intent or nil
end

local function start(state)
    local h = Harness.new()
    noctalia, panel = h.host, h.panel
    h:load()
    h:snapshot(state)
    h:advance(1501)
    return h
end

scenario("overview preserves empty-folder guidance and footer action groups", function()
    local h = start(Harness.fixture())
    assert(h:find("No folders configured."), "empty state missing")
    assert(not string.find(h:text(), "previous selection", 1, true), "empty state implies a lost selection")
    local footer = assert(h:find("footer-actions"), "footer missing")
    assert(#footer.children == 2, "launchers and session actions must occupy separate rows")
    assert(footer.children[1].children[1].props.text == "Web UI")
    assert(footer.children[2].children[1].props.text == "Rescan all folders")
    for _, name in { "TUI", "GUI" } do
        local control = assert(h:find(name))
        assert(control.props.enabled == false and control.props.onClick == nil,
            "future launcher must not dispatch an action")
        assert(control.props.tooltip == "To be added soon.")
    end
    h:click("Add folder")
    assert(h:find("Local directory"), "empty state cannot open add-folder form")
end)

scenario("form return resets the viewport without resetting edits", function()
    local h = start(Harness.fixture())
    assert(h:find("overview-folders", "scroll"))
    h:click("Add folder"); h:settle(true, nil, nil, { folderId = "new" })
    local form = h.host.state.get("view").form
    local key = "form-" .. tostring(form.token)
    assert(h:find(key, "scroll") and not h:find("overview-folders", "scroll"))
    h:edit("path", "/retained")
    assert(h:find(key, "scroll"), "editing must not reset the form viewport")
    h:click("Cancel")
    assert(h:find("overview-folders", "scroll") and not h:find(key, "scroll"))
    h:click("Devices")
    assert(h:find("overview-devices", "scroll"))
end)

scenario("owned cursor clears selection on retained native buttons", function()
    local h = start(Harness.fixture())
    for _ = 1, 5 do h.entry.onKey("Alt+Down", true) end
    local selected = 0
    for _, node in h:nodes() do
        if node.type == "button" then
            assert(type(node.props.selected) == "boolean", "native selection was left unchanged")
            if node.props.selected then selected += 1 end
        end
    end
    assert(selected == 1, "only the current action may carry the owned selection")
end)

scenario("folder toolbar keeps contextual actions and card lifecycle targets", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", paused = false, devices = {}, status = { state = "idle" } } }
    local h = start(s)
    local toolbar = assert(h:find("folder-toolbar"))
    assert(toolbar.children[2].props.key == "Add folder")
    assert(toolbar.children[3].props.key == "Sharing")
    assert(toolbar.children[4].props.key == "Unlink")
    assert(h:find("Rescan") and not h:find("Forget"), "linked folder must offer rescan")
    h:click("Unlink"); h:advance(301); h:click("confirmation-accept")
    local request = h.host.state.get("intent").request
    assert(request.action == "folder.pause" and request.args.folderId == "one")
    h:settle(true)
    s.folders[1].paused = true; h:snapshot(s)
    assert(h:find("Forget") and not h:find("Rescan"), "unlinked folder must offer forget")
    h:click("Link"); h:advance(301); h:click("confirmation-accept")
    request = h.host.state.get("intent").request
    assert(request.action == "folder.resume" and request.args.folderId == "one")
    h:settle(true)
    local found = false
    for _ = 1, 40 do
        h.entry.onKey("Alt+Down", true)
        if h:find("Sharing").props.selected then found = true; break end
    end
    assert(found, "keyboard cursor never reached the icon action")
    h.entry.onKey("Alt+Return", true)
    assert(h:find("Save sharing"), "keyboard sharing action did not open the selected folder")
    h:click("Cancel")
    s.connection.online, s.connection.fresh = false, false
    s.folders = {}; h:snapshot(s)
    assert(h:find("Folder status is unavailable."), "offline state claims an empty configuration")
    assert(h:find("Add folder").props.enabled == false, "offline add remains enabled")
end)

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
    h:click("share-offered")
    s.folders[44].devices[1].remoteState = "valid"
    h:snapshot(s)
    h.entry.onKey("Alt+Left", true); h:click("shares-confirmed")
    h:edit("share-search-1-confirmed", "offered")
    assert(h:checked("share-offered") == false, "acceptance reset draft")
    h:edit("share-search-1-confirmed", "Remote folder paused")
    assert(string.find(h:text(), "Remote folder paused", 1, true))
    s.connection.fresh = false
    h:snapshot(s)
    h.entry.onKey("Alt+Left", true)
    assert(h:find("No confirmed shares"), "stale acceptance claimed")
end)

scenario("device toolbar targets selection and pause gives bounded busy feedback", function()
    local s = Harness.fixture()
    local h = start(s)
    h:click("Devices")
    local toolbar = assert(h:find("device-toolbar"))
    assert(toolbar.children[2].props.key == "Add device")
    assert(toolbar.children[3].props.key == "Shared folders")
    assert(toolbar.children[4].props.key == "Remove")
    h:click("device-pause")
    local request = h.host.state.get("intent").request
    assert(request.action == "device.pause" and request.args.deviceId == "REMOTE")
    assert(h:find("PAUSING", "button").props.enabled == false)
    assert(h:find("Remove").props.onClick == nil)
    h:settle(true)
    h:click("Remove"); h:advance(301); h:click("confirmation-accept")
    request = h.host.state.get("intent").request
    assert(request.action == "device.remove" and request.args.deviceId == "REMOTE")
    h:settle(true)
    s.devices = {}; h:snapshot(s)
    assert(h:find("No remote devices configured.") and h:find("Remove").props.onClick == nil, "Omarchy keeps remove, disabled")
    s.connection.online = false; h:snapshot(s)
    assert(h:find("Device status is unavailable."))
    assert(h:find("Add device").props.enabled == false)
end)

scenario("invitation tabs retain separate pages and never mix offer types", function()
    local s = Harness.fixture()
    for i = 1, 8 do
        table.insert(s.pendingDevices, { id = "pending-" .. i, name = "Incoming " .. i })
        s.pendingFolders["offer-" .. i] = { offeredBy = { REMOTE = { label = "Offer " .. i } } }
    end
    local h = start(s)
    assert(h:find("PENDING FOLDER REQUESTS") and not h:find("PENDING DEVICE REQUESTS"))
    h:click("select-invitation-folders"); h:click("Next")
    h:click("option-invitation-folders-offer-7\nREMOTE")
    h:click("Devices")
    assert(h:find("PENDING DEVICE REQUESTS") and not h:find("PENDING FOLDER REQUESTS"))
    h:click("select-invitation-devices"); h:click("Next"); h:click("option-invitation-devices-pending-7")
    h:click("Folders"); assert(h:find("Offer 7") and h:find("(by Laptop)"))
    h:click("Devices"); assert(h:find("Incoming 7 (pending) wants to connect"))
end)

scenario("footer identifies the active operation and disables repeated activation", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", devices = {}, status = { state = "idle" } } }
    local h = start(s)
    h:click("Rescan all folders")
    assert(h:find("Rescanning...", "button").props.enabled == false)
    assert(h.host.state.get("intent").request.action == "folder.rescan-all")
    h:settle(true)
    h:click("Refresh Sync.status")
    assert(h:find("Rechecking Syncthing", "button").props.enabled == false)
    assert(h.host.state.get("intent").request.type == "refresh")
    h:settle(true); h:advance(1501)
    s.folders[1].status = { state = "error", pullErrors = 1 }; s.counts.folderProblems = 1; h:snapshot(s)
    h:click("Refresh Sync.status")
    assert(h:find("Rechecking Syncthing", "button").props.enabled == false)
    assert(h.host.state.get("intent").request.action == "folder.recheck-errors")
    h:settle(false, "Recheck failed", "unavailable"); h:advance(1501)
    assert(h:find("Refresh Sync.status").props.enabled and string.find(h:text(), "Recheck failed", 1, true))
end)

scenario("status roles distinguish activity, pause, health and stale devices", function()
    local Palette = require("../../hosts/noctalia/controllers/ThemePaletteController.luau")
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", devices = {}, status = { state = "scanning", needTotalItems = 2 } } }
    local h = start(s)
    assert(h:find("folder-state-one").children[1].props.color == Palette.roles.warning,
        "combined scan and sync must use warning semantics")
    s.folders[1].status = { state = "idle" }; h:snapshot(s)
    assert(h:find("folder-state-one").children[1].props.color == Palette.roles.success)
    s.folders[1].paused = true; h:snapshot(s)
    assert(h:find("folder-state-one").children[1].props.color == Palette.roles.warning)
    s.devices[1].paused = true; h:snapshot(s); h:click("Devices")
    assert(h:find("PAUSED").props.color == Palette.roles.warning,
        "connected flag must not override pause")
    s.connection.fresh = false; h:snapshot(s)
    assert(h:find("device-state-REMOTE").children[1].props.color == Palette.roles.warning, "Omarchy keeps the reported device state")
end)

scenario("card identity controls preserve exact paths, IDs and Web UI targets", function()
    local s = Harness.fixture()
    local path = "/data/folder with spaces/'literal' $(not-a-command)"
    s.folders = {
        { id = "one", label = "Notes", path = path, devices = { { id = "REMOTE" } }, status = { state = "idle" } },
        { id = "two", label = "Notes", path = "/other", devices = {}, status = { state = "idle" } },
    }
    local h = start(s)
    h:click("open-folder-one")
    local args = h.commands[#h.commands].args
    assert(args[1] == "xdg-open" and args[2] == path and #args == 2)
    h:click("copy-folder-one"); assert(h.copied[#h.copied] == "one")
    s.folders[1].status.state = "scanning"; h:snapshot(s)
    assert(h:find("Rescan").props.enabled ~= false, "Omarchy only blocks while its own action runs")
    h:click("Devices")
    assert(h:find("1/2 folders shared"))
    h:click("copy-device-REMOTE"); assert(h.copied[#h.copied] == "REMOTE")
    h:click("edit-device-REMOTE")
    assert(h.commands[#h.commands].args[2] == s.webUi.url, "the default Web UI opens its address directly, as in Omarchy")
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
    h:click("Refresh Sync.status")
    assert(string.find(h:text(), "Rechecking Syncthing", 1, true), "generic busy message")
    h:settle(true)
    h:advance(6000)
    assert(not string.find(h:text(), "Refreshed", 1, true), "success notice did not expire")
    h:click("Refresh Sync.status"); h:settle(false, "Check credentials", "unauthorized")
    h:advance(60000)
    assert(string.find(h:text(), "Check credentials", 1, true), "timer erased failure")
end)
scenario("P01 unavailable folder sharing cannot become local-only", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", status = { state = "idle" } } }
    local h = start(s)
    h:click("Sharing")
    h:click("Save sharing")
    assert(not actionIntent(h), "unknown shares may be cleared")
    assert(string.find(h:text(), "Sharing data unavailable", 1, true), "the refusal shows in the header")
    s.folders[1].devices = { { id = "REMOTE" } }
    h:snapshot(s)
    h:click("shares-sharing")
    assert(h:checked("share-REMOTE"), "newly available sharing was not seeded")
    s.connection.fresh = false; h:snapshot(s); h.entry.onKey("Alt+Left", true)
    assert(h:find("Save sharing").props.enabled, "Omarchy allows saving on a connected instance; the core verifies the folder")
end)

scenario("P01 disappeared and reappearing shares reset stale removal intent", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", status = {}, devices = { { id = "REMOTE", remoteState = "valid" } } } }
    local h = start(s)
    h:click("Devices"); h:click("Shared folders"); h:click("shares-confirmed")
    h:click("share-one")
    s.folders[1].devices = {}; h:snapshot(s)
    s.folders[1].devices = { { id = "REMOTE", remoteState = "valid" } }; h:snapshot(s)
    assert(h:checked("share-one"), "newly restored share inherits stale removal")
    h.entry.onKey("Alt+Left", true)
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
    h:click("submit-device")
    assert(not actionIntent(h) and string.find(h:text(), "local device", 1, true), "local ID can submit")
    h:edit("deviceId", knownId)
    h:click("submit-device")
    assert(not actionIntent(h) and string.find(h:text(), "already configured", 1, true), "duplicate ID can submit")
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
    h:click("Add folder submit")
    assert(not actionIntent(h), "newly encrypted offer accepted inline")
    assert(string.find(h:text(), "requires the Syncthing Web UI", 1, true))
    s.pendingFolders = {}; h:snapshot(s)
    h:click("Add folder submit")
    assert(not actionIntent(h), "vanished offer accepted")
    assert(h.host.state.get("view").form.path == "/my/project")
end)

scenario("P04 search, directional choice and filter disclosure preserve identity", function()
    local s = Harness.fixture()
    for i = 1, 20 do table.insert(s.folders, { id = string.format("f%02d", i), path = "/data/" .. i .. "/Photos",
        label = "Photos", status = { state = "idle" }, devices = {} }) end
    local h = start(s)
    h:click("select-folder")
    assert(not h:find("sort-active"), "filters consume space while collapsed")
    h:click("folder-filters"); assert(h:find("sort-active"))
    h:edit("search-folder", "(19)")
    assert(h:find("option-folder-f19"), "label search lost the folder")
    h:search("search-folder").props.onSubmit()
    assert(h.host.state.get("view").folderId == "f19")
    h:click("select-folder"); h:edit("search-folder", "")
    h.entry.onKey("Alt+Down", true); h.entry.onKey("Alt+Return", true)
    local moved = h.host.state.get("view").folderId
    assert(moved ~= "f19", "directional choice did not move")
    h:click("select-folder"); h:edit("search-folder", "not present")
    assert(h:find("No folders match the search and filters"))
    assert(h.host.state.get("view").folderId == moved, "search erased hidden selection")
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
    s.devices[1].paused = true; h:snapshot(s); h.entry.onKey("Alt+Left", true); h:click("shares-unconfirmed")
    assert(string.find(h:text(), "Remote acceptance unconfirmed", 1, true))
    s.devices[1].paused, s.devices[1].connected = false, false; h:snapshot(s)
    assert(string.find(h:text(), "Remote acceptance unconfirmed", 1, true))
    s.devices[1].connected = true; s.folders[1].devices[1].remoteState = "unknown"; h:snapshot(s)
    assert(string.find(h:text(), "Remote acceptance unconfirmed", 1, true))
    h.entry.onKey("Alt+Return", true); h.entry.onKey("Alt+Left", true)
    h:click("save-device-folders")
    assert(h.host.state.get("intent").request.args.folderIds[1] == "one")
end)

scenario("P02 error copy, folder route, retry, clean and unavailable", function()
    local s = Harness.fixture()
    s.folders = { { id = "broken", path = "/broken", devices = {}, status = { state = "error", error = "Access denied" } } }
    s.counts.folderProblems = 1
    local h = start(s)
    h:click("More")
    assert(string.find(h:text(), "affected: /broken", 1, true) and string.find(h:text(), "Access denied", 1, true))
    h:click("Refresh Sync.status")
    assert(h.host.state.get("intent").request.action == "folder.recheck-errors", "refresh did not recheck problem folders")
    h:settle(false, "Recheck failed", "request_failed")
    h:advance(1501)
    h:click("Refresh Sync.status"); h:settle(true); h:advance(1501)
    s.folders[1].status = { state = "idle" }; h:snapshot(s)
    assert(string.find(h:text(), "clean", 1, true))
    s.connection.online, s.connection.fresh = false, false; h:snapshot(s)
    assert(string.find(h:text(), "unavailable", 1, true))
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
    s.connection.phase = "ready"
    summary()
    assert(string.find(icon, "default.svg", 1, true) and tooltip == "Syncthing: Up to date", "Omarchy shows only its own scans")
    assert(string.find(h:text(), "SYNCED", 1, true))
    s.activity.current = { folderId = "one", action = "removing", path = "/one/gone", detail = "gone" }
    h:snapshot(s); summary()
    assert(string.find(h:text(), "SYNCING", 1, true))
    assert(string.find(tooltip, "Sync in progress...", 1, true) and string.find(icon, "sync.svg", 1, true))
    assert(h.seconds); h:advance(1000)
    assert(string.find(h:text(), "File syncing.", 1, true))
    s.lifecycle.active, s.lifecycle.canStart, s.lifecycle.targetMatch = false, true, true; h:snapshot(s); summary()
    assert(string.find(icon, "pause.svg", 1, true) and tooltip == "Syncthing: Syncing stopped")
    local serviceToggle
    for _, node in h:nodes() do if node.type == "toggle" then serviceToggle = node end end
    assert(serviceToggle.props.enabled, "authorized stopped service cannot start")
    serviceToggle.props.onChange(true)
    assert(h.host.state.get("intent").request.action == "lifecycle.start")
end)

scenario("P06 in-form folder sources retain offer identity and route encryption", function()
    local s = Harness.fixture()
    s.pendingFolders = { plain = { offeredBy = { REMOTE = { label = "Shared" } } },
        secret = { offeredBy = { REMOTE = { label = "Secret", remoteEncrypted = true } } } }
    local h = start(s)
    h:click("Add folder"); h:settle(true, nil, nil, { folderId = "new-id" })
    assert(string.find(h:text(), "1 encrypted folder offer requires", 1, true))
    h:click("select-folder-source")
    for _, node in h:nodes() do
        if node.type == "button" and node.props.text == "Shared (by Laptop)" then node.props.onClick(); break end
    end
    h:edit("path", "/local/shared")
    h:click("Add folder submit")
    local args = h.host.state.get("intent").request.args
    assert(args.folderId == "plain" and args.pendingDeviceId == "REMOTE" and args.deviceIds[1] == "REMOTE")
end)

scenario("P08 service reconciliation is explicit and cleanup gates removal", function()
    local s = Harness.fixture()
    s.lifecycle = { active = true, activeState = "active", canControl = true, unit = "syncthing.service", unitFileState = "disabled" }
    local h = start(s)
    assert(h:find("service-state-choice"), "drift must ask, as in Omarchy")
    assert(h:find("Enable systemd autostart (preferred)", "button"))
    h:click("drift-first")
    assert(h.host.state.get("intent").request.action == "lifecycle.enable")
    h:settle(true)
    s.lifecycle.unitFileState = "enabled"; h:snapshot(s)
    h:advance(1501)
    h:click("Settings"); h:click("settings-webui")
    assert(string.find(h:text(), "Preferred: enabled | Actual: enabled", 1, true))
    h:click("Back"); h:click("settings-removal")
    assert(h:find("remove-in-host").props.enabled == false)
    h:click("cleanup-profiles"); h:advance(301); h:click("confirmation-accept")
    assert(h.host.state.get("intent").request.action == "webui.remove-profile")
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
    assert(command.callback == nil, "a waited opener dies with the host's capture timeout")
end)

scenario("P05 confirmation defaults, repeat guard, frozen and vanished targets", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", paused = true, devices = {}, status = { state = "idle" } } }
    local h = start(s)
    h:click("Forget"); h.entry.onKey("Alt+Return", true)
    assert(not h.host.state.get("view").confirm and not actionIntent(h), "default shortcut did not cancel")
    h:click("Forget"); h.entry.onKey("Alt+Down", true); h.entry.onKey("Alt+Return", true)
    assert(not actionIntent(h), "opening repeat bypassed guard")
    h:advance(301)
    s.folders = {}; h:snapshot(s)
    h.entry.onKey("Alt+Return", true)
    assert(not actionIntent(h), "vanished target was submitted")
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
    h:click("Refresh Sync.status"); h:settle(false, text, "failed")
    h:click("Full action details")
    h:click("Copy full details"); assert(h.copied[#h.copied] == text)
    assert(h:find("Back"))
    for _, node in h:nodes() do
        if node.type == "label" then assert(#node.props.text <= 2051, "unbounded native label") end
    end
    h:click("Back"); h:advance(1501); assert(h:find("Refresh Sync.status"))
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
    assert(string.find(h:text(), "affected: /folder/1", 1, true))
    assert(h:find("Next errors") and h:find("select-invitation-folders"))
    h:click("Next errors"); assert(string.find(h:text(), "/folder/5", 1, true))
    h:click("select-invitation-folders"); assert(string.find(h:text(), "1-6 of 512", 1, true))
    h:click("Next"); assert(string.find(h:text(), "7-12 of 512", 1, true))
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
    h:click("filter-paused")
    assert(h:checked("filter-all") == false and not h:find("option-folder-b-paused"))
    h:click("sort-errors")
    local first
    for _, node in h:nodes() do
        if node.props.key and string.find(node.props.key, "option-folder-", 1, true) == 1 then first = node; break end
    end
    assert(first.props.key == "option-folder-z-error")
    h:click("filter-all"); h:click("filter-all")
    assert(h:find("No folders match the search and filters"))
    h:click("Reset")
    local v = h.host.state.get("view")
    assert(v.sort == "name" and v.search == "" and v.filters.paused and v.filters.ready and v.filters.errors)
    h:click("select-folder"); assert(h:find("option-folder-b-paused"))
end)

scenario("P06 pending device acceptance copies its ID and retains edited name", function()
    local s = Harness.fixture()
    local id = string.rep("CCCCCCC-", 7) .. "CCCCCCC"
    s.pendingDevices = { { id = id, name = "Incoming", address = "tcp://192.0.2.1:22000" } }
    local h = start(s)
    h:click("Devices"); h:click("Accept"); h:click("Copy device ID"); assert(h.copied[1] == id)
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
    assert(h:find("Rescan all folders").props.enabled == false)
    h.entry.onKey("Alt+Up", true)
    assert(h:find("Settings").props.selected, "reverse navigation did not wrap")
    h.entry.onKey("Alt+Return", true)
    assert(h.host.state.get("view").form.kind == "settings")
    assert(not actionIntent(h), "opening settings submitted an action")
    h:click("settings-back")
    for _ = 1, 30 do
        h.entry.onKey("Alt+Down", true)
        assert(not string.find(h:text(), ": Rescan all", 1, true), "disabled action entered keyboard navigation")
    end
end)

scenario("plain keys drive the cursor, search and confirmation as in Omarchy", function()
    local h = start(Harness.fixture())
    h.entry.onKey("j", true)
    local first = h.host.state.get("view").actionCursor
    assert(first, "j did not move the cursor")
    h.entry.onKey("Down", true)
    assert(h.host.state.get("view").actionCursor ~= first, "Down did not move the cursor")
    h.entry.onKey("k", true)
    assert(h.host.state.get("view").actionCursor == first, "k did not move back")
    h.entry.onKey("k", true); h.entry.onKey("k", true)
    for _ = 1, 40 do
        if string.find(h.host.state.get("view").actionCursor or "", "Folders", 1, true) then break end
        h.entry.onKey("j", true)
    end
    h.entry.onKey("l", true)
    assert(h.host.state.get("view").section == "devices", "l on the tabs switches, as in Omarchy")
    h.entry.onKey("h", true)
    assert(h.host.state.get("view").section == "folders", "h on the tabs switches back")
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", paused = false, devices = {}, status = { state = "idle" } } }
    h = start(s)
    h.entry.onKey("slash", true); assert(h:search("search-folder"), "slash did not open the selector")
    h.entry.onKey("Alt+Left", true)
    h:click("Unlink"); h:advance(301)
    h.entry.onKey("j", true); h.entry.onKey("space", true)
    assert(h.host.state.get("intent").request.action == "folder.pause", "space did not accept the chosen answer")
end)

scenario("an open list keeps letters away from the panel's shortcuts", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", devices = {}, status = { state = "idle" } }, { id = "two", path = "/two", devices = {}, status = { state = "idle" } } }
    local h = start(s)
    h:click("select-folder")
    local first = assert(h:find("search-folder-1"), "each opening needs a new search field")
    h.entry.onKey("r", true); h.entry.onKey("s", true)
    assert(not actionIntent(h) and not h.host.state.get("view").form, "a letter reached a panel shortcut")
    h.entry.onKey("q", true)
    assert(not h:find("search-folder-1"), "q closes the list")
    h:click("select-folder"); assert(h:find("search-folder-2"))
    assert(first ~= nil)
end)

scenario("action errors sit above the counts and folder errors stay in More", function()
    local s = Harness.fixture()
    s.folders = { { id = "bad", path = "/bad", devices = {}, status = { state = "error", error = "Access denied" } } }
    s.counts.folderProblems = 1
    local h = start(s)
    local function position(text)
        for index, node in h:nodes() do if node.props.text == text then return index end end
        return nil
    end
    assert(not string.find(h:text(), "affected: /bad", 1, true), "folder error details belong in More")
    h:click("Rescan all folders"); h:settle(false, "Syncthing returned HTTP 500", "http")
    assert(position("Syncthing returned HTTP 500") < position("Folders"), "action errors sit above the counts")
    h:click("More")
    assert(string.find(h:text(), "affected: /bad", 1, true))
end)

scenario("a deliberate stop stays quiet and the switch acts directly", function()
    local s = Harness.fixture()
    s.lifecycle = { active = false, canControl = true, canStart = true, targetMatch = true, unit = "syncthing.service" }
    s.connection.online, s.connection.fresh, s.connection.error = false, false, { message = "could not connect to Syncthing" }
    local h = start(s)
    assert(not string.find(h:text(), "could not connect", 1, true), "a stopped service reported a connection problem")
    assert(h:find("service-toggle").props.checked == false)
    h:find("service-toggle").props.onChange("true")
    assert(h.host.state.get("intent").request.action == "lifecycle.start")
end)

scenario("settings arguments authorize the default unit and the file names every preference", function()
    local Settings = require("../../hosts/noctalia/controllers/SettingsController.luau")
    local args = table.concat(Settings.arguments({ lifecycleAuthorized = true, lifecycleUnit = "syncthing.service", lifecycleConfig = "" }, "/p"), " ")
    assert(string.find(args, "--lifecycle-unit syncthing.service", 1, true) and not string.find(args, "--lifecycle-config", 1, true))
    local h = start(Harness.fixture())
    assert(Settings.filePath(h.host) == "fixture/noctalia/syncshell.toml")
    local template = Settings.template(h.host)
    assert(string.find(template, 'plugin_settings."syncshell/syncshell"', 1, true) and string.find(template, "brandedIcon = ", 1, true)
        and string.find(template, 'webUi = "', 1, true))
end)


scenario("geometry: visual bugs found live stay fixed", function()
    local Ui = require("../../hosts/noctalia/ui/UiConstants.luau")
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", devices = {}, status = { state = "idle" } }, { id = "two", path = "/two", devices = {}, status = { state = "idle" } } }
    s.lifecycle = { active = true, canControl = true, canStart = true, targetMatch = true, unitFileState = "enabled", activeState = "active" }
    local h = start(s)
    -- A native button dropped the chip's glyph below its text.
    local chip = assert(h:find("Copy ID"))
    assert(chip.type == "row" and chip.props.align == "center" and chip.children[1].type == "glyph")
    assert(h:find("service-toggle"), "a controllable service shows the switch")
    assert(h:find("select-folder").props.height == Ui.control)
    assert(h:find("Add folder").props.height == Ui.control and h:find("Add folder").props.width == Ui.control)
    assert(h:find("Rescan").props.height == Ui.cardControl)
    local hint = assert(h:find("shortcut-hint"))
    assert(hint.props.justify == "center", "the shortcut hint is centred")
    for _, item in hint.children do
        assert(item.children[1].props.color == require("../../hosts/noctalia/controllers/ThemePaletteController.luau").roles.warning)
    end
end)

scenario("geometry: a body scroll area never nests another", function()
    local s = Harness.fixture()
    s.folders = { { id = "one", path = "/one", devices = {}, status = { state = "idle" } } }
    local h = start(s)
    h:click("Add folder"); h:settle(true, nil, nil, { folderId = "x" })
    h:click("Browse directories")
    local function check(node, inside)
        assert(not (inside and node.type == "scroll"), "nested scroll areas collapse in the host")
        for _, child in node.children do check(child, inside or node.type == "scroll") end
    end
    check(h.tree, false)
end)

scenario("the settings file opens in a terminal editor, as in Omarchy", function()
    local s = Harness.fixture()
    local h = start(s)
    local notified
    h.host.notify = function(title, body) notified = title .. "|" .. body end
    h.host.fileExists = function() return true end
    h:click("Settings"); h:click("settings-open")
    local args = h.commands[#h.commands].args
    assert(args[1] == "xdg-terminal-exec" and args[2] == "-e" and args[4] == "--" and args[5] == "fixture/noctalia/syncshell.toml", table.concat(args, " "))
    assert(notified == "Editing config file|fixture/noctalia/syncshell.toml")
end)

scenario("a missing syncthing says so instead of a worker error", function()
    local h = Harness.new()
    noctalia, panel = h.host, h.panel
    h.host.state.set("status", { generation = "test-generation", ready = false, error = "Syncthing configuration was not found", syncthingMissing = true })
    h:load()
    assert(string.find(h:text(), "Syncthing is not installed", 1, true), "warning missing")
    assert(not string.find(h:text(), "configuration was not found", 1, true), "Omarchy hides the core error when not installed")
end)

-- The action map: each control sends exactly what Omarchy's does.
local function wiringFixture()
    local s = Harness.fixture()
    s.folders = {
        { id = "one", label = "One", path = "/data/one", paused = false, markerName = ".stfolder", devices = { { id = "REMOTE", remoteState = "valid" } }, status = { state = "idle" } },
        { id = "off", label = "Off", path = "/data/off", paused = true, devices = {}, status = { state = "idle" } },
    }
    s.counts.folders = 2
    s.pendingDevices = { { id = string.rep("CCCCCCC-", 7) .. "CCCCCCC", name = "New", address = "tcp://x" } }
    s.pendingFolders = { offered = { offeredBy = { REMOTE = { label = "Docs" } } } }
    return s
end

local function sent(h)
    local intent = assert(actionIntent(h), "no action was sent")
    return intent.request.action, intent.request.args, intent.notice
end

local function sameList(values, expected)
    assert(#values == #expected, "list size")
    for index, value in expected do assert(values[index] == value, "list value " .. tostring(value)) end
end

scenario("wiring: folder toolbar and card send Omarchy's actions and notices", function()
    local s = wiringFixture()
    local h = start(s)
    h.host.state.get("view").folderId = "one"
    h:click("Unlink"); assert(not actionIntent(h), "unlink needs confirmation")
    h:advance(301); h:click("confirmation-accept")
    local action, args, notice = sent(h)
    assert(action == "folder.pause" and args.folderId == "one")
    assert(notice == "Synchronization for One paused. The folder ID, device associations, and data remain.", notice)
    h:settle(true)
    s.folders[1].paused = true; h:snapshot(s)
    h:click("Link"); h:advance(301); h:click("confirmation-accept")
    action, args, notice = sent(h)
    assert(action == "folder.resume" and args.folderId == "one" and string.find(notice, "Linked One.", 1, true))
    h:settle(true)
    assert(h.host.state.get("view").recentlyLinked == "one")
    s.folders[1].paused = false; h:snapshot(s)
    h:click("Rescan")
    action, args, notice = sent(h)
    assert(action == "folder.rescan" and args.folderId == "one" and notice == "Rescan complete for One")
    h:settle(true); h:advance(1501)
    h:click("Rescan all folders")
    action, args, notice = sent(h)
    assert(action == "folder.rescan-all" and notice == "Rescan complete for all folders")
end)

scenario("wiring: forget targets the unlinked folder after confirmation", function()
    local s = wiringFixture()
    s.folders = { s.folders[2] }
    local h = start(s)
    h:click("Forget"); assert(not actionIntent(h)); h:advance(301); h:click("confirmation-accept")
    local action, args, notice = sent(h)
    assert(action == "folder.forget" and args.folderId == "off")
    assert(string.find(notice, "Re-add Folder ID off to rejoin", 1, true))
end)

scenario("wiring: add folder resolves paths, derives the label and creates on request", function()
    local s = wiringFixture()
    s.pendingFolders = {}
    local h = start(s)
    h:click("Add folder")
    assert(h.host.state.get("intent").request.action == "folder.suggest-id")
    h:settle(true, nil, nil, { folderId = "abc" })
    h:edit("path", "~/work/new"); h:click("Add folder submit")
    local action, args, notice = sent(h)
    assert(action == "folder.add-existing" and args.folderId == "abc" and args.label == "new")
    assert(args.path == "/home/fixture/work/new" and #args.deviceIds == 0)
    assert(notice == "Added new locally. It is linked but not shared with another device.", notice)
    h:settle(false, "folder path does not exist", "path_missing")
    assert(string.find(h.host.state.get("view").confirm.message, "and add the folder?", 1, true))
    assert(h.host.state.get("view").message == "", "the error stays behind the dialog in Omarchy")
    h:advance(301); h:click("confirmation-accept")
    action, args = sent(h)
    assert(action == "folder.add-existing" and args.createDirectory == true)
end)

scenario("wiring: a pending folder offer is accepted through the add form", function()
    local s = wiringFixture()
    local h = start(s)
    h:click("Accept")
    local form = h.host.state.get("view").form
    assert(form.kind == "addFolder" and form.folderId == "offered" and form.label == "Docs" and form.selected.REMOTE)
    h:edit("path", "/data/docs"); h:click("Add folder submit")
    local action, args, notice = sent(h)
    assert(action == "folder.add-existing" and args.pendingDeviceId == "REMOTE" and args.folderId == "offered")
    sameList(args.deviceIds, { "REMOTE" })
    assert(notice == "Remote devices may have to accept the folder.", notice)
end)

scenario("wiring: rejecting an offer and dismissing a device send their identities", function()
    local s = wiringFixture()
    local h = start(s)
    h:click("Dismiss"); h:advance(301); h:click("confirmation-accept")
    local action, args, notice = sent(h)
    assert(action == "folder.dismiss-pending" and args.folderId == "offered" and args.pendingDeviceId == "REMOTE")
    assert(notice == "Rejected folder request for Docs (by Laptop).", notice)
    h:settle(true)
    h:click("Devices")
    h:click("Dismiss"); h:advance(301); h:click("confirmation-accept")
    action, args, notice = sent(h)
    assert(action == "device.dismiss-pending" and args.deviceId == s.pendingDevices[1].id)
    assert(notice == "Dismissed pending request from New.", notice)
end)

scenario("wiring: device controls send their identities", function()
    local s = wiringFixture()
    local h = start(s)
    h:click("Devices")
    h:click("device-pause")
    local action, args, notice = sent(h)
    assert(action == "device.pause" and args.deviceId == "REMOTE" and notice == "Paused synchronization with Laptop.", notice)
    h:settle(true)
    s.devices[1].paused = true; h:snapshot(s)
    h:click("device-pause")
    action, args, notice = sent(h)
    assert(action == "device.resume" and args.deviceId == "REMOTE" and notice == "Resumed synchronization with Laptop.", notice)
    h:settle(true)
    h:click("Remove"); h:advance(301); h:click("confirmation-accept")
    action, args, notice = sent(h)
    assert(action == "device.remove" and args.deviceId == "REMOTE" and notice == "Laptop removed from this device.", notice)
end)

scenario("wiring: sharing, share removal and device add send the whole selection", function()
    local s = wiringFixture()
    s.pendingFolders, s.pendingDevices = {}, {}
    local h = start(s)
    h:click("Sharing"); h:click("Save sharing")
    local action, args, notice = sent(h)
    assert(action == "folder.set-sharing" and args.folderId == "one")
    sameList(args.deviceIds, { "REMOTE" })
    assert(notice == "Sharing with Laptop updated.", notice)
    h:settle(true)
    h:click("Devices"); h:click("Shared folders"); h:click("shares-confirmed"); h:click("share-one")
    h.entry.onKey("Alt+Left", true)
    h:click("save-device-folders")
    action, args, notice = sent(h)
    assert(action == "device.remove-folder-shares" and args.deviceId == "REMOTE")
    sameList(args.folderIds, { "one" })
    assert(notice == "Selected folder shares removed from Laptop.", notice)
    h:settle(true)
    h:click("Add device")
    local id = string.rep("CCCCCCC-", 7) .. "CCCCCCC"
    h:edit("deviceId", string.lower(id)); h:edit("name", "Desk"); h:click("submit-device")
    action, args, notice = sent(h)
    assert(action == "device.add" and args.deviceId == id and args.deviceName == "Desk")
    assert(notice == "Desk added. Add this device on Desk to complete connection.", notice)
end)

scenario("wiring: service, Web UI and refresh controls follow Omarchy", function()
    local s = wiringFixture()
    s.lifecycle = { active = true, canControl = true, canStart = true, targetMatch = true, unitFileState = "enabled", activeState = "active" }
    local h = start(s)
    h.entry.onKey("p", true)
    local action, _, notice = sent(h)
    assert(action == "lifecycle.stop" and notice == "", "Omarchy reports the service through its state")
    h:settle(true)
    h:click(h:find("Web UI", "button").props.key)
    assert(h.commands[#h.commands].args[1] == "xdg-open" and h.commands[#h.commands].args[2] == s.webUi.url)
    s.webUi.theme = "syncshell-noctalia-modern"; h:snapshot(s)
    h:click(h:find("Web UI", "button").props.key)
    action = sent(h)
    assert(action == "webui.open")
    h:settle(false, "bridge failed", "desktop_open")
    assert(h.commands[#h.commands].args[2] == s.webUi.url, "a failed bridge falls back to the plain address")
    h:advance(1501)
    h:click("Refresh Sync.status")
    assert(h.host.state.get("intent").request.type == "refresh")
end)

assert(failures == 0, tostring(failures) .. " parity regressions failed")
