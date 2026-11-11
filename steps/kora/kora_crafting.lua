-- kora_crafting: crafting stations (kora_target box -> 'kora_crafting:menu' app ->
-- progress bar) and the admin creator app ('kora_crafting:creator').
--
-- Uses kora_crafting/fft_hooks.lua. The resource has no exports and no stations
-- of its own, so the hook builds one throwaway station in front of the tester
-- through the creator's own admin callbacks and deletes it afterwards. The
-- tester therefore needs the "command" ace (server/_functions.lua isAdmin).
-- Opening the station, choosing a recipe and crafting all go through
-- kora_target and kora_lib exactly as a player would.
--
-- The hook purges before it builds, so the ids are always these.
--   recipe  'fft_recipe'   -> app action 'craft:fft_recipe'
--   station 'fft_station'  -> target label 'FFT test craft'
local K = FFT.kora
if not K then return end
K.feature('kora_crafting')

local HOOK_VERSION = 1

local function hook(action, ...) return K.hook('kora_crafting', action, ...) end

local function closeCraftingApps()
    local ok, state = pcall(K.uiState)
    local app = ok and type(state) == 'table' and state.app or nil
    if app and (app.id == 'kora_crafting:menu' or app.id == 'kora_crafting:creator') then pcall(K.ui, 'app.close') end
end

-- Registered before anything is created, so a failed build is removed too.
local function removeAfterwards(ctx)
    if ctx.state.craftingCleanup then return end
    ctx.state.craftingCleanup = true
    assert(K.export('kora_crafting', 'fftVersion') == HOOK_VERSION, 'kora_crafting FFT hook version mismatch')
    ctx:cleanup(function()
        closeCraftingApps()
        pcall(hook, 'purge')
    end)
end

local function build(ctx, spec)
    removeAfterwards(ctx)
    ctx.state.craftStation = K.must(hook('fixture', spec))
end

K.step('crafting test data is removed afterwards', 'client', function(ctx) removeAfterwards(ctx) end)

K.step('a crafting test station turns {int} {string} into {int} {string}', 'client', function(ctx, cost, material, amount, item)
    build(ctx, { makes = item, amount = amount, give = { { item = material, amount = cost } } })
end)
K.step('a crafting test station makes {int} {string} with {int} {string} that is kept', 'client', function(ctx, amount, item, cost, material)
    build(ctx, { makes = item, amount = amount, give = { { item = material, amount = cost, keep = true } } })
end)
K.step('a crafting test station for the {string} job turns {int} {string} into {int} {string}', 'client', function(ctx, job, cost, material, amount, item)
    build(ctx, { makes = item, amount = amount, job = job, give = { { item = material, amount = cost } } })
end)
-- The recipe demands the highest level the creator allows (Limits.level = 1000).
K.step('a crafting test station turns {int} {string} into {int} {string} behind a skill level I lack', 'client', function(ctx, cost, material, amount, item)
    build(ctx, { makes = item, amount = amount, skillLocked = true, give = { { item = material, amount = cost } } })
end)

K.step('I aim at the crafting test station', 'client', function(ctx)
    local station = assert(ctx.state.craftStation, 'No crafting test station was built')
    K.aimAt(station.aim.x, station.aim.y, station.aim.z)
    Wait(100)
end)

K.step('my client should know the crafting test station', 'client', function(ctx)
    local station = assert(ctx.state.craftStation, 'No crafting test station was built')
    ctx:waitUntil(function()
        for _, entry in ipairs(hook('state').stations or {}) do
            if entry.id == station.station and entry.locations == 1 and entry.targetLabel == station.targetLabel then return true end
        end
    end, 'The client has no target for ' .. station.station, 3000)
end)

K.step('no crafting should be in progress', 'client', function(ctx)
    ctx:waitUntil(function() return hook('state').crafting == false end, 'A station menu or craft is still running', 5000)
end)

-- The Craft button (client/craft.lua:116-121: onAction stores the recipe and
-- answers { close = true }). kora_lib hands that answer to the browser
-- (modules/nui/client.lua "kora_lib:app:action" returns { ok = true, result =
-- result }) and the browser closes the shell by settling the openApp request;
-- only then does OpenCrafting's Kora.nui.openApp return and runCraft start
-- (client/craft.lua:171-174). No browser reads the answer at the callback
-- level, so this step asserts the answer and settles the app as the browser
-- would. The station loop reopens the menu after the craft.
K.step('I craft the recipe {string}', 'client', function(_, recipe)
    local _, result = K.must(K.ui('app.action', 'craft:' .. recipe))
    assert(type(result) == 'table' and result.close == true, 'The Craft action did not answer close = true')
    K.ui('app.close') -- no-op when kora_lib's hook already settled the close
end)

