-- kora_banking: bank counter and ATM AppShell app (kora_banking:bank) plus the
-- society-account exports.
-- No resource hook: the counter and ATM are kora_target options, the app is a
-- kora_lib AppShell app driven through kora_lib's hook, and the account exports
-- are authoritative. Only refusals are asserted on society accounts: a credit
-- or debit there is money other players can see and writes a statement row
-- that has no delete API.
local K = FFT.kora
if not K then return end
K.feature('kora_banking')

-- roundAmount() in kora_banking/server.lua accepts at most this amount, so a
-- debit of it is refused by the guarded UPDATE unless a society really holds it.
local LARGEST_AMOUNT = 1000000000

local function account(name)
    return K.export('kora_banking', 'GetAccount', name)
end

local function balance(name)
    return K.export('kora_banking', 'GetAccountBalance', name)
end

K.step('the bank should hold a society account for {string}', 'server', function(ctx, name)
    local row = account(name)
    assert(type(row) == 'table', 'No bank account named ' .. name)
    ctx:equal(row.account_type, 'job', 'Account type of ' .. name)
    local held = balance(name)
    assert(type(held) == 'number' and held >= 0, 'Society balance is not a non-negative number: ' .. tostring(held))
end)

K.step('the bank should hold no account named {string}', 'server', function(ctx, name)
    ctx:equal(account(name), nil, 'Account ' .. name)
    ctx:equal(balance(name), 0, 'Balance reported for a missing account')
end)

K.step('I remember the bank balance of the account {string}', 'server', function(ctx, name)
    ctx.state.bankAccounts = ctx.state.bankAccounts or {}
    ctx.state.bankAccounts[name] = balance(name)
end)

K.step('the bank balance of the account {string} should be unchanged', 'server', function(ctx, name)
    local before = assert(ctx.state.bankAccounts and ctx.state.bankAccounts[name], 'Remember the account balance first')
    ctx:equal(balance(name), before, 'Balance of ' .. name)
end)

-- AddMoney: amount 0, a negative amount and an unknown account all return
-- false before any UPDATE (roundAmount / adjustAccount in server.lua).
K.step('crediting the bank account {string} with {int} should be refused', 'server', function(_, name, amount)
    local existed = account(name) ~= nil
    local ok = K.export('kora_banking', 'AddMoney', name, amount, 'functional test')
    if ok then
        -- Only reachable when the rule under test is broken: put the money back.
        if existed then pcall(function() exports.kora_banking:RemoveMoney(name, amount, 'functional test rollback') end) end
        error(('AddMoney accepted %d for %s'):format(amount, name), 0)
    end
end)

K.step('debiting the bank account {string} beyond its balance should be refused', 'server', function(_, name)
    local held = balance(name)
    assert(held < LARGEST_AMOUNT, 'Account holds too much to prove an overdraft refusal safely')
    local ok = K.export('kora_banking', 'RemoveMoney', name, LARGEST_AMOUNT, 'functional test')
    if ok then
        pcall(function() exports.kora_banking:AddMoney(name, LARGEST_AMOUNT, 'functional test rollback') end)
        error('RemoveMoney overdrew ' .. name, 0)
    end
end)

-- Client: a correct PIN makes banking:unlock answer with an app update whose
-- default view is the cash view (appUpdate() in kora_banking/client.lua).
-- kora_lib returns a merged update as `result.app`; a wrong PIN answers with a
-- destructive notice and no update.
K.step('the ATM should have unlocked its cash view', 'client', function(ctx)
    local app = (ctx.state.appResult or {}).app
    assert(type(app) == 'table', 'The ATM did not answer the PIN with an app update')
    ctx:equal(app.title, 'Kora ATM', 'Unlocked app title')
    ctx:equal(app.defaultView, 'cash', 'Unlocked default view')
end)
K.step('the ATM should have stayed locked', 'client', function(ctx)
    ctx:equal((ctx.state.appResult or {}).app, nil, 'App update after a wrong PIN')
end)

