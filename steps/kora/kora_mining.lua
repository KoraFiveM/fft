-- kora_mining: pickaxe vendor (kora_lib app), rock gating and smelting stations.
-- No resource hook: the vendor, rocks and stations are published in GlobalState,
-- the interactions are kora_target options and the shop/smelter are kora_lib apps.
--
-- Deliberately not driven: a completed mine or smelt. Both call
-- exports.kora_skills:addRep (XP has no delete API) and a mined rock is marked
-- taken for every player until it respawns.
local K = FFT.kora
if not K then return end
K.feature('kora_mining')

-- MiningConfig.pickaxes in kora_mining/shared/config.lua.
local PICKAXES = { 'bronze_pickaxe', 'iron_pickaxe', 'steel_pickaxe', 'titanium_pickaxe', 'obsidian_pickaxe' }

-- ---------------------------------------------------------------------------
-- Server: published state and fixtures
-- ---------------------------------------------------------------------------

local function shop()
    K.started('kora_mining')
    -- server/pickaxe_shop.lua publishShop(): { model, locations = { { coords = { x, y, z, w } } }, prices }.
    local data = GlobalState.koraMiningPickaxeShop
    assert(type(data) == 'table', 'GlobalState.koraMiningPickaxeShop is not published')
    return data
end

-- Rock spots are published as { coords = vec3(x, y, z), taken = false }
-- (kora_mining/server/main.lua rockLocations), and a vector read back from
-- GlobalState has type 'vector3', not 'table'.
local function isPosition(coords)
    local kind = type(coords)
    return kind == 'table' or kind == 'vector3' or kind == 'vector4'
end

local function shopPrice(item)
    local price = tonumber((shop().prices or {})[item])
    assert(price and price >= 0 and price % 1 == 0, 'Mining shop publishes no whole-number price for ' .. tostring(item))
    return price
end

local function miningLevel(ctx)
    -- Read only: the same call server/pickaxe_shop.lua getMiningLevel makes.
    local skill = K.export('kora_skills', 'getRep', ctx.tester, 'mining')
    assert(type(skill) == 'table' and tonumber(skill.level), 'Mining skill is unavailable for the tester')
    return tonumber(skill.level)
end

