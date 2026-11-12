-- kora_core: the modern export API in kora_core/docs.md, exercised against the
-- test character only. No resource hook: every surface here is a public export
-- or a local server event.
--
-- Deliberately out of reach of this file: addPermission/removePermission (they
-- change persistent ACE state), a successful transferMoney (needs a second
-- player), clearInventory/setItems, character creation or deletion,
-- registerPlayerDataField/createUseable success (no way to undo them while fft
-- runs), stopPaycheck/stopNeedsDecay, and dispatch alerts (kora_dispatch turns
-- every kora_core:server:dispatchAlert into a real call, kora_dispatch/server/compat.lua:58).
-- registerShared/unregisterShared are only used by the one @global scenario,
-- with a scratch fft_ key.
local K = FFT.kora
if not K then return end
K.feature('kora_core')

local CORE = 'kora_core'

-- "money.bank" -> { 'money', 'bank' }. setPath/getPlayerData/onChange take a key array.
local function keys(path)
    local out = {}
    for part in tostring(path):gmatch('[^.]+') do out[#out + 1] = part end
    return out
end

local function show(value)
    if type(value) ~= 'table' then return tostring(value) end
    local parts = {}
    for index = 1, #value do parts[index] = tostring(value[index]) end
    return table.concat(parts, '.')
end

local function refused(what, ok, err, reason)
    if ok then error(('kora_core accepted %s'):format(what), 0) end
    if err ~= reason then
        error(('%s was refused with "%s", expected "%s"'):format(what, tostring(err), reason), 0)
    end
end

-- For exports documented as `return nil, reason` (incrementMetaData, onChange,
-- onSharedChange): FiveM msgpacks export results and a leading nil drops every
-- later value, so the caller only ever sees nil. A bare nil is that refusal; a
-- reason that does arrive must still match.
local function refusedNil(what, value, err, reason)
    if value == nil and err == nil then return end
    refused(what, value, err, reason)
end

local function includes(list, value)
    for _, entry in pairs(type(list) == 'table' and list or {}) do
        if entry == value then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Money (modules/money/server.lua). Config.money.types = cash, bank, crypto;
-- only bank may go negative, down to Config.money.minusLimit (config.lua).
-- Scenarios use bank and crypto: cash may be inventory-owned physical cash.
-- ---------------------------------------------------------------------------

local function restoreBalance(ctx, account)
    local tester = ctx.tester
    local original = K.export(CORE, 'getMoney', tester, account)
    if type(original) ~= 'number' then return end
    ctx:cleanup(function() exports.kora_core:setMoney(tester, account, original, 'functional test cleanup') end)
end

K.step('the core adds {int} to my {string} account', 'server', function(ctx, amount, account)
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, 'addMoney', ctx.tester, account, amount, 'functional test')
    if not ok then error(('addMoney %s %d failed: %s'):format(account, amount, tostring(err)), 0) end
end)
K.step('the core removes {int} from my {string} account', 'server', function(ctx, amount, account)
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, 'removeMoney', ctx.tester, account, amount, 'functional test')
    if not ok then error(('removeMoney %s %d failed: %s'):format(account, amount, tostring(err)), 0) end
end)
K.step('the core should refuse to add {int} to my {string} account with {string}', 'server', function(ctx, amount, account, reason)
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, 'addMoney', ctx.tester, account, amount, 'functional test')
    refused(('addMoney %s %d'):format(account, amount), ok, err, reason)
end)
K.step('the core should refuse to remove {int} from my {string} account with {string}', 'server', function(ctx, amount, account, reason)
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, 'removeMoney', ctx.tester, account, amount, 'functional test')
    refused(('removeMoney %s %d'):format(account, amount), ok, err, reason)
end)
K.step('the core should refuse to set my {string} account to {int} with {string}', 'server', function(ctx, account, amount, reason)
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, 'setMoney', ctx.tester, account, amount, 'functional test')
    refused(('setMoney %s %d'):format(account, amount), ok, err, reason)
end)
K.step('the core should report {int} in my {string} account', 'server', function(ctx, amount, account)
    ctx:equal(K.export(CORE, 'getMoney', ctx.tester, account), amount, account .. ' balance from getMoney')
end)
K.step('the core should report no {string} account for me', 'server', function(ctx, account)
    ctx:equal(K.export(CORE, 'getMoney', ctx.tester, account), nil, account .. ' balance from getMoney')
end)
-- Needs `I remember my {string} balance` first: that step starts the capture of
-- QBCore:Server:OnMoneyChange(src, account, amount, action, reason).
K.step('the core money receipt for {string} should record {word} of {int}', 'server', function(ctx, account, action, amount)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, 'QBCore:Server:OnMoneyChange')) do
            if record[2] == account and record[4] == action and record[3] == amount then return true end
        end
    end, ('No OnMoneyChange receipt for %s %s %d'):format(account, action, amount), 3000)
end)
K.step('no core money receipt should exist for {string}', 'server', function(ctx, account)
    Wait(300)
    for _, record in ipairs(K.captured(ctx, 'QBCore:Server:OnMoneyChange')) do
        if record[2] == account then
            error(('Unexpected OnMoneyChange receipt: %s %s %s'):format(account, tostring(record[4]), tostring(record[3])), 0)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Items through the kora_core gateway (docs.md "Inventory"). Grants use the
-- generic `I hold {int} {string}` step, which calls exports.kora_core:addItem.
-- ---------------------------------------------------------------------------

K.step('the core takes {int} {string} from me', 'server', function(ctx, amount, item)
    local ok, err = K.export(CORE, 'removeItem', ctx.tester, item, amount, nil, 'functional test')
    if not ok then error(('removeItem %d %s failed: %s'):format(amount, item, tostring(err)), 0) end
end)
K.step('the core should refuse to give me {int} {string} with {string}', 'server', function(ctx, amount, item, reason)
    local tester = ctx.tester
    local ok, err = K.export(CORE, 'addItem', tester, item, amount, nil, nil, 'functional test')
    if ok then pcall(function() exports.kora_core:removeItem(tester, item, amount, nil, 'functional test cleanup') end) end
    refused(('addItem %d %s'):format(amount, item), ok, err, reason)
end)
K.step('the core should refuse to take {int} {string} from me with {string}', 'server', function(ctx, amount, item, reason)
    local ok, err = K.export(CORE, 'removeItem', ctx.tester, item, amount, nil, 'functional test')
    refused(('removeItem %d %s'):format(amount, item), ok, err, reason)
end)
K.step('the core should count {int} {string} on me', 'server', function(ctx, amount, item)
    ctx:waitUntil(function() return K.export(CORE, 'getItemCount', ctx.tester, item) == amount end,
        ('getItemCount %s is %s, expected %d'):format(item, tostring((K.export(CORE, 'getItemCount', ctx.tester, item))), amount), 3000)
end)
K.step('the core should confirm I have {int} {string}', 'server', function(ctx, amount, item)
    ctx:equal(K.export(CORE, 'hasItem', ctx.tester, item, amount) == true, true, ('hasItem %s x%d'):format(item, amount))
end)
K.step('the core should deny I have {int} {string}', 'server', function(ctx, amount, item)
    ctx:equal(K.export(CORE, 'hasItem', ctx.tester, item, amount) == true, false, ('hasItem %s x%d'):format(item, amount))
end)
-- getItemByName and getItemBySlot must describe the same slot record.
K.step('the core should find my {string} by name and by slot', 'server', function(ctx, item)
    local byName = K.export(CORE, 'getItemByName', ctx.tester, item)
    assert(type(byName) == 'table', 'getItemByName returned nothing for ' .. item)
    ctx:equal(byName.name, item, 'getItemByName name')
    assert(type(byName.slot) == 'number', 'Item record carries no slot')
    local bySlot = K.export(CORE, 'getItemBySlot', ctx.tester, byName.slot)
    assert(type(bySlot) == 'table', 'getItemBySlot returned nothing for slot ' .. tostring(byName.slot))
    ctx:equal(bySlot.name, item, 'getItemBySlot name')
    ctx:equal(bySlot.amount, byName.amount, 'getItemBySlot amount')
end)
K.step('the core should find no {string} by name', 'server', function(ctx, item)
    ctx:equal(K.export(CORE, 'getItemByName', ctx.tester, item), nil, 'getItemByName ' .. item)
end)
K.step('the core should say I can carry {int} {string}', 'server', function(ctx, amount, item)
    local ok, err = K.export(CORE, 'canCarry', ctx.tester, item, amount)
    if not ok then error(('canCarry %d %s was refused: %s'):format(amount, item, tostring(err)), 0) end
end)
K.step('the core should say I cannot carry {int} {string} because {string}', 'server', function(ctx, amount, item, reason)
    local ok, err = K.export(CORE, 'canCarry', ctx.tester, item, amount)
    refused(('canCarry %d %s'):format(amount, item), ok, err, reason)
end)
K.step('the core should report my carried weight within my limit', 'server', function(ctx)
    local weight, limit = K.export(CORE, 'getWeight', ctx.tester)
    assert(type(weight) == 'number' and type(limit) == 'number', 'getWeight did not return weight and maxWeight')
    assert(weight >= 0 and limit > 0 and weight <= limit, ('Carried weight %s is outside 0..%s'):format(tostring(weight), tostring(limit)))
    ctx.state.coreWeight = weight
end)
K.step('the core should report my carried weight has grown', 'server', function(ctx)
    local before = assert(ctx.state.coreWeight, 'Read the carried weight first')
    local weight = K.export(CORE, 'getWeight', ctx.tester)
    assert(type(weight) == 'number' and weight > before, ('Carried weight is %s, was %s'):format(tostring(weight), tostring(before)))
end)

-- ---------------------------------------------------------------------------
-- Metadata (modules/metadata/server.lua). Fixtures use the generic
-- `my metadata {string} is {int}` step, which restores the original value.
-- ---------------------------------------------------------------------------

K.step('I watch core metadata announcements', 'server', function(ctx)
    local tester = ctx.tester
    K.capture(ctx, 'QBCore:Server:OnMetaDataChange', function(src) return src == tester end)
end)
K.step('the core should have announced my metadata {string} as {int}', 'server', function(ctx, key, value)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, 'QBCore:Server:OnMetaDataChange')) do
            if record[2] == key and record[3] == value then return true end
        end
    end, ('No OnMetaDataChange for %s = %d'):format(key, value), 3000)