-- ---------------------------------------------------------------------------
-- Server: more export and account-row checks (kora_banking/server.lua,
-- server/finance.lua). Read-only, or refusals only.
-- ---------------------------------------------------------------------------

-- The startup thread in server.lua creates a 'gang' account for every gang in
-- kora_core's shared gangs list (except 'none').
K.step('the bank should hold a gang account for {string}', 'server', function(ctx, name)
    local row = account(name)
    assert(type(row) == 'table', 'No bank account named ' .. name)
    ctx:equal(row.account_type, 'gang', 'Account type of ' .. name)
end)

-- addMoney/removeMoney run roundAmount(), which floors before the range check:
-- 0.5 floors to 0 and is refused like any non-positive amount.
K.step('crediting the bank account {string} with half a dollar should be refused', 'server', function(_, name)
    local ok = K.export('kora_banking', 'AddMoney', name, 0.5, 'functional test')
    if ok then error('AddMoney accepted 0.5 for ' .. name, 0) end
end)
K.step('debiting the bank account {string} with {int} should be refused', 'server', function(_, name, amount)
    local existed = account(name) ~= nil
    local ok = K.export('kora_banking', 'RemoveMoney', name, amount, 'functional test')
    if ok then
        if existed then pcall(function() exports.kora_banking:AddMoney(name, amount, 'functional test rollback') end) end
        error(('RemoveMoney accepted %d for %s'):format(amount, name), 0)
    end
end)

-- server/finance.lua: caller() only accepts resources listed in
-- Config.transactionCallers (kora_housing); fft is not one of them.
K.step('the durable banking exports should refuse this resource', 'server', function(ctx)
    -- server/finance.lua returns false, code, message across the export (a leading
    -- nil would drop the code and message on the way back).
    local result, code, message = K.export('kora_banking', 'ExecuteTransaction', 'fft-functional-test', { kind = 'noop' })
    ctx:equal(result, false, 'ExecuteTransaction result')
    ctx:equal(code, 'rejected', 'ExecuteTransaction code')
    ctx:equal(message, 'This resource cannot execute durable banking operations.', 'ExecuteTransaction message')
    result, code, message = K.export('kora_banking', 'GetOperation', 'fft-functional-test')
    ctx:equal(result, false, 'GetOperation result')
    ctx:equal(code, 'rejected', 'GetOperation code')
    ctx:equal(message, 'This resource cannot read banking operations.', 'GetOperation message')
end)

-- Shared accounts: createAccount(name, amount, 'shared', citizenid, '[]') in
-- manage(); the users column is a JSON list of member citizen IDs.
K.step('the bank should hold a shared account {string} owned by me with {int}', 'server', function(ctx, name, amount)
    local citizenid = K.player(ctx).citizenid
    ctx:waitUntil(function()
        local row = account(name)
        return type(row) == 'table' and row.account_type == 'shared' and row.citizenid == citizenid and balance(name) == amount
    end, ('No shared account %s owned by the tester holding %d (balance %s)'):format(name, amount, tostring(balance(name))), 3000)
end)

local function members(name)
    local row = account(name)
    assert(type(row) == 'table', 'No bank account named ' .. name)
    local list = type(row.users) == 'string' and json.decode(row.users) or row.users
    return type(list) == 'table' and list or {}
end
local function isListed(list, citizenid)
    for _, value in ipairs(list) do if value == citizenid then return true end end
    return false
end
K.step('the bank should list me as a member of {string}', 'server', function(ctx, name)
    assert(isListed(members(name), K.player(ctx).citizenid), 'The tester is not in the users list of ' .. name)
end)
K.step('the bank should not list me as a member of {string}', 'server', function(ctx, name)
    assert(not isListed(members(name), K.player(ctx).citizenid), 'The tester is still in the users list of ' .. name)
end)

