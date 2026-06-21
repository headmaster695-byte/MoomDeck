local config = require("config")
local theme = require("ui/theme")
local components = require("ui/components")
local display = require("ui/display")
local events = require("core/events")
local apps = require("apps")

local desktop = {
    active_app = 1,
    mounted = nil,
    taskbar_buttons = {},
}

local function content_bounds()
    local w, h = display.get_size()
    return { x = 1, y = 2, w = w, h = h - 2 }
end

function desktop.mount()
    desktop.mounted = apps[desktop.active_app].mount(display.term, content_bounds())
end

function desktop.redraw()
    local w, h = display.get_size()
    display.term.setBackgroundColor(theme.panel)
    display.term.setTextColor(theme.title)
    display.term.setCursorPos(2, 1)
    display.term.write(components.truncate(" MoomDeck OS v" .. config.version .. " ", w - 2))

    desktop.taskbar_buttons = {}
    local x = 2
    for i, app in ipairs(apps) do
        desktop.taskbar_buttons[#desktop.taskbar_buttons + 1] =
            components.button(display.term, x, h, 14, app.title, i == desktop.active_app)
        x = x + 15
    end

    if desktop.mounted and desktop.mounted.redraw then
        desktop.mounted.redraw()
    end
end

function desktop.switch_app(index)
    if not apps[index] then return end
    desktop.active_app = index
    desktop.mount()
    desktop.redraw()
end

function desktop.handle_event(event, ...)
    local w, h = display.get_size()

    if event == "mouse_click" or event == "mouse_up" then
        local button, x, y = ...
        if y == h then
            for i, btn in ipairs(desktop.taskbar_buttons) do
                if components.hit(btn, x, y) then
                    desktop.switch_app(i)
                    return true
                end
            end
        end

        if desktop.mounted and desktop.mounted.click then
            if desktop.mounted.click(x, y, x, y) then
                desktop.redraw()
                return true
            end
        end
    elseif event == "mouse_scroll" then
        local direction, x, y = ...
        if desktop.mounted and desktop.mounted.scroll then
            desktop.mounted.scroll(direction)
            desktop.redraw()
            return true
        end
    elseif event == "key" then
        local key = ...
        if key == keys.q and desktop.active_app == 4 then
            return false, "quit"
        end
        if desktop.mounted and desktop.mounted.key then
            if desktop.mounted.key(key, desktop) then
                desktop.redraw()
                return true
            end
        end
    elseif event == "char" then
        -- reserved for prompts
    elseif event == "peripheral" or event == "monitor_touch" then
        desktop.redraw()
        return true
    end

    return true
end

function desktop.on_streams_changed()
    desktop.redraw()
end

return desktop
