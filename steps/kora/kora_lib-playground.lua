-- kora_lib-playground: the development command playground (client `test*`
-- commands and the AppShell launcher on the `kora_menu` keybind).
--
-- No resource hook: every surface the playground opens is a kora_lib surface,
-- so kora_lib's hook observes and answers it, and the generic steps in
-- steps/kora.lua plus the kora_lib steps in steps/kora/kora_lib.lua cover
-- almost everything. Only the launcher key, the ping callback and the
-- ACE-gated item fixture need steps of their own.
local K = FFT.kora
if not K then return end
K.feature('kora_lib-playground')

local PLAYGROUND = 'kora_lib-playground'
-- PLAYGROUND_APP_ID in kora_lib-playground/client.lua.
local LAUNCHER = 'kora_lib-playground:launcher'

local function launcherOpen()
    local app = K.uiState().app
    return app ~= nil and app.id == LAUNCHER
end

-- The launcher has no chat command: client.lua binds it with Kora.keybind.add
-- { name = 'kora_menu' }, and kora_lib registers the press and release commands
-- `+kora_menu` and `-kora_menu` for the key mapping. Pressing while the launcher is
-- open closes it (openPlaygroundApp toggles), so the step presses only when it
-- is closed and always sends the release to clear the pressed state.
K.step('I press the playground launcher key', 'client', function(ctx)
    K.started(PLAYGROUND)
    ctx:cleanup(function()
        ExecuteCommand('-kora_menu')
        local ok, state = pcall(function() return exports.kora_lib:fftAction('state') end)
        if ok and type(state) == 'table' and state.app and state.app.id == LAUNCHER then
            pcall(function() exports.kora_lib:fftAction('app.close') end)
        end
    end)
    if launcherOpen() then return end
    ExecuteCommand('+kora_menu')
    Wait(100)
    ExecuteCommand('-kora_menu')
end)

-- server.lua registers `playground:ping`, which answers "pong: <message>" and
-- has no ACE gate. /testcallback triggers it and only prints the answer, so
-- this step triggers the same callback from the tester's client to read it.
K.step('the playground ping callback should answer {string} to {string}', 'client', function(ctx, expected, message)
    K.started(PLAYGROUND)
    ctx:equal(K.export('kora_lib', 'callback_trigger', 'playground:ping', message), expected, 'playground:ping answer')
end)

-- `playground:giveItem` (server.lua) requires the ACE `command.playground`;
-- without it /testgiveitem can only ever show "Could not give item". This is a
-- precondition, not a fixture: it fails clearly when the tester lacks the ACE.
-- Whatever the scenario then grants is taken back in cleanup.
K.step('I may use the playground item fixture for {string}', 'server', function(ctx, item)
    K.started(PLAYGROUND)
    local tester = ctx.tester
    if not IsPlayerAceAllowed(tester, 'command.playground') then
        error('The tester lacks the ACE command.playground, which /testgiveitem needs', 0)
    end
    local core = exports.kora_core
    local before = K.count(ctx, item)
    ctx:cleanup(function()
        local extra = (core:getItemCount(tester, item) or 0) - before
        if extra > 0 then core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
    end)
end)

-- ---------------------------------------------------------------------------
-- Round 3: read-only diagnostic menus, the catalogue, the core/registry
-- snapshots, the give-item and SQL callbacks, the target toggle and the
-- launcher's own structure. Waypoints reuse the kora_phone-stevie steps
-- (`my map waypoint is restored afterwards`, `my map waypoint should be at`).
-- ---------------------------------------------------------------------------

local function openMenu(ctx)
    return K.waitMenu(ctx)
end

local function menuEntry(menu, wanted)
    for _, item in ipairs(menu.items or {}) do
        if item.label == wanted or item.id == wanted then return item end
    end
    error('The open menu has no entry ' .. tostring(wanted), 0)
end

K.step('I have the playground permission', 'server', function(ctx)
    K.started(PLAYGROUND)
    -- isPlaygroundController() in kora_lib-playground/server.lua.
    assert(IsPlayerAceAllowed(ctx.tester, 'command.playground'),
        'The tester lacks the ACE command.playground, which this scenario needs')
end)

K.step('the resource {string} is not installed', 'server', function(_, resource)
    local state = GetResourceState(resource)
    assert(state == 'missing', resource .. ' is ' .. state .. '; this scenario needs it absent')
end)

