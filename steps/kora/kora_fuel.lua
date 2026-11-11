-- kora_fuel: paid refuelling at petrol pumps and EV charging stations.
-- No resource hook: pumps are a kora_target model option, chargers a
-- kora_target sphere zone, the service menu is the kora_lib app `kora_fuel:pump`
-- and every result is a kora_lib notification or progress bar. Fuel level is
-- GTA's native 0-100 vehicle level, read through the resource's own client
-- exports (GetFuel / SetFuel / isElectricVehicle). The purchase event is never
-- sent directly: scenarios only press the app's own `fuel-submit` action, so
-- the server's validation, progress callback and payment run for real.
local K = FFT.kora
if not K then return end
K.feature('kora_fuel')

-- kora_fuel/config.lua Config.pumpModels.
local PUMP_MODELS = {
    'prop_gas_pump_1a', 'prop_gas_pump_1b', 'prop_gas_pump_1c',
    'prop_gas_pump_1d', 'prop_vintage_pump', 'prop_gas_pump_old2',
    'prop_gas_pump_old3',
}
-- kora_fuel/config.lua Config.charging.prop.model.
local CHARGER_MODELS = { 'prop_parkingpay' }

-- Nearest streamed object of one of `models` within `range` of a point.
local function nearestProp(models, x, y, z, range)
    local wanted = {}
    for _, model in ipairs(models) do wanted[GetHashKey(model)] = true end
    local at = vector3(x, y, z)
    local best, bestDistance
    for _, object in ipairs(GetGamePool('CObject')) do
        if wanted[GetEntityModel(object)] then
            local distance = #(GetEntityCoords(object) - at)
            if distance <= range and (not bestDistance or distance < bestDistance) then best, bestDistance = object, distance end
        end
    end
    return best
end

-- Every streamed object of one of `models` within `range`, nearest first.
local function propsNear(models, x, y, z, range)
    local wanted = {}
    for _, model in ipairs(models) do wanted[GetHashKey(model)] = true end
    local at = vector3(x, y, z)
    local found = {}
    for _, object in ipairs(GetGamePool('CObject')) do
        if wanted[GetEntityModel(object)] then
            local distance = #(GetEntityCoords(object) - at)
            if distance <= range then found[#found + 1] = { object = object, distance = distance } end
        end
    end
    table.sort(found, function(a, b) return a.distance < b.distance end)
    local list = {}
    for index, entry in ipairs(found) do list[index] = entry.object end
    return list
end

-- True when nothing but the prop itself stands between the tester and the
-- middle of the prop. HasEntityClearLosToEntity probes to the prop's origin,
-- which for a map pump sits on (or just inside) its raised island, so the map
-- collision of the island blocks that probe from every side.
local function clearViewOf(ped, prop)
    local low, high = GetModelDimensions(GetEntityModel(prop))
    local middle = GetOffsetFromEntityInWorldCoords(prop, 0.0, 0.0, (low.z + high.z) / 2)
    local from = GetEntityCoords(ped)
    local probe = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, middle.x, middle.y, middle.z, 17, ped, 4)
    local _, hit, _, _, entity = GetShapeTestResult(probe)
    return hit ~= 1 and hit ~= true or entity == prop
end

local function closestVehicleTo(coords)
    local best, bestDistance
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local distance = #(GetEntityCoords(vehicle) - coords)
        if not bestDistance or distance < bestDistance then best, bestDistance = vehicle, distance end
    end
    return best, bestDistance
end

local function parked(ctx)
    local vehicle = ctx.state.fuelVehicle
    assert(vehicle and DoesEntityExist(vehicle), 'No vehicle was parked by a kora_fuel step')
    return vehicle
end

