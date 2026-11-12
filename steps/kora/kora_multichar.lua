-- kora_multichar: character select, spawn select and the scene studio.
--
-- HAZARD: the tester IS the character under test. Opening character select,
-- selecting, creating or deleting a character, /logout and the scene studio
-- all replace or log out that character, so none of them is driven here.
-- What is asserted instead is what the server answers to a player who is
-- already in game: the mode guards, the nationality rule and the scene
-- registry's ownership and schema rules. Every asserted path is a refusal or
-- read-only, so nothing needs restoring; a cleanup still leaves the cinematic
-- mode in case a guard ever lets the tester in.
local K = FFT.kora
if not K then return end
K.feature('kora_multichar')

local MULTICHAR = 'kora_multichar'
-- Player state keys written by kora_multichar/server.lua and kora_core.
local MODE_KEY, LOGGED_IN_KEY = 'kora_multichar:mode', 'kora_core:loggedIn'

-- kora_lib/local/callback/server.lua:250 answers a request over the
-- callback's rateLimit with 'Callback rate limit exceeded; retry in %dms.',
-- which rejects the client's trigger. The mode and nationality callbacks allow
-- 8 requests per 10 s (kora_multichar/server.lua), and this feature sends more
-- than that in one run, so an ordinary step waits out the window (bounded to
-- 12 s) instead of failing on a limit an earlier scenario used up.
local function rateLimited(err)
    return K.contains(tostring(err), 'rate limit')
end

local function rawHook(action, ...)
    local packed = table.pack(pcall(K.hook, MULTICHAR, action, ...))
    if not packed[1] then return false, packed[2] end
    local _, result = K.must(packed[2], packed[3])
    assert(type(result) == 'table', ('%s answered with %s'):format(action, type(result)))
    return true, result
end

local function hook(action, ...)
    local deadline = GetGameTimer() + 12000
    while true do
        local ok, result = rawHook(action, ...)
        if ok then return result end
        if not rateLimited(result) or GetGameTimer() >= deadline then error(tostring(result), 0) end
        Wait(500)
    end
end

-- ---------------------------------------------------------------------------
-- Mode guards (kora_multichar:server:enterMode / leaveMode)
-- ---------------------------------------------------------------------------
K.step('the character select hooks should be version {int}', 'client', function(ctx, version)
    ctx:equal(K.export(MULTICHAR, 'fftVersion'), version, 'kora_multichar fftVersion')
end)

K.step('I remember my routing bucket before asking for a cinematic mode', 'server', function(ctx)
    ctx.state.multicharBucket = GetPlayerRoutingBucket(ctx.tester)
end)
K.step('my routing bucket should be the one I remembered', 'server', function(ctx)
    local before = assert(ctx.state.multicharBucket, 'Remember the routing bucket first')
    ctx:equal(GetPlayerRoutingBucket(ctx.tester), before, 'Routing bucket')
end)
K.step('the server should record that I am logged in and in no cinematic mode', 'server', function(ctx)
    local state = Player(ctx.tester).state
    ctx:equal(state[LOGGED_IN_KEY] == true, true, LOGGED_IN_KEY)
    -- server.lua writes false (never nil) when no mode is active; a player who
    -- never opened character select since the resource started has no value.
    local mode = state[MODE_KEY]
    assert(mode == nil or mode == false, MODE_KEY .. ' is ' .. tostring(mode))
end)

