-- kora_businesses: the bundled jobs (mechanic, taxi, garbage, tow, recycle).
--
-- Everything here goes through the surfaces a player uses: kora_target options,
-- kora_lib's interact selector, progress bars, dialogs and the recycle buyer's
-- app. kora_businesses has no FFT hook; its job state (taxi handle, tow delay,
-- garbage route, recycle duty) is file-local, so the steps observe it only
-- through vehicles, notifications and server-owned money/items.
-- Values quoted below come from kora_businesses/jobs/*/{shared,client,server}.lua.
local K = FFT.kora
if not K then return end
K.feature('kora_businesses')

-- Interact box zones that hand out and take back job vehicles.
local BAYS = {
    -- jobs/taxi/shared.lua Taxi.parkLocation, jobs/taxi/client.lua options
    taxi = { x = 909.5, y = -177.35, z = 74.22, plate = 'TAXI', giveBack = 'Return Taxi' },
    -- jobs/tow/shared.lua Tow.Locations.vehicle.coords, jobs/tow/client.lua options
    tow = { x = 489.65, y = -1331.82, z = 29.33, plate = 'TOW', giveBack = 'Store Vehicle', holdOff = 5000 },
}
local NEAR = 120.0 -- job vehicles further away than this are someone else's

local function distance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function plateOf(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):gsub('%s+', ''):upper()
end

-- ---------------------------------------------------------------------------
-- Client: job vehicles (taxi `TAXI`, flatbed `TOW`, trash truck `GARBAGE`)
-- ---------------------------------------------------------------------------

local function platedNearby(plate)
    local at = GetEntityCoords(PlayerPedId())
    local found = {}
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if plateOf(vehicle) == plate and distance(GetEntityCoords(vehicle), at) <= NEAR then
            found[#found + 1] = vehicle
        end
    end
    return found
end

-- Vehicles with the plate that appeared after the baseline step ran.
local function newPlated(ctx, plate)
    local baseline = (ctx.state.bizBaseline or {})[plate]
    assert(baseline, ('Note the job vehicles plated "%s" first'):format(plate))
    local list = {}
    for _, vehicle in ipairs(platedNearby(plate)) do
        if not baseline[vehicle] then list[#list + 1] = vehicle end
    end
    return list
end

local function noteBaseline(ctx, plate)
    ctx.state.bizBaseline = ctx.state.bizBaseline or {}
    if ctx.state.bizBaseline[plate] then return end
    local baseline = {}
    for _, vehicle in ipairs(platedNearby(plate)) do baseline[vehicle] = true end
    ctx.state.bizBaseline[plate] = baseline
    -- Safety net only: each scenario hands its vehicle back through the job's
    -- own option (registered later, so it runs before this).
    ctx:cleanup(function()
        for _, vehicle in ipairs(newPlated(ctx, plate)) do
            if DoesEntityExist(vehicle) then
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteVehicle(vehicle)
            end
        end
    end)
end

-- Run this where the vehicle will appear, before asking for one.
K.step('I note the job vehicles plated {string} around me', 'client', function(ctx, plate)
    noteBaseline(ctx, plate)
end)
K.step('I should be driving a job vehicle plated {string}', 'client', function(ctx, plate)
    ctx:waitUntil(function()
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        return vehicle ~= 0 and plateOf(vehicle) == plate and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId()
    end, ('The tester is not driving a vehicle plated "%s"'):format(plate), 10000)
end)
K.step('a new job vehicle plated {string} should appear near me', 'client', function(ctx, plate)
    ctx:waitUntil(function() return #newPlated(ctx, plate) > 0 end,
        ('No new vehicle plated "%s" appeared'):format(plate), 10000)
end)
K.step('no new job vehicle plated {string} should remain near me', 'client', function(ctx, plate)
    ctx:waitUntil(function() return #newPlated(ctx, plate) == 0 end,
        ('A vehicle plated "%s" is still out'):format(plate), 8000)
end)
K.step('no new job vehicle plated {string} should be issued to me', 'client', function(ctx, plate)
    Wait(2500)
    ctx:equal(#newPlated(ctx, plate), 0, ('New vehicles plated "%s"'):format(plate))
    assert(not IsPedInAnyVehicle(PlayerPedId(), false), 'The tester was left in a vehicle')
end)

-- ---------------------------------------------------------------------------
-- Client: taxi rank and tow yard bays (kora_lib interact box zones)
-- ---------------------------------------------------------------------------

-- The selector opens when the ped enters the zone (kora_lib interact `onEnter`),
-- so this always leaves and re-enters. The issued vehicle is parked on the zone
-- itself; collision with it is switched off so the ped can stand inside it.
local function enterBay(ctx, bay)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then
        ClearPedTasksImmediately(ped)
        ped = PlayerPedId()
    elseif not ctx.state.teleported then
        K.teleport(ctx, bay.x, bay.y, bay.z) -- records the origin and restores it afterwards
    end
    for _, parked in ipairs(platedNearby(bay.plate)) do
        SetEntityNoCollisionEntity(ped, parked, false)
        SetEntityNoCollisionEntity(parked, ped, false)
    end
    pcall(function() exports.kora_lib:fftAction('interact.close') end)
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, bay.x, bay.y, bay.z + 8.0, false, false, false)
    Wait(1000)
    SetEntityCoordsNoOffset(ped, bay.x, bay.y, bay.z, false, false, false)
    FreezeEntityPosition(ped, false)
end

-- Hands the vehicle back through the bay's own option, which is the only path
-- that clears the job's client state (and, for tow, the server's driver entry).
local function giveBack(ctx, bay)
    if #newPlated(ctx, bay.plate) == 0 then return end
    enterBay(ctx, bay)
    local deadline = GetGameTimer() + 3000
    while GetGameTimer() < deadline do
        local called, chosen = pcall(K.ui, 'interact.select', bay.giveBack)
        if not called or chosen then break end
        Wait(100)
    end
    pcall(function() exports.kora_lib:fftAction('interact.close') end)
end

local function bayStep(name)
    local bay = BAYS[name]
    return function(ctx)
        if not ctx.state['bizBay:' .. name] then
            ctx.state['bizBay:' .. name] = true
            noteBaseline(ctx, bay.plate)
            ctx:cleanup(function() giveBack(ctx, bay) end)
            if bay.holdOff then
                -- Runs before giveBack: the tow options stay hidden for 5 s after
                -- a pull-out (jobs/tow/client.lua `delayed`).
                ctx:cleanup(function()
                    if #newPlated(ctx, bay.plate) > 0 then Wait(bay.holdOff - 500) end
                end)
            end
        end
        enterBay(ctx, bay)
        ctx:waitUntil(function() return K.uiState().interact end, 'The bay selector did not open', 5000)
    end
end

K.step('I walk into the taxi rank bay', 'client', bayStep('taxi'))
K.step('I walk into the tow yard bay', 'client', bayStep('tow'))

-- ---------------------------------------------------------------------------
-- Client: mechanic services on a throwaway vehicle
-- ---------------------------------------------------------------------------

local function testVehicle(ctx)
    local vehicle = ctx.state.bizVehicle
    assert(vehicle and DoesEntityExist(vehicle), 'Park a damaged test vehicle first')
    return vehicle
end

-- Networked, because the server resolves the vehicle by net id and checks its
-- position (jobs/mechanic/server.lua getVehicle / nearGarage). Parked side-on
-- 2.6 m away: inside Mechanic.interaction.distance (3.0), measured by the
-- server from the ped to the vehicle origin.
-- In front first, then right, left and behind: in the Burton bay the spot in
-- front is under a lift, and a vehicle spawned there was pushed up onto it
-- (3.4 m above the ped, so every permit was "Move closer to a valid vehicle").
-- A spot is kept only when the vehicle settles on the ped's floor within reach.
local PARK_SIDES = { 0.0, -90.0, 90.0, 180.0 }
local function deleteVehicle(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end
end

K.step('a damaged test vehicle is parked in front of me', 'client', function(ctx)
    local hash = GetHashKey('blista')
    RequestModel(hash)
    ctx:waitUntil(function() return HasModelLoaded(hash) end, 'Vehicle model did not load', 10000)
    local ped = PlayerPedId()
    local origin, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    local vehicle, placed
    ctx:cleanup(function() deleteVehicle(ctx.state.bizVehicle) end)
    for _, side in ipairs(PARK_SIDES) do
        ctx:check()
        local angle = math.rad(heading + side)
        local x, y = origin.x - math.sin(angle) * 2.6, origin.y + math.cos(angle) * 2.6
        vehicle = CreateVehicle(hash, x, y, origin.z - 0.4, heading + side + 90.0, true, false)
        assert(vehicle and vehicle ~= 0, 'Vehicle did not spawn')
        ctx.state.bizVehicle = vehicle
        SetVehicleOnGroundProperly(vehicle)
        Wait(400)
        local at = GetEntityCoords(vehicle)
        local reach = #(vector2(at.x, at.y) - vector2(origin.x, origin.y))
        if math.abs(at.z - (origin.z - 0.4)) <= 1.0 and reach <= 2.9 then
            placed = true
            break
        end
        deleteVehicle(vehicle)
        ctx.state.bizVehicle = nil
    end
    SetModelAsNoLongerNeeded(hash)
    assert(placed, 'No free floor within 2.6 m of the tester for the test vehicle')
    SetEntityHeading(ped, GetHeadingFromVector_2d(GetEntityCoords(vehicle).x - origin.x, GetEntityCoords(vehicle).y - origin.y))
    SetVehicleEngineHealth(vehicle, 300.0)
    SetVehicleBodyHealth(vehicle, 400.0)
    ctx:waitUntil(function()
        if not NetworkGetEntityIsNetworked(vehicle) then NetworkRegisterEntityAsNetworked(vehicle) end
        return NetworkGetEntityIsNetworked(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) ~= 0
    end, 'The test vehicle was not networked', 6000)
    Wait(1000) -- let the server see the entity before a permit is requested
end)

-- The mechanic options are an addGlobalType('vehicle') registration
-- (jobs/mechanic/client.lua registerTargets), for which kora_target's FFT
-- `locate` reports no aim points, so K.target's aimer cannot turn the camera
-- here. Look over the vehicle body (centre, then towards each end and lower)
-- until kora_target reports the test vehicle under the crosshair.
local VEHICLE_AIMS = {
    { 0.0, 0.0, 0.0 }, { 0.0, 0.0, -0.3 }, { 0.0, 0.8, 0.0 }, { 0.0, -0.8, 0.0 },
    { 0.0, 0.0, 0.3 }, { 0.0, 1.4, -0.2 }, { 0.0, -1.4, -0.2 }, { 0.0, 0.0, -0.5 },
}
local function faceTestVehicle(ctx)
    local vehicle = testVehicle(ctx)
    local started = false
    for _, offset in ipairs(VEHICLE_AIMS) do
        ctx:check()
        local at = GetOffsetFromEntityInWorldCoords(vehicle, offset[1], offset[2], offset[3])
        K.aimAt(at.x, at.y, at.z)
        Wait(150)
        if not started then
            local err
            started, err = exports.kora_target:fftAction('start')
            -- Blocked (downed, busy, locked): every further aim would wait 0.5 s
            -- for nothing and push the step past its 15 s limit.
            if not started then error(err or 'Targeting is blocked', 0) end
        end
        if started then
            Wait(150)
            local hover = exports.kora_target:fftAction('hovering')
            if hover and hover.entity == vehicle then return true end
        end
    end
    -- Leave the camera on the centre; the caller reports what it sees.
    local at = GetEntityCoords(vehicle)
    K.aimAt(at.x, at.y, at.z)
    Wait(150)
    return false
end

K.step('I service the test vehicle with {string}', 'client', function(ctx, label)
    faceTestVehicle(ctx)
    K.target(ctx, label, testVehicle(ctx))
end)

-- Other resources may add their own vehicle options, so this checks the label
-- rather than requiring that nothing is offered. A single visible option is
-- read from the crosshair; several are read from the selector, which is closed
-- again without choosing anything.
K.step('the test vehicle should not offer {string}', 'client', function(ctx, label)
    local vehicle = testVehicle(ctx)
    faceTestVehicle(ctx)
    local function stop()
        pcall(function() exports.kora_target:fftAction('stop') end)
        pcall(function() exports.kora_lib:fftAction('interact.close') end)
    end
    ctx:cleanup(stop)
    K.must(exports.kora_target:fftAction('start'))
    Wait(1200)
    local hover = exports.kora_target:fftAction('hovering')
    if not hover or hover.entity ~= vehicle then stop() return end
    if (hover.optionCount or 1) == 1 then
        stop()
        assert(hover.label ~= label, 'The vehicle offers ' .. label)
        return
    end
    -- Releasing with several options opens the selector instead of running one.
    exports.kora_target:fftAction('select', label, vehicle)
    local offered = false
    local deadline = GetGameTimer() + 1500
    while GetGameTimer() < deadline do
        local options = K.uiState().interact
        if options then
            for _, option in ipairs(options) do if option.label == label then offered = true end end
            break
        end
        Wait(50)
    end
    stop()
    assert(not offered, 'The vehicle offers ' .. label)
end)

K.step('the test vehicle engine health should be at least {int}', 'client', function(ctx, health)
    local vehicle = testVehicle(ctx)
    ctx:waitUntil(function() return GetVehicleEngineHealth(vehicle) >= health - 0.5 end,
        ('Engine health is %.0f, expected at least %d'):format(GetVehicleEngineHealth(vehicle), health), 5000)
end)
K.step('the test vehicle engine health should be below {int}', 'client', function(ctx, health)
    Wait(1000)
    local actual = GetVehicleEngineHealth(testVehicle(ctx))
    assert(actual < health, ('Engine health is %.0f, expected below %d'):format(actual, health))
end)
K.step('the test vehicle should be painted {int} and {int}', 'client', function(ctx, primary, secondary)
    local vehicle = testVehicle(ctx)
    ctx:waitUntil(function()
        local first, second = GetVehicleColours(vehicle)
        return first == primary and second == secondary
    end, 'The test vehicle was not resprayed', 5000)
end)

-- ---------------------------------------------------------------------------
-- Client: recycle centre
-- ---------------------------------------------------------------------------

-- kora_lib answers an app action with { ok, result = { notice } }; accept a
-- bare result too so the step survives a hook contract change.
K.step('the recycling buyer should answer with a {string} notice containing {string}', 'client', function(ctx, tone, text)
    local result = ctx.state.appResult
    local inner = type(result) == 'table' and (type(result.result) == 'table' and result.result or result) or {}
    local notice = inner.notice
    assert(type(notice) == 'table', 'The recycling buyer returned no notice')
    ctx:equal(notice.tone, tone, 'Notice tone')
    assert(K.contains(notice.message, text),
        ('Notice is "%s", expected it to contain "%s"'):format(tostring(notice.message), text))
end)

-- Recycle duty is a client-local flag with no way to read it, so the scenario
-- toggles twice and checks that both messages appeared, in whichever order the
-- tester's starting state gives. That also leaves the flag as it was found.
K.step('I should have clocked in and out of the recycling centre once each', 'client', function(ctx)
    ctx:waitUntil(function()
        local clockedIn, clockedOut = 0, 0
        for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            if K.contains(entry.message, 'You Have Clocked In') then clockedIn = clockedIn + 1 end
            if K.contains(entry.message, 'You Have Clocked Out') then clockedOut = clockedOut + 1 end
        end
        return clockedIn == 1 and clockedOut == 1
    end, 'Expected one clock-in and one clock-out notification', 5000)
end)

-- ===========================================================================
-- Round 3: server callbacks and net events driven directly as the tester.
--
-- These steps call kora_businesses' own Kora callbacks and server events with
-- the names the job clients use (jobs/*/client.lua). Every answer is the
-- server's own: the callback's return values, or for net events the server's
-- notification, the tester's money/items, and the vehicle state it orders the
-- client to apply. Positions are always truthful (the ped is teleported first).
-- Paths labelled "server protocol" reproduce the job client's call sequence
-- without its vehicle props; they never skip a server check.
-- ===========================================================================

