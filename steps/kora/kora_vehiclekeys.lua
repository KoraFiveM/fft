-- kora_vehiclekeys: session keys, lock toggle, engine key and the lockpick
-- refusals that never reach a minigame.
-- No resource hook: keys are read and granted through the server exports
-- (giveKeys, removeKeys, hasKeys and the provided qb-vehiclekeys names), the
-- lock state is the replicated entity state bag `kora_vehiclekeys:locked`, and
-- every message is a kora_lib notification.
local K = FFT.kora
if not K then return end
K.feature('kora_vehiclekeys')

local function trim(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper()
end

-- Server view of the vehicle the tester drives (waits for the seat to replicate).
local function serverVehicle(ctx)
    local vehicle
    ctx:waitUntil(function()
        local ped = GetPlayerPed(ctx.tester)
        vehicle = ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
        return vehicle ~= 0 and DoesEntityExist(vehicle) and trim(GetVehicleNumberPlateText(vehicle)) ~= ''
    end, 'The server does not see the tester in a vehicle', 5000)
    return vehicle, trim(GetVehicleNumberPlateText(vehicle))
end

local function clientVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    assert(vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped, 'The tester is not driving a vehicle')
    return vehicle
end

local function give(ctx, plate)
    local tester = ctx.tester
    ctx:cleanup(function() pcall(function() exports.kora_vehiclekeys:removeKeys(tester, plate) end) end)
    ctx:equal(K.export('kora_vehiclekeys', 'giveKeys', tester, plate), true, 'giveKeys result')
end

-- ---------------------------------------------------------------------------
-- Keys by plate (server exports only)
-- ---------------------------------------------------------------------------

K.step('I am given vehicle keys for plate {string}', 'server', function(ctx, plate) give(ctx, plate) end)
K.step('my vehicle keys for plate {string} are taken away', 'server', function(ctx, plate)
    ctx:equal(K.export('kora_vehiclekeys', 'removeKeys', ctx.tester, plate), true, 'removeKeys result')
end)
K.step('I should hold vehicle keys for plate {string}', 'server', function(ctx, plate)
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate), true, 'hasKeys for ' .. plate)
    -- Provided legacy name (Kora.compat.provideExport in server/main.lua).
    ctx:equal(exports['qb-vehiclekeys']:HasKeys(ctx.tester, plate), true, 'qb-vehiclekeys HasKeys for ' .. plate)
end)
K.step('I should not hold vehicle keys for plate {string}', 'server', function(ctx, plate)
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate), false, 'hasKeys for ' .. plate)
    ctx:equal(exports['qb-vehiclekeys']:HasKeys(ctx.tester, plate), false, 'qb-vehiclekeys HasKeys for ' .. plate)
end)
K.step('giving vehicle keys for an empty plate should be refused', 'server', function(ctx)
    ctx:equal(K.export('kora_vehiclekeys', 'giveKeys', ctx.tester, '   '), false, 'giveKeys result for a blank plate')
end)

-- ---------------------------------------------------------------------------
-- Keys of the driven vehicle (server)
-- ---------------------------------------------------------------------------

K.step('I hold the keys of the vehicle I am driving', 'server', function(ctx)
    local _, plate = serverVehicle(ctx)
    give(ctx, plate)
end)
K.step('I hold no keys of the vehicle I am driving', 'server', function(ctx)
    local _, plate = serverVehicle(ctx)
    K.export('kora_vehiclekeys', 'removeKeys', ctx.tester, plate)
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate), false, 'hasKeys for ' .. plate)
end)
K.step('I should still hold the keys of the vehicle I am driving', 'server', function(ctx)
    local _, plate = serverVehicle(ctx)
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate), true, 'hasKeys for ' .. plate)
end)
K.step('I should still hold no keys of the vehicle I am driving', 'server', function(ctx)
    local _, plate = serverVehicle(ctx)
    Wait(500)
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate), false, 'hasKeys for ' .. plate)
end)

