-- kora_truckrobbery: dealer start option, police-count refusal and the server-wide
-- robbery lock (GlobalState.TruckRobbery).
--
-- Hooks: kora_truckrobbery/fft_hooks_server.lua (approved seam: one-shot police
-- waiver for the tester and a reset that only clears a robbery the tester's
-- waived start created) and kora_truckrobbery/fft_hooks.lua (removes the local
-- stockade and guards the start spawns). The dealer option itself is driven
-- through kora_target with the generic steps.
local K = FFT.kora
if not K then return end
K.feature('kora_truckrobbery')

local RESOURCE = 'kora_truckrobbery'

local function published()
    local state = GlobalState.TruckRobbery
    assert(type(state) == 'table', 'GlobalState.TruckRobbery is not published')
    return state
end

local function serverState(ctx)
    local state = K.hook(RESOURCE, 'state', ctx.tester)
    assert(type(state) == 'table', 'kora_truckrobbery hook returned no state')
    return state
end

K.step('the truck robbery should be idle', 'server', function(ctx)
    K.started(RESOURCE)
    local state = published()
    ctx:equal(state.inProgress == true, false, 'Truck robbery in progress')
    ctx:equal(state.coords, nil, 'Truck spawn coords')
    ctx:equal(state.endCoords, nil, 'Truck drop-off coords')
end)

-- Precondition, not a fixture: the refusal can only be observed when the real
-- police count is below Config.ActivePolice (2). Fails clearly otherwise.
K.step('fewer police are on duty than the truck robbery needs', 'server', function()
    local count = K.export('kora_core', 'getDutyCountByType', 'leo')
    assert(type(count) == 'number', 'Police duty count is unavailable')
    assert(count < 2, ('%d police are on duty; this scenario needs fewer than 2'):format(count))
end)

K.step('the truck robbery police requirement is waived for my next attempt', 'server', function(ctx)
    local tester = ctx.tester
    ctx:cleanup(function() pcall(function() exports[RESOURCE]:fftAction('reset', tester) end) end)
    K.must(K.hook(RESOURCE, 'waive', tester))
end)

K.step('the truck robbery should be in progress with a configured route', 'server', function(ctx)
    ctx:waitUntil(function() return published().inProgress == true end, 'Truck robbery did not start', 5000)
    local state = serverState(ctx)
    ctx:equal(state.startedByTester, true, 'Robbery started by the tester')
    ctx:equal(state.routeConfigured, true, 'Spawn and drop-off come from the config lists')
end)

K.step('the truck robbery should still be in progress', 'server', function(ctx)
    Wait(1000)
    ctx:equal(published().inProgress == true, true, 'Truck robbery in progress')
end)

K.step('the truck robbery test state is reset', 'server', function(ctx)
    K.must(K.hook(RESOURCE, 'reset', ctx.tester))
    ctx:waitUntil(function() return published().inProgress ~= true end, 'Truck robbery is still in progress after the reset', 3000)
end)

-- Client side of a started robbery: one local stockade and three guards.
K.step('the truck robbery truck and guards should have spawned for me', 'client', function(ctx)
    ctx:cleanup(function() pcall(function() exports[RESOURCE]:fftAction('cleanup') end) end)
    ctx:waitUntil(function()
        local state = K.hook(RESOURCE, 'state')
        return type(state) == 'table' and state.trucks >= 1 and state.guards >= 3
    end, 'The stockade and its three guards did not spawn', 12000)
end)

K.step('the truck robbery truck and guards are removed', 'client', function(ctx)
    K.must(K.hook(RESOURCE, 'cleanup'))
    ctx:waitUntil(function()
        local state = K.hook(RESOURCE, 'state')
        return type(state) == 'table' and state.trucks == 0 and state.guards == 0
    end, 'Robbery entities are still present', 3000)
end)

-- The event client/client.lua sends after looting the truck at the drop-off,
-- sent here from the dealer instead. The server refuses it with an assert, which
-- prints one script error in the server console.
K.step('I claim the truck robbery is finished without delivering the truck', 'client', function()
    TriggerServerEvent('qb-truckrobbery:server:endRobbery')
end)

