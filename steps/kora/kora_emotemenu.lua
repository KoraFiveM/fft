-- kora_emotemenu: emotes, walk styles and facial expressions.
-- Driven through the real chat commands (/e, /cancel, /walk, /expression,
-- /emotes) and exports; the menu is a kora_lib menu, so kora_lib's hook answers
-- it. Every emote started here is cancelled in cleanup and the tester's walk
-- style and expression are put back. No resource hook.
local K = FFT.kora
if not K then return end
K.feature('kora_emotemenu')

local function bag(key) return LocalPlayer.state['kora_emotemenu:' .. key] end

local function cancelAfterwards(ctx)
    if ctx.state.emoteCleanup then return end
    ctx.state.emoteCleanup = true
    ctx:cleanup(function() pcall(function() exports.kora_emotemenu:cancelEmote(true) end) end)
end

-- ---------------------------------------------------------------------------
-- Emotes (client)
-- ---------------------------------------------------------------------------

K.step('I play the emote {string}', 'client', function(ctx, name)
    assert(name:match('^[%w_%-]+$'), 'Emote name must be a single word')
    cancelAfterwards(ctx)
    ExecuteCommand('e ' .. name)
end)

K.step('I cancel my emote', 'client', function() ExecuteCommand('cancel') end)

K.step('the emote {string} should be playing', 'client', function(ctx, name)
    cancelAfterwards(ctx)
    ctx:waitUntil(function()
        return K.export('kora_emotemenu', 'isInEmote') == true and bag('active') == name
    end, ('Emote %s is not playing (active: %s)'):format(name, tostring(bag('active'))), 8000)
    ctx:equal(K.export('kora_emotemenu', 'getLastEmote'), name, 'Last emote')
end)

K.step('no emote should be playing', 'client', function(ctx)
    ctx:waitUntil(function()
        return K.export('kora_emotemenu', 'isInEmote') == false and not bag('active')
    end, 'An emote is still playing: ' .. tostring(bag('active')), 3000)
end)

K.step('my last emote should be {string}', 'client', function(ctx, name)
    ctx:equal(K.export('kora_emotemenu', 'getLastEmote'), name, 'Last emote')
end)

K.step('playing the emote {string} through the export should be refused with {string}', 'client', function(ctx, name, reason)
    cancelAfterwards(ctx)
    local ok, err = K.export('kora_emotemenu', 'playEmote', name)
    ctx:equal(ok, false, 'playEmote result')
    ctx:equal(err, reason, 'Refusal reason')
end)

-- registerEmote validates with assert(), so a refusal arrives as an export error.
-- Only an invalid name is tried: a successful registration could not be undone.
K.step('registering an emote named {string} should be refused', 'client', function(_, name)
    assert(not name:match('^[%w_%-]+$'), 'This step only tries names the resource must refuse')
    K.started('kora_emotemenu')
    local ok, err = pcall(function()
        exports.kora_emotemenu:registerEmote(name, {
            label = 'FFT refused emote', type = 'anim', hidden = true,
            dict = 'friends@frj@ig_1', clip = 'wave_a',
        })
    end)
    assert(not ok, 'registerEmote accepted the invalid name "' .. name .. '"')
    -- An export that raises without yielding loses its message at the resource
    -- boundary: the callee's SetCallRefRoutine returns msgpack nil and the caller
    -- raises error() with no value (citizen/scripting/lua/scheduler.lua), so the
    -- caller sees only the wrapper below with "nil"; the assert text from
    -- kora_emotemenu/client/main.lua:624 goes to the client console. The reason
    -- is checked only when it survived; the next step proves nothing was registered.
    local text = tostring(err)
    assert(K.contains(text, 'calling export `registerEmote` in resource `kora_emotemenu`'), 'Unexpected refusal: ' .. text)
    assert(text:find(':\n  nil\n', 1, true) or K.contains(text, 'Emote name must contain only letters'),
        'Unexpected refusal: ' .. text)
end)

-- ---------------------------------------------------------------------------
-- Emote state as the server sees it (replicated player state bags)
-- ---------------------------------------------------------------------------