-- kora_lib callback_triggerPacked keeps every return value (a leading nil too).
-- A handler that raises (an assert in jobs/tow/server.lua, for example) comes
-- back as `{ __kora_lib_rejected = true, error = message }` (kora_lib
-- local/callback/shared.lua KoraLibCallbackEnvelope): raising inside the
-- export would lose the message at the export boundary.
local function callServer(name, ...)
    local args = table.pack(...)
    local ok, packed = pcall(function()
        return exports.kora_lib:callback_triggerPacked(name, table.unpack(args, 1, args.n))
    end)
    if not ok then return { raised = true, err = tostring(packed), n = 0 } end
    packed = type(packed) == 'table' and packed or { n = 0 }
    if packed.__kora_lib_rejected then return { raised = true, err = tostring(packed.error), n = 0 } end
    return { raised = false, n = packed.n or 0, packed[1], packed[2] }
end

local function remember(ctx, answer)
    ctx.state.bizCall = answer
    return answer
end

local function lastCall(ctx)
    local answer = ctx.state.bizCall
    assert(answer, 'Call a kora_businesses callback first')
    return answer
end

local function describe(answer)
    if answer.raised then return 'raised: ' .. answer.err end
    return ('answered %s, %s'):format(tostring(answer[1]), tostring(answer[2]))
