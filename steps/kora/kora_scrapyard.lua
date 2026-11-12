-- kora_scrapyard: wanted vehicle list (AppShell app) and the "Demolish Vehicle" bay.
-- No resource hook: the list is a kora_lib AppShell app, the list ped and the bay
-- are kora_target options, and the dismantle is a kora_lib progress bar.
local K = FFT.kora
if not K then return end
K.feature('kora_scrapyard')

-- kora_scrapyard/client/vehiclelist.lua
local LIST_ACTION = 'kora_scrapyard:confirm'

-- Ordinary cars copied from Config.Vehicles (kora_scrapyard/shared/config.lua).
-- The server lists 40 of the 69 configured models each hour, and kora_lib's
-- hook does not expose list items that deep, so the step asks the open list
-- about each candidate the way a click on that row would.
local CANDIDATES = { 'asea', 'blista', 'panto', 'rhapsody', 'prairie', 'asbo', 'stanier', 'washington',
    'tailgater', 'oracle', 'sultan', 'buffalo' }

-- Config.Items plus the bonus 'rubber' (kora_scrapyard/server/server.lua finishScrap).
local MATERIALS = { 'metalscrap', 'plastic', 'copper', 'iron', 'aluminum', 'steel', 'glass', 'rubber' }

-- A listed model answers with no notice (it sends a toast instead); an unlisted
-- one answers with the "no longer on the wanted list" warning.
K.step('I pick a car from the scrapyard vehicle list', 'client', function(ctx)
    for _, model in ipairs(CANDIDATES) do
        local _, result = K.must(K.ui('app.action', LIST_ACTION, { itemId = model }))
        if type(result) ~= 'table' or result.notice == nil then
            ctx.state.scrapModel = model
            return
        end
    end
    error('None of the candidate cars is on the current scrapyard list; rerun after the hourly rotation', 0)
end)

