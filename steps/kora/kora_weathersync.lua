-- kora_weathersync: synchronized weather, clock, time freeze and blackout
-- (server exports, GlobalState.kora_weathersync, admin commands).
-- No resource hook: the state is public through exports.kora_weathersync:getState
-- and GlobalState, and the client effects are readable through game natives.
-- Weather and time are visible to every player, so the suite is read-only apart
-- from one @global scenario that writes back the values already in force.
-- Commands are only ever run with invalid arguments: the tester's permission
-- tier is unknown, so a valid argument could change the world for everyone.
local K = FFT.kora
if not K then return end
K.feature('kora_weathersync')

-- Config.weatherTypes in kora_weathersync/config.lua.
local WEATHER_TYPES = {
    EXTRASUNNY = true, CLEAR = true, NEUTRAL = true, SMOG = true, FOGGY = true, OVERCAST = true,
    CLOUDS = true, CLEARING = true, RAIN = true, THUNDER = true, SNOW = true, BLIZZARD = true,
    SNOWLIGHT = true, XMAS = true, HALLOWEEN = true,
}
-- kora_lib's command dispatcher (kora_lib/modules/commands/server.lua).
local DENIED = 'You do not have permission for this command.'

local function state()
    local current = K.export('kora_weathersync', 'getState')
    assert(type(current) == 'table', 'exports.kora_weathersync:getState returned no state')
    return current
end

local function clockMinutes(current) return current.hour * 60 + current.minute end

local function remember(ctx)
    local current = state()
    ctx.state.weatherBefore = current
    return current
end

local function remembered(ctx)
    return assert(ctx.state.weatherBefore, 'Remember the weather state first')
end

-- The simulated clock keeps running (one game minute per
-- Config.realSecondsPerGameMinute = 8 s), so "unchanged" allows a few minutes.
local function assertUnchanged(ctx)
    local before, now = remembered(ctx), state()
    ctx:equal(now.weather, before.weather, 'Weather')
    ctx:equal(now.timeFrozen, before.timeFrozen, 'Time frozen')
    ctx:equal(now.dynamicWeather, before.dynamicWeather, 'Dynamic weather')
    ctx:equal(now.blackout, before.blackout, 'Blackout')
    local drift = (clockMinutes(now) - clockMinutes(before)) % 1440
    assert(drift <= 5, ('Clock moved %d minutes (now %02d:%02d)'):format(drift, now.hour, now.minute))
    if before.timeFrozen then ctx:equal(drift, 0, 'Frozen clock drift') end
end

K.step('the weather state should be valid', 'server', function(ctx)
    local current = state()
    assert(WEATHER_TYPES[current.weather], 'Weather is not a configured type: ' .. tostring(current.weather))
    assert(math.type(current.hour) == 'integer' and current.hour >= 0 and current.hour <= 23, 'Hour out of range: ' .. tostring(current.hour))
    assert(math.type(current.minute) == 'integer' and current.minute >= 0 and current.minute <= 59, 'Minute out of range: ' .. tostring(current.minute))
    ctx:equal(type(current.timeFrozen), 'boolean', 'timeFrozen type')
    ctx:equal(type(current.dynamicWeather), 'boolean', 'dynamicWeather type')
    ctx:equal(type(current.blackout), 'boolean', 'blackout type')
    ctx:equal(type(current.blackoutAffectsVehicles), 'boolean', 'blackoutAffectsVehicles type')
    assert(math.type(current.revision) == 'integer' and current.revision >= 1, 'Revision should be a positive integer: ' .. tostring(current.revision))
end)

K.step('the published weather state should match the weather service', 'server', function(ctx)
    -- Retried because the clock may tick between the two reads.
    ctx:waitUntil(function()
        local current, published = state(), GlobalState.kora_weathersync
        if type(published) ~= 'table' or published.revision ~= current.revision then return false end
        for _, key in ipairs({ 'weather', 'hour', 'minute', 'timeFrozen', 'dynamicWeather', 'blackout', 'blackoutAffectsVehicles' }) do
            if published[key] ~= current[key] then error('GlobalState.kora_weathersync.' .. key .. ' differs from getState', 0) end
        end
        return true
    end, 'GlobalState.kora_weathersync never matched getState', 3000)
end)