end)
-- incrementMetaData(src, key, delta, min, max) returns the clamped new value.
K.step('the core increments my metadata {string} by {int} within {int} and {int}', 'server', function(ctx, key, delta, min, max)
    local tester = ctx.tester
    local original = K.export(CORE, 'getMetaData', tester, key)
    ctx:cleanup(function() exports.kora_core:setMetaData(tester, key, original) end)
    local value, err = K.export(CORE, 'incrementMetaData', tester, key, delta, min, max)
    if value == nil then error(('incrementMetaData %s failed: %s'):format(key, tostring(err)), 0) end
    ctx.state.coreIncrement = value
end)
K.step('the core increment should have returned {int}', 'server', function(ctx, value)
    ctx:equal(ctx.state.coreIncrement, value, 'incrementMetaData result')
end)
K.step('the core should refuse a metadata key that is not text', 'server', function(ctx)
    local ok, err = K.export(CORE, 'setMetaData', ctx.tester, 12345, 1)
    refused('a numeric metadata key', ok, err, 'metadata key must be a string')
end)
K.step('the core should hold no metadata {string} for me', 'server', function(ctx, key)
    ctx:equal(K.export(CORE, 'getMetaData', ctx.tester, key), nil, 'Metadata ' .. key)
end)

-- ---------------------------------------------------------------------------
-- Jobs, gangs and duty (modules/jobs/server.lua). Grades are one-based.
-- Fixtures use the generic job and gang steps, which restore the originals.
-- ---------------------------------------------------------------------------

K.step('the core should describe my job as {string} grade {int} named {string}', 'server', function(ctx, name, level, gradeName)
    local job = K.export(CORE, 'getJob', ctx.tester)
    assert(type(job) == 'table' and type(job.grade) == 'table', 'getJob returned no job')
    ctx:equal(job.name, name, 'Job name')
    ctx:equal(job.grade.level, level, 'Job grade level')
    ctx:equal(job.grade.name, gradeName, 'Job grade name')
end)
K.step('the core should describe my gang as {string} grade {int} named {string}', 'server', function(ctx, name, level, gradeName)
    local gang = K.export(CORE, 'getGang', ctx.tester)
    assert(type(gang) == 'table' and type(gang.grade) == 'table', 'getGang returned no gang')
    ctx:equal(gang.name, name, 'Gang name')
    ctx:equal(gang.grade.level, level, 'Gang grade level')
    ctx:equal(gang.grade.name, gradeName, 'Gang grade name')
end)
K.step('the core should refuse to set my job to {string} with {string}', 'server', function(ctx, name, reason)
    local tester = ctx.tester
    local previous = K.player(ctx).job or {}
    local previousGrade = type(previous.grade) == 'table' and previous.grade.level or previous.grade
    local ok, err = K.export(CORE, 'setJob', tester, name, 1)
    if ok and previous.name then
        exports.kora_core:setJob(tester, previous.name, previousGrade)
        exports.kora_core:setJobDuty(tester, previous.onduty == true)
    end
    refused('setJob ' .. name, ok, err, reason)
end)
K.step('the core should refuse to set my gang to {string} with {string}', 'server', function(ctx, name, reason)
    local tester = ctx.tester
    local previous = K.player(ctx).gang or {}
    local previousGrade = type(previous.grade) == 'table' and previous.grade.level or previous.grade
    local ok, err = K.export(CORE, 'setGang', tester, name, 1)
    if ok and previous.name then exports.kora_core:setGang(tester, previous.name, previousGrade) end
    refused('setGang ' .. name, ok, err, reason)
end)
K.step('my gang should be {string} according to the core', 'server', function(ctx, name)
    ctx:equal((K.export(CORE, 'getGang', ctx.tester) or {}).name, name, 'Gang name')
end)
-- setJobDuty(src, onDuty). The duty flag before the step is restored afterwards.
local function setDuty(ctx, onDuty)
    local tester = ctx.tester
    local before = (K.player(ctx).job or {}).onduty == true
    ctx:cleanup(function() exports.kora_core:setJobDuty(tester, before) end)
    local ok, err = K.export(CORE, 'setJobDuty', tester, onDuty)
    if not ok then error('setJobDuty failed: ' .. tostring(err), 0) end
end
K.step('the core puts me on duty', 'server', function(ctx) setDuty(ctx, true) end)
K.step('the core takes me off duty', 'server', function(ctx) setDuty(ctx, false) end)
K.step('the core should list me among {string} staff', 'server', function(ctx, name)
    assert(includes(K.export(CORE, 'getPlayersByJob', name, false), ctx.tester), 'getPlayersByJob does not list the tester for ' .. name)
end)
K.step('the core should not list me among {string} staff', 'server', function(ctx, name)
    assert(not includes(K.export(CORE, 'getPlayersByJob', name, false), ctx.tester), 'getPlayersByJob lists the tester for ' .. name)
end)
K.step('the core should list me among on-duty {string} staff', 'server', function(ctx, name)
    assert(includes(K.export(CORE, 'getPlayersByJob', name, true), ctx.tester), 'On-duty index does not list the tester for ' .. name)
end)
K.step('the core should not list me among on-duty {string} staff', 'server', function(ctx, name)
    assert(not includes(K.export(CORE, 'getPlayersByJob', name, true), ctx.tester), 'On-duty index lists the tester for ' .. name)
end)
K.step('I remember the core on-duty count for {string}', 'server', function(ctx, name)
    ctx.state.coreDuty = ctx.state.coreDuty or {}
    local count = K.export(CORE, 'getDutyCount', name)
    assert(type(count) == 'number', 'getDutyCount did not return a number')
    ctx.state.coreDuty[name] = count
end)
K.step('the core on-duty count for {string} should have changed by {int}', 'server', function(ctx, name, delta)
    local before = assert(ctx.state.coreDuty and ctx.state.coreDuty[name], 'Remember the on-duty count first')
    ctx:equal(K.export(CORE, 'getDutyCount', name) - before, delta, 'On-duty count change for ' .. name)
end)

-- ---------------------------------------------------------------------------
-- Player data paths (modules/player/server.lua): getPlayer, getPlayerData,
-- getPlayerByCitizenId, getPlayers, setPath, onChange/offChange.
-- ---------------------------------------------------------------------------

