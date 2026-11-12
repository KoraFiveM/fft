-- kora_metaldetecting: catalog command, detector shop (kora_lib app opened from
-- a kora_target ped option), the detector's on/off rules and the wash station.
-- No resource hook: every surface is a command, a kora_target option, a
-- kora_lib app, text prompt or interact zone, or a usable item, and the results
-- are items and money the server owns.
--
-- Deliberately not driven: a find and a successful wash. Both are decided by a
-- kora_lib skillbar proof (never forced) and a find awards Metal Detecting XP
-- through kora_skills, which has no delete API.
local K = FFT.kora
if not K then return end
K.feature('kora_metaldetecting')

-- kora_metaldetecting/shared/config.lua. The resource's Config is not visible from here.
-- Config.Selling.shop[1]: the server creates the ped at coords.z + zOffset (1.0).
local SHOP = { x = -1111.29, y = -1689.21, z = 4.38, heading = 307.79, model = 'ig_priest' }
local WASH = { x = -1247.79, y = -1542.34, z = 4.3 } -- Config.Selling.wash[1], interact circle radius 1.5
local DETECTOR = 'metaldetector'                     -- Config.Items.detector
-- Config.Loot.sellValues keys: everything the shop's Sell tab can list.
local LOOT = {
    'clump', 'bobby_pin', 'bottle_cap', 'nails', 'toy_car', 'corno', 'car_keys_md', 'silver_ring_md',
    'gold_ring_md', 'gold_chain_md', 'gold_bracelet_md', 'diamond_earring_md', 'diamond_ring_md',
    'gold_diamond_ring_md', 'antique_coin', 'ruby_ring_md',
}

-- ---------------------------------------------------------------------------
-- Server
-- ---------------------------------------------------------------------------

-- Registers the cleanup before the purchase so a bought detector never outlives the scenario.
K.step('any {string} bought from the metal detector shop is handed back afterwards', 'server', function(ctx, item)
    local core, tester = exports.kora_core, ctx.tester
    local before = K.count(ctx, item)
    ctx:cleanup(function()
        local extra = (core:getItemCount(tester, item) or 0) - before
        if extra > 0 then core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
    end)
end)

-- The Sell tab only declares its action while the player owns sellable loot.
K.step('I should carry no metal detecting loot of my own', 'server', function(ctx)
    for _, item in ipairs(LOOT) do
        assert(K.count(ctx, item) == 0, 'Tester already carries ' .. item .. '; this scenario needs a character without detecting loot')
    end
end)

local function useDetector(ctx)
    assert(K.count(ctx, DETECTOR) > 0, 'The tester holds no ' .. DETECTOR)
    K.export('kora_core', 'useItem', ctx.tester, DETECTOR)
end

-- The usable toggles the server's active-detector flag (server/main.lua). The
-- flag is not readable from outside, so the scenario tracks it and the cleanup
-- switches the detector off again if the scenario stopped half way.
K.step('I switch my metal detector on', 'server', function(ctx)
    local core, tester = exports.kora_core, ctx.tester
    useDetector(ctx)
    ctx.state.detectorOn = true
    ctx:cleanup(function()
        if not ctx.state.detectorOn then return end
        ctx.state.detectorOn = false
        local borrowed = (core:getItemCount(tester, DETECTOR) or 0) == 0
        if borrowed then core:addItem(tester, DETECTOR, 1, nil, nil, 'functional test cleanup') end
        pcall(function() core:useItem(tester, DETECTOR) end)
        if borrowed then core:removeItem(tester, DETECTOR, 1, nil, 'functional test cleanup') end
    end)
end)
K.step('I switch my metal detector off', 'server', function(ctx)
    assert(ctx.state.detectorOn, 'Switch the metal detector on first')
    useDetector(ctx)
    ctx.state.detectorOn = false
end)
-- For starts the client refuses: it tells the server to drop the active flag
-- itself (client/main.lua beginDetecting), so no switch-off is registered.
K.step('I try to switch my metal detector on', 'server', function(ctx) useDetector(ctx) end)

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

