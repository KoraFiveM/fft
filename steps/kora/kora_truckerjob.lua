-- kora_truckerjob: freight dispatch (kora_lib AppShell app), trucker skills,
-- truck ownership, and the dispatched truck's accept/cancel/return lifecycle.
--
-- The dispatch app is driven through kora_lib's hook. kora_truckerjob's own
-- hook adds one read-only action, `dashboard`, because contract ids are random
-- and the app's contract list is deeper than kora_lib's hook summary reports.
-- Values quoted below come from kora_truckerjob/config.lua, server.lua and
-- client/client.lua.
local K = FFT.kora
if not K then return end
K.feature('kora_truckerjob')

local RESOURCE = 'kora_truckerjob'
local APP_ID = 'kora_truckerjob:dispatch'               -- client/client.lua APP_ID
local STATION = { x = 153.86, y = -3211.76, z = 5.95 } -- Config.Coords.JobStation
local RETURN = { x = 187.07, y = -3219.34, z = 5.86 }  -- Config.Coords.TruckReturn
local STATION_RANGE = 15.0                           -- server.lua playerIsNear(..., JobStation, 15.0)
local PLATE_PREFIX = 'TRK'                           -- server.lua ('TRK%s'):format(jobId):sub(1, 8)

local function distance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

-- ---------------------------------------------------------------------------
-- Server: trucker record fixture (kora_core metadata `rep.trucker`)
-- ---------------------------------------------------------------------------

local function truckerRecord(ctx)
    local rep = exports.kora_core:getMetaData(ctx.tester, 'rep')
    local trucker = type(rep) == 'table' and rep.trucker or nil
    return type(trucker) == 'table' and trucker or {}
end

-- Replaces only rep.trucker and puts the original value back afterwards. The
-- shape is what server.lua normaliseTruckerRep produces for a new driver.
K.step('my trucking record is reset with {int} skill points', 'server', function(ctx, points)
    assert(points >= 0 and points <= 12, 'Skill points must be 0-12')
    local core, tester = exports.kora_core, ctx.tester
    local original = core:getMetaData(tester, 'rep')
    local previous = type(original) == 'table' and original.trucker or nil
    local function write(trucker)
        local current = core:getMetaData(tester, 'rep')
        local rep = {}
        for key, value in pairs(type(current) == 'table' and current or {}) do rep[key] = value end
        rep.trucker = trucker
        return core:setMetaData(tester, 'rep', rep)
    end
    ctx:cleanup(function() write(previous) end)
    ctx.state.truckerReset = true
    local ok, err = write({
        skills = { distance = 1, cargo = 1, time = 1 },
        trucks = { hauler = true },   -- Config.DefaultTruck
        activeTruck = 'hauler',
        skillPoints = points,
        XP = 0,
    })
    if ok == false then error('Could not reset the trucking record: ' .. tostring(err), 0) end
end)

-- Adds one owned (not selected) truck to the reset record. The reset step's
-- cleanup restores the whole original record, so nothing more to undo here.
-- client/client.lua:634-639 only puts `trucker:select` on a truck that is owned
-- and not selected, and kora_lib refuses any action id the current app
-- definition does not carry; a new driver (hauler only, selected) therefore has
-- no select action at all until a second truck is owned.
K.step('my trucking record also owns the freight truck {string}', 'server', function(ctx, model)
    assert(ctx.state.truckerReset, 'Reset the trucking record first')
    local core, tester = exports.kora_core, ctx.tester
    local current = core:getMetaData(tester, 'rep')
    local rep = {}
    for key, value in pairs(type(current) == 'table' and current or {}) do rep[key] = value end
    local trucker = {}
    for key, value in pairs(type(rep.trucker) == 'table' and rep.trucker or {}) do trucker[key] = value end
    local trucks = {}
    for key, value in pairs(type(trucker.trucks) == 'table' and trucker.trucks or {}) do trucks[key] = value end
    trucks[model] = true
    trucker.trucks = trucks
    rep.trucker = trucker
    local ok, err = core:setMetaData(tester, 'rep', rep)
    if ok == false then error('Could not add the truck to the trucking record: ' .. tostring(err), 0) end
end)

