local Controls = require("./Controls.luau")
local Model = require("../models/PanelModel.luau")
local MultiSelect = require("./SyncshellMultiSelect.luau")
local Source = require("./FolderSource.luau")
local Picker = require("./DirectoryPicker.luau")
local Validation = require("../models/FormModel.luau")
local Form = {}

function Form.render(controller, form)
    if form.picker then return Picker.render(controller, form) end
    local problem = Validation.problem(controller.snapshot, form)
    return ui.column({ gap = 10 }, {
        Controls.formHeader(controller, form.pendingDeviceId and "Accept folder invitation" or "Add folder"),
        Source.render(controller, form),
        Controls.field(controller, form, "path", "Directory", { focus = true, revision = form.pathRevision }),
        Controls.button("Browse directories", function()
            Picker.open(controller, form.path ~= "" and form.path or (controller.host.getenv("HOME") or "/"))
        end, not controller:busy()),
        Controls.field(controller, form, "label", "Label (optional)", { revision = form.labelRevision,
            placeholder = "Derived from the directory name when empty" }),
        Controls.field(controller, form, "folderId", "Folder ID", { enabled = not form.pendingDeviceId, revision = form.idRevision,
            onSubmit = function() controller:submitForm() end }),
        Controls.button("Generate ID", function() controller:send("folder.suggest-id", {}) end,
            not form.pendingDeviceId and not controller:busy(), nil, controller:actionKey("generate-id")),
        Controls.label("Reuse the exact ID to rejoin a remote folder. A new ID creates a different identity.", "on_surface_variant"),
        MultiSelect.render(controller, form, Model.remoteDevices(controller.snapshot),
            "Share with selected devices. No selection keeps the folder local only."),
        Controls.button("Add remote device", function() controller:openForm("addDevice") end, not controller:busy()),
        Controls.label(problem or "Ready to add this folder", problem and "error" or "on_surface_variant"),
        Controls.button(controller:actionLabel("folder.add-existing", "Add folder"), function() controller:submitForm() end,
            problem == nil and not controller:busy() and controller.status.ready, "primary"),
    })
end

return Form
