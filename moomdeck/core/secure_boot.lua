local config = require("config")
local theme = require("ui/theme")
local components = require("ui/components")

local secure_boot = {}

local SALT = "moomdeck_boot_v1"
local EXPECTED_HASH = "1397839541"
local MAX_ATTEMPTS = 5
local LOCKOUT_SECONDS = 30

local function hash_password(password)
    local h = 5381
    for i = 1, #password do
        h = (h * 33 + string.byte(password, i)) % 2147483647
    end
    for i = 1, #SALT do
        h = (h * 33 + string.byte(SALT, i)) % 2147483647
    end
    return tostring(h)
end

local function mask_password(password)
    return string.rep("*", #password)
end

local function draw_screen(term_obj, title, subtitle, field, message, message_color)
    local w, h = term_obj.getSize()
    term_obj.setBackgroundColor(theme.bg)
    term_obj.setTextColor(theme.text)
    term_obj.clear()

    local box_w = math.min(w - 4, 36)
    local box_h = 9
    local box_x = math.floor((w - box_w) / 2) + 1
    local box_y = math.floor((h - box_h) / 2) + 1

    for y = box_y, box_y + box_h - 1 do
        term_obj.setCursorPos(box_x, y)
        term_obj.setBackgroundColor(theme.panel)
        term_obj.write(string.rep(" ", box_w))
    end

    components.text(term_obj, box_x + 2, box_y + 1, title, theme.title, theme.panel)
    if subtitle then
        components.text(term_obj, box_x + 2, box_y + 2, subtitle, theme.text_dim, theme.panel)
    end

    components.text(term_obj, box_x + 2, box_y + 4, "Password:", theme.text, theme.panel)
    term_obj.setCursorPos(box_x + 2, box_y + 5)
    term_obj.setBackgroundColor(theme.panel_alt)
    term_obj.setTextColor(theme.text)
    term_obj.write(components.truncate(mask_password(field) .. "_", box_w - 4))

    if message and message ~= "" then
        components.text(term_obj, box_x + 2, box_y + 7, components.truncate(message, box_w - 4), message_color or theme.danger, theme.panel)
    end
end

local function wait_lockout(term_obj, seconds)
    local end_at = os.clock() + seconds
    while os.clock() < end_at do
        local remaining = math.ceil(end_at - os.clock())
        draw_screen(
            term_obj,
            "MoomDeck Secure Boot",
            "Too many failed attempts",
            "",
            "Locked for " .. remaining .. "s",
            theme.warning
        )
        sleep(1)
    end
end

function secure_boot.authenticate(term_obj)
    if config.secure_boot_enabled == false then
        return true
    end

    term_obj = term_obj or term
    term_obj.setCursorBlink(true)

    local password = ""
    local attempts = 0
    local message = "Enter password to continue"
    local message_color = theme.text_dim

    while true do
        draw_screen(term_obj, "MoomDeck Secure Boot", "Authorized access only", password, message, message_color)

        local event, p1, p2, p3 = os.pullEvent()
        if event == "char" then
            if #password < 32 then
                password = password .. p1
                message = ""
            end
        elseif event == "key" then
            if p1 == keys.enter then
                if hash_password(password) == EXPECTED_HASH then
                    term_obj.setBackgroundColor(theme.bg)
                    term_obj.setTextColor(theme.success)
                    term_obj.clear()
                    components.text(term_obj, 2, 2, "Authentication successful.", theme.success, theme.bg)
                    components.text(term_obj, 2, 3, "Starting MoomDeck...", theme.text_dim, theme.bg)
                    sleep(0.6)
                    term_obj.clear()
                    return true
                end

                attempts = attempts + 1
                password = ""

                if attempts >= MAX_ATTEMPTS then
                    wait_lockout(term_obj, LOCKOUT_SECONDS)
                    attempts = 0
                    message = "Enter password to continue"
                    message_color = theme.text_dim
                else
                    local remaining = MAX_ATTEMPTS - attempts
                    message = "Access denied. " .. remaining .. " attempt" .. (remaining == 1 and "" or "s") .. " left."
                    message_color = theme.danger
                end
            elseif p1 == keys.backspace then
                password = string.sub(password, 1, math.max(0, #password - 1))
                message = ""
            end
        elseif event == "term_resize" then
            -- redraw on next loop
        end
    end
end

return secure_boot
