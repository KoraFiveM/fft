-- kora_pawnshop: pawn counter (kora_target box zone, AppShell app qb-pawnshop:app).
-- No resource hook: the counter is a kora_target option and the app is driven
-- through kora_lib's hook.
--
-- HAZARD. server/server.lua permanently bans (exploitBan) when:
--   * sellPawnItems / meltItemRemove / pickupMelted arrive from a player who is
--     not within Config.PawnLocation[1].distance (3.0 m) of the counter;
--   * sellPawnItems names an item outside Config.PawnItems, or an amount that
--     is not a positive integer;
--   * meltItemRemove names an item outside Config.MeltingItems.
-- Nothing in this suite sends those events except the three guarded steps
-- below, and the feature must never use the generic "I trigger the app action"
-- steps on this app. (The generic "should be unavailable" step is used only
-- for sell and melt with an empty inventory: were the action declared after
-- all, onAction would get no item id and answer with a notice without sending
-- anything. It is never used for qb-pawnshop:pickup.) Each guarded step refuses to send unless the item is on
-- the copied allow-list, the amount is a small positive integer, the app is
-- open and the ped is frozen within 2.0 m of the counter; the feature also
-- asserts the server's own view of the ped position immediately before.
local K = FFT.kora
if not K then return end
K.feature('kora_pawnshop')

-- Config.PawnLocation[1].coords in kora_pawnshop/shared/config.lua.
local COUNTER = { x = 412.34, y = 314.81, z = 103.13 }
-- The server bans beyond 3.0 m; the suite refuses to act beyond 2.0 m.
local SAFE_REACH = 2.0
local MAX_AMOUNT = 20

-- Config.PawnItems / Config.MeltingItems in kora_pawnshop/shared/config.lua.
-- A stale entry here only makes a step refuse to act; it can never widen what
-- is sent, because the suite sends nothing that is absent from these lists.
local SELLABLE = { goldchain = true, diamond_ring = true, rolex = true, tenkgoldchain = true,
    tablet = true, iphone = true, samsungphone = true, laptop = true }
local MELTABLE = { goldchain = true, diamond_ring = true, rolex = true, tenkgoldchain = true }

local APP = 'qb-pawnshop:app'

local function reach(coords)
    local dx, dy, dz = coords.x - COUNTER.x, coords.y - COUNTER.y, coords.z - COUNTER.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Server's own measurement, the same one Kora.distance.player uses for the ban.
K.step('the server should place me within safe reach of the pawnshop counter', 'server', function(ctx)
    K.started('kora_pawnshop')
    local last
    ctx:waitUntil(function()
        local ped = GetPlayerPed(ctx.tester)
        if not ped or ped == 0 then return false end
        last = reach(GetEntityCoords(ped))
        return last <= SAFE_REACH
    end, ('Server sees the tester %s m from the pawnshop counter; nothing was sent'):format(tostring(last)), 5000)
end)

-- Prices are math.random(50, 100) per item, rolled at resource start.
K.step('the pawnshop payout for {int} items should be within the configured price range', 'server', function(ctx, amount)
    local before = assert(ctx.state.moneyBaseline and ctx.state.moneyBaseline.cash, 'Remember the cash balance first')
    local paid
    ctx:waitUntil(function()
        paid = K.money(ctx, 'cash') - before
        return paid > 0
    end, 'The pawnshop paid nothing', 3000)
    assert(paid >= 50 * amount and paid <= 100 * amount,
        ('Pawnshop paid %d for %d items, expected %d-%d'):format(paid, amount, 50 * amount, 100 * amount))
end)

