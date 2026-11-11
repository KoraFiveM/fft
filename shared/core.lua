FFT = { definitions = {}, adapters = {}, contexts = {}, features = {} }
local realm = IsDuplicityVersion() and 'server' or 'client'
FFT.realm = realm
-- Archived report ids are v4 UUIDs. They become file names, so nothing else is accepted.
function FFT.reportUuid(id)
    return type(id)=='string' and #id==36
        and id:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')~=nil
        and id==id:lower()
end
local function owner() return GetInvokingResource() or GetCurrentResourceName() end
local function callable(fn) return type(fn) == 'function' or (type(fn) == 'table' and getmetatable(fn) and getmetatable(fn).__call) end
function FFT.registerStep(spec, callback, resource)
    resource = resource or owner()
    assert(type(spec) == 'table' and type(spec.pattern) == 'string', 'Step pattern required')
    assert(spec.realm == 'client' or spec.realm == 'server', 'Explicit client/server realm required')
    assert(callable(callback), 'Step callback required')
    local id = resource .. ':' .. spec.realm .. ':' .. (spec.hook or 'step') .. ':' .. spec.pattern
    assert(not FFT.definitions[id], 'Duplicate definition: ' .. id)
    FFT.definitions[id] = { id = id, owner = resource, pattern = spec.pattern, realm = spec.realm,
        requires = spec.requires or {}, hook = spec.hook, callback = callback }
    return id
end
exports('registerStep', FFT.registerStep)
function FFT.registerAdapter(id, adapter, resource)
    assert(type(id) == 'string' and type(adapter) == 'table', 'Adapter ID and definition required')
    assert(not FFT.adapters[id], 'Duplicate adapter: ' .. id)
    adapter.owner = resource or owner()
    FFT.adapters[id] = adapter