K.step('my trucking skill {string} should be level {int}', 'server', function(ctx, skill, level)
    ctx:waitUntil(function() return (truckerRecord(ctx).skills or {})[skill] == level end,
        ('Trucking skill %s is %s, expected %d'):format(skill, tostring((truckerRecord(ctx).skills or {})[skill]), level), 3000)
end)
K.step('my trucking skill points should be {int}', 'server', function(ctx, points)
    ctx:waitUntil(function() return truckerRecord(ctx).skillPoints == points end,
        ('Trucking skill points are %s, expected %d'):format(tostring(truckerRecord(ctx).skillPoints), points), 3000)
end)
K.step('I should own the freight truck {string}', 'server', function(ctx, model)
    ctx:waitUntil(function() return (truckerRecord(ctx).trucks or {})[model] == true end,
        'Trucking record does not own ' .. model, 3000)
end)
K.step('I should not own the freight truck {string}', 'server', function(ctx, model)
    Wait(500)
    assert(not (truckerRecord(ctx).trucks or {})[model], 'Trucking record owns ' .. model)
end)
K.step('my active freight truck should be {string}', 'server', function(ctx, model)
    ctx:waitUntil(function() return truckerRecord(ctx).activeTruck == model end,
        'Active freight truck is ' .. tostring(truckerRecord(ctx).activeTruck), 3000)
end)

-- ---------------------------------------------------------------------------
-- Server: dispatched trucks (server-spawned, plate TRK<job id>)
-- ---------------------------------------------------------------------------

