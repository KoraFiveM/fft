-- kora_drugs: published production steps, lab entrances, the dealer roster,
-- corner-selling settings and the usable/command rejection paths.
--
-- Hook: kora_drugs/fft_hooks_server.lua, one read-only action `cornerSelling`.
-- Corner-selling prices are server-only by design (never in GlobalState), and
-- the scenarios must know which items the corner seller accepts before they
-- run /cornerSell, so the tester is proven to carry none of them.
--
-- Hook: kora_drugs/fft_hooks.lua (client), actions `cornerPrice`,
-- `cornerPriceSet` and `cornerPriceRemove`. A server without the example data
-- (Config.storage.exampleData, off by default) has an empty price list, so the
-- corner-selling scenarios price one item themselves through the admin
-- callbacks the /drugCreator cornerselling page sends, and cleanup puts the
-- price list back exactly as it was. The tester must therefore hold the
-- permission /drugCreator asks for; without it the server refuses the save
-- and the fixture step fails with "Admin permission required."
--
-- HAZARD: server/_functions.lua onCooldown drops the player on the fifth hit
-- inside a cooldown window. Nothing here crafts, picks or otherwise calls a
-- path guarded by it. Nothing here completes a sale either: the corner seller
-- takes over an ambient ped, and a delivery, a cook or a lab teleport would
-- move drugs, money or the player in ways other players can see.
local K = FFT.kora
if not K then return end
K.feature('kora_drugs')

-- server/events.lua EventSteps, minus the server-only drugs (CornerSelling, Custom).
local PUBLIC_STEPS = {
    'Cocaine:lab', 'Cocaine:powder', 'Cocaine:cutting', 'Cocaine:bagging',
    'Crack:cook', 'Crack:bagging',
    'Heroin:drying', 'Heroin:vials', 'Heroin:syringe',
    'Meth:tele', 'Meth:pour', 'Meth:heat', 'Meth:smash', 'Meth:bag',
    'Weed:lab', 'Weed:drying', 'Weed:breakNugs', 'Weed:bagWeed',
    'Recipes:settings',
}
local SERVER_ONLY = { 'CornerSelling', 'Custom' }
-- Steps whose locations server/events.lua normalises into { enter, exit } doors.
local ENTRANCES = { 'Cocaine:lab', 'Weed:lab', 'Meth:tele' }
-- server/Weed.lua strains: what the rolling paper looks for.
local WEED = { 'purple_haze_weed', 'ak47_weed', 'amnesia_weed', 'skunk_weed', 'og_kush_weed', 'blue_dream_weed' }
-- server/events.lua keeps this step out of GlobalState and out of the reload
-- broadcast, so re-reading it can never push anything to a client.
local SILENT_STEP = 'CornerSelling:settings'
local USABLES = { rolling_paper = true }
-- Items the fixture may price. A real kora_core item (shared/items.lua) that the
-- shipped example data also sells on the corner (server/schema.lua, row 27).
local FIXTURE_ITEMS = { cocaine_baggy = true }

local function published()
    K.started('kora_drugs')
    local drugs = GlobalState.Drugs
    assert(type(drugs) == 'table', 'GlobalState.Drugs is not published')
    return drugs
end

local function entry(drugs, name)
    local drug, step = name:match('^(%w+):([%w_]+)$')
    local value = type(drugs[drug]) == 'table' and drugs[drug][step]
    assert(type(value) == 'table', 'GlobalState.Drugs has no entry for ' .. name)
    return value
end

local function isVec(value)
    local kind = type(value)
    return (kind == 'table' or kind == 'vector3' or kind == 'vector4')
        and tonumber(value.x) and tonumber(value.y) and tonumber(value.z) and true or false
end

K.step('the drug production registry should publish every public step with settings and locations', 'server', function()
    local drugs = published()
    for _, name in ipairs(PUBLIC_STEPS) do
        local value = entry(drugs, name)
        assert(type(value.data) == 'table', name .. ' publishes no data table')
        assert(type(value.locations) == 'table', name .. ' publishes no locations table')
    end
end)

K.step('the drug production registry should keep server-only drug settings private', 'server', function()
    local drugs = published()
    for _, drug in ipairs(SERVER_ONLY) do
        assert(drugs[drug] == nil, drug .. ' is published in GlobalState.Drugs; its settings are meant to stay on the server')
    end
end)