local function serverBag(ctx, key) return Player(ctx.tester).state['kora_emotemenu:' .. key] end

K.step('the server should see me playing the emote {string}', 'server', function(ctx, name)
    ctx:waitUntil(function() return serverBag(ctx, 'active') == name end,
        ('Server sees active emote %s, expected %s'):format(tostring(serverBag(ctx, 'active')), name), 5000)
    ctx:equal(serverBag(ctx, 'last'), name, 'Last emote on the server')
end)

K.step('the server should see me playing no emote', 'server', function(ctx)
    ctx:waitUntil(function() return not serverBag(ctx, 'active') end,
        'Server still sees the emote ' .. tostring(serverBag(ctx, 'active')), 5000)
end)

K.step('the server should see my walk style as {string}', 'server', function(ctx, name)
    ctx:waitUntil(function() return serverBag(ctx, 'walk') == name end,
        ('Server sees walk style %s, expected %s'):format(tostring(serverBag(ctx, 'walk')), name), 5000)
end)

K.step('the server should see my expression as {string}', 'server', function(ctx, name)
    ctx:waitUntil(function() return serverBag(ctx, 'expression') == name end,
        ('Server sees expression %s, expected %s'):format(tostring(serverBag(ctx, 'expression')), name), 5000)
end)

-- ---------------------------------------------------------------------------
-- Walk style and expression (client). Both persist in the resource's KVP, so the
-- value found before the scenario is restored quietly afterwards.
-- ---------------------------------------------------------------------------

local function protectWalk(ctx)
    if ctx.state.walkProtected then return end
    ctx.state.walkProtected = true
    local original = bag('walk') or 'default'
    ctx:cleanup(function() pcall(function() exports.kora_emotemenu:setWalk(original, true) end) end)
end

local function protectExpression(ctx)
    if ctx.state.expressionProtected then return end
    ctx.state.expressionProtected = true
    -- The bag is nil for the default expression.
    local original = bag('expression') or 'default'
    ctx:cleanup(function() pcall(function() exports.kora_emotemenu:setExpression(original, true) end) end)
end

K.step('I set my walk style to {string}', 'client', function(ctx, name)
    assert(name:match('^[%w_%-]+$'), 'Walk style must be a single word')
    protectWalk(ctx)
    ExecuteCommand('walk ' .. name)
end)

K.step('my walk style should be {string}', 'client', function(ctx, name)
    ctx:waitUntil(function() return bag('walk') == name end,
        ('Walk style is %s, expected %s'):format(tostring(bag('walk')), name), 5000)
end)

K.step('my walk style should stay as it was after I try the walk style {string}', 'client', function(ctx, name)
    assert(name:match('^[%w_%-]+$'), 'Walk style must be a single word')
    protectWalk(ctx)
    local before = bag('walk')
    ExecuteCommand('walk ' .. name)
    Wait(500)
    ctx:equal(bag('walk'), before, 'Walk style after a refused change')
end)

K.step('I set my expression to {string}', 'client', function(ctx, name)
    assert(name:match('^[%w_%-]+$'), 'Expression must be a single word')
    protectExpression(ctx)
    ExecuteCommand('expression ' .. name)
end)

K.step('my expression should be {string}', 'client', function(ctx, name)
    local expected = name ~= 'default' and name or nil
    ctx:waitUntil(function() return bag('expression') == expected end,
        ('Expression is %s, expected %s'):format(tostring(bag('expression')), name), 5000)
end)

K.step('my expression should stay as it was after I try the expression {string}', 'client', function(ctx, name)
    assert(name:match('^[%w_%-]+$'), 'Expression must be a single word')
    protectExpression(ctx)
    local before = bag('expression')
    ExecuteCommand('expression ' .. name)
    Wait(500)
    ctx:equal(bag('expression'), before, 'Expression after a refused change')
end)

-- ---------------------------------------------------------------------------
-- Menu (client). Choosing an entry may start an emote or change the walk style
-- or expression, so all three are protected before the menu opens.
-- ---------------------------------------------------------------------------

