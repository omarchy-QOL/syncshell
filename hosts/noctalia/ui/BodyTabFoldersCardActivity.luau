local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local Activity = {}

function Activity.render(controller, folderId)
    local activity = (controller.snapshot.activity or {}).current
    if not activity or (folderId and activity.folderId ~= folderId) then return ui.column({}) end
    local color = Palette.roles[activity.action == "removing" and "error"
        or (activity.action == "upload" and "success" or "info")]
    local live = (controller.snapshot.connection or {}).online and (controller.snapshot.connection or {}).fresh
    local dots = live and string.rep(".", controller.activityPhase or 0) or ""
    return ui.column({ gap = 4 }, {
        SharedWidgetControls.label((live and "File syncing" or "Last reported activity") .. dots .. " | " .. activity.action, color),
        SharedWidgetControls.label(activity.path .. "\n" .. activity.detail, color),
    })
end

return Activity
