local Controls = require("./Controls.luau")
local Model = require("../models/PanelModel.luau")
local InstallationHelp = require("./InstallationHelp.luau")
local Details = {}

function Details.render(controller)
    local v, s = controller.view, controller.snapshot
    local children = { Controls.button(v.more and "Less" or "More", function() v.more = not v.more; controller:save() end) }
    if v.more then
        local connection, installation = s.connection or {}, s.installation or {}
        table.insert(children, Controls.label(connection.fresh and "State is fresh" or "State is stale; refresh or check the connection",
            connection.fresh and "on_surface_variant" or "error"))
        if v.lastFailure then
            table.insert(children, Controls.label("Last action failure: " .. v.lastFailure, "error"))
            table.insert(children, Controls.button("Copy last failure", function() controller:copy(v.lastFailure) end))
        end
        local problems = Model.problems(s)
        table.insert(children, Controls.label("Syncthing status: " .. (#problems > 0 and "errors" or
            (connection.online and connection.fresh and "clean" or "unavailable"))))
        if #problems > 0 and (not connection.online or not connection.fresh) then
            table.insert(children, Controls.label("Last reported errors; current status is unavailable.", "error"))
        end
        v.problemPage = math.clamp(v.problemPage or 1, 1, math.max(1, math.ceil(#problems / 4)))
        local first = (v.problemPage - 1) * 4 + 1
        if #problems > 0 then table.insert(children, Controls.label(tostring(#problems) .. " affected folders | Page " .. tostring(v.problemPage))) end
        for index = first, math.min(first + 3, #problems) do
            local problem = problems[index]
            local detail = Model.errorText(problem.status)
            table.insert(children, ui.column({ key = "problem-" .. problem.id, gap = 6 }, {
                Controls.label("Affected: " .. problem.path .. " | " .. problem.id, "error"),
                Controls.label(detail, "error"),
                Controls.label("Showing " .. tostring(problem.shown) .. " of " .. tostring(problem.count)
                    .. " reported errors. Open Web UI for full details.", "on_surface_variant"),
                ui.row({ gap = 6 }, {
                    Controls.button("Show folder", function()
                        v.folderId, v.section = problem.id, "folders"; controller:save()
                    end),
                    Controls.button("Copy error details", function() controller:copy(problem.path .. "\n" .. detail) end),
                }),
            }))
        end
        if #problems > 4 then
            table.insert(children, ui.row({ gap = 6 }, {
                Controls.button("Previous errors", function() v.problemPage -= 1; controller:save() end, v.problemPage > 1),
                Controls.button("Next errors", function() v.problemPage += 1; controller:save() end, first + 4 <= #problems),
            }))
        end
        table.insert(children, Controls.button("Full details in Web UI", function() controller:send("webui.open", {}) end,
            connection.online and not controller:busy(), nil, controller:actionKey("details-webui")))
        if connection.error then table.insert(children, Controls.label(connection.error.message, "error")) end
        table.insert(children, InstallationHelp.render(controller))
        table.insert(children, Controls.label("Syncthing: " .. ((s.identity or {}).version or "Unavailable") .. " | "
            .. (installation.executablePath or "Executable not found"), "on_surface_variant"))
        table.insert(children, Controls.label("Endpoint: " .. (connection.endpoint or "Not discovered"), "on_surface_variant"))
        for key, count in s.truncation or {} do
            if count > 0 then table.insert(children, Controls.label(tostring(count) .. " additional " .. key .. "; use Web UI", "error")) end
        end
        table.insert(children, Controls.button("Recheck folder errors", function() controller:send("folder.recheck-errors", {}) end,
            connection.online and not controller:busy(), nil, controller:actionKey("recheck")))
    end
    return Controls.column({ gap = 8 }, children)
end

return Details