local function lockState(vehicle) return Entity(vehicle).state['kora_vehiclekeys:locked'] == true end
K.step('the vehicle I am driving should be locked by its keys', 'server', function(ctx)
    local vehicle = serverVehicle(ctx)
    ctx:waitUntil(function() return lockState(vehicle) end, 'Vehicle lock state is not locked', 3000)
end)
K.step('the vehicle I am driving should not be locked by its keys', 'server', function(ctx)
    local vehicle = serverVehicle(ctx)
    Wait(500)
    ctx:equal(lockState(vehicle), false, 'Vehicle lock state')
end)

-- ---------------------------------------------------------------------------
-- Client: provided export, engine key, lockpick item event
-- ---------------------------------------------------------------------------

K.step('my client key check for the vehicle I am driving should say {word}', 'client', function(ctx, expected)
    assert(expected == 'yes' or expected == 'no', 'Use yes or no')
    local plate = trim(GetVehicleNumberPlateText(clientVehicle()))
    -- client/compat.lua: exports['qb-vehiclekeys']:HasKeys(plate) asks the server.
    ctx:waitUntil(function() return exports['qb-vehiclekeys']:HasKeys(plate) == (expected == 'yes') end,
        'Client HasKeys did not answer ' .. expected .. ' for ' .. plate, 3000)
end)

K.step('the engine of the vehicle I am driving is running', 'client', function(ctx)
    local vehicle = clientVehicle()
    SetVehicleEngineOn(vehicle, true, true, false)
    ctx:waitUntil(function() return GetIsVehicleEngineRunning(vehicle) end, 'Engine did not start', 3000)
end)
K.step('the engine of the vehicle I am driving should be running', 'client', function(ctx)
    local vehicle = clientVehicle()
    ctx:waitUntil(function() return GetIsVehicleEngineRunning(vehicle) end, 'Engine is not running', 4000)
end)
K.step('the engine of the vehicle I am driving should be off', 'client', function(ctx)
    local vehicle = clientVehicle()
    ctx:waitUntil(function() return not GetIsVehicleEngineRunning(vehicle) end, 'Engine is still running', 5000)
end)
K.step('the engine of the vehicle I am driving should stay off', 'client', function(ctx)
    local vehicle = clientVehicle()
    local deadline = GetGameTimer() + 2000
    while GetGameTimer() < deadline do
        ctx:check()
        Wait(250)
    end
    assert(not GetIsVehicleEngineRunning(vehicle), 'Engine is running without keys')
end)

-- Fires the stock lockpick-use event (client/main.lua `lockpicks:UseLockpick`).
-- Only used where the flow is refused before a minigame is authorised: the
-- scenario first proves the tester holds keys, or holds no lockpick item.
K.step('I use a lockpick on the nearest vehicle', 'client', function(ctx)
    assert(not K.uiState().minigame, 'A minigame is already running')
    TriggerEvent('lockpicks:UseLockpick')
    Wait(750)
    ctx:check()
end)
K.step('no lockpick minigame should have started', 'client', function()
    Wait(500)
    assert(not K.uiState().minigame, 'A lockpick minigame started')
end)

-- ===========================================================================
-- Round 3: plate edges, provided legacy exports/events, server callbacks,
-- on-foot lock and lockpick refusals, trusted owner grants and rate limits.
-- ===========================================================================

-- A per-scenario plate derived from ctx.id, so the client and the server name
-- the same plate without passing it through the game (the same derivation as
-- the kora_garages suite, with a different first letter).
local digits = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local function base36(value, length)
    local out = ''
    for _ = 1, length do
        local index = value % 36
        out = digits:sub(index + 1, index + 1) .. out
        value = value // 36
    end
    return out
end
local function testPlate(ctx)
    local id, a, b = tostring(ctx.id), 5381, 7
    for index = 1, #id do
        local byte = id:byte(index)
        a = (a * 33 + byte) % 2147483647
        b = (b * 131 + byte) % 2147483629
    end
    return 'K' .. base36(a, 4) .. base36(b, 3)
end

