-- kora_jewellery: Vangelico display cases (kora_target box zones) and the
-- server rules that guard a case (GlobalState.Jewellery).
--
-- No resource hook and no seam. GlobalState.Jewellery is the authoritative,
-- replicated state, and the display-case option is driven through kora_target
-- with the generic steps. A successful smash needs two officers on duty, raises
-- a dispatch call to them and locks the store until Config.ResetTime, so it is
-- not covered: only the refusals around it are.
local K = FFT.kora
if not K then return end
K.feature('kora_jewellery')

-- Config.VitrineRewards item names (kora_jewellery/shared/config.lua).
local LOOT = { 'rolex', 'diamond_ring', 'goldchain', 'tenkgoldchain' }

local function store()
    K.started('kora_jewellery')
    local state = GlobalState.Jewellery
    assert(type(state) == 'table' and type(state.locations) == 'table', 'GlobalState.Jewellery is not published')
    return state
end

local function case(index)
    local location = store().locations[index]
    assert(type(location) == 'table', 'Unknown jewellery display case ' .. tostring(index))
    return location
end

K.step('the jewellery store should publish {int} display cases', 'server', function(ctx, expected)
    local state = store()
    ctx:equal(type(state.firstAlarm), 'boolean', 'Alarm flag type')
    ctx:equal(#state.locations, expected, 'Display case count')
    for index, location in ipairs(state.locations) do
        assert(type(location.isOpened) == 'boolean' and type(location.isBusy) == 'boolean',
            'Display case ' .. index .. ' has no opened/busy flags')
    end
end)

-- Used as a precondition (the case must be free for the option to show) and as
-- the unchanged-state assertion after a refusal.
K.step('jewellery display case {int} should be untouched', 'server', function(ctx, index)
    Wait(500)
    local location = case(index)
    ctx:equal(location.isOpened, false, 'Display case ' .. index .. ' opened')
    ctx:equal(location.isBusy, false, 'Display case ' .. index .. ' busy')
end)

K.step('I remember the jewellery alarm state', 'server', function(ctx)
    ctx.state.jewelleryAlarm = store().firstAlarm == true
end)
K.step('the jewellery alarm state should be unchanged', 'server', function(ctx)
    assert(ctx.state.jewelleryAlarm ~= nil, 'Remember the jewellery alarm state first')
    ctx:equal(store().firstAlarm == true, ctx.state.jewelleryAlarm, 'Jewellery alarm')
end)

-- Precondition, not a fixture: Config.RequiredCops is 2.
K.step('fewer police are on duty than the jewellery store needs', 'server', function()
    local count = K.export('kora_core', 'getDutyCountByType', 'leo')
    assert(type(count) == 'number', 'Police duty count is unavailable')
    assert(count < 2, ('%d police are on duty; this scenario needs fewer than 2'):format(count))
end)

K.step('I remember my jewellery loot', 'server', function(ctx)
    local held = {}
    for _, item in ipairs(LOOT) do held[item] = K.count(ctx, item) end
    ctx.state.jewelleryLoot = held
end)
K.step('I should have gained no jewellery loot', 'server', function(ctx)
    local held = assert(ctx.state.jewelleryLoot, 'Remember the jewellery loot first')
    Wait(1000)
    for _, item in ipairs(LOOT) do ctx:equal(K.count(ctx, item), held[item], 'Held ' .. item) end
end)

-- Holstering is the same thing the weapon wheel does; no weapon is given or removed.
K.step('I hold no weapon at the jewellery store', 'client', function(ctx)
    local unarmed = GetHashKey('WEAPON_UNARMED')
    SetCurrentPedWeapon(PlayerPedId(), unarmed, true)
    ctx:waitUntil(function() return GetSelectedPedWeapon(PlayerPedId()) == unarmed end, 'Could not holster the weapon', 2000)
end)

-- The events client/client.lua sends during a smash, sent here without the
-- server-side claim (startSmash) that a real smash obtains first.
K.step('I claim the jewellery reward for display case {int} without smashing it', 'client', function(_, index)
    TriggerServerEvent('qb-jewellery:server:vitrineReward', index)
end)
K.step('I try to reserve jewellery display case {int} without enough police', 'client', function(ctx, index)
    -- Releases the case again should the reservation unexpectedly be accepted.
    ctx:cleanup(function() TriggerServerEvent('qb-jewellery:server:setVitrineState', index, false) end)
    TriggerServerEvent('qb-jewellery:server:setVitrineState', index, true)
end)

-- ---------------------------------------------------------------------------
-- Display-case layout and the server rules around a case. Everything below
-- sends the same events/callback client/client.lua uses; the server checks in
-- kora_jewellery/server/server.lua decide, and GlobalState.Jewellery (plus the
-- inventory) is what the scenarios assert.
-- ---------------------------------------------------------------------------

local function near(value, expected) return type(value) == 'number' and math.abs(value - expected) < 0.05 end

-- Config.Locations[n].coords and .offset (shared/config.lua), as published.
K.step('jewellery display case {int} should be published at {float} {float} {float} with its stand point at {float} {float} {float} facing {float}',
    'server', function(_, index, x, y, z, ox, oy, oz, heading)
        local location = case(index)
        local c, o = location.coords, location.offset
        assert(c and near(c.x, x) and near(c.y, y) and near(c.z, z),
            ('Display case %d is at %s, expected %.2f %.2f %.2f'):format(index, tostring(c), x, y, z))
        assert(o and near(o.x, ox) and near(o.y, oy) and near(o.z, oz) and near(o.w, heading),
            ('Display case %d stand point is %s'):format(index, tostring(o)))
    end)

-- server.lua setVitrineState: `type(bool) ~= 'boolean'` is refused.
K.step('I send jewellery display case {int} the reservation flag {string}', 'client', function(_, index, flag)
    TriggerServerEvent('qb-jewellery:server:setVitrineState', index, flag)
end)
-- server.lua setVitrineState: a string index finds no Config.Locations row.
K.step('I try to reserve the jewellery display case keyed {string}', 'client', function(_, key)
    TriggerServerEvent('qb-jewellery:server:setVitrineState', key, true)
end)
-- server.lua setVitrineState(k, false): only the player in busyBy[k] may release.
K.step('I release jewellery display case {int} without having reserved it', 'client', function(_, index)
    TriggerServerEvent('qb-jewellery:server:setVitrineState', index, false)
end)
-- server.lua vitrineReward: replayed claims (the `claiming` lock guards double payouts).
K.step('I claim the jewellery reward for display case {int} {int} times without smashing it', 'client', function(_, index, times)
    assert(times >= 1 and times <= 10, 'Send 1-10 claims')
    for _ = 1, times do TriggerServerEvent('qb-jewellery:server:vitrineReward', index) end
end)
-- server.lua firstAlarm: what client.lua sends when the first case is hit.
-- Only used near a case together with the "fewer police" precondition, or for
-- an unknown/far case, so no dispatch call can be raised.
K.step('I raise the jewellery alarm from display case {int}', 'client', function(_, index)
    TriggerServerEvent('qb-jewellery:server:firstAlarm', index)
end)

-- The real claim callback client.lua calls before the progress bar
-- (Kora.callback.trigger('qb-jewellery:server:startSmash', k)). Should the server
-- unexpectedly grant it, the cleanup releases the case the same way a
-- cancelled smash does.
-- kora_lib callback_triggerPacked keeps every value (a `nil, reason` refusal
-- included) and turns a raised handler error or rate-limit rejection into
-- { __kora_lib_rejected = true, error } (local/callback/shared.lua
-- KoraLibCallbackEnvelope). Normalised to table.pack(pcall(...)) shape:
-- { true, values... } or { false, message }.
local function packedCall(name, ...)
    local args = table.pack(...)
    local ok, packed = pcall(function()
        return exports.kora_lib:callback_triggerPacked(name, table.unpack(args, 1, args.n))
    end)
    if not ok then return { n = 2, false, tostring(packed) } end
    if type(packed) ~= 'table' then return { n = 2, true, packed } end
    if packed.__kora_lib_rejected then return { n = 2, false, tostring(packed.error) } end
    local count = math.tointeger(packed.n) or #packed
    local results = { n = count + 1, true }
    for index = 1, count do results[index + 1] = packed[index] end
    return results
end

K.step('I ask the jewellery store to start smashing display case {int}', 'client', function(ctx, index)
    ctx:cleanup(function() TriggerServerEvent('qb-jewellery:server:setVitrineState', index, false) end)
    K.started('kora_jewellery')
    ctx.state.jewellerySmash = packedCall('qb-jewellery:server:startSmash', index)
end)
local function smashAnswer(ctx)
    local results = assert(ctx.state.jewellerySmash, 'Ask the jewellery store to start smashing first')
    assert(results[1], 'The startSmash callback failed: ' .. tostring(results[2]))
    return results[2], results[3]
end
-- server.lua startSmash: ('%s (%s)'):format(error.minimum_police, error.police_on_duty)
-- locales/en.lua: 'Minimum of %s police needed', '%s on duty'; Config.RequiredCops = 2.
K.step('the jewellery store should refuse the smash for too few police', 'client', function(ctx)
    local granted, reason = smashAnswer(ctx)
    ctx:equal(granted, false, 'startSmash granted')
    local count = type(reason) == 'string' and reason:match('^Minimum of 2 police needed %((%d+) on duty%)$')
    assert(count, ('Refusal reason is "%s"'):format(tostring(reason)))
    assert(tonumber(count) < 2, 'The refusal reports ' .. count .. ' police on duty')
end)
-- server.lua startSmash: an unknown or distant case returns a bare `false`.
K.step('the jewellery store should refuse the smash without a reason', 'client', function(ctx)
    local granted, reason = smashAnswer(ctx)
    ctx:equal(granted, false, 'startSmash granted')
    ctx:equal(reason, nil, 'Refusal reason')
end)

-- Snapshot of every case, so a refusal can be shown to have changed none of them
-- even while real play has a case in use.
local function snapshot()
    local flags = {}
    for index, location in ipairs(store().locations) do
        flags[index] = (location.isOpened and 'opened' or '-') .. '/' .. (location.isBusy and 'busy' or '-')
    end
    return flags
end
K.step('I remember the jewellery display cases', 'server', function(ctx) ctx.state.jewelleryCases = snapshot() end)
K.step('the jewellery display cases should be unchanged', 'server', function(ctx)
    local before = assert(ctx.state.jewelleryCases, 'Remember the jewellery display cases first')
    Wait(500)
    local now = snapshot()
    ctx:equal(#now, #before, 'Display case count')
    for index = 1, #before do ctx:equal(now[index], before[index], 'Display case ' .. index) end
end)