K.step('the weather getters should agree with the weather state', 'server', function(ctx)
    ctx:waitUntil(function()
        local current = state()
        local weather = K.export('kora_weathersync', 'getWeather')
        local hour, minute = K.export('kora_weathersync', 'getTime')
        local frozen = K.export('kora_weathersync', 'getTimeFrozen')
        local dynamic = K.export('kora_weathersync', 'getDynamicWeather')
        local blackout = K.export('kora_weathersync', 'getBlackout')
        if state().revision ~= current.revision then return false end
        ctx:equal(weather, current.weather, 'getWeather')
        ctx:equal(hour, current.hour, 'getTime hour')
        ctx:equal(minute, current.minute, 'getTime minute')
        ctx:equal(frozen, current.timeFrozen, 'getTimeFrozen')
        ctx:equal(dynamic, current.dynamicWeather, 'getDynamicWeather')
        ctx:equal(blackout, current.blackout, 'getBlackout')
        return true
    end, 'Weather state kept changing between reads', 3000)
end)

-- Legacy bridge: Kora.compat.provideExport('qb-weathersync', ...) in server/state.lua.
K.step('the legacy weather exports should report the same weather state', 'server', function(ctx)
    K.started('kora_weathersync')
    local ok, weather, frozen, blackout = pcall(function()
        local legacy = exports['qb-weathersync']
        return legacy:getWeatherState(), legacy:getTimeFreezeState(), legacy:getBlackoutState()
    end)
    if not ok then error('Legacy qb-weathersync exports are unavailable: ' .. tostring(weather), 0) end
    local current = state()
    ctx:equal(weather, current.weather, 'qb-weathersync getWeatherState')
    ctx:equal(frozen, current.timeFrozen, 'qb-weathersync getTimeFreezeState')
    ctx:equal(blackout, current.blackout, 'qb-weathersync getBlackoutState')
end)

K.step('I remember the weather state', 'server', function(ctx) remember(ctx) end)
K.step('the weather state should be unchanged', 'server', function(ctx)
    Wait(500)
    assertUnchanged(ctx)
end)

K.step('setting the weather to {string} should be refused as an unknown weather type', 'server', function(ctx, weatherType)
    assert(not WEATHER_TYPES[weatherType:upper()], 'Use a weather type that is not configured')
    local before = remember(ctx)
    local ok, err = K.export('kora_weathersync', 'setWeather', weatherType)
    if ok then
        K.export('kora_weathersync', 'setWeather', before.weather)
        error('setWeather accepted ' .. weatherType, 0)
    end
    ctx:equal(err, ('unknown weather type %q'):format(weatherType), 'Refusal reason')
end)

K.step('setting the synchronized clock to hour {int} minute {int} should be refused', 'server', function(ctx, hour, minute)
    assert(hour < 0 or hour > 23 or minute < 0 or minute > 59, 'Use a time outside 0-23 and 0-59')
    local before = remember(ctx)
    local ok, err = K.export('kora_weathersync', 'setTime', hour, minute)
    if ok then
        K.export('kora_weathersync', 'setTime', before.hour, before.minute)
        error(('setTime accepted %d:%d'):format(hour, minute), 0)
    end
    ctx:equal(err, 'hour must be 0-23 and minute must be 0-59', 'Refusal reason')
end)

-- Writes back the values already in force with explicit arguments (never the
-- nil toggle form), so players see no change. Each setter publishes once.
-- setWeather and setDynamicWeather are left alone: both restart the dynamic
-- weather timer.
K.step('I reapply the current clock, time freeze and blackout settings', 'server', function(ctx)
    local before = remember(ctx)
    local ok, err = K.export('kora_weathersync', 'setTime', before.hour, before.minute)
    if not ok then error('setTime refused the current time: ' .. tostring(err), 0) end
    ctx:equal(K.export('kora_weathersync', 'setTimeFrozen', before.timeFrozen), before.timeFrozen, 'setTimeFrozen result')
    ctx:equal(K.export('kora_weathersync', 'setBlackout', before.blackout), before.blackout, 'setBlackout result')
end)
K.step('the weather state revision should have advanced by at least {int}', 'server', function(ctx, amount)
    local before, now = remembered(ctx), state()
    assert(now.revision - before.revision >= amount,
        ('Revision went from %d to %d, expected at least +%d'):format(before.revision, now.revision, amount))
end)