-- Runs `send` only when every ban condition is provably avoided, with the ped
-- frozen so it cannot leave the counter between the check and the event.
local function guarded(ctx, amount, send)
    assert(math.type(amount) == 'integer' and amount >= 1 and amount <= MAX_AMOUNT,
        'Pawnshop amount must be an integer from 1 to ' .. MAX_AMOUNT)
    local app = K.uiState().app
    assert(app and app.id == APP, 'The pawnshop app is not open; nothing was sent')
    local ped = PlayerPedId()
    assert(not IsPedInAnyVehicle(ped, false), 'Leave the vehicle; nothing was sent')
    FreezeEntityPosition(ped, true)
    ctx:cleanup(function() FreezeEntityPosition(PlayerPedId(), false) end)
    Wait(250)
    local distance = reach(GetEntityCoords(ped))
    if distance > SAFE_REACH then
        FreezeEntityPosition(ped, false)
        error(('Tester is %.2f m from the pawnshop counter; nothing was sent'):format(distance), 0)
    end
    local ok, err = pcall(send)
    -- Stay frozen until the server has answered, so the event is always
    -- processed while the ped is at the counter.
    Wait(1500)
    FreezeEntityPosition(ped, false)
    if not ok then error(err, 0) end
end

local function action(actionId, context)
    local ok, err, code = K.ui('app.action', actionId, context)
    if not ok then error(('Pawnshop action %s was not accepted (%s): %s'):format(actionId, tostring(code), tostring(err)), 0) end
end

K.step('I pawn {int} {string} at the pawnshop counter', 'client', function(ctx, amount, item)
    assert(SELLABLE[item], item .. ' is not on the pawnshop sell list; nothing was sent')
    guarded(ctx, amount, function()
        action('qb-pawnshop:sell', { itemId = 'sell:' .. item, value = { amount = amount } })
    end)
end)

K.step('I melt {int} {string} at the pawnshop counter', 'client', function(ctx, amount, item)
    assert(MELTABLE[item], item .. ' is not on the pawnshop melting list; nothing was sent')
    guarded(ctx, amount, function()
        action('qb-pawnshop:melt', { itemId = 'melt:' .. item, value = { amount = amount } })
    end)
end)

K.step('I collect my melted items at the pawnshop counter', 'client', function(ctx)
    guarded(ctx, 1, function() action('qb-pawnshop:pickup') end)
end)

-- The app answers a non-positive amount itself and sends nothing to the
-- server (onAction in client/client.lua), so this needs no position guard;
-- it is still limited to listed items and to amounts that can never be sent.
K.step('I ask the pawnshop to buy {int} {string}', 'client', function(ctx, amount, item)
    assert(SELLABLE[item], item .. ' is not on the pawnshop sell list')
    assert(math.type(amount) == 'integer' and amount <= 0, 'This step only sends amounts the app itself refuses')
    local ok, result = K.must(K.ui('app.action', 'qb-pawnshop:sell', { itemId = 'sell:' .. item, value = { amount = amount } }))
    ctx.state.appResult = ok and type(result) == 'table' and result or {}
end)

-- Opening hours read the client's in-game clock (GetClockHours). The fixture
-- suspends kora_weathersync on this client only, which otherwise re-applies
-- the server clock every second, and resumes it during cleanup. No other
-- player's time or weather changes.
K.step('the pawnshop clock reads {int} hundred hours', 'client', function(ctx, hour)
    assert(math.type(hour) == 'integer' and hour >= 0 and hour <= 23, 'Hour must be 0-23')
    local synced = GetResourceState('kora_weathersync') == 'started'
    ctx:cleanup(function()
        NetworkClearClockTimeOverride()
        if synced then TriggerEvent('qb-weathersync:client:EnableSync') end
    end)
    if synced then TriggerEvent('qb-weathersync:client:DisableSync') end
    NetworkOverrideClockTime(hour, 0, 0)
    ctx:waitUntil(function() return GetClockHours() == hour end, 'In-game clock did not change to ' .. hour, 3000)
end)

-- ---------------------------------------------------------------------------
-- Round 3. The same ban rules apply: every step below that can reach the
-- server goes through `guarded` and the allow-lists above.
-- ---------------------------------------------------------------------------

