local base = require("adapters/base")
local util = require("core/util")

local ccbridge = {}

function ccbridge.matches(types)
    return types.create_target or types.create_source
end

local stress_keys = {
    stress = true,
    su = true,
    stress_units = true,
    current_stress = true,
}

local rpm_keys = {
    rpm = true,
    speed = true,
    rotation = true,
}

function ccbridge.probe(name, peripheral, types)
    types = types or base.type_set(name)
    if not types.create_target then
        return {}
    end

    local streams = {}
    local readings = base.parse_target_lines(peripheral)

    for key, reading in pairs(readings) do
        if stress_keys[key] and reading.number then
            streams[#streams + 1] = {
                key = "stress:" .. key,
                category = "stress",
                resource = "stress",
                label = reading.key,
                role = "flow",
                current = reading.number,
                flow_in = reading.number,
                flow_out = 0,
            }
        elseif rpm_keys[key] and reading.number then
            streams[#streams + 1] = {
                key = "rpm:" .. key,
                category = "stress",
                resource = "rpm",
                label = reading.key,
                role = "flow",
                current = reading.number,
                flow_in = reading.number,
                flow_out = 0,
            }
        elseif reading.number then
            local category = "item"
            local lowered = string.lower(reading.key)
            if lowered:find("fluid") or lowered:find("mb") or lowered:find("millibucket") then
                category = "fluid"
            elseif lowered:find("fe") or lowered:find("energy") then
                category = "energy"
            elseif lowered:find("stress") or lowered:find("su") then
                category = "stress"
            end

            streams[#streams + 1] = {
                key = "target:" .. key,
                category = category,
                resource = util.slug(reading.key),
                label = reading.key,
                role = "storage",
                current = reading.number,
                raw = reading.raw,
            }
        end
    end

    return streams
end

function ccbridge.read_stream(peripheral, stream)
    local readings = base.parse_target_lines(peripheral)
    local key = stream.key:match("^target:(.+)$") or stream.resource
    local reading = readings[key]
    if reading and reading.number then
        return {
            current = reading.number,
            flow_in = stream.role == "flow" and reading.number or nil,
            flow_out = 0,
            raw = reading.raw,
        }
    end
    return { current = stream.current or 0 }
end

return ccbridge
