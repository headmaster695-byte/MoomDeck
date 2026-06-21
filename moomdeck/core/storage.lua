local util = require("core/util")

local storage = {
    path = "moomdeck/data.json",
}

local default_data = {
    factories = {},
    machines = {},
    streams = {},
    peripheral_meta = {},
}

local data = util.deepcopy(default_data)

function storage.set_path(path)
    storage.path = path
end

function storage.load()
    if not fs.exists(storage.path) then
        data = util.deepcopy(default_data)
        return data
    end

    local handle = fs.open(storage.path, "r")
    if not handle then
        data = util.deepcopy(default_data)
        return data
    end

    local raw = handle.readAll()
    handle.close()

    local ok, decoded = pcall(textutils.unserialiseJSON, raw)
    if ok and type(decoded) == "table" then
        data = decoded
        data.factories = data.factories or {}
        data.machines = data.machines or {}
        data.streams = data.streams or {}
        data.peripheral_meta = data.peripheral_meta or {}
    else
        data = util.deepcopy(default_data)
    end

    return data
end

function storage.save()
    local dir = storage.path:match("^(.*)/[^/]+$")
    if dir and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local handle = fs.open(storage.path, "w")
    if not handle then
        return false
    end

    handle.write(textutils.serialiseJSON(data))
    handle.close()
    return true
end

function storage.get()
    return data
end

function storage.ensure_factory(id, name)
    data.factories[id] = data.factories[id] or {
        id = id,
        name = name or id,
        machine_ids = {},
    }
    if name then
        data.factories[id].name = name
    end
    return data.factories[id]
end

function storage.ensure_machine(id, name, factory_id)
    data.machines[id] = data.machines[id] or {
        id = id,
        name = name or id,
        factory_id = factory_id,
        stream_ids = {},
    }
    if name then
        data.machines[id].name = name
    end
    if factory_id then
        data.machines[id].factory_id = factory_id
    end
    return data.machines[id]
end

function storage.ensure_stream(id, fields)
    data.streams[id] = data.streams[id] or {
        id = id,
        peripheral = "",
        resource = "",
        category = "item",
        label = "",
        machine_id = nil,
        role = "storage",
        lock_inflow = false,
        locked_inflow_rate = 0,
        max_storage = nil,
    }

    if fields then
        for k, v in pairs(fields) do
            data.streams[id][k] = v
        end
    end

    return data.streams[id]
end

function storage.assign_stream_to_machine(stream_id, machine_id)
    local stream = data.streams[stream_id]
    local machine = machine_id and data.machines[machine_id] or nil
    if not stream then
        return false
    end

    if stream.machine_id and data.machines[stream.machine_id] then
        local old = data.machines[stream.machine_id].stream_ids
        local idx = util.index_of(old, stream_id)
        if idx then
            table.remove(old, idx)
        end
    end

    stream.machine_id = machine_id

    if machine then
        if not util.index_of(machine.stream_ids, stream_id) then
            machine.stream_ids[#machine.stream_ids + 1] = stream_id
        end
        if machine.factory_id and data.factories[machine.factory_id] then
            if not util.index_of(data.factories[machine.factory_id].machine_ids, machine_id) then
                data.factories[machine.factory_id].machine_ids[#data.factories[machine.factory_id].machine_ids + 1] = machine_id
            end
        end
    end

    return true
end

function storage.create_factory(name)
    local id = util.slug(name) .. "_" .. string.sub(util.uuid(), 1, 8)
    local factory = storage.ensure_factory(id, name)
    storage.save()
    return factory
end

function storage.create_machine(name, factory_id)
    local id = util.slug(name) .. "_" .. string.sub(util.uuid(), 1, 8)
    local machine = storage.ensure_machine(id, name, factory_id)
    if factory_id and data.factories[factory_id] then
        local list = data.factories[factory_id].machine_ids
        if not util.index_of(list, id) then
            list[#list + 1] = id
        end
    end
    storage.save()
    return machine
end

return storage
