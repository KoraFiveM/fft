-- kora_consumables: eating, drinking and the legacy AddFood/AddDrink exports.
-- No resource hook: a use goes through exports.kora_core:useItem, the same
-- funnel kora_inventory calls when a player uses a slot, and the progress bar is
-- a kora_lib surface. The use handler blocks on the client's progress bar
-- (kora_consumables/server/server.lua useConsumable), so it runs in its own
-- thread and a later step waits for the result.
local K = FFT.kora
if not K then return end
K.feature('kora_consumables')

-- Longest wait for one use: class durations are 4000 ms
-- (kora_consumables/shared/deafaults.lua) plus the callback round trip.
local USE_TIMEOUT = 10000

K.step('I start consuming {string}', 'server', function(ctx, item)
    K.started('kora_consumables')
    assert(K.count(ctx, item) > 0, 'Tester does not hold ' .. item)
    local use = { item = item, done = false, startedAt = GetGameTimer() }
    ctx.state.consumableUse = use
    local tester = ctx.tester
    CreateThread(function()
        local ok, result = pcall(function() return exports.kora_core:useItem(tester, item) end)
        use.ok, use.result, use.done, use.finishedAt = ok, result, true, GetGameTimer()
    end)
end)

K.step('my {string} use should complete', 'server', function(ctx, item)
    local use = ctx.state.consumableUse
    assert(use and use.item == item, 'No use of ' .. item .. ' was started')
    ctx:waitUntil(function() return use.done end, 'Use of ' .. item .. ' did not return', USE_TIMEOUT)
    if not use.ok then error('useItem raised: ' .. tostring(use.result), 0) end
    assert(use.result == true, 'useItem refused ' .. item)
end)

-- A second use while one is in flight is refused at once (`using[src]`), as is
-- a use of an item that is not held.
K.step('consuming {string} now should be refused', 'server', function(ctx, item)
    K.started('kora_consumables')
    local result = exports.kora_core:useItem(ctx.tester, item)
    assert(result == false, 'useItem accepted ' .. item)
end)

-- Legacy qb-smallresources exports. Only refusals are exercised: an accepted
-- call adds a consumable to the running config for every player until restart.
local LEGACY = { food = 'AddFood', drink = 'AddDrink' }
K.step('registering {string} as legacy {string} worth {int} should be refused with {string}', 'server', function(ctx, item, class, value, reason)
    local export = assert(LEGACY[class], 'Legacy class must be food or drink')
    local ok, err = K.export('kora_consumables', export, item, value)
    if ok then error(('%s accepted %s; restart kora_consumables to remove it'):format(export, item), 0) end
    ctx:equal(err, reason, 'Refusal reason')
end)

-- Same assertion as the generic `a progress bar labelled {string} should
-- start`, but on failure it names the label that was shown instead. The
-- expected label is class label .. item label
-- (kora_consumables/shared/deafaults.lua:23,111-112, e.g. 'Eating ' ..
-- 'Sandwich' from kora_core/shared/upstream/items.lua:252). The client builds
-- it once at script load from its kora_core registry copy, which is filled
-- asynchronously (kora_core/modules/registry/client.lua:10,43-46), so a bar
-- reading only "Eating " means that lookup ran before the registry arrived.
K.step('the consumable progress bar should read {string}', 'client', function(ctx, label)
    local seen, active = nil, false
    local deadline = GetGameTimer() + 8000
    while GetGameTimer() < deadline do
        ctx:check()
        local progress = K.uiState().progress
        if progress then
            active = true
            if progress.label ~= nil then seen = progress.label end
            if K.contains(progress.label, label) then return end
        end
        Wait(100)
    end
    if not active then error('No progress bar started', 0) end
    error(('Progress bar reads "%s", expected "%s"'):format(tostring(seen), label), 0)
end)

-- ---------------------------------------------------------------------------
-- Round 3: registration, timing, receipts, multi-use items and legacy refusals
-- ---------------------------------------------------------------------------

-- kora_consumables registers every Config.Consumables entry with
-- exports.kora_core:createUseable (server/server.lua registerUseable). The
-- kora_core gateway forwards it to kora_inventory, which records the original
-- resource as the owner (kora_inventory/server.lua createUseable/getUseable).
-- An entry whose name is not a real item can never be held, so both halves are
-- asserted: the item exists in kora_core's shared items and the use is ours.
K.step('kora_consumables should handle the use of {string}', 'server', function(_, item)
    K.started('kora_consumables')
    local definition = exports.kora_core:getShared('items', item)
    assert(definition, ('%s is not a shared item, so it can never be held or consumed'):format(item))
    local record = K.export('kora_inventory', 'getUseable', item)
    assert(type(record) == 'table', ('No use handler is registered for %s'):format(item))
    assert(record.resource == 'kora_consumables',
        ('The use of %s is owned by %s, not kora_consumables'):format(item, tostring(record.resource)))
end)

-- server/server.lua useConsumable ignores a use that comes back faster than
-- data.duration - 250 ms, so a real completed use takes at least that long.
K.step('my {string} use should have taken at least {int} milliseconds', 'server', function(ctx, item, minimum)
    local use = ctx.state.consumableUse
    assert(use and use.item == item and use.done, 'The use of ' .. item .. ' has not finished')
    local took = use.finishedAt - use.startedAt
    assert(took >= minimum, ('The use of %s returned after %d ms, expected at least %d'):format(item, took, minimum))
end)