-- Server: the live vehicle carrying the scenario's test plate.
local function testCarEntity(ctx)
    local plate = testPlate(ctx)
    return ctx:waitUntil(function()
        for _, vehicle in ipairs(GetAllVehicles()) do
            if DoesEntityExist(vehicle) and trim(GetVehicleNumberPlateText(vehicle)) == plate then return vehicle end
        end
    end, 'The server sees no vehicle carrying the test plate ' .. plate, 5000)
end

-- Client: calls a server callback the way the resource's own client does, but
-- keeps every returned value (kora_lib callback_triggerPacked returns an
-- { n = ..., ... } envelope, so `nil, reason` survives). A rejected call (rate
-- limit, handler error) arrives as { __kora_lib_rejected = true, error }
-- (KoraLibCallbackEnvelope); it is returned as ok = false with the message.
local function callServer(name, ...)
    local args = table.pack(...)
    local ok, packed = pcall(function()
        return exports.kora_lib:callback_triggerPacked(name, table.unpack(args, 1, args.n))
    end)
    if not ok then return false, nil, tostring(packed) end
    if type(packed) == 'table' and packed.__kora_lib_rejected then return false, nil, tostring(packed.error) end
    if type(packed) ~= 'table' then packed = { n = 1, packed } end
    return true, packed
end
local function mustCall(name, ...)
    local ok, packed, err = callServer(name, ...)
    assert(ok, ('%s failed: %s'):format(name, tostring(err)))
    return packed
end

-- Client: the temporary car of this scenario ("I am driving a temporary ..."),
-- still valid after the tester stepped out of it.
local function testCar(ctx)
    local vehicle = ctx.state.vehicle
    assert(vehicle and DoesEntityExist(vehicle), 'There is no temporary test car; drive one first')
    return vehicle
end
local function testCarNetId(ctx)
    local vehicle = testCar(ctx)
    assert(NetworkGetEntityIsNetworked(vehicle), 'The test car is not networked')
    return NetworkGetNetworkIdFromEntity(vehicle)
end

-- ---------------------------------------------------------------------------
-- Server: plate edges and the provided qb-vehiclekeys exports
-- ---------------------------------------------------------------------------

K.step('giving vehicle keys for plate {string} should be refused', 'server', function(ctx, plate)
    local tester = ctx.tester
    ctx:cleanup(function() pcall(function() exports.kora_vehiclekeys:removeKeys(tester, plate) end) end)
    ctx:equal(K.export('kora_vehiclekeys', 'giveKeys', tester, plate), false, 'giveKeys result for "' .. plate .. '"')
end)

-- server/main.lua normalisePlate: a non-string plate normalises to nil, so every
-- export answers false (Kora.vehicle.normalizePlate returns nil for non-strings).
K.step('the vehicle key exports should refuse a plate that is not text', 'server', function(ctx)
    local tester = ctx.tester
    ctx:equal(K.export('kora_vehiclekeys', 'giveKeys', tester, 12345), false, 'giveKeys with a number plate')
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', tester, 12345), false, 'hasKeys with a number plate')
    ctx:equal(K.export('kora_vehiclekeys', 'removeKeys', tester, 12345), false, 'removeKeys with a number plate')
    ctx:equal(exports['qb-vehiclekeys']:HasKeys(tester, 12345), false, 'qb-vehiclekeys HasKeys with a number plate')
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', tester, '12345'), false, 'hasKeys for the text plate "12345"')
end)

-- server/main.lua legacyArgs: stock servers call (id, plate); swapped arguments are tolerated.
K.step('I am given vehicle keys for plate {string} through the legacy export with swapped arguments', 'server', function(ctx, plate)
    local tester = ctx.tester
    ctx:cleanup(function() pcall(function() exports.kora_vehiclekeys:removeKeys(tester, plate) end) end)
    ctx:equal(exports['qb-vehiclekeys']:GiveKeys(plate, tester), true, 'qb-vehiclekeys GiveKeys(plate, id)')
end)
K.step('my vehicle keys for plate {string} are taken away through the legacy export', 'server', function(ctx, plate)
    ctx:equal(exports['qb-vehiclekeys']:RemoveKeys(ctx.tester, plate), true, 'qb-vehiclekeys RemoveKeys(id, plate)')
end)