-- openReadOnlyMenu() in client.lua: every entry of a diagnostic menu is disabled.
K.step('every entry of the open kora_lib menu should be disabled', 'client', function(ctx)
    local menu = openMenu(ctx)
    assert(#(menu.items or {}) > 0, 'The open menu has no entries')
    for _, item in ipairs(menu.items) do
        assert(item.disabled == true, 'Menu entry is selectable: ' .. tostring(item.label))
    end
end)
K.step('the open kora_lib menu should have {int} entries', 'client', function(ctx, expected)
    ctx:equal(#(openMenu(ctx).items or {}), expected, 'Number of menu entries')
end)
K.step('the open kora_lib menu entry {string} should be described as {string}', 'client', function(ctx, wanted, text)
    ctx:equal(menuEntry(openMenu(ctx), wanted).description, text, 'Description of ' .. wanted)
end)

-- /testresources: "Resource health (<started>/<total> started)", one disabled
-- entry per catalogue resource described "<state> - <purpose>".
K.step('the resource health menu should match the live resource states', 'client', function(ctx)
    local menu = openMenu(ctx)
    local started = 0
    for _, item in ipairs(menu.items or {}) do
        local state = GetResourceState(item.label)
        if state == 'started' then started = started + 1 end
        assert(K.contains(item.description, state .. ' - '),
            ('%s is described "%s" but is %s'):format(tostring(item.label), tostring(item.description), state))
        ctx:equal(item.id, 'resource_' .. item.label, 'Entry id')
    end
    ctx:equal(menu.title, ('Resource health (%d/%d started)'):format(started, #menu.items), 'Menu title')
end)

-- /testresource_catalogue: an entry is selectable exactly when its resource is started.
K.step('the catalogue menu should only offer started resources', 'client', function(ctx)
    local menu = openMenu(ctx)
    assert(#(menu.items or {}) > 0, 'The catalogue lists nothing')
    for _, item in ipairs(menu.items) do
        local started = GetResourceState(item.label) == 'started'
        ctx:equal(item.disabled, not started, ('Disabled flag of %s (%s)'):format(tostring(item.label), GetResourceState(item.label)))
    end
end)

-- /testcore_registries: "<n> registered records" from exports.kora_core:countShared.
K.step('the core registry menu should match the kora_core record counts', 'client', function(ctx)
    local menu = openMenu(ctx)
    for _, registry in ipairs({ 'items', 'vehicles', 'jobs', 'gangs', 'weapons', 'locations' }) do
        local count = K.export('kora_core', 'countShared', registry)
        local item = menuEntry(menu, 'registry_' .. registry)
        ctx:equal(item.description, ('%d registered records'):format(count or 0), 'Registry ' .. registry)
    end
end)

-- /testcore_player: "Job: <label or name>" described "grade <grade> - on duty|off duty".
K.step('the core player snapshot should show my job and duty', 'client', function(ctx)
    local data = K.export('kora_core', 'getPlayerData')
    assert(type(data) == 'table' and type(data.job) == 'table', 'kora_core has no player data for the tester')
    local item = menuEntry(openMenu(ctx), 'core_job')
    local name = data.job.label or data.job.name
    ctx:equal(item.label, 'Job: ' .. tostring(name ~= '' and name or '--'), 'Job entry')
    local duty = data.job.onduty and 'on duty' or 'off duty'
    assert(type(item.description) == 'string' and item.description:sub(-#duty) == duty,
        ('Job entry is described "%s", expected it to end in "%s"'):format(tostring(item.description), duty))
end)

-- Progress bar ---------------------------------------------------------------

K.step('the progress bar should stop within {int} milliseconds', 'client', function(ctx, limit)
    ctx:waitUntil(function() return not K.uiState().progress end, 'The progress bar is still running', limit)
end)

-- Give item and SQL callbacks -------------------------------------------------
-- The same callbacks /testgiveitem, the fixture commands and /testsql_stats
-- trigger (server.lua); the server answers, so the refusals are authoritative.

local function giveItem(item, amount)
    local response = K.export('kora_lib', 'callback_trigger', 'playground:giveItem', item, amount)
    assert(type(response) == 'table', 'playground:giveItem answered with ' .. type(response))
    return response
end

K.step('asking the playground to give {int} {string} should succeed', 'client', function(ctx, amount, item)
    local response = giveItem(item, amount)
    ctx:equal(response.ok, true, 'playground:giveItem ok (' .. tostring(response.err) .. ')')
end)
K.step('asking the playground to give {string} with the amount {string} should be refused with {string}', 'client', function(ctx, item, amount, reason)
    local response = giveItem(item, amount)
    ctx:equal(response.ok, false, 'playground:giveItem ok')
    ctx:equal(response.err, reason, 'Refusal')
end)
K.step('asking the playground to give {string} with the number {float} should be refused with {string}', 'client', function(ctx, item, amount, reason)
    local response = giveItem(item, amount)
    ctx:equal(response.ok, false, 'playground:giveItem ok')
    ctx:equal(response.err, reason, 'Refusal')
end)
K.step('asking the playground to give the number {int} as an item should be refused with {string}', 'client', function(ctx, item, reason)
    local response = giveItem(item, 1)
    ctx:equal(response.ok, false, 'playground:giveItem ok')
    ctx:equal(response.err, reason, 'Refusal')
end)

K.step('the playground SQL statistics callback should answer with live statistics', 'client', function(ctx)
    local response = K.export('kora_lib', 'callback_trigger', 'playground:sqlStats')
    assert(type(response) == 'table', 'playground:sqlStats answered with ' .. type(response))
    ctx:equal(response.ok, true, 'playground:sqlStats ok (' .. tostring(response.err) .. ')')
    assert(type(response.stats) == 'table', 'playground:sqlStats returned no statistics table')
end)

-- Target toggle -----------------------------------------------------------------
-- testtarget_toggle flips exports.kora_target:getState().enabled; cleanup puts
-- the remembered state back through the same export the command uses.

local function targetEnabled()
    local state = K.export('kora_target', 'getState')
    assert(type(state) == 'table', 'kora_target:getState returned nothing')
    return state.enabled == true
end

K.step('I remember whether targeting is enabled', 'client', function(ctx)
    local original = targetEnabled()
    ctx.state.playgroundTarget = original
    ctx:cleanup(function()
        pcall(function()
            if exports.kora_target:getState().enabled ~= original then exports.kora_target:setEnabled(original) end
        end)
    end)
end)
K.step('targeting should be the opposite of what I remembered', 'client', function(ctx)
    local original = ctx.state.playgroundTarget
    assert(original ~= nil, 'Remember whether targeting is enabled first')
    ctx:waitUntil(function() return targetEnabled() == not original end, 'Targeting was not toggled', 3000)
end)
K.step('targeting should be as I remembered', 'client', function(ctx)
    local original = ctx.state.playgroundTarget
    assert(original ~= nil, 'Remember whether targeting is enabled first')
    ctx:waitUntil(function() return targetEnabled() == original end, 'Targeting did not return to its remembered state', 3000)
end)

-- Launcher ----------------------------------------------------------------------

K.step('I press the playground launcher key again', 'client', function(ctx)
    ctx:cleanup(function() ExecuteCommand('-kora_menu') end)
    ExecuteCommand('+kora_menu')
    Wait(100)
    ExecuteCommand('-kora_menu')
end)

-- kora_lib's `app` hook action returns the open app's payload (summarised).
local function launcherPayload()
    local payload = K.ui('app')
    assert(type(payload) == 'table' and type(payload.app) == 'table', 'No app payload is available')
    assert(payload.app.id == LAUNCHER, 'The open app is ' .. tostring(payload.app.id))
    return payload.app
end
K.step('the playground launcher should be titled {string}', 'client', function(ctx, title)
    ctx:equal(launcherPayload().title, title, 'Launcher title')
end)
-- playgroundApp(): one navigation view per COMMANDS section, badge = its entry count.
K.step('the playground launcher should offer the section {string} with {int} entries', 'client', function(ctx, id, entries)
    for _, view in pairs(launcherPayload().navigation or {}) do
        if type(view) == 'table' and view.id == id then
            ctx:equal(view.badge, entries, 'Entries in ' .. id)
            return
        end
    end
    error('The launcher has no section ' .. id, 0)
end)

-- Every launcher action runs ExecuteCommand(<id>) (onAction in client.lua), so
-- each catalogue id must be a command this resource registered.
K.step('the playground should register the command {string}', 'client', function(_, name)
    for _, command in ipairs(GetRegisteredCommands() or {}) do
        if command.name == name then
            assert(command.resource == PLAYGROUND, name .. ' is registered by ' .. tostring(command.resource))
            return
        end
    end
    error('No command /' .. name .. ' is registered', 0)
end)
