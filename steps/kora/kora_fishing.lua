-- kora_fishing: fishing shop, fish buyer and salvage breakdown (kora_lib apps
-- opened from kora_target options) plus the pole's zone rule.
-- No resource hook: every surface is a kora_target option, a kora_lib app or a
-- usable item, and the results are items and cash the server owns.
--
-- Deliberately not driven: casting and catching. A catch is decided by a
-- kora_lib minigame proof (never forced) and awards Fishing XP through
-- kora_skills, which has no delete API.
local K = FFT.kora
if not K then return end
K.feature('kora_fishing')

-- kora_fishing/shared/config.lua. The resource's Config is not visible from
-- here, so the positions and the material list are copied.
local SHOP = { x = -1600.84, y = 5204.13, z = 3.31, heading = 20.0, model = 'a_m_m_farmer_01' }       -- Config.Shop.locations[1]; client/shops.lua sets heading 20.0
local BUYER = { x = -1847.20, y = -1190.31, z = 13.32, heading = 155.0, model = 'a_m_m_farmer_01' }   -- Config.Locations.buyer.locations[1]
local BENCH = { x = 1110.13, y = -2007.89, z = 31.05 }                                                -- Config.Locations.breakdown.locations[1], 2x2x2 box zone
local MATERIALS = { 'rubber', 'metalscrap', 'plastic', 'iron', 'copper', 'glass', 'steel' }           -- Config.Locations.breakdown.receiveItems
local POLES = { fishing_pole = true, magnet_pole = true }                                             -- Config.poles

-- ---------------------------------------------------------------------------
-- Server
-- ---------------------------------------------------------------------------

-- Fishing XP cannot be removed, so this only reads the level (the same call
-- server/shops.lua makes) and fails clearly when the character does not fit.
K.step('my fishing level should be below {int}', 'server', function(ctx, level)
    local skill = K.export('kora_skills', 'getRep', ctx.tester, 'fishing')
    local actual = type(skill) == 'table' and tonumber(skill.level) or 1
    assert(actual < level, ('Tester Fishing level is %d; this scenario needs a level below %d'):format(actual, level))
end)

-- Registers the cleanup before the purchase so bought stock never outlives the scenario.
K.step('any {string} bought from the fishing shop is handed back afterwards', 'server', function(ctx, item)
    local core, tester = exports.kora_core, ctx.tester
    local before = K.count(ctx, item)
    ctx:cleanup(function()
        local extra = (core:getItemCount(tester, item) or 0) - before
        if extra > 0 then core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
    end)
end)

local function materials(ctx)
    local counts, total = {}, 0
    for _, item in ipairs(MATERIALS) do
        counts[item] = K.count(ctx, item)
        total = total + counts[item]
    end
    return counts, total
end

-- Refining pays random materials, so the baseline covers the whole receive list
-- and the cleanup removes whatever was gained.
K.step('I note my crafting materials before refining fishing salvage', 'server', function(ctx)
    local core, tester = exports.kora_core, ctx.tester
    local before, total = materials(ctx)
    ctx.state.fishingMaterials = total
    ctx:cleanup(function()
        for _, item in ipairs(MATERIALS) do
            local extra = (core:getItemCount(tester, item) or 0) - before[item]
            if extra > 0 then core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
        end
    end)
end)
K.step('refining fishing salvage should have paid between {int} and {int} crafting materials', 'server', function(ctx, low, high)
    local before = assert(ctx.state.fishingMaterials, 'Note the crafting materials first')
    local gained = 0
    ctx:waitUntil(function()
        local _, total = materials(ctx)
        gained = total - before
        return gained >= low and gained <= high
    end, ('Refining paid %d crafting materials, expected %d to %d'):format(gained, low, high), 4000)
end)
K.step('refining fishing salvage should have paid nothing', 'server', function(ctx)
    local before = assert(ctx.state.fishingMaterials, 'Note the crafting materials first')
    Wait(1000)
    local _, total = materials(ctx)
    ctx:equal(total - before, 0, 'Crafting materials gained')
end)