-- server/main.lua isOnline: a positive whole number with a ped. 65535 is never
-- a connected player id on a dev server with a handful of slots.
K.step('the legacy key exports should refuse player ids that are not online players', 'server', function(ctx)
    local plate = 'FFTBADID'
    for _, id in ipairs({ 0, -1, 1.5, 65535 }) do
        ctx:equal(exports['qb-vehiclekeys']:GiveKeys(id, plate), false, 'GiveKeys for player id ' .. tostring(id))
        ctx:equal(exports['qb-vehiclekeys']:RemoveKeys(id, plate), false, 'RemoveKeys for player id ' .. tostring(id))
        ctx:equal(exports['qb-vehiclekeys']:HasKeys(id, plate), false, 'HasKeys for player id ' .. tostring(id))
    end
    ctx:equal(exports['qb-vehiclekeys']:GiveKeys(tostring(ctx.tester), plate), false, 'GiveKeys with the id as text')
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate), false, 'hasKeys for ' .. plate)
end)

-- server/main.lua currentPlate: GiveKeys(id) without a plate uses the vehicle the player is in.
K.step('the legacy GiveKeys export without a plate gives me the keys of the vehicle I am driving', 'server', function(ctx)
    local tester = ctx.tester
    local _, plate = serverVehicle(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_vehiclekeys:removeKeys(tester, plate) end) end)
    ctx:equal(exports['qb-vehiclekeys']:GiveKeys(tester), true, 'qb-vehiclekeys GiveKeys(id)')
end)
K.step('the legacy GiveKeys export without a plate should refuse me on foot', 'server', function(ctx)
    local ped = GetPlayerPed(ctx.tester)
    assert(GetVehiclePedIsIn(ped, false) == 0, 'The tester is in a vehicle')
    ctx:equal(exports['qb-vehiclekeys']:GiveKeys(ctx.tester), false, 'qb-vehiclekeys GiveKeys(id) on foot')
end)

K.step('I should lose the vehicle keys for plate {string}', 'server', function(ctx, plate)
    ctx:waitUntil(function() return K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate) == false end,
        'Keys for ' .. plate .. ' were not removed', 3000)
end)

-- ---------------------------------------------------------------------------
-- Server: trusted owner grants (Config.TrustedSetOwner) on the driven vehicle
-- ---------------------------------------------------------------------------

K.step('I should be granted the keys of the vehicle I am driving', 'server', function(ctx)
    local tester = ctx.tester
    local _, plate = serverVehicle(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_vehiclekeys:removeKeys(tester, plate) end) end)
    ctx:waitUntil(function() return K.export('kora_vehiclekeys', 'hasKeys', tester, plate) == true end,
        'The server granted no keys for ' .. plate, 5000)
end)
-- client/compat.lua requestGrant retries for about 3.2 s (8 x 400 ms).
K.step('I should not be granted the keys of the vehicle I am driving', 'server', function(ctx)
    local tester = ctx.tester
    local _, plate = serverVehicle(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_vehiclekeys:removeKeys(tester, plate) end) end)
    local deadline = GetGameTimer() + 4000
    while GetGameTimer() < deadline do
        ctx:check()
        assert(K.export('kora_vehiclekeys', 'hasKeys', tester, plate) == false, 'The server granted keys for ' .. plate)
        Wait(250)
    end
end)

-- ---------------------------------------------------------------------------
-- Server: the scenario test plate (carried by the temporary car or a row)
-- ---------------------------------------------------------------------------

K.step('I hold the keys of my vehiclekeys test car', 'server', function(ctx) give(ctx, testPlate(ctx)) end)
K.step('I hold no keys of my vehiclekeys test car', 'server', function(ctx)
    local plate = testPlate(ctx)
    K.export('kora_vehiclekeys', 'removeKeys', ctx.tester, plate)
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate), false, 'hasKeys for ' .. plate)
end)
K.step('I should hold no keys of my vehiclekeys test car', 'server', function(ctx)
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, testPlate(ctx)), false, 'hasKeys for the test plate')
end)
K.step('my vehiclekeys test car should be locked by its keys', 'server', function(ctx)
    local vehicle = testCarEntity(ctx)
    ctx:waitUntil(function() return lockState(vehicle) end, 'Test car lock state is not locked', 3000)
end)
K.step('my vehiclekeys test car should not be locked by its keys', 'server', function(ctx)
    local vehicle = testCarEntity(ctx)
    Wait(500)
    ctx:equal(lockState(vehicle), false, 'Test car lock state')
end)