K.step('my core player data at {string} should be {int}', 'server', function(ctx, path, value)
    ctx:equal(K.export(CORE, 'getPlayerData', ctx.tester, keys(path)), value, 'PlayerData ' .. path)
end)
K.step('my core player data at {string} should be the text {string}', 'server', function(ctx, path, value)
    ctx:equal(K.export(CORE, 'getPlayerData', ctx.tester, keys(path)), value, 'PlayerData ' .. path)
end)
K.step('my core player data at {string} should be absent', 'server', function(ctx, path)
    ctx:equal(K.export(CORE, 'getPlayerData', ctx.tester, keys(path)), nil, 'PlayerData ' .. path)
end)
K.step('my core player data at {string} should match my full snapshot', 'server', function(ctx, path)
    local snapshot = K.export(CORE, 'getPlayer', ctx.tester)
    assert(type(snapshot) == 'table', 'getPlayer returned no snapshot')
    local expected = snapshot
    for _, key in ipairs(keys(path)) do expected = type(expected) == 'table' and expected[key] or nil end
    assert(type(expected) ~= 'table', 'Compare a scalar path, not a table: ' .. path)
    ctx:equal(K.export(CORE, 'getPlayerData', ctx.tester, keys(path)), expected, 'PlayerData ' .. path)
end)
K.step('the core should find me by my citizen id', 'server', function(ctx)
    local citizenid = K.player(ctx).citizenid
    assert(type(citizenid) == 'string' and citizenid ~= '', 'Test character has no citizenid')
    local found = K.export(CORE, 'getPlayerByCitizenId', citizenid)
    assert(type(found) == 'table', 'getPlayerByCitizenId returned nothing')
    ctx:equal(found.citizenid, citizenid, 'citizenid')
    ctx:equal(found.source, ctx.tester, 'source')
end)
K.step('the core should find nobody by the citizen id {string}', 'server', function(ctx, citizenid)
    ctx:equal(K.export(CORE, 'getPlayerByCitizenId', citizenid), nil, 'getPlayerByCitizenId ' .. citizenid)
end)
K.step('the core player list should include me', 'server', function(ctx)
    assert(includes(K.export(CORE, 'getPlayers'), ctx.tester), 'getPlayers does not list the tester')
end)
-- setPath is the write funnel. Only scratch metadata keys are written here.
K.step('the core writes {int} to my player data at {string}', 'server', function(ctx, value, path)
    local parts = keys(path)
    assert(parts[1] == 'metadata' and #parts == 2, 'This step only writes metadata.<key> paths')
    local tester = ctx.tester
    local original = K.export(CORE, 'getPlayerData', tester, parts)
    ctx:cleanup(function() exports.kora_core:setPath(tester, parts, original) end)
    local ok, err = K.export(CORE, 'setPath', tester, parts, value)
    if not ok then error(('setPath %s failed: %s'):format(path, tostring(err)), 0) end
end)
K.step('the core should refuse an empty player data path with {string}', 'server', function(ctx, reason)
    local ok, err = K.export(CORE, 'setPath', ctx.tester, {}, 1)
    refused('an empty setPath path', ok, err, reason)
end)
-- onChange(prefix, handler) -> id; handler(src, path, value). offChange(id) in cleanup.
K.step('I subscribe to core changes under {string}', 'server', function(ctx, prefix)
    local tester = ctx.tester
    local seen = {}
    ctx.state.coreSeen = seen
    local id, err = K.export(CORE, 'onChange', keys(prefix), function(src, path, value)
        if src ~= tester or #seen >= 50 then return end
        seen[#seen + 1] = { path = show(path), value = value }
    end)
    if not id then error('onChange failed: ' .. tostring(err), 0) end
    ctx.state.coreSubscription = id
    ctx:cleanup(function() exports.kora_core:offChange(id) end)
end)
K.step('I cancel my core subscription', 'server', function(ctx)
    K.export(CORE, 'offChange', assert(ctx.state.coreSubscription, 'Subscribe first'))
end)
K.step('my core subscription should have seen {string} become {int}', 'server', function(ctx, path, value)
    local seen = assert(ctx.state.coreSeen, 'Subscribe first')
    ctx:waitUntil(function()
        for _, record in ipairs(seen) do
            if record.path == path and record.value == value then return true end
        end
    end, ('Subscription never saw %s = %d'):format(path, value), 3000)
end)
K.step('my core subscription should have recorded {int} changes', 'server', function(ctx, count)
    local seen = assert(ctx.state.coreSeen, 'Subscribe first')
    Wait(300)
    ctx:equal(#seen, count, 'Changes seen by the subscription')
end)

-- Client mirror (modules/player/client.lua): getPlayerData(path) reads the
-- replicated copy, so these wait for replication instead of asserting at once.
K.step('my client core mirror at {string} should become {int}', 'client', function(ctx, path, value)
    K.started(CORE)
    ctx:waitUntil(function() return exports.kora_core:getPlayerData(keys(path)) == value end,
        ('Client mirror %s never became %d'):format(path, value), 5000)
end)
K.step('my client core mirror at {string} should become the text {string}', 'client', function(ctx, path, value)
    K.started(CORE)
    ctx:waitUntil(function() return exports.kora_core:getPlayerData(keys(path)) == value end,
        ('Client mirror %s never became %s'):format(path, value), 5000)
end)

-- ---------------------------------------------------------------------------
-- Transactions (modules/transaction/server.lua). The doc string is the
-- transaction table: { reason, money = { add, remove }, items = { add, remove } }.
-- ---------------------------------------------------------------------------

local function guardTransaction(ctx, tx, allowRandom)
    assert(type(tx) == 'table', 'The transaction doc string must be a JSON object')
    assert(allowRandom or tx.random == nil, 'Random rewards are not deterministic; do not use them here')
    local tester = ctx.tester
    -- Reward-list refusal steps only: should a malformed list be accepted after
    -- all, take back whatever it rolled.
    for _, entry in pairs(allowRandom and type(tx.random) == 'table' and tx.random or {}) do
        if type(entry) == 'table' and type(entry.item) == 'string' then
            local item, before = entry.item, exports.kora_core:getItemCount(tester, entry.item) or 0
            ctx:cleanup(function()
                local extra = (exports.kora_core:getItemCount(tester, item) or 0) - before
                if extra > 0 then exports.kora_core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
            end)
        end
    end
    local money = type(tx.money) == 'table' and tx.money or {}
    for _, list in pairs({ money.add or {}, money.remove or {} }) do
        for _, entry in ipairs(type(list) == 'table' and list or {}) do
            if type(entry) == 'table' and type(entry.account) == 'string' then
                local account = entry.account
                local original = exports.kora_core:getMoney(tester, account)
                if type(original) == 'number' then
                    ctx:cleanup(function() exports.kora_core:setMoney(tester, account, original, 'functional test cleanup') end)
                end
            end
        end
    end
    local added = type(tx.items) == 'table' and tx.items.add or {}
    for _, entry in ipairs(type(added) == 'table' and added or {}) do
        if type(entry) == 'table' and type(entry.item) == 'string' then
            local item, before = entry.item, exports.kora_core:getItemCount(tester, entry.item) or 0
            ctx:cleanup(function()
                local extra = (exports.kora_core:getItemCount(tester, item) or 0) - before
                if extra > 0 then exports.kora_core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
            end)
        end
    end
end
K.step('the core runs this transaction for me:', 'server', function(ctx, argument)
    local tx = K.json(argument)
    guardTransaction(ctx, tx)
    local ok, err = K.export(CORE, 'transaction', ctx.tester, tx)
    if not ok then error('Transaction failed: ' .. tostring(err), 0) end
end)
K.step('the core should refuse this transaction with {string}:', 'server', function(ctx, reason, argument)
    local tx = K.json(argument)
    guardTransaction(ctx, tx)
    local ok, err = K.export(CORE, 'transaction', ctx.tester, tx)
    refused('the transaction', ok, err, reason)
end)
K.step('the core should refuse a transaction that is not a table', 'server', function(ctx)
    local ok, err = K.export(CORE, 'transaction', ctx.tester, 'not a table')
    refused('a text transaction', ok, err, 'transaction must be a table')
end)

-- ---------------------------------------------------------------------------
-- Shared registries, identity and permissions: read only.
-- ---------------------------------------------------------------------------

K.step('the core registry {string} should label {string} as {string}', 'server', function(ctx, registry, key, label)
    local record = K.export(CORE, 'getShared', registry, key)
    assert(type(record) == 'table', ('getShared(%s, %s) returned nothing'):format(registry, key))
    ctx:equal(record.name, key, 'Registry record name')
    ctx:equal(record.label, label, 'Registry record label')
end)
K.step('the core registry {string} should not know {string}', 'server', function(ctx, registry, key)
    ctx:equal(K.export(CORE, 'getShared', registry, key), nil, ('getShared(%s, %s)'):format(registry, key))
end)
K.step('the core registry {string} should list {string} among its records', 'server', function(_, registry, key)
    local list = K.export(CORE, 'allShared', registry)
    assert(type(list) == 'table' and #list > 0, 'allShared returned no records for ' .. registry)
    for _, record in ipairs(list) do
        if type(record) == 'table' and record.name == key then return end
    end
    error(('allShared(%s) does not list %s'):format(registry, key), 0)
end)
K.step('the core job {string} should define {int} grades', 'server', function(ctx, name, count)
    local record = K.export(CORE, 'getShared', 'jobs', name)
    assert(type(record) == 'table' and type(record.grades) == 'table', 'No job record for ' .. name)
    ctx:equal(#record.grades, count, 'Grades of ' .. name)
end)
K.step('the core should report my identifiers', 'server', function(ctx)
    local ids = K.export(CORE, 'getIdentifiers', ctx.tester)
    assert(type(ids) == 'table' and next(ids) ~= nil, 'getIdentifiers returned nothing')
    for kind, value in pairs(ids) do
        assert(type(kind) == 'string' and type(value) == 'string' and value ~= '', 'Malformed identifier entry: ' .. tostring(kind))
    end
end)
K.step('the core should generate a citizen id that is not mine', 'server', function(ctx)
    local generated = K.export(CORE, 'generateCitizenId')
    assert(type(generated) == 'string' and generated ~= '', 'generateCitizenId returned nothing')
    assert(generated ~= K.player(ctx).citizenid, 'generateCitizenId returned the tester citizenid')
end)
-- modules/permissions/server.lua: LEVELS = god, admin, mod, user. Read only;
-- addPermission and removePermission are never called.
K.step('I remember my core permission level', 'server', function(ctx)
    local level = K.export(CORE, 'getPermission', ctx.tester)
    assert(level == 'god' or level == 'admin' or level == 'mod' or level == 'user',
        'Unexpected permission level: ' .. tostring(level))
    ctx.state.corePermission = level
end)
K.step('the core should grant me the baseline {string} permission', 'server', function(ctx, permission)
    ctx:equal(K.export(CORE, 'hasPermission', ctx.tester, permission), true, 'hasPermission ' .. permission)
end)
K.step('my core permission level should be unchanged', 'server', function(ctx)
    local before = assert(ctx.state.corePermission, 'Remember the permission level first')
    ctx:equal(K.export(CORE, 'getPermission', ctx.tester), before, 'Permission level')
end)

-- ===========================================================================
-- Deeper coverage. Everything below still targets ctx.tester only, except the
-- "absent player" refusals, which address a server id nobody holds.
-- ===========================================================================

-- A server id no player holds; every step that uses it checks that first.
local ABSENT = 999999

local function assertAbsent()
    assert(exports.kora_core:getPlayer(ABSENT) == nil, 'Server id ' .. ABSENT .. ' is a loaded player; pick another')
end

local function sameValue(a, b)
    return a == b or (type(a) == 'number' and type(b) == 'number' and math.abs(a - b) < 1e-9)
end

-- ---------------------------------------------------------------------------
-- Money edges (modules/money/server.lua): exact assignment, finite-number
-- parsing (finiteAmount), the bank floor, state bags, transfers, offline credits.
-- ---------------------------------------------------------------------------

K.step('the core sets my {string} account to {int}', 'server', function(ctx, account, amount)
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, 'setMoney', ctx.tester, account, amount, 'functional test')
    if not ok then error(('setMoney %s %d failed: %s'):format(account, amount, tostring(err)), 0) end
end)
-- emitMoneyChange sets the replicated state bag kora_core:money:<account>.
K.step('my core money state bag for {string} should be {int}', 'server', function(ctx, account, amount)
    local tester = ctx.tester
    ctx:waitUntil(function() return Player(tester).state['kora_core:money:' .. account] == amount end,
        ('State bag kora_core:money:%s is %s, expected %d'):format(account,
            tostring(Player(tester).state['kora_core:money:' .. account]), amount), 3000)
end)
-- The raw text goes to the export unchanged: numeric strings are parsed by finiteAmount.
K.step('the core adds the amount {string} to my {string} account', 'server', function(ctx, raw, account)
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, 'addMoney', ctx.tester, account, raw, 'functional test')
    if not ok then error(('addMoney %s "%s" failed: %s'):format(account, raw, tostring(err)), 0) end
end)
K.step('the core should report the amount {string} in my {string} account', 'server', function(ctx, raw, account)
    local expected = assert(tonumber(raw), 'Not a number: ' .. raw)
    local actual = K.export(CORE, 'getMoney', ctx.tester, account)
    assert(sameValue(actual, expected), ('%s balance is %s, expected %s'):format(account, tostring(actual), raw))
end)
K.step('the core should refuse to {word} the amount {string} for my {string} account with {string}', 'server', function(ctx, action, raw, account, reason)
    local exportName = ({ add = 'addMoney', remove = 'removeMoney', set = 'setMoney' })[action]
    assert(exportName, 'Action must be add, remove or set')
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, exportName, ctx.tester, account, raw, 'functional test')
    refused(('%s %s "%s"'):format(exportName, account, raw), ok, err, reason)
end)
-- transferMoney(fromSrc, toSrc, ...): the tester is the sender, nobody receives.
K.step('the core should refuse to transfer {int} from my {string} account to an absent player', 'server', function(ctx, amount, account)
    assertAbsent()
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, 'transferMoney', ctx.tester, ABSENT, account, amount, 'functional test')
    refused('transferMoney to an absent player', ok, err, 'no such player')
end)
K.step('the core should refuse to transfer {int} from my {string} account to myself with {string}', 'server', function(ctx, amount, account, reason)
    restoreBalance(ctx, account)
    local ok, err = K.export(CORE, 'transferMoney', ctx.tester, ctx.tester, account, amount, 'functional test')
    refused(('transferMoney %s %d to myself'):format(account, amount), ok, err, reason)
end)
-- calculateTax floors amount * getTaxRate and never exceeds the amount
-- (money/server.lua:93-103); getTransactionTax is either 0 or that figure.
K.step('the core tax preview for {int} should follow the configured rate', 'server', function(ctx, amount)
    for _, account in ipairs({ 'cash', 'bank', 'crypto' }) do
        for _, action in ipairs({ 'add', 'remove', 'transfer' }) do
            local rate = K.export(CORE, 'getTaxRate', account, action)
            assert(type(rate) == 'number' and rate >= 0 and rate <= 1, ('Tax rate %s/%s is %s'):format(account, action, tostring(rate)))
            local tax = K.export(CORE, 'calculateTax', amount, account, action)
            ctx:equal(tax, math.max(0, math.floor(amount * rate)), ('calculateTax %d %s/%s'):format(amount, account, action))
            local applied = K.export(CORE, 'getTransactionTax', amount, account, action)
            assert(applied == 0 or applied == tax, ('getTransactionTax %s/%s is %s, calculateTax %s'):format(account, action, tostring(applied), tostring(tax)))
        end
    end
    ctx:equal(K.export(CORE, 'getTaxRate', 'fft_no_account', 'add'), 0, 'Tax rate of an unknown account')
    ctx:equal(K.export(CORE, 'getTaxRate', 'bank', 'fft_no_action'), 0, 'Tax rate of an unknown action')
    ctx:equal(K.export(CORE, 'calculateTax', 0, 'bank', 'add'), 0, 'Tax on 0')
    ctx:equal(K.export(CORE, 'calculateTax', -500, 'bank', 'add'), 0, 'Tax on a negative amount')
    ctx:equal(K.export(CORE, 'calculateTax', 'not a number', 'bank', 'add'), 0, 'Tax on text')
end)
-- collectTax deposits into the government account, so only refusals are driven:
-- disabled tax first, then the amount check (money/server.lua:118-122).
K.step('the core should refuse to collect a tax of {int}', 'server', function(ctx, amount)
    assert(amount <= 0, 'Only non-positive amounts may be sent to collectTax')
    local enabled = K.export(CORE, 'getTaxAccount') ~= nil
    local ok, err = K.export(CORE, 'collectTax', amount, 'functional test')
    refused('collectTax ' .. amount, ok, err, enabled and 'amount must be positive' or 'transaction tax is disabled')
end)
-- addOfflineMoney(citizenid, account, amount). `who`: "me" is the tester's
-- citizenid (online, so refused), "blank" is the empty string, anything else is literal.
K.step('the core should refuse an offline {string} credit of {string} to {word} with {string}', 'server', function(ctx, account, raw, who, reason)
    local citizenid = who == 'me' and K.player(ctx).citizenid or who == 'blank' and '' or who
    assert(who == 'me' or who == 'blank' or who:sub(1, 4) == 'FFT_', 'Literal citizen ids must start with FFT_')
    local ok, err = K.export(CORE, 'addOfflineMoney', citizenid, account, tonumber(raw) or raw)
    refused(('addOfflineMoney %s %s to %s'):format(account, raw, who), ok, err, reason)
end)
-- setOfflineJob/setOfflineGang check the registry first, then load the stored
-- row; saving refuses an online character (persistence/server.lua:250).
K.step('the core should refuse to store the offline {word} {string} for me with {string}', 'server', function(ctx, kind, name, reason)
    local exportName = ({ job = 'setOfflineJob', gang = 'setOfflineGang' })[kind]
    assert(exportName, 'Kind must be job or gang')
    local ok, err = K.export(CORE, exportName, K.player(ctx).citizenid, name, 1)
    refused(('%s %s'):format(exportName, name), ok, err, reason)
end)

-- Each refusal for a server id with no loaded player, with the exact message.
local ABSENT_CALLS = {
    addMoney = function() return exports.kora_core:addMoney(ABSENT, 'bank', 10, 'functional test') end,
    removeMoney = function() return exports.kora_core:removeMoney(ABSENT, 'bank', 10, 'functional test') end,
    setMoney = function() return exports.kora_core:setMoney(ABSENT, 'bank', 10, 'functional test') end,
    setJob = function() return exports.kora_core:setJob(ABSENT, 'mechanic', 1) end,
    setGang = function() return exports.kora_core:setGang(ABSENT, 'ballas', 1) end,
    setMetaData = function() return exports.kora_core:setMetaData(ABSENT, 'fft_probe', 1) end,
    incrementMetaData = function() return exports.kora_core:incrementMetaData(ABSENT, 'fft_probe', 1) end,
    setPath = function() return exports.kora_core:setPath(ABSENT, { 'metadata', 'fft_probe' }, 1) end,
    savePlayer = function() return exports.kora_core:savePlayer(ABSENT) end,
    jailPlayer = function() return exports.kora_core:jailPlayer(ABSENT, 1, 'functional test') end,
    setDevMode = function() return exports.kora_core:setDevMode(ABSENT, true) end,
}
K.step('the core export {string} should refuse an absent player with {string}', 'server', function(ctx, name, reason)
    local call = assert(ABSENT_CALLS[name], 'No absent-player call is defined for ' .. name)
    K.started(CORE)
    assertAbsent()
    local ok, err = call()
    if name == 'incrementMetaData' then
        -- metadata/server.lua:37 returns nil, 'no such player'.
        refusedNil(name .. ' for an absent player', ok, err, reason)
    else
        refused(name .. ' for an absent player', ok, err, reason)
    end
end)
K.step('the core should know nothing about an absent player', 'server', function(ctx)
    assertAbsent()
    ctx:equal(K.export(CORE, 'getPlayerData', ABSENT), nil, 'getPlayerData')
    ctx:equal(K.export(CORE, 'getMoney', ABSENT, 'bank'), nil, 'getMoney')
    ctx:equal(K.export(CORE, 'getJob', ABSENT), nil, 'getJob')
    ctx:equal(K.export(CORE, 'getGang', ABSENT), nil, 'getGang')
    ctx:equal(K.export(CORE, 'getMetaData', ABSENT, 'hunger'), nil, 'getMetaData')
    ctx:equal(K.export(CORE, 'setJobDuty', ABSENT, true), false, 'setJobDuty')
    ctx:equal(K.export(CORE, 'getRemaining', ABSENT), 0, 'getRemaining')
    ctx:equal(K.export(CORE, 'isJailed', ABSENT), false, 'isJailed')
    ctx:equal(K.export(CORE, 'release', ABSENT), false, 'release')
    ctx:equal(K.export(CORE, 'isDevMode', ABSENT), false, 'isDevMode')
    assert(not includes(K.export(CORE, 'getPlayers'), ABSENT), 'getPlayers lists the absent id')
end)

-- ---------------------------------------------------------------------------
-- Items through the gateway (kora_inventory/server.lua answers while started):
-- hasItem lists and maps, stacking, moveItem and useItem refusals.
-- ---------------------------------------------------------------------------

local function itemList(text)
    local out = {}
    for part in tostring(text):gmatch('[^,]+') do out[#out + 1] = (part:gsub('^%s+', ''):gsub('%s+$', '')) end
    return out
end
K.step('the core should refuse to give me {int} {string}', 'server', function(ctx, amount, item)
    local tester = ctx.tester
    local ok = K.export(CORE, 'addItem', tester, item, amount, nil, nil, 'functional test')
    if ok then pcall(function() exports.kora_core:removeItem(tester, item, math.max(1, amount), nil, 'functional test cleanup') end) end
    assert(not ok, ('addItem %d %s was accepted'):format(amount, item))
    local carry = K.export(CORE, 'canCarry', tester, item, amount)
    assert(not carry, ('canCarry %d %s was accepted'):format(amount, item))
end)
K.step('the core should confirm I have each of {string}', 'server', function(ctx, list)
    ctx:equal(K.export(CORE, 'hasItem', ctx.tester, itemList(list)) == true, true, 'hasItem ' .. list)
end)
K.step('the core should deny I have each of {string}', 'server', function(ctx, list)
    ctx:equal(K.export(CORE, 'hasItem', ctx.tester, itemList(list)) == true, false, 'hasItem ' .. list)
end)
-- Doc string: a JSON object of item name -> required count.
K.step('the core should confirm I have these amounts:', 'server', function(ctx, argument)
    ctx:equal(K.export(CORE, 'hasItem', ctx.tester, K.json(argument)) == true, true, 'hasItem with a count map')
end)
K.step('the core should deny I have these amounts:', 'server', function(ctx, argument)
    ctx:equal(K.export(CORE, 'hasItem', ctx.tester, K.json(argument)) == true, false, 'hasItem with a count map')
end)
-- water_bottle is not unique (shared/items.lua:152), so grants stack in one slot.
K.step('the core should keep my {string} in one stack of {int}', 'server', function(ctx, item, amount)
    local stacks = K.export(CORE, 'getItemsByName', ctx.tester, item)
    assert(type(stacks) == 'table', 'getItemsByName returned nothing')
    ctx:equal(#stacks, 1, 'Stacks of ' .. item)
    ctx:equal(stacks[1].amount, amount, 'Stack size of ' .. item)
end)
K.step('the core should find nothing in my first free slot', 'server', function(ctx)
    local free = K.export(CORE, 'getFreeSlot', ctx.tester)
    assert(type(free) == 'number', 'getFreeSlot returned no slot')
    ctx:equal(K.export(CORE, 'getItemBySlot', ctx.tester, free), nil, 'getItemBySlot ' .. free)
end)
-- moveItem(src, fromSlot, toSlot, amount). The runner resets the inventory.
K.step('the core moves my {string} to a free slot', 'server', function(ctx, item)
    local held = assert(K.export(CORE, 'getItemByName', ctx.tester, item), 'Not holding ' .. item)
    local free = assert(K.export(CORE, 'getFreeSlot', ctx.tester), 'No free slot')
    local ok, err = K.export(CORE, 'moveItem', ctx.tester, held.slot, free)
    if not ok then error(('moveItem %d -> %d failed: %s'):format(held.slot, free, tostring(err)), 0) end
    ctx.state.coreMove = { item = item, from = held.slot, to = free, amount = held.amount }
end)
K.step('the core should show my {string} only in the slot it was moved to', 'server', function(ctx, item)
    local move = assert(ctx.state.coreMove, 'Move an item first')
    ctx:waitUntil(function()
        local moved = K.export(CORE, 'getItemBySlot', ctx.tester, move.to)
        return type(moved) == 'table' and moved.name == item and moved.amount == move.amount
            and K.export(CORE, 'getItemBySlot', ctx.tester, move.from) == nil
    end, ('%s did not move from slot %d to %d'):format(item, move.from, move.to), 3000)
end)
K.step('the core moves my {string} back', 'server', function(ctx, item)
    local move = assert(ctx.state.coreMove, 'Move an item first')
    local ok, err = K.export(CORE, 'moveItem', ctx.tester, move.to, move.from)
    if not ok then error(('moveItem %d -> %d failed: %s'):format(move.to, move.from, tostring(err)), 0) end
    ctx:waitUntil(function()
        local back = K.export(CORE, 'getItemBySlot', ctx.tester, move.from)
        return type(back) == 'table' and back.name == item and back.amount == move.amount
    end, item .. ' did not return to slot ' .. move.from, 3000)
end)
K.step('the core should refuse to move from my first free slot with {string}', 'server', function(ctx, reason)
    local free = assert(K.export(CORE, 'getFreeSlot', ctx.tester), 'No free slot')
    local target = free == 1 and 2 or 1
    local ok, err = K.export(CORE, 'moveItem', ctx.tester, free, target)
    refused(('moveItem from empty slot %d'):format(free), ok, err, reason)
end)
K.step('the core should refuse to move my {string} to slot {int} with {string}', 'server', function(ctx, item, slot, reason)
    local held = assert(K.export(CORE, 'getItemByName', ctx.tester, item), 'Not holding ' .. item)
    local ok, err = K.export(CORE, 'moveItem', ctx.tester, held.slot, slot)
    refused(('moveItem %s to slot %d'):format(item, slot), ok, err, reason)
end)
K.step('the core should refuse to move my {string} onto my {string} with {string}', 'server', function(ctx, item, other, reason)
    local held = assert(K.export(CORE, 'getItemByName', ctx.tester, item), 'Not holding ' .. item)
    local target = assert(K.export(CORE, 'getItemByName', ctx.tester, other), 'Not holding ' .. other)
    local ok, err = K.export(CORE, 'moveItem', ctx.tester, held.slot, target.slot)
    refused(('moveItem %s onto %s'):format(item, other), ok, err, reason)
end)
-- Only items the tester does not hold: a held item would really be used.
K.step('the core should refuse to use {string} with {string}', 'server', function(ctx, item, reason)
    assert((K.export(CORE, 'getItemCount', ctx.tester, item) or 0) == 0, 'The tester holds ' .. item .. '; it would be used')
    local ok, err = K.export(CORE, 'useItem', ctx.tester, item)
    refused('useItem ' .. item, ok, err, reason)
end)

-- ---------------------------------------------------------------------------
-- Metadata edges (modules/metadata/server.lua, modules/needs/server.lua).
-- ---------------------------------------------------------------------------

local function restoreMetadata(ctx, key)
    local tester = ctx.tester
    local original = K.export(CORE, 'getMetaData', tester, key)
    ctx:cleanup(function() exports.kora_core:setMetaData(tester, key, original) end)
end
K.step('my metadata {string} is the text {string}', 'server', function(ctx, key, value)
    restoreMetadata(ctx, key)
    local ok, err = K.export(CORE, 'setMetaData', ctx.tester, key, value)
    if not ok then error(('setMetaData %s failed: %s'):format(key, tostring(err)), 0) end
end)
K.step('the core increments my metadata {string} by {int} without bounds', 'server', function(ctx, key, delta)
    restoreMetadata(ctx, key)
    local value, err = K.export(CORE, 'incrementMetaData', ctx.tester, key, delta)
    if value == nil then error(('incrementMetaData %s failed: %s'):format(key, tostring(err)), 0) end
    ctx.state.coreIncrement = value
end)
-- A non-numeric delta counts as 0 (metadata/server.lua:38).
K.step('the core increments my metadata {string} by the text {string}', 'server', function(ctx, key, delta)
    restoreMetadata(ctx, key)
    local value, err = K.export(CORE, 'incrementMetaData', ctx.tester, key, delta)
    if value == nil then error(('incrementMetaData %s failed: %s'):format(key, tostring(err)), 0) end
    ctx.state.coreIncrement = value
end)
-- getMetaData(src) with no key returns the whole table (metadata/server.lua:9).
K.step('the core should list my metadata {string} as {int} in the full table', 'server', function(ctx, key, value)
    local all = K.export(CORE, 'getMetaData', ctx.tester)
    assert(type(all) == 'table', 'getMetaData without a key returned no table')
    ctx:equal(all[key], value, 'Metadata table entry ' .. key)
end)
-- needs.reset: hunger 100, thirst 100, stress 0 (needs/server.lua:47-51).
K.step('the core resets my needs', 'server', function(ctx)
    for _, key in ipairs({ 'hunger', 'thirst', 'stress' }) do restoreMetadata(ctx, key) end
    K.export(CORE, 'reset', ctx.tester)
end)

-- ---------------------------------------------------------------------------
-- Jobs and gangs against the registry (CoreInternal.player.buildJob/buildGang
-- in modules/player/shared.lua:57-92). Expectations are read from the registry
-- at run time, because job resources may replace the seeds in shared/jobs.lua.
-- ---------------------------------------------------------------------------

K.step('the core should describe my job {string} at grade {int} as the registry defines', 'server', function(ctx, name, level)
    local def = K.export(CORE, 'getShared', 'jobs', name)
    assert(type(def) == 'table' and type(def.grades) == 'table', 'No job record for ' .. name)
    local grade = assert(def.grades[level], ('Job %s has no grade %d'):format(name, level))
    local job = K.export(CORE, 'getJob', ctx.tester)
    assert(type(job) == 'table' and type(job.grade) == 'table', 'getJob returned no job')
    ctx:equal(job.name, name, 'Job name')
    ctx:equal(job.label, def.label, 'Job label')
    ctx:equal(job.type, def.type or 'none', 'Job type')
    ctx:equal(job.payment, grade.payment or 0, 'Job payment')
    ctx:equal(job.isboss, grade.isboss or false, 'Job isboss')
    ctx:equal(job.onduty, def.defaultDuty ~= false, 'Duty right after setJob')
    ctx:equal(job.grade.level, level, 'Job grade level')
    ctx:equal(job.grade.name, grade.name or 'Grade', 'Job grade name')
end)
K.step('the core should describe my gang {string} at grade {int} as the registry defines', 'server', function(ctx, name, level)
    local def = K.export(CORE, 'getShared', 'gangs', name)
    assert(type(def) == 'table' and type(def.grades) == 'table', 'No gang record for ' .. name)
    local grade = assert(def.grades[level], ('Gang %s has no grade %d'):format(name, level))
    local gang = K.export(CORE, 'getGang', ctx.tester)
    assert(type(gang) == 'table' and type(gang.grade) == 'table', 'getGang returned no gang')
    ctx:equal(gang.name, name, 'Gang name')
    ctx:equal(gang.label, def.label, 'Gang label')
    ctx:equal(gang.isboss, grade.isboss or false, 'Gang isboss')
    ctx:equal(gang.grade.level, level, 'Gang grade level')
    ctx:equal(gang.grade.name, grade.name or 'None', 'Gang grade name')
end)
-- The grade text is converted with tonumber; text that is not a number is
-- passed through so setJob's own `tonumber(grade) or 1` handles it.
K.step('I am given the job {string} at the grade {string}', 'server', function(ctx, name, raw)
    K.setJob(ctx, name, tonumber(raw) or raw)
end)
K.step('I am given the gang {string} at the grade {string}', 'server', function(ctx, name, raw)
    local tester = ctx.tester
    local previous = K.player(ctx).gang or {}
    local previousGrade = type(previous.grade) == 'table' and previous.grade.level or previous.grade
    local ok, err = K.export(CORE, 'setGang', tester, name, tonumber(raw) or raw)
    if not ok then error(('setGang %s "%s" failed: %s'):format(name, raw, tostring(err)), 0) end
    ctx:cleanup(function() if previous.name then exports.kora_core:setGang(tester, previous.name, previousGrade) end end)
end)
-- getJob documents grade = { name, level } (modules/jobs/docs.md:15): the level
-- reported must be a grade the job defines, and its name must be that grade's.
K.step('the core should describe a grade that the {word} {string} defines', 'server', function(ctx, kind, name)
    local registry = ({ job = 'jobs', gang = 'gangs' })[kind]
    assert(registry, 'Kind must be job or gang')
    local def = K.export(CORE, 'getShared', registry, name)
    assert(type(def) == 'table' and type(def.grades) == 'table', 'No record for ' .. name)
    local current = K.export(CORE, kind == 'job' and 'getJob' or 'getGang', ctx.tester) or {}
    local level = type(current.grade) == 'table' and current.grade.level
    local defined = def.grades[level]
    assert(defined, ('%s %s reports grade level %s, but it defines %d grades'):format(kind, name, tostring(level), #def.grades))
    ctx:equal(current.grade.name, defined.name, 'Grade name for level ' .. tostring(level))
end)
K.step('I watch core job announcements', 'server', function(ctx)
    local tester = ctx.tester
    local mine = function(src) return src == tester end
    K.capture(ctx, 'QBCore:Server:OnJobUpdate', mine)
    K.capture(ctx, 'QBCore:Server:OnGangUpdate', mine)
    K.capture(ctx, 'QBCore:Server:SetDuty', mine)
end)
K.step('the core should have announced my {word} as {string}', 'server', function(ctx, kind, name)
    local event = ({ job = 'QBCore:Server:OnJobUpdate', gang = 'QBCore:Server:OnGangUpdate' })[kind]
    assert(event, 'Kind must be job or gang')
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, event)) do
            if type(record[2]) == 'table' and record[2].name == name then return true end
        end
    end, ('No %s naming %s'):format(event, name), 3000)
end)
K.step('the core should have announced my duty as {word}', 'server', function(ctx, state)
    assert(state == 'on' or state == 'off', 'Duty must be on or off')
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, 'QBCore:Server:SetDuty')) do
            if record[2] == (state == 'on') then return true end
        end
    end, 'No QBCore:Server:SetDuty ' .. state, 3000)