-- ---------------------------------------------------------------------------
-- Client: banking's own request channel.
-- client.lua request(): TriggerServerEvent('kora_banking:server:request',
-- requestId, operation, ...); server.lua answers with
-- TriggerClientEvent('kora_banking:client:response', src, requestId, result, err)
-- for the operations 'open' (mode, location), 'atmCard' (location?), 'pin'
-- (pin) and 'action' (payload); anything else answers 'Invalid banking request.'.
-- These steps send exactly what the banking client sends, so the server's own
-- session, distance, card, PIN and amount checks decide every answer. Request
-- ids start far above banking's own counter (which starts at 1), and banking's
-- client ignores ids it has no pending request for.
-- ---------------------------------------------------------------------------

local REQUEST_BASE = 2000000000
local requestSerial = 0
local REQUEST_TIMEOUT = 5000

-- Waits at most `timeout` ms; safe in cleanup (no ctx calls).
local function bankRequest(timeout, operation, ...)
    requestSerial = requestSerial % 100000000 + 1
    local id = REQUEST_BASE + requestSerial
    local box = {}
    RegisterNetEvent('kora_banking:client:response')
    local handle = AddEventHandler('kora_banking:client:response', function(requestId, result, err)
        if requestId == id then box.done, box.result, box.err = true, result, err end
    end)
    TriggerServerEvent('kora_banking:server:request', id, operation, ...)
    local deadline = GetGameTimer() + timeout
    while not box.done and GetGameTimer() < deadline do Wait(25) end
    RemoveEventHandler(handle)
    return box.done == true, box.result, box.err
end

local function closeSession() TriggerServerEvent('kora_banking:close') end

-- Sends a request from a step and records the answer as ctx.state.bankAnswer.
local function ask(ctx, operation, ...)
    K.started('kora_banking')
    local done, result, err = bankRequest(REQUEST_TIMEOUT, operation, ...)
    ctx:check()
    assert(done, ('kora_banking did not answer the %s request'):format(tostring(operation)))
    ctx.state.bankAnswer = { result = result, err = err }
    return result, err
end

local function answer(ctx)
    return assert(ctx.state.bankAnswer, 'Send a banking request first')
end

local function refusedWith(ctx, text)
    local reply = answer(ctx)
    assert(not reply.result, ('The bank accepted the request (%s); expected "%s"')
        :format(type(reply.result) == 'table' and tostring(reply.result.message or 'snapshot') or tostring(reply.result), text))
    ctx:equal(reply.err, text, 'Bank refusal')
end

-- A session the steps open is closed in cleanup, like closeSession() in client.lua.
local function opened(ctx, result, err, what)
    assert(type(result) == 'table', ('The bank refused to open %s: %s'):format(what, tostring(err)))
    ctx.state.bankSnapshot = result
    if not ctx.state.bankSessionCleanup then
        ctx.state.bankSessionCleanup = true
        ctx:cleanup(closeSession)
    end
end

local function point(x, y, z) return { x = x, y = y, z = z } end

-- Counter: openBanking(src, 'bank', index) needs Config.locations[index] to
-- exist and the player within BRANCH_RANGE (3.0) of the nearest location.
K.step('I open a bank counter session for location {int}', 'client', function(ctx, index)
    local result, err = ask(ctx, 'open', 'bank', index)
    opened(ctx, result, err, 'the counter')
end)
K.step('opening a bank counter session for location {int} should be refused with {string}', 'client', function(ctx, index, text)
    ctx:cleanup(closeSession)
    ask(ctx, 'open', 'bank', index)
    refusedWith(ctx, text)
end)

