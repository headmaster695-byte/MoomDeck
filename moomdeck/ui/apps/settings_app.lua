local theme = require("ui/theme")
local components = require("ui/components")
local config = require("config")
local peripheral_manager = require("services/peripheral_manager")

local settings_app = {
    id = "settings",
    title = "Settings",
}

function settings_app.mount(parent, bounds)
    local win = window.create(parent, bounds.x, bounds.y, bounds.w, bounds.h, true)

    local function draw()
        local w, h = win.getSize()
        components.fill(win, " ", theme.bg)
        components.draw_header(win, "Settings", "MoomDeck v" .. config.version)

        components.text(win, 2, 4, "Poll interval: " .. tostring(config.poll_interval) .. "s", theme.text, theme.bg)
        components.text(win, 2, 5, "Sample window: " .. tostring(config.sample_window) .. "s", theme.text, theme.bg)
        components.text(win, 2, 6, "Data file: " .. config.data_file, theme.text_dim, theme.bg)

        components.text(win, 2, 8, "Categories", theme.title, theme.bg)
        local y = 9
        for id, cat in pairs(config.categories) do
            components.text(win, 2, y, cat.label .. " (" .. id .. ") unit:" .. cat.unit, cat.color, theme.bg)
            y = y + 1
        end

        components.text(win, 2, h - 2, "[R] rescan peripherals   [Q] quit MoomDeck", theme.text_dim, theme.bg)
    end

    draw()

    return {
        window = win,
        redraw = draw,
        key = function(key)
            if key == keys.r then
                peripheral_manager.scan()
                return true
            end
            return false
        end,
    }
end

return settings_app
