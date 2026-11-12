-- kora_bossmenu: management app (kora_bossmenu:management), job applications and
-- the business-money exports.
-- No resource hook: the menu is a kora_lib AppShell app and the application
-- form a kora_lib input dialog, both driven through kora_lib's hook; the
-- client exports openBossMenu / openApplication are the same entry points the
-- target zones call.
--
-- The tester is the only subject. Steps that name an employee or applicant use
-- the tester's own citizenid, and no step can pay a bonus or hire anyone.
-- Society money is never moved: only refusals of the money exports are asserted.
local K = FFT.kora
if not K then return end
K.feature('kora_bossmenu')

local APP = 'kora_bossmenu:management'
local MAX_QUESTIONS = 20 -- Config.maxQuestions in kora_bossmenu/shared.lua
-- Navigation ids that carry a badge count (appDefinition() in client/main.lua).
local COUNTED = { applicants = true, employees = true, questions = true, activity = true }
-- Actions that may be aimed at the tester. boss:accept is absent on purpose.
local ON_MYSELF = { ['boss:bonus'] = true, ['boss:rank'] = true, ['boss:fire'] = true, ['boss:deny'] = true }

-- ---------------------------------------------------------------------------
-- Server: business-money exports
-- ---------------------------------------------------------------------------

K.step('the boss menu business balance of {string} should match its bank account', 'server', function(ctx, name)
    K.started('kora_banking')
    local held = K.export('kora_bossmenu', 'getBusinessBalance', name)
    assert(type(held) == 'number', 'getBusinessBalance returned ' .. tostring(held))
    ctx:equal(held, K.export('kora_banking', 'GetAccountBalance', name), 'Business balance of ' .. name)
    ctx:equal(K.export('kora_bossmenu', 'GetAccount', name), held, 'Legacy GetAccount for ' .. name)
end)

K.step('the boss menu should know no business called {string}', 'server', function(ctx, name)
    local held, why = K.export('kora_bossmenu', 'getBusinessBalance', name)
    ctx:equal(held, nil, 'Balance of an unknown business')
    -- getBusinessBalance returns nil, 'unknown job'; FiveM exports drop values after a leading nil.
    if why ~= nil then ctx:equal(why, 'unknown job', 'Refusal reason') end
    ctx:equal(K.export('kora_bossmenu', 'GetAccount', name), 0, 'Legacy GetAccount for an unknown business')
end)

-- credit()/debit() in server/main.lua refuse an unknown job and a non-positive
-- amount before touching the bank or the audit log.
K.step('paying {int} into the boss menu business {string} should be refused with {string}', 'server', function(ctx, amount, name, reason)
    local ok, why = K.export('kora_bossmenu', 'addBusinessMoney', name, amount, 'functional test')
    if ok then
        pcall(function() exports.kora_bossmenu:removeBusinessMoney(name, amount, 'functional test rollback') end)
        error(('addBusinessMoney accepted %d for %s'):format(amount, name), 0)
    end
    ctx:equal(why, reason, 'Refusal reason')
end)

K.step('taking {int} out of the boss menu business {string} should be refused with {string}', 'server', function(ctx, amount, name, reason)
    local ok, why = K.export('kora_bossmenu', 'removeBusinessMoney', name, amount, 'functional test')
    if ok then
        pcall(function() exports.kora_bossmenu:addBusinessMoney(name, amount, 'functional test rollback') end)
        error(('removeBusinessMoney accepted %d for %s'):format(amount, name), 0)
    end
    ctx:equal(why, reason, 'Refusal reason')
end)

-- ---------------------------------------------------------------------------
-- Client: management app
-- ---------------------------------------------------------------------------

local function myCitizenId()
    local id = exports.kora_core:getPlayerData({ 'citizenid' })
    assert(type(id) == 'string' and id ~= '', 'My citizenid is unavailable')
    return id
end

local function requireMenu()
    local app = K.uiState().app
    assert(app and app.id == APP, 'The boss menu is not open')
end

local function act(ctx, actionId, context)
    requireMenu()
    local _, result = K.must(K.ui('app.action', actionId, context))
    ctx.state.appResult = type(result) == 'table' and result or {}
    -- A saved change answers with the refreshed navigation; keep the newest.
    local update = ctx.state.appResult.app
    if type(update) == 'table' and type(update.navigation) == 'table' then ctx.state.bossNavigation = update.navigation end
    return ctx.state.appResult
end