K.step('the mining pickaxe shop should publish a vendor and a price for every pickaxe', 'server', function()
    local data = shop()
    assert(type(data.model) == 'string' and data.model ~= '', 'Pickaxe vendor model is missing')
    assert(type(data.locations) == 'table' and #data.locations >= 1, 'No pickaxe vendor location is published')
    for index, location in ipairs(data.locations) do
        local coords = type(location) == 'table' and (location.coords or location)
        assert(type(coords) == 'table' and tonumber(coords.x) and tonumber(coords.y) and tonumber(coords.z),
            'Pickaxe vendor location ' .. index .. ' has no coordinates')
    end
    for _, item in ipairs(PICKAXES) do shopPrice(item) end
end)

K.step('the mining rock registry should publish every rock type with settings and spots', 'server', function()
    K.started('kora_mining')
    -- server/main.lua publishes the id list, GlobalState[id] (spots) and GlobalState[id .. 'Data'] (settings).
    local types = GlobalState.koraMiningRockTypes
    assert(type(types) == 'table' and #types >= 1, 'GlobalState.koraMiningRockTypes is empty or missing')
    for _, id in ipairs(types) do
        assert(type(id) == 'string', 'Rock type id is not a string')
        assert(type(GlobalState[id]) == 'table', 'No spots published for rock type ' .. id)
        assert(type(GlobalState[id .. 'Data']) == 'table', 'No settings published for rock type ' .. id)
        for key, spot in pairs(GlobalState[id]) do
            local coords = type(spot) == 'table' and spot.coords
            assert(isPosition(coords) and tonumber(coords.x) and tonumber(coords.y) and tonumber(coords.z),
                ('Rock %s spot %s has no coordinates'):format(id, tostring(key)))
        end
    end
end)

K.step('the mining smelting stations should be published with a target label and locations', 'server', function()
    K.started('kora_mining')
    local data = GlobalState.koraMiningSmelting
    assert(type(data) == 'table' and type(data.stations) == 'table', 'GlobalState.koraMiningSmelting.stations is not published')
    local count = 0
    for id, station in pairs(data.stations) do
        count = count + 1
        assert(type(station) == 'table' and type(station.locations) == 'table', 'Smelting station has no location list: ' .. tostring(id))
        assert(type(station.targetLabel) == 'string' and station.targetLabel ~= '', 'Smelting station has no target label: ' .. tostring(id))
    end
    assert(count >= 1, 'No smelting station is published')
end)

-- Preconditions on the tester's Mining level. XP cannot be removed, so these
-- only read it and fail with a clear message when the character does not fit.
K.step('my mining level should be at least {int}', 'server', function(ctx, level)
    local actual = miningLevel(ctx)
    assert(actual >= level, ('Tester Mining level is %d; this scenario needs at least %d'):format(actual, level))
end)
K.step('my mining level should be below {int}', 'server', function(ctx, level)
    local actual = miningLevel(ctx)
    assert(actual < level, ('Tester Mining level is %d; this scenario needs a level below %d'):format(actual, level))
end)

local function setCash(ctx, amount)
    assert(amount >= 0 and amount <= (FFTConfig.maxTestBalance or 1000000), 'Test balance out of range')
    local core, tester = exports.kora_core, ctx.tester
    local original = K.money(ctx, 'cash')
    local ok, err = core:setMoney(tester, 'cash', amount, 'functional test')
    if not ok then error('Could not set cash: ' .. tostring(err), 0) end
    ctx:cleanup(function() core:setMoney(tester, 'cash', original, 'functional test cleanup') end)
end

K.step('I carry enough cash for the mining shop price of {string}', 'server', function(ctx, item)
    setCash(ctx, shopPrice(item) + 100)
end)
K.step('I carry less cash than the mining shop price of {string}', 'server', function(ctx, item)
    local price = shopPrice(item)
    assert(price > 0, item .. ' is free at the mining shop; the insufficient-cash rule cannot be exercised')
    setCash(ctx, price - 1)
end)

-- Registers the cleanup before the purchase so a bought pickaxe never outlives the scenario.
K.step('any {string} bought from the mining shop is handed back afterwards', 'server', function(ctx, item)
    local core, tester = exports.kora_core, ctx.tester
    local before = K.count(ctx, item)
    ctx:cleanup(function()
        local extra = (core:getItemCount(tester, item) or 0) - before
        if extra > 0 then core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
    end)
end)

K.step('my cash should have dropped by the mining shop price of {string}', 'server', function(ctx, item)
    local before = assert(ctx.state.moneyBaseline and ctx.state.moneyBaseline.cash, 'Remember the cash balance first')
    local price = shopPrice(item)
    ctx:waitUntil(function() return before - K.money(ctx, 'cash') == price end,
        ('Cash changed by %d, expected -%d'):format(K.money(ctx, 'cash') - before, price), 3000)
end)

K.step('I should carry no mining pickaxe', 'server', function(ctx)
    for _, item in ipairs(PICKAXES) do
        assert(K.count(ctx, item) == 0, 'Tester carries a ' .. item .. '; this scenario needs a character without pickaxes')
    end
end)

-- ---------------------------------------------------------------------------
-- Client: positioning in front of the vendor, a rock or a smelting station.
-- Positions come from the live GlobalState, the entity is looked up in the
-- game pools, and the selection itself goes through kora_target's hook.
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

K.step('I face the mining pickaxe vendor', 'client', function(ctx)
    local data = GlobalState.koraMiningPickaxeShop
    assert(type(data) == 'table' and type(data.locations) == 'table' and data.locations[1], 'No pickaxe vendor is published')
    local coords = data.locations[1].coords or data.locations[1]
    -- client/pickaxe_shop.lua spawnVendors: one ped of shop.model per location, option "Buy Pickaxes".
    face(ctx, 'Buy Pickaxes', coords.x, coords.y, coords.z, {
        heading = coords.w, lift = 0.5, aimLift = 0.2,
        find = function() return nearest('CPed', data.model, coords.x, coords.y, coords.z, 3.0) end,
    })
end)

K.step('I face a free {string} rock in the mining field', 'client', function(ctx, id)
    assert(id:match('^[%w_]+$') and #id <= 32, 'Invalid rock type id')
    local settings, spots = GlobalState[id .. 'Data'], GlobalState[id]
    assert(type(settings) == 'table' and type(spots) == 'table', 'Rock type is not published: ' .. id)
    assert(type(settings.model) == 'string', 'Rock type has no model: ' .. id)
    local keys = {}
    for key, spot in pairs(spots) do
        if type(spot) == 'table' and not spot.taken and isPosition(spot.coords) then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    assert(keys[1], 'Every ' .. id .. ' rock is currently mined out; wait for a respawn')
    local coords = spots[keys[1]].coords
    -- client/rockspawns.lua spawnRock: label is settings.targetLabel or 'Mine rock'.
    local label = settings.targetLabel or 'Mine rock'
    ctx.state.miningLabel = label
    -- The server accepts a mine request within 3.0 of the spot (server/main.lua mineProfile).
    ctx.state.miningEntity = face(ctx, label, coords.x, coords.y, coords.z, {
        distance = 1.7, lift = 1.0, aimLift = 0.3,
        find = function() return nearest('CObject', settings.model, coords.x, coords.y, coords.z, 2.5) end,
    })
end)

K.step('I try to mine the rock I am facing', 'client', function(ctx)
    K.target(ctx, assert(ctx.state.miningLabel, 'Face a rock first'), ctx.state.miningEntity)
end)

K.step('I face a mining smelting station', 'client', function(ctx)
    local data = GlobalState.koraMiningSmelting
    assert(type(data) == 'table' and type(data.stations) == 'table', 'No smelting station is published')
    local ids = {}
    for id, station in pairs(data.stations) do
        local first = type(station) == 'table' and type(station.locations) == 'table' and station.locations[1]
        if first and type(first.coords) == 'table' then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    assert(ids[1], 'No smelting station has a location')
    local station = data.stations[ids[1]]
    local location = station.locations[1]
    local coords = location.coords
    -- client/smelting.lua buildStation: an object target when location.object is set, else a 2x2x2 box zone.
    local label = station.targetLabel or 'Smelt'
    ctx.state.smeltingLabel = label
    if location.object then
        ctx.state.smeltingEntity = face(ctx, label, coords.x, coords.y, coords.z, {
            heading = coords.w, lift = 0.5, aimLift = 0.3,
            find = function() return nearest('CObject', location.object, coords.x, coords.y, coords.z, 2.5) end,
        })
    else
        -- Zone options match the camera ray's hit point, so aim a little below the box centre.
        face(ctx, label, coords.x, coords.y, coords.z, { distance = 1.3, aimLift = -0.3 })
    end
end)

K.step('I open the mining smelting station I am facing', 'client', function(ctx)
    K.target(ctx, assert(ctx.state.smeltingLabel, 'Face a smelting station first'), ctx.state.smeltingEntity)
end)

-- ---------------------------------------------------------------------------
-- Round 3: deeper coverage. Still nothing that completes a mine or a smelt.
-- ---------------------------------------------------------------------------

-- Server: admin gate. MiningUtil.isAdmin (server/util.lua) is the raw `command`
-- ACE; these are preconditions, the tester's ACEs cannot be changed from here.
local function commandAce(ctx)
    local allowed = IsPlayerAceAllowed(ctx.tester, 'command')
    return allowed == true or allowed == 1
end
K.step('I have the mining creator permission', 'server', function(ctx)
    assert(commandAce(ctx), 'The tester lacks the "command" ACE that /miningCreator needs')
end)
K.step('I lack the mining creator permission', 'server', function(ctx)
    assert(not commandAce(ctx), 'The tester holds the "command" ACE, so /miningCreator always opens; '
        .. 'this scenario needs a tester with fft.use but without that ACE')
end)

K.step('I carry exactly the mining shop price of {string}', 'server', function(ctx, item)
    setCash(ctx, shopPrice(item))
end)

-- Seeded rock types (server/schema.lua kora_mining_rockspawns rows), as
-- published by server/main.lua refreshRockspawns: GlobalState[id .. 'Data'].
K.step('the {string} rock type should need Mining level {int} and yield {string} under {string}', 'server', function(ctx, id, level, item, label)
    K.started('kora_mining')
    local settings = GlobalState[id .. 'Data']
    assert(type(settings) == 'table', 'Rock type is not published: ' .. id)
    ctx:equal(tonumber(settings.levelRequired), level, id .. ' levelRequired')
    ctx:equal(settings.item, item, id .. ' reward item')
    ctx:equal(settings.targetLabel, label, id .. ' target label')
    assert(type(GlobalState[id]) == 'table', 'No spots published for ' .. id)
end)

-- Seeded pickaxe flags per rock (server/schema.lua); findPickaxe in
-- server/main.lua skips a pickaxe whose setting has enabled == false.
K.step('the {string} rock type should refuse the pickaxe {string}', 'server', function(ctx, id, pickId)
    local settings = GlobalState[id .. 'Data']
    assert(type(settings) == 'table' and type(settings.pickaxes) == 'table', 'Rock type has no pickaxe settings: ' .. id)
    local setting = settings.pickaxes[pickId]
    assert(type(setting) == 'table', ('Rock %s has no setting for %s'):format(id, pickId))
    ctx:equal(setting.enabled, false, ('%s enabled on %s'):format(pickId, id))
end)

-- server/blips.lua publishBlips: a sorted list of cleaned blips.
local function blips()
    K.started('kora_mining')
    local list = GlobalState.koraMiningBlips
    assert(type(list) == 'table', 'GlobalState.koraMiningBlips is not published')
    return list
end
K.step('the mining map blips should be published with valid settings', 'server', function()
    local list = blips()
    assert(#list >= 1, 'No mining map blip is published')
    assert(#list <= 50, 'More than MAX_BLIPS (50) blips are published')
    local previous
    for _, blip in ipairs(list) do
        assert(type(blip.id) == 'string' and blip.id:match('^[%w_]+$'), 'Blip id is invalid: ' .. tostring(blip.id))
        assert(not previous or previous < blip.id, 'Blips are not sorted by id at ' .. blip.id)
        previous = blip.id
        assert(type(blip.name) == 'string' and blip.name ~= '' and #blip.name <= 48, 'Blip name is invalid: ' .. blip.id)
        assert(type(blip.sprite) == 'number' and blip.sprite % 1 == 0, 'Blip sprite is not whole: ' .. blip.id)
        assert(type(blip.color) == 'number' and blip.color % 1 == 0, 'Blip colour is not whole: ' .. blip.id)
        assert(type(blip.scale) == 'number', 'Blip scale is not a number: ' .. blip.id)
        assert(blip.sprite >= 0 and blip.sprite <= 900, 'Blip sprite out of range: ' .. blip.id)
        assert(blip.color >= 0 and blip.color <= 85, 'Blip colour out of range: ' .. blip.id)
        assert(blip.scale >= 0.1 and blip.scale <= 3.0, 'Blip scale out of range: ' .. blip.id)
        assert(type(blip.shortRange) == 'boolean', 'Blip shortRange is not a boolean: ' .. blip.id)
        for _, axis in ipairs({ 'x', 'y', 'z' }) do
            assert(type(blip[axis]) == 'number' and math.abs(blip[axis]) <= 10000, ('Blip %s %s is invalid'):format(blip.id, axis))
        end
    end
end)
K.step('the mining map blip {string} should be named {string}', 'server', function(ctx, id, name)
    for _, blip in ipairs(blips()) do
        if blip.id == id then ctx:equal(blip.name, name, 'Blip name') return end
    end
    error('No mining map blip ' .. id, 0)
end)

-- ---------------------------------------------------------------------------
-- Client
-- ---------------------------------------------------------------------------

K.step('I step {int} metres away from the mining pickaxe vendor', 'client', function(ctx, metres)
    assert(metres >= 6 and metres <= 50, 'Use 6-50 metres (the shop radius is 5.0, server/pickaxe_shop.lua isAtVendor)')
    local data = GlobalState.koraMiningPickaxeShop
    assert(type(data) == 'table' and type(data.locations) == 'table' and data.locations[1], 'No pickaxe vendor is published')
    for index, location in ipairs(data.locations) do
        if index > 1 then
            local c = location.coords or location
            local first = data.locations[1].coords or data.locations[1]
            assert(#(vector3(c.x, c.y, c.z) - vector3(first.x + metres, first.y, first.z)) > 6.0,
                'Another pickaxe vendor stands near the destination')
        end
    end
    local coords = data.locations[1].coords or data.locations[1]
    K.teleport(ctx, coords.x + metres, coords.y, coords.z + 0.5)
end)

local function openApp(ctx, id)
    ctx:waitUntil(function() local app = K.uiState().app return app and app.id == id end, 'App is not open: ' .. id)
    local payload = K.ui('app')
    assert(type(payload) == 'table' and type(payload.app) == 'table', 'No app payload is available')
    return payload.app
end

local function entries(list)
    local n = 0
    for key in pairs(type(list) == 'table' and list or {}) do if key ~= '...' then n = n + 1 end end
    return n
end

local function block(app, viewId, blockId)
    for _, view in pairs(type(app.navigation) == 'table' and app.navigation or {}) do
        if type(view) == 'table' and view.id == viewId then
            for _, candidate in pairs(type(view.content) == 'table' and view.content.blocks or {}) do
                if type(candidate) == 'table' and candidate.id == blockId then return candidate, view end
            end
            error(('View %s has no block %s'):format(viewId, blockId), 0)
        end
    end
    error('App has no view ' .. viewId, 0)
end

-- client/pickaxe_shop.lua buildNavigation: view 'shop', list 'pickaxe-list', one card per MiningConfig.pickaxes entry.
K.step('the mining pickaxe shop should list every pickaxe', 'client', function(ctx)
    local app = openApp(ctx, 'kora_mining:pickaxeShop')
    ctx:equal(app.title, 'Mining Pickaxes', 'Shop title')
    local list, view = block(app, 'shop', 'pickaxe-list')
    ctx:equal(view.content.title, 'Mining Pickaxes', 'Shop view title')
    ctx:equal(entries(list.items), #PICKAXES, 'Pickaxe cards')
end)

-- client/smelting.lua: stations are box zones or objects; pick one by id.
K.step('I face the mining smelting station {string}', 'client', function(ctx, id)
    local data = GlobalState.koraMiningSmelting
    local station = type(data) == 'table' and type(data.stations) == 'table' and data.stations[id]
    assert(type(station) == 'table' and type(station.locations) == 'table' and station.locations[1],
        'Smelting station is not published with a location: ' .. id)
    local location = station.locations[1]
    local coords = location.coords
    local label = station.targetLabel or 'Smelt'
    ctx.state.smeltingLabel = label
    ctx.state.smeltingEntity = nil
    if location.object then
        ctx.state.smeltingEntity = face(ctx, label, coords.x, coords.y, coords.z, {
            heading = coords.w, lift = 0.5, aimLift = 0.3,
            find = function() return nearest('CObject', location.object, coords.x, coords.y, coords.z, 2.5) end,
        })
    else
        face(ctx, label, coords.x, coords.y, coords.z, { distance = 1.3, aimLift = -0.3 })
    end
end)

-- client/smelting.lua buildRecipeCards: one list block 'recipes-<category>' per
-- MiningConfig.smeltingCategories entry (bars, materials, jewellery, pickaxes, gemstones).
K.step('the mining smelting menu should have a section for every category', 'client', function(ctx)
    local app = openApp(ctx, 'kora_mining:smelting')
    for _, category in ipairs({ 'bars', 'materials', 'jewellery', 'pickaxes', 'gemstones' }) do
        block(app, 'recipes', 'recipes-' .. category)
    end
end)
K.step('the mining smelting section {string} should list at least {int} recipes', 'client', function(ctx, category, minimum)
    local list = block(openApp(ctx, 'kora_mining:smelting'), 'recipes', 'recipes-' .. category)
    local n = entries(list.items)
    assert(n >= minimum, ('Section %s lists %d recipes, expected at least %d'):format(category, n, minimum))
end)
K.step('the mining smelting section {string} should list no recipes', 'client', function(ctx, category)
    local list = block(openApp(ctx, 'kora_mining:smelting'), 'recipes', 'recipes-' .. category)
    ctx:equal(entries(list.items), 0, 'Recipes in section ' .. category)
end)

-- client/creator.lua: APP = 'kora_mining:creator', opened by the server only for admins.
K.step('the mining creator should have refused to open', 'client', function(ctx)
    K.waitNotification(ctx, 'Admin permission required.')
    local app = K.uiState().app
    assert(not (app and app.id == 'kora_mining:creator'), 'The mining creator opened')
end)
