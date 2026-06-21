local util = require("core/util")
local theme = require("ui/theme")
local components = require("ui/components")
local display = require("ui/display")
local peripheral_manager = require("services/peripheral_manager")

local peripherals_app = {
    id = "peripherals",
    title = "Peripherals",
}

function peripherals_app.mount(parent, bounds)
    local win = window.create(parent, bounds.x, bounds.y, bounds.w, bounds.h, true)
    local selected_peripheral = 1
    local selected_stream = 1
    local scroll = 0

    local function draw()
        local w, h = win.getSize()
        components.fill(win, " ", theme.bg)
        components.draw_header(win, "Peripheral Streams", "Live readings under each connected device")

        local views = peripheral_manager.get_peripheral_views()
        local left_w = math.max(16, math.floor(w * 0.28))

        -- Peripheral list
        components.text(win, 2, 3, "Devices", theme.title, theme.bg)
        local y = 4
        for i, view in ipairs(views) do
            local label = view.name .. " (" .. #view.streams .. ")"
            components.button(win, 2, y, left_w - 2, label, i == selected_peripheral)
            y = y + 1
        end

        if #views == 0 then
            components.text(win, 2, 5, "No peripherals found.", theme.text_dim, theme.bg)
            components.text(win, 2, 6, "Attach wired modems and run Scan.", theme.text_dim, theme.bg)
            return {}
        end

        local current = views[selected_peripheral]
        local detail_x = left_w + 1
        local detail_w = w - left_w - 1

        components.text(win, detail_x, 3, current.name, theme.accent, theme.bg)
        components.text(win, detail_x, 4, "Type: " .. tostring(current.type or "?"), theme.text_dim, theme.bg)

        local body_y = 6 - scroll
        local buttons = {}
        for i, stream in ipairs(current.streams) do
            if body_y >= 6 and body_y < h - 1 then
                components.draw_stream_row(win, body_y, detail_w, stream, i == selected_stream)
                buttons[#buttons + 1] = { x = detail_x, y = body_y, w = detail_w, h = 4, index = i }
            end
            body_y = body_y + 4
        end

        if selected_stream <= #current.streams then
            local stream = current.streams[selected_stream]
            local info_y = h - 1
            local lock = stream.lock_inflow and "ON" or "OFF"
            components.text(win, detail_x, info_y, components.truncate(
                string.format("L lock  S max cap  in:%s/s min:%s hr:%s",
                    util.format_number(stream.rates.inflow),
                    util.format_number(stream.rates.per_minute),
                    util.format_number(stream.rates.per_hour)
                ), detail_w - 1
            ), theme.text_dim, theme.bg)
        end

        return buttons
    end

    local buttons = draw()

    return {
        window = win,
        redraw = function()
            buttons = draw()
        end,
        click = function(x, y, win_x, win_y)
            local w = select(1, win.getSize())
            local left_w = math.max(16, math.floor(w * 0.28))
            local views = peripheral_manager.get_peripheral_views()

            if x >= 2 and x < left_w and y >= 4 then
                local idx = y - 3
                if views[idx] then
                    selected_peripheral = idx
                    selected_stream = 1
                    scroll = 0
                    return true
                end
            end

            for _, btn in ipairs(buttons) do
                if x >= btn.x and x < btn.x + btn.w and y >= btn.y and y < btn.y + btn.h then
                    selected_stream = btn.index
                    return true
                end
            end

            return false
        end,
        key = function(key)
            local views = peripheral_manager.get_peripheral_views()
            local current = views[selected_peripheral]
            if not current then return false end
            local stream = current.streams[selected_stream]
            if not stream then return false end

            if key == keys.l then
                peripheral_manager.toggle_lock_inflow(stream.id)
                return true
            elseif key == keys.s then
                local value = components.prompt(display.term, "Max storage (blank=none):", tostring(stream.max_storage or ""))
                if value ~= nil then
                    local max_storage = tonumber(value)
                    peripheral_manager.set_stream_meta(stream.id, {
                        max_storage = max_storage,
                    })
                end
                return true
            end
            return false
        end,
        scroll = function(dir)
            scroll = math.max(0, scroll - dir)
            return true
        end,
    }
end

return peripherals_app