K.step('I open the emote menu', 'client', function(ctx)
    cancelAfterwards(ctx)
    protectWalk(ctx)
    protectExpression(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('menu.cancel') end) end)
    ExecuteCommand('emotes')
end)

-- ===========================================================================
-- Round 3: exports, refusals, cuffed block, menu marks and emote maker checks.
-- Sources: kora_emotemenu/client/main.lua, client/emote_creator.lua,
-- server/emote_creator.lua, config.lua, shared/emotes.lua.
-- ===========================================================================

K.step('playing the emote {string} through the export should succeed', 'client', function(ctx, name)
    cancelAfterwards(ctx)
    local ok, err = K.export('kora_emotemenu', 'playEmote', name)
    ctx:equal(ok, true, 'playEmote result (' .. tostring(err) .. ')')
end)

-- client/main.lua:131-146: cancelEmote returns whether an emote was active.
K.step('cancelling my emote through the export should report that it stopped one', 'client', function(ctx)
    ctx:equal(K.export('kora_emotemenu', 'cancelEmote'), true, 'cancelEmote result')
end)
K.step('cancelling my emote through the export should report that nothing was playing', 'client', function(ctx)
    ctx:equal(K.export('kora_emotemenu', 'cancelEmote'), false, 'cancelEmote result')
end)

-- client/main.lua:223-238: shared emotes look for another player within Config.syncDistance (3.0).
K.step('nobody else is within reach for a shared emote', 'client', function()
    local me = GetEntityCoords(PlayerPedId())
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            if DoesEntityExist(ped) and #(GetEntityCoords(ped) - me) <= 3.0 then
                error('Another player is within 3 m; this scenario needs the tester alone', 0)
            end
        end
    end
end)

K.step('the server should remember my last emote as {string}', 'server', function(ctx, name)
    ctx:waitUntil(function() return serverBag(ctx, 'last') == name end,
        ('Server sees last emote %s, expected %s'):format(tostring(serverBag(ctx, 'last')), name), 5000)
end)

K.step('the server should see no expression on me', 'server', function(ctx)
    ctx:waitUntil(function() return serverBag(ctx, 'expression') == nil end,
        'Server still sees the expression ' .. tostring(serverBag(ctx, 'expression')), 5000)
end)

K.step('setting the walk style {string} through the export should be refused with {string}', 'client', function(ctx, name, reason)
    protectWalk(ctx)
    local before = bag('walk')
    local ok, err = K.export('kora_emotemenu', 'setWalk', name)
    ctx:equal(ok, false, 'setWalk result')
    ctx:equal(err, reason, 'Refusal reason')
    ctx:equal(bag('walk'), before, 'Walk style after a refused change')
end)

K.step('setting the expression {string} through the export should be refused with {string}', 'client', function(ctx, name, reason)
    protectExpression(ctx)
    local before = bag('expression')
    local ok, err = K.export('kora_emotemenu', 'setExpression', name)
    ctx:equal(ok, false, 'setExpression result')
    ctx:equal(err, reason, 'Refusal reason')
    ctx:equal(bag('expression'), before, 'Expression after a refused change')
end)

K.step('I reset my walk style through the export', 'client', function(ctx)
    protectWalk(ctx)
    ctx:equal(K.export('kora_emotemenu', 'resetWalk'), true, 'resetWalk result')
end)
K.step('I reset my expression through the export', 'client', function(ctx)
    protectExpression(ctx)
    ctx:equal(K.export('kora_emotemenu', 'resetExpression'), true, 'resetExpression result')
end)

-- ---------------------------------------------------------------------------
-- Cuffed: canUse (client/main.lua:25-30) also reads the third-party keys
-- `handcuffed` and `isCuffed`. They are set locally (not replicated) and cleared
-- in cleanup; koraCuffed belongs to kora_police's server and is never touched.
-- ---------------------------------------------------------------------------

local CUFF_KEYS = { handcuffed = true, isCuffed = true }

local function clearCuffs(ctx)
    for key in pairs(ctx.state.cuffKeys or {}) do LocalPlayer.state:set(key, nil, false) end
    ctx.state.cuffKeys = {}
