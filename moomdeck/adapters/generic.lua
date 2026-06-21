local base = require("adapters/base")
local util = require("core/util")

local generic = {}

function generic.matches(types)
    return types.inventory or types.fluid_storage or types.energy_storage
end

function generic.probe(name, peripheral)
    local types = base.type_set(name)
    local streams = {}

    if types.inventory then
        local ok, items = base.safe_call(peripheral, "list")
        if ok and type(items) == "table" then
            local grouped = {}
            for _, item in pairs(items) do
                if item and item.name then
                    grouped[item.name] = (grouped[item.name] or 0) + (item.count or 0)
                end
            end
            for item_name, count in pairs(grouped) do
                streams[#streams + 1] = {
                    key = "item:" .. item_name,
                    category = "item",
                    resource = item_name,
                    label = item_name,
                    role = "storage",
                    current = count,
                    max_storage = nil,
                }
            end
        end
    end

    if types.fluid_storage then
        local ok, tanks = base.safe_call(peripheral, "tanks")
        if ok and type(tanks) == "table" then
            for i, tank in ipairs(tanks) do
                if tank and tank.name then
                    streams[#streams + 1] = {
                        key = "fluid:" .. tank.name .. ":" .. i,
                        category = "fluid",
                        resource = tank.name,
                        label = tank.name,
                        role = "storage",
                        current = tank.amount or 0,
                        max_storage = tank.capacity,
                    }
                end
            end
        end
    end

    if types.energy_storage then
        local energy, cap = base.read_energy(peripheral)
        if energy ~= nil then
            streams[#streams + 1] = {
                key = "energy:stored",
                category = "energy",
                resource = "forge_energy",
                label = "Stored FE",
                role = "storage",
                current = energy,
                max_storage = cap,
            }
        end
    end

    return streams
end

function generic.read_stream(peripheral, stream)
    if stream.category == "item" then
        local total = base.sum_inventory(peripheral, stream.resource)
        return { current = total or 0 }
    elseif stream.category == "fluid" then
        local total, label = base.sum_fluids(peripheral, stream.resource)
        return { current = total or 0, label = label }
    elseif stream.category == "energy" then
        local energy, cap = base.read_energy(peripheral)
        return { current = energy or 0, max_storage = cap }
    end
    return { current = 0 }
end

return generic
