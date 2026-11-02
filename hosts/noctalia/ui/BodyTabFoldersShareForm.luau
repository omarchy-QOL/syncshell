local Palette = require("../controllers/ThemePaletteController.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local Model = require("../models/PanelModel.luau")
local MultiSelect = require("./SharedWidgetMultiSelect.luau")
local Form = {}

function Form.render(controller, form)
    local folder = Model.find(controller.snapshot.folders, form.folderId)
    local devices = Model.remoteDevices(controller.snapshot)
    local children = {
        BodyFormHeader.render(controller, "SHARE " .. (folder and Model.folderLabel(folder) or "FOLDER")),
        MultiSelect.render(controller, form, devices),
    }
    if #devices == 0 then
        table.insert(children, SharedWidgetControls.hint("No remote devices available. Add a remote device below.", Palette.roles.warning))
    else
        table.insert(children, SharedWidgetControls.button(controller:actionLabel("folder.set-sharing", "SAVE SHARING", "SAVING..."), function() controller:submitForm() end,
            folder ~= nil and (controller.snapshot.connection or {}).online == true and not controller:busy() and controller.status.ready, "outline", "Save sharing"))
    end
    return ui.column({ gap = 8 }, children)
end

return Form
