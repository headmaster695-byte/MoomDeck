local util = {}

function util.deepcopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[util.deepcopy(k, seen)] = util.deepcopy(v, seen)
    end
    return copy
end

function util.clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function util.round(n, places)
    places = places or 0
    local mul = 10 ^ places
    if n >= 0 then
        return math.floor(n * mul + 0.5) / mul
    end
    return math.ceil(n * mul - 0.5) / mul
end

function util.format_number(n)
    if n == nil or n ~= n then
        return "?"
    end
    local abs = math.abs(n)
    if abs >= 1e9 then
        return util.round(n / 1e9, 2) .. "B"
    elseif abs >= 1e6 then
        return util.round(n / 1e6, 2) .. "M"
    elseif abs >= 1e3 then
        return util.round(n / 1e3, 2) .. "K"
    elseif abs >= 100 then
        return tostring(math.floor(n + 0.5))
    elseif abs >= 10 then
        return tostring(util.round(n, 1))
    end
    return tostring(util.round(n, 2))
end

function util.format_rate(per_second, unit)
    unit = unit or ""
    local suffix = unit ~= "" and (" " .. unit) or ""
    return string.format(
        "%s/s  %s/m  %s/h",
        util.format_number(per_second),
        util.format_number(per_second * 60),
        util.format_number(per_second * 3600)
    ) .. suffix
end

function util.format_duration(seconds)
    if seconds == nil or seconds ~= seconds or seconds == math.huge then
        return "never"
    end
    if seconds < 0 then
        return "full"
    end
    if seconds < 60 then
        return util.round(seconds, 1) .. "s"
    elseif seconds < 3600 then
        return util.round(seconds / 60, 1) .. "m"
    elseif seconds < 86400 then
        return util.round(seconds / 3600, 1) .. "h"
    end
    return util.round(seconds / 86400, 1) .. "d"
end

function util.split_lines(text)
    local lines = {}
    for line in string.gmatch(text or "", "[^\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

function util.parse_number(text)
    if type(text) == "number" then
        return text
    end
    if type(text) ~= "string" then
        return nil
    end
    local cleaned = text:gsub(",", ""):gsub("%s+", "")
    local num = tonumber(cleaned)
    if num then
        return num
    end
    local digits = cleaned:match("([%d%.]+)")
    return digits and tonumber(digits) or nil
end

function util.slug(text)
    text = string.lower(text or "unnamed")
    text = text:gsub("[^%w]+", "_")
    text = text:gsub("^_+", ""):gsub("_+$", "")
    if text == "" then
        return "unnamed"
    end
    return text
end

function util.uuid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return (template:gsub("[xy]", function(c)
        local v = (os.epoch("utc") + math.random(0, 0xffff)) % 16
        if c == "x" then
            return string.format("%x", v)
        end
        return string.format("%x", (v % 4) + 8)
    end))
end

function util.table_count(t)
    local n = 0
    for _ in pairs(t or {}) do
        n = n + 1
    end
    return n
end

function util.sorted_keys(t)
    local keys = {}
    for k in pairs(t or {}) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

function util.index_of(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i
        end
    end
    return nil
end

return util
