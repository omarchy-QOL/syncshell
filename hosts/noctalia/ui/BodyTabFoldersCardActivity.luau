local Ui = require("./UiConstants.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local Activity = {}

function Activity.render(controller, folderId)
    local activity = (controller.snapshot.activity or {}).current
    if not activity or not folderId or activity.folderId ~= folderId then
        return ui.label({ text = " ", fontSize = Ui.caption, maxLines = 1 })
    end
    -- The label keeps the sync color; only the detail shows the file's direction.
    local detailColor = Palette.roles[activity.action == "removing" and "error"
        or (activity.action == "upload" and "success" or "info")]
    local color = Palette.roles.info
    local dots = string.rep(".", controller.activityPhase or 0)
    return ui.row({ gap = 4, align = "center" }, {
        ui.row({ gap = 0, align = "center" }, {
            ui.label({ text = "File syncing", color = color, fontSize = Ui.caption, maxLines = 1 }),
            -- Omarchy reserves the dots' width so the file name stays put.
            ui.label({ text = dots, color = color, fontSize = Ui.caption, maxLines = 1, width = 12 }),
        }),
        ui.label({ text = activity.detail or activity.path, color = detailColor, fontSize = Ui.caption, maxLines = 1, flexGrow = 1 }),
    })
end

return Activity
