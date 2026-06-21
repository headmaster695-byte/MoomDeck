local events = {
    listeners = {},
}

function events.on(name, handler)
    events.listeners[name] = events.listeners[name] or {}
    local list = events.listeners[name]
    list[#list + 1] = handler
    return function()
        for i, fn in ipairs(list) do
            if fn == handler then
                table.remove(list, i)
                break
            end
        end
    end
end

function events.emit(name, ...)
    local list = events.listeners[name]
    if not list then
        return
    end
    for _, fn in ipairs(list) do
        fn(...)
    end
end

return events
