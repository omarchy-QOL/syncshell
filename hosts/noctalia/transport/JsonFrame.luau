-- Parse one frame across bounded stream callbacks instead of one large decode.
-- Escape and scalar semantics remain owned by Noctalia's JSON codec.
local JsonFrame = {}
JsonFrame.__index = JsonFrame

function JsonFrame.new(decode)
    return setmetatable({ decode = decode, stack = {}, tail = "", rootSet = false,
        stringParts = {}, inString = false }, JsonFrame)
end

function JsonFrame:value(value)
    local parent = self.stack[#self.stack]
    if not parent then
        assert(not self.rootSet, "extra JSON value")
        self.root, self.rootSet = value, true
    elseif parent.kind == "array" then
        assert(parent.phase == "value" or parent.phase == "valueOrEnd", "unexpected array value")
        parent.index += 1
        parent.value[parent.index] = value
        parent.phase = "commaOrEnd"
    else
        assert(parent.phase == "value", "unexpected object value")
        parent.value[parent.key] = value
        parent.key, parent.phase = nil, "commaOrEnd"
    end
end

function JsonFrame:finishString()
    local text = table.concat(self.stringParts)
    self.stringParts, self.inString = {}, false
    local parent = self.stack[#self.stack]
    if parent and parent.kind == "object" and (parent.phase == "key" or parent.phase == "keyOrEnd") then
        parent.key, parent.phase = text, "colon"
    else
        self:value(text)
    end
end

function JsonFrame:punctuation(char)
    local parent = self.stack[#self.stack]
    if char == "{" or char == "[" then
        assert(#self.stack < 32, "JSON nesting exceeds limit")
        local value = {}
        self:value(value)
        table.insert(self.stack, { value = value, kind = char == "{" and "object" or "array",
            phase = char == "{" and "keyOrEnd" or "valueOrEnd", index = 0 })
    elseif char == "}" or char == "]" then
        assert(parent and parent.kind == (char == "}" and "object" or "array"), "mismatched JSON container")
        assert(parent.phase == "commaOrEnd" or parent.phase == "keyOrEnd" or parent.phase == "valueOrEnd", "incomplete JSON container")
        table.remove(self.stack)
    elseif char == ":" then
        assert(parent and parent.kind == "object" and parent.phase == "colon", "unexpected JSON colon")
        parent.phase = "value"
    else
        assert(parent and parent.phase == "commaOrEnd", "unexpected JSON comma")
        parent.phase = parent.kind == "object" and "key" or "value"
    end
end

function JsonFrame:stringSegment(raw, position)
    local quote = string.find(raw, '"', position, true)
    local slash = string.find(raw, "\\", position, true)
    local boundary = quote and slash and math.min(quote, slash) or quote or slash
    local last = boundary and boundary - 1 or #raw
    if last >= position then
        local segment = string.sub(raw, position, last)
        local valid, err = self.decode('"' .. segment .. '"')
        assert(valid and not err, "invalid JSON string segment")
        table.insert(self.stringParts, segment)
    end
    if not boundary then return #raw + 1 end
    if string.sub(raw, boundary, boundary) == '"' then
        self:finishString()
        return boundary + 1
    end
    local size = 2
    if string.sub(raw, boundary + 1, boundary + 1) == "u" then
        size = 6
        if boundary + 5 <= #raw then
            local code = tonumber(string.sub(raw, boundary + 2, boundary + 5), 16)
            if code and code >= 0xD800 and code <= 0xDBFF then size = 12 end
        end
    end
    if boundary + size - 1 > #raw then
        self.tail = string.sub(raw, boundary)
        return #raw + 1
    end
    local escaped, err = self.decode('"' .. string.sub(raw, boundary, boundary + size - 1) .. '"')
    assert(type(escaped) == "string" and not err, "invalid JSON escape")
    table.insert(self.stringParts, escaped)
    return boundary + size
end

function JsonFrame:consume(data, final)
    local raw = self.tail .. data
    self.tail = ""
    local position = 1
    while position <= #raw do
        if self.inString then
            position = self:stringSegment(raw, position)
        else
            local char = string.sub(raw, position, position)
            if char == " " or char == "\t" or char == "\r" or char == "\n" then
                position += 1
            elseif char == '"' then
                self.inString = true
                position += 1
            elseif string.find("{}[]:,", char, 1, true) then
                self:punctuation(char)
                position += 1
            else
                local boundary = string.find(raw, "[,%]%}%s]", position)
                if not boundary and not final then
                    self.tail = string.sub(raw, position)
                    assert(#self.tail <= 128, "JSON scalar exceeds limit")
                    break
                end
                local token = string.sub(raw, position, boundary and boundary - 1 or #raw)
                assert(#token <= 128, "JSON scalar exceeds limit")
                local value, err = self.decode(token)
                assert(not err and (token == "null" or type(value) == "number" or type(value) == "boolean"), "invalid JSON scalar")
                self:value(value)
                position = boundary or #raw + 1
            end
        end
    end
    if final then
        assert(self.rootSet and #self.stack == 0 and not self.inString and self.tail == "", "incomplete JSON frame")
        return self.root
    end
    return nil
end

function JsonFrame:feed(data, final)
    local ok, value = pcall(self.consume, self, data, final)
    if not ok then return nil, "Invalid JSON in core output" end
    return value
end

return JsonFrame