end)
K.step('the core should list me among {string} job type staff', 'server', function(ctx, jobType)
    assert(includes(K.export(CORE, 'getPlayersByJobType', jobType, false), ctx.tester), 'getPlayersByJobType does not list the tester for ' .. jobType)
end)
K.step('the core should not list me among {string} job type staff', 'server', function(ctx, jobType)
    assert(not includes(K.export(CORE, 'getPlayersByJobType', jobType, false), ctx.tester), 'getPlayersByJobType lists the tester for ' .. jobType)
end)
K.step('the core should list me among on-duty {string} job type staff', 'server', function(ctx, jobType)
    assert(includes(K.export(CORE, 'getPlayersByJobType', jobType, true), ctx.tester), 'On-duty type index does not list the tester for ' .. jobType)
end)
K.step('the core should not list me among on-duty {string} job type staff', 'server', function(ctx, jobType)
    assert(not includes(K.export(CORE, 'getPlayersByJobType', jobType, true), ctx.tester), 'On-duty type index lists the tester for ' .. jobType)
end)
K.step('I remember the core on-duty count for job type {string}', 'server', function(ctx, jobType)
    ctx.state.coreTypeDuty = ctx.state.coreTypeDuty or {}
    local count = K.export(CORE, 'getDutyCountByType', jobType)
    assert(type(count) == 'number', 'getDutyCountByType did not return a number')
    ctx.state.coreTypeDuty[jobType] = count
end)
K.step('the core on-duty count for job type {string} should have changed by {int}', 'server', function(ctx, jobType, delta)
    local before = assert(ctx.state.coreTypeDuty and ctx.state.coreTypeDuty[jobType], 'Remember the job type count first')
    ctx:equal(K.export(CORE, 'getDutyCountByType', jobType) - before, delta, 'On-duty count change for type ' .. jobType)
end)
K.step('the core {word} job type counts should include {string}', 'server', function(ctx, which, jobType)
    assert(which == 'held' or which == 'on-duty', 'Use held or on-duty')
    local counts = K.export(CORE, 'getJobTypeCounts', which == 'on-duty')
    assert(type(counts) == 'table' and (counts[jobType] or 0) >= 1, ('getJobTypeCounts(%s) has no %s'):format(which, jobType))
end)
-- getOnDutyRoster(filter) (jobs/server.lua:281-325).
local function rosterEntry(ctx, filter)
    for _, entry in ipairs(K.export(CORE, 'getOnDutyRoster', filter) or {}) do
        if entry.src == ctx.tester then return entry end
    end