-- A player_vehicles row for the test plate (kora_core createVehicle, as the
-- kora_garages suite does). Cleanup soft-deletes it (kora_core deleteVehicle).
K.step('my vehiclekeys test plate belongs to an owned vehicle', 'server', function(ctx)
    local tester, plate = ctx.tester, testPlate(ctx)
    ctx:cleanup(function()
        pcall(function() exports.kora_vehiclekeys:removeKeys(tester, plate) end)
        pcall(function() exports.kora_core:deleteVehicle(plate) end)
    end)
    local ok, err = K.export('kora_core', 'createVehicle', K.player(ctx).citizenid, 'blista', plate)
    assert(ok, 'Could not create the owned row for ' .. plate .. ': ' .. tostring(err))
    assert(type(K.export('kora_core', 'getByPlate', plate)) == 'table', 'The owned row for ' .. plate .. ' was not stored')
end)

-- ---------------------------------------------------------------------------
-- Client: the test car, local checks and the provided client surface
-- ---------------------------------------------------------------------------

K.step('my test car carries my vehiclekeys test plate', 'client', function(ctx)
    local vehicle, plate = testCar(ctx), testPlate(ctx)
    SetVehicleNumberPlateText(vehicle, plate)
    ctx:waitUntil(function() return trim(GetVehicleNumberPlateText(vehicle)) == plate end, 'The plate did not change', 2000)
    Wait(500) -- let the plate reach the server through entity sync
end)

K.step('I step out of the vehicle I am driving', 'client', function(ctx)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    assert(vehicle ~= 0, 'The tester is not in a vehicle')
    TaskLeaveVehicle(ped, vehicle, 16)
    ctx:waitUntil(function() return not IsPedInAnyVehicle(PlayerPedId(), false) end, 'Could not leave the vehicle', 5000)
    Wait(300)
end)

-- Moves the tester along the world X axis away from the test car (the car stays).
K.step('I move {int} metres away from my test car', 'client', function(ctx, metres)
    assert(metres >= 1 and metres <= 200, 'Move 1-200 metres')
    assert(not IsPedInAnyVehicle(PlayerPedId(), false), 'Step out of the vehicle first')
    local at = GetEntityCoords(testCar(ctx))
    K.teleport(ctx, at.x + metres, at.y, at.z + 0.5)
end)

K.step('my client key check for plate {string} should say {word}', 'client', function(ctx, plate, expected)
    assert(expected == 'yes' or expected == 'no', 'Use yes or no')
    -- client/compat.lua: false without asking the server for '' or more than 32 characters.
    ctx:waitUntil(function() return exports['qb-vehiclekeys']:HasKeys(plate) == (expected == 'yes') end,
        'Client HasKeys did not answer ' .. expected .. ' for "' .. plate .. '"', 3000)
end)

-- qb-vehiclekeys:server:GetVehicleKeys answers { [plate] = true } for the caller only.
local function keyList()
    local packed = mustCall('qb-vehiclekeys:server:GetVehicleKeys')
    assert(type(packed[1]) == 'table', 'GetVehicleKeys answered ' .. type(packed[1]))
    return packed[1]
end
K.step('the server key list should include plate {string}', 'client', function(_, plate)
    assert(keyList()[plate] == true, 'GetVehicleKeys does not list ' .. plate)
end)
K.step('the server key list should not include plate {string}', 'client', function(_, plate)
    assert(keyList()[plate] == nil, 'GetVehicleKeys lists ' .. plate)
end)

local function ownedAnswer(plate)
    local packed = mustCall('qb-vehiclekeys:server:checkPlayerOwned', plate)
    return packed[1]