end

K.step('a third-party cuff script marks me as cuffed with the state key {string}', 'client', function(ctx, key)
    assert(CUFF_KEYS[key], 'Only the third-party keys handcuffed and isCuffed are used')
    cancelAfterwards(ctx)
    if not ctx.state.cuffKeys then
        ctx.state.cuffKeys = {}
        ctx:cleanup(function()
            for name in pairs(ctx.state.cuffKeys or {}) do LocalPlayer.state:set(name, nil, false) end
        end)
    end
    ctx.state.cuffKeys[key] = true
    LocalPlayer.state:set(key, true, false)
    ctx:waitUntil(function() return LocalPlayer.state[key] == true end, 'The cuff state did not apply', 2000)
end)

K.step('the third-party cuff state is cleared', 'client', function(ctx)
    clearCuffs(ctx)
    ctx:waitUntil(function() return not LocalPlayer.state.handcuffed and not LocalPlayer.state.isCuffed end,
        'The cuff state did not clear', 2000)
end)

-- ---------------------------------------------------------------------------
-- Menu: other ways to open it and the item flags menuItems() sets.
-- openMenu waits for the menu's answer, so the export runs in its own thread.
-- ---------------------------------------------------------------------------

local function protectMenu(ctx)
    cancelAfterwards(ctx)
    protectWalk(ctx)
    protectExpression(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('menu.cancel') end) end)
end

K.step('I open the emote menu with the bare emote command', 'client', function(ctx)
    protectMenu(ctx)
    ExecuteCommand('e')
end)

K.step('I open the emote menu through the export', 'client', function(ctx)
    protectMenu(ctx)
    K.started('kora_emotemenu')
    CreateThread(function() pcall(function() exports.kora_emotemenu:toggleMenu() end) end)
end)

local function menuEntry(ctx, id)
    local menu = K.waitMenu(ctx)
    for _, item in ipairs(menu.items or {}) do
        if item.id == id then return item end
    end
    error('The emote menu has no entry ' .. id, 0)
end

K.step('the emote menu entry {string} should be disabled', 'client', function(ctx, id)
    ctx:equal(menuEntry(ctx, id).disabled, true, 'Disabled flag of ' .. id)
end)
K.step('the emote menu entry {string} should be enabled', 'client', function(ctx, id)
    ctx:equal(menuEntry(ctx, id).disabled, false, 'Disabled flag of ' .. id)
end)
K.step('the emote menu entry {string} should be described as {string}', 'client', function(ctx, id, text)
    ctx:equal(menuEntry(ctx, id).description, text, 'Description of ' .. id)
end)
K.step('the emote menu entry {string} should not be marked active', 'client', function(ctx, id)
    local item = menuEntry(ctx, id)
    assert(item.description ~= 'Currently active', id .. ' is marked as currently active')
end)
K.step('choosing the disabled emote menu entry {string} should be refused', 'client', function(ctx, id)
    K.waitMenu(ctx)
    local ok, err, code = K.ui('menu.select', id)
    assert(not ok, 'The disabled entry was accepted: ' .. id)
    ctx:equal(code, 'disabled', 'Refusal code (' .. tostring(err) .. ')')
end)

-- ---------------------------------------------------------------------------
-- registerEmote: each definition breaks exactly one assert in
-- client/main.lua:623-631. Refusals only; a registration cannot be undone.
-- ---------------------------------------------------------------------------

