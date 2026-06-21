local config = require("config")
local util = require("core/util")
local theme = require("ui/theme")
local components = require("ui/components")
local display = require("ui/display")
local peripheral_manager = require("services/peripheral_manager")
local storage = require("core/storage")

local dashboard = {
    id = "dashboard",
    title = "Dashboard",
}

function dashboard.mount(parent, bounds)
    local win = window.create(parent, bounds.x, bounds.y, bounds.w, bounds.h, true)
    local scroll = 0
    local selected = 1
    local mode = "factories"

    local function content_height()
        if mode == "factories" then
            return #peripheral_manager.get_factory_views() * 5
        elseif mode == "machines" then
            return #peripheral_manager.get_machine_views() * 5
        end
        return #peripheral_manager.get_all_stream_views() * 4
    end

    local function draw()
        local w, h = win.getSize()
        components.fill(win, " ", theme.bg)
        components.draw_header(win, "MoomDeck Dashboard", "Factory / machine resource overview")

        local tabs = {
            components.button(win, 2, 3, 12, "Factories", mode == "factories"),
            components.button(win, 15, 3, 12, "Machines", mode == "machines"),
            components.button(win, 28, 3, 12, "All Streams", mode == "streams"),
        }

        local body_y = 5
        local body_h = h - body_y
        local y = body_y - scroll

        if mode == "factories" then
            local factories = peripheral_manager.get_factory_views()
            if #factories == 0 then
                components.text(win, 2, body_y, "No factories yet. Use Organize app.", theme.text_dim, theme.bg)
            end
            for i, factory in ipairs(factories) do
                if y >= body_y - 1 and y < body_y + body_h then
                    components.text(win, 2, y, factory.name, theme.title, theme.bg)
                    components.text(win, 2, y + 1, string.format(
                        " Machines:%d  Net:%s/s",
                        #factory.machines,
                        util.format_number(factory.totals.net)
                    ), theme.text, theme.bg)
                end
                y = y + 5
            end
        elseif mode == "machines" then
            for _, machine in ipairs(peripheral_manager.get_machine_views()) do
                if y >= body_y - 1 and y < body_y + body_h then
                    components.text(win, 2, y, machine.name, theme.accent, theme.bg)
                    components.text(win, 2, y + 1, string.format(
                        " Streams:%d  In:%s/s  Out:%s/s",
                        #machine.streams,
                        util.format_number(machine.totals.inflow),
                        util.format_number(machine.totals.outflow)
                    ), theme.text, theme.bg)
                end
                y = y + 5
            end
        else
            local idx = 0
            for _, stream in ipairs(peripheral_manager.get_all_stream_views()) do
                idx = idx + 1
                if y >= body_y - 1 and y < body_y + body_h - 3 then
                    components.draw_stream_row(win, y, w, stream, idx == selected)
                end
                y = y + 4
            end
        end

        return tabs
    end

  local tabs = draw()

    return {
        window = win,
        redraw = function()
            tabs = draw()
        end,
        click = function(x, y)
            for _, tab in ipairs(tabs) do
                if components.hit(tab, x, y) then
                    if tab.label == "Factories" then mode = "factories"
                    elseif tab.label == "Machines" then mode = "machines"
                    else mode = "streams" end
                    scroll = 0
                    return true
                end
            end
            return false
        end,
        scroll = function(dir)
            local max_scroll = math.max(0, content_height() - (bounds.h - 5))
            scroll = util.clamp(scroll + dir, 0, max_scroll)
            return true
        end,
    }
end

return dashboard
