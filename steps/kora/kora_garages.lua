-- kora_garages: public, job and impound garages (interact box zones + the
-- AppShell app `kora_garages:garage`).
-- No resource hook: the garage zones are kora_lib interact zones, the panel is
-- a kora_lib app and every refusal is a kora_lib notification, so kora_lib's
-- hook drives them. Owned-vehicle fixtures use kora_core's garage exports
-- (createVehicle / impound / getByPlate / deleteVehicle) and authoritative
-- state is read back from player_vehicles through getByPlate.
local K = FFT.kora
if not K then return end
K.feature('kora_garages')

-- One fixture plate per scenario. The client and the server share ctx.id, so
-- both realms derive the same plate without passing it through the UI (the
-- kora_lib app summary does not expose list items). 8 characters, no spaces:
-- kora_garages compares plates with whitespace removed.
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
local function fixturePlate(ctx)
    local id, a, b = tostring(ctx.id), 5381, 7
    for index = 1, #id do
        local byte = id:byte(index)
        a = (a * 33 + byte) % 2147483647
        b = (b * 131 + byte) % 2147483629
    end
    return 'G' .. base36(a, 4) .. base36(b, 3)
end

local function squash(plate) return (tostring(plate or ''):gsub('%s+', '')):upper() end

-- Server: the spawned entity carrying the fixture plate, if any.
local function entityFor(plate)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and squash(GetVehicleNumberPlateText(vehicle)) == plate then return vehicle end
    end
end

local function row(ctx)
    local plate = fixturePlate(ctx)
    local vehicle = K.export('kora_core', 'getByPlate', plate)
    assert(type(vehicle) == 'table', 'The garage test vehicle ' .. plate .. ' has no player_vehicles row')
    return vehicle, plate
end

-- ---------------------------------------------------------------------------
-- Fixtures (server)
-- ---------------------------------------------------------------------------

