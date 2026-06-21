local theme = require("ui/theme")
local components = require("ui/components")
local display = require("ui/display")
local peripheral_manager = require("services/peripheral_manager")
local storage = require("core/storage")

local organize_app = {
    id = "organize",
    title = "Organize",
}

function organize_app.mount(parent, bounds)
    local win = window.create(parent, bounds.x, bounds.y, bounds.w, bounds.h, true)
    local selected_factory = 1
    local selected_machine = 1
    local selected_stream = 1

    local function factories()
        local list = {}
        for _, factory in pairs(storage.get().factories) do
            list[#list + 1] = factory
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        return list
    end

    local function machines_for(factory_id)
        local list = {}
        for _, machine in pairs(storage.get().machines) do
            if machine.factory_id == factory_id then
                list[#list + 1] = machine
            end
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        return list
    end

    local function draw()
        local w, h = win.getSize()
        components.fill(win, " ", theme.bg)
        components.draw_header(win, "Organize", "Assign streams -> machines -> factories")

        local col_w = math.floor((w - 4) / 3)
        local factories_list = factories()
        local factory = factories_list[selected_factory]
        local machines_list = factory and machines_for(factory.id) or {}
        local machine = machines_list[selected_machine]

        components.text(win, 2, 3, "[N] Factory", theme.title, theme.bg)
        local y = 4
        for i, f in ipairs(factories_list) do
            components.button(win, 2, y, col_w, f.name, i == selected_factory)
            y = y + 1
        end

        local mx = col_w + 3
        components.text(win, mx, 3, "[M] Machine", theme.title, theme.bg)
        y = 4
        for i, m in ipairs(machines_list) do
            components.button(win, mx, y, col_w, m.name, i == selected_machine)
            y = y + 1
        end

        local sx = mx + col_w + 1
        components.text(win, sx, 3, "Streams", theme.title, theme.bg)
        y = 4
        local all_streams = peripheral_manager.get_all_stream_views()
        for i, stream in ipairs(all_streams) do
            local assigned = stream.machine and stream.machine.name or "unassigned"
            local label = stream.label .. " -> " .. assigned
            components.button(win, sx, y, w - sx - 1, label, i == selected_stream)
            y = y + 1
            if y > h - 2 then break end
        end

        components.text(win, 2, h - 1, "[A] assign selected stream to selected machine  [C] clear assignment", theme.text_dim, theme.bg)
    end

    draw()

    return {
        window = win,
        redraw = draw,
        click = function(x, y)
            local w, h = win.getSize()
            local col_w = math.floor((w - 4) / 3)
            local factories_list = factories()

            if y >= 4 and x >= 2 and x < col_w + 2 then
                local idx = y - 3
                if factories_list[idx] then
                    selected_factory = idx
                    selected_machine = 1
                    return true
                end
            end

            local mx = col_w + 3
            local machines_list = factories_list[selected_factory] and machines_for(factories_list[selected_factory].id) or {}
            if y >= 4 and x >= mx and x < mx + col_w then
                local idx = y - 3
                if machines_list[idx] then
                    selected_machine = idx
                    return true
                end
            end

            local sx = mx + col_w + 1
            if y >= 4 and x >= sx then
                local idx = y - 3
                local streams = peripheral_manager.get_all_stream_views()
                if streams[idx] then
                    selected_stream = idx
                    return true
                end
            end

            return false
        end,
        key = function(key)
            local factories_list = factories()
            if key == keys.n then
                local name = components.prompt(display.term, "Factory name:", "New Factory")
                if name and name ~= "" then
                    storage.create_factory(name)
                    selected_factory = #factories()
                end
                return true
            elseif key == keys.m then
                local factory = factories_list[selected_factory]
                if not factory then return true end
                local name = components.prompt(display.term, "Machine name:", "New Machine")
                if name and name ~= "" then
                    storage.create_machine(name, factory.id)
                    selected_machine = #machines_for(factory.id)
                end
                return true
            elseif key == keys.a then
                local factory = factories_list[selected_factory]
                local machines_list = factory and machines_for(factory.id) or {}
                local machine = machines_list[selected_machine]
                local streams = peripheral_manager.get_all_stream_views()
                local stream = streams[selected_stream]
                if machine and stream then
                    peripheral_manager.set_stream_assignment(stream.id, machine.id)
                end
                return true
            elseif key == keys.c then
                local streams = peripheral_manager.get_all_stream_views()
                local stream = streams[selected_stream]
                if stream then
                    peripheral_manager.set_stream_assignment(stream.id, nil)
                end
                return true
            end
            return false
        end,
    }
end

return organize_app
