-- kora_inventory: the server export API (server.lua's `api` table), the client
-- HasItem / session exports, the `inventory` and `closeInv` commands, and the
-- 24/7 convenience shop. Everything is called for the test character only.
--
-- The shop UI purchase goes through kora_inventory's existing FFT hook
-- (dragBuy) by reusing the builtin "I buy {int} {string} through the inventory
-- UI" step; this file adds no hook action.
--
-- Deliberately out of reach of this file: stashes (stashGet/stashSet lazily
-- create a durable stash and no export deletes one; CreateTemporaryStash has
-- no removal export), drops (dropCreate broadcasts a world bag to every
-- client), shopSet/registerShop (shared shop state), createUseable (no
-- removal export), hooks and inspection access. clearInventory/setItems and
-- useItem refusals are covered further down, for the test character only.
local K = FFT.kora
if not K then return end
K.feature('kora_inventory')

local INV = 'kora_inventory'
local PURCHASED = 'kora_inventory:server:itemPurchased'

local function refused(what, ok, err, reason)
    if ok then error(('kora_inventory accepted %s'):format(what), 0) end
    if err ~= reason then
        error(('%s was refused with "%s", expected "%s"'):format(what, tostring(err), reason), 0)
    end
end

-- Removes at most what this scenario added, and only what is still held.
local function forget(ctx, item, amount)
    local tester = ctx.tester
    ctx:cleanup(function()
        local left = exports.kora_inventory:getItemCount(tester, item) or 0
        if left > 0 then
            exports.kora_inventory:removeItem(tester, item, math.min(left, amount), nil, 'functional test cleanup')
        end
    end)
end

local function slotOf(ctx, item)
    local record = K.export(INV, 'getItemByName', ctx.tester, item)
    if type(record) ~= 'table' or type(record.slot) ~= 'number' then
        error(('The tester holds no %s'):format(item), 0)
    end
    return record.slot, record
end

local function freeSlot(ctx)
    local slot = K.export(INV, 'getFreeSlot', ctx.tester)
    if type(slot) ~= 'number' then error('The tester has no free inventory slot', 0) end
    return slot
end

-- ---------------------------------------------------------------------------
-- addItem / removeItem
-- ---------------------------------------------------------------------------

K.step('the inventory gives me {int} {string}', 'server', function(ctx, amount, item)
    forget(ctx, item, amount)
    local ok, err = K.export(INV, 'addItem', ctx.tester, item, amount, nil, nil, 'functional test')
    if not ok then error(('addItem %d %s failed: %s'):format(amount, item, tostring(err)), 0) end
end)
K.step('the inventory should refuse to give me {int} {string} with {string}', 'server', function(ctx, amount, item, reason)
    forget(ctx, item, amount)
    local ok, err = K.export(INV, 'addItem', ctx.tester, item, amount, nil, nil, 'functional test')
    refused(('addItem %d %s'):format(amount, item), ok, err, reason)
end)
K.step('the inventory takes {int} {string} from me', 'server', function(ctx, amount, item)
    local ok, err = K.export(INV, 'removeItem', ctx.tester, item, amount, nil, 'functional test')
    if not ok then error(('removeItem %d %s failed: %s'):format(amount, item, tostring(err)), 0) end
end)
K.step('the inventory takes {int} {string} from the slot holding it', 'server', function(ctx, amount, item)
    local slot = slotOf(ctx, item)
    local ok, err = K.export(INV, 'removeItem', ctx.tester, item, amount, slot, 'functional test')
    if not ok then error(('removeItem %d %s from slot %d failed: %s'):format(amount, item, slot, tostring(err)), 0) end
end)
K.step('the inventory should refuse to take {int} {string} from me with {string}', 'server', function(ctx, amount, item, reason)
    local ok, err = K.export(INV, 'removeItem', ctx.tester, item, amount, nil, 'functional test')
    refused(('removeItem %d %s'):format(amount, item), ok, err, reason)
end)
K.step('the inventory should refuse to take {int} {string} from the slot holding {string} with {string}', 'server', function(ctx, amount, item, other, reason)
    local slot = slotOf(ctx, other)
    local ok, err = K.export(INV, 'removeItem', ctx.tester, item, amount, slot, 'functional test')
    refused(('removeItem %d %s from the %s slot'):format(amount, item, other), ok, err, reason)
end)

-- ---------------------------------------------------------------------------
-- Lookups: getItemCount, getItemByName, getItemsByName, getItemBySlot, hasItem
-- ---------------------------------------------------------------------------

K.step('the inventory should count {int} {string} on me', 'server', function(ctx, amount, item)
    ctx:equal(K.export(INV, 'getItemCount', ctx.tester, item), amount, 'getItemCount ' .. item)
end)
K.step('the inventory should count {int} across {string} and {string}', 'server', function(ctx, amount, first, second)
    ctx:equal(K.export(INV, 'getItemCount', ctx.tester, { first, second }), amount,
        ('getItemCount { %s, %s }'):format(first, second))
end)
K.step('the inventory should find {int} {string} by name and by slot', 'server', function(ctx, amount, item)
    local slot, record = slotOf(ctx, item)
    ctx:equal(record.name, item, 'getItemByName name')
    ctx:equal(record.amount, amount, 'getItemByName amount')
    local bySlot = K.export(INV, 'getItemBySlot', ctx.tester, slot)
    assert(type(bySlot) == 'table', ('getItemBySlot %d returned nothing'):format(slot))
    ctx:equal(bySlot.name, item, 'getItemBySlot name')
    ctx:equal(bySlot.amount, amount, 'getItemBySlot amount')
    local all = K.export(INV, 'getItemsByName', ctx.tester, item)
    assert(type(all) == 'table', 'getItemsByName did not return a table')
    local total = 0
    for _, entry in pairs(all) do
        ctx:equal(entry.name, item, 'getItemsByName entry name')
        total = total + (tonumber(entry.amount) or 0)
    end
    ctx:equal(total, amount, 'getItemsByName total')
end)
K.step('the inventory should find {string} when asked for {string}', 'server', function(ctx, item, spelling)
    local record = K.export(INV, 'getItemByName', ctx.tester, spelling)
    assert(type(record) == 'table', ('getItemByName %s returned nothing'):format(spelling))
    ctx:equal(record.name, item, 'getItemByName name')
end)
K.step('the inventory should find no {string} by name', 'server', function(ctx, item)
    ctx:equal(K.export(INV, 'getItemByName', ctx.tester, item), nil, 'getItemByName ' .. item)
    local all = K.export(INV, 'getItemsByName', ctx.tester, item)
    ctx:equal(type(all) == 'table' and next(all) == nil, true, 'getItemsByName is an empty table')
    ctx:equal(K.export(INV, 'getItemCount', ctx.tester, item), 0, 'getItemCount ' .. item)
end)

K.step('the inventory should confirm I have {int} {string}', 'server', function(ctx, amount, item)
    ctx:equal(K.export(INV, 'hasItem', ctx.tester, item, amount), true, ('hasItem %s x%d'):format(item, amount))
end)
K.step('the inventory should deny I have {int} {string}', 'server', function(ctx, amount, item)
    ctx:equal(K.export(INV, 'hasItem', ctx.tester, item, amount), false, ('hasItem %s x%d'):format(item, amount))
end)
-- Doc string: a JSON array of names, or a JSON object of name -> count.
K.step('the inventory should confirm I have everything in:', 'server', function(ctx, argument)
    ctx:equal(K.export(INV, 'hasItem', ctx.tester, K.json(argument)), true, 'hasItem with a table')
end)
K.step('the inventory should deny I have everything in:', 'server', function(ctx, argument)
    ctx:equal(K.export(INV, 'hasItem', ctx.tester, K.json(argument)), false, 'hasItem with a table')
end)
K.step('the inventory should confirm I have {int} of everything in:', 'server', function(ctx, amount, argument)
    ctx:equal(K.export(INV, 'hasItem', ctx.tester, K.json(argument), amount), true, 'hasItem with a list and an amount')
end)
K.step('the inventory should deny I have {int} of everything in:', 'server', function(ctx, amount, argument)
    ctx:equal(K.export(INV, 'hasItem', ctx.tester, K.json(argument), amount), false, 'hasItem with a list and an amount')
end)

-- ---------------------------------------------------------------------------
-- Weight and capacity: getWeight, canCarry, getFreeSlot
-- ---------------------------------------------------------------------------

K.step('I remember my inventory weight', 'server', function(ctx)
    local weight = K.export(INV, 'getWeight', ctx.tester)
    assert(type(weight) == 'number', 'getWeight did not return a number')
    ctx.state.inventoryWeight = weight
end)
K.step('my inventory weight should have increased by {int}', 'server', function(ctx, amount)
    local before = assert(ctx.state.inventoryWeight, 'Remember the inventory weight first')
    ctx:equal(K.export(INV, 'getWeight', ctx.tester) - before, amount, 'inventory weight change')
end)
K.step('my inventory weight limit should be {int}', 'server', function(ctx, limit)
    local _, max = K.export(INV, 'getWeight', ctx.tester)
    ctx:equal(max, limit, 'getWeight maximum')
end)
K.step('the inventory should say I can carry {int} {string}', 'server', function(ctx, amount, item)
    local ok, err = K.export(INV, 'canCarry', ctx.tester, item, amount)
    if not ok then error(('canCarry %d %s was refused: %s'):format(amount, item, tostring(err)), 0) end
end)
K.step('the inventory should say I cannot carry {int} {string} because {string}', 'server', function(ctx, amount, item, reason)
    local ok, err = K.export(INV, 'canCarry', ctx.tester, item, amount)
    refused(('canCarry %d %s'):format(amount, item), ok, err, reason)
end)
K.step('the inventory free slot should be an empty slot', 'server', function(ctx)
    local slot = freeSlot(ctx)
    ctx:equal(K.export(INV, 'getItemBySlot', ctx.tester, slot), nil, ('contents of free slot %d'):format(slot))
end)

-- ---------------------------------------------------------------------------
-- moveItem
-- ---------------------------------------------------------------------------

K.step('the inventory moves my {string} to a free slot', 'server', function(ctx, item)
    local from, to = slotOf(ctx, item), freeSlot(ctx)
    local ok, err = K.export(INV, 'moveItem', ctx.tester, from, to)
    if not ok then error(('moveItem %d -> %d failed: %s'):format(from, to, tostring(err)), 0) end
    ctx.state.moved = { item = item, from = from, to = to }
end)
K.step('my {string} should now sit in the slot it was moved to', 'server', function(ctx, item)
    local moved = assert(ctx.state.moved, 'Move an item first')
    ctx:equal(moved.item, item, 'moved item')
    local record = K.export(INV, 'getItemBySlot', ctx.tester, moved.to)
    assert(type(record) == 'table', ('Slot %d is empty after the move'):format(moved.to))
    ctx:equal(record.name, item, 'item in the destination slot')
    ctx:equal(K.export(INV, 'getItemBySlot', ctx.tester, moved.from), nil, 'contents of the source slot')
end)
K.step('the inventory should refuse to move an empty slot with {string}', 'server', function(ctx, reason)
    local from = freeSlot(ctx)
    local ok, err = K.export(INV, 'moveItem', ctx.tester, from, from == 1 and 2 or 1)
    refused(('moveItem from empty slot %d'):format(from), ok, err, reason)
end)
K.step('the inventory should refuse to move my {string} to slot {int} with {string}', 'server', function(ctx, item, to, reason)
    local from = slotOf(ctx, item)
    local ok, err = K.export(INV, 'moveItem', ctx.tester, from, to)
    refused(('moveItem %d -> %d'):format(from, to), ok, err, reason)
    ctx:equal(slotOf(ctx, item), from, item .. ' slot after the refused move')
end)
K.step('the inventory should refuse to move {int} of my {string} to a free slot with {string}', 'server', function(ctx, amount, item, reason)
    local from, to = slotOf(ctx, item), freeSlot(ctx)
    local ok, err = K.export(INV, 'moveItem', ctx.tester, from, to, amount)
    refused(('moveItem %d -> %d x%d'):format(from, to, amount), ok, err, reason)
    ctx:equal(K.export(INV, 'getItemBySlot', ctx.tester, to), nil, 'contents of the destination slot')
end)
K.step('the inventory should refuse to move my {string} onto my {string} with {string}', 'server', function(ctx, item, other, reason)
    local from, to = slotOf(ctx, item), slotOf(ctx, other)
    local ok, err = K.export(INV, 'moveItem', ctx.tester, from, to)
    refused(('moveItem %s onto %s'):format(item, other), ok, err, reason)
    ctx:equal(slotOf(ctx, item), from, item .. ' slot after the refused move')
    ctx:equal(slotOf(ctx, other), to, other .. ' slot after the refused move')
end)

-- ---------------------------------------------------------------------------
-- Client: HasItem export, session exports, inventory / closeInv commands
-- ---------------------------------------------------------------------------

K.step('my client inventory should report I have {int} {string}', 'client', function(ctx, amount, item)
    ctx:waitUntil(function() return K.export(INV, 'HasItem', item, amount) == true end,
        ('Client HasItem never reported %d %s'):format(amount, item), 5000)
end)
K.step('my client inventory should report I lack {int} {string}', 'client', function(ctx, amount, item)
    ctx:waitUntil(function() return K.export(INV, 'HasItem', item, amount) == false end,
        ('Client HasItem kept reporting %d %s'):format(amount, item), 5000)
end)
K.step('my client inventory should report I have everything in:', 'client', function(ctx, argument)
    local wanted = K.json(argument)
    ctx:waitUntil(function() return K.export(INV, 'HasItem', wanted) == true end,
        'Client HasItem never confirmed the table', 5000)
end)
K.step('my client inventory should report I lack something in:', 'client', function(ctx, argument)
    local wanted = K.json(argument)
    ctx:waitUntil(function() return K.export(INV, 'HasItem', wanted) == false end,
        'Client HasItem kept confirming the table', 5000)
end)

local function closeScreen()
    pcall(function() exports.kora_inventory:closeInventory() end)
end

K.step('my inventory screen should open on my own inventory', 'client', function(ctx)
    ctx:cleanup(closeScreen)
    local session = ctx:waitUntil(function() return K.export(INV, 'getCurrentSession') end,
        'No inventory session opened', 5000)
    assert(type(session.token) == 'string' and session.token ~= '', 'The session has no token')
    assert(type(session.primary) == 'table', 'The session has no primary inventory')
    ctx:equal(session.secondary, nil, 'session secondary inventory')
end)
K.step('my inventory screen should open on a shop', 'client', function(ctx)
    ctx:cleanup(closeScreen)
    ctx:waitUntil(function()
        local session = K.export(INV, 'getCurrentSession')
        return session and type(session.secondary) == 'table' and session.secondary.type == 'shop'
    end, 'No shop session opened', 5000)
end)
K.step('my inventory screen should be closed', 'client', function(ctx)
    ctx:waitUntil(function() return K.export(INV, 'getCurrentSession') == nil end,
        'The inventory session is still open', 5000)
end)
K.step('my inventory screen should stay closed', 'client', function(ctx)
    ctx:cleanup(closeScreen)
    local deadline = GetGameTimer() + 1500
    while GetGameTimer() < deadline do
        ctx:check()
        if K.export(INV, 'getCurrentSession') ~= nil then error('An inventory session opened', 0) end
        Wait(100)
    end
end)
K.step('I ask to open the inventory shop {string}', 'client', function(ctx, shopId)
    ctx:cleanup(closeScreen)
    K.export(INV, 'openInventory', 'shop', shopId)
end)

-- ---------------------------------------------------------------------------
-- Shops: shopGet, BuyItem, purchase receipts
-- ---------------------------------------------------------------------------

K.step('the inventory shop {string} should stock {string} priced at {int}', 'server', function(ctx, shopId, item, price)
    local stock, err = K.export(INV, 'shopGet', shopId)
    if type(stock) ~= 'table' then error(('shopGet %s failed: %s'):format(shopId, tostring(err)), 0) end
    for _, entry in pairs(stock) do
        if type(entry) == 'table' and entry.name == item then
            ctx:equal(tonumber(entry.price), price, item .. ' price')
            assert((tonumber(entry.amount) or 0) >= 1, item .. ' is sold out')
            return
        end
    end
    error(('Shop %s does not stock %s (sold out?)'):format(shopId, item), 0)
end)
K.step('the inventory should know no shop called {string}', 'server', function(ctx, shopId)
    local stock, err = K.export(INV, 'shopGet', shopId)
    assert(not stock, 'shopGet returned stock for an unknown shop')
    ctx:equal(err, 'shop not found', 'shopGet reason')
end)
K.step('the inventory should refuse to sell me slot {int} of shop {string} with {string}', 'server', function(ctx, slot, shopId, reason)
    local tester = ctx.tester
    -- BuyItem opens the shop session before it checks stock and funds.
    ctx:cleanup(function() pcall(function() exports.kora_inventory:CloseInventory(tester) end) end)
    local ok, err = K.export(INV, 'BuyItem', tester, shopId, slot, 1)
    refused(('BuyItem %s slot %d'):format(shopId, slot), ok, err, reason)
end)

K.step('inventory purchase receipts are being recorded', 'server', function(ctx)
    local tester = ctx.tester
    K.capture(ctx, PURCHASED, function(src) return src == tester end)
end)
K.step('an inventory purchase receipt should record {int} {string} from {string} for {int}', 'server', function(ctx, count, item, shopId, price)
    local receipts = K.captured(ctx, PURCHASED)
    ctx:waitUntil(function() return #receipts > 0 end, 'No purchase receipt arrived', 5000)
    Wait(300) -- a duplicate purchase would land here
    ctx:equal(#receipts, 1, 'purchase receipts')
    local data = receipts[1][2]
    assert(type(data) == 'table', 'The receipt carries no data')
    ctx:equal(tostring(data.shopId), shopId, 'receipt shopId')
    ctx:equal(data.itemName, item, 'receipt itemName')
    ctx:equal(data.count, count, 'receipt count')
    ctx:equal(data.price, price, 'receipt price')
end)
K.step('no inventory purchase receipt should exist', 'server', function(ctx)
    assert(ctx.state.captured and ctx.state.captured[PURCHASED], 'Start recording purchase receipts first')
    Wait(1500)
    ctx:equal(#K.captured(ctx, PURCHASED), 0, 'purchase receipts')
end)

-- Drags once and does not insist on the browser's answer: the hook reply only
-- says what the page did. The refusal itself is asserted server-side by the
-- receipt, item and balance steps that follow.
K.step('I try to drag {string} out of the shop', 'client', function(ctx, item)
    ctx:waitUntil(function()
        local _, err = K.hook(INV, 'dragBuy', item, 1)
        if err and tostring(err):find('No active shop session', 1, true) then return false end
        return true
    end, 'Shop UI did not become ready for dragging ' .. item, 5000)
end)

-- ===========================================================================
-- Deeper coverage. Line references are to kora_inventory/server.lua unless a
-- file is named.
-- ===========================================================================

-- Every slot currently holding `item`, sorted (getItemsByName, server.lua:2618).
local function slotsOf(ctx, item)
    local all = K.export(INV, 'getItemsByName', ctx.tester, item)
    assert(type(all) == 'table', 'getItemsByName did not return a table')
    local slots = {}
    for _, entry in pairs(all) do slots[#slots + 1] = entry end
    table.sort(slots, function(a, b) return a.slot < b.slot end)
    return slots
end

-- ---------------------------------------------------------------------------
-- addItem: amounts and explicit slots (addItem 2514, addPlayer 826,
-- inventory.amount shared.lua:132, inventory.validSlot shared.lua:110)
-- ---------------------------------------------------------------------------

K.step('the inventory gives me one {string} without saying how many', 'server', function(ctx, item)
    forget(ctx, item, 1)
    local ok, err = K.export(INV, 'addItem', ctx.tester, item, nil, nil, nil, 'functional test')
    if not ok then error(('addItem %s without an amount failed: %s'):format(item, tostring(err)), 0) end
end)
K.step('the inventory gives me {float} {string} as a fractional amount', 'server', function(ctx, amount, item)
    forget(ctx, item, math.ceil(amount))
    local ok, err = K.export(INV, 'addItem', ctx.tester, item, amount, nil, nil, 'functional test')
    if not ok then error(('addItem %s %s failed: %s'):format(tostring(amount), item, tostring(err)), 0) end
end)
-- addItem turns a non-positive amount into nil (2515) but canCarry then
-- defaults nil back to 1 (2477, 2522), so no refusal reason is asserted here.
K.step('the inventory should refuse to give me {int} {string} for any reason', 'server', function(ctx, amount, item)
    forget(ctx, item, 1)
    local ok, err = K.export(INV, 'addItem', ctx.tester, item, amount, nil, nil, 'functional test')
    if ok then error(('kora_inventory accepted addItem %d %s'):format(amount, item), 0) end
    assert(err ~= nil, 'addItem refused without a reason')
end)
K.step('the inventory gives me {int} {string} into the first free slot', 'server', function(ctx, amount, item)
    local slot = freeSlot(ctx)
    forget(ctx, item, amount)
    local ok, err = K.export(INV, 'addItem', ctx.tester, item, amount, slot, nil, 'functional test')
    if not ok then error(('addItem %d %s into slot %d failed: %s'):format(amount, item, slot, tostring(err)), 0) end
    ctx.state.placed = { item = item, slot = slot }
end)
K.step('my {string} should sit in the slot it was given into', 'server', function(ctx, item)
    local placed = assert(ctx.state.placed, 'Give an item into a slot first')
    ctx:equal(placed.item, item, 'placed item')
    local record = K.export(INV, 'getItemBySlot', ctx.tester, placed.slot)
    assert(type(record) == 'table', ('Slot %d is empty'):format(placed.slot))
    ctx:equal(record.name, item, ('item in slot %d'):format(placed.slot))
end)
K.step('the inventory should refuse to give me {int} {string} into slot {int} with {string}', 'server', function(ctx, amount, item, slot, reason)
    forget(ctx, item, amount)
    local ok, err = K.export(INV, 'addItem', ctx.tester, item, amount, slot, nil, 'functional test')
    refused(('addItem %d %s into slot %d'):format(amount, item, slot), ok, err, reason)
end)
K.step('the inventory should refuse to give me {int} {string} into the slot holding {string} with {string}', 'server', function(ctx, amount, item, other, reason)
    local slot = slotOf(ctx, other)
    forget(ctx, item, amount)
    local ok, err = K.export(INV, 'addItem', ctx.tester, item, amount, slot, nil, 'functional test')
    refused(('addItem %d %s into the %s slot'):format(amount, item, other), ok, err, reason)
end)
K.step('the inventory gives me {int} more {string} into the slot holding it', 'server', function(ctx, amount, item)
    local slot = slotOf(ctx, item)
    forget(ctx, item, amount)
    local ok, err = K.export(INV, 'addItem', ctx.tester, item, amount, slot, nil, 'functional test')
    if not ok then error(('addItem %d %s into slot %d failed: %s'):format(amount, item, slot, tostring(err)), 0) end
end)
K.step('the inventory should find {int} {string} in slot {int}', 'server', function(ctx, amount, item, slot)
    local record = K.export(INV, 'getItemBySlot', ctx.tester, slot)
    assert(type(record) == 'table', ('Slot %d is empty'):format(slot))
    ctx:equal(record.name, item, ('item in slot %d'):format(slot))
    ctx:equal(record.amount, amount, ('amount in slot %d'):format(slot))
end)
K.step('the inventory slot {int} should hold nothing of mine', 'server', function(ctx, slot)
    ctx:equal(K.export(INV, 'getItemBySlot', ctx.tester, slot), nil, ('getItemBySlot %d'):format(slot))
end)

-- ---------------------------------------------------------------------------
-- Stacking, unique items and weapons (addPlayer 856-907, itemDef 45-59 for
-- config.stackableWeapons, crafting.lua:375 prepareMetadata)
-- ---------------------------------------------------------------------------

K.step('the inventory should keep all my {string} in one slot', 'server', function(ctx, item)
    ctx:equal(#slotsOf(ctx, item), 1, item .. ' stacks')
end)
K.step('the inventory should keep my {string} in {int} separate slots of one each', 'server', function(ctx, item, count)
    local slots = slotsOf(ctx, item)
    ctx:equal(#slots, count, item .. ' slots')
    for _, entry in ipairs(slots) do
        ctx:equal(entry.amount, 1, ('%s amount in slot %d'):format(item, entry.slot))
    end
end)
K.step('every {string} I hold should carry its own weapon serial', 'server', function(ctx, item)
    local seen = {}
    local slots = slotsOf(ctx, item)
    assert(#slots > 0, 'The tester holds no ' .. item)
    for _, entry in ipairs(slots) do
        local info = type(entry.info) == 'table' and entry.info or entry.metadata
        local serial = type(info) == 'table' and info.serial
        assert(type(serial) == 'string' and serial ~= '', ('%s in slot %d has no serial'):format(item, entry.slot))
        assert(not seen[serial], ('Serial %s is used twice'):format(serial))
        seen[serial] = true
    end
end)

-- ---------------------------------------------------------------------------
-- removeItem through a slot and across stacks (removeItem 2547-2596)
-- ---------------------------------------------------------------------------

K.step('the inventory should refuse to take {int} {string} from the slot holding it with {string}', 'server', function(ctx, amount, item, reason)
    local slot = slotOf(ctx, item)
    local ok, err = K.export(INV, 'removeItem', ctx.tester, item, amount, slot, 'functional test')
    refused(('removeItem %d %s from slot %d'):format(amount, item, slot), ok, err, reason)
end)

-- ---------------------------------------------------------------------------
-- moveItem: split, merge, same slot, explicit slot, unique (moveItem 2694)
-- ---------------------------------------------------------------------------

K.step('the inventory splits {int} of my {string} into a free slot', 'server', function(ctx, amount, item)
    local from, to = slotOf(ctx, item), freeSlot(ctx)
    local ok, err = K.export(INV, 'moveItem', ctx.tester, from, to, amount)
    if not ok then error(('moveItem %d -> %d x%d failed: %s'):format(from, to, amount, tostring(err)), 0) end
    ctx.state.split = { item = item, from = from, to = to }
end)
K.step('my split {string} should hold {int} in the new slot and {int} in the old one', 'server', function(ctx, item, moved, left)
    local split = assert(ctx.state.split, 'Split a stack first')
    ctx:equal(split.item, item, 'split item')
    local new, old = K.export(INV, 'getItemBySlot', ctx.tester, split.to), K.export(INV, 'getItemBySlot', ctx.tester, split.from)
    assert(type(new) == 'table' and type(old) == 'table', 'A slot of the split is empty')
    ctx:equal(new.name, item, 'item in the new slot')
    ctx:equal(new.amount, moved, 'amount in the new slot')
    ctx:equal(old.name, item, 'item in the old slot')
    ctx:equal(old.amount, left, 'amount in the old slot')
end)
K.step('the inventory merges my split {string} back onto its original stack', 'server', function(ctx, item)
    local split = assert(ctx.state.split, 'Split a stack first')
    ctx:equal(split.item, item, 'split item')
    local ok, err = K.export(INV, 'moveItem', ctx.tester, split.to, split.from)
    if not ok then error(('moveItem %d -> %d failed: %s'):format(split.to, split.from, tostring(err)), 0) end
end)
K.step('the inventory should accept moving my {string} onto its own slot', 'server', function(ctx, item)
    local slot = slotOf(ctx, item)
    local ok, err = K.export(INV, 'moveItem', ctx.tester, slot, slot)
    if not ok then error(('moveItem %d -> %d was refused: %s'):format(slot, slot, tostring(err)), 0) end
    ctx:equal(slotOf(ctx, item), slot, item .. ' slot after the no-op move')
end)
K.step('the inventory moves my {string} to slot {int}', 'server', function(ctx, item, to)
    local from = slotOf(ctx, item)
    local ok, err = K.export(INV, 'moveItem', ctx.tester, from, to)
    if not ok then error(('moveItem %d -> %d failed: %s'):format(from, to, tostring(err)), 0) end
end)
K.step('the inventory should refuse to move one {string} onto another with {string}', 'server', function(ctx, item, reason)
    local slots = slotsOf(ctx, item)
    assert(#slots >= 2, 'Hold at least two separate ' .. item .. ' first')
    local from, to = slots[1].slot, slots[2].slot
    local ok, err = K.export(INV, 'moveItem', ctx.tester, from, to)
    refused(('moveItem %s %d onto %d'):format(item, from, to), ok, err, reason)
    ctx:equal(#slotsOf(ctx, item), #slots, item .. ' slots after the refused move')
end)

-- ---------------------------------------------------------------------------
-- Lookups and the qb-style aliases (api table 4202-4291)
-- ---------------------------------------------------------------------------

K.step('the inventory should count 0 for a numeric item name', 'server', function(ctx)
    -- getItemCount returns 0 for anything but a string or table (2650-2652).
    ctx:equal(K.export(INV, 'getItemCount', ctx.tester, 42), 0, 'getItemCount 42')
end)
K.step('my free inventory weight should be my weight limit minus my weight', 'server', function(ctx)
    local weight, max = K.export(INV, 'getWeight', ctx.tester)
    ctx:equal(K.export(INV, 'getFreeWeight', ctx.tester), max - weight, 'getFreeWeight')
    ctx:equal(K.export(INV, 'GetFreeWeight', ctx.tester), max - weight, 'GetFreeWeight')
end)
K.step('the qb-style inventory exports should agree I hold {int} {string}', 'server', function(ctx, amount, item)
    local tester = ctx.tester
    ctx:equal(K.export(INV, 'GetItemCount', tester, item), amount, 'GetItemCount')
    ctx:equal(K.export(INV, 'HasItem', tester, item, amount), true, 'HasItem')
    ctx:equal(K.export(INV, 'HasItem', tester, item, amount + 1), false, 'HasItem one more')
    local byName = K.export(INV, 'GetItemByName', tester, item)
    assert(type(byName) == 'table' and byName.name == item, 'GetItemByName found no ' .. item)
    local bySlot = K.export(INV, 'GetItemBySlot', tester, byName.slot)
    assert(type(bySlot) == 'table' and bySlot.name == item, 'GetItemBySlot disagrees with GetItemByName')
    ctx:equal(#K.export(INV, 'GetItemsByName', tester, item), #slotsOf(ctx, item), 'GetItemsByName entries')
    local okCarry, carryErr = K.export(INV, 'CanAddItem', tester, item, 1)
    if not okCarry then error('CanAddItem refused one more: ' .. tostring(carryErr), 0) end
    local held = 0
    for _, entry in pairs(K.export(INV, 'GetInventory', tester) or {}) do
        if entry.name == item then held = held + entry.amount end
    end
    ctx:equal(held, amount, 'GetInventory ' .. item)
    ctx:equal(type(K.export(INV, 'GetFreeSlot', tester)), 'number', 'GetFreeSlot type')
end)
K.step('the inventory gives me {int} {string} through the qb-style AddItem export', 'server', function(ctx, amount, item)
    forget(ctx, item, amount)
    local ok, err = K.export(INV, 'AddItem', ctx.tester, item, amount, nil, nil, 'functional test')
    if not ok then error(('AddItem %d %s failed: %s'):format(amount, item, tostring(err)), 0) end
end)
K.step('the inventory takes {int} {string} from me through the qb-style RemoveItem export', 'server', function(ctx, amount, item)
    local ok, err = K.export(INV, 'RemoveItem', ctx.tester, item, amount, nil, 'functional test')
    if not ok then error(('RemoveItem %d %s failed: %s'):format(amount, item, tostring(err)), 0) end
end)

-- ---------------------------------------------------------------------------
-- clearInventory (2734) and setItems (2851, replacePlayerItems 2810). The
-- runner already clears the test character's items between scenarios.
-- ---------------------------------------------------------------------------

K.step('the inventory clears my items', 'server', function(ctx)
    local ok, err = K.export(INV, 'clearInventory', ctx.tester)
    if not ok then error('clearInventory failed: ' .. tostring(err), 0) end
end)
K.step('the inventory clears my items except {string}', 'server', function(ctx, keep)
    local ok, err = K.export(INV, 'clearInventory', ctx.tester, keep)
    if not ok then error('clearInventory failed: ' .. tostring(err), 0) end
end)
-- Doc string: a JSON array of names, or a JSON object of name -> true.
K.step('the inventory clears my items except everything in:', 'server', function(ctx, argument)
    local ok, err = K.export(INV, 'clearInventory', ctx.tester, K.json(argument))
    if not ok then error('clearInventory failed: ' .. tostring(err), 0) end
end)
-- Doc string: a JSON object of slot -> { "name": ..., "amount": ... }.
K.step('the inventory replaces my items with:', 'server', function(ctx, argument)
    local items = K.json(argument)
    for _, entry in pairs(items) do forget(ctx, entry.name, tonumber(entry.amount) or 1) end
    local ok, err = K.export(INV, 'setItems', ctx.tester, items)
    if not ok then error('setItems failed: ' .. tostring(err), 0) end
end)
K.step('the inventory should refuse to replace my items with {string} given:', 'server', function(ctx, reason, argument)
    local ok, err = K.export(INV, 'setItems', ctx.tester, K.json(argument))
    refused('setItems', ok, err, reason)
end)
K.step('the inventory should refuse to replace my items with something other than a table with {string}', 'server', function(ctx, reason)
    local ok, err = K.export(INV, 'setItems', ctx.tester, 'water_bottle')
    refused('setItems with a string', ok, err, reason)
end)

-- ---------------------------------------------------------------------------
-- useItem (2948) and the cuffed gate (isCuffed 79, openInventory 3407)
-- ---------------------------------------------------------------------------

K.step('the inventory should refuse to use my {string} with {string}', 'server', function(ctx, item, reason)
    local ok, err = K.export(INV, 'useItem', ctx.tester, item)
    refused('useItem ' .. item, ok, err, reason)
end)
-- kora_police writes this boolean (kora_police/server/cuff.lua:80); the
-- generic metadata step only sets integers. Restored in cleanup.
K.step('I am flagged as handcuffed for the inventory', 'server', function(ctx)
    local core, tester = exports.kora_core, ctx.tester
    local original = core:getMetaData(tester, 'ishandcuffed')
    ctx:cleanup(function() core:setMetaData(tester, 'ishandcuffed', original == true) end)
    local ok, err = core:setMetaData(tester, 'ishandcuffed', true)
    if ok == false then error('Could not set ishandcuffed: ' .. tostring(err), 0) end
end)

-- ---------------------------------------------------------------------------
-- Server-opened sessions: OpenInventory (openQbInventory 3455 routes
-- { type = ... } to openInventory), CloseInventory (3447), session events
-- (open 1584, openSelf 1601, close 1503)
-- ---------------------------------------------------------------------------

local OPENED, CLOSED = 'kora_inventory:server:sessionOpened', 'kora_inventory:server:sessionClosed'

local function closeOnServer(tester)
    return function() pcall(function() exports.kora_inventory:CloseInventory(tester) end) end
end

K.step('inventory sessions are being recorded', 'server', function(ctx)
    local tester = ctx.tester
    K.capture(ctx, OPENED, function(src) return src == tester end)
    K.capture(ctx, CLOSED, function(src) return src == tester end)
end)
K.step('the server opens my own inventory', 'server', function(ctx)
    ctx:cleanup(closeOnServer(ctx.tester))
    local ok, payload = K.export(INV, 'OpenInventory', ctx.tester, nil, { type = 'player' })
    if not ok then error('OpenInventory player failed: ' .. tostring(payload), 0) end
    assert(type(payload) == 'table' and type(payload.token) == 'string', 'OpenInventory returned no session')
    ctx:equal(payload.secondary, nil, 'own-inventory session secondary')
end)
K.step('the server should refuse to open my own inventory with {string}', 'server', function(ctx, reason)
    ctx:cleanup(closeOnServer(ctx.tester))
    local ok, err = K.export(INV, 'OpenInventory', ctx.tester, nil, { type = 'player' })
    refused('OpenInventory player', ok, err, reason)
end)
K.step('the server opens the inventory shop {string}', 'server', function(ctx, shopId)
    ctx:cleanup(closeOnServer(ctx.tester))
    local ok, payload = K.export(INV, 'OpenInventory', ctx.tester, nil, { type = 'shop', id = shopId })
    if not ok then error(('OpenInventory shop %s failed: %s'):format(shopId, tostring(payload)), 0) end
    assert(type(payload) == 'table' and type(payload.secondary) == 'table', 'The shop session has no secondary inventory')
    ctx:equal(payload.secondary.type, 'shop', 'session secondary type')
    ctx:equal(tostring(payload.secondary.id), shopId, 'session secondary id')
end)
K.step('the server should refuse to open the inventory shop {string} with {string}', 'server', function(ctx, shopId, reason)
    ctx:cleanup(closeOnServer(ctx.tester))
    local ok, err = K.export(INV, 'OpenInventory', ctx.tester, nil, { type = 'shop', id = shopId })
    refused('OpenInventory shop ' .. shopId, ok, err, reason)
end)
K.step('the server closes my inventory', 'server', function(ctx)
    ctx:equal(K.export(INV, 'CloseInventory', ctx.tester), true, 'CloseInventory result')
end)
K.step('the server should find no inventory of mine to close', 'server', function(ctx)
    ctx:equal(K.export(INV, 'CloseInventory', ctx.tester), false, 'CloseInventory result')
end)
K.step('an inventory session should have opened on my own inventory', 'server', function(ctx)
    local opened = K.captured(ctx, OPENED)
    ctx:waitUntil(function() return #opened > 0 end, 'No inventory session opened', 5000)
    local payload = opened[#opened][2]
    assert(type(payload) == 'table' and type(payload.primary) == 'table', 'The session event carries no primary inventory')
    ctx:equal(payload.primary.key, ('player:%s'):format(ctx.tester), 'session primary key')
    ctx:equal(payload.secondary, nil, 'session secondary')
end)
K.step('an inventory session should have closed because {string}', 'server', function(ctx, reason)
    local closed = K.captured(ctx, CLOSED)
    ctx:waitUntil(function()
        for _, record in ipairs(closed) do if record[3] == reason then return true end end
        return false
    end, 'No inventory session closed with ' .. reason, 5000)
end)
K.step('no inventory session should have opened', 'server', function(ctx)
    assert(ctx.state.captured and ctx.state.captured[OPENED], 'Start recording inventory sessions first')
    Wait(500)
    ctx:equal(#K.captured(ctx, OPENED), 0, 'inventory sessions opened')
end)

K.step('the inventory should refuse to sell me {int} from slot {int} of shop {string} with {string}', 'server', function(ctx, count, slot, shopId, reason)
    ctx:cleanup(closeOnServer(ctx.tester))
    local ok, err = K.export(INV, 'BuyItem', ctx.tester, shopId, slot, count)
    refused(('BuyItem %s slot %d x%d'):format(shopId, slot, count), ok, err, reason)
end)

-- ---------------------------------------------------------------------------
-- Audit trail (recordAudit 188: add 2534, remove 2565/2590, move 2726)
-- ---------------------------------------------------------------------------

local AUDIT = 'kora_inventory:server:audit'

K.step('inventory audit records are being recorded', 'server', function(ctx)
    local tester = ctx.tester
    K.capture(ctx, AUDIT, function(_, src) return src == tester end)
end)
K.step('an inventory audit record {string} should name {int} {string}', 'server', function(ctx, action, amount, item)
    local records = K.captured(ctx, AUDIT)
    ctx:waitUntil(function()
        for _, record in ipairs(records) do
            local details = record[3]
            if record[1] == action and type(details) == 'table' and details.item == item and details.amount == amount then
                return true
            end
        end
        return false
    end, ('No %s audit record for %d %s'):format(action, amount, item), 5000)
end)
K.step('an inventory move audit record should name {int} moved', 'server', function(ctx, amount)
    local records = K.captured(ctx, AUDIT)
    ctx:waitUntil(function()
        for _, record in ipairs(records) do
            local details = record[3]
            if record[1] == 'move' and type(details) == 'table' and details.amount == amount
                and type(details.fromSlot) == 'number' and type(details.toSlot) == 'number' then
                return true
            end
        end
        return false
    end, 'No move audit record for ' .. amount, 5000)
end)

-- ---------------------------------------------------------------------------
-- Client: openInventory export (client.lua:210) and the session mirror
-- ---------------------------------------------------------------------------

K.step('I ask the inventory to open my own inventory', 'client', function(ctx)
    ctx:cleanup(closeScreen)
    K.export(INV, 'openInventory', 'player')
end)
K.step('my open inventory screen should list {int} {string}', 'client', function(ctx, amount, item)
    local function held()
        local session = K.export(INV, 'getCurrentSession')
        local total = 0
        if session and type(session.primary) == 'table' then
            for _, entry in pairs(session.primary.items or {}) do
                if type(entry) == 'table' and entry.name == item then total = total + (tonumber(entry.amount) or 0) end
            end
        end
        return total
    end
    ctx:waitUntil(function() return held() == amount end,
        ('The open inventory screen never listed %d %s'):format(amount, item), 5000)
end)

-- ---------------------------------------------------------------------------
-- Crafting exports (kora_inventory/server/crafting.lua): recipes, the read-only
-- checks, the craft itself, the access callback and craft hooks. Recipes and
-- hooks are owned by fft and removed in cleanup. Ingredients and outputs are the
-- real items water_bottle and coffee (kora_core shared items, not stackable
-- unique). Recipe ids start with fft_test_ so they never collide with config.
-- ---------------------------------------------------------------------------

local CRAFTED = 'kora_inventory:server:crafted'

local function yes(word)
    assert(word == 'true' or word == 'false', 'Use true or false')
    return word == 'true'
end

local function recipeTable(id, ingredient, amount, output, outAmount, access)
    return {
        ingredients = { { name = ingredient, amount = amount } },
        outputs = { { name = output, amount = outAmount } },
        access = access,
    }
end

local function forgetRecipe(ctx, id)
    ctx:cleanup(function() exports.kora_inventory:RemoveCraftRecipe(id) end)
end

local function registerRecipe(ctx, id, ingredient, amount, output, outAmount, access)
    K.started(INV)
    forgetRecipe(ctx, id)
    local ok, err = K.export(INV, 'RegisterCraftRecipe', id, recipeTable(id, ingredient, amount, output, outAmount, access))
    ctx:equal(ok, true, 'RegisterCraftRecipe ' .. id .. ' (' .. tostring(err) .. ')')
end

K.step('I register the craft recipe {string} turning {int} {string} into {int} {string}', 'server',
    function(ctx, id, amount, ingredient, outAmount, output)
        registerRecipe(ctx, id, ingredient, amount, output, outAmount, nil)
    end)

K.step('I register the craft recipe {string} turning {int} {string} into {int} {string} gated by an access check that refuses with {string}', 'server',
    function(ctx, id, amount, ingredient, outAmount, output, reason)
        registerRecipe(ctx, id, ingredient, amount, output, outAmount, function() return false, reason end)
    end)

K.step('I register the craft recipe {string} turning {int} {string} into {int} {string} gated by an access check that errors', 'server',
    function(ctx, id, amount, ingredient, outAmount, output)
        registerRecipe(ctx, id, ingredient, amount, output, outAmount, function() error('deliberate access fault from the FFT suite', 0) end)
    end)

K.step('registering craft recipe {string} from {string} into {string} should be refused with {string}', 'server',
    function(ctx, id, ingredient, output, reason)
        K.started(INV)
        forgetRecipe(ctx, id)
        local ok, err = K.export(INV, 'RegisterCraftRecipe', id, recipeTable(id, ingredient, 1, output, 1, nil))
        ctx:equal(ok, false, 'RegisterCraftRecipe accepted ' .. id)
        ctx:equal(err, reason, 'RegisterCraftRecipe reason')
    end)

-- The id rule is `1..96` characters of letters, digits, `_`, `.` and `-`.
K.step('a craft recipe id of {int} characters should be {word}', 'server', function(ctx, length, expected)
    K.started(INV)
    local id = string.rep('r', length)
    forgetRecipe(ctx, id)
    local ok, err = K.export(INV, 'RegisterCraftRecipe', id, recipeTable(id, 'water_bottle', 1, 'coffee', 1, nil))
    if expected == 'accepted' then
        ctx:equal(ok, true, ('RegisterCraftRecipe with %d characters (%s)'):format(length, tostring(err)))
    else
        ctx:equal(ok, false, ('RegisterCraftRecipe accepted %d characters'):format(length))
        ctx:equal(err, 'invalid recipe id', 'RegisterCraftRecipe reason')
    end
end)

K.step('the craft recipe {string} should read back {int} {string} into {int} {string}', 'server',
    function(ctx, id, amount, ingredient, outAmount, output)
        local recipe = K.export(INV, 'GetCraftRecipe', id)
        assert(type(recipe) == 'table', 'No craft recipe named ' .. id)
        ctx:equal(recipe.id, id, 'recipe id')
        ctx:equal(recipe.label, id, 'label defaults to the id')
        ctx:equal(#recipe.ingredients, 1, 'ingredient rows')
        ctx:equal(recipe.ingredients[1].name, ingredient, 'ingredient name')
        ctx:equal(recipe.ingredients[1].amount, amount, 'ingredient amount')
        ctx:equal(#recipe.outputs, 1, 'output rows')
        ctx:equal(recipe.outputs[1].name, output, 'output name')
        ctx:equal(recipe.outputs[1].amount, outAmount, 'output amount')
    end)

K.step('the craft recipe {string} should be gone', 'server', function(ctx, id)
    ctx:equal(K.export(INV, 'GetCraftRecipe', id), nil, 'GetCraftRecipe ' .. id)
end)

K.step('removing craft recipe {string} should return {word}', 'server', function(ctx, id, expected)
    ctx:equal((K.export(INV, 'RemoveCraftRecipe', id)), yes(expected), 'RemoveCraftRecipe ' .. id)
end)

local function craftFor(ctx, id, amount)
    return K.export(INV, 'CraftItem', ctx.tester, id, nil, amount)
end

K.step('crafting {string} for me should succeed', 'server', function(ctx, id)
    local ok, result = craftFor(ctx, id, nil)
    ctx:equal(ok, true, 'CraftItem ' .. id .. ' (' .. tostring(result) .. ')')
end)

K.step('crafting {string} {int} times for me should succeed', 'server', function(ctx, id, times)
    local ok, result = craftFor(ctx, id, times)
    ctx:equal(ok, true, 'CraftItem ' .. id .. ' x' .. times .. ' (' .. tostring(result) .. ')')
end)

K.step('crafting {string} for me should be refused with {string}', 'server', function(ctx, id, reason)
    local ok, err = craftFor(ctx, id, nil)
    ctx:equal(ok, false, 'CraftItem accepted ' .. id)
    ctx:equal(err, reason, 'CraftItem reason')
end)

-- The amount arrives as text, the way a client would type it.
K.step('crafting {string} with amount {string} should be refused with {string}', 'server', function(ctx, id, raw, reason)
    local ok, err = craftFor(ctx, id, tonumber(raw) or raw)
    ctx:equal(ok, false, 'CraftItem accepted amount ' .. raw)
    ctx:equal(err, reason, 'CraftItem reason for amount ' .. raw)
end)

K.step('I watch for crafting completions', 'server', function(ctx)
    K.capture(ctx, CRAFTED, function(src) return src == ctx.tester end)
end)

K.step('a crafting completion of {string} should have been recorded for me', 'server', function(ctx, id)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, CRAFTED)) do
            if record[2] == id then return true end
        end
    end, ('%s was not reported as crafted for the tester'):format(id), 2000)
end)

-- Craft hooks run after the access check and before anything is consumed.
K.step('I register a craft hook that refuses with {string}', 'server', function(ctx, reason)
    K.started(INV)
    local id = K.export(INV, 'RegisterCraftHook', function() return false, reason end)
    ctx.state.craftHookId = id
    ctx:cleanup(function() exports.kora_inventory:RemoveCraftHook(id) end)
end)

K.step('I register a craft hook that records what it sees', 'server', function(ctx)
    K.started(INV)
    local id = K.export(INV, 'RegisterCraftHook', function(payload)
        ctx.state.craftPayload = payload
        return true
    end)
    ctx.state.craftHookId = id
    ctx:cleanup(function() exports.kora_inventory:RemoveCraftHook(id) end)
end)

K.step('the craft hook should have seen recipe {string} for {int} times for me', 'server', function(ctx, id, times)
    local seen = assert(ctx.state.craftPayload, 'The craft hook has not run')
    ctx:equal(seen.recipeId, id, 'hook recipeId')
    ctx:equal(seen.amount, times, 'hook amount')
    ctx:equal(seen.source, ctx.tester, 'hook source')
end)

K.step('removing the craft hook should return {word}', 'server', function(ctx, expected)
    local id = assert(ctx.state.craftHookId, 'No craft hook was registered in this scenario')
    ctx:equal((K.export(INV, 'RemoveCraftHook', id)), yes(expected), 'RemoveCraftHook')
end)

-- The read-only checks never run the access callback or the hooks.
K.step('the craft recipe {string} should be makeable by me {int} times', 'server', function(ctx, id, times)
    ctx:equal((K.export(INV, 'CanCraftRecipe', ctx.tester, id, times)), true, 'CanCraftRecipe ' .. id)
end)

K.step('the craft recipe {string} should not be makeable by me {int} times with {string}', 'server', function(ctx, id, times, reason)
    local ok, err = K.export(INV, 'CanCraftRecipe', ctx.tester, id, times)
    ctx:equal(ok, false, 'CanCraftRecipe accepted ' .. id)
    ctx:equal(err, reason, 'CanCraftRecipe reason')
end)

-- Trusted, ad hoc query: ingredients by name, outputs by name.
local function trustedCheck(ctx, ingredient, amount, output, outAmount)
    return K.export(INV, 'CanCraftItems', ctx.tester, { [ingredient] = amount }, { { name = output, amount = outAmount } })
end

K.step('a trusted craft check of {int} {string} into {int} {string} should pass', 'server', function(ctx, amount, ingredient, outAmount, output)
    local ok, err = trustedCheck(ctx, ingredient, amount, output, outAmount)
    ctx:equal(ok, true, 'CanCraftItems (' .. tostring(err) .. ')')
end)

K.step('a trusted craft check of {int} {string} into {int} {string} should be refused', 'server', function(ctx, amount, ingredient, outAmount, output)
    local ok = trustedCheck(ctx, ingredient, amount, output, outAmount)
    ctx:equal(ok, false, 'CanCraftItems accepted the check')
end)

-- ---------------------------------------------------------------------------
-- Coverage expansion: persistence status, weapon state reads, carried and
-- equipped weapons, and refusals of the provider-only exchange, stash
-- recovery and legacy police-trash bridges. Reads only; every refusal
-- returns before any lock or SQL write.
-- ---------------------------------------------------------------------------

local function slotOf(ctx, item)
    for slot, entry in pairs(K.player(ctx).items or {}) do
        if type(entry) == 'table' and entry.name == item then return tonumber(slot) or slot end
    end
end

-- getPersistenceStatus (server.lua:3924-3934).
K.step('the kora_inventory persistence status should be consistent', 'server', function(ctx)
    local status = K.export(INV, 'getPersistenceStatus')
    assert(type(status) == 'table', 'getPersistenceStatus did not return a table')
    ctx:equal(type(status.enabled), 'boolean', 'status.enabled type')
    ctx:equal(type(status.schemaReady), 'boolean', 'status.schemaReady type')
    ctx:equal(type(status.ready), 'boolean', 'status.ready type')
    if status.ready then
        ctx:equal(status.enabled and status.schemaReady, true, 'ready implies enabled and schemaReady')
        ctx:equal(status.restoring, false, 'A ready inventory is not restoring')
    end
    if not status.enabled then ctx:equal(status.ready, false, 'Disabled persistence is never ready') end
end)

-- GetWeaponState(src, slot) (server/crafting.lua:768-775): a copy of a
-- weapon's metadata, nil for anything that is not a weapon.
K.step('kora_inventory should report weapon state for my {string}', 'server', function(ctx, item)
    local slot = ctx:waitUntil(function() return slotOf(ctx, item) end, 'I hold no ' .. item, 3000)
    local state = K.export(INV, 'GetWeaponState', ctx.tester, slot)
    ctx:equal(type(state), 'table', ('GetWeaponState for %s in slot %s'):format(item, tostring(slot)))
end)
K.step('kora_inventory should report no weapon state for my {string}', 'server', function(ctx, item)
    local slot = ctx:waitUntil(function() return slotOf(ctx, item) end, 'I hold no ' .. item, 3000)
    ctx:equal(K.export(INV, 'GetWeaponState', ctx.tester, slot), nil, 'GetWeaponState for ' .. item)
end)
K.step('kora_inventory should report no weapon state for an empty or invalid slot', 'server', function(ctx)
    ctx:equal(K.export(INV, 'GetWeaponState', ctx.tester, 'fft'), nil, 'GetWeaponState with a non-numeric slot')
    ctx:equal(K.export(INV, 'GetWeaponState', ctx.tester, 999), nil, 'GetWeaponState for slot 999')
end)

-- GetCarriedWeapons / GetEquippedWeapon (server/weaponcarry.lua:564-581).
K.step('kora_inventory should list only weapons as carried on my body', 'server', function(ctx)
    local carried = K.export(INV, 'GetCarriedWeapons', ctx.tester)
    assert(type(carried) == 'table', 'GetCarriedWeapons did not return a list')
    for index, entry in ipairs(carried) do
        assert(type(entry) == 'table' and type(entry.name) == 'string', ('Carried entry %d has no name'):format(index))
    end
    ctx:equal(#(K.export(INV, 'GetCarriedWeapons', 0) or {}), 0, 'GetCarriedWeapons for player 0')
end)
K.step('kora_inventory should report my equipped weapon as nothing or a held slot', 'server', function(ctx)
    local held = K.export(INV, 'GetEquippedWeapon', ctx.tester)
    if held ~= nil then
        assert(type(held) == 'table' and type(held.name) == 'string' and held.slot ~= nil,
            'GetEquippedWeapon returned a malformed record')
    end
end)

-- Provider-only bridges: fft is never an exchange caller, stash policy owner
-- or kora_sql, so each refuses before any work (exchange.lua:208-225,
-- recovery.lua:45-51, server.lua:3939-3943).
K.step('kora_inventory should refuse a player exchange from fft', 'server', function(ctx)
    local result, code = K.export(INV, 'ExecutePlayerExchange', ctx.tester, 'fft-exchange', { give = {} })
    ctx:equal(result, nil, 'ExecutePlayerExchange result')
    assert(code == nil or code == 'rejected', 'ExecutePlayerExchange code ' .. tostring(code))
    local status, statusCode = K.export(INV, 'GetPlayerExchange', 'fft-exchange')
    ctx:equal(status, nil, 'GetPlayerExchange result')
    assert(statusCode == nil or statusCode == 'rejected', 'GetPlayerExchange code ' .. tostring(statusCode))
end)
K.step('kora_inventory should refuse a stash recovery claim with invalid arguments', 'server', function(ctx)
    local ok, err = K.export(INV, 'ClaimStash', ctx.tester, 42, 'fft-operation')
    refused('a stash claim with a numeric id', ok, err, 'Invalid recovery request.')
    ok, err = K.export(INV, 'claimStash', ctx.tester, 'fft_stash', '')
    refused('a stash claim with an empty operation key', ok, err, 'Invalid recovery request.')
end)
K.step('kora_inventory should refuse a stash recovery claim for a stash fft does not own', 'server', function(ctx)
    local ok, err = K.export(INV, 'ClaimStash', ctx.tester, 'fft_never_a_stash', 'fft-operation')
    assert(not ok, 'kora_inventory accepted a recovery claim for a stash fft does not own')
    assert(err == 'Recovery is unavailable.' or err == 'Inventory persistence is unavailable.',
        'ClaimStash was refused with ' .. tostring(err))
end)
K.step('kora_inventory should refuse the legacy police trash bridge to anyone but kora_sql', 'server', function(ctx)
    local answered, result, reason = false, nil, nil
    K.export(INV, 'deleteLegacyPoliceTrash', function(value, why) answered, result, reason = true, value, why end)
    ctx:waitUntil(function() return answered end, 'deleteLegacyPoliceTrash never answered', 3000)
    ctx:equal(result, nil, 'deleteLegacyPoliceTrash result')
    ctx:equal(reason, 'legacy inventory SQL bridge is restricted to kora_sql', 'deleteLegacyPoliceTrash reason')
end)

-- ---------------------------------------------------------------------------
-- Coverage expansion: legacy qb-inventory / qb-weapons callbacks and events
-- sent the way a stock client would (server/compat/qb_callbacks.lua,
-- qb_events.lua, qb_weapons.lua). None may mint, move, repair or reload
-- anything: each is refused, answered with a safe constant, or may only lower
-- a value. Asserted against the authoritative inventory on the server.
-- ---------------------------------------------------------------------------

local function legacyInvCall(name, ...)
    local args = table.pack(...)
    local ok, packed = pcall(function()
        return exports.kora_lib:callback_triggerPacked(name, table.unpack(args, 1, args.n))
    end)
    if not ok then error(('%s raised: %s'):format(name, tostring(packed)), 0) end
    if type(packed) == 'table' and packed.__kora_lib_rejected then
        error(('%s raised: %s'):format(name, tostring(packed.error)), 0)
    end
    return type(packed) == 'table' and packed or {}
end

K.step('the retired qb-weapons callbacks should answer safely', 'client', function(ctx)
    local config = legacyInvCall('qb-weapons:server:GetConfig')[1]
    ctx:equal(type(config), 'table', 'GetConfig type')
    ctx:equal(next(config), nil, 'GetConfig is empty')
    ctx:equal(legacyInvCall('qb-weapons:server:RepairWeapon', 1)[1], false, 'RepairWeapon')
    ctx:equal(legacyInvCall('qb-weapons:server:RemoveAttachment', { slot = 1 }, 'clip_attachment')[1], false, 'RemoveAttachment')
end)
K.step('the legacy weapon ammo callback should report no weapon in slot {int}', 'client', function(ctx, slot)
    ctx:equal(legacyInvCall('weapon:server:GetWeaponAmmo', slot)[1], 0, 'GetWeaponAmmo of a non-weapon slot')
end)

-- Server realm: find the tester's slot for an item, remember its weapon state.
K.step('I remember the weapon state of my {string}', 'server', function(ctx, item)
    local slot = ctx:waitUntil(function() return slotOf(ctx, item) end, 'I hold no ' .. item, 3000)
    local state = K.export(INV, 'GetWeaponState', ctx.tester, slot) or {}
    ctx.state.weaponSlot = slot
    ctx.state.weaponBefore = { ammo = state.ammo, quality = state.quality, durability = state.durability }
    TriggerClientEvent('fft:kora_inventory:weaponSlot', ctx.tester, slot)
end)
K.step('the weapon state of my {string} should be unchanged', 'server', function(ctx, item)
    local before = assert(ctx.state.weaponBefore, 'Remember the weapon state first')
    Wait(500)
    local state = K.export(INV, 'GetWeaponState', ctx.tester, ctx.state.weaponSlot) or {}
    ctx:equal(state.ammo, before.ammo, item .. ' ammo')
    ctx:equal(state.quality, before.quality, item .. ' quality')
    ctx:equal(state.durability, before.durability, item .. ' durability')
end)
K.step('my client listens for my weapon slot', 'client', function(ctx)
    RegisterNetEvent('fft:kora_inventory:weaponSlot')
    ctx:on('fft:kora_inventory:weaponSlot', function(slot) ctx.state.weaponSlot = slot end)
end)
K.step('a stock client tries to refill, repair and reclaim my weapon', 'client', function(ctx)
    ctx:waitUntil(function() return ctx.state.weaponSlot ~= nil end, 'My weapon slot was not learnt', 3000)
    local slot = ctx.state.weaponSlot
    TriggerServerEvent('qb-weapons:server:UpdateWeaponAmmo', { slot = slot }, 9999)
    TriggerServerEvent('qb-weapons:server:SetWeaponQuality', { slot = slot }, 100)
    TriggerServerEvent('qb-weapons:server:TakeBackWeapon', { slot = slot })
    TriggerServerEvent('qb-weapons:server:UpdateWeaponQuality', { slot = slot }, -50)
    Wait(500)
end)
K.step('a stock client without an open inventory tries to drop, give and move items', 'client', function(ctx)
    local me = GetPlayerServerId(PlayerId())
    ctx:equal(legacyInvCall('qb-inventory:server:createDrop', { fromSlot = 1, amount = 1 })[1], false, 'createDrop without a session')
    ctx:equal(legacyInvCall('qb-inventory:server:giveItem', me, 'water_bottle', 1, 1)[1], false, 'giveItem without a session')
    TriggerServerEvent('qb-inventory:server:SetInventoryData', 'player', 'drop-fft', 1, 1, 1, 1)
    Wait(500)
end)
K.step('forged legacy purchases should be refused', 'client', function(ctx)
    local cases = {
        { shop = 'fft_never_a_shop', item = { slot = 1, name = 'water_bottle' }, amount = 1 },
        { shop = 'fft_never_a_shop', item = { slot = 1 }, amount = 0 },
        { shop = 'fft_never_a_shop', item = { slot = 'fft' }, amount = 1 },
        { shop = {}, item = { slot = 1 }, amount = 1 },
        'fft-not-a-table',
    }
    for index, data in ipairs(cases) do
        ctx:equal(legacyInvCall('qb-inventory:server:attemptPurchase', data)[1], false, ('attemptPurchase case %d'):format(index))
    end
end)
K.step('the legacy drop list should be readable', 'client', function(ctx)
    ctx:equal(type(legacyInvCall('qb-inventory:server:GetCurrentDrops')[1]), 'table', 'GetCurrentDrops')
end)

-- ---------------------------------------------------------------------------
-- Coverage expansion: server weapon-state exports on the tester's own weapon
-- (server/crafting.lua:375-855). The weapon is granted by the scenario and
-- removed in its cleanup, so nothing outlives the run.
-- ---------------------------------------------------------------------------

local function weaponSlot(ctx, item)
    return ctx:waitUntil(function() return slotOf(ctx, item) end, 'I hold no ' .. item, 3000)
end
local function weaponState(ctx, slot) return K.export(INV, 'GetWeaponState', ctx.tester, slot) or {} end

K.step('setting the ammo of my {string} to {int} should store {int}', 'server', function(ctx, item, ammo, expected)
    local slot = weaponSlot(ctx, item)
    local ok, err = K.export(INV, 'SetWeaponAmmo', ctx.tester, slot, ammo)
    assert(ok, 'SetWeaponAmmo refused: ' .. tostring(err))
    ctx:equal(weaponState(ctx, slot).ammo, expected, item .. ' ammo')
end)
K.step('setting the durability of my {string} to {float} should store {float}', 'server', function(ctx, item, value, expected)
    local slot = weaponSlot(ctx, item)
    local ok, err = K.export(INV, 'SetWeaponState', ctx.tester, slot, { durability = value })
    assert(ok, 'SetWeaponState refused: ' .. tostring(err))
    local stored = weaponState(ctx, slot).durability
    assert(type(stored) == 'number' and math.abs(stored - expected) < 1e-6,
        ('%s durability is %s, expected %s'):format(item, tostring(stored), tostring(expected)))
end)
K.step('wearing my {string} by {float} should leave {float} durability', 'server', function(ctx, item, amount, expected)
    local slot = weaponSlot(ctx, item)
    local ok, err = K.export(INV, 'ConsumeWeaponDurability', ctx.tester, slot, amount)
    assert(ok, 'ConsumeWeaponDurability refused: ' .. tostring(err))
    local stored = weaponState(ctx, slot).durability
    assert(type(stored) == 'number' and math.abs(stored - expected) < 1e-6,
        ('%s durability is %s, expected %s'):format(item, tostring(stored), tostring(expected)))
end)
K.step('the weapon state exports should refuse bad input for my {string}', 'server', function(ctx, item)
    local slot = weaponSlot(ctx, item)
    local function refusedWith(expected, ok, err)
        ctx:equal(ok, false, 'Weapon export result')
        ctx:equal(err, expected, 'Weapon export refusal')
    end
    refusedWith('invalid weapon state', K.export(INV, 'SetWeaponState', ctx.tester, slot, 'fft'))
    refusedWith('invalid weapon durability', K.export(INV, 'SetWeaponState', ctx.tester, slot, { durability = 'fft' }))
    refusedWith('invalid weapon ammo', K.export(INV, 'SetWeaponState', ctx.tester, slot, { ammo = 'fft' }))
    refusedWith('invalid durability amount', K.export(INV, 'ConsumeWeaponDurability', ctx.tester, slot, 0))
    refusedWith('invalid weapon slot', K.export(INV, 'SetWeaponAmmo', ctx.tester, 0, 5))
    refusedWith('invalid ammunition amount', K.export(INV, 'LoadWeaponRounds', ctx.tester, slot, 'AMMO_PISTOL', 0))
    refusedWith('ammunition does not fit this weapon', K.export(INV, 'LoadWeaponRounds', ctx.tester, slot, 'AMMO_FFT_NEVER', 5))
end)
K.step('the weapon state exports should refuse a slot that holds {string}', 'server', function(ctx, item)
    local slot = weaponSlot(ctx, item)
    local ok, err = K.export(INV, 'SetWeaponAmmo', ctx.tester, slot, 5)
    ctx:equal(ok, false, 'SetWeaponAmmo on ' .. item)
    ctx:equal(err, 'weapon not found', 'SetWeaponAmmo refusal')
end)
K.step('preparing weapon metadata for {string} should clamp durability {float} and ammo {int}', 'server',
    function(ctx, item, durability, ammo)
        local info, err = K.export(INV, 'PrepareWeaponMetadata', item, { durability = durability, ammo = ammo })
        assert(type(info) == 'table', 'PrepareWeaponMetadata refused: ' .. tostring(err))
        assert(info.durability >= 0 and info.durability <= 100, 'Durability was not clamped: ' .. tostring(info.durability))
        ctx:equal(info.quality, info.durability, 'quality mirrors durability')
    end)
K.step('preparing weapon metadata for {string} should be refused as not a weapon', 'server', function(ctx, item)
    local info, err = K.export(INV, 'PrepareWeaponMetadata', item, {})
    ctx:equal(info, nil, 'PrepareWeaponMetadata result')
    assert(err == nil or err == 'item is not a registered weapon', 'PrepareWeaponMetadata gave ' .. tostring(err))
end)
