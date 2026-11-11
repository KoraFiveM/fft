-- kora_queue: connection queue. Read-only assertions through the functions that
-- exports.kora_queue:GetQueueExports() hands to other resources. Nothing here
-- kicks, re-queues or changes priority. No resource hook.
local K = FFT.kora
if not K then return end
K.feature('kora_queue')

-- The queue functions are declared with a colon but only use their own upvalue,
-- so an empty table stands in for `self` when they are called across resources.
local function queue(name, ...)
    local api = K.export('kora_queue', 'GetQueueExports')
    assert(type(api) == 'table', 'GetQueueExports did not return the queue table')
    if name == nil then return api end
    local fn = api[name]
    if fn == nil then error('The queue does not expose ' .. name, 0) end
    local results = table.pack(pcall(fn, {}, ...))
    if not results[1] then error(('Queue %s failed: %s'):format(name, tostring(results[2])), 0) end
    return table.unpack(results, 2, results.n)
end

local function count(name)
    local value = queue(name)
    assert(type(value) == 'number' and value >= 0 and value == math.floor(value),
        ('Queue %s returned %s, expected a non-negative whole number'):format(name, tostring(value)))
    return value
end

K.step('the connection queue should list me as a joined player', 'server', function(ctx)
    local list = queue('GetPlayerList')
    assert(type(list) == 'table', 'GetPlayerList did not return a table')
    assert(list[ctx.tester] == true or list[tostring(ctx.tester)] == true,
        'The queue player list does not contain the tester (source ' .. tostring(ctx.tester) .. ')')
end)

K.step('the connection queue should count at least {int} joined players', 'server', function(_, minimum)
    local joined = count('GetPlayerCount')
    assert(joined >= minimum, ('Queue counts %d joined players, expected at least %d'):format(joined, minimum))
end)

K.step('the connection queue should count no more joined players than the server slot limit', 'server', function()
    local limit = queue().MaxPlayers
    assert(type(limit) == 'number', 'Queue.MaxPlayers is not a number')
    assert(limit == GetConvarInt('sv_maxclients', 30),
        ('Queue.MaxPlayers is %s but sv_maxclients is %d'):format(tostring(limit), GetConvarInt('sv_maxclients', 30)))
    local joined = count('GetPlayerCount')
    assert(joined <= limit, ('Queue counts %d joined players for %d slots'):format(joined, limit))
end)

K.step('the connection queue should report whole-number waiting and connecting sizes', 'server', function()
    count('GetSize')
    count('ConnectingSize')
end)

K.step('I should not be waiting in the connection queue', 'server', function(ctx)
    ctx:equal(queue('IsInQueue', ctx.tester, false, true, false), false, 'Tester waiting in the queue')
end)

K.step('I should not be in the connecting list of the connection queue', 'server', function(ctx)
    -- The third argument (refresh) is left out on purpose: it would reset a timeout.
    ctx:equal(queue('IsInConnecting', ctx.tester, true), false, 'Tester in the connecting list')
end)

