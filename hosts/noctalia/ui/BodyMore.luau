local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local BodyMoreInstallationHelp = require("./BodyMoreInstallationHelp.luau")
local Details = {}

function Details.render(controller)
    local v, s = controller.view, controller.snapshot
    local children = { ui.button({ key = v.more and "Less" or "More", text = v.more and "Less" or "More", glyph = v.more and "chevron-up" or "chevron-down",
        variant = "ghost", contentAlign = "start", controlSize = "sm", fontSize = 13, glyphSize = 14, onClick = function() v.more = not v.more; controller:save() end }) }
    if v.more then
        local connection, installation = s.connection or {}, s.installation or {}
        if v.lastFailure then
            table.insert(children, SharedWidgetControls.label("Last action failure: " .. v.lastFailure, "error"))
            table.insert(children, SharedWidgetControls.button("Copy last failure", function() controller:copy(v.lastFailure) end))
        end
        local problems = Model.problems(s)
        local clean = #problems == 0 and connection.online and connection.fresh
        table.insert(children, ui.row({ gap = 8, align = "center" }, {
            SharedWidgetControls.caption("SYNCTHING STATUS"),
            ui.label({ text = #problems > 0 and "errors" or (clean and "clean" or "unavailable"), fontSize = 12, fontWeight = "bold",
                color = #problems > 0 and "error" or (clean and Palette.roles.success or "on_surface_variant") }),
        }))
        if #problems > 0 and (not connection.online or not connection.fresh) then
            table.insert(children, SharedWidgetControls.label("Last reported errors; current status is unavailable.", "error"))
        end
        v.problemPage = math.clamp(v.problemPage or 1, 1, math.max(1, math.ceil(#problems / 4)))
        local first = (v.problemPage - 1) * 4 + 1
        if #problems > 0 then table.insert(children, SharedWidgetControls.label(tostring(#problems) .. " affected folders | Page " .. tostring(v.problemPage))) end
        for index = first, math.min(first + 3, #problems) do
            local problem = problems[index]
            local detail = Model.errorText(problem.status)
            table.insert(children, ui.column({ key = "problem-" .. problem.id, gap = 6 }, {
                SharedWidgetControls.label("Affected: " .. problem.path .. " | " .. problem.id, "error"),
                SharedWidgetControls.label(detail, "error"),
                SharedWidgetControls.label("Showing " .. tostring(problem.shown) .. " of " .. tostring(problem.count)
                    .. " reported errors. Open Web UI for full details.", "on_surface_variant"),
                ui.row({ gap = 6 }, {
                    SharedWidgetControls.button("Show folder", function()
                        v.folderId, v.section = problem.id, "folders"; controller:save()
                    end),
                    SharedWidgetControls.button("Copy error details", function() controller:copy(problem.path .. "\n" .. detail) end),
                }),
            }))
        end
        if #problems > 4 then
            table.insert(children, ui.row({ gap = 6 }, {
                SharedWidgetControls.button("Previous errors", function() v.problemPage -= 1; controller:save() end, v.problemPage > 1),
                SharedWidgetControls.button("Next errors", function() v.problemPage += 1; controller:save() end, first + 4 <= #problems),
            }))
        end
        if connection.error then table.insert(children, SharedWidgetControls.label(connection.error.message, "error")) end
        table.insert(children, BodyMoreInstallationHelp.render(controller))
        for key, count in s.truncation or {} do
            if count > 0 then table.insert(children, SharedWidgetControls.label(tostring(count) .. " additional " .. key .. "; use Web UI", "error")) end
        end
    end
    return SharedWidgetControls.column({ gap = 8 }, children)
end

return Details