-- Badge count of a navigation entry: from the newest saved change, else from
-- the definition the menu was opened with.
local function count(ctx, id)
    assert(COUNTED[id], id .. ' is not a counted boss menu section')
    local navigation = ctx.state.bossNavigation
    if not navigation then
        local payload = K.ui('app')
        navigation = type(payload) == 'table' and type(payload.app) == 'table' and payload.app.navigation or nil
    end
    assert(type(navigation) == 'table', 'The boss menu navigation is unavailable')
    for _, entry in ipairs(navigation) do
        if type(entry) == 'table' and entry.id == id then
            return assert(tonumber(entry.badge), 'Boss menu section has no count: ' .. id)
        end
    end
    error('Boss menu has no section ' .. id, 0)
end

K.step('I open the boss menu for my job', 'client', function(ctx)
    K.started('kora_bossmenu')
    ctx.state.bossNavigation = nil
    exports.kora_bossmenu:openBossMenu()
end)

-- A non-boss with no gang is answered "Unknown organization." (the server
-- falls through to the gang role); one with a gang gets the boss refusal.
K.step('the boss menu should have refused to open', 'client', function(ctx)
    ctx:waitUntil(function()
        for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            if K.contains(entry.message, 'Unknown organization') or K.contains(entry.message, 'not a boss') then return true end
        end
    end, 'The boss menu did not refuse with "Unknown organization." or a boss refusal', 8000)
    local app = K.uiState().app
    assert(not (app and app.id == APP), 'The boss menu opened')
end)

K.step('I remember the boss menu count of {string}', 'client', function(ctx, id)
    ctx.state.bossCounts = ctx.state.bossCounts or {}
    ctx.state.bossCounts[id] = count(ctx, id)
end)

K.step('the boss menu count of {string} should have changed by {int}', 'client', function(ctx, id, delta)
    local before = assert(ctx.state.bossCounts and ctx.state.bossCounts[id], 'Remember the count of ' .. id .. ' first')
    assert(ctx.state.bossNavigation, 'No boss menu change has been saved yet')
    ctx:equal(count(ctx, id), before + delta, 'Boss menu count of ' .. id)
end)

-- Removes a question this scenario added, reopening the menu when a step in
-- between closed it (the job fixture is restored after this cleanup runs).
local function removeAddedQuestion(added)
    if not added.index then return end
    local hook = exports.kora_lib
    local function menuOpen() local app = hook:fftAction('state').app return app and app.id == APP end
    if not menuOpen() then
        if hook:fftAction('state').input then hook:fftAction('input.cancel') end
        exports.kora_bossmenu:openBossMenu()
        local deadline = GetGameTimer() + 3000
        while not menuOpen() and GetGameTimer() < deadline do Wait(50) end
        if not menuOpen() then return end
        added.reopened = true
    end
    local ok, result = hook:fftAction('app.action', 'boss:remove-question', { itemId = added.index })
    if ok and type(result) == 'table' and type(result.notice) == 'table' and result.notice.tone == 'success' then added.index = nil end
    if added.reopened then hook:fftAction('app.close') end
end

-- New questions are appended, so the added one sits at index (count + 1).
-- The cleanup removes it only when the add was confirmed at that index.
local function addQuestion(ctx, question, kind)
    local before = count(ctx, 'questions')
    assert(before < MAX_QUESTIONS, 'The application already has the maximum number of questions')
    local index = tostring(before + 1)
    local added = { index = nil, text = question, type = kind }
    ctx.state.bossQuestion = added
    ctx:cleanup(function() removeAddedQuestion(added) end)
    act(ctx, 'boss:add-question', { value = { question = question, type = kind } })
    if ctx.state.bossNavigation and count(ctx, 'questions') == before + 1 then added.index = index end
    return added
end

local function testQuestion(question)
    assert(question:find('FFT', 1, true), 'Test questions must contain "FFT" so they are recognisable')
    return question
end

K.step('I add the boss menu question {string}', 'client', function(ctx, question)
    addQuestion(ctx, testQuestion(question), 'short')
end)
K.step('I add the boss menu question {string} of type {string}', 'client', function(ctx, question, kind)
    addQuestion(ctx, testQuestion(question), kind)
end)
-- addQuestion keeps question:sub(1, 250) (server/main.lua).
K.step('I add a boss menu question longer than 250 characters', 'client', function(ctx)
    addQuestion(ctx, 'FFT long question ' .. ('x'):rep(282), 'short')
end)
-- Whitespace passes the server's type checks; the step still cleans up an
-- accepted one so the refusal scenario leaves nothing behind.
K.step('I try to add a blank boss menu question', 'client', function(ctx)
    addQuestion(ctx, '   ', 'short')
end)