K.step('I ask the server for the cinematic mode {string}', 'client', function(ctx, mode)
    ctx:cleanup(function()
        local current = LocalPlayer.state[MODE_KEY]
        if current ~= nil and current ~= false then
            pcall(function() exports[MULTICHAR]:fftAction('leaveMode') end)
        end
    end)
    ctx.state.multicharEnter = hook('enterMode', mode)
end)
K.step('the cinematic mode should be refused with {string}', 'client', function(ctx, reason)
    local answer = assert(ctx.state.multicharEnter, 'Ask for a cinematic mode first')
    assert(answer.entered == false, 'The server let a logged-in player into the mode (it was left again: '
        .. tostring(answer.leftAgain) .. ')')
    ctx:equal(answer.reason, reason, 'Refusal reason')
end)
K.step('I should not be in a cinematic mode', 'client', function(ctx)
    local mode = LocalPlayer.state[MODE_KEY]
    assert(mode == nil or mode == false, MODE_KEY .. ' is ' .. tostring(mode))
    ctx:equal(LocalPlayer.state[LOGGED_IN_KEY] == true, true, LOGGED_IN_KEY)
end)
K.step('I ask the server to leave the cinematic mode without being in one', 'client', function(ctx)
    ctx.state.multicharLeave = hook('leaveMode')
end)
K.step('leaving the cinematic mode should be acknowledged', 'client', function(ctx)
    local answer = assert(ctx.state.multicharLeave, 'Ask to leave the cinematic mode first')
    ctx:equal(answer.left, true, 'leaveMode answer')
    ctx:waitUntil(function() return LocalPlayer.state[MODE_KEY] == false end,
        MODE_KEY .. ' was not written as false', 3000)
end)

-- ---------------------------------------------------------------------------
-- Nationality rule (kora_multichar:server:validateNationality)
-- ---------------------------------------------------------------------------
K.step('the server checks the nationality {string}', 'client', function(ctx, value)
    ctx.state.multicharNationality = hook('validateNationality', value)
end)
K.step('the server checks a nationality that is not text', 'client', function(ctx)
    ctx.state.multicharNationality = hook('validateNationality', 42)
end)
K.step('the nationality should be accepted as {string}', 'client', function(ctx, expected)
    local answer = assert(ctx.state.multicharNationality, 'Check a nationality first')
    assert(answer.ok == true, 'Nationality was refused: ' .. tostring(answer.result))
    ctx:equal(answer.result, expected, 'Stored nationality')
end)
K.step('the nationality should be refused with {string}', 'client', function(ctx, reason)
    local answer = assert(ctx.state.multicharNationality, 'Check a nationality first')
    assert(answer.ok == false, 'Nationality was accepted as ' .. tostring(answer.result))
    ctx:equal(answer.result, reason, 'Refusal reason')
end)

