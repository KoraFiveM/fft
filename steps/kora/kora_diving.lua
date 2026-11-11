-- kora_diving: coral registry, the coral seller (kora_target ped option) and
-- the diving gear's oxygen rule.
-- No resource hook: the coral registry is GlobalState.Corals, the seller is a
-- kora_target option with a kora_lib progress bar, and the results are items
-- and cash the server owns.
--
-- Deliberately not driven: picking coral (40 m under water, marks the coral
-- picked for every player for five minutes, random reward), filling the gear
-- (client/client.lua keeps the oxygen level in a file-local with no reset, so
-- a filled tank would outlive the scenario) and putting the suit on.
local K = FFT.kora
if not K then return end
K.feature('kora_diving')

-- kora_diving/shared/config.lua. The resource's Config is not visible from here.
local SELLER = { x = -1684.13, y = -1068.91, z = 13.15, heading = 100.0, model = 'a_m_m_salton_01' } -- Config.SellLocations[1]
local CORALS = { 'dendrogyra_coral', 'antipatharia_coral' }                                          -- Config.CoralTypes
local GEAR = { diving_gear = true }                                                                  -- server/server.lua createUseable

-- ---------------------------------------------------------------------------
-- Server
-- ---------------------------------------------------------------------------

K.step('the diving coral registry should publish {int} corals with a position and a picked flag', 'server', function(ctx, expected)
    K.started('kora_diving')
    -- server/server.lua: GlobalState.Corals = Config.CoralLocations ({ coords = vector3, PickedUp = boolean }).
    local corals = GlobalState.Corals
    assert(type(corals) == 'table', 'GlobalState.Corals is not published')
    ctx:equal(#corals, expected, 'Published coral count')
    for index, coral in ipairs(corals) do
        assert(type(coral) == 'table', 'Coral ' .. index .. ' is not a table')
        local coords = coral.coords
        local kind = type(coords)
        assert((kind == 'vector3' or kind == 'table') and tonumber(coords.x) and tonumber(coords.y) and tonumber(coords.z),
            'Coral ' .. index .. ' has no coordinates')
        assert(type(coral.PickedUp) == 'boolean', 'Coral ' .. index .. ' has no boolean PickedUp flag')
    end
end)

-- The seller buys every coral the player carries, so a tester who already owns
-- coral would lose it and skew the payout. Fail early instead.
K.step('I should carry no coral of my own before visiting the diving seller', 'server', function(ctx)
    for _, item in ipairs(CORALS) do
        assert(K.count(ctx, item) == 0, 'Tester already carries ' .. item .. '; the seller would buy it too')
    end
end)

-- Config.CoralTypes prices are math.random() results fixed at server start and
-- not published, so the payout is asserted as a range.
K.step('the diving seller should have paid me between {int} and {int} in cash', 'server', function(ctx, low, high)
    local before = assert(ctx.state.moneyBaseline and ctx.state.moneyBaseline.cash, 'Remember the cash balance first')
    local gained = 0
    ctx:waitUntil(function()
        gained = K.money(ctx, 'cash') - before
        return gained >= low and gained <= high
    end, ('Cash changed by %d, expected +%d to +%d'):format(gained, low, high), 4000)
end)

-- Uses the gear the way the inventory does: kora_core runs the usable the
-- resource registered in server/server.lua.
K.step('I use my diving equipment {string}', 'server', function(ctx, item)
    assert(GEAR[item], 'Not a diving usable covered by this suite: ' .. tostring(item))
    assert(K.count(ctx, item) > 0, 'The tester holds no ' .. item)
    K.export('kora_core', 'useItem', ctx.tester, item)
end)

-- ---------------------------------------------------------------------------
-- Client: positioning. The ped is looked up in the game pool and the selection
-- itself goes through kora_target's hook (generic `I target {string}`).
-- ---------------------------------------------------------------------------

local function stopTargeting()
    pcall(function() exports.kora_target:fftAction('stop') end)
end

local function nearest(pool, model, x, y, z, radius)
    local hash, best, bestDistance = GetHashKey(model), nil, radius
    for _, entity in ipairs(GetGamePool(pool)) do
        if GetEntityModel(entity) == hash then
            local distance = #(GetEntityCoords(entity) - vector3(x, y, z))
            if distance <= bestDistance then best, bestDistance = entity, distance end
        end
    end
    return best
end

---Stands beside a point, trying each side in turn, until `label` is the option
---under the crosshair. `opts.find()` returns the entity the option must belong to.
local function face(ctx, label, x, y, z, opts)
    opts = opts or {}
    ctx:cleanup(stopTargeting)
    local deadline = GetGameTimer() + 8000
    repeat
        for _, turn in ipairs({ 0.0, 90.0, -90.0, 180.0 }) do
            local angle = math.rad((opts.heading or 0.0) + turn)
            K.teleport(ctx, x - math.sin(angle) * (opts.distance or 1.5), y + math.cos(angle) * (opts.distance or 1.5), z + (opts.lift or 0.0))
            local entity
            if opts.find then
                local appear = GetGameTimer() + 2000
                repeat entity = opts.find() if not entity then Wait(100) end until entity or GetGameTimer() > appear
            end
            if entity or not opts.find then
                local tried = GetGameTimer() + 1200
                while GetGameTimer() < tried do
                    ctx:check()
                    local at = entity and GetEntityCoords(entity) or vector3(x, y, z)
                    K.aimAt(at.x, at.y, at.z + (opts.aimLift or 0.0))
                    Wait(150)
                    if exports.kora_target:fftAction('start') then
                        local hover = exports.kora_target:fftAction('hovering')
                        if hover and (hover.label == label or hover.optionCount > 1) and (not entity or hover.entity == entity) then
                            stopTargeting()
                            return entity
                        end
                    end
                end
                stopTargeting()
            end
            if GetGameTimer() > deadline then break end
        end
    until GetGameTimer() > deadline
    error(('Could not bring the target option "%s" under the crosshair near %.2f %.2f %.2f'):format(label, x, y, z), 0)
end

K.step('I face the diving coral seller', 'client', function(ctx)
    -- client/client.lua createSeller: one ped per Config.SellLocations entry, option "Sell Coral".
    face(ctx, 'Sell Coral', SELLER.x, SELLER.y, SELLER.z, {
        heading = SELLER.heading, lift = 0.3, aimLift = 0.2,
        find = function() return nearest('CPed', SELLER.model, SELLER.x, SELLER.y, SELLER.z, 3.0) end,
    })
end)

-- ===========================================================================
-- Round 3: registry contents, request-level seller and pick validation, the
-- oxygen fill callback. The request-level steps send the same net events the
-- resource's own target options send after their progress bars
-- (client/client.lua createSeller / returnTarget), so the server's own checks
-- decide the outcome.
-- ===========================================================================

-- kora_diving/shared/config.lua Config.CoralLocations, in order.
local CORAL_POSITIONS = {
    { -2849.25, -377.58, -40.23 }, { -2838.43, -363.63, -39.45 }, { -2887.04, -394.87, -40.91 },
    { -2808.99, -385.56, -39.32 }, { -3275.03, -38.58, -19.21 }, { -3273.73, -76.0, -26.81 },
    { -3346.53, -50.4, -35.84 }, { -3388.01, 1635.88, -39.41 }, { -3354.19, 1549.3, -38.21 },
    { -3326.04, 1636.43, -40.98 }, { 2978.05, -1509.07, -24.96 }, { 3004.42, -1576.95, -29.36 },
    { 2951.65, -1560.69, -28.36 }, { 3421.69, 1976.54, -50.64 }, { 3424.07, 1957.46, -53.04 },
    { 3434.65, 1993.73, -49.84 }, { 3415.42, 1965.25, -52.04 }, { 2724.0, -2134.95, -19.33 },
    { 2710.68, -2156.06, -18.63 }, { 2702.84, -2139.29, -18.51 }, { 2736.27, -2153.91, -20.88 },
    { 542.31, 7245.37, -30.01 }, { 528.21, 7223.26, -29.51 }, { 510.36, 7254.97, -32.11 },
    { 525.37, 7259.12, -30.51 },
}
-- Config.CoralTypes pick rewards (min/max per pick).
local CORAL_REWARD = { dendrogyra_coral = { 1, 5 }, antipatharia_coral = { 2, 7 } }

local function firstUnpickedCoral()
    local corals = GlobalState.Corals
    assert(type(corals) == 'table', 'GlobalState.Corals is not published')
    for index, coral in ipairs(corals) do
        if coral.PickedUp == false then return index, coral end
    end
    error('Every coral is picked right now; they respawn five minutes after each pick', 0)
end

-- Server ------------------------------------------------------------------

K.step('the diving coral registry should list every configured coral position', 'server', function(ctx)
    local corals = GlobalState.Corals
    assert(type(corals) == 'table', 'GlobalState.Corals is not published')
    ctx:equal(#corals, #CORAL_POSITIONS, 'Published coral count')
    for index, expected in ipairs(CORAL_POSITIONS) do
        local coords = corals[index].coords
        local off = math.abs(coords.x - expected[1]) + math.abs(coords.y - expected[2]) + math.abs(coords.z - expected[3])
        assert(off < 0.05, ('Coral %d is at %.2f %.2f %.2f, config says %.2f %.2f %.2f'):format(
            index, coords.x, coords.y, coords.z, expected[1], expected[2], expected[3]))
    end
end)

K.step('I note what the diving seller paid for one coral', 'server', function(ctx)
    local before = assert(ctx.state.moneyBaseline and ctx.state.moneyBaseline.cash, 'Remember the cash balance first')
    local gained = 0
    ctx:waitUntil(function()
        gained = K.money(ctx, 'cash') - before
        return gained > 0
    end, 'The diving seller paid nothing', 4000)
    -- Config.CoralTypes prices are integers from math.random(50, 100) overall.
    assert(gained >= 50 and gained <= 100, ('One coral paid %d, outside every configured price range'):format(gained))
    ctx.state.divingCoralPrice = gained
end)

K.step('the diving seller should have paid exactly {int} times the noted coral price', 'server', function(ctx, times)
    local price = assert(ctx.state.divingCoralPrice, 'Note the price of one coral first')
    local before = assert(ctx.state.moneyBaseline and ctx.state.moneyBaseline.cash, 'Remember the cash balance first')
    local expected, gained = price * times, 0
    ctx:waitUntil(function()
        gained = K.money(ctx, 'cash') - before
        return gained == expected
    end, ('Expected cash +%d (%d x %d)'):format(expected, times, price), 4000,
        function() return ('; it changed by %d'):format(gained) end)
end)

-- Ped position as the server sees it: GetEntityCoords(GetPlayerPed(src)) is what
-- kora_lib's Kora.distance.player reads.
local function serverPosition(ctx)
    return GetEntityCoords(GetPlayerPed(ctx.tester))
end

K.step('the server should see me {int} metres above the diving coral seller', 'server', function(ctx, metres)
    local at
    ctx:waitUntil(function()
        at = serverPosition(ctx)
        local flat = math.sqrt((at.x - SELLER.x) ^ 2 + (at.y - SELLER.y) ^ 2)
        return flat < 1.0 and math.abs(at.z - (SELLER.z + metres)) < 0.75
    end, 'The server does not see the tester above the seller', 5000, function()
        return (': server sees %.2f %.2f %.2f'):format(at and at.x or 0, at and at.y or 0, at and at.z or 0)
    end)
end)

K.step('I note the first unpicked diving coral', 'server', function(ctx)
    ctx.state.divingCoral = firstUnpickedCoral()
end)

K.step('the diving coral I noted should still be unpicked', 'server', function(ctx)
    local index = assert(ctx.state.divingCoral, 'Note the first unpicked coral first')
    ctx:equal(GlobalState.Corals[index].PickedUp, false, 'Coral ' .. index .. ' PickedUp')
end)

K.step('the diving coral I noted should be marked picked', 'server', function(ctx)
    local index = assert(ctx.state.divingCoral, 'Note the first unpicked coral first')
    ctx:waitUntil(function() return GlobalState.Corals[index].PickedUp == true end,
        'Coral ' .. index .. ' is not marked picked', 3000)
end)

K.step('the server should see me beside the diving coral I noted', 'server', function(ctx)
    local index = assert(ctx.state.divingCoral, 'Note the first unpicked coral first')
    local coords, distance = GlobalState.Corals[index].coords, math.huge
    ctx:waitUntil(function()
        distance = #(serverPosition(ctx) - vector3(coords.x, coords.y, coords.z))
        return distance < 8.0
    end, 'The server does not see the tester beside the coral', 5000,
        function() return (': %.1f m from coral %d'):format(distance, index) end)
end)

local function coralCounts(ctx)
    return { dendrogyra_coral = K.count(ctx, 'dendrogyra_coral'), antipatharia_coral = K.count(ctx, 'antipatharia_coral') }
end

-- server/server.lua PickCoral adds math.random(min, max) of ONE random coral type.
K.step('I should have picked one diving coral reward', 'server', function(ctx)
    local counts
    ctx:waitUntil(function()
        counts = coralCounts(ctx)
        return counts.dendrogyra_coral + counts.antipatharia_coral > 0
    end, 'The pick paid no coral', 3000)
    local kinds = 0
    for item, amount in pairs(counts) do
        if amount > 0 then
            kinds = kinds + 1
            local range = CORAL_REWARD[item]
            assert(amount >= range[1] and amount <= range[2],
                ('Picked %d %s, expected %d to %d'):format(amount, item, range[1], range[2]))
        end
    end
    ctx:equal(kinds, 1, 'Coral types paid by one pick')
    ctx.state.divingReward = counts
end)

K.step('I should still hold only the first diving coral reward', 'server', function(ctx)
    local reward = assert(ctx.state.divingReward, 'Check the first reward first')
    local counts = coralCounts(ctx)
    for item, amount in pairs(reward) do ctx:equal(counts[item], amount, item .. ' after the second pick') end
end)

-- Client ------------------------------------------------------------------

K.step('I stand beside the diving coral seller', 'client', function(ctx)
    -- In front of the ped along its heading, well inside the 10 m sell radius.
    local angle = math.rad(SELLER.heading)
    K.teleport(ctx, SELLER.x - math.sin(angle) * 1.5, SELLER.y + math.cos(angle) * 1.5, SELLER.z + 0.3)
end)

K.step('I hover {int} metres above the diving coral seller', 'client', function(ctx, metres)
    assert(metres >= 1 and metres <= 50, 'Hover height must be 1-50 metres')
    local x, y, z = SELLER.x, SELLER.y, SELLER.z + metres
    K.teleport(ctx, x, y, z)
    ctx:cleanup(function() FreezeEntityPosition(PlayerPedId(), false) end)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    FreezeEntityPosition(ped, true)
end)

-- client/client.lua createSeller: TriggerServerEvent('qb-diving:server:sellCoral').
K.step('I offer my coral to the diving seller', 'client', function()
    TriggerServerEvent('qb-diving:server:sellCoral')
end)
K.step('I offer my coral to the diving seller twice at once', 'client', function()
    TriggerServerEvent('qb-diving:server:sellCoral')
    TriggerServerEvent('qb-diving:server:sellCoral')
end)

-- client/client.lua returnTarget: TriggerServerEvent('qb-diving:server:PickCoral', index).
K.step('I ask to pick diving coral without an index', 'client', function()
    TriggerServerEvent('qb-diving:server:PickCoral')
end)
K.step('I ask to pick diving coral number {int}', 'client', function(_, index)
    TriggerServerEvent('qb-diving:server:PickCoral', index)
end)
K.step('I ask to pick diving coral by the text index {string}', 'client', function(_, index)
    TriggerServerEvent('qb-diving:server:PickCoral', index)
end)
K.step('I ask to pick diving coral by the fractional index {float}', 'client', function(_, index)
    assert(index % 1 ~= 0, 'Use a fractional index')
    TriggerServerEvent('qb-diving:server:PickCoral', index + 0.0)
end)
K.step('I ask to pick the first unpicked diving coral from where I stand', 'client', function()
    TriggerServerEvent('qb-diving:server:PickCoral', (firstUnpickedCoral()))
end)

-- Two metres above the coral prop, inside the server's 10 m pick radius. The
-- K.teleport cleanup brings the diver back to the surface.
K.step('I swim to the first unpicked diving coral', 'client', function(ctx)
    local index, coral = firstUnpickedCoral()
    ctx.state.divingCoral = index
    K.teleport(ctx, coral.coords.x, coral.coords.y, coral.coords.z + 2.0)
end)
K.step('I pick the diving coral I swam to', 'client', function(ctx)
    local index = assert(ctx.state.divingCoral, 'Swim to a coral first')
    TriggerServerEvent('qb-diving:server:PickCoral', index)
end)

-- server/server.lua Kora.callback.register('qb-diving:server:fillOxygen'). The
-- packed form keeps a false answer distinct from a failed call.
K.step('I ask the diving server to take an oxygen tube for my gear', 'client', function(ctx)
    local ok, packed = pcall(function() return exports.kora_lib:callback_triggerPacked('qb-diving:server:fillOxygen') end)
    assert(ok, 'fillOxygen callback failed: ' .. tostring(packed))
    assert(type(packed) == 'table', 'fillOxygen callback returned no answer')
    -- A raised handler error or rate-limit rejection arrives as this envelope
    -- (kora_lib local/callback/shared.lua KoraLibCallbackEnvelope).
    assert(not packed.__kora_lib_rejected, 'fillOxygen callback failed: ' .. tostring(packed.error))
    ctx.state.divingFill = packed[1]
end)
K.step('the diving server should have accepted the oxygen tube', 'client', function(ctx)
    ctx:equal(ctx.state.divingFill, true, 'fillOxygen answer')
end)
K.step('the diving server should have refused the oxygen tube', 'client', function(ctx)
    ctx:equal(ctx.state.divingFill, false, 'fillOxygen answer')
end)