K.step('I remove the boss menu question I added', 'client', function(ctx)
    local added = ctx.state.bossQuestion
    assert(added and added.index, 'No boss menu question was added in this scenario')
    act(ctx, 'boss:remove-question', { itemId = added.index })
    local notice = ctx.state.appResult.notice
    if type(notice) == 'table' and notice.tone == 'success' then added.index = nil end
end)

local function onMyself(ctx, actionId, value)
    assert(ON_MYSELF[actionId], actionId .. ' may not be aimed at the test character')
    if actionId == 'boss:bonus' then
        -- giveBonus floors the amount before refusing anything below 1.
        local amount = math.floor(tonumber(type(value) == 'table' and value.amount) or 0)
        assert(amount <= 0, 'This step never pays a real bonus')
    end
    act(ctx, actionId, { itemId = myCitizenId(), value = value })
end

K.step('I trigger the boss menu action {string} on myself', 'client', function(ctx, actionId)
    onMyself(ctx, actionId, nil)
end)
K.step('I trigger the boss menu action {string} on myself with:', 'client', function(ctx, actionId, argument)
    onMyself(ctx, actionId, K.json(argument))
end)

-- boss:deny is an item action of the applicant rows only (client/main.lua
-- appDefinition: applicants[...].actions), and kora_lib refuses any action id
-- the current definition does not carry ("This action is not declared by the
-- active app.", kora_lib/modules/nui/client.lua). With no applicant at all the
-- deny never reaches the server; with someone else's application pending it
-- does, and server/main.lua denyApplicant answers "Application not found.".
-- Returns 'denied', 'missing' (server refusal) or 'undeclared' (no applicants).
local function deny(ctx, citizenid)
    requireMenu()
    local ok, result, code = K.ui('app.action', 'boss:deny', { itemId = citizenid })
    if not ok then
        if code == 'rejected' and K.contains(result, 'not declared') then
            ctx.state.appResult = {}
            return 'undeclared'
        end
        error(tostring(result), 0)
    end
    ctx.state.appResult = type(result) == 'table' and result or {}
    local update = ctx.state.appResult.app
    if type(update) == 'table' and type(update.navigation) == 'table' then ctx.state.bossNavigation = update.navigation end
    local notice = type(ctx.state.appResult.notice) == 'table' and ctx.state.appResult.notice or {}
    if notice.tone == 'success' then return 'denied' end
    if notice.tone == 'destructive' and K.contains(notice.message, 'Application not found') then return 'missing' end
    error('Unexpected answer to boss:deny: ' .. tostring(notice.tone) .. ' / ' .. tostring(notice.message), 0)
end

-- Denies the tester's own application if one is pending.
K.step('no job application of mine is pending in the boss menu', 'client', function(ctx)
    deny(ctx, myCitizenId())
    ctx.state.appResult = {}
end)

local function refusedDeny(ctx, citizenid)
    local outcome = deny(ctx, citizenid)
    assert(outcome ~= 'denied', 'The boss menu denied an application that should not exist: ' .. citizenid)
end

-- Only made-up ids: a real citizenid here would deny a real application.
K.step('the boss menu should refuse to deny an application from {string}', 'client', function(ctx, citizenid)
    assert(citizenid:sub(1, 3) == 'FFT', 'Use a made-up FFT citizenid')
    refusedDeny(ctx, citizenid)
end)
K.step('the boss menu should refuse to deny my application again', 'client', function(ctx)
    refusedDeny(ctx, myCitizenId())
end)

-- ---------------------------------------------------------------------------
-- Client: application form
-- ---------------------------------------------------------------------------

-- openApplication blocks on the form, so it runs on its own thread.
K.step('I start a job application for {string}', 'client', function(_, job)
    K.started('kora_bossmenu')
    CreateThread(function() exports.kora_bossmenu:openApplication(job, 'job') end)
end)
K.step('I start a gang application for {string}', 'client', function(_, gang)
    K.started('kora_bossmenu')
    CreateThread(function() exports.kora_bossmenu:openApplication(gang, 'gang') end)
end)

local function formFields(ctx)
    local input
    ctx:waitUntil(function() input = K.uiState().input return input end, 'No job application form opened')
    return type(input.fields) == 'table' and input.fields or {}
end

K.step('I answer every job application question with {string}', 'client', function(ctx, answer)
    local values = {}
    for _, field in ipairs(formFields(ctx)) do
        values[field.id] = field.type == 'number' and 1 or field.type == 'select' and 'Yes' or answer
    end
    K.must(K.ui('input.submit', values))
end)

-- A single space passes the form's "required" check and reaches the server,
-- which refuses blank answers. With no questions a blank form would be
-- accepted, so the step refuses to submit one.
K.step('I answer every job application question with blanks', 'client', function(ctx)
    local fields = formFields(ctx)
    assert(#fields > 0, 'The application has no questions; a blank form would be accepted')
    local values = {}
    for _, field in ipairs(fields) do values[field.id] = ' ' end
    K.must(K.ui('input.submit', values))
end)

-- ---------------------------------------------------------------------------
-- Server: more business-money exports (server/main.lua credit/debit/balance)
-- ---------------------------------------------------------------------------

-- Amounts are floored before the positive check, so these never move money;
-- the guard keeps the step from being reused with a real amount.
local function nonPositive(text)
    local amount = math.floor(tonumber(text) or 0)
    assert(amount <= 0, 'This step only sends amounts that floor to zero or less, not ' .. text)
end

K.step('paying the amount {string} into the boss menu business {string} should be refused with {string}', 'server', function(ctx, amount, name, reason)
    nonPositive(amount)
    local value = tonumber(amount) or amount
    local ok, why = K.export('kora_bossmenu', 'addBusinessMoney', name, value, 'functional test')
    assert(not ok, ('addBusinessMoney accepted %s for %s'):format(amount, name))
    ctx:equal(why, reason, 'Refusal reason')
end)
K.step('taking the amount {string} out of the boss menu business {string} should be refused with {string}', 'server', function(ctx, amount, name, reason)
    nonPositive(amount)
    local value = tonumber(amount) or amount
    local ok, why = K.export('kora_bossmenu', 'removeBusinessMoney', name, value, 'functional test')
    assert(not ok, ('removeBusinessMoney accepted %s for %s'):format(amount, name))
    ctx:equal(why, reason, 'Refusal reason')
end)

-- The qb-management exports wrap credit/debit in parentheses and so answer a
-- bare false. Each is paired with its opposite to undo an unexpected success.
local LEGACY = {
    AddMoney = 'RemoveMoney', RemoveMoney = 'AddMoney',
    AddGangMoney = 'RemoveGangMoney', RemoveGangMoney = 'AddGangMoney',
}
local REFUSED_NAMES = { none = true, unemployed = true }

K.step('the legacy boss menu export {string} should refuse {int} for {string}', 'server', function(ctx, export, amount, name)
    local undo = assert(LEGACY[export], 'Unknown legacy money export: ' .. export)
    assert(amount <= 0 or REFUSED_NAMES[name] or name:sub(1, 4) == 'fft_',
        'Only non-positive amounts or organisations the boss menu refuses may be sent')
    local ok = K.export('kora_bossmenu', export, name, amount)
    if ok then
        pcall(function() exports.kora_bossmenu[undo](exports.kora_bossmenu, name, amount) end)
        error(('%s accepted %d for %s'):format(export, amount, name), 0)
    end
    ctx:equal(ok, false, export .. ' result')
end)

K.step('the boss menu gang balance of {string} should match its bank account', 'server', function(ctx, name)
    K.started('kora_banking')
    local expected = tonumber(K.export('kora_banking', 'GetAccountBalance', name)) or 0
    ctx:equal(K.export('kora_bossmenu', 'GetGangAccount', name), expected, 'Legacy GetGangAccount for ' .. name)
end)
K.step('the boss menu should report no gang balance for {string}', 'server', function(ctx, name)
    ctx:equal(K.export('kora_bossmenu', 'GetGangAccount', name), 0, 'Legacy GetGangAccount for ' .. name)
end)

-- ---------------------------------------------------------------------------
-- Client: which organisation the menu manages
-- ---------------------------------------------------------------------------

local function navigationEntry(id)
    local payload = K.ui('app')
    local app = type(payload) == 'table' and type(payload.app) == 'table' and payload.app or {}
    for _, entry in ipairs(type(app.navigation) == 'table' and app.navigation or {}) do
        if type(entry) == 'table' and entry.id == id then return entry, app end
    end
    return nil, app
end

K.step('I open the gang boss menu', 'client', function(ctx)
    K.started('kora_bossmenu')
    ctx.state.bossNavigation = nil
    exports.kora_bossmenu:openBossMenu('gang')
end)

-- appDefinition(): description = jobLabel; the employees view is titled
-- "Gang roster" for a gang and "Employee roster" for a job.
K.step('the boss menu should be managing {string}', 'client', function(ctx, label)
    requireMenu()
    local _, app = navigationEntry('employees')
    ctx:equal(app.description, label, 'Organisation managed by the boss menu')
end)
K.step('the boss menu roster should be titled {string}', 'client', function(ctx, title)
    requireMenu()
    local entry = assert(navigationEntry('employees'), 'The boss menu has no employees view')
    ctx:equal(type(entry.content) == 'table' and entry.content.title or nil, title, 'Roster title')
end)
K.step('the boss menu should count at least {int} employee', 'client', function(_, minimum)
    requireMenu()
    local entry = assert(navigationEntry('employees'), 'The boss menu has no employees view')
    local total = tonumber(entry.badge) or 0
    assert(total >= minimum, ('The boss menu counts %d employees, expected at least %d'):format(total, minimum))
end)

K.step('the boss menu should have refused to open with {string}', 'client', function(ctx, text)
    K.waitNotification(ctx, text, 8000)
    local app = K.uiState().app
    assert(not (app and app.id == APP), 'The boss menu opened')
end)
K.step('the boss menu should stay closed', 'client', function()
    Wait(2500)
    local app = K.uiState().app
    assert(not (app and app.id == APP), 'The boss menu opened')
end)

-- The qb-core compatibility events the resource registers (client/main.lua).
local LEGACY_EVENTS = { ['qb-bossmenu:client:OpenMenu'] = true, ['qb-gangmenu:client:OpenMenu'] = true }
K.step('the legacy menu event {string} fires on my client', 'client', function(ctx, event)
    assert(LEGACY_EVENTS[event], 'Not a kora_bossmenu compatibility event: ' .. event)
    ctx.state.bossNavigation = nil
    TriggerEvent(event)
end)

-- ---------------------------------------------------------------------------
-- Client: extra menu items (AddBossMenuItem / AddGangMenuItem)
-- ---------------------------------------------------------------------------

-- A local client event owned by this step file; nothing else listens to it.
local EXTRA_EVENT = 'fft:kora_bossmenu:extra'

local function addExtra(ctx, export, remove, id, label, params)
    assert(id:sub(1, 4) == 'fft_', 'Extra item ids must start with fft_')
    ctx.state.bossExtraRuns = ctx.state.bossExtraRuns or {}
    if not ctx.state.bossExtraHandler then
        local runs = ctx.state.bossExtraRuns
        ctx.state.bossExtraHandler = AddEventHandler(EXTRA_EVENT, function(args)
            if type(args) == 'table' and type(args.probe) == 'string' then runs[#runs + 1] = args.probe end
        end)
        local handler = ctx.state.bossExtraHandler
        ctx:cleanup(function() RemoveEventHandler(handler) end)
    end
    ctx:cleanup(function() pcall(function() exports.kora_bossmenu[remove](exports.kora_bossmenu, id) end) end)
    params.event, params.args = EXTRA_EVENT, { probe = id }
    exports.kora_bossmenu[export](exports.kora_bossmenu, { header = label, params = params }, id)
end

K.step('the boss menu carries an extra item {string} labelled {string}', 'client', function(ctx, id, label)
    addExtra(ctx, 'AddBossMenuItem', 'RemoveBossMenuItem', id, label, {})
end)
K.step('the boss menu carries a server-side extra item {string}', 'client', function(ctx, id)
    addExtra(ctx, 'AddBossMenuItem', 'RemoveBossMenuItem', id, 'FFT server item', { isServer = true })
end)
K.step('the boss menu carries a command extra item {string}', 'client', function(ctx, id)
    addExtra(ctx, 'AddBossMenuItem', 'RemoveBossMenuItem', id, 'FFT command item', { isCommand = true })
end)
K.step('the gang menu carries an extra item {string} labelled {string}', 'client', function(ctx, id, label)
    addExtra(ctx, 'AddGangMenuItem', 'RemoveGangMenuItem', id, label, {})
end)
K.step('the boss menu extra item {string} is removed', 'client', function(_, id)
    exports.kora_bossmenu:RemoveBossMenuItem(id)
end)

K.step('the boss menu should offer the extra item {string} labelled {string}', 'client', function(ctx, id, label)
    requireMenu()
    local entry = assert(navigationEntry('overview'), 'The boss menu has no overview')
    local actions = type(entry.content) == 'table' and type(entry.content.actions) == 'table' and entry.content.actions or {}
    for _, action in ipairs(actions) do
        if type(action) == 'table' and action.id == 'boss:extra:' .. id then
            ctx:equal(action.label, label, 'Extra item label')
            return
        end
    end
    error('The boss menu overview does not offer boss:extra:' .. id, 0)
end)
K.step('the boss menu extra item {string} should have run once', 'client', function(ctx, id)
    ctx:waitUntil(function()
        local total = 0
        for _, probe in ipairs(ctx.state.bossExtraRuns or {}) do if probe == id then total = total + 1 end end
        return total == 1
    end, 'The extra item event did not fire exactly once for ' .. id, 3000)
end)

-- ---------------------------------------------------------------------------
-- Client: editing questions
-- ---------------------------------------------------------------------------

K.step('I edit the boss menu question I added to {string} of type {string}', 'client', function(ctx, question, kind)
    local added = assert(ctx.state.bossQuestion and ctx.state.bossQuestion.index, 'No boss menu question was added in this scenario')
    testQuestion(question)
    act(ctx, 'boss:edit-question', { itemId = added, value = { question = question, type = kind } })
    local notice = ctx.state.appResult.notice
    if type(notice) == 'table' and notice.tone == 'success' then
        ctx.state.bossQuestion.text, ctx.state.bossQuestion.type = question, kind
    end
end)
K.step('I try to change the boss menu question I added to type {string}', 'client', function(ctx, kind)
    local added = assert(ctx.state.bossQuestion and ctx.state.bossQuestion.index, 'No boss menu question was added in this scenario')
    act(ctx, 'boss:edit-question', { itemId = added, value = { question = ctx.state.bossQuestion.text, type = kind } })
end)

-- onAction() raises "That application question is no longer available." for an
-- index the menu does not hold; kora_lib answers "The app action failed.".
K.step('the boss menu should fail to {string} question number {int}', 'client', function(_, verb, index)
    local actionId = verb == 'edit' and 'boss:edit-question' or verb == 'remove' and 'boss:remove-question'
    assert(actionId, 'Use "edit" or "remove"')
    requireMenu()
    local ok, err = K.ui('app.action', actionId, { itemId = tostring(index),
        value = { question = 'FFT probe question', type = 'short' } })
    assert(not ok, actionId .. ' succeeded on question ' .. index)
    assert(K.contains(err, 'The app action failed'), 'Unexpected refusal: ' .. tostring(err))
end)

-- ---------------------------------------------------------------------------
-- Client: application form contents
-- ---------------------------------------------------------------------------

K.step('the job application form should be titled {string}', 'client', function(ctx, title)
    local input
    ctx:waitUntil(function() input = K.uiState().input return input end, 'No job application form opened')
    ctx:equal(input.title, title, 'Application form title')
end)

-- applicationFields(): short -> text, long -> textarea, number -> number, yesno -> select.
local FIELD_TYPES = { short = 'text', long = 'textarea', number = 'number', yesno = 'select' }

K.step('the last job application question should be the one I added', 'client', function(ctx)
    local added = assert(ctx.state.bossQuestion, 'No boss menu question was added in this scenario')
    local fields = formFields(ctx)
    local last = assert(fields[#fields], 'The application form has no questions')
    ctx:equal(last.label, added.text:sub(1, 250), 'Last question label')
    ctx:equal(last.type, FIELD_TYPES[added.type], 'Last question field type')
    ctx:equal(last.required, true, 'Last question is required')
    if added.type == 'yesno' then
        local options = type(last.options) == 'table' and last.options or {}
        ctx:equal(#options, 2, 'Yes / No options')
        ctx:equal(options[1].value, 'Yes', 'First option')
        ctx:equal(options[2].value, 'No', 'Second option')
    end
end)
K.step('the last job application question should be cut to 250 characters', 'client', function(ctx)
    local fields = formFields(ctx)
    local last = assert(fields[#fields], 'The application form has no questions')
    ctx:equal(type(last.label) == 'string' and #last.label or nil, 250, 'Last question length')
end)
K.step('the job application form should not include the question I added', 'client', function(ctx)
    local added = assert(ctx.state.bossQuestion, 'No boss menu question was added in this scenario')
    for _, field in ipairs(formFields(ctx)) do
        assert(field.label ~= added.text, 'The application form still asks: ' .. added.text)
    end
end)
K.step('no job application form should open', 'client', function()
    Wait(2500)
    assert(not K.uiState().input, 'A job application form opened')
end)