-- kora_core Core.garage.createVehicle inserts the row with the table default
-- state (garaged). Cleanup removes the spawned entity, the session keys and the
-- row (deleteVehicle is kora_core's soft delete).
K.step('I own a garaged {string} for the garage tests', 'server', function(ctx, model)
    local tester, plate = ctx.tester, fixturePlate(ctx)
    local citizenid = K.player(ctx).citizenid
    assert(K.export('kora_core', 'getShared', 'vehicles', model), 'Unknown shared vehicle model: ' .. model)
    ctx:cleanup(function()
        local entity = entityFor(plate)
        if entity then DeleteEntity(entity) end
        pcall(function() exports.kora_vehiclekeys:removeKeys(tester, plate) end)
        pcall(function() exports.kora_core:deleteVehicle(plate) end)
    end)
    local ok, err = K.export('kora_core', 'createVehicle', citizenid, model, plate)
    assert(ok, 'Could not create the garage test vehicle ' .. plate .. ': ' .. tostring(err))
    local vehicle = row(ctx)
    ctx:equal(vehicle.citizenid, citizenid, 'Owner of the garage test vehicle')
    ctx:equal(vehicle.state, 'garaged', 'Initial state of the garage test vehicle')
end)

-- kora_core Core.garage.impound(plate, fee, lot): what police/tow scripts call.
K.step('my garage test vehicle is impounded for a fee of {int}', 'server', function(ctx, fee)
    local _, plate = row(ctx)
    local ok, err = K.export('kora_core', 'impound', plate, fee, 'impoundlot')
    assert(ok, 'Could not impound ' .. plate .. ': ' .. tostring(err))
    ctx:equal(row(ctx).state, 'impounded', 'State after impounding')
end)

-- Simulates the spawned vehicle being lost (despawned, destroyed and cleaned up)
-- while its row still says it is out.
K.step('my garage test vehicle is removed from the world', 'server', function(ctx)
    local plate = fixturePlate(ctx)
    -- The server reads the plate back from entity sync, which trails the "is ready."
    -- notification by a moment (the same wait as "should be in the world").
    local entity = ctx:waitUntil(function() return entityFor(plate) end,
        'The garage test vehicle ' .. plate .. ' is not in the world', 5000)
    DeleteEntity(entity)
    ctx:waitUntil(function() return not entityFor(plate) end, 'The garage test vehicle was not removed', 3000)
    Wait(1000) -- let the removal reach the tester's client before the next step
end)

-- ---------------------------------------------------------------------------
-- Assertions (server)
-- ---------------------------------------------------------------------------

K.step('my garage test vehicle should be {word}', 'server', function(ctx, state)
    assert(state == 'garaged' or state == 'out' or state == 'impounded', 'Use garaged, out or impounded')
    local seen
    ctx:waitUntil(function()
        seen = row(ctx).state
        return seen == state
    end, ('Garage test vehicle is %s, expected %s'):format(tostring(seen), state), 5000)
end)
K.step('my garage test vehicle should stay {word}', 'server', function(ctx, state)
    Wait(1500)
    ctx:equal(row(ctx).state, state, 'State of the garage test vehicle')
end)
-- Config.RecordGarageId = true (shared/config.lua): storing records the garage.
K.step('my garage test vehicle should be recorded at garage {string}', 'server', function(ctx, garageId)
    ctx:equal(row(ctx).garage_id, garageId, 'garage_id of the garage test vehicle')
end)
K.step('my garage test vehicle should be in the world', 'server', function(ctx)
    local plate = fixturePlate(ctx)
    ctx:waitUntil(function() return entityFor(plate) ~= nil end, 'No spawned vehicle carries plate ' .. plate, 5000)
end)
K.step('my garage test vehicle should not be in the world', 'server', function(ctx)
    local plate = fixturePlate(ctx)
    ctx:waitUntil(function() return entityFor(plate) == nil end, 'A spawned vehicle still carries plate ' .. plate, 5000)
end)
K.step('I should hold the keys of my garage test vehicle', 'server', function(ctx)
    local plate = fixturePlate(ctx)
    ctx:waitUntil(function() return K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate) == true end,
        'No keys were given for ' .. plate, 3000)
end)
K.step('I should hold no keys of my garage test vehicle', 'server', function(ctx)
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, fixturePlate(ctx)), false, 'hasKeys for the garage test vehicle')
end)

-- server/compat.lua exports('getAllGarages'): one entry per enabled Config.garages key.
K.step('the garage directory should list {string} as the {word} garage {string}', 'server', function(_, name, kind, label)
    local garages = K.export('kora_garages', 'getAllGarages')
    assert(type(garages) == 'table', 'getAllGarages returned ' .. type(garages))
    for _, garage in ipairs(garages) do
        if garage.name == name then
            assert(garage.type == kind, ('Garage %s has type %s, expected %s'):format(name, tostring(garage.type), kind))
            assert(garage.label == label, ('Garage %s is labelled "%s", expected "%s"'):format(name, tostring(garage.label), label))
            assert(garage.takeVehicle and garage.spawnPoint, 'Garage ' .. name .. ' has no access or spawn point')
            return
        end
    end
    error('getAllGarages does not list ' .. name, 0)
end)

-- ---------------------------------------------------------------------------
-- Client: the public openGarage export and the vehicle card action
-- ---------------------------------------------------------------------------

-- client/client.lua exports('openGarage'): the same openGarage(id) the zone runs.
-- The server still checks distance, job and duty in `kora_garages:list`.
K.step('I ask to open the garage {string}', 'client', function(ctx, garageId)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('app.close') end) end)
    local ok, err = K.export('kora_garages', 'openGarage', garageId)
    assert(ok == true, 'openGarage refused: ' .. tostring(err))
end)
K.step('asking to open the garage {string} should be refused with {string}', 'client', function(ctx, garageId, message)
    local ok, err = K.export('kora_garages', 'openGarage', garageId)
    ctx:equal(ok, false, 'openGarage result')
    ctx:equal(err, message, 'openGarage refusal')
end)