-- Removes whatever a craft produced. Call before crafting.
K.step('any {string} I craft is removed afterwards', 'server', function(ctx, item)
    local core, tester = exports.kora_core, ctx.tester
    local before = K.count(ctx, item)
    ctx:cleanup(function()
        local extra = (core:getItemCount(tester, item) or 0) - before
        if extra > 0 then core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
    end)
end)

-- Creator actions that ask a question (name dialog, delete confirmation) hold
-- their NUI callback open until answered, so they run in their own thread and
-- the generic input/confirmation steps answer them.
K.step('I start the crafting creator action {string}', 'client', function(ctx, actionId)
    local pending = { done = false }
    ctx.state.creatorAction = pending
    CreateThread(function()
        local ran, ok, result = pcall(K.ui, 'app.action', actionId)
        pending.ok, pending.result, pending.done = ran and ok, ran and result or ok, true
    end)
end)

local function creatorResult(ctx)
    local pending = assert(ctx.state.creatorAction, 'No crafting creator action was started')
    ctx:waitUntil(function() return pending.done end, 'The crafting creator action did not answer', 6000)
    if not pending.ok then error('Crafting creator action failed: ' .. tostring(pending.result), 0) end
    return type(pending.result) == 'table' and pending.result or {}
end

K.step('the crafting creator should answer with a {string} notice containing {string}', 'client', function(ctx, tone, text)
    local notice = creatorResult(ctx).notice
    assert(type(notice) == 'table', 'The crafting creator returned no notice')
    ctx:equal(notice.tone, tone, 'Notice tone')
    assert(K.contains(notice.message, text), ('Notice is "%s", expected it to contain "%s"'):format(tostring(notice.message), text))
end)

K.step('the crafting creator should answer without a notice', 'client', function(ctx)
    local notice = creatorResult(ctx).notice
    assert(notice == nil, 'Unexpected notice: ' .. tostring(type(notice) == 'table' and notice.message or notice))
end)

local function hasRecipe(id)
    local registry = K.must(hook('registry'))
    for _, recipe in ipairs(registry.recipes or {}) do
        if recipe == id then return true end
    end
    return false
end

-- Read from the server through the creator's own read-only admin callback.
K.step('the crafting server should have the recipe {string}', 'client', function(ctx, id)
    ctx:waitUntil(function() return hasRecipe(id) end, 'The server has no recipe ' .. id, 3000)
end)
K.step('the crafting server should not have the recipe {string}', 'client', function(ctx, id)
    ctx:waitUntil(function() return not hasRecipe(id) end, 'The server still has the recipe ' .. id, 3000)
end)

-- ---------------------------------------------------------------------------
-- Round 3: more fixtures, creator forms and authoritative read-backs.
-- ---------------------------------------------------------------------------

-- More recipe shapes, all through the same hook fixture (fft_hooks.lua
-- actions.fixture: up to 5 materials, 1-50 each, amount made 1-10).
K.step('a crafting test station turns {int} {string} and {int} {string} into {int} {string}', 'client', function(ctx, costA, materialA, costB, materialB, amount, item)
    build(ctx, { makes = item, amount = amount, give = { { item = materialA, amount = costA }, { item = materialB, amount = costB } } })
end)
K.step('a crafting test station makes {int} {string} from nothing', 'client', function(ctx, amount, item)
    build(ctx, { makes = item, amount = amount, give = {} })
end)
K.step('a crafting test station makes {int} {string} with {int} {string} kept and {int} {string} used up', 'client', function(ctx, amount, item, keptCost, kept, usedCost, used)
    build(ctx, { makes = item, amount = amount, give = { { item = kept, amount = keptCost, keep = true }, { item = used, amount = usedCost } } })
end)

-- Deletes the test station and recipe through the creator's admin delete
-- callbacks (fft_hooks.lua actions.purge), as an admin would while a player
-- stands at it. The server re-publishes the station (server/data.lua
-- kora_crafting:client:stationReload with nil).
K.step('the crafting test data is deleted', 'client', function()
    K.must(hook('purge'))
end)

K.step('my client should no longer know the crafting test station', 'client', function(ctx)
    local station = assert(ctx.state.craftStation, 'No crafting test station was built')
    ctx:waitUntil(function()
        for _, entry in ipairs(hook('state').stations or {}) do
            if entry.id == station.station then return false end
        end
        return true
    end, 'The client still has a target for ' .. station.station, 3000)
end)