-- ---------------------------------------------------------------------------
-- Start callback, route and drop-off rules (kora_truckrobbery/server/server.lua)
-- ---------------------------------------------------------------------------

-- fft_hooks_server.lua `state`: police count and Config.ActivePolice as read by the start.
K.step('the truck robbery server should report it idle and needing {int} police', 'server', function(ctx, required)
    local state = serverState(ctx)
    ctx:equal(state.inProgress, false, 'Truck robbery in progress')
    ctx:equal(state.coords, nil, 'Truck spawn coords')
    ctx:equal(state.endCoords, nil, 'Truck drop-off coords')
    ctx:equal(state.startedByTester, false, 'Robbery started by the tester')
    ctx:equal(state.required, required, 'Config.ActivePolice')
    assert(type(state.police) == 'number', 'Police count unavailable')
end)

-- The callback client/client.lua startRobbery() calls, asked directly so no
-- truck or guards are spawned. callback_triggerPacked answers one envelope; a
-- raised handler assert arrives as { __kora_lib_rejected = true, error }
-- (callback_trigger would raise across the export boundary and lose the
-- message). Stored as pcall-shaped results: ok flag, then values or error.
K.step('I ask the dealer to start the truck robbery', 'client', function(ctx)
    K.started(RESOURCE)
    local ok, packed = pcall(function()
        return exports.kora_lib:callback_triggerPacked('qb-truckrobbery:server:startRobbery')
    end)
    if not ok then
        ctx.state.truckStart = { n = 2, false, tostring(packed) }
    elseif type(packed) == 'table' and packed.__kora_lib_rejected then
        ctx.state.truckStart = { n = 2, false, tostring(packed.error) }
    else
        packed = type(packed) == 'table' and packed or { n = 0 }
        ctx.state.truckStart = table.pack(true, table.unpack(packed, 1, tonumber(packed.n) or #packed))
    end
end)
local function startAnswer(ctx)
    return assert(ctx.state.truckStart, 'Ask the dealer to start the truck robbery first')
end
K.step('the dealer should accept the truck robbery', 'client', function(ctx)
    local results = startAnswer(ctx)
    assert(results[1], 'The start callback failed: ' .. tostring(results[2]))
    ctx:equal(results[2], true, 'Start accepted')
end)
K.step('the dealer should decline the truck robbery', 'client', function(ctx)
    local results = startAnswer(ctx)
    assert(results[1], 'The start callback failed: ' .. tostring(results[2]))
    ctx:equal(results[2], false, 'Start accepted')
end)
K.step('the dealer should fail the truck robbery with {string}', 'client', function(ctx, text)
    local results = startAnswer(ctx)
    assert(not results[1], 'The start callback answered: ' .. tostring(results[2]))
    assert(K.contains(tostring(results[2]), text),
        ('Start failed with "%s", expected it to mention "%s"'):format(tostring(results[2]), text))
end)

-- GlobalState.TruckRobbery against the hook's view of robData.
K.step('the published truck robbery route should match the server', 'server', function(ctx)
    local state, public = serverState(ctx), published()
    ctx:equal(state.inProgress, true, 'Truck robbery in progress')
    ctx:equal(state.routeConfigured, true, 'Spawn and drop-off come from the config lists')
    for _, key in ipairs({ 'coords', 'endCoords' }) do
        local a, b = state[key], public[key]
        assert(a and b and math.abs(a.x - b.x) < 0.01 and math.abs(a.y - b.y) < 0.01 and math.abs(a.z - b.z) < 0.01,
            ('Published %s differs from the server'):format(key))
    end
end)
K.step('I remember the truck robbery route', 'server', function(ctx)
    local state = serverState(ctx)
    assert(state.coords and state.endCoords, 'No truck robbery route is set')
    ctx.state.truckRoute = json.encode({ state.coords, state.endCoords })
end)
K.step('the truck robbery route should be unchanged', 'server', function(ctx)
    local before = assert(ctx.state.truckRoute, 'Remember the truck robbery route first')
    Wait(500)
    local state = serverState(ctx)
    ctx:equal(json.encode({ state.coords, state.endCoords }), before, 'Truck robbery route')
end)

-- The drop-off is random (Config.VehicleDropOff), so it is read from the
-- published state the client itself reads in client/client.lua.
K.step('I stand at the truck robbery drop-off', 'client', function(ctx)
    local state = GlobalState.TruckRobbery
    local at = type(state) == 'table' and state.endCoords
    assert(at, 'No truck robbery drop-off is published')
    K.teleport(ctx, at.x, at.y, at.z)
end)

-- client/client.lua: the robbery start sends endRobbery after looting.
-- (Same event as the existing step; this one is sent from wherever the tester stands.)
K.step('I claim the truck robbery is finished from here', 'client', function()
    TriggerServerEvent('qb-truckrobbery:server:endRobbery')
end)

K.step('no robbery truck or guards should exist for me', 'client', function()
    Wait(1000)
    local state = K.hook(RESOURCE, 'state')
    assert(type(state) == 'table', 'kora_truckrobbery client hook returned no state')
    assert(state.trucks == 0 and state.guards == 0,
        ('%d trucks and %d guards are present'):format(state.trucks, state.guards))
end)

-- client/client.lua handlePeds/blip: driver seat -1 and passengers 0 and 1,
-- WEAPON_ASSAULTRIFLE each, blip sprite 477 colour 1 on the truck.
K.step('the robbery truck should carry three armed guards and its blip', 'client', function(ctx)
    local stockade, guard = GetHashKey('stockade'), GetHashKey('s_m_m_security_01')
    local truck
    ctx:waitUntil(function()
        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            if GetEntityModel(vehicle) == stockade and not NetworkGetEntityIsNetworked(vehicle) then truck = vehicle return true end
        end
    end, 'No local stockade found', 5000)
    for _, seat in ipairs({ -1, 0, 1 }) do
        local ped = GetPedInVehicleSeat(truck, seat)
        assert(ped ~= 0 and GetEntityModel(ped) == guard, 'No security guard in seat ' .. seat)
        assert(HasPedGotWeapon(ped, GetHashKey('WEAPON_ASSAULTRIFLE'), false), 'Guard in seat ' .. seat .. ' is unarmed')
    end
    local blip = GetBlipFromEntity(truck)
    assert(blip ~= 0 and DoesBlipExist(blip), 'The truck has no blip')
    ctx:equal(GetBlipSprite(blip), 477, 'Truck blip sprite')
    ctx:equal(GetBlipColour(blip), 1, 'Truck blip colour')
end)

-- The dealer (Config.DealerCoords 960.78 -216.25 76.25, a local ped from
-- client/client.lua) stands on a raised spot: the old fixed stand point at
-- 961.9 -216.25 dropped the tester about 4 m to the ground beside a wall, out
-- of reach. K.face tries each side of the dealer, raised 1 m so the tester
-- lands on whatever the dealer stands on, until "start Robbery" (locales/en.lua
-- targets.dealer.start_robbery) is under the crosshair.
local DEALER = { x = 960.78, y = -216.25, z = 76.25, model = 'a_m_m_skater_01' }
K.step('I face the truck robbery dealer', 'client', function(ctx)
    local hash = GetHashKey(DEALER.model)
    K.face(ctx, 'start Robbery', DEALER.x, DEALER.y, DEALER.z, {
        distance = 1.2, lift = 1.0,
        find = function()
            for _, ped in ipairs(GetGamePool('CPed')) do
                if GetEntityModel(ped) == hash and #(GetEntityCoords(ped) - vector3(DEALER.x, DEALER.y, DEALER.z)) < 2.5 then
                    return ped
                end
            end
        end,
    })
end)

-- client/client.lua: Kora.entities.create('a_m_m_skater_01', Config.DealerCoords, ...).
K.step('the truck robbery dealer should stand at 960.78 -216.25 76.25', 'client', function(ctx)
    local model, spot = GetHashKey('a_m_m_skater_01'), vector3(960.78, -216.25, 76.25)
    ctx:waitUntil(function()
        for _, ped in ipairs(GetGamePool('CPed')) do
            if GetEntityModel(ped) == model then
                local at = GetEntityCoords(ped)
                if #(vector2(at.x, at.y) - vector2(spot.x, spot.y)) < 1.0 and math.abs(at.z - spot.z) < 2.0 then return true end
            end
        end
    end, 'The dealer ped is not at Config.DealerCoords', 5000)
end)