K.step('I face the metal detector shop keeper', 'client', function(ctx)
    -- client/shop.lua setupShopPed: the option is attached once the networked
    -- ped's statebag has arrived and the player is inside the shop's 50 m sphere.
    face(ctx, 'Open Metal Detector Shop', SHOP.x, SHOP.y, SHOP.z, {
        heading = SHOP.heading, lift = 0.2, aimLift = 0.2,
        find = function() return nearest('CPed', SHOP.model, SHOP.x, SHOP.y, SHOP.z, 3.0) end,
    })
end)

K.step('I stand at the metal detecting wash station', 'client', function(ctx)
    K.teleport(ctx, WASH.x, WASH.y, WASH.z + 0.5)
end)

-- ===========================================================================
-- Round 3: request-level shop, wash and find rules. These send the same
-- kora_lib events and callbacks the resource's client sends
-- (client/shop.lua onAction, client/main.lua washClump / playFind), through
-- kora_lib's own exports, so the server's checks and rate limits decide every
-- outcome. Kora.events handlers that refuse return silently, so the scenarios
-- assert that nothing changed.
-- ===========================================================================

-- Config.Selling.wash, shared/config.lua.
local WASHES = {
    { x = -1247.79, y = -1542.34, z = 4.3 },
    { x = -1250.03, y = -1541.78, z = 4.3 },
    { x = -1252.35, y = -1541.27, z = 4.3 },
}
-- Config.Loot.items: everything a find or a wash can pay.
local FINDS = {
    'clump', 'metalscrap', 'copper', 'aluminum', 'iron', 'bobby_pin', 'bottle_cap', 'nails', 'toy_car', 'corno',
    'car_keys_md', 'steel', 'silver_ring_md', 'gold_ring_md', 'gold_chain_md', 'gold_bracelet_md',
    'diamond_earring_md', 'diamond_ring_md', 'gold_diamond_ring_md', 'antique_coin', 'ruby_ring_md',
}

-- Server ------------------------------------------------------------------

local function detectingProgress(ctx)
    local skill = K.export('kora_skills', 'getRep', ctx.tester, 'metaldetecting') -- Config.Skill.name
    local counts = {}
    for _, item in ipairs(FINDS) do counts[item] = K.count(ctx, item) end
    return type(skill) == 'table' and tonumber(skill.xp) or nil, counts
end
K.step('I note my metal detecting loot and XP', 'server', function(ctx)
    local xp, counts = detectingProgress(ctx)
    ctx.state.detectingProgress = { xp = xp, counts = counts }
end)
K.step('my metal detecting loot and XP should be unchanged', 'server', function(ctx)
    local before = assert(ctx.state.detectingProgress, 'Note the loot and XP first')
    local xp, counts = detectingProgress(ctx)
    ctx:equal(xp, before.xp, 'Metal Detecting XP')
    for item, amount in pairs(before.counts) do ctx:equal(counts[item], amount, item .. ' count') end
end)

-- The client stopped the detector itself and told the server
-- (client/main.lua stopDetecting(true)), so the switch-off registered by
-- `I switch my metal detector on` must not toggle it back on. Pair with the
-- client step `my metal detector is switched off afterwards`.
K.step('my metal detector has been switched off for me', 'server', function(ctx)
    assert(ctx.state.detectorOn, 'Switch the metal detector on first')
    ctx.state.detectorOn = false
end)

-- Client ------------------------------------------------------------------

local function trigger(name, ...)
    local ok, err = exports.kora_lib:events_trigger(name, ...)
    assert(ok, ('Could not send %s: %s'):format(name, tostring(err)))
end

-- kora_metaldetecting:server:stoppedDetecting only acts when the server has the
-- detector active, so this cleanup is safe whatever state the scenario left.
K.step('my metal detector is switched off afterwards', 'client', function(ctx)
    ctx:cleanup(function()
        pcall(function() exports.kora_lib:events_trigger('kora_metaldetecting:server:stoppedDetecting') end)
    end)
end)