-- client/_functions.lua buildStation keeps each station's targetLabel; the
-- hook's state() reports it for fft_ stations, with or without locations.
K.step('my client should know the crafting station {string} with the target label {string}', 'client', function(ctx, id, label)
    ctx:waitUntil(function()
        for _, entry in ipairs(hook('state').stations or {}) do
            if entry.id == id and entry.targetLabel == label then return true end
        end
    end, ('The client has no station %s labelled "%s"'):format(id, label), 3000)
end)

-- Moves the tester straight away from the station, beyond Config.Distance
-- (shared/config.lua 5.0) of its location, and waits for the server to see the
-- new position (server/_functions.lua isNear uses Kora.distance.player).
K.step('I move {int} metres away from the crafting test station', 'client', function(ctx, metres)
    local station = assert(ctx.state.craftStation, 'No crafting test station was built')
    assert(metres > 5 and metres <= 30, 'Move 6-30 metres')
    local at = GetEntityCoords(PlayerPedId())
    local dx, dy = at.x - station.aim.x, at.y - station.aim.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.1 then dx, dy, length = 1.0, 0.0, 1.0 end
    local x, y = station.aim.x + dx / length * metres, station.aim.y + dy / length * metres
    K.teleport(ctx, x, y, at.z, GetEntityHeading(PlayerPedId()))
    local deadline = GetGameTimer() + 1500
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
    local now = GetEntityCoords(PlayerPedId())
    assert(math.sqrt((now.x - station.aim.x) ^ 2 + (now.y - station.aim.y) ^ 2) > 5.5, 'The tester is still near the station')
end)

-- kora_lib's hook records progressStart's duration (fft_hooks.lua observe);
-- kora_crafting passes the recipe's progress.time (server/craft.lua begin).
K.step('the crafting progress bar should last {int} milliseconds', 'client', function(ctx, duration)
    local progress = ctx:waitUntil(function() return K.uiState().progress end, 'No progress bar is running')
    ctx:equal(progress.duration, duration, 'Progress duration')
end)

-- Creator actions with form values (kora_lib passes context.value to onAction,
-- client/creator.lua onAction `values`). They run in a thread like the other
-- creator actions, so a dialog they open can be answered afterwards.
local function startCreator(ctx, actionId, values)
    local pending = { done = false }
    ctx.state.creatorAction = pending
    CreateThread(function()
        local ran, ok, result = pcall(K.ui, 'app.action', actionId, { value = values })
        pending.ok, pending.result, pending.done = ran and ok, ran and result or ok, true
    end)
end

K.step('I start the crafting creator action {string} with:', 'client', function(ctx, actionId, argument)
    startCreator(ctx, actionId, K.json(argument))
end)
K.step('I search the crafting creator items for {string}', 'client', function(ctx, query)
    startCreator(ctx, 'recipe:search', { query = query })
end)
K.step('I search the crafting creator recipes for {string}', 'client', function(ctx, query)
    startCreator(ctx, 'station:search', { recipeQuery = query })
end)

-- The recipe "Details" form (client/creator.lua detailsForm, detailsInput):
-- every field is sent on Save, so overrides go onto a valid record. Numbers are
-- sent as text; detailsInput tonumber()s them, and '' means "empty".
local function recipeDetails(overrides)
    local values = {
        label = 'FFT recipe', tag = '', amount = '1',
        progressLabel = 'Crafting...', progressTime = '5000',          -- DefaultProgress
        animDict = 'mp_arresting', animClip = 'a_uncuff', animFlag = '49', -- DefaultAnim
        disable = { 'car', 'combat', 'move' }, skill = 'none', level = '', xp = '',
    }
    for key, value in pairs(overrides) do
        assert(values[key] ~= nil, 'The details form has no field ' .. tostring(key))
        values[key] = value
    end
    return values
end
K.step('I save the crafting recipe details with:', 'client', function(ctx, argument)
    startCreator(ctx, 'recipe:details', recipeDetails(K.json(argument)))
end)
K.step('I save the crafting recipe details with {string} set to {string}', 'client', function(ctx, field, value)
    startCreator(ctx, 'recipe:details', recipeDetails({ [field] = value }))
end)

