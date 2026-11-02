local Ui = require("./hosts/noctalia/ui/UiConstants.luau")
local SnapshotStore = require("./hosts/noctalia/transport/SnapshotStore.luau")
local Controller = require("./hosts/noctalia/controllers/PanelController.luau")
local Navigation = require("./hosts/noctalia/models/PanelNavigation.luau")
local Model = require("./hosts/noctalia/models/PanelModel.luau")
local Palette = require("./hosts/noctalia/controllers/ThemePaletteController.luau")
local SharedWidgetControls = require("./hosts/noctalia/ui/SharedWidgetControls.luau")
local Header = require("./hosts/noctalia/ui/Header.luau")
local BodyTabFolders = require("./hosts/noctalia/ui/BodyTabFolders.luau")
local BodyTabDevices = require("./hosts/noctalia/ui/BodyTabDevices.luau")
local BodyInvitations = require("./hosts/noctalia/ui/BodyInvitations.luau")
local BodyMore = require("./hosts/noctalia/ui/BodyMore.luau")
local BodyTabFoldersAddForm = require("./hosts/noctalia/ui/BodyTabFoldersAddForm.luau")
local AddDeviceForm = require("./hosts/noctalia/ui/BodyTabDevicesAddForm.luau")
local BodyTabFoldersShareForm = require("./hosts/noctalia/ui/BodyTabFoldersShareForm.luau")
local BodyTabDevicesFoldersForm = require("./hosts/noctalia/ui/BodyTabDevicesFoldersForm.luau")
local SettingsPage = require("./hosts/noctalia/ui/SettingsPage.luau")
local SettingsMenu = require("./hosts/noctalia/ui/SettingsMenu.luau")
local SettingsSelfRemovalSteps = require("./hosts/noctalia/ui/SettingsSelfRemovalSteps.luau")
local Confirmation = require("./hosts/noctalia/ui/SharedDialogConfirm.luau")
local SharedDialogChoice = require("./hosts/noctalia/ui/SharedDialogChoice.luau")
local FooterActions = require("./hosts/noctalia/ui/FooterActions.luau")
local FooterShortcutHint = require("./hosts/noctalia/ui/FooterShortcutHint.luau")

local controller
local opened = false

local function formTree(form)
    if form.kind == "settings" then
        if form.page == "webui" then return SettingsPage.render(controller) end
        if form.page == "removal" then return SettingsSelfRemovalSteps.render(controller) end
        return SettingsMenu.render(controller)
    end
    if form.kind == "addFolder" then return BodyTabFoldersAddForm.render(controller, form) end
    if form.kind == "addDevice" or form.kind == "acceptDevice" then return AddDeviceForm.render(controller, form) end
    if form.kind == "sharing" then return BodyTabFoldersShareForm.render(controller, form) end
    if form.kind == "deviceFolders" then return BodyTabDevicesFoldersForm.render(controller, form) end
    error("unknown form " .. tostring(form.kind))
end

