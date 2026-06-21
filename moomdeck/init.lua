-- MoomDeck module loader for CC:Tweaked
local ROOT = "moomdeck"
local cache = {}

local function resolve(path)
    if path:sub(1, #ROOT + 1) == ROOT .. "/" then
        return path
    end
    return ROOT .. "/" .. path
end

local function require(path)
    local full = resolve(path)
    if cache[full] then
        return cache[full]
    end

    local env = setmetatable({
        require = require,
        package = { loaded = cache },
    }, { __index = _G })

    local chunk, err = loadfile(full .. ".lua", "t", env)
    if not chunk then
        error("MoomDeck: failed to load " .. full .. ": " .. tostring(err), 2)
    end

    local ok, result = pcall(chunk)
    if not ok then
        error("MoomDeck: error running " .. full .. ": " .. tostring(result), 2)
    end

    if result == nil then
        result = env
    end

    cache[full] = result
    return result
end

return {
    require = require,
    ROOT = ROOT,
}
