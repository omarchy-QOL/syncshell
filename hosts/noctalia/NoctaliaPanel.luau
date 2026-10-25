local SnapshotStore = require("./transport/SnapshotStore.luau")
local Controller = require("./controllers/PanelController.luau")
local Navigation = require("./models/PanelNavigation.luau")
local Model = require("./models/PanelModel.luau")
local SharedWidgetControls = require("./ui/SharedWidgetControls.luau")
local Header = require("./ui/Header.luau")
local BodyTabFoldersSelector = require("./ui/BodyTabFoldersSelector.luau")
local BodyTabFoldersCard = require("./ui/BodyTabFoldersCard.luau")
local BodyTabDevices = require("./ui/BodyTabDevices.luau")
local BodyInvitations = require("./ui/BodyInvitations.luau")
local BodyMore = require("./ui/BodyMore.luau")
local BodyTabFoldersAddForm = require("./ui/BodyTabFoldersAddForm.luau")
local AddDeviceForm = require("./ui/BodyTabDevicesAddForm.luau")
local BodyTabFoldersShareForm = require("./ui/BodyTabFoldersShareForm.luau")
local BodyTabDevicesFoldersForm = require("./ui/BodyTabDevicesFoldersForm.luau")
local SettingsPage = require("./ui/SettingsPage.luau")
local Confirmation = require("./ui/SharedDialogConfirm.luau")
local FooterActions = require("./ui/FooterActions.luau")
local FooterShortcutHint = require("./ui/FooterShortcutHint.luau")

local controller
local opened = false

local function formTree(form)
    if form.kind == "addFolder" or form.kind == "acceptFolder" then return BodyTabFoldersAddForm.render(controller, form) end
    if form.kind == "addDevice" or form.kind == "acceptDevice" then return AddDeviceForm.render(controller, form) end
    if form.kind == "sharing" then return BodyTabFoldersShareForm.render(controller, form) end
    if form.kind == "deviceFolders" then return BodyTabDevicesFoldersForm.render(controller, form) end
    return SettingsPage.render(controller)
end

local function render()
    if not opened or not controller then return end
    local v = controller.view
    controller.navigation, controller.actionNavigation, controller.selectionView = nil, nil, nil
    panel.setWantsSecondTicks(controller:needsTicks())
    if v.details then
        panel.render(ui.column({ key = "details", padding = 12, gap = 8 }, {
            SharedWidgetControls.label(v.details.title),
            ui.scroll({ flexGrow = 1 }, { SharedWidgetControls.label(v.details.text) }),
            ui.row({ gap = 8 }, {
                SharedWidgetControls.button("Back", function() v.details = nil; controller:save() end),
                SharedWidgetControls.button("Copy full details", function() controller:copy(v.details.text) end),
            }),
        }))
        return
    end
    if v.confirm then
        panel.render(Confirmation.render(controller))
        return
    end
    local body = {}
    if v.form then
        table.insert(body, formTree(v.form))
    else
        table.insert(body, ui.row({ gap = 8 }, {
            SharedWidgetControls.button("Folders", function() v.section = "folders"; controller:save() end, true, v.section == "folders" and "primary" or "ghost"),
            SharedWidgetControls.button("Devices", function() v.section = "devices"; controller:save() end, true, v.section == "devices" and "primary" or "ghost"),
        }))
        if v.section == "folders" then
            table.insert(body, BodyTabFoldersSelector.render(controller))
            table.insert(body, SharedWidgetControls.button("Add folder", function() controller:openForm("addFolder") end, not controller:busy()))
            table.insert(body, BodyTabFoldersCard.render(controller, Model.find(controller.snapshot.folders, v.folderId)))
        else
            table.insert(body, BodyTabDevices.render(controller))
        end
        table.insert(body, BodyInvitations.render(controller))
        table.insert(body, BodyMore.render(controller))
    end
    if controller.selectionView then
        local selection = controller.selectionView
        panel.render(ui.column({ key = "selection", padding = 12, gap = 8 }, {
            SharedWidgetControls.label(selection.title),
            SharedWidgetControls.notice(controller, controller.status.error or v.message, "on_surface_variant", "action details"),
            ui.scroll({ key = "selection-body", flexGrow = 1 }, { selection.tree }),
            SharedWidgetControls.button("Back to " .. (v.form and "form" or "overview"), selection.close),
        }))
        return
    end
    local enabled = controller.status.ready and not controller:busy()
    local message = controller.status.error or v.message
    local tree = ui.column({ padding = 12, gap = 8 }, {
        Header.render(controller),
        SharedWidgetControls.notice(controller, message ~= "" and message or "", (controller.status.error or v.noticeKind == "error" or v.noticeKind == "uncertain") and "error"
            or (v.noticeKind == "success" and "tertiary" or "on_surface_variant"), "action details"),
        ui.scroll({ key = "body", flexGrow = 1, gap = 10 }, body),
        FooterActions.render(controller, enabled),
        FooterShortcutHint.render(),
    })
    table.insert(tree.children, Navigation.decorate(controller, tree))
    panel.render(tree)
end

controller = Controller.new(noctalia, render)
local snapshots = SnapshotStore.reader(noctalia, function(value)
    controller:setSnapshot(value)
    controller:save()
end, function(active) panel.setNeedsFrameTick(active and opened) end)
noctalia.state.watch("snapshot", function(value) snapshots.select(value) end)

function onFrameTick() snapshots.step() end
function update() controller:tick() end

function onOpen()
    opened = true
    controller:setStatus(noctalia.state.get("status"))
    snapshots.select(noctalia.state.get("snapshot"))
    controller:setResults(noctalia.state.get("results"))
    render()
end

function onClose()
    opened = false
    panel.setWantsSecondTicks(false)
    panel.setNeedsFrameTick(false)
    controller:save()
end

function onKey(chord, pressed)
    if not pressed then return end
    local v = controller.view
    if v.details then
        if chord == "Alt+Left" then v.details = nil; controller:save() end
        return
    end
    if v.confirm then
        if chord == "Alt+Left" then controller:cancel()
        elseif chord == "Alt+Up" or chord == "Alt+Down" then
            v.confirm.choice = v.confirm.choice == "accept" and "cancel" or "accept"; controller:save()
        elseif chord == "Alt+Return" then
            if v.confirm.choice == "accept" then controller:acceptConfirmation() else controller:cancel() end
        end
        return
    end
    if controller.navigation and controller.navigation(chord) then return end
    if chord == "Alt+Left" then controller:cancel(); return end
    if controller.actionNavigation and controller.actionNavigation(chord) then return end
    if chord == "q" then panel.close(); return end
    if v.form then return end
    if chord == "r" then controller:rescanAll()
    elseif chord == "w" and (controller.snapshot.connection or {}).online then controller:send("webui.open", {})
    elseif chord == "s" then controller:openForm("settings")
    elseif chord == "p" then
        local lifecycle = controller.snapshot.lifecycle or {}
        if lifecycle.canControl or (not lifecycle.active and lifecycle.canStart) then
            controller:confirm(lifecycle.active and "Stop Syncthing?" or "Start Syncthing?",
                lifecycle.active and "lifecycle.stop" or "lifecycle.start", {})
        end
    end
end
