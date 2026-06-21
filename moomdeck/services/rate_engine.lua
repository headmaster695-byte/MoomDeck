local config = require("config")
local util = require("core/util")

local rate_engine = {}

local function trim_samples(samples, now, max_age)
    local cutoff = now - max_age
    while #samples > 0 and samples[1].t < cutoff do
        table.remove(samples, 1)
    end
end

function rate_engine.new_tracker()
    return {
        samples = {},
        last = nil,
        gross_in = 0,
        gross_out = 0,
        gross_window_start = os.clock(),
    }
end

function rate_engine.record(tracker, amount, now)
    now = now or os.clock()
    amount = amount or 0

    if tracker.last then
        local delta = amount - tracker.last.amount
        local dt = now - tracker.last.t
        if dt > 0 then
            if delta >= 0 then
                tracker.gross_in = tracker.gross_in + delta
            else
                tracker.gross_out = tracker.gross_out + math.abs(delta)
            end
        end
    end

    tracker.last = { t = now, amount = amount }
    tracker.samples[#tracker.samples + 1] = tracker.last
    trim_samples(tracker.samples, now, config.sample_window)

    local window = os.clock() - tracker.gross_window_start
    if window >= 30 then
        tracker.gross_in = 0
        tracker.gross_out = 0
        tracker.gross_window_start = os.clock()
    end
end

function rate_engine.record_flow(tracker, inflow, outflow, now)
    now = now or os.clock()
    tracker.flow_in = inflow
    tracker.flow_out = outflow
    tracker.flow_t = now
    tracker.last = tracker.last or { t = now, amount = 0 }
end

local function slope_rate(samples, min_age)
    if #samples < 2 then
        return 0
    end

    local newest = samples[#samples]
    local oldest = samples[1]
    for i = 1, #samples do
        if newest.t - samples[i].t >= min_age then
            oldest = samples[i]
            break
        end
    end

    local dt = newest.t - oldest.t
    if dt <= 0 then
        return 0
    end

    return (newest.amount - oldest.amount) / dt
end

function rate_engine.compute(tracker, opts)
    opts = opts or {}
    local net = slope_rate(tracker.samples, opts.min_age or config.min_sample_age)

    local gross_window = os.clock() - tracker.gross_window_start
    local inflow = 0
    local outflow = 0

    if tracker.flow_in ~= nil and tracker.flow_t and (os.clock() - tracker.flow_t) < 5 then
        inflow = tracker.flow_in
        outflow = tracker.flow_out or 0
    elseif gross_window > 0 then
        inflow = tracker.gross_in / gross_window
        outflow = tracker.gross_out / gross_window
    end

    if opts.lock_inflow and opts.locked_inflow_rate then
        inflow = opts.locked_inflow_rate
        if net < 0 then
            outflow = math.max(outflow, inflow + math.abs(net))
        elseif net > 0 and outflow == 0 then
            outflow = math.max(0, inflow - net)
        end
    end

    local time_to_fill = nil
    if opts.max_storage and opts.current ~= nil then
        local remaining = opts.max_storage - opts.current
        if remaining <= 0 then
            time_to_fill = 0
        elseif net > 0 then
            time_to_fill = remaining / net
        else
            time_to_fill = math.huge
        end
    end

    return {
        net = net,
        inflow = inflow,
        outflow = outflow,
        per_second = net,
        per_minute = net * 60,
        per_hour = net * 3600,
        time_to_fill = time_to_fill,
        sample_count = #tracker.samples,
    }
end

function rate_engine.aggregate(trackers, opts)
    local totals = { net = 0, inflow = 0, outflow = 0, current = 0, max_storage = 0 }
    local has_cap = false

    for _, entry in ipairs(trackers) do
        local rates = rate_engine.compute(entry.tracker, entry.opts)
        totals.net = totals.net + rates.net
        totals.inflow = totals.inflow + rates.inflow
        totals.outflow = totals.outflow + rates.outflow
        totals.current = totals.current + (entry.opts.current or 0)
        if entry.opts.max_storage then
            totals.max_storage = totals.max_storage + entry.opts.max_storage
            has_cap = true
        end
    end

    if has_cap and totals.net > 0 then
        totals.time_to_fill = (totals.max_storage - totals.current) / totals.net
    else
        totals.time_to_fill = nil
    end

    totals.per_second = totals.net
    totals.per_minute = totals.net * 60
    totals.per_hour = totals.net * 3600
    return totals
end

return rate_engine
