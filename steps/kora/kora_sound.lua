-- kora_sound: server-synced sound playback (exports.kora_sound:PlaySound /
-- StopSound and the legacy InteractSound_SV:* net events).
-- No resource hook: the server answers every request with an
-- InteractSound_CL:* net event, which the FFT client observes by registering
-- the same event names. That proves what the server sent to the tester (file,
-- resolved volume, loop id); it does not prove the NUI page played audio.
-- Only sounds addressed to the tester are requested. PlaySoundAll,
-- PlaySoundInArea, PlayOnAll and PlayWithinDistance reach other players and
-- are not used.
local K = FFT.kora
if not K then return end
K.feature('kora_sound')

-- Net events the kora_sound client handles (kora_sound/client/main.lua).
local DELIVERIES = {
    { event = 'InteractSound_CL:PlayOnOne', kind = 'play' },
    { event = 'InteractSound_CL:PlayLoop', kind = 'loop' },
    { event = 'InteractSound_CL:StopSound', kind = 'stop' },
}

local function heard(ctx)
    return assert(ctx.state.soundLog, 'Listen for sounds first')
end

local function find(ctx, kind, key, value)
    for _, entry in ipairs(heard(ctx)) do
        if entry.kind == kind and entry[key] == value then return entry end
    end
end

