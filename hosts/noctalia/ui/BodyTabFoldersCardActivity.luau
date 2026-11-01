local Ui = require("./UiConstants.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local Activity = {}

function Activity.render(controller, folderId)
    local activity = (controller.snapshot.activity or {}).current
    if not activity or (folderId and activity.folderId ~= folderId) then return nil end
    local color = Palette.roles[activity.action == "removing" and "error"
        or (activity.action == "upload" and "success" or "info")]
    local live = (controller.snapshot.connection or {}).online and (controller.snapshot.connection or {}).fresh
    local dots = live and string.rep(".", controller.activityPhase or 0) or ""
    return ui.row({ gap = 4, align = "center" }, {
        ui.label({ text = (live and "File syncing" or "Last reported activity") .. dots, color = color, fontSize = Ui.caption, maxLines = 1 }),
        ui.label({ text = activity.detail or activity.path, color = color, fontSize = Ui.caption, maxLines = 1, flexGrow = 1 }),
    })
end

return Activity
