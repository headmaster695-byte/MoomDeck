local scheduler = {
    tasks = {},
    next_id = 1,
}

function scheduler.every(interval, fn, name)
    local id = scheduler.next_id
    scheduler.next_id = scheduler.next_id + 1
    scheduler.tasks[id] = {
        id = id,
        name = name or ("task_" .. id),
        interval = interval,
        fn = fn,
        next_run = os.clock() + interval,
    }
    return id
end

function scheduler.cancel(id)
    scheduler.tasks[id] = nil
end

function scheduler.tick()
    local now = os.clock()
    for _, task in pairs(scheduler.tasks) do
        if now >= task.next_run then
            local ok, err = pcall(task.fn)
            if not ok then
                print("[MoomDeck] Task " .. task.name .. " failed: " .. tostring(err))
            end
            task.next_run = now + task.interval
        end
    end
end

return scheduler