-- The vehicle card's button: action `garage:use` with the plate as item id.
-- The app takes the vehicle out, stores it or pays its release depending on
-- the row state the server listed.
K.step('I use my garage test vehicle in the garage app', 'client', function(ctx)
    K.must(K.ui('app.action', 'garage:use', { itemId = fixturePlate(ctx) }))
end)
K.step('the garage should announce my garage test vehicle with {string}', 'client', function(ctx, text)
    K.waitNotification(ctx, fixturePlate(ctx) .. ' ' .. text, 12000)
end)

-- Config.spawn.warpIntoVehicle is off, so a vehicle taken out waits in the
-- first free bay of the garage's `spawns` (server/server.lua pickSpawn). Ambient
-- or leftover cars in the near bays push it up to 26 m away, beyond
-- Config.interaction.storeDistance (12 m) of the garage point, and the client's
-- findVehicle then answers "That vehicle is not here." A player drives the car
-- back to the garage before storing it; this seats the tester in the driver
-- seat and moves the car to the given spot with the engine off.
K.step('I drive my garage test vehicle to {float} {float} {float} facing {float}', 'client', function(ctx, x, y, z, heading)
    local plate = fixturePlate(ctx)
    local vehicle = ctx:waitUntil(function()
        for _, candidate in ipairs(GetGamePool('CVehicle')) do
            if squash(GetVehicleNumberPlateText(candidate)) == plate then return candidate end
        end
    end, 'This client does not see the garage test vehicle ' .. plate, 5000)
    local ped = PlayerPedId()
    SetPedIntoVehicle(ped, vehicle, -1)
    ctx:waitUntil(function() return GetPedInVehicleSeat(vehicle, -1) == ped end,
        'The tester did not get into the garage test vehicle', 3000)
    ctx:waitUntil(function()
        NetworkRequestControlOfEntity(vehicle)
        return NetworkHasControlOfEntity(vehicle)
    end, 'The tester has no control of the garage test vehicle', 3000)
    SetVehicleEngineOn(vehicle, false, true, false)
    SetEntityCoords(vehicle, x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
    SetEntityHeading(vehicle, heading + 0.0)
    SetVehicleOnGroundProperly(vehicle)
    local target = vector3(x + 0.0, y + 0.0, z + 0.0)
    ctx:waitUntil(function() return #(GetEntityCoords(vehicle).xy - target.xy) < 1.5 end,
        'The garage test vehicle did not reach the garage', 3000)
    Wait(1000) -- the server checks distances against its synced copy of the positions
end)
-- For a plate the panel does not list: kora_lib may refuse the undeclared item
-- action, or the app's onAction ignores it (`usable[plate]` is nil). Either
-- way nothing may happen, which the following server assertions prove.
K.step('I try to use my unlisted garage test vehicle in the garage app', 'client', function(ctx)
    local ok, err, code = K.ui('app.action', 'garage:use', { itemId = fixturePlate(ctx) })
    assert(ok or code == 'rejected', 'Garage app action failed unexpectedly: ' .. tostring(err))
    Wait(1000)
    ctx:check()
end)

-- ===========================================================================
-- Round 3: every configured garage, the server callbacks driven directly,
-- store validation, gang garages, the stock vehicle list and the property
-- garage registration refusals.
-- ===========================================================================

-- Client: calls a kora_garages callback with every returned value kept
-- (kora_lib callback_triggerPacked envelope { n = ..., ... }). A rejection
-- (rate limit, handler error) arrives as { __kora_lib_rejected = true, error }
-- (kora_lib local/callback/shared.lua KoraLibCallbackEnvelope) and is returned
-- as ok = false with its message.
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
local function expectRefusal(ctx, name, expected, ...)
    local packed = mustCall(name, ...)
    assert(packed[1] == false or packed[1] == nil, ('%s was not refused (answered %s)'):format(name, tostring(packed[1])))
    ctx:equal(packed[2], expected, name .. ' refusal')
end

-- Client: the vehicle carrying the fixture plate, if this client sees one.
local function clientEntityFor(plate)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and squash(GetVehicleNumberPlateText(vehicle)) == plate then return vehicle end
    end
end
local function fixtureNetId(ctx, required)
    local plate = fixturePlate(ctx)
    local entity
    if required then
        entity = ctx:waitUntil(function() return clientEntityFor(plate) end, 'This client sees no vehicle carrying ' .. plate, 5000)
    else
        entity = clientEntityFor(plate)
    end
    return entity and NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or 0
end

-- ---------------------------------------------------------------------------
-- Fixtures (server)
-- ---------------------------------------------------------------------------

-- kora_core Core.garage.spawnVehicle(src, plate, coords, heading): spawns the
-- row as a networked entity and marks it out (what a trusted provider calls).
-- The fixture step's cleanup removes the entity by plate.
K.step('my garage test vehicle is brought out at {float} {float} {float}', 'server', function(ctx, x, y, z)
    local _, plate = row(ctx)
    ctx:cleanup(function()
        local entity = entityFor(plate)
        if entity then DeleteEntity(entity) end
    end)
    local netId, err = K.export('kora_core', 'spawnVehicle', ctx.tester, plate, vector3(x, y, z), 0.0)
    assert(netId, 'Could not bring out ' .. plate .. ': ' .. tostring(err))
    ctx:equal(row(ctx).state, 'out', 'State after bringing the vehicle out')
    ctx:waitUntil(function() return entityFor(plate) ~= nil end, 'The spawned vehicle does not carry ' .. plate, 5000)
end)

-- ---------------------------------------------------------------------------
-- Assertions (server)
-- ---------------------------------------------------------------------------

-- server/server.lua confirmOut -> tagVehicle -> kora_core tagVehicle: the
-- server-only `vehicleid` state bag holds player_vehicles.id.
K.step('my spawned garage test vehicle should carry its player_vehicles id', 'server', function(ctx)
    local vehicle, plate = row(ctx)
    local entity = ctx:waitUntil(function() return entityFor(plate) end, 'No spawned vehicle carries ' .. plate, 5000)
    ctx:equal(Entity(entity).state.vehicleid, math.tointeger(tonumber(vehicle.id)), 'vehicleid state bag')
end)

-- server/compat.lua getAllGarages: blip fields come from Config.garageTypes.
K.step('the garage directory entry {string} should use the {string} blip with sprite {int} and colour {int}', 'server',
    function(ctx, name, blipName, sprite, colour)
        for _, garage in ipairs(K.export('kora_garages', 'getAllGarages') or {}) do
            if garage.name == name then
                ctx:equal(garage.blipName, blipName, 'blipName of ' .. name)
                ctx:equal(garage.blipNumber, sprite, 'blipNumber of ' .. name)
                ctx:equal(garage.blipColor, colour, 'blipColor of ' .. name)
                return
            end
        end
        error('getAllGarages does not list ' .. name, 0)
    end)
K.step('the garage directory entry {string} should bring vehicles out at {float} {float} {float}', 'server',
    function(_, name, x, y, z)
        for _, garage in ipairs(K.export('kora_garages', 'getAllGarages') or {}) do
            if garage.name == name then
                local spawn = garage.spawnPoint
                assert(spawn and math.abs(spawn.x - x) < 0.01 and math.abs(spawn.y - y) < 0.01 and math.abs(spawn.z - z) < 0.01,
                    ('Spawn point of %s is %s'):format(name, tostring(spawn)))
                return
            end
        end
        error('getAllGarages does not list ' .. name, 0)
    end)
K.step('the garage directory should not list {string}', 'server', function(_, name)
    for _, garage in ipairs(K.export('kora_garages', 'getAllGarages') or {}) do
        assert(garage.name ~= name, 'getAllGarages lists ' .. name)
    end
end)

-- server/property.lua RegisterPropertyGarage: each definition below fails one
-- validation rule, so the export returns before any database write.
local okCoords = { x = 1747.0, y = 3273.7, z = 41.6 }
local invalidPropertyGarages = {
    ['not a table'] = function() return 'garage' end,
    ['missing coordinates'] = function() return { slots = 2, spawns = { okCoords } } end,
    ['no capacity'] = function() return { coords = okCoords, spawns = { okCoords } } end,
    ['zero capacity'] = function() return { coords = okCoords, slots = 0, spawns = { okCoords } } end,
    ['fractional capacity'] = function() return { coords = okCoords, slots = 1.5, spawns = { okCoords } } end,
    ['capacity above 1000'] = function() return { coords = okCoords, slots = 1001, spawns = { okCoords } } end,
    ['no spawn'] = function() return { coords = okCoords, slots = 2, spawns = {} } end,
    ['a malformed spawn'] = function() return { coords = okCoords, slots = 2, spawns = { { x = 'a', y = 0, z = 0 } } } end,
    ['capacity owners that are not a list'] = function() return { coords = okCoords, slots = 2, spawns = { okCoords }, capacityOwnerIds = 'ABC123' } end,
    ['an empty capacity owner'] = function() return { coords = okCoords, slots = 2, spawns = { okCoords }, capacityOwnerIds = { '' } } end,
    ['a valid definition'] = function() return { coords = okCoords, slots = 2, spawns = { okCoords } } end,
}
local function policy() return false end
K.step('registering the property garage {string} with {string} should be refused with {string}', 'server',
    function(ctx, id, kind, expected)
        local build = assert(invalidPropertyGarages[kind], 'Unknown property garage definition: ' .. kind)
        -- A valid definition is only allowed for an id the static config already uses.
        assert(kind ~= 'a valid definition' or id == 'legionsquare', 'A valid definition would be stored; use it only with a taken id')
        local ok, err = K.export('kora_garages', 'RegisterPropertyGarage', id, build(), policy)
        ctx:equal(ok, false, 'RegisterPropertyGarage result')
        ctx:equal(err, expected, 'RegisterPropertyGarage refusal')
    end)
K.step('registering the property garage {string} without a policy should be refused with {string}', 'server',
    function(ctx, id, expected)
        local ok, err = K.export('kora_garages', 'RegisterPropertyGarage', id, invalidPropertyGarages['a valid definition'](), nil)
        ctx:equal(ok, false, 'RegisterPropertyGarage result')
        ctx:equal(err, expected, 'RegisterPropertyGarage refusal')
    end)
K.step('unregistering the property garage {string} should be refused with {string}', 'server', function(ctx, id, expected)
    local ok, err = K.export('kora_garages', 'UnregisterPropertyGarage', id)
    ctx:equal(ok, false, 'UnregisterPropertyGarage result')
    ctx:equal(err, expected, 'UnregisterPropertyGarage refusal')
end)

-- ---------------------------------------------------------------------------
-- Client: the server callbacks driven directly (server/server.lua)
-- ---------------------------------------------------------------------------

local function listFixture(ctx, garageId)
    local packed = mustCall('kora_garages:list', garageId)
    assert(type(packed[1]) == 'table', ('kora_garages:list refused %s: %s'):format(garageId, tostring(packed[2])))
    local plate = fixturePlate(ctx)
    for _, vehicle in ipairs(packed[1].vehicles or {}) do
        if squash(vehicle.plate) == plate then return vehicle, packed[1] end
    end
    return nil, packed[1]
end

K.step('listing the garage {string} should be refused with {string}', 'client', function(ctx, garageId, expected)
    expectRefusal(ctx, 'kora_garages:list', expected, garageId)
end)
K.step('listing the garage {string} should describe it as {string} of type {word}', 'client', function(ctx, garageId, label, kind)
    local _, payload = listFixture(ctx, garageId)
    ctx:equal(payload.garage.id, garageId, 'Listed garage id')
    ctx:equal(payload.garage.label, label, 'Listed garage label')
    ctx:equal(payload.garage.type, kind, 'Listed garage type')
end)
K.step('listing the garage {string} should show my garage test vehicle as {word}', 'client', function(ctx, garageId, state)
    local vehicle = listFixture(ctx, garageId)
    assert(vehicle, 'kora_garages:list for ' .. garageId .. ' does not show the garage test vehicle')
    ctx:equal(vehicle.state, state, 'Listed state')
end)
K.step('listing the garage {string} should show my garage test vehicle with a fee of {int}', 'client', function(ctx, garageId, fee)
    local vehicle = listFixture(ctx, garageId)
    assert(vehicle, 'kora_garages:list for ' .. garageId .. ' does not show the garage test vehicle')
    ctx:equal(vehicle.fee, fee, 'Listed impound fee')
end)
K.step('listing the garage {string} should not show my garage test vehicle', 'client', function(ctx, garageId)
    local vehicle = listFixture(ctx, garageId)
    assert(not vehicle, 'kora_garages:list for ' .. garageId .. ' shows the garage test vehicle as ' .. tostring(vehicle and vehicle.state))
end)

-- takeOut claims the plate in pendingOut; cleanup always answers cancelOut,
-- which removes a pending entity and is a no-op otherwise.
local function cancelOnCleanup(ctx)
    if ctx.state.garageCancelRegistered then return end
    ctx.state.garageCancelRegistered = true
    local plate = fixturePlate(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_lib:callback_triggerPacked('kora_garages:cancelOut', plate) end) end)