-- A second melt while one is in progress: server/server.lua returns early
-- (lastBatch.readyAt) and the client disables the melt view. If kora_lib no
-- longer declares the melt action the request never leaves the client; either
-- way the authoritative item count is asserted afterwards.
K.step('I try to melt {int} {string} again at the pawnshop counter', 'client', function(ctx, amount, item)
    assert(MELTABLE[item], item .. ' is not on the pawnshop melting list; nothing was sent')
    guarded(ctx, amount, function()
        local ok, err, code = K.ui('app.action', 'qb-pawnshop:melt', { itemId = 'melt:' .. item, value = { amount = amount } })
        ctx.state.pawnshopRetry = { ok = ok, err = err, code = code }
    end)
end)

-- onAction (client/client.lua) answers these itself and sends nothing: no
-- item id, or an id without the "<kind>:" prefix, or a non-positive amount.
K.step('I ask the pawnshop to melt {int} {string}', 'client', function(ctx, amount, item)
    assert(MELTABLE[item], item .. ' is not on the pawnshop melting list')
    assert(math.type(amount) == 'integer' and amount <= 0, 'This step only sends amounts the app itself refuses')
    local _, result = K.must(K.ui('app.action', 'qb-pawnshop:melt', { itemId = 'melt:' .. item, value = { amount = amount } }))
    ctx.state.appResult = type(result) == 'table' and result or {}
end)
K.step('I ask the pawnshop to buy without choosing an item', 'client', function(ctx)
    local _, result = K.must(K.ui('app.action', 'qb-pawnshop:sell', { value = { amount = 1 } }))
    ctx.state.appResult = type(result) == 'table' and result or {}
end)
K.step('I ask the pawnshop to buy {string} without the item prefix', 'client', function(ctx, item)
    assert(SELLABLE[item], item .. ' is not on the pawnshop sell list')
    local _, result = K.must(K.ui('app.action', 'qb-pawnshop:sell', { itemId = item, value = { amount = 1 } }))
    ctx.state.appResult = type(result) == 'table' and result or {}
end)
K.step('I ask the pawnshop to buy {string} without an amount', 'client', function(ctx, item)
    assert(SELLABLE[item], item .. ' is not on the pawnshop sell list')
    local _, result = K.must(K.ui('app.action', 'qb-pawnshop:sell', { itemId = 'sell:' .. item }))
    ctx.state.appResult = type(result) == 'table' and result or {}
end)

-- Every sale pays amount * entry.price, with entry.price rolled once per
-- resource start (shared/config.lua), credited as
-- addMoney(src, 'cash', totalPrice, 'qb-pawnshop:server:sellPawnItems').
local SALE_REASON = 'qb-pawnshop:server:sellPawnItems'
local function salePayouts(ctx)
    local paid = {}
    for _, record in ipairs(K.captured(ctx, 'QBCore:Server:OnMoneyChange')) do
        local account, amount, reason = record[2], record[3], record[5]
        if account == 'cash' and type(amount) == 'number' and amount > 0 and (reason == nil or reason == SALE_REASON) then
            paid[#paid + 1] = amount
        end
    end
    return paid
end
K.step('the pawnshop sales of {int} and then {int} items should pay one price per item', 'server', function(ctx, first, second)
    assert(first > 0 and second > 0, 'Item counts must be positive')
    local paid
    ctx:waitUntil(function() paid = salePayouts(ctx) return #paid >= 2 end,
        'Expected two pawnshop payouts (remember the cash balance before selling)', 3000)
    ctx:equal(#paid, 2, 'Pawnshop payouts')
    local unitA, unitB = paid[1] / first, paid[2] / second
    assert(unitA == unitB, ('Paid %d for %d and %d for %d: the price per item changed'):format(paid[1], first, paid[2], second))
    assert(unitA >= 50 and unitA <= 100, ('Price per item %s is outside 50-100'):format(tostring(unitA)))
end)

-- error.closed in locales/en.json with Config.TimeOpen = 7 and Config.TimeClosed = 17.
K.step('the pawnshop should say it is closed until {int} hundred hours', 'client', function(ctx, hour)
    K.waitNotification(ctx, ('Come back between %02d:00 and'):format(hour))
end)