-- Parks a networked temporary vehicle beside a pump or charger prop and puts
-- the tester on foot between the two, aiming at the prop:
--   prop <- 2.0 m -> tester <- 3.2 m -> vehicle (side on to the prop).
-- That keeps the vehicle inside Config.vehicleSearchDistance (6.0) of the
-- tester and the prop inside the pump option's 2.5 m target distance. The
-- forecourt layout is map data, so the four sides of the prop are tried until
-- one has a clear line of sight, ground under the tester and no vehicle in the
-- parking spot. The engine is left off and the level is set with SetFuel.
local function parkBeside(ctx, models, range, what, model, level, x, y, z)
    assert(level >= 0 and level <= 100, 'Fuel level must be 0-100')
    local hash = GetHashKey(model)
    assert(IsModelInCdimage(hash) and IsModelAVehicle(hash), 'Unknown vehicle model: ' .. model)
    assert(not IsPedInAnyVehicle(PlayerPedId(), false), 'Leave the vehicle before using a kora_fuel parking step')

    K.teleport(ctx, x, y, z + 1.0)
    ctx:waitUntil(function() return nearestProp(models, x, y, z, range) end,
        ('No %s prop is streamed within %.0f m of %.2f %.2f %.2f'):format(what, range, x, y, z), 5000)

    RequestModel(hash)
    ctx:waitUntil(function() return HasModelLoaded(hash) end, 'Vehicle model did not load: ' .. model, 5000)

    -- The nearest props are tried in turn (at most three, to stay inside the step
    -- limit): a forecourt pump can have a kerb, a neighbouring pump or an ambient
    -- car on every side. Each refusal is kept for the failure message.
    local chosen, prop, at
    local refused = {}
    for index, candidate in ipairs(propsNear(models, x, y, z, range)) do
        if index > 3 or chosen then break end
        local origin = GetEntityCoords(candidate)
        local heading = math.rad(GetEntityHeading(candidate))
        local forward = { x = -math.sin(heading), y = math.cos(heading) }
        local sides = {
            { forward.x, forward.y }, { -forward.x, -forward.y },
            { forward.y, -forward.x }, { -forward.y, forward.x },
        }
        for sideIndex, side in ipairs(sides) do
            ctx:check()
            local spot = vector3(origin.x + side[1] * 5.2, origin.y + side[2] * 5.2, origin.z + 0.5)
            K.teleport(ctx, origin.x + side[1] * 2.0, origin.y + side[2] * 2.0, origin.z + 1.0)
            Wait(300)
            local ped = PlayerPedId()
            local drop = math.abs(GetEntityCoords(ped).z - (origin.z + 1.0))
            local reason
            if drop >= 1.5 then
                reason = ('no ground, %.1f m off'):format(drop)
            elseif not HasEntityClearLosToEntity(ped, candidate, 17) and not clearViewOf(ped, candidate) then
                reason = 'view blocked'
            elseif IsPositionOccupied(spot.x, spot.y, spot.z, 2.4, false, true, false, false, false, 0, false) then
                reason = 'a vehicle is in the spot'
            end
            if not reason then
                chosen, prop, at = { side = side, spot = spot }, candidate, origin
                break
            end
            refused[#refused + 1] = ('%d.%d %s'):format(index, sideIndex, reason)
        end
    end
    assert(chosen, ('No side of the %s has room for the tester and a parked vehicle (prop.side: %s)')
        :format(what, table.concat(refused, '; ')))

    local facing = GetHeadingFromVector_2d(chosen.side[2], -chosen.side[1]) -- side on to the prop
    local vehicle = CreateVehicle(hash, chosen.spot.x, chosen.spot.y, chosen.spot.z, facing, true, false)
    assert(vehicle and vehicle ~= 0, 'Vehicle did not spawn')
    ctx.state.fuelVehicle = vehicle
    ctx:cleanup(function()
        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, false, true, true)
    -- Network ids are occasionally slower than 3 s to arrive; ask again once.
    local registered = false
    ctx:waitUntil(function()
        assert(DoesEntityExist(vehicle), 'The parked vehicle was removed right after it spawned')
        if NetworkGetEntityIsNetworked(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) ~= 0 then return true end
        if not registered then registered = true NetworkRegisterEntityAsNetworked(vehicle) end
    end, 'The parked vehicle was not networked', 5000)
    ctx:equal(K.export('kora_fuel', 'SetFuel', vehicle, level + 0.0), true, 'SetFuel result')
    Wait(500) -- let the vehicle settle and the charger option's 500 ms memo expire

    local pedCoords = GetEntityCoords(PlayerPedId())
    local closest, distance = closestVehicleTo(pedCoords)
    assert(closest == vehicle, 'Another vehicle is closer to the tester than the parked test vehicle; kora_fuel would service that one')
    assert(distance <= 6.0, ('The parked vehicle is %.1f m away; kora_fuel searches 6.0 m'):format(distance))
    local propAt = GetEntityCoords(prop)
    K.aimAt(propAt.x, propAt.y, propAt.z + 1.0)
    Wait(100)
end

K.step('I park a {string} with fuel level {int} at the charger near {float} {float} {float}', 'client', function(ctx, model, level, x, y, z)
    parkBeside(ctx, CHARGER_MODELS, 4.0, 'charger', model, level, x, y, z)
end)
K.step('I park a {string} with fuel level {int} at the fuel pump near {float} {float} {float}', 'client', function(ctx, model, level, x, y, z)
    parkBeside(ctx, PUMP_MODELS, 30.0, 'fuel pump', model, level, x, y, z)
end)

K.step('the engine of the parked vehicle is left running', 'client', function(ctx)
    local vehicle = parked(ctx)
    SetVehicleEngineOn(vehicle, true, true, false)
    ctx:waitUntil(function() return GetIsVehicleEngineRunning(vehicle) end, 'The parked engine did not start', 3000)
    Wait(600)
    assert(GetIsVehicleEngineRunning(vehicle), 'The parked engine did not keep running')
end)

-- client/main.lua exports('GetFuel'): floored, clamped native level.
K.step('the fuel level of the parked vehicle should be {int}', 'client', function(ctx, level)
    local vehicle = parked(ctx)
    local seen
    ctx:waitUntil(function()
        seen = K.export('kora_fuel', 'GetFuel', vehicle)
        return seen == level
    end, ('Fuel level is %s, expected %d'):format(tostring(seen), level), 5000)
end)
K.step('the fuel level of the parked vehicle should stay {int}', 'client', function(ctx, level)
    local vehicle = parked(ctx)
    Wait(1500)
    ctx:equal(K.export('kora_fuel', 'GetFuel', vehicle), level, 'Fuel level')
end)
K.step('I set the fuel level of the parked vehicle to {float}', 'client', function(ctx, level)
    ctx:equal(K.export('kora_fuel', 'SetFuel', parked(ctx), level), true, 'SetFuel result')
end)
K.step('setting the fuel level of a missing vehicle should be refused', 'client', function(ctx)
    ctx:equal(K.export('kora_fuel', 'SetFuel', 0, 50.0), false, 'SetFuel result for no vehicle')
end)
K.step('the parked vehicle should count as {word} for fuel', 'client', function(ctx, kind)
    assert(kind == 'electric' or kind == 'petrol', 'Use electric or petrol')
    ctx:equal(K.export('kora_fuel', 'isElectricVehicle', parked(ctx)), kind == 'electric', 'isElectricVehicle')
end)

-- ===========================================================================
-- Round 3: classification, legacy exports, app header, titles and waypoint.
-- ===========================================================================

-- A vehicle for export checks only: spawned 4 m in front of the tester
-- wherever they stand, engine off, deleted in cleanup. Not at any station.
K.step('I spawn a temporary {string} beside me for kora_fuel', 'client', function(ctx, model)
    local hash = GetHashKey(model)
    assert(IsModelInCdimage(hash) and IsModelAVehicle(hash), 'Unknown vehicle model: ' .. model)
    assert(not IsPedInAnyVehicle(PlayerPedId(), false), 'Leave the vehicle before spawning a kora_fuel test vehicle')
    RequestModel(hash)
    ctx:waitUntil(function() return HasModelLoaded(hash) end, 'Vehicle model did not load: ' .. model, 8000)
    local ped = PlayerPedId()
    local at = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.5)
    local vehicle = CreateVehicle(hash, at.x, at.y, at.z, GetEntityHeading(ped), true, false)
    assert(vehicle and vehicle ~= 0, 'Vehicle did not spawn')
    ctx.state.fuelVehicle = vehicle
    ctx:cleanup(function()
        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, false, true, true)
end)

