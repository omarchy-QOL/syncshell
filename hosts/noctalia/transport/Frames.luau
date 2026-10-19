local Frames = {}
local MAX_BYTES = 8 * 1024 * 1024
local CHUNK_BYTES = 4 * 1024

function Frames.new()
    return { frame = 0, bytes = 0, next = 1, started = 0, count = 0 }
end

local function integer(value)
    return type(value) == "number" and value >= 1 and value % 1 == 0
end

function Frames.push(state, part, now)
    if type(part) ~= "table" or part.transport ~= 1 or not integer(part.frame)
        or not integer(part.index) or not integer(part.count)
        or part.count > 2060 or part.index > part.count
        or type(part.data) ~= "string" or #part.data > CHUNK_BYTES then
        return nil, "Invalid transport chunk"
    end
    if state.next == 1 then
        if part.frame ~= state.frame + 1 or part.index ~= 1 then
            return nil, "Missing or repeated transport frame"
        end
        state.frame = part.frame
        state.count = part.count
        state.started = now
    end
    if part.frame ~= state.frame or part.index ~= state.next or part.count ~= state.count
        or now - state.started > 30000 then
        return nil, "Incomplete or out-of-order transport frame"
    end
    local needsAck = part.index % 8 == 0 or part.index == part.count
    local token = tostring(part.frame) .. ":" .. tostring(part.index)
    if (needsAck and part.ack ~= token) or (not needsAck and part.ack ~= nil) then
        return nil, "Invalid transport acknowledgement"
    end
    state.bytes += #part.data
    if state.bytes > MAX_BYTES then
        return nil, "Transport frame exceeds the supported limit"
    end
    state.next += 1
    if part.index == part.count then
        state.bytes, state.next = 0, 1
        return true, nil, part.ack
    end
    return nil, nil, part.ack
end

function Frames.expired(state, now)
    return state.next > 1 and now - state.started > 30000
end

return Frames
