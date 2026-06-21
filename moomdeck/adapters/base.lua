local util = require("core/util")

local base = {}

function base.has_method(peripheral, name)
    return type(peripheral) == "table" and type(peripheral[name]) == "function"
end

function base.safe_call(peripheral, name, ...)
    if not base.has_method(peripheral, name) then
        return nil, "missing method"
    end
    return pcall(peripheral[name], peripheral, ...)
end

function base.get_types(name)
    local ok, types = pcall(peripheral.getType, name)
    if ok and type(types) == "table" then
        return types
    end
    return {}
end

function base.type_set(name)
    local set = {}
    for _, ty in ipairs(base.get_types(name)) do
        set[ty] = true
    end
    return set
end

function base.first_type(name)
    local types = base.get_types(name)
    return types[1]
end

function base.sum_inventory(peripheral, filter_name)
    local ok, items = base.safe_call(peripheral, "list")
    if not ok or type(items) ~= "table" then
        return nil
    end

    local total = 0
    local label = filter_name
    for _, item in pairs(items) do
        if item and item.name then
            if not filter_name or item.name == filter_name then
                total = total + (item.count or 0)
                label = item.name
            end
        end
    end

    return total, label
end

function base.sum_fluids(peripheral, filter_name)
    local ok, tanks = base.safe_call(peripheral, "tanks")
    if not ok or type(tanks) ~= "table" then
        return nil
    end

    local total = 0
    local label = filter_name
    for _, tank in pairs(tanks) do
        if tank and tank.name then
            if not filter_name or tank.name == filter_name then
                total = total + (tank.amount or 0)
                label = tank.name
            end
        end
    end

    return total, label
end

function base.read_energy(peripheral)
    local ok, energy = base.safe_call(peripheral, "getEnergy")
    if not ok then
        return nil
    end
    local ok2, cap = base.safe_call(peripheral, "getEnergyCapacity")
    return energy or 0, cap
end

function base.read_stress(peripheral)
    local ok, stress = base.safe_call(peripheral, "getStress")
    if not ok then
        return nil
    end
    local ok2, cap = base.safe_call(peripheral, "getStressCapacity")
    return stress or 0, cap
end

function base.parse_target_lines(peripheral)
    local readings = {}
    local ok, height = base.safe_call(peripheral, "getSize")
    if not ok or not height then
        return readings
    end

    for y = 1, height do
        local ok_line, line = base.safe_call(peripheral, "getLine", y)
        if ok_line and type(line) == "string" and line ~= "" then
            local key, value = line:match("^%s*([^:]+):%s*(.+)%s*$")
            if key and value then
                readings[util.slug(key)] = {
                    raw = line,
                    key = key,
                    value = value,
                    number = util.parse_number(value),
                }
            else
                readings["line_" .. y] = {
                    raw = line,
                    key = "line_" .. y,
                    value = line,
                    number = util.parse_number(line),
                }
            end
        end
    end

    return readings
end

return base