local INVALID_DEFINITIONS = {
    not_a_table = function() return 'not a table' end,
    no_label = function() return { type = 'anim', hidden = true, dict = 'friends@frj@ig_1', clip = 'wave_a' } end,
    label_not_text = function() return { label = 5, type = 'anim', hidden = true, dict = 'friends@frj@ig_1', clip = 'wave_a' } end,
    unknown_type = function() return { label = 'FFT', type = 'ped', hidden = true, dict = 'friends@frj@ig_1', clip = 'wave_a' } end,
    no_type = function() return { label = 'FFT', hidden = true, dict = 'friends@frj@ig_1', clip = 'wave_a' } end,
    visible_without_category = function() return { label = 'FFT', type = 'anim', dict = 'friends@frj@ig_1', clip = 'wave_a' } end,
    visible_unknown_category = function() return { label = 'FFT', type = 'anim', category = 'fft_none', dict = 'friends@frj@ig_1', clip = 'wave_a' } end,
    anim_without_dict = function() return { label = 'FFT', type = 'anim', hidden = true, clip = 'wave_a' } end,
    anim_without_clip = function() return { label = 'FFT', type = 'anim', hidden = true, dict = 'friends@frj@ig_1' } end,
    scenario_without_scenario = function() return { label = 'FFT', type = 'scenario', hidden = true } end,
}

K.step('registering an emote with the invalid definition {string} should be refused', 'client', function(_, case)
    local build = assert(INVALID_DEFINITIONS[case], 'Unknown invalid definition case: ' .. case)
    K.started('kora_emotemenu')
    local ok, err = pcall(function() exports.kora_emotemenu:registerEmote('fft_refused_emote', build()) end)
    assert(not ok, 'registerEmote accepted the invalid definition ' .. case)
    -- See the name refusal step above: the assert text rarely survives the export boundary.
    assert(K.contains(tostring(err), 'registerEmote'), 'Unexpected refusal: ' .. tostring(err))
end)

-- ---------------------------------------------------------------------------
-- Emote maker. Driven through the creator page's own NUI callbacks
-- (creator:change, creator:action in client/emote_creator.lua); the editor is
-- reset with the page's own 'new' action afterwards. The server applies a 2 s
-- save and 1 s delete cooldown that drops requests silently
-- (server/emote_creator.lua:3-4), so requests are spaced past it.
-- ---------------------------------------------------------------------------

local lastSaveAt, lastDeleteAt = -100000, -100000

local function resetEditorAfterwards(ctx)
    if ctx.state.editorReset then return end
    ctx.state.editorReset = true
    ctx:cleanup(function()
        pcall(function() FFT.nui('kora_emotemenu', 'creator:action', { action = 'new' }, 2000) end)
    end)
end

local function editor(ctx, data)
    resetEditorAfterwards(ctx)
    K.nui('kora_emotemenu', 'creator:action', { action = 'new' })
    if data then K.nui('kora_emotemenu', 'creator:change', data) end
end

local function spaced(ctx, last, gap)
    ctx:waitUntil(function() return GetGameTimer() - last >= gap end, 'Cooldown wait overran', gap + 500)
end

-- Values for the editor's required fields (client/emote_creator.lua:332-337).
local FILLED = { name = 'fft_probe', label = 'FFT probe', dict = 'missfam4', clip = 'base' }

K.step('the emote maker editor has only these fields filled: {string}', 'client', function(ctx, list)
    local data = { name = '', label = '', dict = '', clip = '', category = 'general', editingName = nil }
    if list ~= 'none' then
        for field in list:gmatch('[^,]+') do
            data[field] = assert(FILLED[field], 'Unknown editor field: ' .. field)
        end
    end
    editor(ctx, data)
end)

K.step('saving in the emote maker should be refused', 'client', function(ctx)
    local answer = K.nui('kora_emotemenu', 'creator:action', { action = 'save' })
    ctx:equal(type(answer) == 'table' and answer.ok, false, 'creator:action save answer')
end)

K.step('I ask the emote maker to preview', 'client', function(ctx)
    cancelAfterwards(ctx)
    K.nui('kora_emotemenu', 'creator:action', { action = 'play' })
    ctx:cleanup(function() pcall(function() FFT.nui('kora_emotemenu', 'creator:action', { action = 'stop' }, 2000) end) end)
end)

local VALID = { name = 'fft_probe', label = 'FFT probe', category = 'general', dict = 'missfam4', clip = 'base', flag = 49 }
local function with(changes)
    local out = {}
    for k, v in pairs(VALID) do out[k] = v end
    for k, v in pairs(changes) do out[k] = v end
    return out
