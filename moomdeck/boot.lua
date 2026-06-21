local config = require("config")
local storage = require("core/storage")
local events = require("core/events")
local scheduler = require("core/scheduler")
local secure_boot = require("core/secure_boot")
local display = require("ui/display")
local desktop = require("ui/desktop")
local peripheral_manager = require("services/peripheral_manager")

local MoomDeck = {}

local running = false

local function save_loop()
    storage.save()
end

function MoomDeck.push(payload)
    return peripheral_manager.register_push(payload)
end

function MoomDeck.start()
    if running then
        return
    end
    running = true

    math.randomseed(os.epoch("utc"))

    secure_boot.authenticate(term)

    storage.set_path(config.data_file)
    storage.load()

    display.init()
    display.set_title("MoomDeck")

    local modem = peripheral.find("modem")
    if modem then
        rednet.open(peripheral.getName(modem))
    end

    peripheral_manager.scan()
    peripheral_manager.poll()

    desktop.mount()
    desktop.redraw()

    events.on("streams_polled", desktop.on_streams_changed)
    events.on("streams_changed", desktop.on_streams_changed)
    events.on("taxonomy_changed", desktop.on_streams_changed)
    events.on("peripherals_scanned", desktop.on_streams_changed)

    scheduler.every(config.poll_interval, function()
        peripheral_manager.poll()
    end, "poll")

    scheduler.every(5, save_loop, "save")
    scheduler.every(config.ui_refresh, function()
        desktop.redraw()
    end, "ui")

    while running do
        scheduler.tick()
        local event, p1, p2, p3, p4 = os.pullEvent()

        if event == "rednet_message" then
            local sender, message = p1, p2
            if type(message) == "table" and message.type == "moomdeck_push" then
                peripheral_manager.register_push(message)
            end
        else
            local ok, action = desktop.handle_event(event, p1, p2, p3, p4)
            if ok == false and action == "quit" then
                running = false
            end
        end
    end

    save_loop()
end

return MoomDeck