K.step('every published drug lab entrance should have an enter and an exit position', 'server', function()
    local drugs = published()
    for _, name in ipairs(ENTRANCES) do
        local locations = entry(drugs, name).locations
        assert(type(locations) == 'table', name .. ' publishes no locations table')
        for index, door in pairs(locations) do
            assert(type(door) == 'table' and isVec(door.enter) and isVec(door.exit),
                ('%s entrance %s is not a normalised { enter, exit } pair'):format(name, tostring(index)))
        end
    end
end)

K.step('every drug dealer in the roster should list the {int} configured products', 'server', function(_, expected)
    -- server/legacy_dealers.lua roster(): [name] = { id, name, coords, time = { min, max }, products }.
    -- Products come from shared/legacy_dealers.lua: price 15, minrep (slot - 1) * 20.
    local roster = K.export('kora_drugs', 'GetDealers')
    assert(type(roster) == 'table', 'GetDealers did not return a table')
    for name, dealer in pairs(roster) do
        local label = 'Dealer ' .. tostring(name)
        assert(type(dealer) == 'table' and dealer.name == name, label .. ' is not keyed by its own name')
        assert(isVec(dealer.coords), label .. ' has no coordinates')
        assert(type(dealer.time) == 'table' and tonumber(dealer.time.min) and tonumber(dealer.time.max), label .. ' has no opening hours')
        assert(type(dealer.products) == 'table', label .. ' has no product list')
        local count = 0
        for slot, product in pairs(dealer.products) do
            count = count + 1
            slot = tonumber(slot)
            assert(slot and type(product) == 'table' and type(product.name) == 'string' and product.name ~= '',
                label .. ' has an unnamed product')
            assert(product.price == 15, ('%s sells %s for %s, expected 15'):format(label, product.name, tostring(product.price)))
            assert(product.minrep == (slot - 1) * 20,
                ('%s product %d needs reputation %s, expected %d'):format(label, slot, tostring(product.minrep), (slot - 1) * 20))
            assert(type(product.amount) == 'number' and product.amount >= 0, label .. ' product ' .. slot .. ' has no stock amount')
        end
        assert(count == expected, ('%s lists %d products, expected %d'):format(label, count, expected))
    end
end)

local function cornerSelling(ctx)
    local _, settings = K.must(K.hook('kora_drugs', 'cornerSelling', ctx.tester))
    assert(type(settings) == 'table' and type(settings.items) == 'table', 'Corner selling snapshot is malformed')
    assert(settings.configured, 'Corner selling has no pricing configured (CornerSelling:settings row); /cornerSell cannot work on this server')
    return settings
end

-- Fixture: prices one item for the length of the scenario. The price the item
-- had before is read first and the restore is registered before the save, so a
-- save whose answer never arrives is still undone.
K.step('the corner seller buys {string} for {int} during this scenario', 'client', function(ctx, item, price)
    assert(FIXTURE_ITEMS[item], 'Not an item this suite may price for corner selling: ' .. tostring(item))
    local _, before = K.must(K.hook('kora_drugs', 'cornerPrice', item))
    assert(type(before) == 'table', 'The corner price hook returned no snapshot')
    local previous = tonumber(before.price)
    ctx:cleanup(function()
        pcall(function()
            if previous then exports.kora_drugs:fftAction('cornerPriceSet', item, previous)
            else exports.kora_drugs:fftAction('cornerPriceRemove', item) end
        end)
    end)
    K.must(K.hook('kora_drugs', 'cornerPriceSet', item, price))
end)

K.step('corner selling should price {string} at {int}', 'server', function(ctx, item, price)
    local settings = cornerSelling(ctx)
    for _, entry in ipairs(settings.items) do
        if entry.name == item then
            ctx:equal(entry.price, price, 'Corner selling price for ' .. item)
            return
        end
    end
    error('The corner seller has no price for ' .. item, 0)
end)

K.step('corner selling should have a positive price for at least one item', 'server', function(ctx)
    local settings = cornerSelling(ctx)
    assert(settings.count >= 1, 'Corner selling pricing is empty')
    for _, item in ipairs(settings.items) do
        assert(type(item.price) == 'number' and item.price > 0,
            ('Corner selling price for %s is %s'):format(tostring(item.name), tostring(item.price)))
    end
    if settings.maxSell ~= nil then assert(settings.maxSell >= 1, 'Corner selling maxSell is below 1') end
end)