local function validLoopId(id)
    assert(id:match('^fft_[%w_]+$') and #id <= 40, 'Loop ids used by tests must start with fft_')
end

K.step('I listen for sounds addressed to me', 'client', function(ctx)
    K.started('kora_sound')
    if ctx.state.soundLog then return end
    local log = {}
    ctx.state.soundLog = log
    for _, delivery in ipairs(DELIVERIES) do
        RegisterNetEvent(delivery.event)
        ctx:on(delivery.event, function(first, volume, id)
            if #log >= 50 then return end
            if delivery.kind == 'stop' then
                log[#log + 1] = { kind = 'stop', id = tostring(first) }
            else
                log[#log + 1] = { kind = delivery.kind, file = tostring(first), volume = tonumber(volume), id = id and tostring(id) or nil }
            end
        end)
    end
    -- Let the per-player cooldown (Config.cooldownMs = 150) of an earlier request lapse.
    Wait(300)
end)

-- Server export: exports.kora_sound:PlaySound(src, file, volume?, options?).
K.step('the sound service plays {string} to me at volume {float}', 'server', function(ctx, file, volume)
    assert(volume > 0 and volume <= 1, 'Test volume must be within 0-1')
    K.export('kora_sound', 'PlaySound', ctx.tester, file, volume)
end)
K.step('the sound service plays {string} to me at its preset volume', 'server', function(ctx, file)
    K.export('kora_sound', 'PlaySound', ctx.tester, file)
end)
K.step('the sound service loops {string} to me as {string} at volume {float}', 'server', function(ctx, file, id, volume)
    validLoopId(id)
    assert(volume > 0 and volume <= 1, 'Test volume must be within 0-1')
    local tester = ctx.tester
    ctx:cleanup(function() pcall(function() exports.kora_sound:StopSound(id, tester) end) end)
    K.export('kora_sound', 'PlaySound', tester, file, volume, { loop = true, id = id })
end)
K.step('the sound service stops the loop {string}', 'server', function(_, id)
    validLoopId(id)
    K.export('kora_sound', 'StopSound', id)
end)

-- Legacy client entry point: InteractSound_SV:PlayOnSource(file, volume).
K.step('I request the sound {string} for myself at volume {float}', 'client', function(ctx, file, volume)
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', file, volume)
end)
K.step('I request the sound {string} for myself without a volume', 'client', function(ctx, file)
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', file)
end)
K.step('I request the sound {string} for myself twice without pausing', 'client', function(ctx, file)
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', file, 0.05)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', file, 0.05)
end)

local function closeTo(actual, expected)
    return type(actual) == 'number' and math.abs(actual - expected) < 0.0001
end

K.step('the sound {string} should be played to me at volume {float}', 'client', function(ctx, file, volume)
    local entry = ctx:waitUntil(function() return find(ctx, 'play', 'file', file) end,
        'No InteractSound_CL:PlayOnOne received for ' .. file, 3000)
    assert(closeTo(entry.volume, volume), ('%s was sent at volume %s, expected %s'):format(file, tostring(entry.volume), tostring(volume)))
end)
K.step('the sound {string} should be played to me exactly once', 'client', function(ctx, file)
    ctx:waitUntil(function() return find(ctx, 'play', 'file', file) end,
        'No InteractSound_CL:PlayOnOne received for ' .. file, 3000)
    Wait(1000)
    local total = 0
    for _, entry in ipairs(heard(ctx)) do
        if entry.kind == 'play' and entry.file == file then total = total + 1 end
    end
    ctx:equal(total, 1, 'Deliveries of ' .. file)
end)
K.step('no sound should be played to me', 'client', function(ctx)
    Wait(1500)
    for _, entry in ipairs(heard(ctx)) do
        if entry.kind ~= 'stop' then error('A sound was delivered: ' .. tostring(entry.file), 0) end
    end
end)
K.step('the looping sound {string} should start for me as {string} at volume {float}', 'client', function(ctx, file, id, volume)
    local entry = ctx:waitUntil(function() return find(ctx, 'loop', 'id', id) end,
        'No InteractSound_CL:PlayLoop received for loop ' .. id, 3000)
    ctx:equal(entry.file, file, 'Looping sound file')
    assert(closeTo(entry.volume, volume), ('Loop was sent at volume %s, expected %s'):format(tostring(entry.volume), tostring(volume)))
end)
K.step('the looping sound {string} should be stopped for me', 'client', function(ctx, id)
    ctx:waitUntil(function() return find(ctx, 'stop', 'id', id) end,
        'No InteractSound_CL:StopSound received for loop ' .. id, 3000)
end)

-- ---------------------------------------------------------------------------
-- Round 3: export edge cases, loop bookkeeping, the other legacy entry points,
-- validation boundaries and area playback centred on the tester.
-- ---------------------------------------------------------------------------

local function testVolume(volume)
    assert(volume > 0 and volume <= 1, 'Test volume must be within 0-1')
end

local function countOf(ctx, kind, key, value)
    local total = 0
    for _, entry in ipairs(heard(ctx)) do
        if entry.kind == kind and entry[key] == value then total = total + 1 end
    end
    return total
end

-- Waits for at least one delivery, lets late ones arrive, then counts them.
local function settledCount(ctx, kind, key, value, label)
    ctx:waitUntil(function() return countOf(ctx, kind, key, value) > 0 end, 'Nothing received for ' .. label, 3000)
    Wait(1000)
    return countOf(ctx, kind, key, value)
end

local function stopLoopLater(ctx, id)
    local tester = ctx.tester
    ctx:cleanup(function() pcall(function() exports.kora_sound:StopSound(id, tester) end) end)
end

-- The tester's server-side position, the same value playInArea measures from
-- (kora_sound/server/main.lua:68).
local function testerCoords(ctx)
    local ped = GetPlayerPed(ctx.tester)
    assert(ped and ped ~= 0, 'Tester has no ped on the server')
    return GetEntityCoords(ped)
end

-- Server exports (kora_sound/server/main.lua:104-107).
-- Config.resolveVolume keeps any explicit volume, including 0 (config.lua:34).
K.step('the sound service plays {string} to me silently', 'server', function(ctx, file)
    K.export('kora_sound', 'PlaySound', ctx.tester, file, 0)
end)
K.step('the sound service plays {string} to me {int} times in a row at volume {float}', 'server', function(ctx, file, times, volume)
    assert(times >= 1 and times <= 5, 'Play 1-5 times')
    testVolume(volume)
    for _ = 1, times do K.export('kora_sound', 'PlaySound', ctx.tester, file, volume) end
end)
K.step('the sound service loops {string} to me without an id at volume {float}', 'server', function(ctx, file, volume)
    testVolume(volume)
    K.export('kora_sound', 'PlaySound', ctx.tester, file, volume, { loop = true })
end)
K.step('the sound service plays {string} to me with the id {string} but no loop flag at volume {float}', 'server', function(ctx, file, id, volume)
    validLoopId(id)
    testVolume(volume)
    stopLoopLater(ctx, id)
    K.export('kora_sound', 'PlaySound', ctx.tester, file, volume, { id = id })
end)
K.step('the sound service loops {string} to me as {string} at its preset volume', 'server', function(ctx, file, id)
    validLoopId(id)
    stopLoopLater(ctx, id)
    K.export('kora_sound', 'PlaySound', ctx.tester, file, nil, { loop = true, id = id })
end)
K.step('the sound service stops the loop {string} for me only', 'server', function(ctx, id)
    validLoopId(id)
    K.export('kora_sound', 'StopSound', id, ctx.tester)
end)
-- stopSound returns at once without an id (server/main.lua:85).
K.step('the sound service stops a loop without naming it', 'server', function()
    K.export('kora_sound', 'StopSound', nil)
end)

-- PlaySoundInArea(coords, radius, file, volume?, options?), server/main.lua:59-81.
K.step('the sound service plays {string} in a {float} metre area centred on me at volume {float}', 'server', function(ctx, file, radius, volume)
    assert(radius == 0, 'Areas centred on the tester use a zero radius so nobody else can hear them')
    testVolume(volume)
    K.export('kora_sound', 'PlaySoundInArea', testerCoords(ctx), radius, file, volume)
end)
K.step('the sound service plays {string} in a {float} metre area centred on me at its preset volume', 'server', function(ctx, file, radius)
    assert(radius == 0, 'Areas centred on the tester use a zero radius so nobody else can hear them')
    K.export('kora_sound', 'PlaySoundInArea', testerCoords(ctx), radius, file)
end)
K.step('the sound service loops {string} as {string} in a {float} metre area centred on me at volume {float}', 'server', function(ctx, file, id, radius, volume)
    assert(radius == 0, 'Areas centred on the tester use a zero radius so nobody else can hear them')
    validLoopId(id)
    testVolume(volume)
    stopLoopLater(ctx, id)
    K.export('kora_sound', 'PlaySoundInArea', testerCoords(ctx), radius, file, volume, { loop = true, id = id })
end)
-- A small sphere directly above the tester proves Config.falloffVolume
-- (config.lua:46-50) without reaching anyone who is not right beside them.
K.step('the sound service plays {string} in a {float} metre area centred {float} metres above me at volume {float}', 'server', function(ctx, file, radius, above, volume)
    assert(radius > 0 and radius <= 2, 'Falloff areas are limited to 2 metres')
    assert(above >= 0 and above <= 5, 'Keep the centre within 5 metres of the tester')
    testVolume(volume)
    local at = testerCoords(ctx)
    K.export('kora_sound', 'PlaySoundInArea', vector3(at.x, at.y, at.z + above), radius, file, volume)
end)

-- Legacy namespace: Kora.compat.provideExport('interact-sound', ...) in
-- server/main.lua:108-111. The name is not a running resource, so K.export
-- (which checks the resource state) cannot be used.
local function legacy(name, ...)
    K.started('kora_sound')
    local results = table.pack(pcall(function(...) return exports['interact-sound'][name](exports['interact-sound'], ...) end, ...))
    if not results[1] then error(('exports[\'interact-sound\']:%s failed: %s'):format(name, tostring(results[2])), 0) end
    return table.unpack(results, 2, results.n)
end
K.step('the legacy interact-sound service plays {string} to me at volume {float}', 'server', function(ctx, file, volume)
    testVolume(volume)
    legacy('PlaySound', ctx.tester, file, volume)
end)
K.step('the legacy interact-sound service loops {string} to me as {string} at volume {float}', 'server', function(ctx, file, id, volume)
    validLoopId(id)
    testVolume(volume)
    stopLoopLater(ctx, id)
    legacy('PlaySound', ctx.tester, file, volume, { loop = true, id = id })
end)
K.step('the legacy interact-sound service stops the loop {string}', 'server', function(_, id)
    validLoopId(id)
    legacy('StopSound', id)
end)

-- Legacy client entry points (server/main.lua:113-138). The server applies
-- passesCooldown first, then validSoundFile, then validVolume.
local LONG_NAME = { [128] = true, [129] = true }
local function longName(length)
    assert(LONG_NAME[length], 'Use a 128 or 129 character name')
    return 'fft_' .. string.rep('x', length - 4)
end
local WRONG_TYPES = { number = function() return 42 end, table = function() return { 'Cuff' } end,
    boolean = function() return true end, nothing = function() return nil end }

K.step('I request the sound {string} for myself with the text volume {string}', 'client', function(ctx, file, volume)
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', file, volume)
end)
K.step('I request a sound with a {int} character name for myself', 'client', function(ctx, length)
    heard(ctx)
    ctx.state.soundLongName = longName(length)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', ctx.state.soundLongName, 0.05)
end)
K.step('a sound with a {int} character name should be played to me', 'client', function(ctx, length)
    local name = assert(ctx.state.soundLongName, 'Request a long sound name first')
    ctx:equal(#name, length, 'Requested name length')
    ctx:waitUntil(function() return find(ctx, 'play', 'file', name) end,
        'No InteractSound_CL:PlayOnOne received for the ' .. length .. ' character name', 3000)
end)
K.step('I request a sound named by a {word} for myself', 'client', function(ctx, kind)
    heard(ctx)
    local value = assert(WRONG_TYPES[kind], 'Use number, table, boolean or nothing')
    TriggerServerEvent('InteractSound_SV:PlayOnSource', value(), 0.05)
end)
K.step('I request the invalid sound {string} and then {string} for myself without pausing', 'client', function(ctx, bad, good)
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', bad, 0.05)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', good, 0.05)
end)
K.step('I request the sound {string} for myself twice with a pause of {int} milliseconds', 'client', function(ctx, file, pause)
    assert(pause >= 300 and pause <= 3000, 'Pause 300-3000 ms (Config.cooldownMs is 150)')
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', file, 0.05)
    local deadline = GetGameTimer() + pause
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', file, 0.05)
end)
K.step('I request the sound {string} for my own server id at volume {float}', 'client', function(ctx, file, volume)
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnOne', GetPlayerServerId(PlayerId()), file, volume)
end)
K.step('I request the sound {string} for my own server id written as text at volume {float}', 'client', function(ctx, file, volume)
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnOne', tostring(GetPlayerServerId(PlayerId())), file, volume)
end)
K.step('I request the sound {string} for my own server id without a volume', 'client', function(ctx, file)
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnOne', GetPlayerServerId(PlayerId()), file)
end)
-- Only ids that cannot name a connected player: text, empty, 0 and a server id
-- far above any slot in use.
local NOBODY = { fft_nobody = true, [''] = true, ['0'] = true, ['64999'] = true }
K.step('I request the sound {string} for the target {string} at volume {float}', 'client', function(ctx, file, target, volume)
    assert(NOBODY[target], 'Only targets that cannot reach another player are allowed')
    assert(GetPlayerFromServerId(tonumber(target) or -1) == -1, 'Target ' .. target .. ' is a connected player')
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnOne', target, file, volume)
end)
K.step('I request {string} for my own server id and then {string} for myself without pausing', 'client', function(ctx, first, second)
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayOnOne', GetPlayerServerId(PlayerId()), first, 0.05)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', second, 0.05)
end)
-- InteractSound_SV:PlayWithinDistance(maxDistance, file, volume): a zero range
-- centred on the sender reaches the sender only.
K.step('I request the sound {string} within {int} metres of myself at volume {float}', 'client', function(ctx, file, distance, volume)
    assert(distance == 0, 'Only a zero range is used, so no other player can hear it')
    heard(ctx)
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', distance, file, volume)
end)

-- Client assertions on what the server delivered.
K.step('the sound {string} should be played to me exactly {int} times', 'client', function(ctx, file, times)
    ctx:equal(settledCount(ctx, 'play', 'file', file, file), times, 'Deliveries of ' .. file)
end)
K.step('the sound {string} should not be played to me', 'client', function(ctx, file)
    Wait(1000)
    ctx:equal(countOf(ctx, 'play', 'file', file), 0, 'Deliveries of ' .. file)
end)
K.step('the sound {string} should be played to me at roughly volume {float}', 'client', function(ctx, file, volume)
    local entry = ctx:waitUntil(function() return find(ctx, 'play', 'file', file) end,
        'No InteractSound_CL:PlayOnOne received for ' .. file, 3000)
    assert(type(entry.volume) == 'number' and math.abs(entry.volume - volume) <= 0.01,
        ('%s was sent at volume %s, expected about %s'):format(file, tostring(entry.volume), tostring(volume)))
end)
K.step('no looping sound should start for me', 'client', function(ctx)
    Wait(1000)
    for _, entry in ipairs(heard(ctx)) do
        if entry.kind == 'loop' then error('A loop was started: ' .. tostring(entry.id), 0) end
    end
end)
K.step('the looping sound {string} should have started for me exactly {int} times', 'client', function(ctx, id, times)
    ctx:equal(settledCount(ctx, 'loop', 'id', id, 'loop ' .. id), times, 'Loop starts for ' .. id)
end)
K.step('the looping sound {string} should be stopped for me exactly once', 'client', function(ctx, id)
    ctx:equal(settledCount(ctx, 'stop', 'id', id, 'loop ' .. id), 1, 'Stops for ' .. id)
end)
K.step('the looping sound {string} should be stopped for me exactly {int} times', 'client', function(ctx, id, times)
    ctx:equal(settledCount(ctx, 'stop', 'id', id, 'loop ' .. id), times, 'Stops for ' .. id)
end)
K.step('the looping sound {string} should not be stopped for me', 'client', function(ctx, id)
    Wait(1000)
    ctx:equal(countOf(ctx, 'stop', 'id', id), 0, 'Stops for ' .. id)
end)
K.step('no loop stop should reach me', 'client', function(ctx)
    Wait(1500)
    for _, entry in ipairs(heard(ctx)) do
        if entry.kind == 'stop' then error('A loop stop was delivered: ' .. tostring(entry.id), 0) end
    end
end)