end
local function prop(model, bone, offsetX)
    return { modelName = model, bone = bone, offset = { x = offsetX or 0.0, y = 0.0, z = 0.0 }, rotation = { x = 0.0, y = 0.0, z = 0.0 } }
end

-- Each case breaks exactly one check in buildEmote / the save handler
-- (server/emote_creator.lua:52-95, 112-125). name_taken uses the built-in wave.
local INVALID_SAVES = {
    name_with_space = with({ name = 'fft probe' }),
    name_with_dot = with({ name = 'fft.probe' }),
    name_too_long = with({ name = string.rep('a', 33) }),
    category_scenarios = with({ category = 'scenarios' }),
    category_shared = with({ category = 'shared' }),
    category_unknown = with({ category = 'fft_none' }),
    dict_with_space = with({ dict = 'miss fam4' }),
    dict_too_long = with({ dict = string.rep('a', 129) }),
    clip_with_space = with({ clip = 'ba se' }),
    flag_negative = with({ flag = -1 }),
    flag_too_big = with({ flag = 65536 }),
    prop_bad_model = with({ props = { prop('bad model!', 0) } }),
    prop_offset_too_far = with({ props = { prop('p_amb_coffeecup_01', 28422, 5000.0) } }),
    second_prop_bad_bone = with({ props = { prop('p_amb_coffeecup_01', 28422), prop('p_amb_clipboard_01', -1) } }),
    name_taken = with({ name = 'wave' }),
    editing_unknown = with({ editingName = 'fft_no_such_saved' }),
}

K.step('I fill the emote maker with the invalid case {string} and save', 'client', function(ctx, case)
    local data = assert(INVALID_SAVES[case], 'Unknown invalid save case: ' .. case)
    editor(ctx, data)
    spaced(ctx, lastSaveAt, 2100)
    lastSaveAt = GetGameTimer()
    local answer = K.nui('kora_emotemenu', 'creator:action', { action = 'save' })
    ctx:equal(type(answer) == 'table' and answer.ok, true, 'The editor stopped the save before the server saw it')
end)

K.step('I ask the emote maker to delete the saved emote {string}', 'client', function(ctx, name)
    resetEditorAfterwards(ctx)
    spaced(ctx, lastDeleteAt, 1100)
    lastDeleteAt = GetGameTimer()
    K.nui('kora_emotemenu', 'creator:action', { action = 'delete', name = name })
end)

-- The server checks the "command" ACE first (server/emote_creator.lua:100,145),
-- so a tester without it gets the permission refusal instead; either is a refusal.
local function emoteMakerAnswer(ctx, text, permission)
    local entry = ctx:waitUntil(function()
        for _, e in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            if K.contains(e.message, text) or K.contains(e.message, permission) then return e end
        end
    end, 'The emote maker did not answer "' .. text .. '"', 5000)
    if K.contains(entry.message, permission) then
        print(('[fft] kora_emotemenu: tester lacks the "command" ACE; got the permission refusal instead of "%s"'):format(text))
    end
    ctx:equal(entry.type, 'error', 'Notification type')
end

K.step('the emote maker should answer {string} unless I lack permission to create emotes', 'client', function(ctx, text)
    emoteMakerAnswer(ctx, text, 'You do not have permission to create emotes.')
end)
K.step('the emote maker should answer {string} unless I lack permission to delete emotes', 'client', function(ctx, text)
    emoteMakerAnswer(ctx, text, 'You do not have permission to delete emotes.')
end)

-- shared/created.json is the store the save and delete handlers rewrite.
K.step('I remember the saved emote file', 'server', function(ctx)
    K.started('kora_emotemenu')
    ctx.state.createdJson = LoadResourceFile('kora_emotemenu', 'shared/created.json') or ''
end)
K.step('the saved emote file should be unchanged', 'server', function(ctx)
    local before = assert(ctx.state.createdJson, 'Remember the saved emote file first')
    Wait(1000)
    ctx:equal(LoadResourceFile('kora_emotemenu', 'shared/created.json') or '', before, 'shared/created.json')
end)
