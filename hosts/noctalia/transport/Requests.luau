local Requests = {}

-- Noctalia encodes an empty table as an object, including typed sharing arrays.
function Requests.encode(request, encode)
    local copy = table.clone(request)
    if request.args then
        copy.args = table.clone(request.args)
    end
    local arrays = {}
    for _, name in { "deviceIds", "folderIds" } do
        if copy.args and copy.args[name] ~= nil then
            local values = copy.args[name]
            if type(values) ~= "table" then
                return nil, "Invalid sharing selection"
            end
            for index, value in values do
                if type(index) ~= "number" or index < 1 or index % 1 ~= 0
                    or index > #values or type(value) ~= "string" then
                    return nil, "Invalid sharing selection"
                end
            end
            if #values == 0 then
                arrays[name] = true
                copy.args[name] = nil
            end
        end
    end
    if next(arrays) then
        local args, err = encode(copy.args)
        if not args then return nil, err end
        for _, name in { "deviceIds", "folderIds" } do
            if arrays[name] then
                args = string.sub(args, 1, -2) .. (args == "{}" and "" or ",")
                    .. '"' .. name .. '":[]}'
            end
        end
        copy.args = nil
        local head, err = encode(copy)
        if not head then return nil, err end
        return string.sub(head, 1, -2) .. ',"args":' .. args .. '}'
    end
    return encode(copy)
end

function Requests.quote(value)
    return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

return Requests