-- Removes every copy while the progress bar runs. takeItem then fails to remove
-- the slot (kora_inventory removeItem: 'item not in slot') and applyUse returns
-- before addStatus, so nothing is applied.
K.step('I lose every {string} while it is being consumed', 'server', function(ctx, item)
    local use = ctx.state.consumableUse
    assert(use and use.item == item and not use.done, 'No use of ' .. item .. ' is in progress')
    local held = K.count(ctx, item)
    assert(held > 0, 'Tester holds no ' .. item)
    local ok, err = exports.kora_core:removeItem(ctx.tester, item, held, nil, 'functional test')
    if not ok then error('Could not remove ' .. item .. ': ' .. tostring(err), 0) end
end)

-- kora_inventory fires kora_inventory:server:usedItem(src, name, item) after a
-- use handler accepted the use (kora_inventory/server.lua useItem).
K.step('I watch the inventory use receipts', 'server', function(ctx)
    local tester = ctx.tester
    K.capture(ctx, 'kora_inventory:server:usedItem', function(src) return tonumber(src) == tester end)
end)

K.step('the inventory should have recorded {int} use of {string}', 'server', function(ctx, expected, item)
    local function count()
        local total = 0
        for _, record in ipairs(K.captured(ctx, 'kora_inventory:server:usedItem')) do
            if record[2] == item then total = total + 1 end
        end
        return total
    end
    ctx:waitUntil(function() return count() == expected end,
        ('Recorded %d uses of %s, expected %d'):format(count(), item, expected), 3000)
end)

-- An item whose info carries `uses` loses one use per consume and is only
-- removed at zero (server/server.lua takeItem, via qb-inventory SetItemData).
K.step('I hold 1 {string} with {int} uses left', 'server', function(ctx, item, uses)
    assert(uses >= 1 and uses <= 10, 'Uses must be 1-10')
    local core, tester = exports.kora_core, ctx.tester
    local ok, err = core:addItem(tester, item, 1, nil, { uses = uses }, 'functional test')
    if not ok then error(('Could not grant %s with %d uses: %s'):format(item, uses, tostring(err)), 0) end
    ctx:cleanup(function()
        local left = core:getItemCount(tester, item) or 0
        if left > 0 then core:removeItem(tester, item, left, nil, 'functional test cleanup') end
    end)
end)

K.step('my {string} should have {int} uses left', 'server', function(ctx, item, uses)
    local function current()
        for _, entry in pairs(K.player(ctx).items or {}) do
            if entry and entry.name == item then
                local info = entry.info or entry.metadata
                return type(info) == 'table' and info.uses or nil
            end
        end
    end
    ctx:waitUntil(function() return current() == uses end,
        ('%s has %s uses left, expected %d'):format(item, tostring(current()), uses), 3000)
end)

-- Legacy qb-smallresources exports (server/server.lua legacyAdd). Only refusals
-- are driven: every row names an item that is already configured or that does
-- not exist, so no row can add a consumable to the running config.
local LEGACY_EXPORTS = { AddFood = true, AddDrink = true, AddAlcohol = true, AddCustom = true }
local LEGACY_VALUES = {
    zero = function() return 0 end,
    ten = function() return 10 end,
    hundred = function() return 100 end,
    negative = function() return -1 end,
    over = function() return 100.5 end,
    nan = function() return 0 / 0 end,
    text = function() return 'ten' end,
    empty_table = function() return {} end,
    none = function() return nil end,
}
local SAFE_LEGACY_ITEM = { fft_no_such_item = true, sandwich = true, water_bottle = true, beer = true,
    cigarette = true, chocolate_bar = true, [''] = true }

local function legacyRefusal(ctx, resource, export, item, kind, reason)
    assert(LEGACY_EXPORTS[export], 'Unknown legacy export ' .. export)
    assert(SAFE_LEGACY_ITEM[item], item .. ' is not a safe legacy test item')
    local value = assert(LEGACY_VALUES[kind], 'Unknown legacy value kind ' .. kind)()
    K.started('kora_consumables')
    local ok, result, why = pcall(function() return exports[resource][export](exports[resource], item, value) end)
    if not ok then error(('exports.%s:%s raised: %s'):format(resource, export, tostring(result)), 0) end
    if result then error(('%s accepted %s; restart kora_consumables to remove it'):format(export, item), 0) end
    ctx:equal(why, reason, 'Refusal reason')
end

K.step('the legacy consumable export {string} should refuse {string} with a {word} value and say {string}', 'server',
    function(ctx, export, item, kind, reason)
        legacyRefusal(ctx, 'kora_consumables', export, item, kind, reason)
    end)

-- Same handler, reached through the provided qb-smallresources identity
-- (Kora.compat.provideExport in server/server.lua).
K.step('the qb-smallresources export {string} should refuse {string} with a {word} value and say {string}', 'server',
    function(ctx, export, item, kind, reason)
        legacyRefusal(ctx, 'qb-smallresources', export, item, kind, reason)
    end)

K.step('the legacy consumable export {string} should refuse a numeric item name', 'server', function(ctx, export)
    assert(LEGACY_EXPORTS[export], 'Unknown legacy export ' .. export)
    local ok, why = K.export('kora_consumables', export, 42, 10)
    ctx:equal(ok, false, export .. ' result')
    ctx:equal(why, 'invalid arguments', 'Refusal reason')
end)
