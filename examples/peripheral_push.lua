-- Example peripheral-side script for pushing custom readings to MoomDeck.
-- Run this on a computer next to your monitored block, with a modem on the network.

local modem = peripheral.find("modem") or error("Attach a wireless/wired modem")
rednet.open(peripheral.getName(modem))

local MAIN_ID = 1 -- Set this to your MoomDeck computer's rednet ID

local function push(payload)
    rednet.send(MAIN_ID, {
        type = "moomdeck_push",
        peripheral = os.getComputerLabel() or "remote_scanner",
        key = payload.key,
        category = payload.category,
        resource = payload.resource,
        label = payload.label,
        current = payload.current,
        max_storage = payload.max_storage,
        flow_in = payload.flow_in,
        flow_out = payload.flow_out,
        role = payload.role or "storage",
    })
end

-- Example: cobblestone generator chest scan
while true do
    local chest = peripheral.wrap("top") -- change side as needed
    if chest and chest.list then
        local total = 0
        for _, item in pairs(chest.list()) do
            if item.name == "minecraft:cobblestone" then
                total = total + item.count
            end
        end
        push({
            key = "item:minecraft:cobblestone",
            category = "item",
            resource = "minecraft:cobblestone",
            label = "Cobblestone Generator",
            current = total,
            max_storage = 1728, -- optional: set your buffer size
        })
    end
    sleep(1)
end