end
K.step('taking my garage test vehicle out of {string} directly should be refused with {string}', 'client', function(ctx, garageId, expected)
    cancelOnCleanup(ctx)
    expectRefusal(ctx, 'kora_garages:takeOut', expected, garageId, fixturePlate(ctx))
end)
K.step('I start taking my garage test vehicle out of {string} directly', 'client', function(ctx, garageId)
    cancelOnCleanup(ctx)
    local packed = mustCall('kora_garages:takeOut', garageId, fixturePlate(ctx))
    local result = packed[1]
    assert(type(result) == 'table' and math.type(result.netId) == 'integer', 'kora_garages:takeOut refused: ' .. tostring(packed[2]))
    ctx:equal(result.timeout, 10000, 'Take-out timeout (Config.spawn.timeout)')
    ctx.state.garageTakeOut = result
end)
K.step('I cancel taking my garage test vehicle out', 'client', function(ctx)
    ctx:equal(mustCall('kora_garages:cancelOut', fixturePlate(ctx))[1], true, 'kora_garages:cancelOut answer')
end)
K.step('I confirm taking my garage test vehicle out', 'client', function(ctx)
    local result = assert(ctx.state.garageTakeOut, 'Start the take-out first')
    -- client/client.lua waits for the entity before confirming; so does this step.
    ctx:waitUntil(function() return NetworkDoesNetworkIdExist(result.netId) end, 'The taken-out vehicle never reached this client', 8000)
    local packed = mustCall('kora_garages:confirmOut', fixturePlate(ctx), result.netId)
    ctx:equal(packed[1], true, 'kora_garages:confirmOut answer (' .. tostring(packed[2]) .. ')')
end)
K.step('confirming my garage test vehicle out with network id 0 should be refused with {string}', 'client', function(ctx, expected)
    expectRefusal(ctx, 'kora_garages:confirmOut', expected, fixturePlate(ctx), 0)
end)