-- ATM: openBanking(src, 'atm', location) checks the card first, then nearAtm()
-- (atmDistance 1.8 + atmTolerance 1.0 from the given coordinates).
K.step('I open an ATM session at {float} {float} {float}', 'client', function(ctx, x, y, z)
    local result, err = ask(ctx, 'open', 'atm', point(x, y, z))
    opened(ctx, result, err, 'the ATM')
end)
K.step('opening an ATM session at {float} {float} {float} should be refused with {string}', 'client', function(ctx, x, y, z, text)
    ctx:cleanup(closeSession)
    ask(ctx, 'open', 'atm', point(x, y, z))
    refusedWith(ctx, text)
end)

-- atmCardCallback(src, location): card first, then distance when a location is given.
K.step('the bank card check at {float} {float} {float} should pass', 'client', function(ctx, x, y, z)
    local result, err = ask(ctx, 'atmCard', point(x, y, z))
    assert(result == true, 'Card check refused: ' .. tostring(err))
end)
K.step('the bank card check at {float} {float} {float} should be refused with {string}', 'client', function(ctx, x, y, z, text)
    ask(ctx, 'atmCard', point(x, y, z))
    refusedWith(ctx, text)
end)
K.step('the bank card check without a position should pass', 'client', function(ctx)
    local result, err = ask(ctx, 'atmCard')
    assert(result == true, 'Card check refused: ' .. tostring(err))
end)
K.step('the bank card check without a position should be refused with {string}', 'client', function(ctx, text)
    ask(ctx, 'atmCard')
    refusedWith(ctx, text)
end)

-- pinCallback(src, pin): a correct PIN answers the unlocked ATM snapshot.
K.step('I enter the ATM PIN {string}', 'client', function(ctx, pin)
    local result = ask(ctx, 'pin', pin)
    if type(result) == 'table' then ctx.state.bankSnapshot = result end
end)

-- Payload placeholders: "$citizenid" is the tester's citizen ID and
-- "$reference" a per-scenario random statement reason, so a statement row can
-- be told apart from older rows (bank statements are never deleted).
local function reference(ctx)
    ctx.state.bankReference = ctx.state.bankReference or ('fft ref %d'):format(math.random(100000, 999999))
    return ctx.state.bankReference
end
local function citizenId()
    local id = exports.kora_core:getPlayerData({ 'citizenid' })
    assert(type(id) == 'string' and id ~= '', 'Client player data has no citizen ID')
    return id
end
local function fillPayload(ctx, payload)
    for key, value in pairs(payload) do
        if value == '$citizenid' then payload[key] = citizenId()
        elseif value == '$reference' then payload[key] = reference(ctx) end
    end
    return payload
end

-- actionCallback(src, payload) -> { message, snapshot } or nil, err.
local function sendAction(ctx, payload)
    local result = ask(ctx, 'action', payload)
    if type(result) == 'table' and type(result.snapshot) == 'table' then ctx.state.bankSnapshot = result.snapshot end
end
K.step('I send the banking action:', 'client', function(ctx, argument)
    local payload = K.json(argument)
    assert(type(payload) == 'table', 'The banking action must be a JSON object')
    sendAction(ctx, fillPayload(ctx, payload))
end)
K.step('I send a banking action that is not a table', 'client', function(ctx)
    ask(ctx, 'action', 'deposit')
end)
K.step('I send the banking request {string}', 'client', function(ctx, operation)
    ask(ctx, operation)
end)
-- The memberRateLimit check runs before anything else in addMember/removeMember.
K.step('sending the banking action {int} times should be refused each time with {string}:', 'client', function(ctx, times, text, argument)
    assert(times >= 1 and times <= 10, 'Send the action 1-10 times')
    local payload = K.json(argument)
    for attempt = 1, times do
        ask(ctx, 'action', fillPayload(ctx, payload))
        local reply = answer(ctx)
        assert(not reply.result and reply.err == text,
            ('Attempt %d answered "%s", expected "%s"'):format(attempt, tostring(reply.err or 'success'), text))
    end
end)
-- Net events from one client reach the server in order, so the next request
-- already sees the session gone (RegisterNetEvent('kora_banking:close')).
K.step('I close my banking session', 'client', function() closeSession() end)