end

-- Whether the server holds a tow job for the tester (jobs/tow/server.lua
-- towDrivers[source]): set when TakeOutVehicle hands one out, cleared when
-- ReturnVehicle answers true. The cleanup only returns a job that is out, as
-- every ReturnVehicle without one asserts and prints a SCRIPT ERROR.
local function trackTow(ctx, name, answer)
    if answer.raised then return answer end
    if name == 'qb-tow:server:TakeOutVehicle' and type(answer[1]) == 'table' then ctx.state.bizTowOut = true end
    if name == 'qb-tow:server:ReturnVehicle' and answer[1] == true then ctx.state.bizTowOut = false end
    return answer
end

K.step('I call the kora_businesses callback {string}', 'client', function(ctx, name)
    remember(ctx, trackTow(ctx, name, callServer(name)))
end)

-- The doc string is a JSON array of the callback's arguments.
K.step('I call the kora_businesses callback {string} with:', 'client', function(ctx, name, argument)
    local args = K.json(argument)
    assert(type(args) == 'table', 'The doc string must be a JSON array of arguments')
    remember(ctx, trackTow(ctx, name, callServer(name, table.unpack(args))))
end)

-- jobs/tow/server.lua refuses with assert(): the handler's message reaches the
-- caller, and the init.lua callback wrapper prints it as a SCRIPT ERROR on
-- kora_businesses' console while kora_lib logs "handler ... errored: <message>".
-- Declares both lines; the text is the assert message (jobs/tow/server.lua:9-56).
K.step('the tow server will refuse on the console with {string}', 'server', function(ctx, text)
    K.expectConsoleError(ctx, text, 'kora_businesses')
    K.expectConsoleError(ctx, text, 'kora_lib')
end)