local function storeArgs(ctx, garageId, fuel, mods)
    return garageId, fixturePlate(ctx), fixtureNetId(ctx, false), fuel, mods
end
K.step('storing my garage test vehicle at {string} directly with fuel {float} should be refused with {string}', 'client',
    function(ctx, garageId, fuel, expected)
        expectRefusal(ctx, 'kora_garages:store', expected, storeArgs(ctx, garageId, fuel))
    end)
K.step('storing my garage test vehicle at {string} directly should be refused', 'client', function(ctx, garageId)
    local packed = mustCall('kora_garages:store', storeArgs(ctx, garageId, 50.0))
    assert(packed[1] ~= true, 'kora_garages:store accepted the vehicle at ' .. garageId)
end)
K.step('I store my garage test vehicle at {string} directly with fuel {float}', 'client', function(ctx, garageId, fuel)
    fixtureNetId(ctx, true)
    local packed = mustCall('kora_garages:store', storeArgs(ctx, garageId, fuel))
    ctx:equal(packed[1], true, 'kora_garages:store answer (' .. tostring(packed[2]) .. ')')
end)
-- server/server.lua store: mods must be nil or a table.
K.step('storing my garage test vehicle at {string} directly with the modifications {string} should be refused with {string}', 'client',
    function(ctx, garageId, mods, expected)
        fixtureNetId(ctx, true)
        expectRefusal(ctx, 'kora_garages:store', expected, storeArgs(ctx, garageId, 50.0, mods))
    end)
