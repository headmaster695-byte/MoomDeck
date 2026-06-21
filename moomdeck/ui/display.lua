local config = require("config")
local theme = require("ui/theme")

local display = {
    monitor = nil,
    term = term,
    width = 51,
    height = 19,
}

function display.init()
    local monitors = { peripheral.find("monitor") }
    if #monitors > 0 and monitors[1] then
        display.monitor = monitors[1]
        display.term = display.monitor
        display.monitor.setTextScale(0.5)
    else
        display.term = term
    end

    display.width, display.height = display.term.getSize()
    display.term.setBackgroundColor(theme.bg)
    display.term.setTextColor(theme.text)
    display.term.clear()
    return display
end

function display.is_monitor()
    return display.monitor ~= nil
end

function display.get_size()
    if display.term and display.term.getSize then
        return display.term.getSize()
    end
    return display.width, display.height
end

function display.set_title(text)
    if display.is_monitor() then
        display.term.setLabel(text)
    end
end

function display.create_window(x, y, w, h, visible)
    return window.create(display.term, x, y, w, h, visible ~= false)
end

function display.blit_centered(y, text, fg, bg)
    local w = select(1, display.get_size())
    local x = math.max(1, math.floor((w - #text) / 2) + 1)
    display.term.setCursorPos(x, y)
    if bg then display.term.setBackgroundColor(bg) end
    if fg then display.term.setTextColor(fg) end
    display.term.write(text)
end

return display