K.step('the kora_businesses callback should answer false', 'client', function(ctx)
    local answer = lastCall(ctx)
    assert(not answer.raised and answer[1] == false, 'Expected false, ' .. describe(answer))
end)
K.step('the kora_businesses callback should answer nothing', 'client', function(ctx)
    local answer = lastCall(ctx)
    assert(not answer.raised and answer[1] == nil, 'Expected nil, ' .. describe(answer))
end)
K.step('the kora_businesses callback should answer true', 'client', function(ctx)
    local answer = lastCall(ctx)
    assert(not answer.raised and answer[1] == true, 'Expected true, ' .. describe(answer))
end)
K.step('the kora_businesses callback should answer an empty list', 'client', function(ctx)
    local answer = lastCall(ctx)
    assert(not answer.raised and type(answer[1]) == 'table' and next(answer[1]) == nil, 'Expected {}, ' .. describe(answer))
end)
-- `false, reason` and `nil, reason` refusals.
K.step('the kora_businesses callback should refuse with {string}', 'client', function(ctx, text)
    local answer = lastCall(ctx)
    assert(not answer.raised and not answer[1], 'Expected a refusal, ' .. describe(answer))
    assert(K.contains(answer[2], text), ('Refusal is "%s", expected "%s"'):format(tostring(answer[2]), text))
end)
-- Handler asserts: the caller sees the raised message (kora_lib only logs it
-- with its own "[kora_lib:callback]" prefix, which is not a console error).
K.step('the kora_businesses callback should fail with {string}', 'client', function(ctx, text)
    local answer = lastCall(ctx)
    assert(answer.raised, 'Expected the callback to raise, ' .. describe(answer))
    assert(K.contains(answer.err, text), ('Raised "%s", expected "%s"'):format(answer.err, text))
end)

-- ---------------------------------------------------------------------------
-- Mechanic permits (jobs/mechanic/server.lua 'kora_businesses:mechanic:permit'
-- and the 'kora_businesses:server:serviceCompleted' net event)
-- ---------------------------------------------------------------------------

K.step('I request a {string} service permit for the test vehicle', 'client', function(ctx, action)
    local netId = NetworkGetNetworkIdFromEntity(testVehicle(ctx))
    local answer = remember(ctx, callServer('kora_businesses:mechanic:permit', action, netId))
    if answer[1] == true then ctx.state.bizPermit = answer[2] end
end)

K.step('I request a {string} service permit for vehicle network id {int}', 'client', function(ctx, action, netId)
    remember(ctx, callServer('kora_businesses:mechanic:permit', action, netId))
end)

K.step('the service permit should be granted', 'client', function(ctx)
    local answer = lastCall(ctx)
    assert(not answer.raised and answer[1] == true, 'Expected a permit, ' .. describe(answer))
    assert(type(answer[2]) == 'string' and answer[2] ~= '', 'The permit id is empty')
end)

local function completeService(permitId, argument)
    local payload = argument and K.json(argument) or nil
    TriggerServerEvent('kora_businesses:server:serviceCompleted', permitId, payload)
end

K.step('I complete the vehicle service with the permit {string} and:', 'client', function(_, permitId, argument)
    completeService(permitId, argument)
end)
K.step('I complete the vehicle service with my permit and:', 'client', function(ctx, argument)
    completeService(assert(ctx.state.bizPermit, 'Request a service permit first'), argument)
end)
K.step('I complete the vehicle service with my permit', 'client', function(ctx)
    completeService(assert(ctx.state.bizPermit, 'Request a service permit first'), nil)
end)

K.step('I note the test vehicle paint', 'client', function(ctx)
    local primary, secondary = GetVehicleColours(testVehicle(ctx))
    ctx.state.bizPaint = { primary, secondary }
end)
K.step('the test vehicle paint should be unchanged', 'client', function(ctx)
    local noted = assert(ctx.state.bizPaint, 'Note the test vehicle paint first')
    Wait(1500) -- a wrongly applied respray arrives as a client event within this window
    local primary, secondary = GetVehicleColours(testVehicle(ctx))
    ctx:equal(primary, noted[1], 'Primary paint')
    ctx:equal(secondary, noted[2], 'Secondary paint')
end)
K.step('the test vehicle body health should be at least {int}', 'client', function(ctx, health)
    local vehicle = testVehicle(ctx)
    ctx:waitUntil(function() return GetVehicleBodyHealth(vehicle) >= health - 0.5 end,
        ('Body health is %.0f, expected at least %d'):format(GetVehicleBodyHealth(vehicle), health), 5000)
end)
K.step('the test vehicle body health should be below {int}', 'client', function(ctx, health)
    Wait(1000)
    local actual = GetVehicleBodyHealth(testVehicle(ctx))
    assert(actual < health, ('Body health is %.0f, expected below %d'):format(actual, health))
end)
K.step('the test vehicle should have stock bumpers', 'client', function(ctx)
    local vehicle = testVehicle(ctx)
    SetVehicleModKit(vehicle, 0)
    ctx:equal(GetVehicleMod(vehicle, 1), -1, 'Front bumper mod')
    ctx:equal(GetVehicleMod(vehicle, 2), -1, 'Rear bumper mod')
end)

-- Bursts one tyre by GTA wheel index (0 front left, 1 front right, 4 rear left,
-- 5 rear right). jobs/mechanic/client.lua fixOneTyre repairs the first burst
-- tyre it finds while stabilising.
K.step('the test vehicle has a burst tyre at wheel index {int}', 'client', function(ctx, index)
    local vehicle = testVehicle(ctx)
    SetVehicleTyresCanBurst(vehicle, true)
    SetVehicleTyreBurst(vehicle, index, true, 1000.0)
    ctx:waitUntil(function() return IsVehicleTyreBurst(vehicle, index, false) end, 'The tyre did not burst', 3000)
end)
K.step('the test vehicle tyre at wheel index {int} should not be burst', 'client', function(ctx, index)
    local vehicle = testVehicle(ctx)
    ctx:waitUntil(function() return not IsVehicleTyreBurst(vehicle, index, false) end,
        ('Tyre %d is still burst'):format(index), 5000)
end)

