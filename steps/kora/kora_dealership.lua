-- kora_dealership: the customer side of a public dealership (browse a display
-- vehicle, swap the display, buy from the showroom app).
-- No resource hook: the display vehicles carry a kora_target entity option,
-- the showroom is the kora_lib app `kora_dealership:showroom`, the catalogue and
-- the display swaps are replicated as GlobalState.Dealerships /
-- GlobalState.DealershipSwaps (server/functions.lua fn.publish), and a purchase
-- is asserted from the tester's player_vehicles rows (kora_core getByOwner) and
-- the server event `qb-vehicleshop:server:onVehiclePurchased`.
-- Dealership data lives in the database (seeded by server/schema.lua), so
-- placements and prices are read from GlobalState at run time, never copied.
local K = FFT.kora
if not K then return end
K.feature('kora_dealership')

local BROWSE = 'Browse dealership' -- locales/en.lua c.customer.target

local function squash(plate) return (tostring(plate or ''):gsub('%s+', '')):upper() end

local function dealership(id)
    local all = GlobalState.Dealerships
    local record = type(all) == 'table' and all[id]
    assert(type(record) == 'table', 'Dealership is not published in GlobalState.Dealerships: ' .. id)
    return record
end

local function listing(record, model)
    for _, entry in ipairs(record.vehicles or {}) do
        if entry.model == model then return entry end
    end
end

-- The placement whose configured (default) model is `model`.
local function placementOf(record, model)
    for index, placement in ipairs(record.placements or {}) do
        if placement.model == model then return index, placement end
    end
    error('No display placement defaults to ' .. model, 0)
end

local function shownModel(id, index, placement)
    local swaps = GlobalState.DealershipSwaps
    local forDealer = type(swaps) == 'table' and swaps[id]
    return forDealer and forDealer[tostring(index)] or placement.model
end

-- Purchases are only driven at public dealerships: there fn.adjustStock and
-- fn.creditSale change nothing, so a test purchase touches no dealership funds
-- or stock (server/functions.lua).
local function publicListing(id, model)
    local record = dealership(id)
    assert(record.type == 'public', ('Dealership %s is %s; test purchases are limited to public dealerships'):format(id, tostring(record.type)))
    local entry = listing(record, model)
    assert(entry, ('%s is not sold at %s'):format(model, id))
    local price = math.floor(tonumber(entry.price) or 0)
    assert(price >= 1 and price <= 100000, ('Listed price of %s is %d; refusing a test purchase outside 1-100000'):format(model, price))
    return price
end

-- ---------------------------------------------------------------------------
-- Server: catalogue, funds and owned vehicles
-- ---------------------------------------------------------------------------

K.step('the dealership {string} should be a {word} dealership selling {string}', 'server', function(ctx, id, kind, model)
    local record = dealership(id)
    ctx:equal(record.type, kind, 'Type of dealership ' .. id)
    local entry = listing(record, model)
    assert(entry, ('%s is not sold at %s'):format(model, id))
    assert((tonumber(entry.price) or 0) >= 1, 'Listed price of ' .. model .. ' is not positive')
end)
K.step('the dealership {string} should display {string} by default', 'server', function(_, id, model)
    local _, placement = placementOf(dealership(id), model)
    local coords = placement.coords
    assert(type(coords) == 'table' and coords.x and coords.y and coords.z, 'Display placement has no coordinates')
end)

local function setBank(ctx, amount)
    local core, tester = exports.kora_core, ctx.tester
    local original = K.money(ctx, 'bank')
    ctx:cleanup(function() core:setMoney(tester, 'bank', original, 'functional test cleanup') end)
    local ok, err = core:setMoney(tester, 'bank', amount, 'functional test')
    assert(ok, 'Could not set the bank balance: ' .. tostring(err))
    ctx.state.dealershipBank = amount
end
K.step('my bank covers the {string} listed at dealership {string} with {int} to spare', 'server', function(ctx, model, id, spare)
    assert(spare >= 0 and spare <= 10000, 'Spare amount must be 0-10000')
    setBank(ctx, publicListing(id, model) + spare)
end)
K.step('my bank is {int} short of the {string} listed at dealership {string}', 'server', function(ctx, short, model, id)
    local price = publicListing(id, model)
    assert(short >= 1 and short <= price, 'Shortfall must be between 1 and the listed price')
    setBank(ctx, price - short)
end)
K.step('I should have paid the listed price of {string} at dealership {string} from my bank', 'server', function(ctx, model, id)
    local price = publicListing(id, model)
    local before = assert(ctx.state.dealershipBank, 'The bank balance was not set by a dealership step')
    ctx:waitUntil(function() return K.money(ctx, 'bank') == before - price end,
        ('Bank is %s, expected %d'):format(tostring(K.money(ctx, 'bank')), before - price), 5000)
end)
K.step('the dealership should not have charged my bank', 'server', function(ctx)
    local before = assert(ctx.state.dealershipBank, 'The bank balance was not set by a dealership step')
    Wait(1500)
    ctx:equal(K.money(ctx, 'bank'), before, 'Bank balance')
end)

