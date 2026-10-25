local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Validation = require("../models/FormModel.luau")
local MultiSelect = require("./SharedWidgetMultiSelect.luau")
local Form = {}

function Form.render(controller, form)
    local folder = Model.find(controller.snapshot.folders, form.folderId)
    local problem = Validation.problem(controller.snapshot, form)
    return ui.column({ gap = 10 }, {
        SharedWidgetControls.formHeader(controller, "Folder sharing"),
        SharedWidgetControls.label(folder and (Model.folderLabel(folder) .. " | " .. folder.id) or "Folder is no longer configured", folder and "on_surface" or "error"),
        SharedWidgetControls.label(problem or "Selected devices receive a share offer; no selection keeps the folder local only.", problem and "error" or "on_surface_variant"),
        MultiSelect.render(controller, form, Model.remoteDevices(controller.snapshot), "Save applies the entire selection. Clearing all keeps this folder local only."),
        SharedWidgetControls.button("Add remote device", function() controller:openForm("addDevice") end, not controller:busy()),
        SharedWidgetControls.button(controller:actionLabel("folder.set-sharing", "Save sharing"), function() controller:submitForm() end,
            problem == nil and not controller:busy() and controller.status.ready, "primary"),
    })
end

return Form