-- ---------------------------------------------------------------------------
-- Taxi (jobs/taxi/server.lua)
-- ---------------------------------------------------------------------------

-- jobs/taxi/shared.lua Taxi.PickUp / Taxi.DropOffs are not copied here: the
-- answer is checked for shape (two distinct vector positions).
K.step('the taxi server should hand me a pickup and a drop-off', 'client', function(ctx)
    local answer = lastCall(ctx)
    assert(not answer.raised and type(answer[1]) == 'table', 'Expected a fare, ' .. describe(answer))
    local pickup, dropoff = answer[1].pickup, answer[1].dropoff
    for name, point in pairs({ pickup = pickup, dropoff = dropoff }) do
        assert(point and tonumber(point.x) and tonumber(point.y) and tonumber(point.z), 'The fare has no ' .. name .. ' position')
    end
    assert(pickup.x ~= dropoff.x or pickup.y ~= dropoff.y, 'Pickup and drop-off are the same place')
end)

-- ---------------------------------------------------------------------------
-- Tow (jobs/tow/server.lua; positions from jobs/tow/shared.lua)
-- ---------------------------------------------------------------------------

local TOW_YARD = { x = 489.65, y = -1331.82, z = 29.33 } -- Tow.Locations.vehicle.coords
-- Tow.Locations.towspots[i].coords, in config order.
local TOW_SPOTS = {
    { -2480.87, -211.96, 17.39 }, { -2723.39, 13.20, 15.13 }, { -3169.62, 976.18, 15.04 }, { -3139.76, 1078.72, 20.19 },
    { -1656.94, -246.16, 54.51 }, { -1586.66, -647.56, 29.44 }, { -1036.15, -491.06, 36.21 }, { -1029.19, -475.53, 36.42 },
    { 75.21, 164.85, 104.69 }, { -534.60, -756.72, 31.60 }, { 487.24, -30.83, 88.86 }, { -772.20, -1281.81, 4.56 },
    { -663.84, -1206.99, 10.17 }, { 719.12, -767.78, 24.89 }, { -970.95, -2410.45, 13.34 }, { -1067.52, -2571.41, 13.21 },
    { -619.24, -2207.29, 5.57 }, { 1192.08, -1336.91, 35.11 }, { -432.81, -2166.05, 9.89 }, { -451.82, -2269.35, 7.17 },
    { 939.27, -2197.54, 30.55 }, { -556.11, -1794.73, 22.04 }, { 591.74, -2628.22, 5.57 }, { 1654.52, -2535.83, 74.49 },
    { 1642.61, -2413.32, 93.14 }, { 1371.32, -2549.53, 47.58 }, { 383.84, -1652.87, 37.28 }, { 27.22, -1030.88, 29.41 },
    { 229.26, -365.91, 43.75 }, { -85.81, -51.67, 61.11 }, { -4.60, -670.27, 31.86 }, { -111.90, 91.97, 71.08 },
    { -314.26, -698.23, 32.55 }, { -366.91, 115.54, 65.58 }, { -592.07, 138.21, 60.07 }, { -1613.86, 18.76, 61.80 },
    { -1709.80, 55.11, 65.71 }, { -521.89, -266.78, 34.94 }, { -451.09, -333.52, 34.02 }, { 322.36, -1900.50, 25.77 },
}

-- Polls a callback until `accept(answer)` holds; the server sees a teleport a
-- moment after the client does.
local function pollServer(ctx, timeout, accept, name, ...)
    local args = table.pack(...)
    local answer
    ctx:waitUntil(function()
        answer = callServer(name, table.unpack(args, 1, args.n))
        return accept(answer)
    end, name .. ' never gave the expected answer', timeout, function() return ' | last: ' .. describe(answer or { n = 0 }) end)
    return remember(ctx, answer)
end

-- The tow job's server state ends only through ReturnVehicle at the yard
-- (towDrivers[source] = nil, keys removed), so cleanup goes back there.
local function returnTowAtYard(ctx)
    if not ctx.state.bizTowOut then return end
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, TOW_YARD.x, TOW_YARD.y, TOW_YARD.z, false, false, false)
    Wait(1200) -- the server checks the ped is within 10 m of the yard
    local deadline = GetGameTimer() + 3000
    while GetGameTimer() < deadline do
        local answer = callServer('qb-tow:server:ReturnVehicle')
        if answer.raised and K.contains(answer.err, 'does not have a tow vehicle out') then break end
        if answer[1] == true then break end
        Wait(800)
    end
    ctx.state.bizTowOut = false
end

-- Safety net for refusal scenarios: if the server wrongly issues a tow job,
-- it is handed back at the yard afterwards.
K.step('any tow job issued to me is handed back afterwards', 'client', function(ctx)
    ctx:cleanup(function() returnTowAtYard(ctx) end)
end)

-- Server protocol of jobs/tow/client.lua: TakeOutVehicle at the yard.
-- Waits before asking: every early call asserts "too far" (a SCRIPT ERROR).
K.step('I take out a tow job through the server protocol', 'client', function(ctx)
    K.teleport(ctx, TOW_YARD.x, TOW_YARD.y, TOW_YARD.z)
    ctx:cleanup(function() returnTowAtYard(ctx) end)
    Wait(1200)
    local answer = pollServer(ctx, 6000, function(a)
        return not (a.raised and K.contains(a.err, 'too far from the vehicle location'))
    end, 'qb-tow:server:TakeOutVehicle')
    trackTow(ctx, 'qb-tow:server:TakeOutVehicle', answer)
    assert(not answer.raised and type(answer[1]) == 'table', 'No tow job was issued: ' .. describe(answer))
    local location = tonumber(answer[1].location)
    assert(location and TOW_SPOTS[location], 'The tow job has no configured tow spot: ' .. tostring(answer[1].location))
    ctx:equal(answer[1].droppedOff, 0, 'Vehicles dropped off')
    ctx:equal(answer[1].hasPickedUp, false, 'Picked up')
    ctx.state.bizTowSpot = location
end)