-- The amount dialog of recipe:add / recipe:edit (client/creator.lua askAmount):
-- fields `amount` (number) and `keep` ('use' | 'keep').
K.step('the crafting amount dialog should default to {int} and {string}', 'client', function(ctx, amount, keep)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('input.cancel') end) end)
    local input = ctx:waitUntil(function() return K.uiState().input end, 'No input dialog opened')
    local found = {}
    for _, field in pairs(input.fields or {}) do
        if type(field) == 'table' and field.id then found[field.id] = field.default end
    end
    ctx:equal(tonumber(found.amount), amount, 'Amount default')
    ctx:equal(found.keep, keep, 'Used-up default')
end)
K.step('I answer the crafting amount dialog with {string} and {string}', 'client', function(ctx, amount, keep)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('input.cancel') end) end)
    ctx:waitUntil(function() return K.uiState().input end, 'No input dialog opened')
    K.must(K.ui('input.submit', { amount = tonumber(amount) or amount, keep = keep }))
end)

-- Reopens the creator so kora_lib's open request carries the navigation built
-- from a fresh kora_crafting:creator:get (client/creator.lua open()).
K.step('I reopen the crafting creator', 'client', function(ctx)
    if K.uiState().app then K.must(K.ui('app.close')) end
    ctx:waitUntil(function() return not K.uiState().app end, 'The app did not close', 3000)
    ExecuteCommand('craftCreator')
    ctx:cleanup(closeCraftingApps)
    ctx:waitUntil(function()
        local app = K.uiState().app
        return app and app.id == 'kora_crafting:creator'
    end, 'The crafting creator did not reopen')
end)

-- Reads the open crafting app (menu or creator) as kora_lib opened it. Only
-- view and block titles survive the hook's depth limit (fft_hooks.lua
-- actions.app), so the steps assert those: block titles carry the counts,
-- e.g. "Required items (2)" or "Ready to craft (1)".
local function craftingViews()
    local payload = K.must(K.ui('app'))
    local app = type(payload) == 'table' and payload.app or {}
    assert(app.id == 'kora_crafting:menu' or app.id == 'kora_crafting:creator', 'No crafting app is open')
    return type(app.navigation) == 'table' and app.navigation or {}
end
local function craftingView(id)
    for _, view in pairs(craftingViews()) do
        if type(view) == 'table' and view.id == id then return view end
    end
end
local function hasBlock(title)
    local seen = {}
    for _, view in pairs(craftingViews()) do
        local content = type(view) == 'table' and view.content
        for _, block in pairs(type(content) == 'table' and type(content.blocks) == 'table' and content.blocks or {}) do
            if type(block) == 'table' and block.title then
                if block.title == title then return true end
                seen[#seen + 1] = '"' .. tostring(block.title) .. '"'
            end
        end
    end
    return false, table.concat(seen, ', ')
end

K.step('the crafting app should show the block {string}', 'client', function(ctx, title)
    local seen = ''
    ctx:waitUntil(function()
        local found, titles = hasBlock(title)
        seen = titles or seen
        return found
    end, 'No block titled "' .. title .. '"', 3000, function() return ' | blocks: ' .. seen end)
end)
K.step('the crafting app should not show the block {string}', 'client', function(_, title)
    local found = hasBlock(title)
    assert(not found, 'A block is titled "' .. title .. '"')
end)
K.step('the crafting app view {string} should be titled {string}', 'client', function(ctx, id, title)
    local view = assert(craftingView(id), 'The crafting app has no view ' .. id)
    ctx:equal(view.content and view.content.title, title, 'View title')
end)
K.step('the crafting app view {string} should say {string}', 'client', function(_, id, text)
    local view = assert(craftingView(id), 'The crafting app has no view ' .. id)
    local description = view.content and view.content.description
    assert(K.contains(description, text), ('View %s says "%s", expected "%s"'):format(id, tostring(description), text))
end)
K.step('the crafting app should not have the view {string}', 'client', function(_, id)
    assert(not craftingView(id), 'The crafting app has the view ' .. id)
end)

local function registryHas(list, id)
    for _, entry in ipairs(K.must(hook('registry'))[list] or {}) do
        if entry == id then return true end
    end
    return false
end
K.step('the crafting server should have the station {string}', 'client', function(ctx, id)
    ctx:waitUntil(function() return registryHas('stations', id) end, 'The server has no station ' .. id, 3000)
end)
K.step('the crafting server should not have the station {string}', 'client', function(ctx, id)
    ctx:waitUntil(function() return not registryHas('stations', id) end, 'The server still has the station ' .. id, 3000)
end)
K.step('the crafting server should have {int} test recipes', 'client', function(ctx, count)
    ctx:waitUntil(function() return #(K.must(hook('registry')).recipes or {}) == count end,
        'The server does not have ' .. count .. ' fft_ recipes', 3000)
end)
