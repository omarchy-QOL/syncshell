local JsonFrame = require("./JsonFrame.luau")
local Store = {}

local function key(bank, index)
    return "snapshot-" .. tostring(bank) .. "-" .. tostring(index)
end

function Store.writer(host)
    local previous = host.state.get("snapshot")
    local bank = previous and previous.bank or 0
    local descriptor
    return {
        push = function(part, generation)
            if part.index == 1 then
                bank = 1 - bank
                descriptor = { bank = bank, generation = generation, frame = part.frame, count = part.count }
            end
            host.state.set(key(bank, part.index), { generation = generation, frame = part.frame, data = part.data })
        end,
        commit = function(revision, received)
            descriptor.revision, descriptor.received = revision, received
            host.state.set("snapshot", descriptor)
        end,
    }
end

-- Two bounded banks let readers finish the previous snapshot during a write.
-- A reader overtaken by the producer discards its partial tree and starts fresh.
function Store.reader(host, ready, active)
    local descriptor, parser, index
    local completed
    local function select(value)
        active(descriptor ~= nil)
        if not value or (descriptor and value.generation == descriptor.generation and value.frame == descriptor.frame)
            or (completed and value.generation == completed.generation and value.frame == completed.frame) then return end
        descriptor, parser, index = value, JsonFrame.new(host.json.decode), 1
        active(true)
    end
    local function step()
        if not descriptor then return end
        local part = host.state.get(key(descriptor.bank, index))
        if not part or part.generation ~= descriptor.generation or part.frame ~= descriptor.frame then
            descriptor, parser = nil, nil
            active(false)
            select(host.state.get("snapshot"))
            return
        end
        local final = index == descriptor.count
        local frame, err = parser:feed(part.data, final)
        if err then descriptor, parser = nil, nil; active(false); return end
        index += 1
        if final then
            local value = descriptor
            completed, descriptor, parser = descriptor, nil, nil
            active(false)
            ready({ generation = value.generation, revision = value.revision,
                received = value.received, state = frame.state })
        end
    end
    return { select = select, step = step }
end

return Store
