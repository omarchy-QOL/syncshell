local Palette = require("../controllers/ThemePaletteController.luau")
local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local Model = require("../models/PanelModel.luau")
local MultiSelect = require("./SharedWidgetMultiSelect.luau")
local Source = require("./BodyTabFoldersAddFormSource.luau")
local Picker = require("./BodyTabFoldersAddFormPicker.luau")
local Validation = require("../models/FormModel.luau")
local Form = {}

local function trailing(key, text, help, callback, enabled)
    return ui.button({ key = key, text = text, tooltip = help, height = Ui.field, fontSize = Ui.caption, variant = "outline", enabled = enabled, onClick = callback })
end

function Form.render(controller, form)
    if form.picker then return Picker.render(controller, form) end
    local devices = Model.remoteDevices(controller.snapshot)
    local selected = #Model.selected(form.selected)
    local children = {
        BodyFormHeader.render(controller, "ADD FOLDER"),
        Source.render(controller, form),
        SharedWidgetControls.field(controller, form, "path", "Local directory", { focus = true, revision = form.pathRevision,
            placeholder = "/path/to/my/folder", trailing = trailing("Browse directories", "BROWSE", "Choose an existing local directory", function()
                Picker.open(controller, form.path ~= "" and form.path or (controller.host.getenv("HOME") or "/"))
            end, not controller:busy()) }),
        SharedWidgetControls.field(controller, form, "label", "Label", { revision = form.labelRevision, onEdited = function() form.labelFromOffer = false end,
            placeholder = "Derived from the directory name when empty" }),
        SharedWidgetControls.field(controller, form, "folderId", "Folder ID", { revision = form.idRevision,
            placeholder = (controller.view.pending or {}).action == "folder.suggest-id" and "Generating..." or "Required folder identity",
            onEdited = function() form.prepareError = nil end,
            onSubmit = function() controller:submitForm() end,
            trailing = trailing(controller:actionKey("generate-id"), "NEW ID", "Generate a new Syncthing folder ID", function()
                -- A new identity leaves any chosen offer, as in Omarchy.
                form.pendingDeviceId, form.folderId, form.idRevision = nil, "", (form.idRevision or 0) + 1
                form.prepareError = nil
                controller:send("folder.suggest-id", {})
            end, not controller:busy() and (controller.view.pending or {}).action ~= "folder.suggest-id") }),
        form.prepareError and SharedWidgetControls.hint(form.prepareError, "error") or SharedWidgetControls.hint("Reuse the exact ID to rejoin an existing remote folder. A new ID creates a different folder identity."),
        MultiSelect.render(controller, form, devices),
        SharedWidgetControls.hint(selected == 0 and "Local only: not shared with other devices."
            or "Selected devices receive a share offer and may need to accept it.", selected == 0 and Palette.roles.warning or nil),
    }
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("folder.add-existing", "ADD FOLDER", "ADDING..."), function() controller:submitForm() end,
        Validation.trim(form.path) ~= "" and Validation.trim(form.folderId) ~= "" and (controller.snapshot.connection or {}).online == true
            and not controller:busy() and controller.status.ready, "outline", "Add folder submit"))
    return ui.column({ gap = 8 }, children)
end

return Form
