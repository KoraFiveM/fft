-- kora_dispatch: authoritative call registry (server exports), the unit
-- response state machine and the kora_lib AppShell tablet (kora_dispatch:tablet).
--
-- No resource hook. Calls are raised and closed through the real server exports,
-- which needs the approved seam in kora_dispatch/config.lua (`fft` is a trusted
-- caller while fft_kora_hooks is true): those scenarios are tagged @seam.
-- The tablet is a kora_lib app, so kora_lib's hook drives it; the feed is
-- observed through kora_lib's message log (action `kora_dispatch:feed`).
--
-- Client and server contexts do not share state: both sides identify a call by
-- the title the feature gives it. The server keeps title -> id from createCall;
-- the client learns the id from the feed the server pushed to it.
local K = FFT.kora
if not K then return end
K.feature('kora_dispatch')

local RESOURCE = 'kora_dispatch'
-- Calls raised by a scenario expire on their own after this long even if the
-- cleanup never runs (createCall `duration`, ms). Config.priorities[3] is the
-- quietest tone ('Routine', type 'info' toast).
local CALL_LIFETIME = 60000
local CALL_PRIORITY = 3

-- ---------------------------------------------------------------------------
-- Server: call registry
-- ---------------------------------------------------------------------------

local function callId(ctx, title)
    local id = ctx.state.dispatchCalls and ctx.state.dispatchCalls[title]
    assert(id, 'No dispatch call titled "' .. tostring(title) .. '" was raised in this scenario')
    return id
end

local function wireCall(ctx, title)
    local call = K.export(RESOURCE, 'getCall', callId(ctx, title))
    assert(type(call) == 'table', 'Dispatch call "' .. title .. '" is no longer stored')
    return call
end

local function isActive(ctx, title, service)
    local id = callId(ctx, title)
    for _, call in ipairs(K.export(RESOURCE, 'getCalls', { service = service, activeOnly = true }) or {}) do
        if call.id == id then return true end
    end
    return false
end

local function myUnit(ctx, title)
    for _, unit in ipairs(wireCall(ctx, title).units or {}) do
        if unit.src == ctx.tester then return unit end
    end
end

