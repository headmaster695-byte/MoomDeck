-- MoomDeck installer for CC:Tweaked
-- Run once on a fresh computer: wget run https://raw.githubusercontent.com/headmaster695-byte/MoomDeck/main/install.lua

local BASE = "https://raw.githubusercontent.com/headmaster695-byte/MoomDeck/main/"

local files = {
    "startup.lua",
    "moomdeck/init.lua",
    "moomdeck/config.lua",
    "moomdeck/boot.lua",
    "moomdeck/apps.lua",
    "moomdeck/core/util.lua",
    "moomdeck/core/storage.lua",
    "moomdeck/core/events.lua",
    "moomdeck/core/scheduler.lua",
    "moomdeck/core/secure_boot.lua",
    "moomdeck/services/rate_engine.lua",
    "moomdeck/services/peripheral_manager.lua",
    "moomdeck/adapters/base.lua",
    "moomdeck/adapters/generic.lua",
    "moomdeck/adapters/ccbridge.lua",
    "moomdeck/adapters/advanced_peripherals.lua",
    "moomdeck/adapters/create.lua",
    "moomdeck/ui/theme.lua",
    "moomdeck/ui/components.lua",
    "moomdeck/ui/display.lua",
    "moomdeck/ui/desktop.lua",
    "moomdeck/ui/apps/dashboard.lua",
    "moomdeck/ui/apps/peripherals_app.lua",
    "moomdeck/ui/apps/organize_app.lua",
    "moomdeck/ui/apps/settings_app.lua",
    "examples/peripheral_push.lua",
}

local function ensure_dir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

local function download(url, path)
    if not http or not http.get then
        return false, "HTTP API is not available"
    end

    local response = http.get(url)
    if not response then
        return false, "request failed"
    end

    local content = response.readAll()
    response.close()

    local handle = fs.open(path, "w")
    if not handle then
        return false, "could not write file"
    end

    handle.write(content)
    handle.close()
    return true
end

print("MoomDeck installer")
print("Downloading from " .. BASE)
print("")

if not http or not http.get then
    print("ERROR: HTTP is not enabled on this computer.")
    print("Ask your server admin to enable http_enabled in CC:Tweaked config.")
    return
end

local ok_count = 0
local fail_count = 0

for _, path in ipairs(files) do
    local dir = path:match("(.+)/[^/]+$")
    if dir then
        local built = ""
        for part in string.gmatch(dir, "[^/]+") do
            built = built == "" and part or (built .. "/" .. part)
            ensure_dir(built)
        end
    end

    local url = BASE .. path
    term.write("Fetching " .. path .. " ... ")

    local ok, err = download(url, path)
    if ok then
        print("OK")
        ok_count = ok_count + 1
    else
        print("FAILED (" .. tostring(err) .. ")")
        fail_count = fail_count + 1
    end
end

print("")
print(string.format("Done: %d succeeded, %d failed", ok_count, fail_count))

if fail_count == 0 then
    print("Reboot the computer to start MoomDeck.")
else
    print("Some files failed. Check that http/https is enabled in CC:Tweaked config.")
end
