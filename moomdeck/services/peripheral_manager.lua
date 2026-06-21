local config = require("config")
local storage = require("core/storage")
local events = require("core/events")
local util = require("core/util")
local rate_engine = require("services/rate_engine")
local generic = require("adapters/generic")
local ccbridge = require("adapters/ccbridge")
local advanced = require("adapters/advanced_peripherals")
local create_adapter = require("adapters/create")
local base = require("adapters/base")

local peripheral_manager = {
    peripherals = {},
    live = {},
    adapters = { generic, ccbridge, advanced, create_adapter },
    pushed = {},
}

local function stream_id(peripheral_name, key)
    return util.slug(peripheral_name) .. "::" .. key
end

local function pick_adapter(types)
    for _, adapter in ipairs(peripheral_manager.adapters) do
        if adapter.matches(types) then
            return adapter
        end
    end
    return generic
end

local function ensure_live(id)
    peripheral_manager.live[id] = peripheral_manager.live[id] or {
        tracker = rate_engine.new_tracker(),
        current = 0,
        max_storage = nil,
        last_update = 0,
        status = "ok",
        message = "",
    }
    return peripheral_manager.live[id]
end

function peripheral_manager.register_push(payload)
    if type(payload) ~= "table" then
        return false, "payload must be table"
    end

    local peripheral_name = payload.peripheral or payload.name or "external"
    local key = payload.key or (payload.category .. ":" .. (payload.resource or "unknown"))
    local id = stream_id(peripheral_name, key)

    storage.ensure_stream(id, {
        peripheral = peripheral_name,
        resource = payload.resource or key,
        category = payload.category or "item",
        label = payload.label or payload.resource or key,
        role = payload.role or "storage",
        max_storage = payload.max_storage,
    })

    peripheral_manager.pushed[id] = {
        current = payload.current or 0,
        max_storage = payload.max_storage,
        flow_in = payload.flow_in or payload.inflow,
        flow_out = payload.flow_out or payload.outflow,
        t = os.clock(),
    }

    events.emit("streams_changed")
    return true, id
end

function peripheral_manager.scan()
    local names = peripheral.getNames()
    local found = {}

    for _, name in ipairs(names) do
        found[name] = true
        local wrapped = peripheral.wrap(name)
        if wrapped then
            local types = base.type_set(name)
            local adapter = pick_adapter(types)
            local discovered = adapter.probe(name, wrapped, types) or {}

            peripheral_manager.peripherals[name] = {
                name = name,
                types = types,
                adapter = adapter,
                peripheral = wrapped,
                streams = discovered,
            }

            for _, stream in ipairs(discovered) do
                local id = stream_id(name, stream.key)
                storage.ensure_stream(id, {
                    peripheral = name,
                    resource = stream.resource,
                    category = stream.category,
                    label = stream.label,
                    role = stream.role,
                    max_storage = stream.max_storage,
                })
            end
        end
    end

    for name in pairs(peripheral_manager.peripherals) do
        if not found[name] then
            peripheral_manager.peripherals[name] = nil
        end
    end

    events.emit("peripherals_scanned")
end

function peripheral_manager.poll()
    local now = os.clock()

    for name, entry in pairs(peripheral_manager.peripherals) do
        for _, stream in ipairs(entry.streams) do
            local id = stream_id(name, stream.key)
            local saved = storage.get().streams[id]
            local live = ensure_live(id)

            local reading = entry.adapter.read_stream(entry.peripheral, stream, entry.types)
            if reading then
                live.current = reading.current or 0
                live.max_storage = reading.max_storage or saved.max_storage or stream.max_storage
                live.last_update = now
                live.status = "ok"
                live.message = reading.raw or ""

                rate_engine.record(live.tracker, live.current, now)

                if reading.flow_in ~= nil or reading.flow_out ~= nil then
                    rate_engine.record_flow(
                        live.tracker,
                        reading.flow_in or 0,
                        reading.flow_out or 0,
                        now
                    )
                end
            else
                live.status = "error"
                live.message = "read failed"
            end
        end
    end

    for id, pushed in pairs(peripheral_manager.pushed) do
        if now - pushed.t < 30 then
            local live = ensure_live(id)
            live.current = pushed.current or 0
            live.max_storage = pushed.max_storage or live.max_storage
            live.last_update = now
            live.status = "pushed"
            rate_engine.record(live.tracker, live.current, now)
            if pushed.flow_in or pushed.flow_out then
                rate_engine.record_flow(live.tracker, pushed.flow_in or 0, pushed.flow_out or 0, now)
            end
        end
    end

    events.emit("streams_polled")
end