end
local function checkRoster(ctx, entry, onDuty)
    local job = K.export(CORE, 'getJob', ctx.tester)
    ctx:equal(entry.citizenid, K.player(ctx).citizenid, 'Roster citizenid')
    ctx:equal(entry.job, job.name, 'Roster job')
    ctx:equal(entry.jobLabel, job.label or job.name, 'Roster job label')
    ctx:equal(entry.jobType, job.type or 'none', 'Roster job type')
    ctx:equal(entry.grade, job.grade.level, 'Roster grade')
    ctx:equal(entry.gradeLabel, job.grade.name, 'Roster grade label')
    ctx:equal(entry.onDuty, onDuty, 'Roster duty')
end
K.step('the core on-duty roster for {string} should describe me', 'server', function(ctx, name)
    checkRoster(ctx, assert(rosterEntry(ctx, { job = name }), 'On-duty roster does not list the tester for ' .. name), true)
end)
K.step('the core on-duty roster for {string} should not list me', 'server', function(ctx, name)
    assert(not rosterEntry(ctx, { job = name }), 'On-duty roster lists the tester for ' .. name)
end)
K.step('the core full roster for {string} should describe me off duty', 'server', function(ctx, name)
    checkRoster(ctx, assert(rosterEntry(ctx, { job = name, onDutyOnly = false }), 'Full roster does not list the tester for ' .. name), false)
end)
K.step('the core on-duty roster for job type {string} should not list me', 'server', function(ctx, jobType)
    assert(not rosterEntry(ctx, { jobType = jobType }), 'On-duty roster lists the tester for type ' .. jobType)
end)
-- GlobalState.OnDuty is republished 100 ms after an index change (jobs/server.lua:13-34).
K.step('the published on-duty count for {string} should match the core', 'server', function(ctx, name)
    ctx:waitUntil(function()
        local published = GlobalState.OnDuty
        return type(published) == 'table' and (published[name] or 0) == K.export(CORE, 'getDutyCount', name)
    end, 'GlobalState.OnDuty does not match getDutyCount for ' .. name, 3000)
end)

