local JsonFrame = require("../../hosts/noctalia/transport/JsonFrame.luau")
local Store = require("../../hosts/noctalia/transport/SnapshotStore.luau")
local raw = '{"v":2,"type":"snapshot","state":{"strings":["a\\n\\uD83D\\uDE00\\\\\\\"z","界"],"flag":false,"null":null,"number":-1.23e-4}}\n'
for size = 1, #raw do
    -- UTF-8 bytes are kept together by the Go transport.
    local parser = JsonFrame.new(decode)
    local value
    local index = 1
    while index <= #raw do
        local last = math.min(#raw, index + size - 1)
        while last < #raw and string.byte(raw, last + 1) >= 128 and string.byte(raw, last + 1) < 192 do last += 1 end
        local err
        value, err = parser:feed(string.sub(raw, index, last), last == #raw)
        assert(not err, tostring(size) .. ": " .. tostring(err))
        index = last + 1
    end
    assert(encode(value) == encode(decode(raw)), "incremental JSON changed escape/scalar semantics")
end
for _, invalid in { '{"x":}', '[1,]', '{"a":1,}', '"\\uD800"', 'true false', '{"a" 1}', '[01]', '["a" "b"]' } do
    assert(select(2, JsonFrame.new(decode):feed(invalid, true)), "accepted invalid JSON: " .. invalid)
end
local dense = '{"v":2,"type":"snapshot","state":{"items":[' .. string.rep('0,', 100000) .. '0]}}\n'
local parser = JsonFrame.new(decode)
for offset = 1, #dense, 4 * 1024 do
    local final = offset + 4 * 1024 > #dense
    withBudget(function()
        local value, err = parser:feed(string.sub(dense, offset, offset + 4 * 1024 - 1), final)
        assert(not err, err)
        if final then assert(#value.state.items == 100001) end
    end, 25)
end
local state = {}
local host = { json = { decode = decode }, state = {
    get = function(key) return state[key] and decode(state[key]) end,
    set = function(key, value) state[key] = encode(value) end,
} }
local writer = Store.writer(host)
local output, active
local reader = Store.reader(host, function(value) output = value end, function(value) active = value end)
local function publish(frame, text)
    local parts = { '{"v":2,"type":"snapshot","state":', encode({ text = text }) .. '}' }
    for index, data in parts do writer.push({ frame = frame, index = index, count = 2, data = data }, "generation") end
    writer.commit(frame, frame)
end
publish(1, "old")
reader.select(host.state.get("snapshot"))
reader.step()
publish(2, "middle")
publish(3, "new")
while active do reader.step() end
assert(output.state.text == "new", "reader combined overwritten snapshot banks")
reader.select(host.state.get("snapshot"))
assert(not active, "completed reader keeps requesting frame ticks")
local keys = 0
for _ in state do keys += 1 end
assert(keys == 5, "snapshot generations leaked state keys")
print("Noctalia incremental JSON and snapshot bank checks passed")