K.step('I stand beside the metal detector shop keeper', 'client', function(ctx)
    local angle = math.rad(SHOP.heading)
    K.teleport(ctx, SHOP.x - math.sin(angle) * 1.5, SHOP.y + math.cos(angle) * 1.5, SHOP.z)
end)
K.step('I stand at metal detecting wash station {int}', 'client', function(ctx, index)
    local wash = assert(WASHES[index], 'Config.Selling.wash has no station ' .. index)
    K.teleport(ctx, wash.x, wash.y, wash.z + 0.5)
end)

-- soldLoot(shopIndex, item, amount)
local SOLD = 'kora_metaldetecting:server:soldLoot'
K.step('I offer {int} {string} to the metal detector shop', 'client', function(_, amount, item)
    trigger(SOLD, 1, item, amount)
end)
K.step('I offer {int} {string} to metal detector shop number {int}', 'client', function(_, amount, item, shop)
    trigger(SOLD, shop, item, amount)
end)
K.step('I offer {int} {string} to the metal detector shop twice at once', 'client', function(_, amount, item)
    trigger(SOLD, 1, item, amount)
    trigger(SOLD, 1, item, amount)
end)
K.step('I offer a fractional {float} {string} to the metal detector shop', 'client', function(_, amount, item)
    assert(amount % 1 ~= 0, 'Use a fractional amount')
    trigger(SOLD, 1, item, amount + 0.0)
end)
K.step('I offer the text amount {string} of {string} to the metal detector shop', 'client', function(_, amount, item)
    trigger(SOLD, 1, item, amount)
end)

-- purchasedDetector(shopIndex, account)
local PURCHASED = 'kora_metaldetecting:server:purchasedDetector'
K.step('I order a metal detector paying by {string}', 'client', function(_, account)
    trigger(PURCHASED, 1, account)
end)
K.step('I order a metal detector from shop number {int} paying by {string}', 'client', function(_, shop, account)
    trigger(PURCHASED, shop, account)
end)
K.step('I order a metal detector paying by {string} {int} times at once', 'client', function(_, account, times)
    assert(times >= 2 and times <= 4, 'Order 2-4 times')
    for _ = 1, times do trigger(PURCHASED, 1, account) end
end)

-- Callbacks. A granted beginWash or beginFind returns a skill-check
-- authorization; these scenarios only ask where the server must refuse, and a
-- granted answer fails the step without ever starting the skillbar.
local function askDetecting(ctx, name, ...)
    local args = table.pack(...)
    local ok, packed = pcall(function() return exports.kora_lib:callback_triggerPacked(name, table.unpack(args, 1, args.n)) end)
    assert(ok, name .. ' failed: ' .. tostring(packed))
    assert(type(packed) == 'table', name .. ' returned no answer')
    -- A raised handler error arrives as { __kora_lib_rejected = true, error }.
    assert(not packed.__kora_lib_rejected, name .. ' failed: ' .. tostring(packed.error))
    ctx.state.detectingAnswer = packed[1]
end
K.step('I ask to begin washing a clump at wash station {int}', 'client', function(ctx, index)
    askDetecting(ctx, 'kora_metaldetecting:server:beginWash', index)
end)
K.step('I ask the metal detector to begin a find on ground {int}', 'client', function(ctx, ground)
    askDetecting(ctx, 'kora_metaldetecting:server:beginFind', ground)
end)
K.step('the metal detecting server should have answered no', 'client', function(ctx)
    ctx:equal(ctx.state.detectingAnswer, false, 'Server answer')
end)

-- washedClump(washIndex, proof, authorization) / completedFind(ground, proof,
-- authorization) without a matching authorization or a real proof.
K.step('I send a forged clump wash at wash station {int}', 'client', function(_, index)
    trigger('kora_metaldetecting:server:washedClump', index, 'fft-forged-proof', 'fft-forged-authorization')
end)
K.step('I send a forged metal detecting find on ground {int}', 'client', function(_, ground)
    trigger('kora_metaldetecting:server:completedFind', ground, 'fft-forged-proof', 'fft-forged-authorization')
end)
