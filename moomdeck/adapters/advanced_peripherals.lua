local base = require("adapters/base")

local advanced = {}

function advanced.matches(types)
    return types.energy_detector or types.energyDetector
        or types.inventory_manager
        or types.redstone_integrator
        or types.me_bridge
        or types.rs_bridge
end

function advanced.probe(name, peripheral, types)
    types = types or base.type_set(name)
    local streams = {}

    if types.energy_detector or types.energyDetector then
        streams[#streams + 1] = {
            key = "energy:transfer",
            category = "energy",
            resource = "fe_transfer",
            label = "FE Transfer",
            role = "flow",
            current = 0,
            flow_in = 0,
            flow_out = 0,
        }
    end

    if types.inventory_manager then
        local ok, items = base.safe_call(peripheral, "getItems")
        if ok and type(items) == "table" then
            local grouped = {}
            for _, item in pairs(items) do
                if item and item.name then
                    grouped[item.name] = (grouped[item.name] or 0) + (item.count or 0)
                end
            end
            for item_name, count in pairs(grouped) do
                streams[#streams + 1] = {
                    key = "player_item:" .. item_name,
                    category = "item",
                    resource = item_name,
                    label = item_name .. " (player)",
                    role = "storage",
                    current = count,
                }
            end
        end
    end

    return streams
end

function advanced.read_stream(peripheral, stream, types)
    types = types or {}

    if stream.key == "energy:transfer" then
        local ok, rate = base.safe_call(peripheral, "getTransferRate")
        local flow = ok and (rate or 0) or 0
        return {
            current = flow,
            flow_in = flow,
            flow_out = 0,
        }
    end

    if stream.key:match("^player_item:") then
        local total = 0
        local ok, items = base.safe_call(peripheral, "getItems")
        if ok and type(items) == "table" then
            for _, item in pairs(items) do
                if item and item.name == stream.resource then
                    total = total + (item.count or 0)
                end
            end
        end
        return { current = total }
    end

    return { current = 0 }
end

return advanced