-- Same client-side temporary vehicle as the generic "I am driving a temporary
-- {string}" step, for the model picked from the list. Never an owned vehicle.
K.step('I am driving a temporary car of the picked scrapyard model', 'client', function(ctx)
    local model = assert(ctx.state.scrapModel, 'Pick a car from the scrapyard vehicle list first')
    local hash = GetHashKey(model)
    assert(IsModelInCdimage(hash) and IsModelAVehicle(hash), 'Unknown vehicle model: ' .. model)
    RequestModel(hash)
    ctx:waitUntil(function() return HasModelLoaded(hash) end, 'Vehicle model did not load: ' .. model, 10000)
    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    local vehicle = CreateVehicle(hash, at.x, at.y, at.z + 0.5, GetEntityHeading(ped), true, false)
    assert(vehicle and vehicle ~= 0, 'Vehicle did not spawn')
    ctx.state.vehicle = vehicle
    ctx:cleanup(function()
        if DoesEntityExist(vehicle) then
            TaskLeaveVehicle(PlayerPedId(), vehicle, 16)
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(vehicle)
    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    ctx:waitUntil(function() return GetVehiclePedIsIn(PlayerPedId(), false) == vehicle end, 'Could not enter the vehicle', 3000)
end)

K.step('the scrapyard should have removed my vehicle', 'client', function(ctx)
    local vehicle = assert(ctx.state.vehicle, 'No temporary vehicle was spawned')
    ctx:waitUntil(function() return not DoesEntityExist(vehicle) end, 'The scrapped vehicle still exists', 5000)
end)

K.step('my temporary vehicle should still exist', 'client', function(ctx)
    local vehicle = assert(ctx.state.vehicle, 'No temporary vehicle was spawned')
    assert(DoesEntityExist(vehicle), 'The vehicle was removed')
end)

local function materials(ctx)
    local counts, total = {}, 0
    for _, item in ipairs(MATERIALS) do
        counts[item] = K.count(ctx, item)
        total = total + counts[item]
    end
    return counts, total
end

-- Records the baseline and hands back anything the scrapyard grants afterwards.
K.step('I remember my scrap materials', 'server', function(ctx)
    local before, total = materials(ctx)
    ctx.state.scrapBaseline = total
    local core, tester = exports.kora_core, ctx.tester
    ctx:cleanup(function()
        for _, item in ipairs(MATERIALS) do
            local extra = (core:getItemCount(tester, item) or 0) - before[item]
            if extra > 0 then core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
        end
    end)
end)

K.step('I should have gained at least {int} scrap materials', 'server', function(ctx, amount)
    local baseline = assert(ctx.state.scrapBaseline, 'Remember the scrap materials first')
    ctx:waitUntil(function() return select(2, materials(ctx)) - baseline >= amount end,
        ('Gained %d scrap materials, expected at least %d'):format(select(2, materials(ctx)) - baseline, amount), 5000)
end)

K.step('I should not have gained scrap materials', 'server', function(ctx)
    local baseline = assert(ctx.state.scrapBaseline, 'Remember the scrap materials first')
    local _, total = materials(ctx)
    ctx:equal(total - baseline, 0, 'Scrap materials gained')
end)

-- ---------------------------------------------------------------------------
-- Round 3: list contents, list refusals, bay refusals, attendant and blip.
-- ---------------------------------------------------------------------------

-- Config.Locations[1].list (shared/config.lua) and the attendant model
-- (client/vehiclelist.lua: a_m_m_skater_01 at list.coords.z - 1.0).
local LIST_POINT = { 2403.51, 3127.95, 48.15 }
local function listPoint() return vector3(LIST_POINT[1], LIST_POINT[2], LIST_POINT[3]) end
local ATTENDANT = 'a_m_m_skater_01'
-- Config.VehicleCount
local LIST_SIZE = 40

-- Every car in Config.Vehicles with a passenger seat; used to find a
-- configured car that is not on this hour's list.
local CONFIGURED_CARS = { 'asea', 'blista', 'panto', 'rhapsody', 'prairie', 'asbo', 'stanier', 'washington',
    'tailgater', 'oracle', 'oracle2', 'sultan', 'buffalo', 'buffalo2', 'felon', 'sentinel', 'sentinel2', 'exemplar',
    'jackal', 'fusilade', 'blista2', 'schafter2', 'schwarzer', 'serrano', 'cognoscenti', 'zion', 'zion2', 'f620',
    'ninef', 'ninef2', 'banshee', 'alpha', 'baller', 'baller2', 'huntley', 'pigalle', 'bullet', 'turismor', 'zentorno',
    'dominator', 'blade', 'chino', 'sabregt', 'gauntlet', 'virgo', 'fq2', 'jester', 'feltzer2', 'ruiner', 'rebel',
    'slamvan', 'tampa', 'rocoto', 'seminole', 'landstalker', 'picador', 'bobcatxl', 'cavalcade', 'cavalcade2',
    'comet2', 'sandking', 'sandking2', 'ratloader2', 'bison' }

local function listApp(ctx)
    ctx:waitUntil(function() local app = K.uiState().app return app and app.id == 'kora_scrapyard:vehicleList' end,
        'The scrapyard vehicle list is not open')
    local payload = K.ui('app')
    assert(type(payload) == 'table' and type(payload.app) == 'table', 'No app payload is available')
    return payload.app
end

local function listBlock(app)
    for _, view in pairs(type(app.navigation) == 'table' and app.navigation or {}) do
        if type(view) == 'table' and view.id == 'view_list' then
            for _, block in pairs(type(view.content) == 'table' and view.content.blocks or {}) do
                if type(block) == 'table' and block.id == 'items' then return block, view end
            end
        end
    end
    error('The vehicle list has no view_list/items block', 0)
end

-- client/vehiclelist.lua buildNavigation and Config.vehicleList (imageFit
-- 'contain', imageAspect 'wide'). The list holds at most Config.VehicleCount
-- entries; dismantled ones are removed until the hourly rotation.
K.step('the scrapyard vehicle list should show the wanted cars', 'client', function(ctx)
    local app = listApp(ctx)
    ctx:equal(app.title, 'Vehicle List', 'App title')
    ctx:equal(app.footer, 'Press Escape to close', 'App footer')
    local block, view = listBlock(app)
    ctx:equal(view.label, 'Vehicle List', 'View label')
    ctx:equal(block.type, 'list', 'Block type')
    ctx:equal(block.imageFit, 'contain', 'Image fit')
    ctx:equal(block.imageAspect, 'wide', 'Image aspect')
    local n = 0
    for key in pairs(type(block.items) == 'table' and block.items or {}) do if key ~= '...' then n = n + 1 end end
    assert(n >= 1 and n <= LIST_SIZE, ('The list shows %d vehicles, expected 1-%d'):format(n, LIST_SIZE))
end)

-- An unlisted model answers a warning and a fresh navigation (update.navigation).
K.step('the scrapyard list answer should carry a refreshed list', 'client', function(ctx)
    local result = ctx.state.appResult or {}
    assert(type(result.update) == 'table' and type(result.update.navigation) == 'table',
        'The answer did not refresh the vehicle list')
end)

K.step('I pick a configured car that is not on the scrapyard list', 'client', function(ctx)
    for _, model in ipairs(CONFIGURED_CARS) do
        local _, result = K.must(K.ui('app.action', LIST_ACTION, { itemId = model }))
        if type(result) == 'table' and type(result.notice) == 'table' and result.notice.tone == 'warning' then
            ctx.state.scrapModel = model
            return
        end
    end
    error('Every configured car is on the scrapyard list', 0)
end)

local function spawnAsPassenger(ctx, model)
    local hash = GetHashKey(model)
    assert(IsModelInCdimage(hash) and IsModelAVehicle(hash), 'Unknown vehicle model: ' .. model)
    RequestModel(hash)
    ctx:waitUntil(function() return HasModelLoaded(hash) end, 'Vehicle model did not load: ' .. model, 10000)
    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    local vehicle = CreateVehicle(hash, at.x, at.y, at.z + 0.5, GetEntityHeading(ped), true, false)
    assert(vehicle and vehicle ~= 0, 'Vehicle did not spawn')
    ctx.state.vehicle = vehicle
    ctx:cleanup(function()
        if DoesEntityExist(vehicle) then
            TaskLeaveVehicle(PlayerPedId(), vehicle, 16)
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(vehicle)
    assert(GetVehicleMaxNumberOfPassengers(vehicle) >= 1, model .. ' has no passenger seat')
    TaskWarpPedIntoVehicle(ped, vehicle, 0)
    ctx:waitUntil(function() return GetPedInVehicleSeat(vehicle, 0) == PlayerPedId() end, 'Could not take the passenger seat', 3000)
    assert(GetPedInVehicleSeat(vehicle, -1) == 0, 'Someone is in the driver seat')
end

-- client/client.lua scrapVehicle refuses anyone not in seat -1 before the server is asked.
K.step('I sit as a passenger in a temporary {string}', 'client', function(ctx, model) spawnAsPassenger(ctx, model) end)
K.step('I sit as a passenger in a temporary car of the picked scrapyard model', 'client', function(ctx)
    spawnAsPassenger(ctx, assert(ctx.state.scrapModel, 'Pick a car from the scrapyard vehicle list first'))
end)

K.step('the scrapyard attendant should stand at the list point', 'client', function(ctx)
    local hash = GetHashKey(ATTENDANT)
    ctx:waitUntil(function()
        for _, ped in ipairs(GetGamePool('CPed')) do
            if GetEntityModel(ped) == hash and #(GetEntityCoords(ped) - listPoint()) < 2.5 then return true end
        end
    end, 'No scrapyard attendant stands near the list point', 8000)
end)

-- client/client.lua: one sprite 380 blip per Config.Locations list point.
K.step('the scrapyard should be marked on the map', 'client', function()
    local blip = GetFirstBlipInfoId(380)
    while DoesBlipExist(blip) do
        if #(GetBlipInfoIdCoord(blip) - listPoint()) < 1.0 then return end
        blip = GetNextBlipInfoId(380)
    end
    error('No sprite 380 blip at the scrapyard list point', 0)
end)