-- Uses the pole the way the inventory does: kora_core runs the usable the
-- resource registered in server/server.lua.
-- server/server.lua startCooldown: a cast blocks the next one for 2 s ("You
-- must wait before fishing again.") even after the line is reeled in, and the
-- previous scenario's cast is often less than 2 s old. Kept across scenarios.
local lastPoleUse = nil
local function awaitPoleCooldown()
    local elapsed = lastPoleUse and GetGameTimer() - lastPoleUse
    if elapsed and elapsed < 2300 then Wait(2300 - elapsed) end
end
local function notePoleUse() lastPoleUse = GetGameTimer() end

K.step('I use my fishing pole {string}', 'server', function(ctx, item)
    assert(POLES[item], 'Not a fishing pole: ' .. tostring(item))
    assert(K.count(ctx, item) > 0, 'The tester holds no ' .. item)
    awaitPoleCooldown()
    K.export('kora_core', 'useItem', ctx.tester, item)
    notePoleUse()
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
local function face(ctx, label, x, y, z, opts) return K.face(ctx, label, x, y, z, opts) end

local function facePed(ctx, label, place)
    face(ctx, label, place.x, place.y, place.z, {
        heading = place.heading, lift = 0.5, aimLift = 0.2,
        find = function() return nearest('CPed', place.model, place.x, place.y, place.z, 3.0) end,
    })
end

K.step('I face the fishing shop keeper', 'client', function(ctx) facePed(ctx, 'Open Fishing Shop', SHOP) end)
K.step('I face the fish buyer', 'client', function(ctx) facePed(ctx, 'Open Buyer Menu', BUYER) end)
K.step('I face the fishing breakdown bench', 'client', function(ctx)
    -- Zone options match the camera ray's hit point, so aim a little below the box centre.
    face(ctx, 'Open Refine Menu', BENCH.x, BENCH.y, BENCH.z, { distance = 1.3, aimLift = -0.3 })
end)

-- The refine action runs a 5 second progress bar inside the app's handler
-- (client/breakdown.lua), which is as long as kora_lib's hook waits for an NUI
-- answer. Either outcome means the handler was started; the scenario then
-- asserts the server result.
K.step('I refine the fishing salvage entry {string}', 'client', function(_, itemId)
    assert(itemId:match('^refine:%d+$'), 'Salvage entries are refine:<index>')
    local ok, err = K.ui('app.action', 'kora_fishing:refine', { itemId = itemId })
    if not ok and not K.contains(err, 'did not answer') then error(tostring(err), 0) end
end)

-- ===========================================================================
-- Round 3: request-level shop, buyer and bench rules, the gate callbacks, pole
-- use inside a zone and the catch callbacks. The request-level steps send the
-- same net events and callbacks the resource's own apps send
-- (client/shops.lua, client/sales.lua, client/breakdown.lua), so the server's
-- checks decide every outcome.
-- ===========================================================================

-- Config.poles bait names (every pole), shared/config.lua.
local BAITS = {
    'worm', 'plug_bait', 'soft_plastic_bait', 'spinner_bait',
    'magnet_2lb', 'magnet_5lb', 'magnet_10lb', 'magnet_20lb',
}
-- Everything a catch can pay: Config.poles[*].baits[*].catch.
local CATCHES = {
    'flounder', 'reddrum', 'tuna', 'steelhead', 'blue_fish', 'halibut', 'catfish', 'white_bass', 'salmon',
    'bass', 'trout', 'rusty_usb', 'rusty_motherboard', 'rusty_scanner', 'rusty_antenna', 'copper_pipe',
    'rusty_scrap_metal', 'rusty_pistol', 'rusty_sign', 'rusty_chain', 'rusty_tire', 'rusty_box',
    'rusty_shotgun', 'rusty_ak', 'rusty_bike', 'rusty_wheelchair', 'closed_safe',
}
-- Config.zones[1] "Sandy Bay Dock": a point at least 3 m inside the polygon
-- (checked offline with server/server.lua isPointInPoly), points z 31.88-32.08,
-- thickness 5.5.
local SANDY_DOCK = { x = 1302.78, y = 4232.96, z = 32.9 }

-- Server ------------------------------------------------------------------

K.step('I carry no bait for any fishing pole', 'server', function(ctx)
    for _, bait in ipairs(BAITS) do
        assert(K.count(ctx, bait) == 0, 'Tester carries ' .. bait .. '; a cast could reach the catch minigame')
    end
end)

-- kora_core runs the usable the same way the inventory does, in one frame.
local function usePoleTimes(ctx, item, times)
    assert(POLES[item], 'Not a fishing pole: ' .. tostring(item))
    assert(K.count(ctx, item) > 0, 'The tester holds no ' .. item)
    awaitPoleCooldown()
    for _ = 1, times do K.export('kora_core', 'useItem', ctx.tester, item) end
    notePoleUse()
end
K.step('I use my fishing pole {string} twice at once', 'server', function(ctx, item) usePoleTimes(ctx, item, 2) end)
K.step('I use my fishing pole {string} three times at once', 'server', function(ctx, item) usePoleTimes(ctx, item, 3) end)

local function fishingProgress(ctx)
    local skill = K.export('kora_skills', 'getRep', ctx.tester, 'fishing')
    local counts = {}
    for _, item in ipairs(CATCHES) do counts[item] = K.count(ctx, item) end
    return type(skill) == 'table' and tonumber(skill.xp) or nil, counts
end
K.step('I note my fishing catch and Fishing XP', 'server', function(ctx)
    local xp, counts = fishingProgress(ctx)
    ctx.state.fishingProgress = { xp = xp, counts = counts }
end)
K.step('my fishing catch and Fishing XP should be unchanged', 'server', function(ctx)
    local before = assert(ctx.state.fishingProgress, 'Note the catch and Fishing XP first')
    local xp, counts = fishingProgress(ctx)
    ctx:equal(xp, before.xp, 'Fishing XP')
    for item, amount in pairs(before.counts) do ctx:equal(counts[item], amount, item .. ' count') end
end)

-- Client: standing beside things without targeting them -------------------

local function standBeside(ctx, place, distance, lift)
    local angle = math.rad(place.heading or 0.0)
    K.teleport(ctx, place.x - math.sin(angle) * distance, place.y + math.cos(angle) * distance, place.z + lift)
end
K.step('I stand beside the fishing shop keeper', 'client', function(ctx) standBeside(ctx, SHOP, 1.5, 0.5) end)
K.step('I stand beside the fish buyer', 'client', function(ctx) standBeside(ctx, BUYER, 1.5, 0.5) end)
K.step('I stand beside the fishing breakdown bench', 'client', function(ctx) standBeside(ctx, BENCH, 1.3, 0.0) end)

-- Ends any cast the scenario started, on both sides (server/server.lua
-- kora_fishing:server:stopFishing tells the client to stop too).
K.step('I stand on the Sandy Bay fishing dock', 'client', function(ctx)
    ctx:cleanup(function()
        TriggerServerEvent('kora_fishing:server:stopFishing')
        -- kora_lib cancels only the owner's minigame (modules/minigames/client.lua).
        pcall(function() exports.kora_lib:minigames_cancel('kora_fishing') end)
    end)
    K.teleport(ctx, SANDY_DOCK.x, SANDY_DOCK.y, SANDY_DOCK.z)
end)

-- Client: shop requests (server/shops.lua purchaseItem(shopKey, itemKey, amount)) --

local PURCHASE = 'kora_fishing:server:purchaseItem'
K.step('I ask the fishing shop to sell me {int} of shop item {int}', 'client', function(_, amount, item)
    TriggerServerEvent(PURCHASE, 1, item, amount)
end)
K.step('I ask fishing shop number {int} to sell me {int} of shop item {int}', 'client', function(_, shop, amount, item)
    TriggerServerEvent(PURCHASE, shop, item, amount)
end)
K.step('I ask the fishing shop to sell me a fractional {float} of shop item {int}', 'client', function(_, amount, item)
    assert(amount % 1 ~= 0, 'Use a fractional amount')
    TriggerServerEvent(PURCHASE, 1, item, amount + 0.0)
end)
K.step('I ask the fishing shop to sell me the text amount {string} of shop item {int}', 'client', function(_, amount, item)
    TriggerServerEvent(PURCHASE, 1, item, amount)
end)
K.step('I ask the fishing shop for shop item {int} without naming the shop', 'client', function(_, item)
    TriggerServerEvent(PURCHASE, nil, item, 1)
end)
K.step('I ask the fishing shop for nothing in particular', 'client', function()
    TriggerServerEvent(PURCHASE, 1, nil, 1)
end)

-- Client: buyer requests (server/sales.lua sellItem(key, item, number)) ----

local SELL = 'kora_fishing:server:sellItem'
K.step('I ask the fish buyer to buy {int} of buyer item {int}', 'client', function(_, amount, item)
    TriggerServerEvent(SELL, 1, item, amount)
end)
K.step('I ask the fish buyer twice at once to buy {int} of buyer item {int}', 'client', function(_, amount, item)
    TriggerServerEvent(SELL, 1, item, amount)
    TriggerServerEvent(SELL, 1, item, amount)
end)
K.step('I ask fish buyer location {int} to buy {int} of buyer item {int}', 'client', function(_, key, amount, item)
    TriggerServerEvent(SELL, key, item, amount)
end)
K.step('I ask the fish buyer to buy a fractional {float} of buyer item {int}', 'client', function(_, amount, item)
    assert(amount % 1 ~= 0, 'Use a fractional amount')
    TriggerServerEvent(SELL, 1, item, amount + 0.0)
end)
K.step('I ask the fish buyer to buy the text amount {string} of buyer item {int}', 'client', function(_, amount, item)
    TriggerServerEvent(SELL, 1, item, amount)
end)
K.step('I ask the fish buyer to buy buyer item {int} without an amount', 'client', function(_, item)
    TriggerServerEvent(SELL, 1, item)
end)

-- Client: bench requests (server/breakdown.lua refineItem(key, item)) ------

local REFINE = 'kora_fishing:server:refineItem'
K.step('I ask the fishing bench to refine salvage entry {int}', 'client', function(_, item)
    TriggerServerEvent(REFINE, 1, item)
end)
K.step('I ask fishing breakdown location {int} to refine salvage entry {int}', 'client', function(_, key, item)
    TriggerServerEvent(REFINE, key, item)
end)
K.step('I ask the fishing bench to refine without naming the salvage', 'client', function()
    TriggerServerEvent(REFINE, 1)
end)

-- Client: callbacks. callback_triggerPacked returns one { n, ... } envelope
-- (kora_lib/local/callback/client.lua); a handler assert or a rate-limit
-- rejection raises, and the message survives the export boundary.
-- A raised handler error arrives as { __kora_lib_rejected = true, error }
-- (kora_lib local/callback/shared.lua KoraLibCallbackEnvelope).
local function askFishing(ctx, name, ...)
    local args = table.pack(...)
    local ok, packed = pcall(function() return exports.kora_lib:callback_triggerPacked(name, table.unpack(args, 1, args.n)) end)
    if ok and type(packed) == 'table' and packed.__kora_lib_rejected then ok, packed = false, packed.error end
    ctx.state.fishingAnswer = ok and { ok = true, packed = packed } or { ok = false, err = tostring(packed) }
    return ctx.state.fishingAnswer
end
K.step('I ask whether fishing shop number {int} will open for me', 'client', function(ctx, key)
    askFishing(ctx, 'kora_fishing:client:confirmOpenShop', key)
end)
K.step('I ask whether fish buyer location {int} will open for me', 'client', function(ctx, key)
    askFishing(ctx, 'kora_fishing:server:canOpenBuyerMenu', key)
end)
K.step('I ask whether fishing breakdown location {int} will open for me', 'client', function(ctx, key)
    askFishing(ctx, 'kora_fishing:server:openRefineMenu', key)
end)
K.step('I ask the fishing server to begin a catch', 'client', function(ctx)
    askFishing(ctx, 'kora_fishing:server:beginCatch')
end)

local function answer(ctx)
    return assert(ctx.state.fishingAnswer, 'Ask the fishing server first')
end
K.step('the fishing server should have answered yes', 'client', function(ctx)
    local result = answer(ctx)
    assert(result.ok, 'The callback was refused: ' .. tostring(result.err))
    ctx:equal(type(result.packed) == 'table' and result.packed[1], true, 'Callback answer')
end)
K.step('the fishing server should have refused with {string}', 'client', function(ctx, text)
    local result = answer(ctx)
    assert(not result.ok, 'The callback answered instead of refusing')
    assert(K.contains(result.err, text), ('Refusal is "%s", expected it to mention "%s"'):format(result.err, text))
end)
K.step('the fishing server should have answered no with {string}', 'client', function(ctx, text)
    local result = answer(ctx)
    assert(result.ok, 'The callback was refused: ' .. tostring(result.err))
    local packed = result.packed or {}
    ctx:equal(packed[1], false, 'Callback answer')
    assert(K.contains(packed[2], text), ('Reason is "%s", expected "%s"'):format(tostring(packed[2]), text))
end)

-- server/server.lua beginCatch answers false, 'You are not currently fishing.'
-- once isFishing[src] is cleared. Polled no faster than its 2-per-second limit;
-- the scenarios using this hold no bait, so the call can never authorize a catch.
K.step('the fishing server should no longer have me fishing', 'client', function(ctx)
    local last = 'no answer'
    ctx:waitUntil(function()
        local result = askFishing(ctx, 'kora_fishing:server:beginCatch')
        local packed = result.ok and result.packed or {}
        last = result.ok and tostring(packed[2]) or result.err
        if result.ok and type(packed[1]) == 'table' then
            error('beginCatch authorized a catch; this scenario must hold no bait', 0)
        end
        if result.ok and packed[1] == false and K.contains(packed[2], 'You are not currently fishing.') then return true end
        Wait(600)
    end, 'The fishing server still has the tester fishing', 8000, function() return ': last answer ' .. last end)
end)

K.step('I ask the fishing server to begin a catch {int} times at once', 'client', function(ctx, times)
    assert(times >= 2 and times <= 5, 'Ask 2-5 times')
    local results, done = {}, 0
    for index = 1, times do
        CreateThread(function()
            local ok, packed = pcall(function() return exports.kora_lib:callback_triggerPacked('kora_fishing:server:beginCatch') end)
            if ok and type(packed) == 'table' and packed.__kora_lib_rejected then ok, packed = false, packed.error end
            results[index] = ok and { ok = true, packed = packed } or { ok = false, err = tostring(packed) }
            done = done + 1
        end)
    end
    ctx:waitUntil(function() return done == times end, 'Not every catch request was answered', 10000)
    for _, result in ipairs(results) do
        if result.ok and type(result.packed) == 'table' and type(result.packed[1]) == 'table' then
            error('beginCatch authorized a catch for a player who is not fishing', 0)
        end
    end
    ctx.state.fishingBurst = results
end)
K.step('at least one catch request should have been refused with {string}', 'client', function(ctx, text)
    local results = assert(ctx.state.fishingBurst, 'Send the catch requests first')
    for _, result in ipairs(results) do
        if not result.ok and K.contains(result.err, text) then return end
    end
    error('No catch request was refused with "' .. text .. '"', 0)
end)

-- server/server.lua catchFish(requestedZone, proof, authorization): without a
-- pending beginCatch authorization it returns before touching anything.
K.step('I send a forged fishing catch', 'client', function()
    TriggerServerEvent('kora_fishing:server:catchFish', 1, 'fft-forged-proof', 'fft-forged-authorization')
end)

-- client/breakdown.lua: the action handler awaits a cancellable 5 s progress
-- bar and only sends refineItem when it completes.
K.step('I start refining the fishing salvage entry {string} and cancel it midway', 'client', function(ctx, itemId)
    assert(itemId:match('^refine:%d+$'), 'Salvage entries are refine:<index>')
    local finished = false
    CreateThread(function()
        pcall(function() K.ui('app.action', 'kora_fishing:refine', { itemId = itemId }) end)
        finished = true
    end)
    ctx:waitUntil(function() return K.uiState().progress end, 'The refine progress bar did not start', 3000)
    -- kora_lib only cancels a bar for its owner (modules/progressbar/client.lua
    -- Kora.progressbar.cancel(owner)); this is the player's cancel request.
    assert(exports.kora_lib:progressbar_cancel('kora_fishing') == true, 'kora_lib refused to cancel the refine progress bar')
    ctx:waitUntil(function() return not K.uiState().progress end, 'The refine progress bar did not stop', 2000)
    ctx:waitUntil(function() return finished end, 'The refine action did not return after the cancel', 6000)
end)