-- ---------------------------------------------------------------------------
-- Player data surface (modules/player/server.lua).
-- ---------------------------------------------------------------------------

K.step('the core should report my whole player data', 'server', function(ctx)
    local whole = K.export(CORE, 'getPlayerData', ctx.tester)
    assert(type(whole) == 'table', 'getPlayerData without a path returned nothing')
    local snapshot = K.player(ctx)
    ctx:equal(whole.citizenid, snapshot.citizenid, 'citizenid')
    assert(type(whole.money) == 'table' and type(whole.metadata) == 'table' and type(whole.job) == 'table',
        'Whole PlayerData lacks money, metadata or job')
    local found = false
    for _, data in ipairs(K.export(CORE, 'getAllPlayers') or {}) do
        if data.citizenid == snapshot.citizenid then found = true end
    end
    assert(found, 'getAllPlayers does not include the tester')
end)
-- player/server.lua:319-320 set both bags on login.
K.step('the core should report me logged in and itself ready', 'server', function(ctx)
    ctx:equal(K.export(CORE, 'isCoreReady'), true, 'isCoreReady')
    ctx:equal(Player(ctx.tester).state['kora_core:loggedIn'], true, 'State bag kora_core:loggedIn')
    ctx:equal(Player(ctx.tester).state.isLoggedIn, true, 'State bag isLoggedIn')
    assert(type(K.export(CORE, 'getStarterItems')) == 'table', 'getStarterItems returned no table')
end)
-- A bare string prefix is wrapped into { prefix } (player/server.lua:257).
K.step('I subscribe to core changes under the single key {string}', 'server', function(ctx, key)
    local tester = ctx.tester
    local seen = {}
    ctx.state.coreSeen = seen
    local id, err = K.export(CORE, 'onChange', key, function(src, path, value)
        if src ~= tester or #seen >= 50 then return end
        seen[#seen + 1] = { path = show(path), value = value }
    end)
    if not id then error('onChange failed: ' .. tostring(err), 0) end
    ctx.state.coreSubscription = id
    ctx:cleanup(function() exports.kora_core:offChange(id) end)
end)
K.step('the core should refuse a change subscription without a handler', 'server', function(ctx)
    local id, err = K.export(CORE, 'onChange', { 'metadata' }, 'not a function')
    if id then exports.kora_core:offChange(id) end
    -- player/server.lua:252 returns nil, 'handler must be callable'.
    refusedNil('onChange without a handler', id, err, 'handler must be callable')
end)
K.step('the core should refuse to save my player field {string} with {string}', 'server', function(ctx, field, reason)
    local ok, err = K.export(CORE, 'savePlayer', ctx.tester, field)
    refused('savePlayer ' .. field, ok, err, reason)
end)
-- The provider is never callable, so a valid key can never be registered here.
K.step('the core should refuse to register the player data field {string} with {string}', 'server', function(_, key, reason)
    local ok, err = K.export(CORE, 'registerPlayerDataField', key, 'not a function')
    refused('registerPlayerDataField ' .. key, ok, err, reason)
end)
K.step('the core should refuse to write the player data field {string} with {string}', 'server', function(ctx, key, reason)
    local ok, err = K.export(CORE, 'setPlayerDataField', ctx.tester, key, 1)
    refused('setPlayerDataField ' .. key, ok, err, reason)
end)

-- Client subscription (modules/player/client.lua:25-32): handler(path, value).
K.step('I watch my client core data under {string}', 'client', function(ctx, prefix)
    K.started(CORE)
    local seen = {}
    ctx.state.coreClientSeen = seen
    local id, err = exports.kora_core:onPlayerDataChange(keys(prefix), function(path, value)
        if #seen < 50 then seen[#seen + 1] = { path = show(path), value = value } end
    end)
    if not id then error('onPlayerDataChange failed: ' .. tostring(err), 0) end
    ctx:cleanup(function() exports.kora_core:offPlayerDataChange(id) end)
end)
K.step('my client core watch should have seen {string} become {int}', 'client', function(ctx, path, value)
    local seen = assert(ctx.state.coreClientSeen, 'Watch the client data first')
    ctx:waitUntil(function()
        for _, record in ipairs(seen) do
            if record.path == path and record.value == value then return true end
        end
    end, ('Client watch never saw %s = %d'):format(path, value), 5000)
end)

-- ---------------------------------------------------------------------------
-- Development mode (modules/development/server.lua and client.lua).
-- ---------------------------------------------------------------------------

K.step('I watch core dev mode announcements', 'server', function(ctx)
    local tester = ctx.tester
    -- Dev mode is in-memory per source and is not reset between scenarios
    -- (development/server.lua:4), so an earlier suite may have left it on; a
    -- repeated setting announces nothing (server.lua:21). Start from off.
    if K.export(CORE, 'isDevMode', tester) == true then
        ctx:cleanup(function() exports.kora_core:setDevMode(tester, true) end)
        local ok, err = K.export(CORE, 'setDevMode', tester, false)
        if not ok then error('setDevMode off failed: ' .. tostring(err), 0) end
    end
    K.capture(ctx, 'kora_core:server:devModeChanged', function(src) return src == tester end)
end)
K.step('the core turns my dev mode {word}', 'server', function(ctx, state)
    assert(state == 'on' or state == 'off', 'Dev mode must be on or off')
    local tester = ctx.tester
    local original = K.export(CORE, 'isDevMode', tester) == true
    ctx:cleanup(function() exports.kora_core:setDevMode(tester, original) end)
    local ok, err = K.export(CORE, 'setDevMode', tester, state == 'on')
    if not ok then error('setDevMode failed: ' .. tostring(err), 0) end
end)
K.step('the core should report my dev mode {word}', 'server', function(ctx, state)
    ctx:equal(K.export(CORE, 'isDevMode', ctx.tester), state == 'on', 'isDevMode')
end)
K.step('my client should report dev mode {word}', 'client', function(ctx, state)
    K.started(CORE)
    ctx:waitUntil(function() return exports.kora_core:isDevMode() == (state == 'on') end,
        'Client isDevMode never became ' .. state, 5000)
end)
-- Comma list of on/off in firing order; a repeated setting fires nothing.
K.step('the core should have announced my dev mode changes as {string}', 'server', function(ctx, list)
    local expected = itemList(list)
    ctx:waitUntil(function() return #K.captured(ctx, 'kora_core:server:devModeChanged') >= #expected end,
        'Fewer dev mode announcements than ' .. list, 3000)
    Wait(300)
    local actual = {}
    for _, record in ipairs(K.captured(ctx, 'kora_core:server:devModeChanged')) do
        actual[#actual + 1] = record[2] and 'on' or 'off'
    end
    ctx:equal(table.concat(actual, ','), table.concat(expected, ','), 'Dev mode announcements')
end)
K.step('the core should refuse to set my dev mode to the text {string} with {string}', 'server', function(ctx, value, reason)
    local tester = ctx.tester
    local original = K.export(CORE, 'isDevMode', tester) == true
    ctx:cleanup(function() exports.kora_core:setDevMode(tester, original) end)
    local ok, err = K.export(CORE, 'setDevMode', tester, value)
    refused('setDevMode "' .. value .. '"', ok, err, reason)
end)

-- ---------------------------------------------------------------------------
-- Jail (modules/jail/server.lua, client.lua). Config.jail: deferToResources
-- { 'xt-prison', 'qbx_prison' } and coords vector4(1651.86, 2570.13, 45.56)
-- (config.lua:78-81).
-- ---------------------------------------------------------------------------

local JAIL_DEFER = { 'xt-prison', 'qbx_prison' }
local JAIL_COORDS = { x = 1651.86, y = 2570.13, z = 45.56 }

local function restoreJail(ctx)
    local tester = ctx.tester
    local jailed = K.export(CORE, 'getMetaData', tester, 'jailed')
    local injail = K.export(CORE, 'getMetaData', tester, 'injail')
    ctx:cleanup(function()
        exports.kora_core:release(tester)
        exports.kora_core:setPath(tester, { 'metadata', 'jailed' }, jailed)
        exports.kora_core:setPath(tester, { 'metadata', 'injail' }, injail)
    end)
end
K.step('the core should refuse to jail me for {string} minutes with {string}', 'server', function(ctx, raw, reason)
    restoreJail(ctx)
    local ok, err = K.export(CORE, 'jailPlayer', ctx.tester, tonumber(raw) or raw, 'functional test')
    refused(('jailPlayer for "%s" minutes'):format(raw), ok, err, reason)
end)
K.step('the core should not hold me in jail', 'server', function(ctx)
    ctx:equal(K.export(CORE, 'isJailed', ctx.tester), false, 'isJailed')
    ctx:equal(K.export(CORE, 'getRemaining', ctx.tester), 0, 'getRemaining')
    ctx:equal(K.export(CORE, 'release', ctx.tester), false, 'release while free')
end)
K.step('the core jails me for {int} minute', 'server', function(ctx, minutes)
    assert(minutes == 1, 'Jail the tester for exactly 1 minute')
    for _, resource in ipairs(JAIL_DEFER) do
        assert(GetResourceState(resource) ~= 'started', resource .. ' is started; kora_core would defer the sentence to it')
    end
    assert(not K.export(CORE, 'isJailed', ctx.tester), 'The tester is already jailed')
    local tester = ctx.tester
    K.capture(ctx, 'kora_core:server:playerJailed', function(src) return src == tester end)
    K.capture(ctx, 'kora_core:server:playerReleased', function(src) return src == tester end)
    restoreJail(ctx)
    local ok, err = K.export(CORE, 'jailPlayer', tester, minutes, 'functional test')
    if not ok then error('jailPlayer failed: ' .. tostring(err), 0) end
end)
K.step('the core should hold me in jail for at most {int} seconds', 'server', function(ctx, seconds)
    ctx:equal(K.export(CORE, 'isJailed', ctx.tester), true, 'isJailed')
    local remaining = K.export(CORE, 'getRemaining', ctx.tester)
    assert(type(remaining) == 'number' and remaining > 0 and remaining <= seconds,
        ('getRemaining is %s, expected 1..%d'):format(tostring(remaining), seconds))
    local jailed = K.export(CORE, 'getMetaData', ctx.tester, 'jailed')
    ctx:equal(K.export(CORE, 'getMetaData', ctx.tester, 'injail'), jailed, 'metadata.injail matches metadata.jailed')
end)
K.step('the core should have announced that I was jailed for {int} minute', 'server', function(ctx, minutes)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, 'kora_core:server:playerJailed')) do
            if record[2] == minutes and record[3] == 'functional test' then return true end
        end
    end, 'No kora_core:server:playerJailed for ' .. minutes .. ' minute', 3000)