-- The fixture plate with the network id of the temporary car the tester drives.
K.step('storing my garage test vehicle at {string} with the car I am driving should be refused with {string}', 'client',
    function(ctx, garageId, expected)
        local vehicle = assert(ctx.state.vehicle, 'Drive a temporary car first')
        expectRefusal(ctx, 'kora_garages:store', expected, garageId, fixturePlate(ctx), NetworkGetNetworkIdFromEntity(vehicle), 50.0)
    end)

-- kora_garages:getGarages answers Config.garages.
K.step('the client garage catalogue should describe {string} as {string} of type {word}', 'client', function(ctx, garageId, label, kind)
    local garages = mustCall('kora_garages:getGarages')[1]
    assert(type(garages) == 'table' and type(garages[garageId]) == 'table', 'kora_garages:getGarages does not include ' .. garageId)
    ctx:equal(garages[garageId].label, label, 'Catalogue label of ' .. garageId)
    ctx:equal(garages[garageId].type, kind, 'Catalogue type of ' .. garageId)
end)

-- server/compat.lua qb-garages:server:GetPlayerVehicles: at most one answer per
-- second per player, so the step waits that out before asking.
local function playerVehicles(ctx)
    Wait(1100)
    ctx:check()
    return mustCall('qb-garages:server:GetPlayerVehicles')[1]
