local base = require("adapters/base")

local create_adapter = {}

function create_adapter.matches(types)
    return types.create_stressometer or types.stressometer
end

function create_adapter.probe(name, peripheral)
    local streams = {}
    local stress, cap = base.read_stress(peripheral)
    if stress ~= nil then
        streams[#streams + 1] = {
            key = "stress:network",
            category = "stress",
            resource = "stress",
            label = "Network Stress",
            role = "storage",
            current = stress,
            max_storage = cap,
        }
    end
    return streams
end

function create_adapter.read_stream(peripheral, stream)
    if stream.key == "stress:network" then
        local stress, cap = base.read_stress(peripheral)
        return {
            current = stress or 0,
            max_storage = cap,
        }
    end
    return { current = 0 }
end

return create_adapter
