local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Ui = require("./UiConstants.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local BodyMoreInstallationHelp = require("./BodyMoreInstallationHelp.luau")
local Details = {}
-- Native trees are bounded, so long error lists page instead of scrolling.
local errorPage = 4

function Details.render(controller)
    local v, s = controller.view, controller.snapshot
    local children = { ui.button({ key = v.more and "Less" or "More", text = v.more and "Less" or "More", glyph = v.more and "chevron-up" or "chevron-down",
        variant = "ghost", contentAlign = "start", height = Ui.control, fontSize = Ui.body, glyphSize = Ui.body,
        onClick = function() v.more = not v.more; controller:save() end }) }
    if v.more then
        local connection = s.connection or {}
        local problems = Model.problems(s)
        local fresh = connection.online and connection.fresh
        table.insert(children, ui.row({ gap = 8, align = "center" }, {
            SharedWidgetControls.caption("SYNCTHING STATUS"),
            ui.label({ text = #problems > 0 and "errors" or (fresh and "clean" or "unavailable"), fontSize = Ui.caption, fontWeight = "bold",
                color = #problems > 0 and "error" or (fresh and Palette.roles.success or "on_surface_variant") }),
        }))
        if not fresh then
            table.insert(children, SharedWidgetControls.hint(#problems > 0 and "Last reported errors; current status is unavailable."
                or "Current Syncthing status is unavailable.", "error"))
        end
        v.problemPage = math.clamp(v.problemPage or 1, 1, math.max(1, math.ceil(#problems / errorPage)))
        local first = (v.problemPage - 1) * errorPage + 1
        for index = first, math.min(first + errorPage - 1, #problems) do
            local problem = problems[index]
            local rows = {
                ui.row({ gap = 4, align = "center" }, {
                    ui.glyph({ name = "folder", size = Ui.caption, color = "on_surface_variant" }),
                    SharedWidgetControls.hint("affected: " .. problem.path),
                }),
                ui.label({ text = Model.errorText(problem.status), color = "error", fontSize = Ui.bodySmall, maxLines = 0 }),
            }
            if problem.shown < problem.count then
                table.insert(rows, SharedWidgetControls.hint("Showing " .. tostring(problem.shown) .. " of " .. tostring(problem.count)
                    .. " current errors. Open Web UI for the full list."))
            end
            table.insert(children, ui.column({ key = "problem-" .. problem.id, gap = 4 }, rows))
        end
        if #problems > errorPage then
            table.insert(children, ui.row({ gap = 6 }, {
                SharedWidgetControls.button("Previous errors", function() v.problemPage -= 1; controller:save() end, v.problemPage > 1, "outline"),
                SharedWidgetControls.button("Next errors", function() v.problemPage += 1; controller:save() end, first + errorPage <= #problems, "outline"),
            }))
        end
        table.insert(children, ui.separator({}))
        table.insert(children, BodyMoreInstallationHelp.render(controller))
    end
    return SharedWidgetControls.column({ gap = 8 }, children)
end

return Details