end
K.step('the server should say plate {string} is owned by me', 'client', function(ctx, plate)
    ctx:equal(ownedAnswer(plate), true, 'checkPlayerOwned for ' .. plate)
end)
K.step('the server should say plate {string} is not owned by me', 'client', function(ctx, plate)
    ctx:equal(ownedAnswer(plate), false, 'checkPlayerOwned for ' .. plate)
end)
K.step('the server should say my vehiclekeys test plate is owned by me', 'client', function(ctx)
    ctx:equal(ownedAnswer(testPlate(ctx)), true, 'checkPlayerOwned for the test plate')
end)
K.step('the server key checks should answer no for a plate that is not text', 'client', function(ctx)
    ctx:equal(ownedAnswer(12345), false, 'checkPlayerOwned with a number plate')
    ctx:equal(mustCall('kora_vehiclekeys:server:legacyHasKeys', 12345)[1], false, 'legacyHasKeys with a number plate')
    ctx:equal(exports['qb-vehiclekeys']:HasKeys(12345), false, 'client HasKeys with a number plate')
end)

-- client/compat.lua qb-vehiclekeys:client:RemoveKeys -> server RemoveOwnKeys.
K.step('I drop my keys for plate {string} through the legacy client event', 'client', function(_, plate)
    TriggerEvent('qb-vehiclekeys:client:RemoveKeys', plate)
    Wait(300)
end)

-- client/compat.lua: vehiclekeys:client:SetOwner / qb-vehiclekeys:client:AddKeys
-- only ask the server (AcquireVehicleKeys with the network id).
K.step('I claim the keys of the vehicle I am driving with the client event {string}', 'client', function(_, event)
    assert(event == 'vehiclekeys:client:SetOwner' or event == 'qb-vehiclekeys:client:AddKeys', 'Unknown claim event: ' .. event)
    TriggerEvent(event, trim(GetVehicleNumberPlateText(clientVehicle())))
end)
-- server/main.lua resolveAcquireTarget: an older caller may send the plate of the vehicle it is in.
K.step('I claim the keys of the vehicle I am driving by plate through the legacy server event', 'client', function()
    TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', trim(GetVehicleNumberPlateText(clientVehicle())))
end)

-- server/main.lua GiveVehicleKeys ignores the giver as a receiver.
K.step('I hand the keys of the vehicle I am driving to myself through the legacy server event', 'client', function()
    local plate = trim(GetVehicleNumberPlateText(clientVehicle()))
    TriggerServerEvent('qb-vehiclekeys:server:GiveVehicleKeys', { GetPlayerServerId(PlayerId()) }, plate)
    Wait(600)
end)
K.step('I run the givekeys command with my own server id', 'client', function()
    ExecuteCommand('givekeys ' .. GetPlayerServerId(PlayerId()))
    Wait(600)
end)

-- server/main.lua setVehLockState: state >= 2 locks; the event is throttled to
-- one per 500 ms per player, so the step waits that out afterwards.
K.step('I set the lock state of my test car to {int} through the legacy server event', 'client', function(ctx, state)
    TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', testCarNetId(ctx), state)
    Wait(600)
end)

K.step('the doors of my test car should report lock status {int}', 'client', function(ctx, status)
    local vehicle = testCar(ctx)
    ctx:waitUntil(function() return GetVehicleDoorLockStatus(vehicle) == status end,
        ('Door lock status is %d, expected %d'):format(GetVehicleDoorLockStatus(vehicle), status), 3000)
end)
K.step('the doors of my test car should keep lock status {int}', 'client', function(ctx, status)
    Wait(750)
    ctx:equal(GetVehicleDoorLockStatus(testCar(ctx)), status, 'Door lock status')
end)

-- client/stock.lua addNoLockVehicles / removeNoLockVehicles (client-local, advisory).
K.step('the vehicle model {string} is marked as having no lock', 'client', function(ctx, model)
    ctx:cleanup(function() pcall(function() exports['qb-vehiclekeys']:removeNoLockVehicles(model) end) end)
    exports['qb-vehiclekeys']:addNoLockVehicles(model)
end)
K.step('the vehicle model {string} is no longer marked as having no lock', 'client', function(_, model)
    exports['qb-vehiclekeys']:removeNoLockVehicles(model)
end)