-- exports.kora_dispatch:createCall (server/api.lua). The call reaches every
-- on-duty member of the job, so the scenarios are tagged @global.
K.step('a dispatch call titled {string} is raised for the job {string}', 'server', function(ctx, title, job)
    assert(#title > 0 and #title <= 80, 'Call title must be 1-80 characters')
    local id, result = K.export(RESOURCE, 'createCall', {
        jobs = { job },
        title = title,
        message = 'Automated functional test call. No action needed.',
        priority = CALL_PRIORITY,
        duration = CALL_LIFETIME,
    })
    if type(id) ~= 'number' then
        error(('createCall refused (is the fft seam active? setr fft_kora_hooks true): %s'):format(tostring(result)), 0)
    end
    ctx:cleanup(function() pcall(function() exports.kora_dispatch:closeCall(id, 'fft cleanup') end) end)
    ctx.state.dispatchCalls = ctx.state.dispatchCalls or {}
    ctx.state.dispatchCalls[title] = id
    ctx.state.dispatchRecipients = result
end)

K.step('the dispatch call {string} should have reached at least {int} unit', 'server', function(ctx, title, minimum)
    callId(ctx, title)
    local count = tonumber(ctx.state.dispatchRecipients)
    assert(count and count >= minimum, ('createCall reported %s recipient(s), expected at least %d'):format(tostring(count), minimum))
end)

K.step('the dispatch call {string} should be live for the service {string}', 'server', function(ctx, title, service)
    local call = wireCall(ctx, title)
    ctx:equal(call.service, service, 'Call service')
    ctx:equal(call.title, title, 'Call title')
    ctx:equal(call.origin, 'fft', 'Call origin')
    ctx:equal(call.closedAt, nil, 'Call closedAt')
    assert(isActive(ctx, title, service), 'Call is missing from the active ' .. service .. ' calls')
end)

K.step('the dispatch call {string} should have priority {int}', 'server', function(ctx, title, priority)
    ctx:equal(wireCall(ctx, title).priority, priority, 'Call priority')
end)

K.step('the dispatch call {string} is revised to priority {int}', 'server', function(ctx, title, priority)
    local ok, err = K.export(RESOURCE, 'updateCall', callId(ctx, title), { priority = priority, duration = CALL_LIFETIME })
    if not ok then error('updateCall refused: ' .. tostring(err), 0) end
end)

K.step('revising the dispatch call {string} to priority {int} should be refused with {string}', 'server', function(ctx, title, priority, reason)
    local ok, err = K.export(RESOURCE, 'updateCall', callId(ctx, title), { priority = priority })
    assert(not ok, 'updateCall accepted priority ' .. priority)
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('the dispatch call {string} is closed with the reason {string}', 'server', function(ctx, title, reason)
    local ok, err = K.export(RESOURCE, 'closeCall', callId(ctx, title), reason)
    if not ok then error('closeCall refused: ' .. tostring(err), 0) end
end)

K.step('the dispatch call {string} should be closed with the reason {string}', 'server', function(ctx, title, reason)
    local call = wireCall(ctx, title)
    ctx:equal(type(call.closedAt), 'number', 'Call closedAt type')
    ctx:equal(call.closeReason, reason, 'Close reason')
    assert(not isActive(ctx, title, call.service), 'A closed call is still listed as active')
end)

-- Doc string: the createCall payload as JSON. Nothing must be created.
K.step('raising a dispatch call should be refused with {string}:', 'server', function(ctx, reason, argument)
    local payload = K.json(argument)
    assert(type(payload) == 'table', 'Payload must be a JSON object')
    payload.duration = CALL_LIFETIME
    local id, err = K.export(RESOURCE, 'createCall', payload)
    if id then
        pcall(function() exports.kora_dispatch:closeCall(id, 'fft cleanup') end)
        error('createCall accepted the payload as call #' .. tostring(id), 0)
    end
    assert(K.contains(err, reason), ('Refusal is "%s", expected it to contain "%s"'):format(tostring(err), reason))
end)

-- ---------------------------------------------------------------------------
-- Server: unit responses (exports.kora_dispatch:setUnitState, the function the
-- kora_dispatch:respond callback delegates to)
-- ---------------------------------------------------------------------------

K.step('I respond to the dispatch call {string} as {string}', 'server', function(ctx, title, state)
    local result, err = K.export(RESOURCE, 'setUnitState', ctx.tester, callId(ctx, title), state)
    if result ~= state then error(('setUnitState refused %s: %s'):format(state, tostring(err)), 0) end
end)

K.step('I advance my response to the dispatch call {string}', 'server', function(ctx, title)
    local result, err = K.export(RESOURCE, 'setUnitState', ctx.tester, callId(ctx, title))
    if not result then error('setUnitState refused to advance: ' .. tostring(err), 0) end
end)

K.step('I drop my response to the dispatch call {string}', 'server', function(ctx, title)
    -- Detaching returns false with no error; a refusal returns false and a reason.
    local result, err = K.export(RESOURCE, 'setUnitState', ctx.tester, callId(ctx, title), false)
    assert(result == false and err == nil, 'Detaching was refused: ' .. tostring(err))
end)

K.step('responding to the dispatch call {string} should be refused with {string}', 'server', function(ctx, title, reason)
    local result, err = K.export(RESOURCE, 'setUnitState', ctx.tester, callId(ctx, title), 'en_route')
    assert(result == false, 'setUnitState accepted the response: ' .. tostring(result))
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('responding to an unknown dispatch call should be refused with {string}', 'server', function(ctx, reason)
    local result, err = K.export(RESOURCE, 'setUnitState', ctx.tester, -1, 'en_route')
    assert(result == false, 'setUnitState accepted an unknown call')
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('my response to the dispatch call {string} should be {string}', 'server', function(ctx, title, state)
    ctx:waitUntil(function()
        local unit = myUnit(ctx, title)
        return unit and unit.state == state
    end, ('My response is %s, expected %s'):format(tostring((myUnit(ctx, title) or {}).state), state), 5000)
end)

K.step('I should not be attached to the dispatch call {string}', 'server', function(ctx, title)
    ctx:waitUntil(function() return myUnit(ctx, title) == nil end, 'I am still attached to the call', 3000)
end)

-- kora_core setJobDuty fires QBCore:Server:SetDuty, which is what detaches a unit.
K.step('I end my dispatch shift', 'server', function(ctx)
    local ok, err = exports.kora_core:setJobDuty(ctx.tester, false)
    if not ok then error('Could not go off duty: ' .. tostring(err), 0) end
end)

local function onRoster(ctx, service)
    for _, unit in ipairs(K.export(RESOURCE, 'getOnDutyUnits', { service = service }) or {}) do
        if unit.src == ctx.tester then return unit end
    end
end

K.step('the dispatch roster for the service {string} should include me', 'server', function(ctx, service)
    ctx:waitUntil(function() return onRoster(ctx, service) end, 'I am not on the ' .. service .. ' roster', 3000)
end)
K.step('the dispatch roster for the service {string} should not include me', 'server', function(ctx, service)
    ctx:waitUntil(function() return not onRoster(ctx, service) end, 'I am still on the ' .. service .. ' roster', 3000)
end)

-- ---------------------------------------------------------------------------
-- Client: service membership, feed and tablet
-- ---------------------------------------------------------------------------

-- exports.kora_dispatch:getService (client/exports.lua). The client hydrates
-- asynchronously after a job or duty change, so this waits for it.
K.step('my dispatch service should be {string}', 'client', function(ctx, service)
    K.started(RESOURCE)
    -- An export that returns nil yields NO value across resources, so the call is
    -- wrapped in parentheses: a bare tostring(export()) raises "value expected".
    local seen
    ctx:waitUntil(function()
        seen = (exports.kora_dispatch:getService())
        return seen == service
    end, 'Dispatch service is not ' .. service, 8000, function() return ': it is ' .. tostring(seen) end)
end)

K.step('I should have no dispatch service', 'client', function(ctx)
    K.started(RESOURCE)
    local seen
    ctx:waitUntil(function()
        seen = (exports.kora_dispatch:getService())
        return seen == nil
    end, 'Dispatch service is still set', 8000, function() return ': ' .. tostring(seen) end)
end)

-- The real key path: Kora.keybind.add registers +kora_dispatch_tablet / -kora_dispatch_tablet
-- (kora_dispatch/client/keybinds.lua, kora_lib/modules/keybind/client.lua).
K.step('I press the dispatch tablet key', 'client', function(ctx)
    K.started(RESOURCE)
    ctx:cleanup(function() pcall(function() exports.kora_dispatch:setTablet(false) end) end)
    ExecuteCommand('+kora_dispatch_tablet')
    Wait(100)
    ExecuteCommand('-kora_dispatch_tablet')
end)

-- Newest feed payload kora_dispatch sent through Kora.nui.setDispatchFeed since
-- the scenario began. The payload is `false` while the tablet is open.
local function feedCall(ctx, title)
    local entries = K.ui('log', ctx.state.uiBaseline or 0) or {}
    for index = #entries, 1, -1 do
        local entry = entries[index]
        if entry.action == 'kora_dispatch:feed' then
            if type(entry.data) ~= 'table' then return nil end
            for _, call in pairs(type(entry.data.calls) == 'table' and entry.data.calls or {}) do
                if type(call) == 'table' and call.title == title then return call end
            end
            return nil
        end
    end
end

K.step('the dispatch feed should show the call {string}', 'client', function(ctx, title)
    local call = ctx:waitUntil(function() return feedCall(ctx, title) end, 'The dispatch feed does not show "' .. title .. '"', 8000)
    ctx.state.dispatchFeedIds = ctx.state.dispatchFeedIds or {}
    ctx.state.dispatchFeedIds[title] = call.id
end)

K.step('the dispatch feed should show the call {string} as closed', 'client', function(ctx, title)
    ctx:waitUntil(function()
        local call = feedCall(ctx, title)
        return call and call.closedAt ~= nil
    end, 'The dispatch feed does not show "' .. title .. '" as closed', 8000)
end)

-- App action dispatch:select with the call id as item id (client/ui.lua).
-- Run `the dispatch feed should show the call` first so the id is known.
K.step('I select the dispatch call {string} on the tablet', 'client', function(ctx, title)
    local id = ctx.state.dispatchFeedIds and ctx.state.dispatchFeedIds[title]
    assert(id, 'Observe the call on the dispatch feed before opening the tablet')
    K.must(K.ui('app.action', 'dispatch:select', { itemId = tostring(id) }))
end)

-- App action dispatch:respond:<state>. The tablet only declares the next state
-- of the selected call and re-registers itself when the server pushes the
-- updated call, so wait for the action to be declared; a refusal by the
-- server (the app's handler raising) fails the step.
K.step('I respond {string} to the selected dispatch call on the tablet', 'client', function(ctx, state)
    assert(state == 'en_route' or state == 'on_scene' or state == 'clear', 'Unknown unit state: ' .. state)
    ctx:waitUntil(function()
        local ok, err = K.ui('app.action', 'dispatch:respond:' .. state)
        if ok then return true end
        if K.contains(err, 'not declared') then return false end
        error('The tablet refused the response: ' .. tostring(err), 0)
    end, 'The tablet does not offer the response ' .. state, 8000)
end)

-- ===========================================================================
-- Round 3: payload normalisation, patching, expiry, closing, listing, the unit
-- state machine edges, onAccept, player alerts, feed keys and tablet details.
-- Every call is still raised for "tow" (service recovery), lives at most
-- CALL_LIFETIME unless a scenario says otherwise, and is closed in cleanup.
-- ===========================================================================

local function remember(ctx, label, id)
    ctx.state.dispatchCalls = ctx.state.dispatchCalls or {}
    ctx.state.dispatchCalls[label] = id
end

local function closeLater(ctx, id)
    ctx:cleanup(function() pcall(function() exports.kora_dispatch:closeCall(id, 'fft cleanup') end) end)
end

-- createCall with a scenario-supplied payload (shared/calls.lua:75-138 normalise,
-- server/recipients.lua:38-85 resolve). `label` is how later steps name the call,
-- because the payload may carry no title at all (title falls back to message).
local function raise(ctx, label, payload)
    local id, result = K.export(RESOURCE, 'createCall', payload)
    if type(id) ~= 'number' then error('createCall refused: ' .. tostring(result), 0) end
    closeLater(ctx, id)
    remember(ctx, label, id)
    ctx.state.dispatchRecipients = result
    return id
end

K.step('a dispatch call known as {string} is raised with:', 'server', function(ctx, label, argument)
    local payload = K.json(argument)
    assert(type(payload) == 'table', 'Payload must be a JSON object')
    if payload.duration == nil then payload.duration = CALL_LIFETIME end
    raise(ctx, label, payload)
end)

-- No duration: the lifetime comes from Config.priorities[priority].ttl
-- (shared/calls.lua:135). Use priority 3 (120000 ms) so it still dies quickly.
K.step('a dispatch call known as {string} is raised without a duration with:', 'server', function(ctx, label, argument)
    local payload = K.json(argument)
    assert(type(payload) == 'table', 'Payload must be a JSON object')
    assert(payload.duration == nil, 'This step must not be given a duration')
    raise(ctx, label, payload)
end)

-- Priority fallback (shared/calls.lua:57-61): floor(tonumber(p) or 0), unknown -> 2.
K.step('a dispatch call known as {string} is raised for the job {string} with the priority {string} given as {string}', 'server', function(ctx, label, job, raw, kind)
    local priority
    if kind == 'number' then priority = assert(tonumber(raw), 'Not a number: ' .. raw)
    elseif kind == 'text' then priority = raw
    else error('Priority kind must be "number" or "text"', 0) end
    raise(ctx, label, { jobs = { job }, title = label, message = 'Automated functional test call. No action needed.',
        priority = priority, duration = CALL_LIFETIME })
end)

K.step('the dispatch call {string} should belong to the service {string}', 'server', function(ctx, label, service)
    ctx:equal(wireCall(ctx, label).service, service, 'Call service')
end)

K.step('the dispatch call {string} should have the field {string} set to {string}', 'server', function(ctx, label, field, value)
    ctx:equal(wireCall(ctx, label)[field], value, 'Call ' .. field)
end)

-- Wire shape (server/api.lua:16-43): onAccept and jobs are never carried.
K.step('the dispatch call {string} should have no field {string}', 'server', function(ctx, label, field)
    local value = wireCall(ctx, label)[field]
    assert(value == nil, ('Call %s is %s, expected none'):format(field, tostring(value)))
end)

K.step('the dispatch call {string} should be located at {float} {float} {float}', 'server', function(ctx, label, x, y, z)
    local coords = wireCall(ctx, label).coords
    assert(type(coords) == 'table', 'Call has no coordinates')
    for axis, expected in pairs({ x = x, y = y, z = z }) do
        assert(math.abs((coords[axis] or 0) - expected) < 0.01, ('Call %s is %s, expected %s'):format(axis, tostring(coords[axis]), expected))
    end
end)

K.step('the dispatch call {string} should carry the data {string} set to {string}', 'server', function(ctx, label, key, value)
    local data = wireCall(ctx, label).data
    assert(type(data) == 'table', 'Call carries no data')
    ctx:equal(tostring(data[key]), value, 'Call data ' .. key)
end)

K.step('the dispatch call {string} should carry no data {string}', 'server', function(ctx, label, key)
    local data = wireCall(ctx, label).data
    assert(type(data) ~= 'table' or data[key] == nil, 'Call data carries ' .. key)
end)

-- expiresAt = createdAt + ttl (server/store.lua:103, 205-207).
K.step('the dispatch call {string} should last {int} milliseconds', 'server', function(ctx, label, ms)
    local call = wireCall(ctx, label)
    ctx:equal(call.expiresAt - call.createdAt, ms, 'Call lifetime')
end)

-- The doc-string refusal step forces a valid duration; this one sends a bad one.
K.step('raising a dispatch call with a duration of {int} should be refused with {string}', 'server', function(ctx, duration, reason)
    local id, err = K.export(RESOURCE, 'createCall', { jobs = { 'tow' }, title = 'FFT refused call', duration = duration })
    if id then
        pcall(function() exports.kora_dispatch:closeCall(id, 'fft cleanup') end)
        error('createCall accepted duration ' .. duration, 0)
    end
    assert(K.contains(err, reason), ('Refusal is "%s", expected it to contain "%s"'):format(tostring(err), reason))
end)

K.step('raising a dispatch call from a non-table payload should be refused with {string}', 'server', function(_, reason)
    local id, err = K.export(RESOURCE, 'createCall', 'FFT not a payload')
    if id then
        pcall(function() exports.kora_dispatch:closeCall(id, 'fft cleanup') end)
        error('createCall accepted a string payload', 0)
    end
    assert(K.contains(err, reason), ('Refusal is "%s", expected it to contain "%s"'):format(tostring(err), reason))
end)

-- updateCall (server/store.lua:174-211).
K.step('the dispatch call {string} is patched with:', 'server', function(ctx, label, argument)
    local ok, err = K.export(RESOURCE, 'updateCall', callId(ctx, label), K.json(argument))
    if not ok then error('updateCall refused: ' .. tostring(err), 0) end
end)

K.step('patching the dispatch call {string} should be refused with {string}:', 'server', function(ctx, label, reason, argument)
    local ok, err = K.export(RESOURCE, 'updateCall', callId(ctx, label), K.json(argument))
    assert(not ok, 'updateCall accepted the patch')
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('patching the dispatch call {string} with a non-table patch should be refused with {string}', 'server', function(ctx, label, reason)
    local ok, err = K.export(RESOURCE, 'updateCall', callId(ctx, label), 'FFT not a patch')
    assert(not ok, 'updateCall accepted a string patch')
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('patching an unknown dispatch call should be refused with {string}', 'server', function(_, reason)
    local ok, err = K.export(RESOURCE, 'updateCall', -1, { title = 'FFT unknown call' })
    assert(not ok, 'updateCall accepted an unknown call')
    assert(err == reason, ('Refusal is "%s", expected "%s"'):format(tostring(err), reason))
end)

-- A duration patch re-bases expiresAt on createdAt (server/store.lua:206-207),
-- so a 1 ms duration expires the call at once without closing it.
K.step('the dispatch call {string} is made to expire', 'server', function(ctx, label)
    local ok, err = K.export(RESOURCE, 'updateCall', callId(ctx, label), { duration = 1 })
    if not ok then error('updateCall refused: ' .. tostring(err), 0) end
end)

K.step('the dispatch call {string} is revived', 'server', function(ctx, label)
    local ok, err = K.export(RESOURCE, 'updateCall', callId(ctx, label), { duration = CALL_LIFETIME })
    if not ok then error('updateCall refused: ' .. tostring(err), 0) end
end)

-- Expired is not closed (shared/calls.lua:145-148): still stored, closedAt nil,
-- missing from activeOnly.
K.step('the dispatch call {string} should have expired without being closed', 'server', function(ctx, label)
    local call = wireCall(ctx, label)
    ctx:equal(call.closedAt, nil, 'Call closedAt')
    assert(GetGameTimer() >= call.expiresAt, 'Call has not reached its expiry')
    assert(not isActive(ctx, label, call.service), 'An expired call is still listed as active')
end)

K.step('the dispatch call {string} should be listed as active', 'server', function(ctx, label)
    local call = wireCall(ctx, label)
    assert(isActive(ctx, label, call.service), 'The call is not listed as active')
end)

-- closeCall is idempotent: the first close wins (server/store.lua:216-225).
K.step('closing the dispatch call {string} again with the reason {string} should change nothing', 'server', function(ctx, label, reason)
    local before = wireCall(ctx, label)
    assert(before.closedAt, 'The call is not closed yet')
    Wait(50)
    local ok, err = K.export(RESOURCE, 'closeCall', callId(ctx, label), reason)
    assert(ok == true, 'A repeated close was refused: ' .. tostring(err))
    local after = wireCall(ctx, label)
    ctx:equal(after.closedAt, before.closedAt, 'Call closedAt')
    ctx:equal(after.closeReason, before.closeReason, 'Close reason')
end)

K.step('the dispatch call {string} is closed with a non-text reason', 'server', function(ctx, label)
    local ok, err = K.export(RESOURCE, 'closeCall', callId(ctx, label), 42)
    if not ok then error('closeCall refused: ' .. tostring(err), 0) end
end)

K.step('closing an unknown dispatch call should be refused with {string}', 'server', function(_, reason)
    local ok, err = K.export(RESOURCE, 'closeCall', -1, 'fft')
    assert(not ok, 'closeCall accepted an unknown call')
    assert(err == reason, ('Refusal is "%s", expected "%s"'):format(tostring(err), reason))
end)

-- getCalls lists each service newest first (server/store.lua:129-153).
local function listIndex(calls, id)
    for index, call in ipairs(calls or {}) do if call.id == id then return index end end
end

K.step('the dispatch call {string} should be listed before {string}', 'server', function(ctx, newer, older)
    local service = wireCall(ctx, newer).service
    local calls = K.export(RESOURCE, 'getCalls', { service = service })
    local a, b = listIndex(calls, callId(ctx, newer)), listIndex(calls, callId(ctx, older))
    assert(a and b, 'Both calls must be listed for the service ' .. service)
    assert(a < b, ('"%s" is listed at %d, after "%s" at %d'):format(newer, a, older, b))
end)

K.step('the dispatch calls for the job {string} should include {string}', 'server', function(ctx, job, label)
    assert(listIndex(K.export(RESOURCE, 'getCalls', { job = job }), callId(ctx, label)), 'The job filter does not list ' .. label)
end)

K.step('the dispatch calls for the job {string} should not include {string}', 'server', function(ctx, job, label)
    assert(not listIndex(K.export(RESOURCE, 'getCalls', { job = job }), callId(ctx, label)), 'The job filter lists ' .. label)
end)

-- getOnDutyUnits { job } (server/api.lua:246-249).
local function onJobRoster(ctx, job)
    for _, unit in ipairs(K.export(RESOURCE, 'getOnDutyUnits', { job = job }) or {}) do
        if unit.src == ctx.tester then return unit end
    end
end
K.step('the dispatch roster for the job {string} should include me', 'server', function(ctx, job)
    ctx:waitUntil(function() return onJobRoster(ctx, job) end, 'I am not on the ' .. job .. ' roster', 3000)
end)
K.step('the dispatch roster for the job {string} should not include me', 'server', function(ctx, job)
    ctx:waitUntil(function() return not onJobRoster(ctx, job) end, 'I am still on the ' .. job .. ' roster', 3000)
end)

-- setUnitState edges (server/api.lua:174-241, server/store.lua:233-262).
K.step('responding {string} to the dispatch call {string} should be refused with {string}', 'server', function(ctx, state, label, reason)
    local result, err = K.export(RESOURCE, 'setUnitState', ctx.tester, callId(ctx, label), state)
    assert(result == false, 'setUnitState accepted ' .. state .. ': ' .. tostring(result))
    ctx:equal(err, reason, 'Refusal reason')
end)

-- nextState('clear') is nil, which detaches (shared/calls.lua:188-194): false, no error.
K.step('advancing my response to the dispatch call {string} should detach me', 'server', function(ctx, label)
    local result, err = K.export(RESOURCE, 'setUnitState', ctx.tester, callId(ctx, label))
    assert(result == false and err == nil, ('Advancing past clear answered %s, %s'):format(tostring(result), tostring(err)))
end)

-- Dispatch.store.get takes tonumber(id) (server/store.lua:121-123).
K.step('I respond to the dispatch call {string} as {string} by its text id', 'server', function(ctx, label, state)
    local result, err = K.export(RESOURCE, 'setUnitState', ctx.tester, tostring(callId(ctx, label)), state)
    if result ~= state then error(('setUnitState refused %s: %s'):format(state, tostring(err)), 0) end
end)

K.step('responding to a dispatch call with the id {string} should be refused with {string}', 'server', function(ctx, id, reason)
    local result, err = K.export(RESOURCE, 'setUnitState', ctx.tester, id, 'en_route')
    assert(result == false, 'setUnitState accepted the id ' .. id)
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('I start my dispatch shift', 'server', function(ctx)
    local ok, err = exports.kora_core:setJobDuty(ctx.tester, true)
    if not ok then error('Could not go on duty: ' .. tostring(err), 0) end
end)

-- onAccept (server/api.lua:230-236; docs/index.md "The onAccept hook"). The
-- event name is chosen here; only this scenario listens to it.
K.step('I listen for the dispatch acceptance event {string}', 'server', function(ctx, event)
    assert(event:sub(1, 4) == 'fft:', 'Use an fft: event name')
    local tester = ctx.tester
    K.capture(ctx, event, function(src) return src == tester end)
end)

K.step('a dispatch call titled {string} is raised for the job {string} announcing acceptance on {string}', 'server', function(ctx, title, job, event)
    assert(event:sub(1, 4) == 'fft:', 'Use an fft: event name')
    raise(ctx, title, { jobs = { job }, title = title, message = 'Automated functional test call. No action needed.',
        priority = CALL_PRIORITY, duration = CALL_LIFETIME, onAccept = event, data = { fftRef = title } })
end)

K.step('the acceptance event {string} should have fired once for the dispatch call {string}', 'server', function(ctx, event, label)
    local id = callId(ctx, label)
    ctx:waitUntil(function() return #K.captured(ctx, event) >= 1 end, 'The acceptance event did not fire', 3000)
    Wait(250)
    local records = K.captured(ctx, event)
    ctx:equal(#records, 1, 'Acceptance event firings')
    local src, firedId, data = table.unpack(records[1])
    ctx:equal(src, ctx.tester, 'Accepting unit')
    ctx:equal(firedId, id, 'Accepted call id')
    ctx:equal(type(data) == 'table' and data.fftRef or nil, label, 'Accepted call data')
end)

K.step('the acceptance event {string} should not have fired', 'server', function(ctx, event)
    Wait(500)
    ctx:equal(#K.captured(ctx, event), 0, 'Acceptance event firings')
end)

-- ---------------------------------------------------------------------------
-- Server: player alerts (server/ingress.lua). fft is a trusted caller under the
-- seam, so it may own alert keys. A registration cannot be removed through the
-- API; re-registering the same key by the same owner replaces it
-- (ingress.lua:101-116) and kora_dispatch drops fft's keys when fft stops
-- (ingress.lua:22, docs/index.md registerPlayerAlert). Only the fixed keys below
-- are ever registered, so the registry stays bounded.
-- ---------------------------------------------------------------------------

local PLAYER_ALERTS = { ['fft:recovery-alert'] = true, ['fft:recovery-units-only'] = true }
local ALERT_COOLDOWN = 1000 -- Config.ingress.minimumCooldown

local function registerAlert(key, job, requiredJobType)
    assert(PLAYER_ALERTS[key], 'Only the fixed fft player alert keys may be registered: ' .. key)
    local ok, err = K.export(RESOURCE, 'registerPlayerAlert', key, {
        jobs = { job },
        title = 'FFT player alert ' .. key,
        message = 'Automated functional test call. No action needed.',
        priority = CALL_PRIORITY,
        duration = CALL_LIFETIME,
        cooldown = ALERT_COOLDOWN,
        -- Must never reach a unit (ingress.lua:50-53).
        onAccept = 'fft:dispatch:player-alert-accepted',
        -- Only primitive values survive (ingress.lua:60-69).
        data = { fftNote = 'kept', fftNested = { dropped = true } },
        requiredJobType = requiredJobType,
    })
    if not ok then error('registerPlayerAlert refused (is the fft seam active?): ' .. tostring(err), 0) end
end

K.step('the player alert {string} is registered for the job {string}', 'server', function(_, key, job)
    registerAlert(key, job, nil)
end)

K.step('the player alert {string} is registered for the job {string} for on-duty {string} units only', 'server', function(_, key, job, jobType)
    registerAlert(key, job, jobType)
end)

-- Doc string: the definition as JSON. The key must be invalid or the definition
-- must be refused, so nothing is registered.
K.step('registering the player alert {string} should be refused with {string}:', 'server', function(_, key, reason, argument)
    local ok, err = K.export(RESOURCE, 'registerPlayerAlert', key, K.json(argument))
    assert(not ok, 'registerPlayerAlert accepted ' .. key)
    assert(K.contains(err, reason), ('Refusal is "%s", expected it to contain "%s"'):format(tostring(err), reason))
end)

K.step('registering the player alert {string} without a definition should be refused with {string}', 'server', function(_, key, reason)
    local ok, err = K.export(RESOURCE, 'registerPlayerAlert', key, 'FFT not a definition')
    assert(not ok, 'registerPlayerAlert accepted ' .. key)
    assert(K.contains(err, reason), ('Refusal is "%s", expected it to contain "%s"'):format(tostring(err), reason))
end)

-- A previous scenario may have raised the same key less than a cooldown ago;
-- a cooling-down refusal consumes nothing (ingress.lua:154-160), so wait it out.
K.step('I raise the player alert {string}', 'server', function(ctx, key)
    local id, result
    ctx:waitUntil(function()
        id, result = K.export(RESOURCE, 'createPlayerCall', ctx.tester, key)
        if type(id) == 'number' then return true end
        if result == 'player alert is cooling down' then return false end
        error('createPlayerCall refused: ' .. tostring(result), 0)
    end, 'The player alert stayed on cooldown', ALERT_COOLDOWN + 3000)
    closeLater(ctx, id)
    remember(ctx, key, id)
end)

K.step('raising the player alert {string} should be refused with {string}', 'server', function(ctx, key, reason)
    local id, err = K.export(RESOURCE, 'createPlayerCall', ctx.tester, key)
    if type(id) == 'number' then
        pcall(function() exports.kora_dispatch:closeCall(id, 'fft cleanup') end)
        error('createPlayerCall raised call #' .. id, 0)
    end
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('raising the player alert {string} again should be refused while it cools down', 'server', function(ctx, key)
    local id, err, remaining = K.export(RESOURCE, 'createPlayerCall', ctx.tester, key)
    if type(id) == 'number' then
        pcall(function() exports.kora_dispatch:closeCall(id, 'fft cleanup') end)
        error('createPlayerCall raised call #' .. id .. ' during its cooldown', 0)
    end
    ctx:equal(err, 'player alert is cooling down', 'Refusal reason')
    assert(type(remaining) == 'number' and remaining > 0 and remaining <= ALERT_COOLDOWN,
        'Remaining cooldown is ' .. tostring(remaining))
end)

K.step('raising the player alert {string} for an invalid reporter should be refused with {string}', 'server', function(ctx, key, reason)
    local id, err = K.export(RESOURCE, 'createPlayerCall', 0, key)
    assert(id == false, 'createPlayerCall accepted reporter 0')
    ctx:equal(err, reason, 'Refusal reason')
end)

-- Coordinates come from the reporter's networked ped (ingress.lua:121-125).
K.step('the dispatch call {string} should be located at my position', 'server', function(ctx, label)
    local coords = wireCall(ctx, label).coords
    assert(type(coords) == 'table', 'Call has no coordinates')
    local at = GetEntityCoords(GetPlayerPed(ctx.tester))
    local distance = #(vector3(coords.x, coords.y, coords.z) - at)
    assert(distance < 10.0, ('Call is %.1f m from me'):format(distance))
end)

K.step('the dispatch call {string} should name me as its reporter', 'server', function(ctx, label)
    local data = wireCall(ctx, label).data
    assert(type(data) == 'table', 'Call carries no data')
    ctx:equal(data.reporter, ctx.tester, 'Call reporter')
    ctx:equal(data.incident, label, 'Call incident key')
end)

-- ---------------------------------------------------------------------------
-- Client: feed keys, routes, presentation exports and tablet details
-- ---------------------------------------------------------------------------

local FEED_KEYS = { next = true, previous = true, respond = true, toggle = true }

-- client/keybinds.lua: Kora.keybind.add registers +kora_dispatch_<name>.
local function pressKey(name)
    ExecuteCommand('+kora_dispatch_' .. name)
    Wait(100)
    ExecuteCommand('-kora_dispatch_' .. name)
end

-- Newest feed payload since the scenario began: a table, false (tablet open or
-- no service), or nil when nothing was sent yet.
local function latestFeed(ctx)
    local entries = K.ui('log', ctx.state.uiBaseline or 0) or {}
    for index = #entries, 1, -1 do
        if entries[index].action == 'kora_dispatch:feed' then return entries[index].data end
    end
end

K.step('I press the dispatch {string} key', 'client', function(_, name)
    K.started(RESOURCE)
    assert(FEED_KEYS[name], 'Unknown dispatch key: ' .. name)
    pressKey(name)
end)

-- moveSelection(-1) walks towards newer calls and clamps at the newest
-- (client/state.lua moveSelection), so pressing "previous" until the feed's
-- selection is its first (newest) call lands on the newest call.
K.step('I select the newest dispatch call with the feed keys', 'client', function(ctx)
    K.started(RESOURCE)
    ctx:waitUntil(function()
        pressKey('previous')
        Wait(150)
        local feed = latestFeed(ctx)
        local first = type(feed) == 'table' and type(feed.calls) == 'table' and feed.calls[1]
        return type(first) == 'table' and feed.selected == first.id
    end, 'The feed keys did not select the newest call', 12000)
end)

K.step('the dispatch feed should have the call {string} selected', 'client', function(ctx, title)
    local id = ctx:waitUntil(function() local call = feedCall(ctx, title) return call and call.id end,
        'The dispatch feed does not show "' .. title .. '"', 8000)
    ctx:waitUntil(function()
        local feed = latestFeed(ctx)
        return type(feed) == 'table' and feed.selected == id
    end, 'The dispatch feed does not have "' .. title .. '" selected', 5000, function()
        local feed = latestFeed(ctx)
        return ': selected is ' .. tostring(type(feed) == 'table' and feed.selected or feed)
    end)
end)

-- Shows the feed through exports.kora_dispatch:setUiOptions (client/exports.lua:24-37)
-- and restores the player's own hidden preference afterwards. Run it after the
-- dispatch service is known, so a feed payload has been rendered.
K.step('my dispatch feed is shown', 'client', function(ctx)
    K.started(RESOURCE)
    local feed = ctx:waitUntil(function()
        local value = latestFeed(ctx)
        if type(value) == 'table' then return value end
        -- Nothing rendered since the scenario began: setUiOptions renders now.
        exports.kora_dispatch:setUiOptions({})
        return false
    end, 'No dispatch feed was rendered since the scenario began', 8000)
    local original = feed.hidden == true
    ctx:cleanup(function() pcall(function() exports.kora_dispatch:setUiOptions({ hidden = original }) end) end)
    assert((exports.kora_dispatch:setUiOptions({ hidden = false })) == true, 'setUiOptions refused { hidden = false }')
end)

K.step('the dispatch feed should be hidden', 'client', function(ctx)
    ctx:waitUntil(function()
        local feed = latestFeed(ctx)
        return type(feed) == 'table' and feed.hidden == true
    end, 'The dispatch feed is not hidden', 5000)
end)

K.step('the dispatch feed should be shown', 'client', function(ctx)
    ctx:waitUntil(function()
        local feed = latestFeed(ctx)
        return type(feed) == 'table' and feed.hidden ~= true
    end, 'The dispatch feed is not shown', 5000)
end)

-- render() sends `false` while the tablet is open or without a service (client/ui.lua:182-198).
K.step('the dispatch feed should be cleared', 'client', function(ctx)
    ctx:waitUntil(function() return latestFeed(ctx) == false end, 'The dispatch feed was not cleared', 5000)
end)

-- exports.kora_dispatch:getRoutedCall (client/exports.lua:55-57, client/blip.lua route/callId).
K.step('my dispatch route should lead to the call {string}', 'client', function(ctx, title)
    local id = ctx.state.dispatchFeedIds and ctx.state.dispatchFeedIds[title]
    assert(id, 'Observe the call on the dispatch feed first')
    local seen
    ctx:waitUntil(function()
        seen = (exports.kora_dispatch:getRoutedCall())
        return seen == id
    end, 'No route to "' .. title .. '"', 5000, function() return ': routed call is ' .. tostring(seen) end)
end)

K.step('I should have no dispatch route', 'client', function(ctx)
    local seen
    ctx:waitUntil(function()
        seen = (exports.kora_dispatch:getRoutedCall())
        return seen == nil
    end, 'A dispatch route is still set', 5000, function() return ': routed call is ' .. tostring(seen) end)
end)

-- client/theme.lua:35-38 refuses before changing anything.
K.step('setting the dispatch theme to {string} should be refused with {string}', 'client', function(_, hex, reason)
    K.started(RESOURCE)
    local ok, err = exports.kora_dispatch:setTheme(hex)
    assert(ok == false, 'setTheme accepted ' .. hex)
    assert(K.contains(err, reason), ('Refusal is "%s", expected it to contain "%s"'):format(tostring(err), reason))
end)

K.step('setting the dispatch UI options to a non-table should be refused', 'client', function()
    K.started(RESOURCE)
    assert((exports.kora_dispatch:setUiOptions('FFT not options')) == false, 'setUiOptions accepted a string')
end)

-- The tablet's dispatch:route action (client/ui.lua:169-171).
K.step('I route to the selected dispatch call on the tablet', 'client', function()
    K.must(K.ui('app.action', 'dispatch:route'))
end)

-- The app handler raises when the server refuses (client/ui.lua:175-176), which
-- kora_lib answers as a failed action.
K.step('responding {string} to the selected dispatch call on the tablet should fail', 'client', function(_, state)
    local ok = K.ui('app.action', 'dispatch:respond:' .. state)
    assert(not ok, 'The tablet accepted the response ' .. state)
end)
