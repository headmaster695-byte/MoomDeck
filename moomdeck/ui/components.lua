local theme = require("ui/theme")
local util = require("core/util")

local components = {}

function components.fill(win, ch, bg, fg)
    local w, h = win.getSize()
    win.setBackgroundColor(bg or theme.bg)
    for y = 1, h do
        win.setCursorPos(1, y)
        win.write(string.rep(ch or " ", w))
    end
end

function components.text(win, x, y, text, fg, bg)
    win.setCursorPos(x, y)
    if bg then win.setBackgroundColor(bg) end
    if fg then win.setTextColor(fg) end
    win.write(text)
end

function components.truncate(text, width)
    text = tostring(text or "")
    if #text <= width then
        return text
    end
    if width <= 3 then
        return string.sub(text, 1, width)
    end
    return string.sub(text, 1, width - 3) .. "..."
end

function components.button(win, x, y, width, label, selected)
    local bg = selected and theme.accent or theme.panel_alt
    local fg = selected and theme.text_dark or theme.text
    win.setBackgroundColor(bg)
    win.setTextColor(fg)
    win.setCursorPos(x, y)
    win.write(" " .. components.truncate(label, width - 2) .. string.rep(" ", math.max(0, width - #label - 2)))
    return { x = x, y = y, w = width, h = 1, label = label }
end

function components.hit(button, x, y)
    return x >= button.x and x < button.x + button.w and y == button.y
end

function components.draw_header(win, title, subtitle)
    local w = select(1, win.getSize())
    win.setBackgroundColor(theme.panel)
    win.setTextColor(theme.title)
    win.setCursorPos(2, 1)
    win.write(components.truncate(title, w - 4))
    if subtitle then
        win.setTextColor(theme.text_dim)
        win.setCursorPos(2, 2)
        win.write(components.truncate(subtitle, w - 4))
    end
end

function components.draw_stream_row(win, y, width, stream, selected)
    local bg = selected and theme.accent_alt or theme.bg
    local fg = selected and theme.text or theme.text
    win.setBackgroundColor(bg)
    win.setTextColor(theme.category[stream.category] or theme.text)
    win.setCursorPos(1, y)
    win.write(components.truncate(" " .. (stream.label or stream.id), width))

    win.setTextColor(fg)
    win.setCursorPos(1, y + 1)
    win.write(components.truncate(
        string.format(" %s  cur:%s", stream.category_label, util.format_number(stream.current)),
        width
    ))

    win.setCursorPos(1, y + 2)
    win.write(components.truncate(
        " in " .. util.format_number(stream.rates.inflow) .. "/s  out " .. util.format_number(stream.rates.outflow) .. "/s",
        width
    ))

    win.setCursorPos(1, y + 3)
    local fill = ""
    if stream.max_storage then
        fill = " cap:" .. util.format_number(stream.max_storage)
        if stream.rates.time_to_fill then
            fill = fill .. "  fill:" .. util.format_duration(stream.rates.time_to_fill)
        end
    end
    win.write(components.truncate(
        " net " .. util.format_number(stream.rates.net) .. "/s" .. fill,
        width
    ))

    if stream.lock_inflow then
        win.setTextColor(theme.warning)
        win.setCursorPos(width - 6, y)
        win.write(" LOCK ")
    end
end

function components.prompt(term_obj, prompt, default)
    local w, h = term_obj.getSize()
    local box_w = math.min(w - 4, 40)
    local box_h = 5
    local box_x = math.floor((w - box_w) / 2) + 1
    local box_y = math.floor((h - box_h) / 2) + 1

    local win = window.create(term_obj, box_x, box_y, box_w, box_h, true)
    components.fill(win, " ", theme.panel)
    components.text(win, 2, 1, prompt, theme.title, theme.panel)
    win.setCursorPos(2, 3)
    win.setBackgroundColor(theme.panel_alt)
    win.setTextColor(theme.text)
    win.write(string.rep(" ", box_w - 4))

    local input = default or ""
    win.setCursorPos(2, 3)
    win.write(input)

    local function redraw()
        win.setCursorPos(2, 3)
        win.setBackgroundColor(theme.panel_alt)
        win.write(components.truncate(input .. "_", box_w - 4))
    end

    while true do
        redraw()
        local event, p1, p2, p3 = os.pullEvent()
        if event == "key" then
            if p1 == keys.enter then
                win.close()
                term_obj.setVisible(true)
                return input
            elseif p1 == keys.escape then
                win.close()
                term_obj.setVisible(true)
                return nil
            elseif p1 == keys.backspace then
                input = string.sub(input, 1, math.max(0, #input - 1))
            end
        elseif event == "char" then
            if #input < box_w - 4 then
                input = input .. p1
            end
        end
    end
end

return components