K.step('the bank should refuse with {string}', 'client', function(ctx, text) refusedWith(ctx, text) end)
K.step('the bank should answer {string}', 'client', function(ctx, text)
    local reply = answer(ctx)
    assert(type(reply.result) == 'table', 'The bank refused: ' .. tostring(reply.err))
    ctx:equal(reply.result.message, text, 'Bank answer')
    assert(type(reply.result.snapshot) == 'table', 'The answer carried no account snapshot')
end)

-- ---------------------------------------------------------------------------
-- Client: assertions on the last snapshot (snapshot() in server.lua).
-- ---------------------------------------------------------------------------

local function snapshot(ctx)
    return assert(ctx.state.bankSnapshot, 'Open a banking session first')
end
local function row(ctx, name)
    for _, entry in ipairs(snapshot(ctx).accounts or {}) do
        if entry.name == name then return entry end
    end
end

K.step('the bank snapshot should be for a counter session', 'client', function(ctx)
    local data = snapshot(ctx)
    ctx:equal(data.mode, 'bank', 'Snapshot mode')
    ctx:equal(data.locked, false, 'Snapshot locked')
end)
-- A locked ATM snapshot is built with unlocked = false: no accounts, no history.
K.step('the ATM session should be locked', 'client', function(ctx)
    local data = snapshot(ctx)
    ctx:equal(data.mode, 'atm', 'Snapshot mode')
    ctx:equal(data.locked, true, 'Snapshot locked')
    ctx:equal(#(data.accounts or {}), 0, 'Accounts shown by a locked ATM')
    ctx:equal(next(data.transactions or {}), nil, 'Statements shown by a locked ATM')
end)
-- accountRows(data, 'atm') returns the personal account only.
K.step('the ATM session should be unlocked', 'client', function(ctx)
    local reply = answer(ctx)
    assert(type(reply.result) == 'table', 'The ATM refused the PIN: ' .. tostring(reply.err))
    local data = snapshot(ctx)
    ctx:equal(data.mode, 'atm', 'Snapshot mode')
    ctx:equal(data.locked, false, 'Snapshot locked')
end)
K.step('the bank snapshot should list only my personal account', 'client', function(ctx)
    local accounts = snapshot(ctx).accounts or {}
    ctx:equal(#accounts, 1, 'Accounts listed')
    ctx:equal(accounts[1].name, 'checking', 'Only account')
end)
K.step('the bank snapshot should list the account {string}', 'client', function(ctx, name)
    assert(row(ctx, name), 'The snapshot does not list ' .. name)
end)
K.step('the bank snapshot should not list the account {string}', 'client', function(ctx, name)
    assert(not row(ctx, name), 'The snapshot lists ' .. name)
end)
-- Labels from accountRows(): 'Personal bank', 'Society bank', 'Gang bank', 'Shared bank'.
K.step('the bank snapshot account {string} should be a {string} account labelled {string}', 'client', function(ctx, name, kind, label)
    local entry = assert(row(ctx, name), 'The snapshot does not list ' .. name)
    ctx:equal(entry.type, kind, 'Account type of ' .. name)
    ctx:equal(entry.label, label, 'Account label of ' .. name)
end)
K.step('the bank snapshot should let me manage the account {string}', 'client', function(ctx, name)
    local entry = assert(row(ctx, name), 'The snapshot does not list ' .. name)
    ctx:equal(entry.canManage, true, 'canManage of ' .. name)
end)
K.step('the bank snapshot should not let me manage the account {string}', 'client', function(ctx, name)
    local entry = assert(row(ctx, name), 'The snapshot does not list ' .. name)
    ctx:equal(entry.canManage, false, 'canManage of ' .. name)
end)
K.step('the bank snapshot should show {int} in the account {string}', 'client', function(ctx, amount, name)
    local entry = assert(row(ctx, name), 'The snapshot does not list ' .. name)
    ctx:equal(tonumber(entry.balance), amount, 'Balance of ' .. name)
end)
K.step('the bank snapshot should show {int} cash', 'client', function(ctx, amount)
    ctx:equal(tonumber((snapshot(ctx).profile or {}).cash), amount, 'Cash in the snapshot profile')
end)
K.step('the bank snapshot should show my citizen ID as the account number', 'client', function(ctx)
    ctx:equal((snapshot(ctx).profile or {}).accountNumber, citizenId(), 'Profile account number')
end)
-- cardRows(): one row per bank_card item, number masked as '**** 1234'.
K.step('the bank snapshot should list {int} bank cards', 'client', function(ctx, count)
    local cards = (snapshot(ctx).profile or {}).cards or {}
    ctx:equal(#cards, count, 'Bank cards in the snapshot')
    for _, card in ipairs(cards) do
        assert(type(card.number) == 'string' and card.number:match('^%*%*%*%* %d%d%d%d$'),
            'Card number is not masked to its last four digits: ' .. tostring(card.number))
    end
end)
-- limits in snapshot(): Config.dailyLimit 5000, maxAccounts 2, minAmount all 1;
-- maxTransfer and counterDaily are nil while tiers are disabled.
K.step('the bank snapshot should report the configured limits', 'client', function(ctx)
    local data = snapshot(ctx)
    local limits = assert(data.limits, 'The snapshot has no limits')
    ctx:equal(limits.maxAccounts, 2, 'maxAccounts')
    ctx:equal((limits.min or {}).withdraw, 1, 'Minimum withdrawal')
    ctx:equal((limits.min or {}).deposit, 1, 'Minimum deposit')
    ctx:equal((limits.min or {}).transfer, 1, 'Minimum transfer')
    assert(type(limits.daily) == 'number' and limits.daily >= 0 and limits.daily <= 5000,
        'Daily ATM allowance out of range: ' .. tostring(limits.daily))
    ctx:equal(limits.maxTransfer, nil, 'maxTransfer with tiers disabled')
    ctx:equal(limits.counterDaily, nil, 'counterDaily with tiers disabled')
    ctx:equal(data.branch, nil, 'Branch info with tiers disabled')
    ctx:equal(type(data.transactions), 'table', 'Transactions type')
end)
K.step('the bank snapshot should allow at least {int} more ATM withdrawal today', 'client', function(ctx, amount)
    local daily = (snapshot(ctx).limits or {}).daily
    assert(type(daily) == 'number' and daily >= amount,
        ('Only %s of today\'s ATM allowance is left; this scenario needs %d'):format(tostring(daily), amount))
end)
-- dailyWithdrawalRemaining(): 5000 minus today's checking 'withdraw' statements.
K.step('I remember my ATM allowance', 'client', function(ctx)
    local daily = (snapshot(ctx).limits or {}).daily
    assert(type(daily) == 'number', 'The snapshot has no daily allowance')
    ctx.state.bankAllowance = daily
end)
K.step('my ATM allowance should have dropped by {int}', 'client', function(ctx, amount)
    local before = assert(ctx.state.bankAllowance, 'Remember the ATM allowance first')
    local daily = (snapshot(ctx).limits or {}).daily
    ctx:equal(daily, math.max(0, before - amount), 'ATM allowance after the withdrawal')
end)
K.step('my ATM allowance should be unchanged', 'client', function(ctx)
    local before = assert(ctx.state.bankAllowance, 'Remember the ATM allowance first')
    ctx:equal((snapshot(ctx).limits or {}).daily, before, 'ATM allowance')
end)
-- transactionRows(): newest 50 statements per listed account.
K.step('the bank snapshot should record a {string} of {int} on {string} with my reference', 'client', function(ctx, kind, amount, name)
    local wanted = assert(ctx.state.bankReference, 'No action used "$reference"')
    for _, entry in ipairs((snapshot(ctx).transactions or {})[name] or {}) do
        if entry.reason == wanted and entry.statement_type == kind and tonumber(entry.amount) == amount then return end
    end
    error(('No %s statement of %d on %s with reason "%s"'):format(kind, amount, name, wanted), 0)
end)

-- ---------------------------------------------------------------------------
-- Client: shared-account hygiene. Only accounts named "fft..." are closed;
-- any other shared account the tester owns is reported, never touched.
-- Uses the same counter session, internal transfer and 'delete' action a
-- player would (manage() in server.lua refuses to close a funded account).
-- ---------------------------------------------------------------------------

local function ours(name) return type(name) == 'string' and name:lower():sub(1, 3) == 'fft' end

-- Returns the owned shared accounts left afterwards, or nil, err.
local function sweepShared(budget)
    local deadline = GetGameTimer() + budget
    local function left() return math.max(200, math.min(1500, deadline - GetGameTimer())) end
    local done, data, err = bankRequest(left(), 'open', 'bank', 1)
    if not done or type(data) ~= 'table' then return nil, 'counter session: ' .. tostring(err or 'no answer') end
    local remaining = {}
    for _, entry in ipairs(data.accounts or {}) do
        if entry.type == 'shared' and entry.canManage == true then
            local closed = false
            if ours(entry.name) and GetGameTimer() < deadline then
                local funds = math.floor(tonumber(entry.balance) or 0)
                if funds > 0 then
                    bankRequest(left(), 'action', { kind = 'transfer', from = entry.name, to = 'checking', amount = funds, reason = 'fft cleanup' })
                end
                local _, result = bankRequest(left(), 'action', { kind = 'delete', account = entry.name })
                closed = type(result) == 'table'
            end
            if not closed then remaining[#remaining + 1] = entry.name end
        end
    end
    closeSession()
    return remaining
end

-- Needs the tester at the branch counter of Config.locations[1].
K.step('I own no shared bank accounts', 'client', function(ctx)
    K.started('kora_banking')
    ctx:cleanup(function() sweepShared(4000) end)
    local remaining, err = sweepShared(8000)
    ctx:check()
    assert(remaining, 'Could not check the shared accounts: ' .. tostring(err))
    assert(#remaining == 0, 'The test character still owns shared accounts: ' .. table.concat(remaining, ', '))
end)

-- ---------------------------------------------------------------------------
-- Client: the AppShell app itself (client.lua appDefinition()/onAction).
-- ---------------------------------------------------------------------------

-- Counter opens at viewId 'accounts', a locked ATM at 'unlock' (open() in client.lua).
K.step('the bank app should be showing the {string} view', 'client', function(ctx, view)
    ctx:waitUntil(function()
        local app = K.uiState().app
        return app and app.id == 'kora_banking:bank' and app.viewId == view
    end, 'The bank app is not showing the view ' .. view, 3000)
end)
-- banking:select-account raises 'That account is no longer available.' for an
-- id the snapshot does not list; kora_lib reports a raised action as rejected.
K.step('selecting the account {string} in the bank app should be refused', 'client', function(_, name)
    local ok, err, code = K.ui('app.action', 'banking:select-account', { itemId = name })
    assert(not ok, 'The bank app selected ' .. name)
    assert(code == 'rejected', 'Selecting failed for another reason: ' .. tostring(err))
end)
-- appUpdate(): title 'Kora Bank' / 'Kora ATM', defaultView 'accounts' / 'cash'.
K.step('the bank app should have refreshed as {string} with default view {string}', 'client', function(ctx, title, view)
    local app = (ctx.state.appResult or {}).app
    assert(type(app) == 'table', 'The bank app did not answer with an update')
    ctx:equal(app.title, title, 'App title')
    ctx:equal(app.defaultView, view, 'Default view')
end)