local function ownedPlates(citizenid)
    local plates = {}
    for _, vehicle in ipairs(exports.kora_core:getByOwner(citizenid) or {}) do plates[squash(vehicle.plate)] = vehicle end
    return plates
end
local function entityFor(plate)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and squash(GetVehicleNumberPlateText(vehicle)) == plate then return vehicle end
    end
end
local function newVehicles(ctx)
    local list = {}
    for plate, vehicle in pairs(ownedPlates(ctx.state.dealershipOwner)) do
        if not ctx.state.dealershipOwned[plate] then list[#list + 1] = vehicle end
    end
    return list
end

-- Snapshots the tester's vehicles. Cleanup removes every vehicle the scenario
-- added to that list: the delivered entity, its session keys and the row
-- (kora_core deleteVehicle, a soft delete).
K.step('I note the vehicles I own before visiting the dealership', 'server', function(ctx)
    local tester, citizenid = ctx.tester, K.player(ctx).citizenid
    local before = ownedPlates(citizenid)
    ctx.state.dealershipOwner, ctx.state.dealershipOwned = citizenid, before
    ctx:cleanup(function()
        for plate in pairs(ownedPlates(citizenid)) do
            if not before[plate] then
                local entity = entityFor(plate)
                if entity then DeleteEntity(entity) end
                pcall(function() exports.kora_vehiclekeys:removeKeys(tester, plate) end)
                pcall(function() exports.kora_core:deleteVehicle(plate) end)
            end
        end
    end)
    -- server/functions.lua fn.deliverVehicle: TriggerEvent(..., cid, model, plate).
    K.capture(ctx, 'qb-vehicleshop:server:onVehiclePurchased', function(cid) return cid == citizenid end)
end)

K.step('the dealership should have delivered me one new {string} with its keys', 'server', function(ctx, model)
    assert(ctx.state.dealershipOwned, 'Note the owned vehicles first')
    local added
    ctx:waitUntil(function()
        added = newVehicles(ctx)
        return #added == 1
    end, ('Expected 1 new owned vehicle, found %d'):format(added and #added or 0), 8000)
    local vehicle = added[1]
    local plate = squash(vehicle.plate)
    ctx:equal(vehicle.vehicle or vehicle.model, model, 'Model of the purchased vehicle')
    ctx:equal(vehicle.state, 'out', 'State of the purchased vehicle')
    ctx:equal(K.export('kora_vehiclekeys', 'hasKeys', ctx.tester, plate), true, 'Keys for ' .. plate)
    -- functions.lua deliverVehicle sets the plate with the server RPC native; the
    -- server reads it back only once the owning client has synced the entity.
    ctx:waitUntil(function() return entityFor(plate) ~= nil end,
        'No spawned vehicle carries the purchased plate ' .. plate, 5000)
    local events = K.captured(ctx, 'qb-vehicleshop:server:onVehiclePurchased')
    ctx:equal(#events, 1, 'onVehiclePurchased events')
    ctx:equal(events[1][2], model, 'onVehiclePurchased model')
    ctx:equal(squash(events[1][3]), plate, 'onVehiclePurchased plate')
end)
K.step('the dealership should not have delivered me a vehicle', 'server', function(ctx)
    assert(ctx.state.dealershipOwned, 'Note the owned vehicles first')
    Wait(1500)
    ctx:equal(#newVehicles(ctx), 0, 'New owned vehicles')
    ctx:equal(#K.captured(ctx, 'qb-vehicleshop:server:onVehiclePurchased'), 0, 'onVehiclePurchased events')
end)

K.step('the {string} display of dealership {string} should show {string}', 'server', function(ctx, default, id, model)
    local index, placement = placementOf(dealership(id), default)
    local seen
    ctx:waitUntil(function()
        seen = shownModel(id, index, placement)
        return seen == model
    end, ('Display %d shows %s, expected %s'):format(index, tostring(seen), model), 3000)
end)

-- ---------------------------------------------------------------------------
-- Client: the display vehicle and the showroom app
-- ---------------------------------------------------------------------------

-- The client-local display vehicle standing on a placement.
local function displayEntity(placement)
    local at = vector3(placement.coords.x + 0.0, placement.coords.y + 0.0, placement.coords.z + 0.0)
    local best, bestDistance
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local distance = #(GetEntityCoords(vehicle) - at)
        if distance < 2.0 and (not bestDistance or distance < bestDistance) then best, bestDistance = vehicle, distance end
    end
    return best
end

local function stopTargeting() pcall(function() exports.kora_target:fftAction('stop') end) end

-- Walks up to the display vehicle of a placement and selects its
-- "Browse dealership" target option. The showroom layout is database data, so
-- the step tries the four sides of the car (2.6 m from its centre, inside the
-- server's 5 m purchase range) until the option is the one under the camera.
K.step('I browse the {string} display of dealership {string}', 'client', function(ctx, model, id)
    local _, placement = placementOf(dealership(id), model)
    local coords = placement.coords
    local heading = math.rad((coords.w or 0.0) + 0.0)
    local forward = { x = -math.sin(heading), y = math.cos(heading) }
    local sides = {
        { forward.x, forward.y }, { -forward.x, -forward.y },
        { forward.y, -forward.x }, { -forward.y, forward.x },
    }
    ctx:cleanup(stopTargeting)
    local entity, found
    for _, side in ipairs(sides) do
        K.teleport(ctx, coords.x + side[1] * 2.6, coords.y + side[2] * 2.6, coords.z + 1.0)
        entity = entity or ctx:waitUntil(function() return displayEntity(placement) end, 'No display vehicle stands on the ' .. model .. ' placement', 4000)
        local at = GetEntityCoords(entity)
        K.aimAt(at.x, at.y, at.z + 0.2)
        local deadline = GetGameTimer() + 1500
        while GetGameTimer() < deadline and not found do
            ctx:check()
            if exports.kora_target:fftAction('start') then
                local hover = exports.kora_target:fftAction('hovering')
                found = hover and hover.entity == entity
            end
            if not found then Wait(100) end
        end
        if found then break end
        stopTargeting()
    end
    assert(found, 'The ' .. model .. ' display vehicle could not be targeted from any side')
    -- A display vehicle can carry other vehicle options, in which case
    -- K.target answers kora_lib's interact selector and does not itself see
    -- whether the option ran. kora_target counts every option that passed
    -- runOption's gates (kora_target/client/loop.lua:795 -> fft_hooks.lua
    -- `selections`), so fail here rather than 15 s later on the app step.
    local function selections()
        local state = exports.kora_target:fftAction('state')
        return type(state) == 'table' and tonumber(state.selections) or 0
    end
    local before = selections()
    K.target(ctx, BROWSE, entity)
    ctx:waitUntil(function() return selections() > before end,
        'The "' .. BROWSE .. '" option was chosen but kora_target never ran it', 2000)
end)

-- The Swap button of a vehicle card. A swap is in-memory server state every
-- player sees (GlobalState.DealershipSwaps), so cleanup presses "Reset display
-- to default" if the showroom is still open; a restart of kora_dealership also
-- clears it.
K.step('I swap the showroom display to {string}', 'client', function(ctx, model)
    ctx:cleanup(function()
        Wait(1100) -- Config.swapCooldown
        pcall(function() exports.kora_lib:fftAction('app.action', 'swap:reset') end)
    end)
    local _, result = K.must(K.ui('app.action', 'swap:' .. model, { itemId = model }))
    ctx.state.appResult = type(result) == 'table' and result or {}
end)

-- The purchase warps the tester into the delivered vehicle; step out so the
-- position restore and the server-side entity removal run on foot.
K.step('I get out of the vehicle the dealership delivered', 'client', function(ctx)
    local ped = PlayerPedId()
    ctx:waitUntil(function() return IsPedInAnyVehicle(ped, false) end, 'The tester was not placed in the purchased vehicle', 8000)
    local vehicle = GetVehiclePedIsIn(ped, false)
    TaskLeaveVehicle(ped, vehicle, 16)
    ctx:waitUntil(function() return not IsPedInAnyVehicle(PlayerPedId(), false) end, 'Could not leave the purchased vehicle', 5000)
end)

-- ===========================================================================
-- Round 3: the seeded catalogue, the customer callbacks driven directly
-- (purchase, test drive, offer, swap) with their refusals and rate limits, and
-- the owner/seller callbacks refused at a public dealership.
-- ===========================================================================

-- server/functions.lua cleanVehicles: a public dealership lists every vehicle
-- with publicStock = 9999.
K.step('every vehicle listed at dealership {string} should have a stock of {int}', 'server', function(ctx, id, stock)
    local record = dealership(id)
    assert(#(record.vehicles or {}) > 0, 'Dealership ' .. id .. ' lists no vehicles')
    for _, entry in ipairs(record.vehicles) do
        ctx:equal(tonumber(entry.stock), stock, 'Stock of ' .. tostring(entry.model))
    end
end)
-- Prices are the seeded server/schema.lua values (Config.UsePDM).
K.step('the dealership {string} should list {string} for {int}', 'server', function(ctx, id, model, price)
    local entry = listing(dealership(id), model)
    assert(entry, ('%s is not sold at %s'):format(model, id))
    ctx:equal(tonumber(entry.price), price, 'Listed price of ' .. model)
    assert(type(entry.name) == 'string' and entry.name ~= '', 'Listing of ' .. model .. ' has no display name')
end)
K.step('the dealership {string} should not list {string}', 'server', function(_, id, model)
    assert(not listing(dealership(id), model), model .. ' is sold at ' .. id)
end)

-- ---------------------------------------------------------------------------
-- Client: the customer callbacks (server/customer.lua, server/creator.lua)
-- ---------------------------------------------------------------------------

-- Keeps every returned value (kora_lib callback_triggerPacked envelope). A
-- rejection (handler error) raises and is returned as ok = false.
local function callServer(name, ...)
    local args = table.pack(...)
    local ok, packed = pcall(function()
        return exports.kora_lib:callback_triggerPacked(name, table.unpack(args, 1, args.n))
    end)
    if not ok then return false, nil, tostring(packed) end
    if type(packed) ~= 'table' then packed = { n = 1, packed } end
    return true, packed
end
local function mustCall(name, ...)
    local ok, packed, err = callServer(name, ...)
    assert(ok, ('%s failed: %s'):format(name, tostring(err)))
    return packed
end

-- A display reference is the default model of a placement ("issi3") or a raw
-- index ("7", "0", "1.5", "abc"); the raw value is sent as the client would.
local function displayIndex(id, display)
    local all = GlobalState.Dealerships
    local record = type(all) == 'table' and all[id]
    if type(record) == 'table' then
        for index, placement in ipairs(record.placements or {}) do
            if placement.model == display then return index end
        end
    end
    return tonumber(display) or display
end

-- Config.rateLimits (ms): each customer callback starts its cooldown before
-- validating, so a refusal step first waits out the previous call's window.
local actions = {
    buy = { name = 'kora_dealership:confirmPurchase', cooldown = 2000 },
    testdrive = { name = 'kora_dealership:testDrive', cooldown = 3000 },
    offer = { name = 'kora_dealership:makeOffer', cooldown = 5000 },
    swap = { name = 'kora_dealership:swap', cooldown = 1000 },
}
local function argumentsFor(kind, id, index, model)
    if kind == 'offer' then return id, index, model, 1000, 'functional test' end
    return id, index, model
end

-- A test drive that unexpectedly starts is ended at once (the server's own
-- kora_dealership:server:testDriveEnded, which deletes the car and restores the bucket).
local function endTestDriveOnCleanup(ctx)
    if ctx.state.dealershipTestDriveGuard then return end
    ctx.state.dealershipTestDriveGuard = true
    ctx:cleanup(function() TriggerServerEvent('kora_dealership:server:testDriveEnded') end)
end

local function refuse(ctx, kind, model, display, id, expected, wait)
    local action = assert(actions[kind], 'Use buy, testdrive, offer or swap')
    if kind == 'testdrive' then endTestDriveOnCleanup(ctx) end
    if wait then
        local deadline = GetGameTimer() + action.cooldown + 100
        while GetGameTimer() < deadline do ctx:check() Wait(50) end
    end
    local packed = mustCall(action.name, argumentsFor(kind, id, displayIndex(id, display), model))
    if kind == 'testdrive' and packed[1] then TriggerServerEvent('kora_dealership:server:testDriveEnded') end
    assert(packed[1] == false or packed[1] == nil, ('%s was not refused (answered %s)'):format(action.name, tostring(packed[1])))
    ctx:equal(packed[2], expected, action.name .. ' refusal')
end

K.step('asking to {word} {string} at display {string} of dealership {string} should be refused with {string}', 'client',
    function(ctx, kind, model, display, id, expected) refuse(ctx, kind, model, display, id, expected, true) end)
K.step('asking again at once to {word} {string} at display {string} of dealership {string} should be refused with {string}', 'client',
    function(ctx, kind, model, display, id, expected) refuse(ctx, kind, model, display, id, expected, false) end)

-- server/creator.lua swap: a model that is not text is refused before the cooldown.
K.step('asking to swap display {string} of dealership {string} to a number should be refused with {string}', 'client',
    function(ctx, display, id, expected)
        local packed = mustCall(actions.swap.name, id, displayIndex(id, display), 7)
        assert(packed[1] ~= true, 'The swap to a number was accepted')
        ctx:equal(packed[2], expected, 'kora_dealership:swap refusal')
    end)

-- A successful swap is server-wide (GlobalState.DealershipSwaps); cleanup
-- resets the placement to its default (swap with no model) after the cooldown.
K.step('I swap the {string} display of dealership {string} to {string} directly', 'client', function(ctx, display, id, model)
    local index = displayIndex(id, display)
    assert(math.type(index) == 'integer', 'Unknown display ' .. display)
    ctx:cleanup(function()
        Wait(1100) -- Config.swapCooldown
        pcall(function() exports.kora_lib:callback_triggerPacked(actions.swap.name, id, index) end)
    end)
    local deadline = GetGameTimer() + actions.swap.cooldown + 100
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
    local packed = mustCall(actions.swap.name, id, index, model)
    ctx:equal(packed[1], true, 'kora_dealership:swap answer (' .. tostring(packed[2]) .. ')')
end)

-- Buys at a public dealership (the bank is set by the dealership money steps).
K.step('I buy {string} at the {string} display of dealership {string} directly', 'client', function(ctx, model, display, id)
    local index = displayIndex(id, display)
    assert(math.type(index) == 'integer', 'Unknown display ' .. display)
    local deadline = GetGameTimer() + actions.buy.cooldown + 100
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
    local packed = mustCall(actions.buy.name, id, index, model)
    assert(math.type(packed[1]) == 'integer', 'kora_dealership:confirmPurchase refused: ' .. tostring(packed[2]))
end)

-- Stands 2.6 m in front of a placement (inside Config.testDriveDistance and
-- Config.swapDistance), the first side the browse step tries.
K.step('I stand beside the {string} display of dealership {string}', 'client', function(ctx, model, id)
    local _, placement = placementOf(dealership(id), model)
    local coords = placement.coords
    local heading = math.rad((coords.w or 0.0) + 0.0)
    K.teleport(ctx, coords.x - math.sin(heading) * 2.6, coords.y + math.cos(heading) * 2.6, coords.z + 1.0)
end)

-- Owner, employee and seller callbacks (server/Management.lua authorize,
-- server/sales.lua authorizeSale) refuse a dealership that is not owned before
-- anything else. Extra arguments are the shapes the client sends.
local ownerCalls = {
    ['management:openOwnerManagement'] = function(id) return id, 1 end,
    ['management:addEmployee'] = function(id) return id, 1, GetPlayerServerId(PlayerId()) end,
    ['management:removeEmployee'] = function(id) return id, 1, 'FFT00000' end,
    ['management:savePermissions'] = function(id) return id, 1, 'FFT00000', { 'sellVehicles' } end,
    ['management:saveSettings'] = function(id) return id, 1, { commission = 5 } end,
    ['management:savePlacement'] = function(id) return id, 1, { placements = {} } end,
    ['management:depositFunds'] = function(id) return id, 1, 100 end,
    ['management:withdrawFunds'] = function(id) return id, 1, 100 end,
    ['management:orderVehicle'] = function(id) return id, 1, 'issi3', 1 end,
    ['management:getOffers'] = function(id) return id, 1 end,
    ['management:resolveOffer'] = function(id) return id, 1, 1, 'deny' end,
    ['sales:open'] = function(id) return id, 1 end,
    ['sales:confirm'] = function(id) return id, 1, GetPlayerServerId(PlayerId()), 'issi3', 5000 end,
}
K.step('the dealership callback {string} for dealership {string} should be refused with {string}', 'client',
    function(ctx, short, id, expected)
        local build = assert(ownerCalls[short], 'Unknown dealership owner callback: ' .. short)
        local packed = mustCall('kora_dealership:' .. short, build(id))
        assert(packed[1] == false or packed[1] == nil, ('kora_dealership:%s was not refused'):format(short))
        ctx:equal(packed[2], expected, 'kora_dealership:' .. short .. ' refusal')
    end)

-- server/customer.lua testDrive warps the tester into the test car on success.
K.step('no test drive should have started', 'client', function()
    Wait(1000)
    assert(not IsPedInAnyVehicle(PlayerPedId(), false), 'The tester was put in a vehicle')
end)