end
K.step('my stock vehicle list should show my garage test vehicle as {string} at {string}', 'client', function(ctx, state, garage)
    local list, plate = playerVehicles(ctx), fixturePlate(ctx)
    assert(type(list) == 'table', 'GetPlayerVehicles answered ' .. type(list))
    for _, vehicle in ipairs(list) do
        if squash(vehicle.plate) == plate then
            ctx:equal(vehicle.state, state, 'Stock state label')
            ctx:equal(vehicle.garage, garage, 'Stock garage label')
            assert(type(vehicle.fullname) == 'string' and vehicle.fullname ~= '', 'Stock fullname is empty')
            return
        end
    end
    error('GetPlayerVehicles does not list ' .. plate, 0)
end)
K.step('asking for my stock vehicle list twice within a second should answer nothing the second time', 'client', function(ctx)
    local first = playerVehicles(ctx)
    assert(type(first) == 'table', 'The first GetPlayerVehicles call answered ' .. type(first))
    local second = mustCall('qb-garages:server:GetPlayerVehicles')[1]
    ctx:equal(second, nil, 'Second GetPlayerVehicles answer')
end)

-- The kora_lib interact selector (garage zones, client/client.lua addZone).
K.step('the garage zone should not offer {string}', 'client', function(ctx, label)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('interact.close') end) end)
    local deadline = GetGameTimer() + 2000
    while GetGameTimer() < deadline do
        ctx:check()
        for _, option in ipairs(K.uiState().interact or {}) do
            assert(option.label ~= label, 'The garage zone offers ' .. label)
        end
        Wait(200)
    end
end)