local function render()
    if not opened or not controller then return end
    local v = controller.view
    Palette.refresh(noctalia)
    controller.dropdownLong = nil
    controller.navigation, controller.actionNavigation, controller.dropdownList = nil, nil, nil
    panel.setWantsSecondTicks(controller:needsTicks())
    if v.details then
        panel.render(ui.column({ key = "details", flexGrow = 1, padding = 12, gap = 8 }, {
            SharedWidgetControls.label(v.details.title),
            ui.scroll({ flexGrow = 1 }, { SharedWidgetControls.label(v.details.text) }),
            ui.row({ gap = 8 }, {
                SharedWidgetControls.button("Back", function() v.details = nil; controller:save() end),
                SharedWidgetControls.button("Copy full details", function() controller:copy(v.details.text) end),
            }),
        }))
        return
    end
    local body = {}
    if v.form then
        table.insert(body, formTree(v.form))
    else
        local function tab(key, text, section)
            -- Omarchy marks the open tab with a quiet fill; the host's selected button is loud.
            return ui.row({ key = key, height = Ui.control, paddingH = 10, align = "center", radius = 3, border = "outline", borderWidth = 1,
                fill = v.section == section and "on_surface/0.18" or "#00000000",
                onClick = function()
                    -- Omarchy closes open lists with the tab.
                    v.section, v.filtersOpen = section, false
                    for _, item in v.selectors or {} do item.open = false end
                    controller:save()
                end },
                { ui.label({ text = text, fontSize = Ui.caption, maxLines = 1 }) })
        end
        table.insert(body, ui.row({ gap = 6, justify = "start" }, {
            tab("Folders", "FOLDERS (" .. tostring(#(controller.snapshot.folders or {})) .. ")", "folders"),
            tab("Devices", "DEVICES (" .. tostring(#Model.remoteDevices(controller.snapshot)) .. ")", "devices"),
        }))
        if v.section == "folders" then
            table.insert(body, BodyTabFolders.render(controller))
        else
            table.insert(body, BodyTabDevices.render(controller))
        end
        if not controller.dropdownList then
            local invitations = BodyInvitations.render(controller)
            if invitations then table.insert(body, invitations) end
            table.insert(body, BodyMore.render(controller))
        end
    end
    local enabled = controller.status.ready and not controller:busy()
    local bodyKey = v.form and ("form-" .. tostring(v.form.token)) or ("overview-" .. v.section)
    -- Omarchy's settings menu replaces the whole panel.
    local top = (v.form and v.form.kind == "settings") and {} or { Header.render(controller, v.form ~= nil) }
    if #top > 0 then table.insert(top, SharedWidgetControls.separator()) end
    -- Omarchy's forms open beside the panel, its view options and long lists over the footer;
    -- this fixed surface lends them the footer's space.
    local bottom = (v.form or (controller.dropdownList and (v.filtersOpen or controller.dropdownLong))) and {}
        or { SharedWidgetControls.separator(), FooterActions.render(controller, enabled), FooterShortcutHint.render() }
    -- Retained native nodes keep an omitted prop, so opacity is always explicit.
    local opacity = v.confirm and 0.35 or 1
    -- The host insets a scroll's content, so the edges above and below follow it.
    local top_ = ui.column({ key = "panel-top", gap = 8, paddingH = 4, opacity = opacity }, top)
    local bottom_ = ui.column({ key = "panel-bottom", gap = 8, paddingH = 4, opacity = opacity }, bottom)
    local lifecycle = controller.snapshot.lifecycle or {}
    local drift = lifecycle.canControl and not v.confirm and Model.driftDecision(noctalia.getConfig("serviceState"), lifecycle)
    if drift and drift.status == "drift" then
        v.driftChoice = v.driftChoice or "drift-first"
        controller.navigation = function(chord)
            if chord == "Alt+Up" or chord == "Alt+Down" then
                v.driftChoice = v.driftChoice == "drift-first" and "drift-second" or "drift-first"; controller:save()
            elseif chord == "Alt+Return" then
                controller:chooseDrift(v.driftChoice == "drift-first" and drift.first or drift.second)
            elseif chord == "q" then
                panel.close()
            end
            return true
        end
        top_.props.opacity, bottom_.props.opacity = 0.35, 0.35
        Confirmation.dim(top_); Confirmation.dim(bottom_)
        panel.render(ui.column({ flexGrow = 1, padding = 12, gap = 8 }, {
            top_,
            ui.column({ key = "panel-dialog", flexGrow = 1, paddingH = 4, justify = "center" }, { SharedDialogChoice.render(controller, drift) }),
            bottom_,
        }))
        return
    end
    if v.confirm then
        Confirmation.dim(top_); Confirmation.dim(bottom_)
        -- Omarchy's scrim cancels; the space around the dialog stands in for it.
        local function scrim() return ui.box({ flexGrow = 1, fill = "#00000000", onClick = function() controller:cancel() end }) end
        panel.render(ui.column({ flexGrow = 1, padding = 12, gap = 8 }, {
            top_,
            ui.column({ key = "panel-dialog", flexGrow = 1, paddingH = 4 }, { scrim(), Confirmation.render(controller), scrim() }),
            bottom_,
        }))
        return
    end
    local tree = ui.column({ flexGrow = 1, padding = 12, gap = 8 }, {
        top_,
        ui.scroll({ key = bodyKey, flexGrow = 1, gap = 8, padding = 0, scrollToBottomRev = v.scrollRevision }, body),
        bottom_,
    })
    Navigation.decorate(controller, tree)
    panel.render(tree)
end

controller = Controller.new(noctalia, render)
local snapshots = SnapshotStore.reader(noctalia, function(value)
    controller:setSnapshot(value)
    controller:save()
end, function(active) panel.setNeedsFrameTick(active and opened) end)
noctalia.state.watch("snapshot", function(value) snapshots.select(value) end)

function onConfigChanged() render() end
function onFrameTick() snapshots.step() end
function update() controller:tick() end

function onOpen()
    opened = true
    controller:setStatus(noctalia.state.get("status"))
    snapshots.select(noctalia.state.get("snapshot"))
    controller:setResults(noctalia.state.get("results"))
    render()
    -- As Omarchy does on opening, without waiting for the next timed refresh.
    controller:refreshInBackground()
end

function onClose()
    opened = false
    controller:resetTransient()
    panel.setWantsSecondTicks(false)
    panel.setNeedsFrameTick(false)
    controller:save()
end

-- Omarchy's plain keys. Left and Right stay with text fields and Enter with
-- the focused control, as a captured chord is always consumed: Space activates
-- the cursor instead. Printable keys go to a focused field first.
local chords = { Up = "cursor-up", k = "cursor-up", Down = "cursor-down", j = "cursor-down",
    h = "cursor-left", l = "cursor-right", space = "Alt+Return" }
-- Lists and dialogs have one axis, so any direction steps through them.
local oneAxis = { ["cursor-up"] = "Alt+Up", ["cursor-left"] = "Alt+Up", ["cursor-down"] = "Alt+Down", ["cursor-right"] = "Alt+Down" }

function onKey(chord, pressed)
    if not pressed then return end
    local v = controller.view
    chord = chords[chord] or chord
    if v.details then
        if chord == "Alt+Left" then v.details = nil; controller:save() end
        return
    end
    if v.confirm then
        chord = oneAxis[chord] or chord
        if chord == "Alt+Left" then controller:cancel()
        elseif chord == "Alt+Up" or chord == "Alt+Down" then
            v.confirm.choice = v.confirm.choice == "accept" and "cancel" or "accept"; controller:save()
        elseif chord == "Alt+Return" then
            if v.confirm.choice == "accept" then controller:acceptConfirmation() else controller:cancel() end
        end
        return
    end
    if controller.navigation then
        -- An open list owns the keyboard: its letters must never reach the panel's shortcuts.
        controller.navigation(chord == "q" and "Alt+Left" or (oneAxis[chord] or chord), chord)
        return
    end
    if chord == "Alt+Left" then controller:cancel(); return end
    if controller.actionNavigation and controller.actionNavigation(chord) then return end
    if chord == "q" then
        if v.form then controller:cancel() else panel.close() end
        return
    end
    if v.form then return end
    if chord == "r" then controller:rescanAll()
    elseif chord == "w" then controller:openWebUi()
    elseif chord == "s" then controller:openForm("settings")
    elseif chord == "p" then
        local lifecycle = controller.snapshot.lifecycle or {}
        if lifecycle.canControl or lifecycle.canStart then
            controller:send(lifecycle.active and "lifecycle.stop" or "lifecycle.start", {})
        end
    end
end