function peripheral_manager.get_peripheral_views()
    local views = {}

    for name, entry in pairs(peripheral_manager.peripherals) do
        local stream_views = {}
        for _, stream in ipairs(entry.streams) do
            local id = stream_id(name, stream.key)
            stream_views[#stream_views + 1] = peripheral_manager.get_stream_view(id)
        end

        table.sort(stream_views, function(a, b)
            return (a.label or a.id) < (b.label or b.id)
        end)

        views[#views + 1] = {
            name = name,
            type = base.first_type(name),
            streams = stream_views,
        }
    end

    table.sort(views, function(a, b)
        return a.name < b.name
    end)

    return views
end

function peripheral_manager.get_stream_view(id)
    local saved = storage.get().streams[id]
    local live = peripheral_manager.live[id] or ensure_live(id)
    local machine = saved and saved.machine_id and storage.get().machines[saved.machine_id] or nil
    local factory = machine and machine.factory_id and storage.get().factories[machine.factory_id] or nil

    local rates = rate_engine.compute(live.tracker, {
        min_age = config.min_sample_age,
        current = live.current,
        max_storage = saved and saved.max_storage or live.max_storage,
        lock_inflow = saved and saved.lock_inflow,
        locked_inflow_rate = saved and saved.locked_inflow_rate,
    })

    local category = saved and saved.category or "item"
    local cat_info = config.categories[category] or config.categories.item

    return {
        id = id,
        peripheral = saved and saved.peripheral or "",
        resource = saved and saved.resource or "",
        label = saved and saved.label or id,
        category = category,
        category_label = cat_info.label,
        unit = cat_info.unit,
        color = cat_info.color,
        role = saved and saved.role or "storage",
        current = live.current,
        max_storage = saved and saved.max_storage or live.max_storage,
        machine = machine,
        factory = factory,
        lock_inflow = saved and saved.lock_inflow or false,
        locked_inflow_rate = saved and saved.locked_inflow_rate or 0,
        rates = rates,
        status = live.status,
        message = live.message,
        last_update = live.last_update,
    }
end

function peripheral_manager.get_all_stream_views()
    local views = {}
    for id in pairs(storage.get().streams) do
        views[#views + 1] = peripheral_manager.get_stream_view(id)
    end
    table.sort(views, function(a, b)
        return (a.label or a.id) < (b.label or b.id)
    end)
    return views
end

function peripheral_manager.get_machine_views()
    local views = {}
    for machine_id, machine in pairs(storage.get().machines) do
        local streams = {}
        for _, stream_id_ref in ipairs(machine.stream_ids) do
            streams[#streams + 1] = peripheral_manager.get_stream_view(stream_id_ref)
        end
        local trackers = {}
        for _, s in ipairs(streams) do
            local live = peripheral_manager.live[s.id]
            if live then
                trackers[#trackers + 1] = {
                    tracker = live.tracker,
                    opts = {
                        current = s.current,
                        max_storage = s.max_storage,
                        lock_inflow = s.lock_inflow,
                        locked_inflow_rate = s.locked_inflow_rate,
                    },
                }
            end
        end

        views[#views + 1] = {
            id = machine_id,
            name = machine.name,
            factory_id = machine.factory_id,
            streams = streams,
            totals = rate_engine.aggregate(trackers),
        }
    end

    table.sort(views, function(a, b)
        return a.name < b.name
    end)

    return views
end

function peripheral_manager.get_factory_views()
    local views = {}
    for factory_id, factory in pairs(storage.get().factories) do
        local machines = {}
        for _, machine_id in ipairs(factory.machine_ids) do
            for _, machine_view in ipairs(peripheral_manager.get_machine_views()) do
                if machine_view.id == machine_id then
                    machines[#machines + 1] = machine_view
                end
            end
        end

        local trackers = {}
        for _, machine in ipairs(machines) do
            for _, stream in ipairs(machine.streams) do
                local live = peripheral_manager.live[stream.id]
                if live then
                    trackers[#trackers + 1] = {
                        tracker = live.tracker,
                        opts = {
                            current = stream.current,
                            max_storage = stream.max_storage,
                            lock_inflow = stream.lock_inflow,
                            locked_inflow_rate = stream.locked_inflow_rate,
                        },
                    }
                end
            end
        end

        views[#views + 1] = {
            id = factory_id,
            name = factory.name,
            machines = machines,
            totals = rate_engine.aggregate(trackers),
        }
    end

    table.sort(views, function(a, b)
        return a.name < b.name
    end)

    return views
end

function peripheral_manager.set_stream_assignment(stream_id_ref, machine_id)
    storage.assign_stream_to_machine(stream_id_ref, machine_id)
    storage.save()
    events.emit("taxonomy_changed")
end

function peripheral_manager.set_stream_meta(stream_id_ref, fields)
    storage.ensure_stream(stream_id_ref, fields)
    storage.save()
    events.emit("taxonomy_changed")
end

function peripheral_manager.toggle_lock_inflow(stream_id_ref)
    local stream = storage.get().streams[stream_id_ref]
    if not stream then
        return
    end
    local view = peripheral_manager.get_stream_view(stream_id_ref)
    stream.lock_inflow = not stream.lock_inflow
    if stream.lock_inflow then
        stream.locked_inflow_rate = view.rates.inflow
    end
    storage.save()
    events.emit("taxonomy_changed")
end

return peripheral_manager