-- ---------------------------------------------------------------------------
-- Scene registry
-- ---------------------------------------------------------------------------
K.step('I fetch the character select scenes', 'client', function(ctx)
    ctx.state.multicharScenes = hook('scenes')
end)
K.step('the scenes should include {string}', 'client', function(ctx, id)
    local scenes = assert(ctx.state.multicharScenes, 'Fetch the scenes first')
    local scene = scenes[id]
    assert(type(scene) == 'table', 'Scene is not registered: ' .. id)
    assert(type(scene.label) == 'string' and #scene.label > 0 and #scene.label <= 64, 'Scene ' .. id .. ' has no valid label')
    -- SceneSchema.validate requires 1..Config.sceneLimits.maxCameras cameras.
    assert(scene.cameras >= 1 and scene.cameras <= 8, ('Scene %s has %d cameras'):format(id, scene.cameras))
end)
K.step('the scenes should not include {string}', 'client', function(ctx, id)
    local scenes = assert(ctx.state.multicharScenes, 'Fetch the scenes first')
    assert(scenes[id] == nil, 'Scene is registered: ' .. id)
end)

-- The exports run with FFT as the invoking resource. Only refusals are driven:
-- an accepted registration is broadcast to every connected client.
local function sceneAnswer(ctx, ok, err)
    ctx.state.multicharScene = { ok = ok, err = err }
end
K.step('another resource registers a scene over the bundled scene {string}', 'server', function(ctx, id)
    sceneAnswer(ctx, K.export(MULTICHAR, 'RegisterScene', id, { label = 'FFT takeover attempt' }))
end)
K.step('another resource registers a scene with the id {string} and no label', 'server', function(ctx, id)
    sceneAnswer(ctx, K.export(MULTICHAR, 'RegisterScene', id, {}))
end)
K.step('another resource registers a scene with the id {string} that is not a table', 'server', function(ctx, id)
    sceneAnswer(ctx, K.export(MULTICHAR, 'RegisterScene', id, 'not a scene'))
end)
K.step('another resource unregisters the scene {string}', 'server', function(ctx, id)
    sceneAnswer(ctx, K.export(MULTICHAR, 'UnregisterScene', id))
end)
K.step('the scene request should be refused with {string}', 'server', function(ctx, reason)
    local answer = assert(ctx.state.multicharScene, 'Send a scene request first')
    assert(not answer.ok, 'The scene request was accepted')
    ctx:equal(answer.err, reason, 'Refusal reason')
end)

-- ---------------------------------------------------------------------------
-- Legacy surface
-- ---------------------------------------------------------------------------
K.step('the legacy character select server log request should answer with an empty list', 'client', function()
    local _, result = K.must(K.hook(MULTICHAR, 'serverLogs'))
    assert(type(result) == 'table' and next(result) == nil, 'GetServerLogs did not answer with an empty table')
end)
K.step('the character select resource should provide the legacy name {string}', 'server', function(_, name)
    -- provide '<name>' lines in kora_multichar/fxmanifest.lua.
    K.started(MULTICHAR)
    local found = false
    for index = 0, GetNumResourceMetadata(MULTICHAR, 'provide') - 1 do
        if GetResourceMetadata(MULTICHAR, 'provide', index) == name then found = true end
    end
    assert(found, 'kora_multichar does not provide ' .. name)
end)

-- ---------------------------------------------------------------------------
-- Round 3: rate limits, more nationality inputs, scene schema refusals
-- ---------------------------------------------------------------------------

-- Callback rateLimit = { max = 8, window = 10000 } on
-- kora_multichar:server:validateNationality (kora_multichar/server.lua).
local RATE_MAX, RATE_WINDOW = 8, 10000

K.step('the character select rate limit window has passed', 'client', function(ctx)
    -- Every earlier request is older than the window once it has elapsed.
    local deadline = GetGameTimer() + RATE_WINDOW + 300
    while GetGameTimer() < deadline do ctx:check() Wait(100) end
end)

K.step('the server checks the nationality {string} as often as the rate limit allows', 'client', function(ctx, value)
    local answers = {}
    for index = 1, RATE_MAX do
        local ok, result = rawHook('validateNationality', value)
        assert(ok, ('Request %d of %d was refused: %s'):format(index, RATE_MAX, tostring(result)))
        answers[#answers + 1] = result
    end
    ctx.state.multicharBurst = answers
end)
K.step('every one of those nationality checks should be accepted as {string}', 'client', function(ctx, expected)
    local answers = assert(ctx.state.multicharBurst, 'Send the burst of nationality checks first')
    ctx:equal(#answers, RATE_MAX, 'Answered nationality checks')
    for index, answer in ipairs(answers) do
        assert(answer.ok == true, ('Check %d was refused: %s'):format(index, tostring(answer.result)))
        ctx:equal(answer.result, expected, 'Nationality ' .. index)
    end
end)
K.step('one more nationality check should be refused by the callback rate limit', 'client', function()
    local ok, result = rawHook('validateNationality', 'American')
    assert(not ok, 'The server answered a request over its rate limit: ' .. tostring(type(result) == 'table' and result.result))
    assert(rateLimited(result), 'Refused for another reason: ' .. tostring(result))
end)

-- server.lua: value:match('^%s*(.-)%s*$') trims tabs and newlines too.
K.step('the server checks the nationality {string} wrapped in tabs and newlines', 'client', function(ctx, value)
    ctx.state.multicharNationality = hook('validateNationality', '\t\n' .. value .. '\n\t')
end)
K.step('the server checks a missing nationality', 'client', function(ctx)
    ctx.state.multicharNationality = hook('validateNationality', nil)
end)
K.step('the server checks a nationality given as a boolean', 'client', function(ctx)
    ctx.state.multicharNationality = hook('validateNationality', true)
end)
-- The hook only forwards strings up to 64 bytes; 40 is well inside that and
-- longer than every Config.nationalities entry.
K.step('the server checks a nationality of {int} repeated letters', 'client', function(ctx, length)
    assert(length >= 1 and length <= 64, 'Length must be 1-64')
    ctx.state.multicharNationality = hook('validateNationality', ('A'):rep(length))
end)

K.step('I ask the server to leave the cinematic mode {int} times', 'client', function(ctx, times)
    assert(times >= 1 and times <= 4, 'Leave at most 4 times (rate limit is 8 per 10 s)')
    local answers = {}
    for index = 1, times do answers[index] = hook('leaveMode') end
    ctx.state.multicharLeaves = answers
end)
K.step('every leave request should be acknowledged', 'client', function(ctx)
    local answers = assert(ctx.state.multicharLeaves, 'Leave the cinematic mode first')
    for index, answer in ipairs(answers) do ctx:equal(answer.left, true, 'leaveMode answer ' .. index) end
    ctx:waitUntil(function() return LocalPlayer.state[MODE_KEY] == false end, MODE_KEY .. ' was not written as false', 3000)
end)

-- Bundled scenes in kora_multichar/scenes.lua: label and priority per id, and
-- every one builds its cameras with revealCameras (close, focal, establishing).
K.step('the scene {string} should be labelled {string} with priority {int}', 'client', function(ctx, id, label, priority)
    local scenes = assert(ctx.state.multicharScenes, 'Fetch the scenes first')
    local scene = assert(scenes[id], 'Scene is not registered: ' .. id)
    ctx:equal(scene.label, label, 'Scene ' .. id .. ' label')
    ctx:equal(scene.priority, priority, 'Scene ' .. id .. ' priority')
end)
K.step('the scene {string} should have {int} cameras', 'client', function(ctx, id, cameras)
    local scenes = assert(ctx.state.multicharScenes, 'Fetch the scenes first')
    local scene = assert(scenes[id], 'Scene is not registered: ' .. id)
    ctx:equal(scene.cameras, cameras, 'Scene ' .. id .. ' cameras')
end)

-- Scene schema refusals (SceneSchema.validate in kora_multichar/shared/scene.lua).
-- Each defect breaks exactly one rule of an otherwise valid definition, and the
-- feature asserts the exact message of the first rule that fails. An accepted
-- registration is broadcast to every client, so the cleanup removes the probe
-- scene if the server ever accepts one.
local PROBE_ID = 'fft_probe_scene'
local function offset(heading)
    return { x = 0.5, y = 0.5, z = 0.5, w = heading and 10.5 or nil }
end
local function baseScene()
    return {
        label = 'FFT probe scene',
        anchor = { x = 1.5, y = 1.5, z = 1.5, w = 90.5 },
        character = { offset = offset(true) },
        cameras = { { id = 'c1', offset = { x = 2.5, y = 2.5, z = 1.5 }, lookAt = offset(false) } },
    }
end
local function prop(id, extra)
    local entity = { id = id, type = 'prop', model = 'prop_bin_08', offset = offset(true) }
    for key, value in pairs(extra or {}) do entity[key] = value end
    return entity
end
local function cameras(count, sameId)
    local list = {}
    for index = 1, count do
        list[index] = { id = sameId and 'c1' or ('c' .. index), offset = { x = 2.5, y = 2.5, z = 1.5 }, lookAt = offset(false) }
    end
    return list
end
local DEFECTS = {
    ['a 65 byte label'] = function(scene) scene.label = ('a'):rep(65) end,
    ['a control character in the label'] = function(scene) scene.label = 'FFT\nprobe' end,
    ['a 49 character id'] = function(scene) return ('f'):rep(49) end,
    ['an empty id'] = function() return '' end,
    ['a numeric id'] = function() return 42 end,
    ['a fractional priority'] = function(scene) scene.priority = 1.5 end,
    ['no anchor'] = function(scene) scene.anchor = nil end,
    ['an anchor without a heading'] = function(scene) scene.anchor = offset(false) end,
    ['no character offset'] = function(scene) scene.character = {} end,
    ['selectors that are not a list'] = function(scene) scene.selectors = { job = 'police' } end,
    ['a selector without job or gang'] = function(scene) scene.selectors = { { duty = true } } end,
    ['a selector duty that is not boolean'] = function(scene) scene.selectors = { { job = 'police', duty = 'yes' } } end,
    ['an inverted grade range'] = function(scene) scene.selectors = { { job = 'police', minGrade = 3, maxGrade = 1 } } end,
    ['an environment hour of 24'] = function(scene) scene.environment = { hour = 24 } end,
    ['an environment minute of 60'] = function(scene) scene.environment = { minute = 60 } end,
    ['an environment strength of 2'] = function(scene) scene.environment = { strength = 2 } end,
    ['an entity of an unknown type'] = function(scene) scene.entities = { prop('e1', { type = 'plane' }) } end,
    ['nine peds'] = function(scene)
        local peds = {}
        for index = 1, 9 do peds[index] = { id = 'p' .. index, type = 'ped', model = 'a_m_y_beach_02', offset = offset(true) } end
        scene.entities = peds
    end,
    ['two entities with the same id'] = function(scene) scene.entities = { prop('e1'), prop('e1') } end,
    ['a ped seated in an unknown vehicle'] = function(scene)
        scene.entities = { { id = 'p1', type = 'ped', model = 'a_m_y_beach_02', offset = offset(true), seat = { vehicle = 'ghost', index = -1 } } }
    end,
    ['a prop that snaps to water'] = function(scene) scene.entities = { prop('e1', { snapToWater = true }) } end,
    ['no cameras'] = function(scene) scene.cameras = {} end,
    ['nine cameras'] = function(scene) scene.cameras = cameras(9) end,
    ['two cameras with the same id'] = function(scene) scene.cameras = cameras(2, true) end,
    ['a camera without a look-at point'] = function(scene) scene.cameras[1].lookAt = nil end,
    ['a camera field of view of 5'] = function(scene) scene.cameras[1].fov = 5 end,
    ['a timeline longer than the limit'] = function(scene) scene.timeline = { durationMs = 120001 } end,
    ['a timeline cue of an unknown type'] = function(scene) scene.timeline = { cues = { { at = 0, type = 'explosion' } } } end,
    ['a camera cue for an unknown camera'] = function(scene) scene.timeline = { cues = { { at = 0, type = 'camera', camera = 'nope' } } } end,
    ['a cue after the end of the timeline'] = function(scene)
        scene.timeline = { durationMs = 1000, cues = { { at = 2000, type = 'camera', camera = 'c1' } } }
    end,
}

K.step('another resource registers a scene with the defect {string}', 'server', function(ctx, defect)
    local apply = assert(DEFECTS[defect], 'Unknown scene defect: ' .. defect)
    local scene = baseScene()
    local id = apply(scene)
    if id == nil then id = PROBE_ID end
    ctx:cleanup(function()
        -- Only reached if the server wrongly accepted the probe; fft owns it.
        if type(id) == 'string' then pcall(function() exports[MULTICHAR]:UnregisterScene(id) end) end
    end)
    sceneAnswer(ctx, K.export(MULTICHAR, 'RegisterScene', id, scene))
end)
K.step('another resource unregisters a scene by a numeric id', 'server', function(ctx)
    sceneAnswer(ctx, K.export(MULTICHAR, 'UnregisterScene', 42))
end)

K.step('the character select resource should depend on {string}', 'server', function(_, name)
    -- dependency lines in kora_multichar/fxmanifest.lua.
    K.started(MULTICHAR)
    for index = 0, GetNumResourceMetadata(MULTICHAR, 'dependency') - 1 do
        if GetResourceMetadata(MULTICHAR, 'dependency', index) == name then return end
    end
    error('kora_multichar does not depend on ' .. name, 0)
end)