end
exports('registerAdapter', FFT.registerAdapter)
function FFT.catalogue()
    local list = {}
    for _, d in pairs(FFT.definitions) do
        list[#list + 1] = { id=d.id, pattern=d.pattern, realm=d.realm, requires=d.requires, hook=d.hook }
    end
    table.sort(list, function(a,b) return a.id < b.id end)
    return list
end
-- Server console errors. The console listener in server/main.lua feeds complete
-- lines to FFT.consoleLine. A scenario may declare an error line it provokes on
-- purpose (ctx:expectConsoleError); such a line and its traceback are kept on
-- the expectation instead of being logged as an error. Expectations live on the
-- scenario's context, so they end with the scenario and never reach another
-- scenario or another tester's session. Nothing here may print: output from the
-- listener would re-enter it.
local CONSOLE_MESSAGE, EXPECT_MIN, EXPECT_MAX, EXPECT_LIMIT, EXPECT_LINES = 4000, 16, 300, 8, 5
---Validates and stores one expectation in `list`. Plain text, no patterns.
---@param list table[] the scenario context's `expectedConsole`
---@param text string exact text the error line must contain (colour codes excluded)
---@param resource? string only accept the line from this resource's console channel
function FFT.consoleExpectation(list, text, resource)
    assert(type(text) == 'string', 'Expected console text must be a string')
    text = text:match('^%s*(.-)%s*$')
    assert(not text:find('%c'), 'Expected console text must be a single line without control characters')
    local specific = select(2, text:gsub('%w', ''))
    assert(#text >= EXPECT_MIN and specific >= 8, ('Expected console text must be specific: at least %d characters, 8 of them letters or digits'):format(EXPECT_MIN))
    assert(#text <= EXPECT_MAX, ('Expected console text is limited to %d characters'):format(EXPECT_MAX))
    assert(resource == nil or (type(resource) == 'string' and resource:match('^[%w_%-%.]+$') and #resource <= 64),
        'Expected console resource must be a resource name')
    for _, e in ipairs(list) do if e.text == text and e.resource == resource then return e end end
    assert(#list < EXPECT_LIMIT, ('A scenario may expect at most %d console errors'):format(EXPECT_LIMIT))
    local e = { text=text, resource=resource, matched=0, lines={} }
    list[#list + 1] = e
    return e
end
---Records one error line for a running scenario: on a matching expectation of
---`context`, otherwise through `log`. Returns the record that continuation
---lines are appended to, and whether the line was expected.
---@param context? table the session's current scenario context
---@param log fun(entry: table): table? stores an ordinary console error
function FFT.consoleRecord(context, resource, plain, log)
    for _, e in ipairs(context and context.expectedConsole or {}) do
        if (e.resource == nil or e.resource == resource) and plain:find(e.text, 1, true) then
            e.matched = e.matched + 1
            local record = { resource=resource, message=plain }
            if #e.lines < EXPECT_LINES then e.lines[#e.lines + 1] = record end
            return record, true
        end
    end
    return log({ type='console', kind='server', resource=resource, message=plain }), false
end
---Classifies one complete console line. `track` keeps, per channel, the records
---of the last error so its continuation lines (traceback) join them.
---@param record fun(resource: string, plain: string): table[] stores the error for every running scenario
function FFT.consoleLine(track, channel, line, now, record)
    local plain = line:gsub('%^%d', '')
    if not plain:find('%S') then return end
    local last = track[channel]
    if last and now - last.at <= 250 and last.lines < 40 and (plain:match('^%s*>') or plain:match('^%s+%S')
        or plain:find('stack traceback', 1, true) or plain:match('^%s*%[C%]')) then
        last.at, last.lines = now, last.lines + 1
        for _, entry in ipairs(last.entries) do entry.message = (entry.message .. '\n' .. plain):sub(1, CONSOLE_MESSAGE) end
        return
    end
    track[channel] = nil
    -- Platform chatter that says nothing about the code under test.
    if plain:find('Server list query returned an error', 1, true) then return end
    local isError = line:find('^1', 1, true) or plain:find('SCRIPT ERROR', 1, true)
        or plain:lower():find('%f[%a]error%f[%A]')
    if not isError then return end
    local entries = record(channel:match('^script:(.+)$') or channel, plain)
    if #entries > 0 then track[channel] = { at=now, lines=1, entries=entries } end
end
function FFT.context(id, tester, fixture, adapter)
    local ctx = { id=id, tester=tester, fixture=fixture, adapterId=adapter, state={}, cleanups={}, cancelled=false,
        expectedConsole={} }
    function ctx:check()
        assert(not ctx.cancelled, 'Cancelled')
        assert(not ctx.deadline or GetGameTimer() < ctx.deadline, 'Step timed out')
    end
    function ctx:waitUntil(fn, message, timeout, describe)
        local limit = GetGameTimer() + math.min(timeout or FFTConfig.stepTimeout, FFTConfig.stepTimeout)
        -- Give up just before the step watchdog so the caller's message is reported
        -- instead of the generic step timeout.
        if ctx.deadline and not ctx.cancelled then limit = math.min(limit, ctx.deadline - 500) end
        repeat
            ctx:check()
            local value = fn()
            if value then return value end
            Wait(50)
        until GetGameTimer() >= limit
        local detail = describe and select(2, pcall(describe)) or ''
        error((message or 'Condition timed out') .. (type(detail) == 'string' and detail or ''), 0)
    end
    function ctx:equal(actual, expected, message)
        if actual ~= expected then
            ctx.assertion = { actual=actual, expected=expected }
            error((message or 'Assertion failed') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
        end
    end
    -- Exported callbacks receive table snapshots across resource VMs. Methods close
    -- over the owned context; get/set retain state without relying on table aliasing.
    function ctx:get(key) return ctx.state[key] end
    function ctx:set(key,value) ctx:check(); ctx.state[key]=value end
    function ctx:cleanup(fn) ctx:check(); ctx.cleanups[#ctx.cleanups + 1] = fn end
    -- Declares a server console error this scenario provokes on purpose. The
    -- listener is server-side, so only the server context can hold expectations.
    function ctx:expectConsoleError(text, resource)
        assert(realm == 'server', 'Console errors can only be expected from a server-realm step')
        ctx:check()
        FFT.consoleExpectation(ctx.expectedConsole, text, resource)
    end
    function ctx:on(event, fn)
        local handle = AddEventHandler(event, function(...) if not ctx.cancelled then fn(...) end end)
        ctx:cleanup(function() RemoveEventHandler(handle) end)
    end
    function ctx:call(capability, ...)
        ctx:check()
        local selected = assert(FFT.adapters[ctx.adapterId], 'Adapter unavailable: ' .. tostring(ctx.adapterId))
        local fn = selected.operations and selected.operations[capability]
        if not fn and selected.extends then fn = FFT.adapters[selected.extends].operations[capability] end
        assert(fn, 'Missing ' .. realm .. ' capability: ' .. capability)
        return fn(ctx, ...)
    end
    FFT.contexts[id] = ctx
    return ctx
end
function FFT.preflight(adapterId, requirements)
    local a = assert(FFT.adapters[adapterId], 'Missing adapter: ' .. tostring(adapterId))
    if a.preflight then a.preflight() end
    for _, capability in ipairs(requirements or {}) do
        assert((a.operations and a.operations[capability]) or
            (a.extends and FFT.adapters[a.extends].operations[capability]), 'Missing capability: ' .. capability)
    end
end
-- A watchdog stops accepting results; callbacks must cooperate via ctx:check/waitUntil.
function FFT.execute(ctx, definition, args, argument)
    local start = GetGameTimer()
    local d = FFT.definitions[definition]
    if not d or d.realm ~= realm then return { status='failed', error='Definition unavailable in ' .. realm } end
    local done, ok, err = false, false, nil
    ctx.deadline, ctx.assertion = start + FFTConfig.stepTimeout, nil
    CreateThread(function()
        ok, err = xpcall(function()
            FFT.preflight(ctx.adapterId, d.requires)
            ctx:check()
            local values = {}
            for i,v in ipairs(args or {}) do values[i] = v end
            if argument then values[#values + 1] = argument end
            d.callback(ctx, table.unpack(values))
            ctx:check()
        end, debug.traceback)
        done = true
    end)
    while not done and not ctx.cancelled and GetGameTimer() < ctx.deadline do Wait(25) end
    local timed = not ctx.cancelled and GetGameTimer() >= ctx.deadline
    if timed then ctx.cancelled = true end
    return { status=timed and 'timed_out' or (ctx.cancelled and 'cancelled' or (ok and 'passed' or 'failed')),
        error=timed and ('Step exceeded '..tostring(FFTConfig.stepTimeout/1000)..' seconds while waiting for an operation') or err, duration=GetGameTimer()-start, assertion=ctx.assertion }
end
function FFT.cleanup(ctx)
    ctx.cancelled = true
    local errors = {}
    for i=#ctx.cleanups,1,-1 do
        local done, ok, err = false, false, nil
        CreateThread(function() ok,err=xpcall(ctx.cleanups[i], debug.traceback); done=true end)
        local deadline = GetGameTimer()+FFTConfig.cleanupTimeout
        while not done and GetGameTimer()<deadline do Wait(25) end
        if not done or not ok then errors[#errors+1]=not done and 'Cleanup timed out' or tostring(err) end
    end
    FFT.contexts[ctx.id] = nil
    return errors
end
AddEventHandler(realm == 'server' and 'onResourceStop' or 'onClientResourceStop', function(name)
    local relevant=name==GetCurrentResourceName() or (FFTConfig.adapter=='kora' and
        (name=='kora_core' or name=='kora_target' or name=='kora_inventory'))
    for id,d in pairs(FFT.definitions) do if d.owner == name then FFT.definitions[id]=nil; relevant=true end end
    for id,a in pairs(FFT.adapters) do if a.owner == name then FFT.adapters[id]=nil; relevant=true end end
    for id,f in pairs(FFT.features) do if f.owner == name then FFT.features[id]=nil end end
    if relevant then for _,ctx in pairs(FFT.contexts) do ctx.cancelled=true end end
end)