-- client/main.lua:30-33: no entity is never electric.
K.step('a missing vehicle should not count as electric for fuel', 'client', function(ctx)
    ctx:equal(K.export('kora_fuel', 'isElectricVehicle', 0), false, 'isElectricVehicle(0)')
end)

-- Legacy names come from kora_fuel's `provide` lines and the compat handler in
-- client/main.lua:70-85 (Kora.compat.provideExport registers
-- __cfx_export_<name>_<export>). No resource of that name runs, so K.export
-- (which requires a started resource) is not used.
local LEGACY = { LegacyFuel = true, ['qb-fuel'] = true, ['ps-fuel'] = true, ['cdn-fuel'] = true }

local function legacy(name, export, ...)
    assert(LEGACY[name], 'Not a legacy fuel provider of kora_fuel: ' .. tostring(name))
    K.started('kora_fuel')
    local results = table.pack(pcall(function(...) return exports[name][export](exports[name], ...) end, ...))
    if not results[1] then error(('exports[%q]:%s failed: %s'):format(name, export, tostring(results[2])), 0) end
    return table.unpack(results, 2, results.n)
end

K.step('I set the fuel of the parked vehicle through the legacy {string} export to {float}', 'client', function(ctx, name, level)
    local result = legacy(name, 'SetFuel', parked(ctx), level)
    ctx:equal(result, nil, 'Legacy SetFuel return value')
end)