end)
K.step('the core releases me from jail', 'server', function(ctx)
    ctx:equal(K.export(CORE, 'release', ctx.tester), true, 'release')
end)
K.step('the core should have announced my release from jail', 'server', function(ctx)
    ctx:waitUntil(function() return #K.captured(ctx, 'kora_core:server:playerReleased') > 0 end,
        'No kora_core:server:playerReleased', 3000)
end)
-- Records where the ped stands and brings it back after the jail run. The
-- containment zone pulls the ped back while the sentence lasts, so the return
-- waits until the client mirror shows the sentence cleared.
local function jailCleared()
    local releaseAt = exports.kora_core:getPlayerData({ 'metadata', 'jailed' })
    return type(releaseAt) ~= 'number' or releaseAt == 0
end
local function returnFromJail(origin)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, origin.x, origin.y, origin.z, false, false, false)
    SetEntityHeading(ped, origin.h)
end
K.step('I will be brought back here after the core jail', 'client', function(ctx)
    K.started(CORE)
    local ped = PlayerPedId()
    assert(not IsPedInAnyVehicle(ped, false), 'Leave the vehicle first')
    local at = GetEntityCoords(ped)
    local origin = { x = at.x, y = at.y, z = at.z, h = GetEntityHeading(ped) }
    ctx.state.coreJailOrigin = origin
    ctx:cleanup(function()
        if ctx.state.coreJailReturned then return end
        local deadline = GetGameTimer() + 3000
        while not jailCleared() and GetGameTimer() < deadline do Wait(100) end
        Wait(500)
        returnFromJail(origin)
    end)
end)
K.step('I should be within {int} metres of the core jail', 'client', function(ctx, radius)
    ctx:waitUntil(function()
        local at = GetEntityCoords(PlayerPedId())
        return #(at - vector3(JAIL_COORDS.x, JAIL_COORDS.y, JAIL_COORDS.z)) <= radius
    end, ('Not within %d metres of the jail at %.2f %.2f %.2f'):format(radius, JAIL_COORDS.x, JAIL_COORDS.y, JAIL_COORDS.z), 5000)
end)
K.step('I return to where I stood before the core jail', 'client', function(ctx)
    local origin = assert(ctx.state.coreJailOrigin, 'Record the position before the jail first')
    ctx:waitUntil(jailCleared, 'The client mirror still shows a jail sentence', 5000)
    returnFromJail(origin)
    ctx.state.coreJailReturned = true
    ctx:waitUntil(function()
        local at = GetEntityCoords(PlayerPedId())
        return #(at - vector3(origin.x, origin.y, origin.z)) <= 5.0
    end, 'The ped was pulled away from its original position', 3000)
end)

-- ---------------------------------------------------------------------------
-- Transactions: reward-list refusals (transaction/server.lua:36-49).
-- ---------------------------------------------------------------------------

K.step('the core should refuse this reward transaction with {string}:', 'server', function(ctx, reason, argument)
    local tx = K.json(argument)
    assert(tx.random ~= nil, 'This step is for transactions with a random list')
    guardTransaction(ctx, tx, true)
    local ok, err = K.export(CORE, 'transaction', ctx.tester, tx)
    refused('the reward transaction', ok, err, reason)
end)

-- ---------------------------------------------------------------------------
-- Registries (modules/registry/server.lua, shared.lua). RI.create keys:
-- items name, vehicles model, jobs name, gangs name, weapons name, locations key.
-- ---------------------------------------------------------------------------

local REGISTRY_KEYS = { items = 'name', vehicles = 'model', jobs = 'name', gangs = 'name', weapons = 'name', locations = 'key' }

