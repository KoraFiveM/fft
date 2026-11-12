-- kora_scoreboard: player count, on-duty police count and police-gated
-- activity status in the kora_lib AppShell app "qb-scoreboard:app".
-- Uses kora_scoreboard/fft_hooks.lua (action `view`): kora_lib's hook confirms
-- the app is open but its payload summary stops above the stat values and
-- table rows, and the figures are file-local in the scoreboard client. The
-- hook only reports what the scoreboard last sent to its own app.
-- The activity busy flag (qb-scoreboard:server:SetActivityBusy) is broadcast to
-- every player and is never toggled here.
local K = FFT.kora
if not K then return end
K.feature('kora_scoreboard')

-- Status texts from policeStatus() in kora_scoreboard/client/client.lua.
local READY, NEEDS_POLICE, COOLDOWN = 'Ready', 'Needs more police', 'On cooldown'

local function view()
    local snapshot = K.must(K.hook('kora_scoreboard', 'view'))
    assert(type(snapshot) == 'table' and type(snapshot.stats) == 'table' and type(snapshot.activities) == 'table',
        'Scoreboard hook returned no view')
    return snapshot
end

local function stat(snapshot, label)
    for _, item in ipairs(snapshot.stats) do
        if item.label == label then return item.value end
    end
    error('Scoreboard shows no "' .. label .. '" figure', 0)
end

-- Stat labels from buildNavigation() in client/client.lua.
local function policeCount(snapshot)
    local value = tonumber(stat(snapshot, 'Police on duty'))
    assert(value, 'Scoreboard police count is not a number')
    return value
end

K.step('the scoreboard should show at least {int} player online within the server capacity', 'client', function(_, minimum)
    local value = stat(view(), 'Players online')
    local online, capacity = tostring(value):match('^(%d+) / (%d+)$')
    online, capacity = tonumber(online), tonumber(capacity)
    assert(online and capacity, 'Players online reads "' .. tostring(value) .. '", expected "<online> / <capacity>"')
    assert(online >= minimum, ('Scoreboard shows %d players online, expected at least %d'):format(online, minimum))
    assert(capacity >= 1, 'Scoreboard capacity should be at least 1')
end)

K.step('the scoreboard should count at least {int} police on duty', 'client', function(_, minimum)
    local count = policeCount(view())
    assert(count >= minimum, ('Scoreboard counts %d police, expected at least %d'):format(count, minimum))
end)

K.step('I remember the scoreboard police count', 'client', function(ctx)
    ctx.state.scoreboardPolice = policeCount(view())
end)
K.step('the scoreboard police count should be {int} lower than before', 'client', function(ctx, amount)
    local before = assert(ctx.state.scoreboardPolice, 'Remember the scoreboard police count first')
    ctx:equal(policeCount(view()), before - amount, 'Scoreboard police count')
end)

K.step('the scoreboard should list the activity {string}', 'client', function(_, label)
    for _, row in ipairs(view().activities) do
        if row.label == label then
            assert(row.required and row.required >= 0, 'Activity has no police requirement: ' .. label)
            return
        end
    end
    error('Scoreboard does not list ' .. label, 0)
end)