K.step('the legacy {string} fuel export should read the parked vehicle as {float}', 'client', function(ctx, name, level)
    local vehicle = parked(ctx)
    local seen
    ctx:waitUntil(function()
        seen = legacy(name, 'GetFuel', vehicle)
        return type(seen) == 'number' and math.abs(seen - level) < 0.01
    end, ('Legacy %s GetFuel is %s, expected %.2f'):format(name, tostring(seen), level), 3000)
end)

K.step('the legacy {string} fuel export should ignore a non-finite level', 'client', function(ctx, name)
    local vehicle = parked(ctx)
    local before = GetVehicleFuelLevel(vehicle)
    for _, bad in ipairs({ 0 / 0, math.huge, -math.huge }) do
        ctx:equal(legacy(name, 'SetFuel', vehicle, bad), nil, 'Legacy SetFuel return value')
    end
    ctx:equal(legacy(name, 'SetFuel', vehicle, '50'), nil, 'Legacy SetFuel with a text level')
    Wait(200)
    assert(math.abs(GetVehicleFuelLevel(vehicle) - before) < 0.01,
        ('Fuel level changed from %.2f to %.2f'):format(before, GetVehicleFuelLevel(vehicle)))
end)

K.step('the legacy {string} fuel export should ignore my own ped', 'client', function(ctx, name)
    local ped = PlayerPedId()
    ctx:equal(legacy(name, 'GetFuel', ped), nil, 'Legacy GetFuel for a ped')
    ctx:equal(legacy(name, 'SetFuel', ped, 50.0), nil, 'Legacy SetFuel for a ped')
end)

K.step('the legacy {string} fuel export should ignore a missing vehicle', 'client', function(ctx, name)
    ctx:equal(legacy(name, 'GetFuel', 0), nil, 'Legacy GetFuel for no vehicle')
    ctx:equal(legacy(name, 'SetFuel', 0, 50.0), nil, 'Legacy SetFuel for no vehicle')
end)

-- client/main.lua:3-9 and locales/en.lua: 'Charging' for EVs and chargers, else 'Fuel'.
K.step('the kora_fuel notice {string} should be titled {string}', 'client', function(ctx, text, title)
    local entry = K.waitNotification(ctx, text)
    ctx:equal(entry.title, title, 'Notification title')
end)

-- client/main.lua:289-300 buildApp: title and description of the registered app.
K.step('the fuel app should be titled {string} with the description {string}', 'client', function(ctx, title, description)
    local app = ctx:waitUntil(function()
        local summary = K.ui('app')
        return type(summary) == 'table' and type(summary.app) == 'table' and summary.app.id == 'kora_fuel:pump' and summary.app
    end, 'The kora_fuel app payload is not visible', 3000)
    ctx:equal(app.title, title, 'App title')
    ctx:equal(app.description, description, 'App description')
end)

-- pumpRefusal (client/main.lua:118-130) sets the GPS waypoint. The tester's own
-- waypoint is recorded first and put back (or cleared) afterwards.
K.step('my GPS waypoint is put back afterwards', 'client', function(ctx)
    local had = IsWaypointActive()
    local saved = had and GetBlipInfoIdCoord(GetFirstBlipInfoId(8)) or nil
    ctx:cleanup(function()
        if saved then SetNewWaypoint(saved.x + 0.0, saved.y + 0.0)
        elseif IsWaypointActive() then SetWaypointOff() end
    end)
    if had then SetWaypointOff() end
    -- The game can drop a waypoint set close to the player (the Little Seoul
    -- charger is about 30 m from its petrol pump) before the next step looks,
    -- so every waypoint that appears during the scenario is recorded each frame.
    local watching = true
    ctx:cleanup(function() watching = false end)
    CreateThread(function()
        while watching do
            if IsWaypointActive() then
                local at = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
                ctx.state.fuelWaypoint = { x = at.x, y = at.y }
            end
            Wait(0)
        end
    end)
end)

K.step('my GPS waypoint should be near {float} {float}', 'client', function(ctx, x, y)
    local at = ctx:waitUntil(function()
        if IsWaypointActive() then
            local blip = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
            return { x = blip.x, y = blip.y }
        end
        return ctx.state.fuelWaypoint
    end, 'No GPS waypoint was set during the scenario', 3000)
    local distance = math.sqrt((at.x - x) ^ 2 + (at.y - y) ^ 2)
    assert(distance < 5.0, ('The waypoint is %.1f m from %.2f %.2f'):format(distance, x, y))
end)