K.step('the connection queue should know my identifiers', 'server', function(ctx)
    local ids = queue('GetIds', ctx.tester)
    assert(type(ids) == 'table' and #ids > 0, 'GetIds returned no identifiers for the tester')
    for _, id in ipairs(ids) do
        assert(type(id) == 'string' and id:find(':', 1, true), 'Malformed identifier: ' .. tostring(id))
    end
end)

K.step('the connection queue should answer my priority as a power or none', 'server', function(ctx)
    local ids = queue('GetIds', ctx.tester)
    assert(type(ids) == 'table' and #ids > 0, 'GetIds returned no identifiers for the tester')
    local priority = queue('IsPriority', ids)
    assert(priority == false or type(priority) == 'number',
        'IsPriority returned ' .. tostring(priority) .. ', expected false or a number')
end)

K.step('the connection queue fullness should match its own counts', 'server', function()
    local expected = count('GetPlayerCount') + count('ConnectingSize') < queue().MaxPlayers
    assert(queue('NotFull') == expected, 'NotFull disagrees with player count, connecting size and slot limit')
end)

K.step('the hard cap resource should not be running beside the connection queue', 'server', function()
    local state = GetResourceState('hardcap')
    assert(state ~= 'started' and state ~= 'starting', 'hardcap is ' .. state .. ' although the queue disables it')
end)

-- ---------------------------------------------------------------------------
-- Round 3: queue, connecting and priority bookkeeping driven with fake entries.
-- These mirror the resource's own rcon debug commands (addq, removeq, addc,
-- removec, setpos in kora_queue/shared/sh_queue.lua) through the same exported
-- functions. Every fake id starts with "fft:" so it can never match a real
-- player, fake queue entries use the source "fft" (the source "debug" would get
-- a random priority, sh_queue.lua AddToQueue), and every addition registers its
-- removal at once. Scenarios using these steps change server-wide queue state
-- and are tagged @global. OnJoin, CanJoin, UpdatePosData and the
-- Queue:playerActivated event are never driven: they cannot be undone or they
-- run other resources' join callbacks.
-- ---------------------------------------------------------------------------

local function fakeId(id)
    assert(type(id) == 'string' and id:match('^fft:[%w%-_]+$') and #id <= 64,
        'Test queue ids must look like fft:<name>, got ' .. tostring(id))
    return id
end

local function forgetEntry(id)
    -- Cleanup-safe: RemoveFromQueue and RemoveFromConnecting ignore ids that are not listed.
    pcall(function()
        local api = exports.kora_queue:GetQueueExports()
        api.RemoveFromQueue({}, { id })
        api.RemoveFromConnecting({}, { id })
    end)
end

local function forgetPriority(id)
    pcall(function() exports.kora_queue:GetQueueExports().RemovePriority({}, id) end)
end

local function position(id)
    local pos = queue('IsInQueue', { id }, true)
    return pos ~= false and pos or nil
end

K.step('the connection queue has no waiting or connecting players', 'server', function()
    local waiting, connecting = count('GetSize'), count('ConnectingSize')
    assert(waiting == 0 and connecting == 0,
        ('The queue is in use (%d waiting, %d connecting); these scenarios need it idle'):format(waiting, connecting))
end)

K.step('a test entry {string} waits in the connection queue', 'server', function(ctx, id)
    fakeId(id)
    ctx:cleanup(function() forgetEntry(id) end)
    queue('AddToQueue', { id }, os.time(), 'FFT ' .. id, 'fft')
    assert(position(id), 'AddToQueue did not list ' .. id)
end)

K.step('adding the test entry {string} to the connection queue again should change nothing', 'server', function(ctx, id)
    fakeId(id)
    local before, pos = count('GetSize'), position(id)
    assert(pos, id .. ' is not waiting in the queue')
    queue('AddToQueue', { id }, os.time(), 'FFT ' .. id .. ' again', 'fft')
    ctx:equal(count('GetSize'), before, 'Queue size after a duplicate add')
    ctx:equal(position(id), pos, 'Position of ' .. id)
end)

K.step('the connection queue should hold {int} waiting players', 'server', function(ctx, expected)
    ctx:equal(count('GetSize'), expected, 'Queue size')
end)
K.step('the connection queue should count {int} connecting players', 'server', function(ctx, expected)
    ctx:equal(count('ConnectingSize'), expected, 'Connecting size')
end)

K.step('the test entry {string} should be number {int} in the connection queue', 'server', function(ctx, id, expected)
    ctx:equal(position(id), expected, 'Queue position of ' .. id)
    local list = queue('GetQueueList')
    assert(type(list) == 'table' and list[expected] and list[expected].ids and list[expected].ids[1] == id,
        'GetQueueList does not hold ' .. id .. ' at position ' .. expected)
end)
K.step('the test entry {string} should not be in the connection queue', 'server', function(ctx, id)
    ctx:equal(queue('IsInQueue', { id }), false, id .. ' waiting in the queue')
end)

K.step('I remove the test entry {string} from the connection queue', 'server', function(_, id)
    queue('RemoveFromQueue', { fakeId(id) })
end)
K.step('I remove queue position {int} from the connection queue', 'server', function(_, index)
    local entry = (queue('GetQueueList') or {})[index]
    assert(entry and entry.ids and type(entry.ids[1]) == 'string' and entry.ids[1]:sub(1, 4) == 'fft:',
        'Queue position ' .. index .. ' is not a test entry; refusing to remove it')
    queue('RemoveFromQueue', nil, nil, index)
end)

K.step('I move the test entry {string} to position {int} in the connection queue', 'server', function(_, id, newPos)
    assert(position(fakeId(id)), id .. ' is not waiting in the queue')
    -- SetPos answers false when refused and nothing (nil) when it moved the entry.
    local result = queue('SetPos', { id }, newPos)
    assert(result ~= false, 'SetPos refused to move ' .. id .. ' to ' .. newPos)
end)
K.step('moving the test entry {string} to position {int} should be refused', 'server', function(ctx, id, newPos)
    local before = position(fakeId(id))
    ctx:equal(queue('SetPos', { id }, newPos), false, 'SetPos result')
    ctx:equal(position(id), before, 'Position of ' .. id)
end)

-- Priority ------------------------------------------------------------------

K.step('the test entry {string} has queue priority {int}', 'server', function(ctx, id, power)
    fakeId(id)
    ctx:cleanup(function() forgetPriority(id) end)
    ctx:equal(queue('AddPriority', id, power), true, 'AddPriority result')
end)
-- Uppercase is fine here: the single-id form lowercases (sh_queue.lua AddPriority).
K.step('the queue id {string} is given priority {int}', 'server', function(ctx, id, power)
    assert(id:lower():match('^fft:'), 'Only fft: ids may be given priority')
    ctx:cleanup(function() forgetPriority(id) end)
    ctx:equal(queue('AddPriority', id, power), true, 'AddPriority result')
end)
K.step('the test entry {string} is given the non-numeric queue priority {string}', 'server', function(ctx, id, power)
    fakeId(id)
    ctx:cleanup(function() forgetPriority(id) end)
    ctx:equal(queue('AddPriority', id, power), true, 'AddPriority result')
end)
-- A temporary priority cannot be deleted through the exports, so cleanup gives
-- it a zero-second lifetime and the queue's own one-second sweep drops it.
K.step('the test entry {string} has temporary queue priority {int} for {int} seconds', 'server', function(ctx, id, power, seconds)
    fakeId(id)
    assert(seconds > 0 and seconds <= 300, 'Use a temporary priority of 1-300 seconds')
    ctx:cleanup(function()
        pcall(function() exports.kora_queue:GetQueueExports().AddPriority({}, id, 1, 0) end)
    end)
    ctx:equal(queue('AddPriority', id, power, seconds), true, 'AddPriority result')
end)
K.step('the test entries get queue priority through a table:', 'server', function(ctx, argument)
    local rows = K.json(argument)
    assert(type(rows) == 'table' and next(rows), 'Give a JSON object of id: power')
    for id in pairs(rows) do
        -- Only lowercase ids: the table form stores ids as given and RemovePriority
        -- lowercases, so an uppercase id here could never be cleaned up.
        assert(fakeId(id) == id:lower(), 'Table-form test ids must be lowercase: ' .. id)
        ctx:cleanup(function() forgetPriority(id) end)
    end
    ctx:equal(queue('AddPriority', rows), true, 'AddPriority result')
end)
K.step('giving queue priority through a table with the power {string} for {string} should be refused', 'server', function(ctx, power, id)
    fakeId(id)
    ctx:cleanup(function() forgetPriority(id) end)
    -- shared/sh_queue.lua AddPriority prints this refusal through DebugPrint.
    K.expectConsoleError(ctx, 'Error adding a priority id, invalid data passed', 'kora_queue')
    ctx:equal(queue('AddPriority', { [id] = power }), false, 'AddPriority result')
    ctx:equal(queue('GetPriorityList')[id], nil, 'Stored priority for ' .. id)
end)
K.step('giving queue priority to no id should be refused', 'server', function(ctx)
    ctx:equal(queue('AddPriority', nil, 50), false, 'AddPriority(nil) result')
end)
K.step('removing queue priority from no id should be refused', 'server', function(ctx)
    ctx:equal(queue('RemovePriority', nil), false, 'RemovePriority(nil) result')
end)
K.step('I remove the queue priority of {string}', 'server', function(ctx, id)
    assert(id:lower():match('^fft:'), 'Only fft: ids may have their priority removed')
    ctx:equal(queue('RemovePriority', id), true, 'RemovePriority result')
end)

K.step('the connection queue should give {string} the priority {int}', 'server', function(ctx, id, expected)
    ctx:equal(queue('IsPriority', { id }), expected, 'IsPriority of ' .. id)
end)
K.step('the connection queue should give {string} no priority', 'server', function(ctx, id)
    ctx:equal(queue('IsPriority', { id }), false, 'IsPriority of ' .. id)
end)
K.step('the connection queue priority list should hold {string} at {int}', 'server', function(ctx, key, expected)
    ctx:equal(queue('GetPriorityList')[key], expected, 'Priority list entry ' .. key)
end)
K.step('the connection queue priority list should not hold {string}', 'server', function(ctx, key)
    ctx:equal(queue('GetPriorityList')[key], nil, 'Priority list entry ' .. key)
end)
K.step('the connection queue should give {string} a temporary priority of {int}', 'server', function(ctx, id, expected)
    local power, endTime = queue('HasTempPriority', { id })
    ctx:equal(power, expected, 'Temporary priority of ' .. id)
    assert(type(endTime) == 'number' and endTime > os.time(), 'Temporary priority of ' .. id .. ' has no future end time')
end)
K.step('the connection queue should count {int} waiting players with temporary priority', 'server', function(ctx, expected)
    ctx:equal(queue('TempSize'), expected, 'TempSize')
end)
K.step('the connection queue should count no waiting players with temporary priority', 'server', function(ctx)
    -- TempSize answers false, not 0, when nobody waiting has a temporary priority.
    ctx:equal(queue('TempSize'), false, 'TempSize')
end)

-- Steam ids -----------------------------------------------------------------

K.step('the connection queue should convert the steam id {string} to {string}', 'server', function(ctx, hex, legacy)
    ctx:equal(queue('HexIdToSteamId', hex), legacy, 'HexIdToSteamId of ' .. hex)
end)
-- Read-only: a legacy id is a valid identifier string and the shipped
-- Config.Priority itself contains steam_0 rows (sv_queue_config.lua).
K.step('the connection queue should answer the priority of the legacy id {string} as a power or none', 'server', function(_, id)
    local priority = queue('IsPriority', { id })
    assert(priority == false or type(priority) == 'number',
        'IsPriority returned ' .. tostring(priority) .. ', expected false or a number')
end)
K.step('the connection queue should recognise whether I run steam', 'server', function(ctx)
    local expected = false
    for _, id in ipairs(GetPlayerIdentifiers(ctx.tester)) do
        if id:sub(1, 5) == 'steam' then expected = true end
    end
    ctx:equal(queue('IsSteamRunning', ctx.tester), expected, 'IsSteamRunning')
end)
-- GetIds drops ip: identifiers that carry no priority when other ids exist.
K.step('my queue identifiers should leave out unprioritised ip addresses', 'server', function(ctx)
    local ids = queue('GetIds', ctx.tester)
    assert(type(ids) == 'table' and #ids > 0, 'GetIds returned no identifiers for the tester')
    if #ids == 1 then return end
    for _, id in ipairs(ids) do
        if id:sub(1, 3) == 'ip:' then
            assert(queue('IsPriority', { id }), 'GetIds kept the unprioritised ' .. id)
        end
    end
end)

-- Connecting list -----------------------------------------------------------

-- addc in sh_queue.lua: an entry whose first id is "debug" is listed as
-- connecting without being queued, and the timeout sweep never drops it.
K.step('a debug entry is in the connecting list', 'server', function(ctx)
    ctx:cleanup(function()
        pcall(function() exports.kora_queue:GetQueueExports().RemoveFromConnecting({}, { 'debug' }) end)
    end)
    ctx:equal(queue('AddToConnecting', { 'debug' }), true, 'AddToConnecting result')
end)
K.step('the queue id {string} should be in the connecting list', 'server', function(ctx, id)
    ctx:equal(queue('IsInConnecting', { id }), true, id .. ' in the connecting list')
end)
K.step('the queue id {string} should not be in the connecting list', 'server', function(ctx, id)
    ctx:equal(queue('IsInConnecting', { id }), false, id .. ' in the connecting list')
end)
K.step('I remove the queue id {string} from the connecting list', 'server', function(ctx, id)
    assert(id == 'debug' or fakeId(id), 'Only test ids may be removed')
    ctx:equal(queue('RemoveFromConnecting', { id }), true, 'RemoveFromConnecting result')
end)
K.step('removing the queue id {string} from the connecting list should find nothing', 'server', function(ctx, id)
    assert(id == 'debug' or fakeId(id), 'Only test ids may be removed')
    ctx:equal(queue('RemoveFromConnecting', { id }), false, 'RemoveFromConnecting result')
end)
K.step('the test entry {string} should be let through to the connecting list', 'server', function(ctx, id)
    ctx:equal(queue('AddToConnecting', { fakeId(id) }), true, 'AddToConnecting result')
end)
K.step('letting the test entry {string} through to the connecting list should be refused', 'server', function(ctx, id)
    local before = position(fakeId(id))
    ctx:equal(queue('AddToConnecting', { id }), false, 'AddToConnecting result')
    ctx:equal(position(id), before, 'Queue position of ' .. id)
    ctx:equal(queue('IsInConnecting', { id }), false, id .. ' in the connecting list')
end)

-- Fullness and display -------------------------------------------------------

K.step('the connection queue first-join fullness should match its own counts', 'server', function(ctx)
    local expected = queue('NotFull') and count('GetSize') <= 1
    ctx:equal(queue('NotFull', true), expected, 'NotFull(true)')
end)
K.step('the connection queue should not let a first join through', 'server', function(ctx)
    ctx:equal(queue('NotFull', true), false, 'NotFull(true)')
end)

K.step('the connection queue display flags should follow the server convars', 'server', function(ctx)
    local api = queue()
    ctx:equal(api.Debug, GetConvar('sv_debugqueue', 'true') == 'true', 'Queue.Debug')
    ctx:equal(api.DisplayQueue, GetConvar('sv_displayqueue', 'true') == 'true', 'Queue.DisplayQueue')
end)

-- The one-second sweep in sh_queue.lua prefixes sv_hostname with "[n] " while
-- n players wait, when DisplayQueue is on and the original host name is known.
local function hostName()
    local api = queue()
    assert(api.DisplayQueue == true, 'sv_displayqueue is off, so the queue does not show its size')
    assert(type(api.InitHostName) == 'string', 'The queue has no original host name to decorate')
    return api.InitHostName
end
K.step('the server name should show {int} waiting players', 'server', function(ctx, waiting)
    local expected = ('[%d] %s'):format(waiting, hostName())
    ctx:waitUntil(function() return GetConvar('sv_hostname', '') == expected end,
        ('sv_hostname is "%s", expected "%s"'):format(GetConvar('sv_hostname', ''), expected), 4000)
end)
K.step('the server name should not show a waiting count', 'server', function(ctx)
    local expected = hostName()
    ctx:waitUntil(function() return GetConvar('sv_hostname', '') == expected end,
        ('sv_hostname is "%s", expected "%s"'):format(GetConvar('sv_hostname', ''), expected), 4000)
end)

-- IsPriority also looks a hex steam id up in its legacy steam_0 form
-- (HexIdToSteamId, sh_queue.lua). The permanent form is used: the temporary
-- form runs HasTempPriority on the id first, which cannot parse steam_0 ids.
K.step('the legacy steam id {string} is given priority {int}', 'server', function(ctx, id, power)
    assert(id:match('^steam_0:[01]:%d+$'), 'Not a legacy steam id: ' .. id)
    assert(queue('GetPriorityList')[id] == nil, id .. ' already has a configured priority; refusing to replace it')
    ctx:cleanup(function() forgetPriority(id) end)
    ctx:equal(queue('AddPriority', id, power), true, 'AddPriority result')
end)