-- /cornerSell with stock takes over an ambient ped, so the scenario must not
-- reach the command unless the tester carries nothing the corner seller buys.
K.step('I carry nothing the corner seller would buy', 'server', function(ctx)
    local settings = cornerSelling(ctx)
    assert(settings.count == #settings.items, 'Corner selling prices more items than the hook reports; cannot prove the tester carries none')
    for _, item in ipairs(settings.items) do
        assert(K.count(ctx, item.name) == 0, 'Tester carries ' .. item.name .. ', which the corner seller would buy')
    end
end)

K.step('I should carry no weed that rolling paper could use', 'server', function(ctx)
    for _, item in ipairs(WEED) do
        assert(K.count(ctx, item) == 0, 'Tester carries ' .. item .. '; using rolling paper would start rolling a joint')
    end
end)

-- Uses the item the way the inventory does: kora_core runs the usable the
-- resource registered in server/Weed.lua.
K.step('I use my drug item {string}', 'server', function(ctx, item)
    assert(USABLES[item], 'Not a drug usable covered by this suite: ' .. tostring(item))
    assert(K.count(ctx, item) > 0, 'The tester holds no ' .. item)
    K.export('kora_core', 'useItem', ctx.tester, item)
end)

-- exports.kora_drugs:ReloadEvents(name) re-reads one step and reports whether
-- the stored row differed from what the server last saw. The first call settles
-- any pending difference; the second must then report no change. Only the
-- silent server-only step is used, so no client ever receives a reload.
K.step('reloading the unchanged corner selling settings should report no change', 'server', function()
    K.export('kora_drugs', 'ReloadEvents', SILENT_STEP)
    local changed = K.export('kora_drugs', 'ReloadEvents', SILENT_STEP)
    assert(changed == false, 'ReloadEvents reported ' .. tostring(changed) .. ' for an unchanged step, expected false')
end)

-- ===========================================================================
-- Round 3: the /drugCreator server callbacks, corner prices, plants, dealers
-- ===========================================================================

-- server/_functions.lua:49-52 isAdmin: the ACE `command`. Every creator
-- callback checks it first (server/creator.lua:35-40) and answers
-- false, 'Admin permission required.' otherwise.
K.step('I may use the drug creator', 'server', function(ctx)
    local allowed = IsPlayerAceAllowed(ctx.tester, 'command')
    if allowed ~= true and allowed ~= 1 then
        error('The tester lacks the ACE "command" kora_drugs checks for /drugCreator; '
            .. 'these scenarios need a tester who may use the drug creator', 0)
    end
end)

-- The creator callbacks are kora_lib callbacks; fft asks them the way the
-- creator page does. callback_triggerPacked keeps every value (a `nil, reason`
-- refusal included); a raised handler error or rate-limit rejection arrives as
-- { __kora_lib_rejected = true, error } (kora_lib local/callback/shared.lua).
local function creatorCall(name, ...)
    K.started('kora_drugs')
    K.started('kora_lib')
    local ok, packed = pcall(function(...) return exports.kora_lib:callback_triggerPacked(name, ...) end, ...)
    if not ok then error(('Callback %s failed: %s'):format(name, tostring(packed)), 0) end
    if type(packed) ~= 'table' then return packed end
    if packed.__kora_lib_rejected then error(('Callback %s failed: %s'):format(name, tostring(packed.error)), 0) end
    return table.unpack(packed, 1, math.tointeger(packed.n) or #packed)
end

local CORNER_STEP = 'CornerSelling:settings' -- server/creator.lua:23

-- The corner settings the cornerselling page loads, copied like fft_hooks.lua load().
local function cornerData()
    local result, err = creatorCall('kora_drugs:creator:corner:get')
    assert(type(result) == 'table' and type(result.data) == 'table', 'Could not load the corner settings: ' .. tostring(err))
    local copy = {}
    for key, value in pairs(result.data) do copy[key] = value end
    copy.pricing = {}
    for name, price in pairs(type(result.data.pricing) == 'table' and result.data.pricing or {}) do copy.pricing[name] = price end
    return copy, result
end

-- A corner save that breaks one rule of cleanCornerData (server/creator.lua:476-529).
-- Everything else is sent back as it was read, so even a save that should have
-- been refused but was not changes nothing else; it is undone in cleanup.
local function cornerSave(change)
    return function(ctx)
        local original = cornerData()
        local data = cornerData()
        change(data)
        return { 'kora_drugs:creator:event:save', CORNER_STEP, { data = data } }, function()
            exports.kora_lib:callback_trigger('kora_drugs:creator:event:save', CORNER_STEP, { data = original })
        end
    end
end

local function fixed(...)
    local request = table.pack(...)
    return function() return request end
end

-- Each request is one refusal branch of server/creator.lua; the expected
-- message is given in the feature. `undo` runs only if the server accepted it.
local CREATOR_REQUESTS = {
    -- events (:768-817, :1092-1124)
    ['reading an unknown event'] = fixed('kora_drugs:creator:event:get', 'Fft:noSuchStep'),
    ['reading the reserved Weed:pick event'] = fixed('kora_drugs:creator:event:get', 'Weed:pick'),
    ['saving an unknown event'] = fixed('kora_drugs:creator:event:save', 'Fft:noSuchStep', { data = {} }),
    ['saving corner settings without a patch table'] = fixed('kora_drugs:creator:event:save', CORNER_STEP, 'everything'),
    ['saving corner settings whose data is not a table'] = fixed('kora_drugs:creator:event:save', CORNER_STEP, { data = 'prices' }),
    ['saving a corner price list that is not a table'] = cornerSave(function(data) data.pricing = 'cheap' end),
    ['saving a corner price for a malformed item name'] = cornerSave(function(data) data.pricing['fft item!'] = 20 end),
    ['saving a negative corner price'] = cornerSave(function(data) data.pricing.cocaine_baggy = -1 end),
    ['saving a corner price above the limit'] = cornerSave(function(data) data.pricing.cocaine_baggy = 1000001 end),
    ['saving a corner price that is not a number'] = cornerSave(function(data) data.pricing.cocaine_baggy = 'cheap' end),
    ['saving 501 corner prices'] = cornerSave(function(data)
        data.pricing = {}
        for index = 1, 501 do data.pricing['fft_corner_item_' .. index] = 1 end
    end),
    ['saving a max sell of 0'] = cornerSave(function(data) data.maxSell = 0 end),
    ['saving a rip-off of 1.5'] = cornerSave(function(data) data.ripOff = 1.5 end),
    ['saving a minimum police of 101'] = cornerSave(function(data) data.minPolice = 101 end),
    ['saving a negative THC swing'] = cornerSave(function(data) data.weedPercentFlow = -0.1 end),
    ['deleting the permanent corner settings'] = fixed('kora_drugs:creator:event:delete', CORNER_STEP),
    ['deleting an unknown event'] = fixed('kora_drugs:creator:event:delete', 'Fft:noSuchStep'),
    ['restoring the permanent recipe settings'] = fixed('kora_drugs:creator:event:restore', 'Recipes:settings'),
    -- plants (:290-354); prop_plant_01a is the Cocaine:pick model of server/schema.lua:19
    ['reading an unknown plant'] = fixed('kora_drugs:creator:get', 'FftNoSuchPlant'),
    ['saving a plant without a patch table'] = fixed('kora_drugs:creator:save', 'FftNoSuchPlant', 'everything'),
    ['saving an unknown plant'] = fixed('kora_drugs:creator:save', 'FftNoSuchPlant', {}),
    ['deleting an unknown plant'] = fixed('kora_drugs:creator:delete', 'FftNoSuchPlant'),
    ['creating a plant whose name starts with a digit'] = fixed('kora_drugs:creator:create', '1FftPlant', 'prop_plant_01a', 'cocaine_baggy'),
    ['creating a plant named like a GlobalState key'] = fixed('kora_drugs:creator:create', 'Drugs', 'prop_plant_01a', 'cocaine_baggy'),
    ['creating a plant with a malformed model'] = fixed('kora_drugs:creator:create', 'FftNoSuchPlant', 'bad model!', 'cocaine_baggy'),
    ['creating a plant that gives an unknown item'] = fixed('kora_drugs:creator:create', 'FftNoSuchPlant', 'prop_plant_01a', 'fft_no_such_item'),
    -- recipes (:882-948)
    ['searching items for an unknown recipe'] = fixed('kora_drugs:creator:recipes:search', 'cocaine', 'Fft:noSuchRecipe'),
    ['setting the items of an unknown recipe'] = fixed('kora_drugs:creator:recipes:set', 'Fft:noSuchRecipe', {}),
    ['setting the product of an unknown recipe'] = fixed('kora_drugs:creator:recipes:receive', 'Fft:noSuchRecipe', 'cocaine_baggy', 1),
    ['deleting an unknown recipe'] = fixed('kora_drugs:creator:recipes:delete', 'Fft:noSuchRecipe'),
    ['creating a recipe whose drug starts with a digit'] = fixed('kora_drugs:creator:recipes:create', '1Fft', 'test', 'cocaine_baggy', 1),
    ['creating a recipe that makes an unknown item'] = fixed('kora_drugs:creator:recipes:create', 'Fft', 'test', 'fft_no_such_item', 1),
    ['creating a recipe that makes 0 items'] = fixed('kora_drugs:creator:recipes:create', 'Fft', 'test', 'cocaine_baggy', 0),
    -- custom drugs and events (:996-1066)
    ['creating a custom drug whose name starts with a digit'] = fixed('kora_drugs:creator:custom:drug:create', '1FftDrug'),
    ['creating a custom drug named Weed'] = fixed('kora_drugs:creator:custom:drug:create', 'Weed'),
    ['creating a custom drug named weed in lower case'] = fixed('kora_drugs:creator:custom:drug:create', 'weed'),
    ['deleting an unknown custom drug'] = fixed('kora_drugs:creator:custom:drug:delete', 'FftNoSuchDrug'),
    ['creating a custom event whose name starts with a digit'] = fixed('kora_drugs:creator:custom:event:create', 'FftNoSuchDrug', '1step'),
    ['creating a custom event for an unknown drug'] = fixed('kora_drugs:creator:custom:event:create', 'FftNoSuchDrug', 'cook'),
    ['creating a custom event over a base event'] = fixed('kora_drugs:creator:custom:event:create', 'Weed', 'drying'),
    ['deleting a base event as a custom event'] = fixed('kora_drugs:creator:custom:event:delete', 'Weed:drying'),
}

-- What to undo if a request that should be refused was accepted after all.
local CREATOR_UNDO = {
    ['kora_drugs:creator:create'] = function(request) return 'kora_drugs:creator:delete', request[2] end,
    ['kora_drugs:creator:recipes:create'] = function(request) return 'kora_drugs:creator:recipes:delete', ('%s:%s'):format(request[2], request[3]) end,
    ['kora_drugs:creator:custom:drug:create'] = function(request) return 'kora_drugs:creator:custom:drug:delete', request[2] end,
    ['kora_drugs:creator:custom:event:create'] = function(request) return 'kora_drugs:creator:custom:event:delete', ('%s:%s'):format(request[2], request[3]) end,
    ['kora_drugs:creator:event:delete'] = function(request) return 'kora_drugs:creator:event:restore', request[2] end,
}

K.step('the drug creator should refuse {string} with {string}', 'client', function(ctx, case, message)
    local build = assert(CREATOR_REQUESTS[case], 'No drug creator request named "' .. case .. '"')
    local request, undo = build(ctx)
    local undoCall = CREATOR_UNDO[request[1]]
    local accepted = false
    ctx:cleanup(function()
        if not accepted then return end
        pcall(function()
            if undo then undo()
            elseif undoCall then exports.kora_lib:callback_trigger(undoCall(request)) end
        end)
    end)
    local result, err = creatorCall(table.unpack(request, 1, request.n or #request))
    accepted = result ~= false and result ~= nil
    if accepted then error(('The drug creator accepted %s (answer %s)'):format(case, json.encode(result)), 0) end
    ctx:equal(err, message, 'Refusal message for ' .. case)
end)

-- Read-only: every public step the creator can open, server/creator.lua:808-812.
K.step('the drug creator should open the event {string} with its data and locations', 'client', function(ctx, step)
    local result, err = creatorCall('kora_drugs:creator:event:get', step)
    assert(type(result) == 'table', ('The creator could not open %s: %s'):format(step, tostring(err)))
    ctx:equal(result.step, step, 'Step of the answer')
    assert(type(result.data) == 'table', step .. ' has no data table')
    assert(type(result.locations) == 'table', step .. ' has no locations table')
end)

K.step('the drug creator corner page should list {string} at {int}', 'client', function(ctx, item, price)
    local data, result = cornerData()
    ctx:equal(tonumber(data.pricing[item]), price, 'Creator price for ' .. item)
    -- server/creator.lua:826-833: every priced item is described from the shared item list.
    assert(type(result.items) == 'table' and result.items[item] ~= nil, 'The corner page does not describe ' .. item)
end)

K.step('the drug creator should list every plant published to players', 'client', function(ctx)
    local types = GlobalState.drugPlantTypes
    if type(types) ~= 'table' or #types == 0 then return end -- no plant rows: nothing to compare
    local list, err = creatorCall('kora_drugs:creator:list')
    assert(type(list) == 'table', 'The creator plant list failed: ' .. tostring(err))
    local listed = {}
    for _, plant in ipairs(list) do listed[plant.id] = plant end
    for _, name in ipairs(types) do
        local plant = listed[name]
        assert(plant, 'Published plant ' .. tostring(name) .. ' is missing from the creator list')
        -- server/plantSpawns.lua:33: disabled plants are never published.
        ctx:equal(plant.disabled, false, 'Published plant ' .. name .. ' is disabled in the creator')
    end
end)

-- Fixture companion: takes one price away for the length of the scenario
-- through the hook's cornerPriceRemove, restoring the price it had.
K.step('the corner seller stops buying {string} during this scenario', 'client', function(ctx, item)
    assert(FIXTURE_ITEMS[item], 'Not an item this suite may price for corner selling: ' .. tostring(item))
    local _, before = K.must(K.hook('kora_drugs', 'cornerPrice', item))
    local previous = tonumber(before and before.price)
    ctx:cleanup(function()
        pcall(function() if previous then exports.kora_drugs:fftAction('cornerPriceSet', item, previous) end end)
    end)
    K.must(K.hook('kora_drugs', 'cornerPriceRemove', item))
end)

K.step('corner selling should not price {string}', 'server', function(ctx, item)
    local _, settings = K.must(K.hook('kora_drugs', 'cornerSelling', ctx.tester))
    assert(type(settings) == 'table' and type(settings.items) == 'table', 'Corner selling snapshot is malformed')
    for _, entry in ipairs(settings.items) do
        if entry.name == item then error(('The corner seller still prices %s at %s'):format(item, tostring(entry.price)), 0) end
    end
end)

-- server/events.lua:105-107: a name that is not Drug:step, or a :pick step, is never reloaded.
K.step('reloading the drug step {string} should be refused', 'server', function(ctx, name)
    ctx:equal(K.export('kora_drugs', 'ReloadEvents', name), false, 'ReloadEvents("' .. name .. '")')
end)

-- server/plantSpawns.lua:78-90: each published type has GlobalState[type]
-- (spots) and GlobalState[type .. 'Data'] (settings).
K.step('every published drug plant should have spots and settings', 'server', function()
    K.started('kora_drugs')
    local types = GlobalState.drugPlantTypes
    if types == nil then return end
    assert(type(types) == 'table', 'GlobalState.drugPlantTypes is not a list')
    local seen = {}
    for _, name in ipairs(types) do
        assert(type(name) == 'string' and name:match('^%w+$'), 'Malformed plant type ' .. tostring(name))
        assert(not seen[name], 'Plant type ' .. name .. ' is published twice')
        seen[name] = true
        local spots, data = GlobalState[name], GlobalState[name .. 'Data']
        assert(type(spots) == 'table', 'Plant ' .. name .. ' publishes no spots')
        for index, spot in ipairs(spots) do
            assert(type(spot) == 'table' and isVec(spot.coords), ('Plant %s spot %d has no coordinates'):format(name, index))
            assert(type(spot.taken) == 'boolean', ('Plant %s spot %d has no taken flag'):format(name, index))
        end
        assert(type(data) == 'table', 'Plant ' .. name .. ' publishes no settings')
        assert(data.disabled ~= true, 'Disabled plant ' .. name .. ' is published')
    end
end)

-- server/legacy_dealers.lua:233-234: the qb-drugs compatibility export serves the same roster.
K.step('the qb-drugs dealer export should serve the same roster', 'server', function(ctx)
    local roster = K.export('kora_drugs', 'GetDealers')
    local ok, compat = pcall(function() return exports['qb-drugs']:GetDealers() end)
    assert(ok, 'exports["qb-drugs"]:GetDealers failed: ' .. tostring(compat))
    assert(type(roster) == 'table' and type(compat) == 'table', 'A dealer roster is not a table')
    for name, dealer in pairs(roster) do
        assert(type(compat[name]) == 'table', 'qb-drugs roster misses dealer ' .. tostring(name))
        ctx:equal(compat[name].id, dealer.id, 'Id of dealer ' .. tostring(name))
    end
    for name in pairs(compat) do assert(roster[name], 'qb-drugs roster has an extra dealer ' .. tostring(name)) end
end)