K.step('every scoreboard activity status should follow the police count', 'client', function(ctx)
    local snapshot = view()
    local police = policeCount(snapshot)
    assert(#snapshot.activities > 0, 'Scoreboard lists no activities')
    for _, row in ipairs(snapshot.activities) do
        -- A cooldown is set by other resources at runtime and overrides the police check.
        assert(type(row.required) == 'number', 'Activity has no police requirement: ' .. tostring(row.label))
        if row.status ~= COOLDOWN then
            ctx:equal(row.status, police >= row.required and READY or NEEDS_POLICE,
                ('Status of %s (needs %s, %d on duty)'):format(tostring(row.label), tostring(row.required), police))
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Round 3: server data callback, activity table contents, app metadata, the
-- open guard, the key mode and the activity busy flag.
-- ---------------------------------------------------------------------------

local APP_ID = 'qb-scoreboard:app' -- APP_ID in kora_scoreboard/client/client.lua

local function activity(snapshot, label)
    for _, row in ipairs(snapshot.activities) do
        if row.label == label then return row end
    end
    error('Scoreboard does not list ' .. label, 0)
end

-- The callback the scoreboard itself triggers before opening (server/server.lua).
-- callback_triggerPacked turns a raised handler error into
-- { __kora_lib_rejected = true, error } so its message is reported.
local function serverData()
    local packed = K.export('kora_lib', 'callback_triggerPacked', 'qb-scoreboard:server:GetScoreboardData')
    assert(type(packed) == 'table', 'GetScoreboardData returned no answer')
    assert(not packed.__kora_lib_rejected, 'GetScoreboardData failed: ' .. tostring(packed.error))
    local total, police, players = packed[1], packed[2], packed[3]
    assert(type(total) == 'number' and type(police) == 'number', 'GetScoreboardData did not answer with two counts')
    assert(type(players) == 'table', 'GetScoreboardData did not answer with a player table')
    return total, police, players
end

K.step('the scoreboard server data should list me with an opt-in flag', 'client', function()
    local total, police, players = serverData()
    assert(total >= 1, 'GetScoreboardData counts no players')
    assert(police >= 0 and police <= total, ('GetScoreboardData counts %d police for %d players'):format(police, total))
    local me = GetPlayerServerId(PlayerId())
    local entry = players[me] or players[tostring(me)]
    assert(type(entry) == 'table', 'GetScoreboardData does not list the tester (' .. me .. ')')
    assert(type(entry.optin) == 'boolean', 'Opt-in flag is ' .. tostring(entry.optin) .. ', expected a boolean')
end)

K.step('the scoreboard server data should count at least {int} police on duty', 'client', function(_, minimum)
    local _, police = serverData()
    assert(police >= minimum, ('GetScoreboardData counts %d police, expected at least %d'):format(police, minimum))
end)
K.step('I remember the scoreboard server police count', 'client', function(ctx)
    local _, police = serverData()
    ctx.state.scoreboardServerPolice = police
end)
K.step('the scoreboard server police count should be unchanged', 'client', function(ctx)
    local before = assert(ctx.state.scoreboardServerPolice, 'Remember the scoreboard server police count first')
    local _, police = serverData()
    ctx:equal(police, before, 'GetScoreboardData police count')
end)
K.step('the scoreboard server police count should be {int} higher than before', 'client', function(ctx, amount)
    local before = assert(ctx.state.scoreboardServerPolice, 'Remember the scoreboard server police count first')
    local _, police = serverData()
    ctx:equal(police, before + amount, 'GetScoreboardData police count')
end)

K.step('the scoreboard server police count should be {int} lower than before', 'client', function(ctx, amount)
    local before = assert(ctx.state.scoreboardServerPolice, 'Remember the scoreboard server police count first')
    local _, police = serverData()
    ctx:equal(police, before - amount, 'GetScoreboardData police count')
end)

-- The app shows the figures fetched right before it opened, so this compares
-- them with a fresh answer of the same callback.
K.step('the scoreboard should show the player and police counts the server reports', 'client', function(ctx)
    local snapshot = view()
    local online = tonumber(tostring(stat(snapshot, 'Players online')):match('^(%d+) / %d+$'))
    local total, police = serverData()
    ctx:equal(online, total, 'Players online')
    ctx:equal(policeCount(snapshot), police, 'Police on duty')
end)

-- Rows, labels and minimumPolice from Config.IllegalActions (shared/config.lua).
K.step('the scoreboard should require {int} police for {string}', 'client', function(ctx, required, label)
    ctx:equal(activity(view(), label).required, required, 'Required police for ' .. label)
end)
K.step('the scoreboard should list {int} activities', 'client', function(ctx, expected)
    ctx:equal(#view().activities, expected, 'Number of activities')
end)
-- buildActivityRows() sorts rows by activity label.
K.step('the scoreboard activities should be sorted by name', 'client', function()
    local rows = view().activities
    for index = 2, #rows do
        assert(rows[index - 1].label < rows[index].label,
            ('"%s" is listed before "%s"'):format(tostring(rows[index - 1].label), tostring(rows[index].label)))
    end
end)
K.step('the scoreboard should show the activity {string} as {string}', 'client', function(ctx, label, status)
    ctx:waitUntil(function() return activity(view(), label).status == status end,
        ('%s does not show "%s"'):format(label, status), 3000,
        function() return (' (shows "%s")'):format(tostring(activity(view(), label).status)) end)
end)
K.step('the scoreboard should not show the activity {string} on cooldown', 'client', function(_, label)
    local row = activity(view(), label)
    assert(row.status ~= COOLDOWN, label .. ' is on cooldown from a real robbery; this scenario would clear it')
end)
K.step('the scoreboard should report itself open', 'client', function(ctx)
    ctx:waitUntil(function() return view().open == true end, 'Scoreboard hook reports the app closed', 3000)
end)
K.step('the scoreboard should report itself closed', 'client', function(ctx)
    ctx:waitUntil(function() return view().open == false end, 'Scoreboard hook reports the app open', 3000)
end)

K.step('I remember how often the scoreboard figures were sent', 'client', function(ctx)
    ctx.state.scoreboardUpdates = view().updates
end)
K.step('the scoreboard figures should have been sent {int} more times', 'client', function(ctx, amount)
    local before = assert(ctx.state.scoreboardUpdates, 'Remember how often the scoreboard figures were sent first')
    ctx:waitUntil(function() return view().updates >= before + amount end,
        ('Scoreboard figures were not sent %d more times'):format(amount), 5000,
        function() return (' (sent %d more times)'):format(view().updates - before) end)
    ctx:equal(view().updates, before + amount, 'Scoreboard update count')
end)

-- App metadata from Kora.nui.registerApp in client/client.lua.
local function appPayload()
    local payload = K.ui('app')
    assert(type(payload) == 'table' and type(payload.app) == 'table', 'No app payload is available')
    assert(payload.app.id == APP_ID, 'The open app is ' .. tostring(payload.app.id))
    return payload.app
end
K.step('the scoreboard app should be titled {string}', 'client', function(ctx, title)
    ctx:equal(appPayload().title, title, 'App title')
end)
K.step('the scoreboard footer should describe the configured key mode', 'client', function()
    local footer = tostring(appPayload().footer)
    assert(footer:match('^Press .+ or Escape to close$') or footer:match('^Hold .+ to view$'),
        'Footer is "' .. footer .. '", expected "Press <key> or Escape to close" or "Hold <key> to view"')
end)

K.step('I run the scoreboard command twice in a row', 'client', function(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('app.close') end) end)
    -- The second call lands while the first is still fetching: openScoreboard's
    -- `opening` guard must ignore it instead of opening twice or closing.
    ExecuteCommand('scoreboard')
    ExecuteCommand('scoreboard')
end)

-- +scoreboard / -scoreboard are the key mapping commands. Config.Toggle is read
-- from the footer the app was registered with (registerApp in client.lua).
K.step('pressing and releasing the scoreboard key should follow the configured key mode', 'client', function(ctx)
    ctx:cleanup(function()
        pcall(ExecuteCommand, '-scoreboard')
        pcall(function() exports.kora_lib:fftAction('app.close') end)
    end)
    ExecuteCommand('+scoreboard')
    ctx:waitUntil(function() local app = K.uiState().app return app and app.id == APP_ID end, 'The scoreboard key did not open the app')
    local toggle = tostring(appPayload().footer):match('^Press ') ~= nil
    ExecuteCommand('-scoreboard')
    if toggle then
        Wait(500)
        local app = K.uiState().app
        assert(app and app.id == APP_ID, 'Toggle mode: releasing the key closed the scoreboard')
        ExecuteCommand('+scoreboard')
        ExecuteCommand('-scoreboard')
        ctx:waitUntil(function() return not K.uiState().app end, 'Toggle mode: pressing the key again did not close the scoreboard', 3000)
    else
        ctx:waitUntil(function() return not K.uiState().app end, 'Hold mode: releasing the key did not close the scoreboard', 3000)
    end
end)

-- Busy flag. qb-scoreboard:server:SetActivityBusy is a server-local event that
-- broadcasts to every client (server/server.lua), so these steps are @global.
-- Ids are the Config.IllegalActions keys.
local function setBusy(id, value)
    TriggerEvent('qb-scoreboard:server:SetActivityBusy', id, value)
end
K.step('the activity {string} is set busy on the scoreboard', 'server', function(ctx, id)
    assert(type(id) == 'string' and #id <= 32, 'Invalid activity id')
    ctx:cleanup(function() pcall(setBusy, id, false) end)
    setBusy(id, true)
end)
K.step('the activity {string} is set free on the scoreboard', 'server', function(_, id)
    assert(type(id) == 'string' and #id <= 32, 'Invalid activity id')
    setBusy(id, false)
end)
K.step('the unknown activity {string} is set busy on the scoreboard', 'server', function(ctx, id)
    -- Refused by the server handler (not a Config.IllegalActions key); the
    -- cleanup is the same refused call with false, kept for symmetry.
    ctx:cleanup(function() pcall(setBusy, id, false) end)
    setBusy(id, true)
end)
K.step('the activity {string} is set busy on the scoreboard with the value {string}', 'server', function(ctx, id, value)
    -- A non-boolean flag is refused by the server handler.
    ctx:cleanup(function() pcall(setBusy, id, false) end)
    setBusy(id, value)
end)
K.step('the activity {string} is set busy on the scoreboard with no value', 'server', function(ctx, id)
    ctx:cleanup(function() pcall(setBusy, id, false) end)
    setBusy(id, nil)
end)