local function freightTrucks()
    local found = {}
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) then
            local plate = (GetVehicleNumberPlateText(vehicle) or ''):gsub('%s+', ''):upper()
            if plate:sub(1, #PLATE_PREFIX) == PLATE_PREFIX then found[#found + 1] = vehicle end
        end
    end
    return found
end

-- Trucks that appeared since the baseline and are near the tester or the depot
-- bays. On a shared server another driver's truck is therefore left alone.
local function newFreightTrucks(ctx)
    local baseline = assert(ctx.state.truckerBaseline, 'Track dispatched freight trucks first')
    local ped = GetPlayerPed(ctx.tester)
    local at = ped ~= 0 and GetEntityCoords(ped) or nil
    local list = {}
    for _, vehicle in ipairs(freightTrucks()) do
        if not baseline[vehicle] then
            local coords = GetEntityCoords(vehicle)
            if distance(coords, STATION) <= 150.0 or (at and distance(coords, at) <= 150.0) then
                list[#list + 1] = vehicle
            end
        end
    end
    return list
end

-- Call before accepting a contract. Deleting the truck is also what closes a
-- still-active contract: client.lua watchTruck -> handleTruckLost releases the
-- server's vehicle state and keys and abandons the job.
K.step('freight trucks dispatched to me are removed afterwards', 'server', function(ctx)
    local baseline = {}
    for _, vehicle in ipairs(freightTrucks()) do baseline[vehicle] = true end
    ctx.state.truckerBaseline = baseline
    -- Trucks this scenario saw as its own. A scenario may drive the truck far
    -- from the depot (the port trailer office), where the distance filter of
    -- newFreightTrucks no longer finds it once the tester is moved back.
    local seen = {}
    ctx.state.truckerSeen = seen
    ctx:cleanup(function()
        for _, vehicle in ipairs(newFreightTrucks(ctx)) do
            if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
        end
        for vehicle in pairs(seen) do
            if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
        end
    end)
end)
local function rememberTrucks(ctx)
    local list = newFreightTrucks(ctx)
    local seen = assert(ctx.state.truckerSeen, 'Track dispatched freight trucks first')
    ctx.state.truckerPlates = ctx.state.truckerPlates or {}
    for _, vehicle in ipairs(list) do
        if not seen[vehicle] then
            seen[vehicle] = true
            local plates = ctx.state.truckerPlates
            plates[#plates + 1] = GetVehicleNumberPlateText(vehicle)
        end
    end
    return list
end
K.step('a freight truck should have been dispatched to me', 'server', function(ctx)
    ctx:waitUntil(function() return #rememberTrucks(ctx) > 0 end, 'No TRK-plated truck was spawned at the depot', 10000)
end)
K.step('no freight truck should have been dispatched to me', 'server', function(ctx)
    Wait(1500)
    ctx:equal(#newFreightTrucks(ctx), 0, 'Dispatched freight trucks')
end)
K.step('my freight truck should have been collected', 'server', function(ctx)
    ctx:waitUntil(function() return #newFreightTrucks(ctx) == 0 end, 'The dispatched truck still exists', 8000)
end)

-- ---------------------------------------------------------------------------
-- Client: dispatch app
-- ---------------------------------------------------------------------------

-- Client-side pacing for the dispatch app's server callbacks. Each one is rate
-- limited per player (server.lua: skillUpgraded 4 per 5 s, truckPurchased 2 per
-- 5 s, truckSelected 3 per 5 s, jobAccepted 3 per 5 s, jobCompleted 3 per 10 s)
-- and a limited call fails the whole app action. Scenarios run back to back, so
-- the suite's own steps stay one call under each limit, which leaves room for a
-- call made through the generic `I trigger the app action` step just before.
local BUDGET = {
    ['trucker:upgrade'] = { 3, 5500 },
    ['trucker:purchase'] = { 1, 5500 },
    ['trucker:select'] = { 2, 5500 },
    ['trucker:accept'] = { 2, 5500 },
    ['trucker:cancel'] = { 2, 10500 },
    dashboard = { 4, 5500 },        -- dashboardRequested 5 per 5 s
    vehicle = { 3, 10500 },         -- vehicleRequested 4 per 10 s (truck and trailer)
}
local calls = {}
local function pace(ctx, actionId)
    local budget = BUDGET[actionId]
    if not budget then return end
    local list = calls[actionId] or {}
    calls[actionId] = list
    while true do
        local now = GetGameTimer()
        while list[1] and now - list[1] >= budget[2] do table.remove(list, 1) end
        if #list < budget[1] then break end
        ctx:check()
        Wait(100)
    end
    list[#list + 1] = GetGameTimer()
end

local function closeDispatch()
    pcall(function() exports.kora_lib:fftAction('app.close') end)
end

local function waitDispatch(ctx)
    ctx:waitUntil(function()
        local app = K.uiState().app
        return app and app.id == APP_ID
    end, 'Freight dispatch did not open')
end

-- An action result with `close = true` (trucker:accept, client/client.lua:722)
-- is closed by the browser, not by kora_lib's Lua (modules/nui/client.lua only
-- sends the notice). The hook answers the NUI callback without a browser, so
-- the app stays open, openDispatch() returns early on `appActive`
-- (client/client.lua:753) and the stale definition (no `trucker:cancel`, which
-- client/client.lua:660-663 only adds with an active contract) would be reused.
-- Close it the way the browser would, then let openDispatch's thread unwind.
local function closeStaleDispatch(ctx)
    if not K.uiState().app then return end
    closeDispatch()
    ctx:waitUntil(function() return K.uiState().app == nil end, 'The previous app did not close', 5000)
    Wait(300)
end

-- The dashboard callback allows 5 requests per 5 s (server.lua) and opening the
-- app spends one too, so every read here is paced and never polled.
local function board(ctx)
    pace(ctx, 'dashboard')
    Wait(300)
    local snapshot, err = K.hook(RESOURCE, 'dashboard')
    if type(snapshot) ~= 'table' then error('Freight board unavailable: ' .. tostring(err), 0) end
    return snapshot
end

-- First open contract the tester's skills qualify for (server.lua jobQualifies).
local function qualifyingContract(snapshot)
    local skills = snapshot.rep.skills
    for _, job in ipairs(snapshot.jobs) do
        if not job.active and job.distanceLevel <= skills.distance and job.cargoLevel <= skills.cargo
            and (not job.timeLevel or job.timeLevel <= skills.time) then
            return job
        end
    end
end

-- kora_lib answers an app action with { ok, result = { notice, ... } }; accept
-- both that and a bare result so the step survives a hook contract change.
local function notice(ctx)
    local result = ctx.state.appResult
    if type(result) ~= 'table' then return nil end
    local inner = type(result.result) == 'table' and result.result or result
    return type(inner.notice) == 'table' and inner.notice or nil
end

-- exports.kora_truckerjob:openDispatch is the function the depot target option
-- runs (client.lua `onSelect = openDispatch`).
K.step('I open the freight dispatch', 'client', function(ctx)
    closeStaleDispatch(ctx)
    ctx:cleanup(closeDispatch)
    pace(ctx, 'dashboard')
    K.export(RESOURCE, 'openDispatch')
    waitDispatch(ctx)
end)
K.step('I open the freight dispatch away from the depot', 'client', function(ctx)
    local away = distance(GetEntityCoords(PlayerPedId()), STATION)
    assert(away > STATION_RANGE + 10.0, ('The tester is %.0f m from the depot; move further away first'):format(away))
    closeStaleDispatch(ctx)
    ctx:cleanup(closeDispatch)
    pace(ctx, 'dashboard')
    K.export(RESOURCE, 'openDispatch')
    waitDispatch(ctx)
end)

K.step('the freight board should offer a contract my skills qualify for', 'client', function(ctx)
    local snapshot = board(ctx)
    assert(#snapshot.jobs > 0, 'The freight board is empty')
    assert(qualifyingContract(snapshot), 'No open contract matches the tester skills')
end)
K.step('the freight board should show no active contract of mine', 'client', function(ctx)
    local active = board(ctx).activeJobId
    assert(active == nil, 'A contract is still active: ' .. tostring(active))
end)

K.step('I accept a freight contract my skills qualify for', 'client', function(ctx)
    local job = assert(qualifyingContract(board(ctx)), 'No open contract matches the tester skills')
    ctx.state.truckerJob = job.id
    ctx.state.appResult = nil
    pace(ctx, 'trucker:accept')
    pace(ctx, 'vehicle')
    -- Accepting also spawns the truck, which can outlast kora_lib's 5 s NUI
    -- callback wait; the outcome is then asserted by the next steps.
    local ok, result, code = K.ui('app.action', 'trucker:accept', { itemId = job.id })
    if ok then
        ctx.state.appResult = type(result) == 'table' and result or {}
        -- Do what the browser does with `close = true` (see closeStaleDispatch).
        if ctx.state.appResult.close == true then closeStaleDispatch(ctx) end
    elseif code == 'rejected' or code == 'not_open' then
        error(tostring(result), 0)
    end
end)

-- A notice that closes the app is delivered as a notification instead
-- (kora_lib app action `close = true`), so accept either surface.
K.step('the freight dispatch should answer with a {string} notice containing {string}', 'client', function(ctx, tone, text)
    local answer = notice(ctx)
    if answer then
        ctx:equal(answer.tone, tone, 'Notice tone')
        assert(K.contains(answer.message, text),
            ('Notice is "%s", expected it to contain "%s"'):format(tostring(answer.message), text))
        return
    end
    K.waitNotification(ctx, text, 8000)
end)
K.step('the freight dispatch should refuse the request', 'client', function(ctx)
    local answer = assert(notice(ctx), 'The last dispatch action returned no notice')
    ctx:equal(answer.tone, 'destructive', 'Notice tone')
end)

-- ---------------------------------------------------------------------------
-- Client: the dispatched truck
-- ---------------------------------------------------------------------------

local function myFreightTruck(ctx)
    local wanted = ctx.state.truckerJob and (PLATE_PREFIX .. ctx.state.truckerJob):sub(1, 8):gsub('%s+', ''):upper() or nil
    local at = GetEntityCoords(PlayerPedId())
    local best, bestDistance
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local plate = (GetVehicleNumberPlateText(vehicle) or ''):gsub('%s+', ''):upper()
        if (wanted and plate == wanted) or (not wanted and plate:sub(1, #PLATE_PREFIX) == PLATE_PREFIX) then
            local away = distance(GetEntityCoords(vehicle), at)
            if not bestDistance or away < bestDistance then best, bestDistance = vehicle, away end
        end
    end
    return best
end

K.step('I take the wheel of my freight truck', 'client', function(ctx)
    local truck = ctx:waitUntil(function() return myFreightTruck(ctx) end, 'The dispatched truck is not streamed', 8000)
    ctx:cleanup(function()
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local at = GetEntityCoords(ped)
            ClearPedTasksImmediately(ped)
            SetEntityCoordsNoOffset(ped, at.x, at.y, at.z + 1.0, false, false, false)
        end
    end)
    TaskWarpPedIntoVehicle(PlayerPedId(), truck, -1)
    ctx:waitUntil(function() return GetVehiclePedIsIn(PlayerPedId(), false) == truck end, 'Could not enter the truck', 5000)
end)
-- Moves the truck the tester is driving; the server checks the truck's own
-- position (server.lua vehicleIsAtReturn, 15 m) before accepting the return.
local function moveTruck(ctx, x, y, z, heading)
    local truck = GetVehiclePedIsIn(PlayerPedId(), false)
    assert(truck ~= 0, 'Take the wheel of the freight truck first')
    ctx:waitUntil(function() return NetworkHasControlOfEntity(truck) or NetworkRequestControlOfEntity(truck) end,
        'Could not take network control of the truck', 5000)
    local target = { x = x, y = y, z = z }
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(truck, x + 0.0, y + 0.0, z + 1.0, false, false, false)
    if heading then SetEntityHeading(truck, heading + 0.0) end
    SetVehicleOnGroundProperly(truck)
    ctx:waitUntil(function() return distance(GetEntityCoords(truck), target) <= 10.0 end,
        'The truck did not reach its destination', 5000)
    Wait(1000)
end
K.step('I bring my freight truck to the depot return point', 'client', function(ctx)
    moveTruck(ctx, RETURN.x, RETURN.y, RETURN.z)
end)
-- The tester drives the truck itself, as a player would: a truck left ~700 m
-- behind leaves the client's scope and watchTruck (client/client.lua) then
-- closes the contract as "Your truck is gone".
K.step('I move my freight truck to {float} {float} {float} facing {float}', 'client', function(ctx, x, y, z, heading)
    moveTruck(ctx, x, y, z, heading)
end)
K.step('I step out of my freight truck', 'client', function(ctx)
    local ped = PlayerPedId()
    local truck = GetVehiclePedIsIn(ped, false)
    assert(truck ~= 0, 'The tester is not in a vehicle')
    SetVehicleEngineOn(truck, false, true, true)
    TaskLeaveVehicle(ped, truck, 0)
    ctx:waitUntil(function() return not IsPedInAnyVehicle(PlayerPedId(), false) end, 'Could not leave the truck', 8000)
end)

-- ===========================================================================
-- Round 3 additions
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Server: raw trucker records (server.lua normaliseTruckerRep)
-- ---------------------------------------------------------------------------

local function editTrucker(ctx, edit)
    assert(ctx.state.truckerReset, 'Reset the trucking record first')
    local core, tester = exports.kora_core, ctx.tester
    local current = core:getMetaData(tester, 'rep')
    local rep = {}
    for key, value in pairs(type(current) == 'table' and current or {}) do rep[key] = value end
    local trucker = {}
    for key, value in pairs(type(rep.trucker) == 'table' and rep.trucker or {}) do
        if type(value) == 'table' then
            local copy = {}
            for k, v in pairs(value) do copy[k] = v end
            trucker[key] = copy
        else
            trucker[key] = value
        end
    end
    edit(trucker)
    rep.trucker = trucker
    local ok, err = core:setMetaData(tester, 'rep', rep)
    if ok == false then error('Could not write the trucking record: ' .. tostring(err), 0) end
end

-- Writes `value` at a dotted path ("skills.distance", "skillPoints", "XP",
-- "activeTruck", "trucks", "skills") of the reset record, to drive
-- normaliseTruckerRep's repair branches with malformed stored data.
local function storeAt(ctx, path, value)
    assert(#path > 0 and #path <= 40, 'Path must be 1-40 characters')
    editTrucker(ctx, function(trucker)
        local parent, key = trucker, path
        local head, tail = path:match('^([^.]+)%.([^.]+)$')
        if head then
            if type(trucker[head]) ~= 'table' then trucker[head] = {} end
            parent, key = trucker[head], tail
        end
        parent[key] = value
    end)
end
K.step('my trucking record stores the number {string} in {string}', 'server', function(ctx, value, path)
    local number = assert(tonumber(value), 'Not a number: ' .. value)
    storeAt(ctx, path, number)
end)
K.step('my trucking record stores the text {string} in {string}', 'server', function(ctx, value, path)
    storeAt(ctx, path, value)
end)

-- server.lua normaliseTruckerRep starts from `rep.trucker or {}` for a
-- character that has never opened the dispatch.
K.step('my trucking record is cleared', 'server', function(ctx)
    local core, tester = exports.kora_core, ctx.tester
    local original = core:getMetaData(tester, 'rep')
    local previous = type(original) == 'table' and original.trucker or nil
    ctx:cleanup(function()
        local current = core:getMetaData(tester, 'rep')
        local rep = {}
        for key, value in pairs(type(current) == 'table' and current or {}) do rep[key] = value end
        rep.trucker = previous
        core:setMetaData(tester, 'rep', rep)
    end)
    local rep = {}
    for key, value in pairs(type(original) == 'table' and original or {}) do rep[key] = value end
    rep.trucker = nil
    local ok, err = core:setMetaData(tester, 'rep', rep)
    if ok == false then error('Could not clear the trucking record: ' .. tostring(err), 0) end
end)

K.step('my trucking skills are distance {int} cargo {int} time {int}', 'server', function(ctx, d, c, t)
    for _, level in ipairs({ d, c, t }) do assert(level >= 1 and level <= 4, 'Skill levels are 1-4') end
    editTrucker(ctx, function(trucker) trucker.skills = { distance = d, cargo = c, time = t } end)
end)

-- Owns and selects a Config.Trucks entry (config.lua Trucks) without buying it.
K.step('my trucking record drives the freight truck {string}', 'server', function(ctx, model)
    editTrucker(ctx, function(trucker)
        trucker.trucks = trucker.trucks or {}
        trucker.trucks[model] = true
        trucker.activeTruck = model
    end)
end)

K.step('my trucking XP should be {int}', 'server', function(ctx, xp)
    ctx:waitUntil(function() return truckerRecord(ctx).XP == xp end,
        ('Trucking XP is %s, expected %d'):format(tostring(truckerRecord(ctx).XP), xp), 3000)
end)

-- ---------------------------------------------------------------------------
-- Server: the dispatched truck's model and keys (kora_vehiclekeys)
-- ---------------------------------------------------------------------------

K.step('the dispatched freight truck should be a {string}', 'server', function(ctx, model)
    local list = ctx:waitUntil(function()
        local found = rememberTrucks(ctx)
        return #found > 0 and found or nil
    end, 'No TRK-plated truck was spawned at the depot', 10000)
    local hash = GetHashKey(model)
    for _, vehicle in ipairs(list) do
        ctx:equal(GetEntityModel(vehicle), hash, 'Dispatched truck model (' .. model .. ')')
    end
end)
K.step('exactly one freight truck should have been dispatched to me', 'server', function(ctx)
    ctx:waitUntil(function() return #rememberTrucks(ctx) > 0 end, 'No TRK-plated truck was spawned at the depot', 10000)
    Wait(1500)
    ctx:equal(#rememberTrucks(ctx), 1, 'Dispatched freight trucks')
end)

-- server.lua giveTruckKeys -> exports.kora_vehiclekeys:giveKeys(source, plate, true)
-- (Config.GiveKeys = true); removeTruckKeys on return or loss.
local function holdsKeys(ctx, plate)
    return K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate) == true
end
K.step('I should hold keys to my dispatched freight truck', 'server', function(ctx)
    ctx:waitUntil(function()
        rememberTrucks(ctx)
        for _, plate in ipairs(ctx.state.truckerPlates or {}) do
            if holdsKeys(ctx, plate) then return true end
        end
    end, 'kora_vehiclekeys reports no key for the dispatched truck', 8000)
end)
K.step('I should no longer hold keys to my dispatched freight truck', 'server', function(ctx)
    local plates = ctx.state.truckerPlates or {}
    assert(#plates > 0, 'No dispatched truck was seen in this scenario')
    ctx:waitUntil(function()
        for _, plate in ipairs(plates) do
            if holdsKeys(ctx, plate) then return false end
        end
        return true
    end, 'kora_vehiclekeys still reports a key for the dispatched truck', 8000)
end)

-- Deleting the truck is what a despawn or another script does; the client's
-- watchTruck (Config.TruckLost) must then close the contract.
K.step('my dispatched freight truck disappears', 'server', function(ctx)
    local list = rememberTrucks(ctx)
    assert(#list > 0, 'No dispatched truck to remove')
    for _, vehicle in ipairs(list) do
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end
end)

-- ---------------------------------------------------------------------------
-- Server: trailers at the port bays (config.lua Coords.TrailerSpawns)
-- ---------------------------------------------------------------------------

-- Every trailer model in config.lua DeliveryTypes.
local TRAILER_MODELS = {
    'trailers', 'docktrailer', 'trailers4', 'trailers3', 'trailerlogs', 'trailers2',
    'tr2', 'trflat', 'tvtrailer', 'tanker2', 'tanker', 'tr3', 'tr4', 'trailerlarge',
}
local TRAILER_BAYS = { x = 931.0, y = -3154.2, z = 7.9 } -- centre of TrailerSpawns (x 892.6-969.6)
local TRAILER_RADIUS = 60.0

local function portTrailers()
    local models = {}
    for _, name in ipairs(TRAILER_MODELS) do models[GetHashKey(name)] = true end
    local found = {}
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and models[GetEntityModel(vehicle)]
            and distance(GetEntityCoords(vehicle), TRAILER_BAYS) <= TRAILER_RADIUS then
            found[#found + 1] = vehicle
        end
    end
    return found
end
local function newTrailers(ctx)
    local baseline = assert(ctx.state.trailerBaseline, 'Track dispatched freight trailers first')
    local list = {}
    for _, vehicle in ipairs(portTrailers()) do
        if not baseline[vehicle] then list[#list + 1] = vehicle end
    end
    return list
end
K.step('freight trailers dispatched to me are removed afterwards', 'server', function(ctx)
    local baseline = {}
    for _, vehicle in ipairs(portTrailers()) do baseline[vehicle] = true end
    ctx.state.trailerBaseline = baseline
    ctx:cleanup(function()
        for _, vehicle in ipairs(newTrailers(ctx)) do
            if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
        end
    end)
end)
K.step('a freight trailer should have been dispatched to me', 'server', function(ctx)
    ctx:waitUntil(function() return #newTrailers(ctx) > 0 end, 'No trailer was spawned at the port bays', 10000)
end)
-- server.lua jobCompleted(successful = false) deletes state.trailer.
K.step('my freight trailer should have been released', 'server', function(ctx)
    ctx:waitUntil(function() return #newTrailers(ctx) == 0 end, 'The dispatched trailer still exists', 8000)
end)

-- ---------------------------------------------------------------------------
-- Client: paced dispatch actions and board reads
-- ---------------------------------------------------------------------------

local function dispatchAction(ctx, actionId, itemId)
    pace(ctx, actionId)
    if actionId == 'trucker:accept' then pace(ctx, 'vehicle') end
    ctx.state.appResult = nil
    local ok, result = K.ui('app.action', actionId, itemId ~= nil and { itemId = itemId } or nil)
    if not ok then error(('Dispatch action %s failed: %s'):format(actionId, tostring(result)), 0) end
    ctx.state.appResult = type(result) == 'table' and result or {}
    if ctx.state.appResult.close == true then closeStaleDispatch(ctx) end
end
-- Same NUI-callback path as `I trigger the app action`, spaced under the
-- server's per-player callback rate limits so back-to-back scenarios hold.
K.step('I use the freight dispatch action {string} on {string}', 'client', function(ctx, actionId, itemId)
    dispatchAction(ctx, actionId, itemId)
end)
K.step('I use the freight dispatch action {string}', 'client', function(ctx, actionId)
    dispatchAction(ctx, actionId, nil)
end)

-- server.lua jobAccepted checks distance, then cargo, then time; pick an open
-- contract whose first failing check is `skill` for the tester's levels.
local function firstMissingSkill(job, skills)
    if job.distanceLevel > skills.distance then return 'distance' end
    if job.cargoLevel > skills.cargo then return 'cargo' end
    if job.timeLevel and job.timeLevel > skills.time then return 'time' end
end
K.step('I accept a freight contract that needs a higher {string} skill', 'client', function(ctx, skill)
    local snapshot = board(ctx)
    local chosen
    for _, job in ipairs(snapshot.jobs) do
        if not job.active and firstMissingSkill(job, snapshot.rep.skills) == skill then chosen = job break end
    end
    assert(chosen, ('No open contract on the board needs a higher %s skill right now'):format(skill))
    ctx.state.truckerJob = chosen.id
    dispatchAction(ctx, 'trucker:accept', chosen.id)
end)
K.step('I accept another freight contract my skills qualify for', 'client', function(ctx)
    local first = assert(ctx.state.truckerJob, 'Accept a contract first')
    local snapshot = board(ctx)
    local chosen
    for _, job in ipairs(snapshot.jobs) do
        if not job.active and job.id ~= first and not firstMissingSkill(job, snapshot.rep.skills) then chosen = job break end
    end
    assert(chosen, 'No second qualifying contract is on the board')
    dispatchAction(ctx, 'trucker:accept', chosen.id)
end)

K.step('the freight board should show my accepted contract as active', 'client', function(ctx)
    local wanted = assert(ctx.state.truckerJob, 'Accept a contract first')
    local snapshot = board(ctx)
    ctx:equal(snapshot.activeJobId, wanted, 'Active contract')
    for _, job in ipairs(snapshot.jobs) do
        if job.id == wanted then
            assert(job.active, 'The accepted contract is not reserved on the board')
            return
        end
    end
    error('The accepted contract is not on the board', 0)
end)
K.step('the freight board should no longer list my accepted contract', 'client', function(ctx)
    local wanted = assert(ctx.state.truckerJob, 'Accept a contract first')
    for _, job in ipairs(board(ctx).jobs) do
        if job.id == wanted then error('The contract is still listed: ' .. wanted, 0) end
    end
end)
K.step('the freight board should still list my contract as open', 'client', function(ctx)
    local wanted = assert(ctx.state.truckerJob, 'Pick a contract first')
    for _, job in ipairs(board(ctx).jobs) do
        if job.id == wanted then
            assert(not job.active, 'The contract was reserved: ' .. wanted)
            return
        end
    end
    error('The contract is no longer listed: ' .. wanted, 0)
end)
K.step('the freight board should report {int} skill points', 'client', function(ctx, points)
    ctx:equal(board(ctx).rep.skillPoints, points, 'Skill points on the freight board')
end)