-- A player-sent kora_weathersync:server:setWeather must be ignored (serverOnly
-- in server/state.lua). If it were honoured the weather would change for
-- everyone, so the guard restores it.
K.step('I guard the weather against a forged change', 'server', function(ctx)
    local before = remember(ctx)
    ctx:cleanup(function()
        local now = exports.kora_weathersync:getWeather()
        if now ~= before.weather and (now == 'XMAS' or now == 'HALLOWEEN') then
            exports.kora_weathersync:setWeather(before.weather)
        end
    end)
end)
K.step('I send a forged weather change as a player', 'client', function()
    K.started('kora_weathersync')
    local published = GlobalState.kora_weathersync
    assert(type(published) == 'table', 'GlobalState.kora_weathersync is not published')
    TriggerServerEvent('kora_weathersync:server:setWeather', published.weather == 'XMAS' and 'HALLOWEEN' or 'XMAS')
    Wait(1000)
end)

-- ---------------------------------------------------------------------------
-- Client
-- ---------------------------------------------------------------------------

K.step('the weather type list should include the current weather', 'client', function(ctx)
    local types = K.export('kora_weathersync', 'getWeatherTypes')
    assert(type(types) == 'table' and #types > 0, 'getWeatherTypes returned no list')
    local published = GlobalState.kora_weathersync
    assert(type(published) == 'table', 'GlobalState.kora_weathersync is not published')
    for _, weatherType in ipairs(types) do
        ctx:equal(WEATHER_TYPES[weatherType] == true, true, 'Configured weather type ' .. tostring(weatherType))
        if weatherType == published.weather then return end
    end
    error('Current weather is not in the type list: ' .. tostring(published.weather), 0)
end)

-- client/main.lua re-applies NetworkOverrideClockTime every second.
K.step('my game clock should follow the synchronized time', 'client', function(ctx)
    K.started('kora_weathersync')
    ctx:waitUntil(function()
        local published = GlobalState.kora_weathersync
        return type(published) == 'table' and GetClockHours() == published.hour and GetClockMinutes() == published.minute
    end, ('Game clock is %02d:%02d and never matched the synchronized time'):format(GetClockHours(), GetClockMinutes()), 6000)
end)

-- Server answers qb-weathersync:server:RequestStateSync with
-- kora_weathersync:client:state, at most once per 2 s per player.
K.step('I ask for a weather state sync twice in a row', 'client', function(ctx)
    K.started('kora_weathersync')
    local replies = {}
    ctx.state.weatherSyncReplies = replies
    RegisterNetEvent('kora_weathersync:client:state')
    ctx:on('kora_weathersync:client:state', function(reply)
        if #replies < 10 then
            replies[#replies + 1] = type(reply) == 'table' and { weather = reply.weather, hour = reply.hour, minute = reply.minute } or {}
        end
    end)
    -- Let the cooldown of any earlier request lapse.
    local deadline = GetGameTimer() + 2200
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
    TriggerServerEvent('qb-weathersync:server:RequestStateSync')
    TriggerServerEvent('qb-weathersync:server:RequestStateSync')
end)
K.step('I should receive exactly one weather state reply', 'client', function(ctx)
    local replies = assert(ctx.state.weatherSyncReplies, 'Ask for a weather state sync first')
    ctx:waitUntil(function() return #replies > 0 end, 'No kora_weathersync:client:state reply arrived', 3000)
    Wait(1000)
    ctx:equal(#replies, 1, 'Weather state replies')
    assert(WEATHER_TYPES[replies[1].weather], 'Reply carries no configured weather: ' .. tostring(replies[1].weather))
    ctx:equal(math.type(replies[1].hour), 'integer', 'Reply hour type')
end)

-- The tester may or may not hold the admin tier. An invalid argument is refused
-- either way: by the permission gate, or by the command's own validation.
K.step('the world control command should be refused for lack of permission or with {string}', 'client', function(ctx, reason)
    ctx:waitUntil(function()
        for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            if K.contains(entry.message, DENIED) or K.contains(entry.message, reason) then return true end
        end
    end, ('No refusal notification (expected "%s" or "%s")'):format(DENIED, reason), 5000)
end)

-- ---------------------------------------------------------------------------
-- Round 3: export and legacy-export refusals, write-back of current values
-- through the legacy setters, every server-only event forged by a player,
-- state-sync replies, and the client-local legacy events (SyncTime,
-- SyncWeather, DisableSync, EnableSync), which change only the tester's view.
-- Sources: kora_weathersync/server/state.lua, server/commands.lua,
-- client/main.lua and config.lua.
-- ---------------------------------------------------------------------------

-- Config.weatherTypes in order (config.lua).
local WEATHER_ORDER = {
    'EXTRASUNNY', 'CLEAR', 'NEUTRAL', 'SMOG', 'FOGGY', 'OVERCAST', 'CLOUDS', 'CLEARING',
    'RAIN', 'THUNDER', 'SNOW', 'BLIZZARD', 'SNOWLIGHT', 'XMAS', 'HALLOWEEN',
}
-- Config.weatherEffects rain levels (config.lua); unlisted weather has none.
local RAIN_LEVEL = { RAIN = 0.35, THUNDER = 0.70 }

local function legacyExport(name, ...)
    K.started('kora_weathersync')
    local results = table.pack(pcall(function(...) return exports['qb-weathersync'][name](exports['qb-weathersync'], ...) end, ...))
    if not results[1] then error(('exports[\'qb-weathersync\']:%s failed: %s'):format(name, tostring(results[2])), 0) end
    return table.unpack(results, 2, results.n)
end

-- Restores anything a scenario that should change nothing did change, using
-- explicit values only. Registered before the action that could change it.
local function guardEverything(ctx)
    local before = remember(ctx)
    ctx:cleanup(function()
        local ws = exports.kora_weathersync
        local now = ws:getState()
        if now.weather ~= before.weather then ws:setWeather(before.weather) end
        if now.timeFrozen ~= before.timeFrozen then ws:setTimeFrozen(before.timeFrozen) end
        if now.dynamicWeather ~= before.dynamicWeather then ws:setDynamicWeather(before.dynamicWeather) end
        if now.blackout ~= before.blackout then ws:setBlackout(before.blackout) end
        local drift = ((now.hour * 60 + now.minute) - (before.hour * 60 + before.minute)) % 1440
        if drift > 5 then ws:setTime(before.hour, before.minute) end
    end)
    return before
end

-- Native export refusals ------------------------------------------------------

local ODD_VALUES = { number = function() return 5 end, nothing = function() return nil end, ['true'] = function() return true end }
K.step('setting the weather to a {word} value should be refused as an unknown weather type', 'server', function(ctx, kind)
    local make = assert(ODD_VALUES[kind], 'Use number, nothing or true')
    local value = make()
    local before = guardEverything(ctx)
    local okSet, err = K.export('kora_weathersync', 'setWeather', value)
    ctx:equal(okSet, false, 'setWeather result')
    ctx:equal(err, ('unknown weather type %q'):format(tostring(value)), 'Refusal reason')
    ctx:equal(state().weather, before.weather, 'Weather')
end)
K.step('setting the synchronized clock to the fractional hour {float} minute {float} should be refused', 'server', function(ctx, hour, minute)
    assert(hour ~= math.floor(hour) or minute ~= math.floor(minute), 'Use a fractional hour or minute')
    guardEverything(ctx)
    local okSet, err = K.export('kora_weathersync', 'setTime', hour, minute)
    ctx:equal(okSet, false, 'setTime result')
    ctx:equal(err, 'hour must be 0-23 and minute must be 0-59', 'Refusal reason')
end)
K.step('setting the synchronized clock with the text {string} and {string} should be refused', 'server', function(ctx, hour, minute)
    guardEverything(ctx)
    local okSet, err = K.export('kora_weathersync', 'setTime', hour, minute)
    ctx:equal(okSet, false, 'setTime result')
    ctx:equal(err, 'hour must be 0-23 and minute must be 0-59', 'Refusal reason')
end)
-- The native setter has no default minute (validInteger(nil) fails).
K.step('setting the synchronized clock to the current hour without a minute should be refused', 'server', function(ctx)
    local before = guardEverything(ctx)
    local okSet, err = K.export('kora_weathersync', 'setTime', before.hour)
    ctx:equal(okSet, false, 'setTime result')
    ctx:equal(err, 'hour must be 0-23 and minute must be 0-59', 'Refusal reason')
end)

-- Legacy qb-weathersync exports --------------------------------------------------

K.step('the legacy weather clock and dynamic weather should match the weather state', 'server', function(ctx)
    ctx:waitUntil(function()
        local current = state()
        local hour, minute = legacyExport('getTime')
        local dynamic = legacyExport('getDynamicWeather')
        if state().revision ~= current.revision then return false end
        ctx:equal(hour, current.hour, 'qb-weathersync getTime hour')
        ctx:equal(minute, current.minute, 'qb-weathersync getTime minute')
        ctx:equal(dynamic, current.dynamicWeather, 'qb-weathersync getDynamicWeather')
        return true
    end, 'Weather state kept changing between reads', 3000)
end)
K.step('the legacy weather export should refuse the weather {string}', 'server', function(ctx, weatherType)
    assert(not WEATHER_TYPES[weatherType:upper()], 'Use a weather type that is not configured')
    guardEverything(ctx)
    -- legacyExports.setWeather returns only the boolean (state.lua).
    local okSet, extra = legacyExport('setWeather', weatherType)
    ctx:equal(okSet, false, 'qb-weathersync setWeather result')
    ctx:equal(extra, nil, 'qb-weathersync setWeather second value')
end)
-- legacyTime (state.lua): false for a non-numeric or out-of-range hour or a
-- negative minute. Hour 24 and minute 60 are accepted (they wrap), so they are
-- never sent here.
K.step('the legacy clock export should refuse hour {string} minute {string}', 'server', function(ctx, hour, minute)
    local h, m = tonumber(hour), tonumber(minute)
    assert(not h or h < 0 or h > 24 or (m and m < 0), 'Use a time the legacy setter refuses')
    guardEverything(ctx)
    ctx:equal(legacyExport('setTime', hour, minute), false, 'qb-weathersync setTime result')
end)
K.step('I write the current clock back through the legacy export as text', 'server', function(ctx)
    local before = guardEverything(ctx)
    ctx:equal(legacyExport('setTime', tostring(before.hour), tostring(before.minute)), true, 'qb-weathersync setTime result')
end)
K.step('I write the current clock back through the legacy export with fractions', 'server', function(ctx)
    local before = guardEverything(ctx)
    ctx:equal(legacyExport('setTime', before.hour + 0.75, before.minute + 0.25), true, 'qb-weathersync setTime result')
end)
K.step('I write the current time freeze and blackout back through the legacy exports', 'server', function(ctx)
    local before = guardEverything(ctx)
    ctx:equal(legacyExport('setTimeFreeze', before.timeFrozen), before.timeFrozen, 'qb-weathersync setTimeFreeze result')
    ctx:equal(legacyExport('setBlackout', before.blackout), before.blackout, 'qb-weathersync setBlackout result')
end)

-- Forged server-only events -----------------------------------------------------------

-- serverOnly() in state.lua drops every one of these from a player source.
local FORGEABLE = {
    ['kora_weathersync:server:setWeather'] = 'weather',
    ['kora_weathersync:server:setTime'] = 'time',
    ['qb-weathersync:server:setWeather'] = 'weather',
    ['qb-weathersync:server:setTime'] = 'time',
    ['qb-weathersync:server:toggleBlackout'] = 'toggle',
    ['qb-weathersync:server:toggleFreezeTime'] = 'toggle',
    ['qb-weathersync:server:toggleDynamicWeather'] = 'toggle',
}
K.step('I guard every weather setting against a forged change', 'server', function(ctx) guardEverything(ctx) end)
K.step('I send the forged event {string} as a player', 'client', function(_, event)
    local kind = assert(FORGEABLE[event], 'Not a server-only weather event: ' .. event)
    K.started('kora_weathersync')
    local published = GlobalState.kora_weathersync
    assert(type(published) == 'table', 'GlobalState.kora_weathersync is not published')
    if kind == 'weather' then
        TriggerServerEvent(event, published.weather == 'XMAS' and 'HALLOWEEN' or 'XMAS')
    elseif kind == 'time' then
        TriggerServerEvent(event, (published.hour + 12) % 24, 0)
    else
        TriggerServerEvent(event)
    end
    Wait(1000)
end)

-- State sync -----------------------------------------------------------------------------------

local function listenForSync(ctx)
    local replies = ctx.state.weatherSyncReplies
    if replies then return replies end
    replies = {}
    ctx.state.weatherSyncReplies = replies
    RegisterNetEvent('kora_weathersync:client:state')
    ctx:on('kora_weathersync:client:state', function(reply)
        if #replies < 10 and type(reply) == 'table' then
            replies[#replies + 1] = { weather = reply.weather, hour = reply.hour, minute = reply.minute,
                timeFrozen = reply.timeFrozen, blackout = reply.blackout, revision = reply.revision }
        end
    end)
    return replies
end
local function lapseSyncCooldown(ctx)
    local deadline = GetGameTimer() + 2200 -- syncCooldownMs = 2000 in state.lua
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
end
K.step('I ask for a weather state sync on both request events in a row', 'client', function(ctx)
    K.started('kora_weathersync')
    listenForSync(ctx)
    lapseSyncCooldown(ctx)
    TriggerServerEvent('kora_weathersync:server:requestStateSync')
    TriggerServerEvent('qb-weathersync:server:RequestStateSync')
end)
K.step('I ask for a weather state sync twice with the cooldown between', 'client', function(ctx)
    K.started('kora_weathersync')
    listenForSync(ctx)
    lapseSyncCooldown(ctx)
    TriggerServerEvent('kora_weathersync:server:requestStateSync')
    lapseSyncCooldown(ctx)
    TriggerServerEvent('kora_weathersync:server:requestStateSync')
end)
K.step('I should receive exactly {int} weather state replies', 'client', function(ctx, count)
    local replies = assert(ctx.state.weatherSyncReplies, 'Ask for a weather state sync first')
    ctx:waitUntil(function() return #replies >= count end, ('Only %d of %d weather state replies arrived'):format(#replies, count), 3000)
    Wait(1000)
    ctx:equal(#replies, count, 'Weather state replies')
end)
K.step('the weather state reply should match the published state', 'client', function(ctx)
    local replies = assert(ctx.state.weatherSyncReplies, 'Ask for a weather state sync first')
    local reply = assert(replies[#replies], 'No weather state reply arrived')
    local published = GlobalState.kora_weathersync
    assert(type(published) == 'table', 'GlobalState.kora_weathersync is not published')
    assert(reply.revision <= published.revision, 'Reply is newer than the published state')
    ctx:equal(reply.weather, published.weather, 'Reply weather')
    ctx:equal(reply.timeFrozen, published.timeFrozen, 'Reply timeFrozen')
    ctx:equal(reply.blackout, published.blackout, 'Reply blackout')
    local drift = ((published.hour * 60 + published.minute) - (reply.hour * 60 + reply.minute)) % 1440
    assert(drift <= 2, ('Reply clock %02d:%02d is %d minutes behind the published clock'):format(reply.hour, reply.minute, drift))
end)

-- Client view ------------------------------------------------------------------------------------

K.step('the weather type list should be the configured list in order', 'client', function(ctx)
    local types = K.export('kora_weathersync', 'getWeatherTypes')
    assert(type(types) == 'table', 'getWeatherTypes returned no list')
    ctx:equal(#types, #WEATHER_ORDER, 'Weather type count')
    for index, weatherType in ipairs(WEATHER_ORDER) do ctx:equal(types[index], weatherType, 'Weather type ' .. index) end
end)
-- applyState persists the weather type; during a 15 s blend the next type is the target.
K.step('my game weather should follow the synchronized weather', 'client', function(ctx)
    K.started('kora_weathersync')
    ctx:waitUntil(function()
        local published = GlobalState.kora_weathersync
        if type(published) ~= 'table' then return false end
        local hash = GetHashKey(published.weather)
        return GetNextWeatherTypeHashName() == hash or GetPrevWeatherTypeHashName() == hash
    end, 'Game weather never matched the synchronized weather', 12000)
end)
-- client/main.lua re-applies SetRainLevel from Config.weatherEffects every second.
K.step('my rain level should follow the synchronized weather', 'client', function(ctx)
    K.started('kora_weathersync')
    ctx:waitUntil(function()
        local published = GlobalState.kora_weathersync
        if type(published) ~= 'table' then return false end
        return math.abs(GetRainLevel() - (RAIN_LEVEL[published.weather] or 0.0)) < 0.01
    end, ('Rain level %.2f never matched the synchronized weather'):format(GetRainLevel()), 4000)
end)

-- Client-local legacy events. They change only the tester's own view, until
-- the next server publish or an explicit state sync, which the cleanup asks for.
local function resyncLater(ctx)
    if ctx.state.weatherResync then return end
    ctx.state.weatherResync = true
    ctx:cleanup(function()
        TriggerEvent('qb-weathersync:client:EnableSync')
    end)
end
K.step('I shift my local clock by {int} hours with the legacy time event', 'client', function(ctx, hours)
    assert(hours >= 1 and hours <= 23, 'Shift by 1-23 hours')
    local published = assert(GlobalState.kora_weathersync, 'GlobalState.kora_weathersync is not published')
    resyncLater(ctx)
    local target = (published.hour + hours) % 24
    ctx.state.weatherLocalHour = target
    -- SyncTime(base, offset): hour = floor(total / 60) % 24, minute = total % 60.
    TriggerEvent('qb-weathersync:client:SyncTime', target * 60, published.minute)
end)
K.step('my game clock should show the shifted hour', 'client', function(ctx)
    local target = assert(ctx.state.weatherLocalHour, 'Shift the local clock first')
    ctx:waitUntil(function() return GetClockHours() == target end,
        ('Game clock shows %02d, expected the local hour %02d'):format(GetClockHours(), target), 2500)
end)
K.step('I send the legacy time event with the values {string} and {string}', 'client', function(ctx, base, offset)
    resyncLater(ctx)
    TriggerEvent('qb-weathersync:client:SyncTime', base, offset)
end)
K.step('I request a fresh weather state sync', 'client', function(ctx)
    K.started('kora_weathersync')
    listenForSync(ctx)
    lapseSyncCooldown(ctx)
    TriggerServerEvent('kora_weathersync:server:requestStateSync')
    ctx:waitUntil(function() return #ctx.state.weatherSyncReplies > 0 end, 'No weather state reply arrived', 3000)
end)
K.step('I send the legacy weather event for a rainier weather', 'client', function(ctx)
    local published = assert(GlobalState.kora_weathersync, 'GlobalState.kora_weathersync is not published')
    local weatherType = published.weather == 'THUNDER' and 'RAIN' or 'THUNDER'
    ctx.state.weatherLocalRain = RAIN_LEVEL[weatherType]
    resyncLater(ctx)
    TriggerEvent('qb-weathersync:client:SyncWeather', weatherType:lower())
end)
K.step('my rain level should show the local weather', 'client', function(ctx)
    local level = assert(ctx.state.weatherLocalRain, 'Send the legacy weather event first')
    ctx:waitUntil(function() return math.abs(GetRainLevel() - level) < 0.01 end,
        ('Rain level %.2f, expected the local %.2f'):format(GetRainLevel(), level), 2000)
end)
K.step('I send the legacy weather event for the unknown weather {string}', 'client', function(ctx, weatherType)
    assert(not WEATHER_TYPES[weatherType:upper()], 'Use a weather type that is not configured')
    resyncLater(ctx)
    TriggerEvent('qb-weathersync:client:SyncWeather', weatherType)
end)
K.step('I suspend weather sync with the legacy event', 'client', function(ctx)
    K.started('kora_weathersync')
    resyncLater(ctx)
    TriggerEvent('qb-weathersync:client:DisableSync')
end)
-- DisableSync forces CLEAR, no rain and 18:00 locally (client/main.lua).
K.step('my game should show the suspended interior view', 'client', function(ctx)
    ctx:waitUntil(function() return GetClockHours() == 18 end, 'Game clock is not 18:00 after DisableSync', 1500)
    ctx:equal(GetPrevWeatherTypeHashName(), GetHashKey('CLEAR'), 'Weather after DisableSync')
    assert(GetRainLevel() < 0.01, 'Rain level is ' .. GetRainLevel())
    Wait(1500)
    ctx:equal(GetClockHours(), 18, 'Clock while sync is suspended')
end)
K.step('I resume weather sync with the legacy event', 'client', function(ctx)
    listenForSync(ctx)
    lapseSyncCooldown(ctx) -- EnableSync sends RequestStateSync, which shares the 2 s cooldown
    TriggerEvent('qb-weathersync:client:EnableSync')
end)