K.step('the core registry snapshot should describe every registry', 'server', function(ctx)
    local all = K.export(CORE, 'sharedSnapshotAll')
    assert(type(all) == 'table', 'sharedSnapshotAll returned nothing')
    for name, keyField in pairs(REGISTRY_KEYS) do
        local entry = all[name]
        assert(type(entry) == 'table', 'Snapshot has no registry ' .. name)
        ctx:equal(entry.keyField, keyField, 'Key field of ' .. name)
        assert(type(entry.epoch) == 'number', 'Snapshot epoch of ' .. name .. ' is not a number')
        local count = K.export(CORE, 'countShared', name)
        assert(count > 0, 'Registry ' .. name .. ' is empty')
        ctx:equal(#(entry.records or {}), count, 'Snapshot records of ' .. name)
        ctx:equal(#K.export(CORE, 'allShared', name), count, 'allShared length of ' .. name)
    end
    ctx:equal(K.export(CORE, 'countShared', 'fft_no_such_registry'), 0, 'countShared of an unknown registry')
    ctx:equal(#(K.export(CORE, 'allShared', 'fft_no_such_registry') or {}), 0, 'allShared of an unknown registry')
end)
K.step('the core location {string} should be labelled {string}', 'server', function(ctx, key, label)
    local record = K.export(CORE, 'getShared', 'locations', key)
    assert(type(record) == 'table', 'No location ' .. key)
    ctx:equal(record.key, key, 'Location key')
    ctx:equal(record.label, label, 'Location label')
    assert(type(record.x) == 'number' and type(record.y) == 'number' and type(record.z) == 'number', 'Location has no coordinates')
end)
-- Refused records must not reach the registry; an accepted one is removed at once.
local function refusedRecord(ctx, what, name, key, record, reason)
    local ok, err = K.export(CORE, 'registerShared', name, key, record)
    if ok then exports.kora_core:unregisterShared(name, key) end
    refused(what, ok, err, reason)
    ctx:equal(K.export(CORE, 'getShared', name, key), nil, 'Registry record ' .. tostring(key))
end
K.step('the core should refuse a shared location {string} that is not a table', 'server', function(ctx, key)
    assert(key:sub(1, 4) == 'fft_', 'Use an fft_ scratch key')
    refusedRecord(ctx, 'a text record', 'locations', key, 'not a table', 'record must be a table')
end)
K.step('the core should refuse a shared record for the unknown registry {string}', 'server', function(_, name)
    local ok, err = K.export(CORE, 'registerShared', name, 'fft_probe', { name = 'fft_probe' })
    refused('registerShared into ' .. name, ok, err, ('no registry named %q'):format(name))
end)
K.step('the core should refuse a location record keyed {string} under the key {string}', 'server', function(ctx, recordKey, key)
    assert(key:sub(1, 4) == 'fft_' and recordKey:sub(1, 4) == 'fft_', 'Use fft_ scratch keys')
    refusedRecord(ctx, 'a mismatched record', 'locations', key, { key = recordKey, label = 'FFT probe' },
        ('record.key (%s) does not match key (%s)'):format(recordKey, key))
    ctx:equal(K.export(CORE, 'getShared', 'locations', recordKey), nil, 'Registry record ' .. recordKey)
end)
K.step('the core should refuse to watch the registry {string} with {string}', 'server', function(_, name, reason)
    local useHandler = reason ~= 'handler must be callable'
    local id, err = K.export(CORE, 'onSharedChange', name, useHandler and function() end or 'not a function')
    if id then exports.kora_core:offSharedChange(name, id) end
    -- registry/server.lua:138-139 return nil, reason; with a callable handler an
    -- unknown registry is the only refusal left, without one the handler check is.
    refusedNil('onSharedChange ' .. name, id, err, reason)
end)
K.step('the core should refuse to unregister the unknown location {string}', 'server', function(ctx, key)
    assert(K.export(CORE, 'getShared', 'locations', key) == nil, 'Location ' .. key .. ' exists')
    ctx:equal(K.export(CORE, 'unregisterShared', 'locations', key), false, 'unregisterShared ' .. key)
end)
-- @global round trip: handler(action, key, record, previous).
K.step('I watch the core registry {string}', 'server', function(ctx, name)
    local seen = {}
    ctx.state.coreRegistrySeen = seen
    local id, err = K.export(CORE, 'onSharedChange', name, function(action, key, record)
        if type(key) ~= 'string' or key:sub(1, 4) ~= 'fft_' or #seen >= 50 then return end
        seen[#seen + 1] = { action = action, key = key, label = type(record) == 'table' and record.label or nil }
    end)
    if not id then error('onSharedChange failed: ' .. tostring(err), 0) end
    ctx:cleanup(function() exports.kora_core:offSharedChange(name, id) end)
end)
K.step('I remember the core registry count for {string}', 'server', function(ctx, name)
    ctx.state.coreRegistryCount = ctx.state.coreRegistryCount or {}
    ctx.state.coreRegistryCount[name] = K.export(CORE, 'countShared', name)
end)
K.step('the core registry {string} count should have changed by {int}', 'server', function(ctx, name, delta)
    local before = assert(ctx.state.coreRegistryCount and ctx.state.coreRegistryCount[name], 'Remember the registry count first')
    ctx:equal(K.export(CORE, 'countShared', name) - before, delta, 'Record count change of ' .. name)
end)
-- Coordinates are copied from an existing location, never made up.
K.step('the core registers the probe location {string} labelled {string} at the location {string}', 'server', function(ctx, key, label, source)
    assert(key:sub(1, 4) == 'fft_', 'Use an fft_ scratch key')
    local from = K.export(CORE, 'getShared', 'locations', source)
    assert(type(from) == 'table', 'No location ' .. source)
    ctx:cleanup(function()
        if exports.kora_core:getShared('locations', key) then exports.kora_core:unregisterShared('locations', key) end
    end)
    local ok, err = K.export(CORE, 'registerShared', 'locations', key, { key = key, label = label, x = from.x, y = from.y, z = from.z, h = from.h })
    if not ok then error('registerShared failed: ' .. tostring(err), 0) end
end)
K.step('the core unregisters the probe location {string}', 'server', function(ctx, key)
    assert(key:sub(1, 4) == 'fft_', 'Use an fft_ scratch key')
    ctx:equal(K.export(CORE, 'unregisterShared', 'locations', key), true, 'unregisterShared ' .. key)
end)
K.step('the core registry watch should have seen {word} of {string}', 'server', function(ctx, action, key)
    local seen = assert(ctx.state.coreRegistrySeen, 'Watch the registry first')
    ctx:waitUntil(function()
        for _, record in ipairs(seen) do
            if record.action == action and record.key == key then return true end
        end
    end, ('Registry watch never saw %s of %s'):format(action, key), 3000)
end)

-- ---------------------------------------------------------------------------
-- Identity, permissions, commands, logs and loops: read only.
-- Config.identity: primaryIdentifier 'license', citizenIdPrefix '' (config.lua:7-11).
-- ---------------------------------------------------------------------------

K.step('the core should find my citizen id by my primary identifier', 'server', function(ctx)
    local ids = K.export(CORE, 'getIdentifiers', ctx.tester)
    local license = type(ids) == 'table' and ids.license
    assert(type(license) == 'string' and license ~= '', 'The tester has no license identifier')
    local found = K.export(CORE, 'findByIdentifier', 'license', license)
    assert(includes(found, K.player(ctx).citizenid), 'findByIdentifier(license) does not include the tester citizenid')
end)
K.step('the core should find no citizen by the {word} identifier {string}', 'server', function(ctx, kind, value)
    local found = K.export(CORE, 'findByIdentifier', kind, value)
    ctx:equal(#(found or {}), 0, ('findByIdentifier(%s, %s)'):format(kind, value))
end)
K.step('the core should generate {int} distinct citizen ids shaped like mine', 'server', function(ctx, count)
    assert(count >= 2 and count <= 20, 'Generate 2-20 ids')
    local mine = K.player(ctx).citizenid
    local seen = {}
    for _ = 1, count do
        local id = K.export(CORE, 'generateCitizenId')
        assert(type(id) == 'string' and id:match('^[A-Z0-9]+$'), 'Malformed citizen id: ' .. tostring(id))
        ctx:equal(#id, #mine, 'Generated citizen id length')
        assert(not seen[id], 'generateCitizenId repeated ' .. id)
        seen[id] = true
    end
end)
-- isOptin is false for the 'user' level (permissions/server.lua:39-42), and
-- the user level holds none of the privileged permissions.
K.step('the core opt-in and privileged permissions should follow my level', 'server', function(ctx)
    local level = K.export(CORE, 'getPermission', ctx.tester)
    local optin = K.export(CORE, 'isOptin', ctx.tester)
    assert(type(optin) == 'boolean', 'isOptin did not return a boolean')
    if level == 'user' then
        ctx:equal(optin, false, 'isOptin for a user')
        for _, permission in ipairs({ 'god', 'admin', 'mod' }) do
            ctx:equal(K.export(CORE, 'hasPermission', ctx.tester, permission), false, 'hasPermission ' .. permission)
        end
    end
end)
K.step('the core should list the {string} command for {string}', 'server', function(ctx, name, permission)
    for _, command in ipairs(K.export(CORE, 'listCommands') or {}) do
        if command.name == name then
            ctx:equal(command.permission, permission, 'Permission of /' .. name)
            return
        end
    end
    error('listCommands does not list ' .. name, 0)
end)
K.step('the core log statistics and paycheck loop should be live', 'server', function(ctx)
    local stats = K.export(CORE, 'getLogStats')
    assert(type(stats) == 'table' and type(stats.counts) == 'table' and type(stats.ringSize) == 'number' and stats.ringSize >= 0,
        'getLogStats returned no { counts, ringSize }')
    ctx:equal(K.export(CORE, 'isPaycheckRunning'), true, 'isPaycheckRunning')
end)

-- ---------------------------------------------------------------------------
-- Pure utilities (modules/util/shared.lua).
-- ---------------------------------------------------------------------------

K.step('the core should round {float} to {float}', 'server', function(ctx, value, expected)
    local actual = K.export(CORE, 'round', value)
    assert(sameValue(actual, expected), ('round %s is %s, expected %s'):format(value, tostring(actual), expected))
end)
K.step('the core should round {float} to {int} places as {float}', 'server', function(ctx, value, places, expected)
    assert(sameValue(K.export(CORE, 'round', value, places), expected), ('round %s %d is %s'):format(value, places, tostring((K.export(CORE, 'round', value, places)))))
end)
K.step('the core should round a text value to 0', 'server', function(ctx)
    ctx:equal(K.export(CORE, 'round', 'not a number'), 0, 'round of text')
end)
K.step('the core should trim {string} to {string}', 'server', function(ctx, value, expected)
    ctx:equal(K.export(CORE, 'trim', value), expected, 'trim')
end)
K.step('the core should split {string} on {string} into {int} parts', 'server', function(ctx, value, delimiter, count)
    local parts = K.export(CORE, 'splitStr', value, delimiter)
    assert(type(parts) == 'table', 'splitStr returned nothing')
    ctx:equal(#parts, count, ('splitStr "%s" on "%s"'):format(value, delimiter))
    ctx:equal(table.concat(parts, delimiter), value, 'Rejoined parts')
end)
K.step('the core should make random {word} text of length {int}', 'server', function(ctx, kind, length)
    local spec = ({ letter = { 'randomStr', '^%u*$' }, digit = { 'randomInt', '^%d*$' }, alphanumeric = { 'randomAlnum', '^[%u%d]*$' } })[kind]
    assert(spec, 'Kind must be letter, digit or alphanumeric')
    local text = K.export(CORE, spec[1], length)
    assert(type(text) == 'string', spec[1] .. ' did not return text')
    ctx:equal(#text, length, spec[1] .. ' length')
    assert(text:match(spec[2]), ('%s returned "%s"'):format(spec[1], text))
end)
-- pathSet returns the previous value; deepClone keeps nested values.
K.step('the core should read, write and copy nested paths', 'server', function(ctx)
    local sample = { a = { b = 3, list = { 'x', 'y' } } }
    ctx:equal(K.export(CORE, 'pathGet', sample, { 'a', 'b' }), 3, 'pathGet a.b')
    ctx:equal(K.export(CORE, 'pathGet', sample, { 'a', 'list', 2 }), 'y', 'pathGet a.list.2')
    ctx:equal(K.export(CORE, 'pathGet', sample, { 'a', 'b', 'c' }), nil, 'pathGet through a number')
    ctx:equal(K.export(CORE, 'pathGet', sample, { 'missing', 'b' }), nil, 'pathGet missing')
    ctx:equal(K.export(CORE, 'pathSet', sample, { 'a', 'b' }, 4), 3, 'pathSet previous value')
    ctx:equal(K.export(CORE, 'pathSet', sample, { 'new', 'leaf' }, 1), nil, 'pathSet previous value of a new path')
    local copy = K.export(CORE, 'deepClone', sample)
    assert(type(copy) == 'table' and type(copy.a) == 'table', 'deepClone returned no table')
    ctx:equal(copy.a.b, 3, 'deepClone a.b')
    ctx:equal(copy.a.list[2], 'y', 'deepClone a.list.2')
    ctx:equal(K.export(CORE, 'deepClone', 'text'), 'text', 'deepClone of text')
end)

-- ---------------------------------------------------------------------------
-- Every vehicle model the game knows must be in the shared vehicles registry.
-- GetAllVehicleModels is a client native ("all registered vehicle model names,
-- including non-dlc and custom vehicles"), so this runs on the client. The
-- registry (shared/vehicles.lua, keyed by `model`) is read through allShared.
-- Read only; nothing is spawned or changed.
-- ---------------------------------------------------------------------------

K.step('every registered vehicle model should be in the shared vehicles list', 'client', function(ctx)
    local models = GetAllVehicleModels()
    assert(type(models) == 'table' and #models > 0, 'GetAllVehicleModels returned no models')

    local list = K.export(CORE, 'allShared', 'vehicles')
    assert(type(list) == 'table' and #list > 0, 'allShared returned no vehicles')
    local known = {}
    for _, record in ipairs(list) do
        if type(record) == 'table' and type(record.model) == 'string' then
            known[record.model:lower()] = true
        end
    end

    local missing, seen = {}, {}
    for _, model in ipairs(models) do
        local name = tostring(model):lower()
        if not seen[name] then
            seen[name] = true
            if not known[name] then missing[#missing + 1] = name end
        end
    end
    if #missing == 0 then return end

    table.sort(missing)
    local shown = {}
    for index = 1, math.min(#missing, 40) do shown[index] = missing[index] end
    error(('%d of %d vehicle models are not in the shared vehicles list: %s%s'):format(
        #missing, #models, table.concat(shown, ', '),
        #missing > #shown and (' ... and %d more'):format(#missing - #shown) or ''), 0)
end)
