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
    return ui.button({ key = key, text = text, tooltip = help, height = Ui.control, fontSize = Ui.caption, variant = "outline", enabled = enabled, onClick = callback })
end

function Form.render(controller, form)
    if form.picker then return Picker.render(controller, form) end
    local problem = Validation.problem(controller.snapshot, form)
    local devices = Model.remoteDevices(controller.snapshot)
    local selected = #Model.selected(form.selected)
    local children = {
        BodyFormHeader.render(controller, "ADD FOLDER"),
        Source.render(controller, form),
        SharedWidgetControls.field(controller, form, "path", "Local directory", { focus = true, revision = form.pathRevision,
            placeholder = "/path/to/my/folder", trailing = trailing("Browse directories", "BROWSE", "Choose an existing local directory", function()
                Picker.open(controller, form.path ~= "" and form.path or (controller.host.getenv("HOME") or "/"))
            end, not controller:busy()) }),
        SharedWidgetControls.field(controller, form, "label", "Label", { revision = form.labelRevision,
            placeholder = "Derived from the directory name when empty" }),
        SharedWidgetControls.field(controller, form, "folderId", "Folder ID", { enabled = not form.pendingDeviceId, revision = form.idRevision,
            placeholder = controller:actionLabel("folder.suggest-id", "") ~= "" and "Generating..." or "Required folder identity",
            onSubmit = function() controller:submitForm() end,
            trailing = trailing(controller:actionKey("generate-id"), "NEW ID", "Generate a new Syncthing folder ID", function() controller:send("folder.suggest-id", {}) end,
                not form.pendingDeviceId and not controller:busy()) }),
        SharedWidgetControls.hint("Reuse the exact ID to rejoin an existing remote folder. A new ID creates a different folder identity."),
        MultiSelect.render(controller, form, devices, "Share with selected devices. No selection keeps the folder local only."),
        SharedWidgetControls.hint(selected == 0 and "Local only: not shared with other devices."
            or "Selected devices receive a share offer and may need to accept it.", selected == 0 and "secondary" or nil),
    }
    if #devices == 0 then
        table.insert(children, SharedWidgetControls.button("Add remote device", function() controller:openForm("addDevice") end, not controller:busy()))
    end
    -- Omarchy stays quiet until there is an entry to judge.
    if problem and form.path ~= "" then table.insert(children, SharedWidgetControls.hint(problem, "error")) end
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("folder.add-existing", "ADD FOLDER", "ADDING..."), function() controller:submitForm() end,
        problem == nil and not controller:busy() and controller.status.ready, "outline", "Add folder submit"))
    return ui.column({ gap = 8 }, children)
end

return Form
