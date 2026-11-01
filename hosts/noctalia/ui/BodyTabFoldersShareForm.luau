local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local Model = require("../models/PanelModel.luau")
local Validation = require("../models/FormModel.luau")
local MultiSelect = require("./SharedWidgetMultiSelect.luau")
local Form = {}

function Form.render(controller, form)
    local folder = Model.find(controller.snapshot.folders, form.folderId)
    local problem = Validation.problem(controller.snapshot, form)
    local devices = Model.remoteDevices(controller.snapshot)
    local children = {
        BodyFormHeader.render(controller, "SHARE " .. (folder and Model.folderLabel(folder) or "FOLDER")),
        MultiSelect.render(controller, form, devices, "Save applies the entire selection. Clearing all keeps this folder local only."),
    }
    if not folder then table.insert(children, SharedWidgetControls.hint("Folder is no longer configured", "error"))
    elseif problem then table.insert(children, SharedWidgetControls.hint(problem, "error")) end
    if #devices == 0 then
        table.insert(children, SharedWidgetControls.hint("No remote devices available. Add a remote device below.", "secondary"))
        table.insert(children, SharedWidgetControls.button("Add remote device", function() controller:openForm("addDevice") end, not controller:busy()))
    end
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("folder.set-sharing", "SAVE SHARING"), function() controller:submitForm() end,
        problem == nil and not controller:busy() and controller.status.ready, "outline", "Save sharing"))
    return ui.column({ gap = 8 }, children)
end

return Form