K.step('I go to my tow spot and pick up the vehicle through the server protocol', 'client', function(ctx)
    local spot = TOW_SPOTS[assert(ctx.state.bizTowSpot, 'Take out a tow job first')]
    K.teleport(ctx, spot[1], spot[2], spot[3])
    pollServer(ctx, 10000, function(a) return not a.raised and a[1] == true end, 'qb-tow:server:pickUp')
end)

K.step('I drop the vehicle at the tow yard through the server protocol', 'client', function(ctx)
    K.teleport(ctx, TOW_YARD.x, TOW_YARD.y, TOW_YARD.z)
    Wait(1200) -- every early call asserts "too far from the tow yard" (a SCRIPT ERROR)
    local answer = pollServer(ctx, 10000, function(a)
        return not (a.raised and K.contains(a.err, 'too far from the tow yard'))
    end, 'qb-tow:server:DropOff')
    assert(not answer.raised and type(answer[1]) == 'table', 'Drop-off refused: ' .. describe(answer))
    ctx:equal(answer[1].droppedOff, 1, 'Vehicles dropped off')
    ctx:equal(answer[1].hasPickedUp, false, 'Picked up after drop-off')
end)

K.step('I stand at a tow spot other than mine', 'client', function(ctx)
    local mine = assert(ctx.state.bizTowSpot, 'Take out a tow job first')
    local yard = vector3(TOW_YARD.x, TOW_YARD.y, TOW_YARD.z)
    for index, spot in ipairs(TOW_SPOTS) do
        local mineAt = TOW_SPOTS[mine]
        local here = vector3(spot[1], spot[2], spot[3])
        -- more than 10 m (the server's pickUp radius) from my spot and the yard
        if index ~= mine and #(here - vector3(mineAt[1], mineAt[2], mineAt[3])) > 50.0 and #(here - yard) > 50.0 then
            K.teleport(ctx, spot[1], spot[2], spot[3])
            Wait(1500) -- let the server see the new position
            return
        end
    end
    error('No other tow spot is far enough away')
end)

-- ---------------------------------------------------------------------------
-- Garbage (jobs/garbage/server.lua; positions from jobs/garbage/shared.lua)
-- ---------------------------------------------------------------------------

local DEPOT = { x = -313.84, y = -1522.82, z = 27.56 } -- Garbage.Locations.main
local TRUCK_SPAWN = { x = -333.84, y = -1527.28, z = 27.28, h = 1.97 } -- Garbage.Locations.vehicle[1]
-- Garbage.Locations.trashcan[i].coords (x, y, z), in config order.
local TRASHCANS = {
    { -168.07, -1662.8, 33.31 }, { 118.06, -1943.96, 20.43 }, { 297.94, -2018.26, 20.49 }, { 424.98, -1523.57, 29.28 },
    { 488.49, -1284.1, 29.24 }, { 307.47, -1033.6, 29.03 }, { 239.19, -681.5, 37.15 }, { 543.51, -204.41, 54.16 },
    { 268.72, -25.92, 73.36 }, { 267.03, 276.01, 105.54 }, { 21.65, 375.44, 112.67 }, { -546.9, 286.57, 82.85 },
    { -683.23, -169.62, 37.74 }, { -771.02, -218.06, 37.05 }, { -1057.06, -515.45, 35.83 }, { -1558.64, -478.22, 35.18 },
    { -1350.0, -895.64, 13.36 }, { -1243.73, -1359.72, 3.93 }, { -845.87, -1113.07, 6.91 }, { -635.21, -1226.45, 11.8 },
    { -587.74, -1739.13, 22.47 },
}

-- qb-garbagejob:cancel deletes the registered truck and clears the route; it
-- answers true even without a route, so it is safe to run unconditionally.
local function cancelGarbage()
    callServer('qb-garbagejob:cancel')
end

K.step('I start a garbage route through the server protocol', 'client', function(ctx)
    K.teleport(ctx, TRUCK_SPAWN.x, TRUCK_SPAWN.y, TRUCK_SPAWN.z + 1.0)
    ctx:cleanup(cancelGarbage)
    local answer = remember(ctx, callServer('qb-garbagejob:spawnTruck'))
    assert(not answer.raised and type(answer[1]) == 'table', 'No route was issued: ' .. describe(answer))
    ctx.state.bizRoute = answer[1]
    ctx.state.bizRouteIndex = 1
end)

-- Garbage.MinStops..MaxStops stops, distinct trashcans, MinBagsPerStop..MaxBagsPerStop bags.
K.step('my garbage route should have {int} to {int} distinct stops of {int} to {int} bags', 'client', function(ctx, minStops, maxStops, minBags, maxBags)
    local route = assert(ctx.state.bizRoute, 'Start a garbage route first')
    assert(#route >= minStops and #route <= maxStops, ('The route has %d stops'):format(#route))
    local seen = {}
    for i, entry in ipairs(route) do
        assert(TRASHCANS[entry.stop], ('Stop %d is trashcan %s, which is not configured'):format(i, tostring(entry.stop)))
        assert(not seen[entry.stop], ('Trashcan %d appears twice'):format(entry.stop))
        seen[entry.stop] = true
        assert(entry.bags >= minBags and entry.bags <= maxBags, ('Stop %d has %d bags'):format(i, entry.bags))
    end
end)

K.step('I try to collect a bag at a trashcan that is not my current stop', 'client', function(ctx)
    local route = assert(ctx.state.bizRoute, 'Start a garbage route first')
    local wrong = route[1].stop % #TRASHCANS + 1 -- any other configured trashcan
    local can = TRASHCANS[wrong]
    K.teleport(ctx, can[1], can[2], can[3] + 0.5)
    Wait(1500) -- let the server see the ped at that trashcan
    remember(ctx, callServer('qb-garbagejob:collectBag', wrong))
end)

K.step('I collect a bag at my first garbage stop from the depot', 'client', function(ctx)
    local route = assert(ctx.state.bizRoute, 'Start a garbage route first')
    remember(ctx, callServer('qb-garbagejob:collectBag', route[1].stop))
end)

K.step('I try to complete garbage route stop {int}', 'client', function(ctx, index)
    remember(ctx, callServer('qb-garbagejob:completeStop', index))
end)

-- A networked trash2 registered with qb-garbagejob:setTruck, as
-- jobs/garbage/client.lua does after spawning one at the depot.
K.step('I register my own garbage truck through the server protocol', 'client', function(ctx)
    local hash = GetHashKey('trash2') -- Garbage.Vehicle
    RequestModel(hash)
    ctx:waitUntil(function() return HasModelLoaded(hash) end, 'Truck model did not load', 10000)
    local vehicle = CreateVehicle(hash, TRUCK_SPAWN.x, TRUCK_SPAWN.y, TRUCK_SPAWN.z, TRUCK_SPAWN.h, true, false)
    assert(vehicle and vehicle ~= 0, 'The truck did not spawn')
    SetModelAsNoLongerNeeded(hash)
    ctx.state.bizTruck = vehicle
    ctx:cleanup(function()
        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end)
    ctx:waitUntil(function()
        return NetworkGetEntityIsNetworked(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) ~= 0
    end, 'The truck was not networked', 5000)
    ctx.state.bizTruckNet = NetworkGetNetworkIdFromEntity(vehicle)
    pollServer(ctx, 6000, function(a) return not a.raised and a[1] == true end, 'qb-garbagejob:setTruck', ctx.state.bizTruckNet)
end)

K.step('I try to register network id {int} as my garbage truck', 'client', function(ctx, netId)
    remember(ctx, callServer('qb-garbagejob:setTruck', netId))
end)

-- The blista from 'a damaged test vehicle is parked in front of me': networked
-- and near, but not a Garbage.Vehicle ('trash2').
K.step('I try to register the test vehicle as my garbage truck', 'client', function(ctx)
    remember(ctx, callServer('qb-garbagejob:setTruck', NetworkGetNetworkIdFromEntity(testVehicle(ctx))))
end)

K.step('I try to register my garbage truck again', 'client', function(ctx)
    remember(ctx, callServer('qb-garbagejob:setTruck', assert(ctx.state.bizTruckNet, 'Register a truck first')))
end)

K.step('I try to return my garbage truck', 'client', function(ctx)
    remember(ctx, callServer('qb-garbagejob:returnTruck', ctx.state.bizTruckNet or 0))
end)

-- Moves the truck next to the tester once the tester's teleport has loaded
-- collision there. Moved first, across the map, it fell through the unloaded
-- ground, so depositBag (truck within 6 m) answered false. Frozen so it stays
-- put until the server has seen it; DeleteEntity on return removes it frozen.
local function parkTruck(truck, x, y, z)
    FreezeEntityPosition(truck, false)
    SetEntityCoords(truck, x, y, z, false, false, false, false)
    SetVehicleOnGroundProperly(truck)
    FreezeEntityPosition(truck, true)
    Wait(750) -- the server sees an owned entity's new position a moment later
end

-- One stop of the route: park the truck beside the trashcan, stand at the can,
-- collect every bag (4 m), deposit every bag (truck within 6 m) and complete.
K.step('I clear the next garbage stop through the server protocol', 'client', function(ctx)
    local route = assert(ctx.state.bizRoute, 'Start a garbage route first')
    local index = ctx.state.bizRouteIndex
    if index > #route then return end -- 5-stop routes finish one step early
    local truck = assert(ctx.state.bizTruck, 'Register a truck first')
    local entry = route[index]
    local can = TRASHCANS[entry.stop]
    K.teleport(ctx, can[1], can[2], can[3] + 0.5)
    parkTruck(truck, can[1] + 4.5, can[2], can[3] + 0.5)
    pollServer(ctx, 6000, function(a) return not a.raised and a[1] == true end, 'qb-garbagejob:collectBag', entry.stop)
    for _ = 2, entry.bags do
        local answer = remember(ctx, callServer('qb-garbagejob:collectBag', entry.stop))
        assert(answer[1] == true, 'A bag was refused: ' .. describe(answer))
    end
    local extra = remember(ctx, callServer('qb-garbagejob:collectBag', entry.stop))
    assert(extra[1] == false, 'The server allowed more bags than the stop has: ' .. describe(extra))
    pollServer(ctx, 4000, function(a) return not a.raised and a[1] == true end, 'qb-garbagejob:depositBag', entry.stop)
    for _ = 2, entry.bags do
        local answer = remember(ctx, callServer('qb-garbagejob:depositBag', entry.stop))
        assert(answer[1] == true, 'A deposit was refused: ' .. describe(answer))
    end
    local done = remember(ctx, callServer('qb-garbagejob:completeStop', index))
    assert(done[1] == true, 'The stop was not completed: ' .. describe(done))
    ctx.state.bizRouteIndex = index + 1
end)

K.step('I return my garbage truck at the depot through the server protocol', 'client', function(ctx)
    local truck = assert(ctx.state.bizTruck, 'Register a truck first')
    local route = ctx.state.bizRoute
    assert(ctx.state.bizRouteIndex > #route, 'The route is not finished yet')
    K.teleport(ctx, DEPOT.x, DEPOT.y, DEPOT.z + 0.5)
    parkTruck(truck, DEPOT.x + 5.0, DEPOT.y, DEPOT.z + 0.5)
    local answer = pollServer(ctx, 6000, function(a) return not a.raised and type(a[1]) == 'number' end,
        'qb-garbagejob:returnTruck', ctx.state.bizTruckNet)
    -- jobs/garbage/server.lua: payment = stops * 50
    ctx:equal(answer[1], #route * 50, 'Route payment')
end)

K.step('the garbage truck should be gone', 'client', function(ctx)
    local truck = ctx.state.bizTruck
    ctx:waitUntil(function() return not truck or not DoesEntityExist(truck) end, 'The returned truck still exists', 5000)
end)

-- Pay for a 5- or 6-stop route (Garbage.MinStops/MaxStops, 50 per stop).
K.step('my {string} balance should have risen by the garbage route pay', 'server', function(ctx, account)
    local before = assert(ctx.state.moneyBaseline and ctx.state.moneyBaseline[account], 'Remember the balance first')
    ctx:waitUntil(function()
        local delta = K.money(ctx, account) - before
        return delta == 250 or delta == 300
    end, ('%s changed by %d, expected 250 or 300'):format(account, K.money(ctx, account) - before), 3000)
end)

-- ---------------------------------------------------------------------------
-- Recycle (jobs/recycle/server.lua; positions from jobs/recycle/shared.lua)
-- ---------------------------------------------------------------------------

-- The eight Sales materials, all priced 2.
local MATERIALS = { 'metalscrap', 'plastic', 'copper', 'rubber', 'iron', 'aluminum', 'steel', 'glass' }

K.step('the recycling buyer should quote {int} for every material', 'client', function(ctx, price)
    local answer = pollServer(ctx, 6000, function(a) return not a.raised and type(a[1]) == 'table' end,
        'kora_businesses:recycle:getPriceList')
    local count = 0
    for _ in pairs(answer[1]) do count = count + 1 end
    ctx:equal(count, #MATERIALS, 'Materials on the price list')
    for _, item in ipairs(MATERIALS) do ctx:equal(answer[1][item], price, 'Price of ' .. item) end
end)

-- Waits until the server sees the tester away from the buyer (5 m).
K.step('the recycling buyer should refuse to quote', 'client', function(ctx)
    pollServer(ctx, 6000, function(a) return not a.raised and a[1] == false end, 'kora_businesses:recycle:getPriceList')
end)

-- `amount` is sent as a number, except `text:<x>` (the string x), `nil`,
-- `true` and `false`, so the outline can send every wrong type.
local function literal(text)
    if text == 'nil' then return nil end
    if text == 'true' then return true end
    if text == 'false' then return false end
    if text:sub(1, 5) == 'text:' then return text:sub(6) end
    return assert(tonumber(text), 'Not a number: ' .. text)
end
K.step('I send the recycling buyer a sale of {string} {string}', 'client', function(_, amount, item)
    TriggerServerEvent('kora_businesses:recycle:sellItem', item, literal(amount))
    Wait(750)
end)

-- Pallets: Recycle.PickupLocations[i].loc; hand-in: Recycle.DropLocation.
local PALLET_ONE = { x = 1067.68, y = -3095.57, z = -39.0 }
local DROP = { x = 1048.224, y = -3097.071, z = -38.999 }

local function cancelPickup() TriggerServerEvent('kora_businesses:recycle:cancelPickup') end

K.step('I stand at the first recycling pallet', 'client', function(ctx)
    K.teleport(ctx, PALLET_ONE.x, PALLET_ONE.y, PALLET_ONE.z, 342.39)
    ctx:cleanup(cancelPickup)
end)

K.step('I pick up a recycling package from pallet {int}', 'client', function(ctx, index)
    ctx:cleanup(cancelPickup)
    remember(ctx, callServer('kora_businesses:recycle:pickupPackage', index))
end)

-- Polls, because the server sees the pallet teleport a moment late.
K.step('the recycling centre should authorise a package from pallet {int}', 'client', function(ctx, index)
    local answer = pollServer(ctx, 6000, function(a) return not a.raised and type(a[1]) == 'table' end,
        'kora_businesses:recycle:pickupPackage', index)
    assert(type(answer[1].networked) == 'boolean', 'The authorisation does not say whether the box is networked')
end)

K.step('I cancel my recycling package', 'client', function()
    cancelPickup()
    Wait(500)
end)

K.step('I carry my recycling package to the hand-in point', 'client', function(ctx)
    K.teleport(ctx, DROP.x, DROP.y, DROP.z)
end)

K.step('I hand in my recycling package', 'client', function()
    TriggerServerEvent('kora_businesses:recycle:getItem')
    Wait(1500)
end)

local function recycleHoldings(ctx)
    local counts = {}
    for _, item in ipairs(MATERIALS) do counts[item] = K.count(ctx, item) end
    counts.cryptostick = K.count(ctx, 'cryptostick')
    return counts
end

K.step('I remember my recycling materials', 'server', function(ctx)
    ctx.state.bizMaterials = recycleHoldings(ctx)
end)

local function materialGain(ctx)
    local before = assert(ctx.state.bizMaterials, 'Remember the recycling materials first')
    local now, gained = recycleHoldings(ctx), 0
    for _, item in ipairs(MATERIALS) do gained = gained + (now[item] - before[item]) end
    return gained, now.cryptostick - before.cryptostick
end

-- jobs/recycle/server.lua getItem: 1-5 rolls of 1-5 materials, 20% for one cryptostick.
K.step('I should have received {int} to {int} recycling materials', 'server', function(ctx, low, high)
    ctx:waitUntil(function()
        local gained = materialGain(ctx)
        return gained >= low and gained <= high
    end, ('Expected %d-%d new materials'):format(low, high), 5000, function() return (' | gained %d'):format(materialGain(ctx)) end)
    local _, sticks = materialGain(ctx)
    assert(sticks == 0 or sticks == 1, ('Gained %d cryptosticks, expected at most 1'):format(sticks))
end)

K.step('my recycling materials should be unchanged', 'server', function(ctx)
    Wait(1000)
    local gained, sticks = materialGain(ctx)
    ctx:equal(gained, 0, 'Materials gained')
    ctx:equal(sticks, 0, 'Cryptosticks gained')
end)

-- ---------------------------------------------------------------------------
-- CCTV (jobs/cctv/server.lua) as someone who is not a CCTV engineer
-- ---------------------------------------------------------------------------

local function calloutCount()
    local n = 0
    for _ in pairs(K.export('kora_businesses', 'getCctvCallouts') or {}) do n = n + 1 end
    return n
end
K.step('I note the number of CCTV call-outs', 'server', function(ctx)
    ctx.state.bizCallouts = calloutCount()
end)
K.step('the number of CCTV call-outs should be unchanged', 'server', function(ctx)
    ctx:equal(calloutCount(), assert(ctx.state.bizCallouts, 'Note the CCTV call-outs first'), 'CCTV call-outs')
end)

-- Residential call-outs are only authorised for the caller's own citizen id.
K.step('I request a residential CCTV call-out for another citizen', 'client', function(ctx)
    remember(ctx, callServer('kora_businesses:cctv:requestCallout', {
        issue = 'camera', customerType = 'residential', citizenid = 'FFT00000',
    }))
end)