K.step('I toggle the engine with the legacy client event', 'client', function()
    TriggerEvent('qb-vehiclekeys:client:ToggleEngine')
end)

-- ---------------------------------------------------------------------------
-- Client: the server callbacks themselves (server/main.lua)
-- ---------------------------------------------------------------------------

local callbacks = {
    toggle = 'kora_vehiclekeys:server:toggleRequested',
    access = 'kora_vehiclekeys:server:accessRequested',
    -- Only called where the server refuses before authorising a minigame: the
    -- scenario first proves the tester holds the keys or holds no lockpick item.
    lockpick = 'kora_vehiclekeys:server:lockpickStarted',
    hotwire = 'kora_vehiclekeys:server:hotwireStarted',
}
local function refusal(ctx, kind, networkId, expected)
    local name = assert(callbacks[kind], 'Use toggle, access, lockpick or hotwire')
    local ok, packed, err = callServer(name, networkId)
    assert(ok, name .. ' failed: ' .. tostring(err))
    assert(packed[1] == nil or packed[1] == false, ('%s was not refused: %s'):format(name, tostring(packed[1])))
    ctx:equal(packed[2], expected, name .. ' refusal')
end

K.step('asking the server to {word} network id {string} should be refused with {string}', 'client', function(ctx, kind, id, expected)
    refusal(ctx, kind, tonumber(id) or id, expected)
end)
K.step('asking the server to {word} my own character should be refused with {string}', 'client', function(ctx, kind, expected)
    refusal(ctx, kind, NetworkGetNetworkIdFromEntity(PlayerPedId()), expected)
end)
K.step('asking the server to {word} my test car should be refused with {string}', 'client', function(ctx, kind, expected)
    refusal(ctx, kind, testCarNetId(ctx), expected)
end)

-- accessRequested answers false (no reason) for every refusal. Polled at most
-- six times, 500 ms apart, so a seat change can reach the server
-- (Config.RateLimits.access allows 20 calls per 10 s).
K.step('the server should answer {word} when I ask for access to my test car', 'client', function(ctx, expected)
    assert(expected == 'yes' or expected == 'no', 'Use yes or no')
    local netId, answer = testCarNetId(ctx), nil
    for attempt = 1, 6 do
        answer = mustCall(callbacks.access, netId)[1]
        if answer == (expected == 'yes') then return end
        if attempt < 6 then ctx:check() Wait(500) end
    end
    ctx:equal(answer, expected == 'yes', 'accessRequested answer')
end)

K.step('asking the server to toggle the lock of my test car should answer {word}', 'client', function(ctx, expected)
    assert(expected == 'locked' or expected == 'unlocked', 'Use locked or unlocked')
    local packed = mustCall(callbacks.toggle, testCarNetId(ctx))
    ctx:equal(packed[1], expected == 'locked', 'toggleRequested answer')
end)

-- Config.RateLimits.toggle = { max = 10, window = 5000 }: the 11th call within
-- 5 s is rejected by kora_lib before the handler runs.
K.step('I toggle the lock of my test car {int} times through the server', 'client', function(ctx, times)
    assert(times >= 1 and times <= 10, 'Toggle 1-10 times')
    local netId, expected = testCarNetId(ctx), nil
    for index = 1, times do
        local packed = mustCall(callbacks.toggle, netId)
        assert(type(packed[1]) == 'boolean', ('Toggle %d was refused: %s'):format(index, tostring(packed[2])))
        if expected ~= nil then ctx:equal(packed[1], expected, 'Lock answer of toggle ' .. index) end
        expected = not packed[1]
    end
end)
K.step('the next lock toggle of my test car should be rejected by the rate limit', 'client', function(ctx)
    local ok, packed, err = callServer(callbacks.toggle, testCarNetId(ctx))
    assert(not ok, 'The toggle was not rate limited: ' .. tostring(packed and packed[1]))
    assert(K.contains(err, 'Callback rate limit exceeded'), 'Unexpected rejection: ' .. tostring(err))
end)
