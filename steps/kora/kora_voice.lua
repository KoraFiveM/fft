-- kora_voice: server-authoritative radio and call membership, the restriction
-- policy, client requests, proximity modes and the radio item.
-- No resource hook: the server exports (kora_voice/server/api.lua), the state bag
-- keys (Config.state in kora_voice/config.lua) and the client exports
-- (kora_voice/client/exports.lua) are all public.
--
-- Rules taken from kora_voice/AGENTS.md: membership is asserted on the server
-- only (store, state bag, local server events). Client steps only REQUEST and
-- read the server's answer; they never assert or write membership.
--
-- Safety: every step that would put the tester on a radio channel or a call
-- first proves the channel has no members, so the tester never shares audio or
-- a roster with another player. The open test frequency and the test call id
-- are deliberately obscure.
local K = FFT.kora
if not K then return end
K.feature('kora_voice')

local RESOURCE = 'kora_voice'
-- Config.state in kora_voice/config.lua.
local RADIO_KEY, CALL_KEY = 'kora_voice:radio', 'kora_voice:call'
local RADIO_EVENT, CALL_EVENT = 'kora_voice:server:radioChanged', 'kora_voice:server:callChanged'

-- ---------------------------------------------------------------------------
-- Server helpers
-- ---------------------------------------------------------------------------

local function radioOf(ctx) return K.export(RESOURCE, 'getRadioChannel', ctx.tester) end
local function callOf(ctx) return K.export(RESOURCE, 'getCallChannel', ctx.tester) end

local function requireEmptyRadio(ctx, channel)
    local tester = ctx.tester
    for _, member in ipairs(K.export(RESOURCE, 'getRadioMembers', channel) or {}) do
        if member ~= tester then
            error(('Radio channel %d has other members; refusing to put the tester on it'):format(channel), 0)
        end
    end
end

local function requireEmptyCall(ctx, channel)
    local tester = ctx.tester
    for member in pairs(K.export(RESOURCE, 'getPlayersInCall', channel) or {}) do
        if tonumber(member) ~= tester then
            error(('Call %d has other members; refusing to put the tester in it'):format(channel), 0)
        end
    end
end

local function truth(word)
    assert(word == 'true' or word == 'false', 'Use true or false')
    return word == 'true'
end

-- Records the tester's memberships, clears them through the trusted exports and
-- restores them (and drops any test grant) afterwards. Also starts recording the
-- membership events, so it must come before any step that changes membership.
K.step('I start with no voice radio channel and no voice call', 'server', function(ctx)
    K.started(RESOURCE)
    local voice, tester = exports.kora_voice, ctx.tester
    local radio, call = voice:getRadioChannel(tester), voice:getCallChannel(tester)
    ctx:cleanup(function()
        voice:revokeRadioChannels(tester)
        voice:setPlayerRadio(tester, radio or nil)
        voice:setPlayerCall(tester, call or nil)
    end)
    voice:setPlayerRadio(tester, nil)
    voice:setPlayerCall(tester, nil)
    K.capture(ctx, RADIO_EVENT, function(src) return src == tester end)
    K.capture(ctx, CALL_EVENT, function(src) return src == tester end)
end)

-- ---------------------------------------------------------------------------
-- Server: radio membership (trusted exports)
-- ---------------------------------------------------------------------------

K.step('the voice radio channel {int} has no members', 'server', function(ctx, channel)
    requireEmptyRadio(ctx, channel)
end)

K.step('voice puts me on radio channel {int}', 'server', function(ctx, channel)
    requireEmptyRadio(ctx, channel)
    local ok, err = K.export(RESOURCE, 'setPlayerRadio', ctx.tester, channel)
    if ok ~= true then error('setPlayerRadio failed: ' .. tostring(err), 0) end
end)

K.step('I should be on voice radio channel {int}', 'server', function(ctx, channel)
    local tester = ctx.tester
    ctx:waitUntil(function() return radioOf(ctx) == channel end,
        ('Radio channel is %s, expected %d'):format(tostring(radioOf(ctx)), channel), 3000)
    ctx:equal(Player(tester).state[RADIO_KEY], channel, 'State bag ' .. RADIO_KEY)
    for _, member in ipairs(K.export(RESOURCE, 'getRadioMembers', channel) or {}) do
        if member == tester then return end
    end
    error(('The tester is not in the member list of radio channel %d'):format(channel), 0)
end)

K.step('I should be on no voice radio channel', 'server', function(ctx)
    ctx:waitUntil(function() return radioOf(ctx) == false end,
        'Radio channel is ' .. tostring(radioOf(ctx)) .. ', expected none', 3000)
    -- The cleared value is an explicit false, never a missing key (server/publish.lua).
    ctx:equal(Player(ctx.tester).state[RADIO_KEY], false, 'State bag ' .. RADIO_KEY)
end)

local function published(ctx, event, channel)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, event)) do
            if record[2] == channel then return true end
        end
    end, ('%s was not fired for the tester with %s'):format(event, tostring(channel)), 2000)
end

K.step('a voice radio change to channel {int} should have been published for me', 'server', function(ctx, channel)
    published(ctx, RADIO_EVENT, channel)
end)
K.step('a voice radio change to no channel should have been published for me', 'server', function(ctx)
    published(ctx, RADIO_EVENT, false)
end)

-- The channel argument of removePlayerFromRadio is a guard, not a target.
K.step('removing me from voice radio channel {int} should return {word}', 'server', function(ctx, channel, expected)
    ctx:equal(K.export(RESOURCE, 'removePlayerFromRadio', ctx.tester, channel), truth(expected), 'removePlayerFromRadio result')
end)

K.step('voice should refuse to put me on the radio channel {string}', 'server', function(ctx, raw)
    local ok, err = K.export(RESOURCE, 'setPlayerRadio', ctx.tester, tonumber(raw) or raw)
    ctx:equal(ok, false, 'setPlayerRadio result')
    assert(K.contains(err, 'is not a valid radio channel'), 'Unexpected error: ' .. tostring(err))
end)

K.step('the voice radio channel {int} should be restricted', 'server', function(ctx, channel)
    ctx:equal(K.export(RESOURCE, 'isChannelRestricted', channel), true, 'isChannelRestricted ' .. channel)
end)
K.step('the voice radio channel {int} should be open', 'server', function(ctx, channel)
    ctx:equal(K.export(RESOURCE, 'isChannelRestricted', channel), false, 'isChannelRestricted ' .. channel)
end)

-- A grant replaces any earlier grant for the player; the fixture step revokes it.
K.step('I am granted the voice radio channel {int}', 'server', function(ctx, channel)
    local voice, tester = exports.kora_voice, ctx.tester
    K.started(RESOURCE)
    ctx:cleanup(function() voice:revokeRadioChannels(tester) end)
    ctx:equal(voice:grantRadioChannels(tester, { channel }), 1, 'Granted channel count')
end)

-- ---------------------------------------------------------------------------
-- Server: call membership (trusted exports; there is no client join path)
-- ---------------------------------------------------------------------------

K.step('voice puts me in call {int}', 'server', function(ctx, channel)
    requireEmptyCall(ctx, channel)
    local ok, err = K.export(RESOURCE, 'setPlayerCall', ctx.tester, channel)
    if ok ~= true then error('setPlayerCall failed: ' .. tostring(err), 0) end
end)

K.step('I should be in voice call {int}', 'server', function(ctx, channel)
    ctx:waitUntil(function() return callOf(ctx) == channel end,
        ('Call channel is %s, expected %d'):format(tostring(callOf(ctx)), channel), 3000)
    ctx:equal(Player(ctx.tester).state[CALL_KEY], channel, 'State bag ' .. CALL_KEY)
end)

K.step('I should be in no voice call', 'server', function(ctx)
    ctx:waitUntil(function() return callOf(ctx) == false end,
        'Call channel is ' .. tostring(callOf(ctx)) .. ', expected none', 3000)
    ctx:equal(Player(ctx.tester).state[CALL_KEY], false, 'State bag ' .. CALL_KEY)
end)

K.step('a voice call change to channel {int} should have been published for me', 'server', function(ctx, channel)
    published(ctx, CALL_EVENT, channel)
end)

K.step('removing me from voice call {int} should return {word}', 'server', function(ctx, channel, expected)
    ctx:equal(K.export(RESOURCE, 'removePlayerFromCall', ctx.tester, channel), truth(expected), 'removePlayerFromCall result')
end)

K.step('voice should refuse to put me in the call {string}', 'server', function(ctx, raw)
    local ok, err = K.export(RESOURCE, 'setPlayerCall', ctx.tester, tonumber(raw) or raw)
    ctx:equal(ok, false, 'setPlayerCall result')
    assert(K.contains(err, 'is not a valid call channel'), 'Unexpected error: ' .. tostring(err))
end)

-- The radio item's use handler only asks the client to open its dialog
-- (kora_voice/server/item.lua). useItem is kora_core's server use path.
K.step('I use my voice radio item', 'server', function(ctx)
    local used = K.export('kora_core', 'useItem', ctx.tester, 'radio')
    if used ~= true then error('kora_core did not run the radio use handler', 0) end
end)

-- ---------------------------------------------------------------------------
-- Client: radio REQUESTS (the server decides; assert the result on the server)
-- Client radio requests are limited to 10 per 10 s (Config.rateLimit.radio).
-- ---------------------------------------------------------------------------

-- Every client radio request (kora_voice:requestRadio, kora_voice:leaveRadio
-- and the pma-voice events) shares one limiter in server/api.lua
-- consumeClientRequest: Config.rateLimit.radio, 10 per 10 s. A refused request
-- would fail the scenario that sent it, so the suite's own request steps stay
-- two under the limit across back-to-back scenarios. Requests sent by the radio
-- item dialog are paced by the step that answers the dialog.
local RADIO_BUDGET, RADIO_WINDOW = 8, 10500
local radioRequests = {}
local function paceRadio(ctx)
    while true do
        local now = GetGameTimer()
        while radioRequests[1] and now - radioRequests[1] >= RADIO_WINDOW do table.remove(radioRequests, 1) end
        if #radioRequests < RADIO_BUDGET then break end
        ctx:check()
        Wait(100)
    end
    radioRequests[#radioRequests + 1] = GetGameTimer()
end

K.step('I request the voice radio channel {int}', 'client', function(ctx, channel)
    K.started(RESOURCE)
    paceRadio(ctx)
    local ok, reason = exports.kora_voice:addPlayerToRadio(channel)
    ctx.state.voiceRequest = { ok = ok, reason = reason }
end)

local function request(ctx)
    return assert(ctx.state.voiceRequest, 'Request a voice radio channel first')
end

K.step('my voice radio request should be granted', 'client', function(ctx)
    local result = request(ctx)
    if result.ok ~= true then error('The server refused: ' .. tostring(result.reason or 'no answer'), 0) end
end)

K.step('my voice radio request should be refused with {string}', 'client', function(ctx, reason)
    local result = request(ctx)
    ctx:equal(result.ok, false, 'Request result')
    ctx:equal(result.reason, reason, 'Refusal reason')
end)

K.step('I leave my voice radio channel', 'client', function(ctx)
    paceRadio(ctx)
    ctx:equal(K.export(RESOURCE, 'removePlayerFromRadio'), true, 'Leave request result')
end)

-- pma-voice's client event. kora_voice treats it as an untrusted request for
-- `source` (kora_voice/server/compat.lua), so the policy still applies.
K.step('I send the legacy voice radio join event for channel {int}', 'client', function(ctx, channel)
    K.started(RESOURCE)
    paceRadio(ctx)
    TriggerServerEvent('pma-voice:setPlayerRadio', channel)
end)

-- ---------------------------------------------------------------------------
-- Client: proximity and local audio properties (no membership involved)
-- ---------------------------------------------------------------------------

K.step('I remember my voice settings', 'client', function(ctx)
    K.started(RESOURCE)
    local voice = exports.kora_voice
    local mode, volume = voice:getTalkingMode().index, voice:getVoiceProperty('radioVolume')
    ctx:cleanup(function()
        voice:setMegaphone(false)
        voice:setTalkingMode(mode)
        if type(volume) == 'number' then voice:setRadioVolume(volume) end
    end)
end)

K.step('I set my voice mode to {string}', 'client', function(_, name)
    K.export(RESOURCE, 'setTalkingMode', name)
end)
K.step('I set my voice mode to index {int}', 'client', function(_, index)
    K.export(RESOURCE, 'setTalkingMode', index)
end)
K.step('I cycle my voice mode', 'client', function()
    K.export(RESOURCE, 'cycleTalkingMode')
end)

K.step('my voice mode should be {string} at index {int}', 'client', function(ctx, name, index)
    local mode = K.export(RESOURCE, 'getTalkingMode')
    ctx:equal(mode.name, name, 'Voice mode name')
    ctx:equal(mode.index, index, 'Voice mode index')
end)

K.step('my voice range should be {float}', 'client', function(ctx, range)
    local actual = K.export(RESOURCE, 'getTalkingMode').range
    assert(type(actual) == 'number' and math.abs(actual - range) < 0.01,
        ('Voice range is %s, expected %s'):format(tostring(actual), tostring(range)))
end)

K.step('I switch my voice megaphone {word}', 'client', function(_, word)
    assert(word == 'on' or word == 'off', 'Use on or off')
    K.export(RESOURCE, 'setMegaphone', word == 'on')
end)

K.step('I set my voice radio volume to {int}', 'client', function(_, volume)
    K.export(RESOURCE, 'setRadioVolume', volume)
end)

K.step('my voice radio volume should be {float}', 'client', function(ctx, volume)
    local actual = K.export(RESOURCE, 'getVoiceProperty', 'radioVolume')
    assert(type(actual) == 'number' and math.abs(actual - volume) < 0.001,
        ('Radio volume is %s, expected %s'):format(tostring(actual), tostring(volume)))
end)

K.step('setting the unknown voice property {string} should fail', 'client', function(ctx, name)
    ctx:equal(K.export(RESOURCE, 'setVoiceProperty', name, 1), false, 'setVoiceProperty result')
end)

-- ===========================================================================
-- Round 3 additions
-- ===========================================================================

local function count(ctx, event)
    return #K.captured(ctx, event)
end

-- ---------------------------------------------------------------------------
-- Server: trusted radio assignment edges (server/api.lua A.assign,
-- shared/channels.lua normalise: tonumber, NaN check, math.floor, 1-1000)
-- ---------------------------------------------------------------------------

-- Raw values reach normalise as given; numeric text becomes a number first so
-- a fractional channel is floored the way a phone keypad value would be.
K.step('voice puts me on the radio channel {string}', 'server', function(ctx, raw)
    local value = tonumber(raw) or raw
    local channel = math.floor(tonumber(raw) or 0)
    requireEmptyRadio(ctx, channel)
    local ok, err = K.export(RESOURCE, 'setPlayerRadio', ctx.tester, value)
    if ok ~= true then error('setPlayerRadio failed: ' .. tostring(err), 0) end
end)

-- Only an explicit nil/false means "leave" for the trusted path (A.assign).
K.step('voice takes me off the radio', 'server', function(ctx)
    local ok, err = K.export(RESOURCE, 'setPlayerRadio', ctx.tester, false)
    if ok ~= true then error('setPlayerRadio(false) failed: ' .. tostring(err), 0) end
end)

K.step('{int} voice radio changes should have been published for me', 'server', function(ctx, expected)
    Wait(500)
    ctx:equal(count(ctx, RADIO_EVENT), expected, RADIO_EVENT .. ' count')
end)
K.step('{int} voice call changes should have been published for me', 'server', function(ctx, expected)
    Wait(500)
    ctx:equal(count(ctx, CALL_EVENT), expected, CALL_EVENT .. ' count')
end)

-- radioChanged(src, current or false, previous or false), server/api.lua commitRadio.
K.step('a voice radio change from channel {int} to channel {int} should have been published for me', 'server', function(ctx, from, to)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, RADIO_EVENT)) do
            if record[2] == to and record[3] == from then return true end
        end
    end, ('No %s from %d to %d'):format(RADIO_EVENT, from, to), 2000)
end)
K.step('a voice call change from channel {int} to channel {int} should have been published for me', 'server', function(ctx, from, to)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, CALL_EVENT)) do
            if record[2] == to and record[3] == from then return true end
        end
    end, ('No %s from %d to %d'):format(CALL_EVENT, from, to), 2000)
end)
K.step('a voice call change to no channel should have been published for me', 'server', function(ctx)
    published(ctx, CALL_EVENT, false)
end)

K.step('I should not be listed on voice radio channel {int}', 'server', function(ctx, channel)
    for _, member in ipairs(K.export(RESOURCE, 'getRadioMembers', channel) or {}) do
        if member == ctx.tester then error(('The tester is still listed on radio channel %d'):format(channel), 0) end
    end
    ctx:equal(K.export(RESOURCE, 'getPlayersInRadioChannel', channel)[ctx.tester], nil, 'getPlayersInRadioChannel entry')
end)
-- pma-voice's map shape (server/api.lua getPlayersInRadioChannel).
K.step('the voice radio member map for channel {int} should include me', 'server', function(ctx, channel)
    local map = K.export(RESOURCE, 'getPlayersInRadioChannel', channel) or {}
    local found = false
    for member, flag in pairs(map) do
        if tonumber(member) == ctx.tester and flag == true then found = true end
    end
    assert(found, ('The tester is not in the member map of radio channel %d'):format(channel))
end)
K.step('the voice call member map for call {int} should include me', 'server', function(ctx, channel)
    local found = false
    for member, flag in pairs(K.export(RESOURCE, 'getPlayersInCall', channel) or {}) do
        if tonumber(member) == ctx.tester and flag == true then found = true end
    end
    assert(found, ('The tester is not in the member map of call %d'):format(channel))
end)

-- No guard: server/api.lua removeFromRadio(src, nil) removes whatever the player is on.
K.step('removing me from my voice radio channel without a guard should return {word}', 'server', function(ctx, expected)
    ctx:equal(K.export(RESOURCE, 'removePlayerFromRadio', ctx.tester), truth(expected), 'removePlayerFromRadio result')
end)
K.step('removing me from my voice call without a guard should return {word}', 'server', function(ctx, expected)
    ctx:equal(K.export(RESOURCE, 'removePlayerFromCall', ctx.tester), truth(expected), 'removePlayerFromCall result')
end)

K.step('voice puts me in the call {string}', 'server', function(ctx, raw)
    local value = tonumber(raw) or raw
    requireEmptyCall(ctx, math.floor(tonumber(raw) or 0))
    local ok, err = K.export(RESOURCE, 'setPlayerCall', ctx.tester, value)
    if ok ~= true then error('setPlayerCall failed: ' .. tostring(err), 0) end
end)

K.step('the voice radio state bag should read no channel', 'server', function(ctx)
    ctx:equal(Player(ctx.tester).state[RADIO_KEY], false, 'State bag ' .. RADIO_KEY)
    ctx:equal(K.export(RESOURCE, 'getRadioChannel', ctx.tester), false, 'getRadioChannel')
end)
K.step('the voice call state bag should read no channel', 'server', function(ctx)
    ctx:equal(Player(ctx.tester).state[CALL_KEY], false, 'State bag ' .. CALL_KEY)
    ctx:equal(K.export(RESOURCE, 'getCallChannel', ctx.tester), false, 'getCallChannel')
end)

-- ---------------------------------------------------------------------------
-- Server: restriction lookup and grants (server/policy.lua P.grant)
-- ---------------------------------------------------------------------------

K.step('the voice radio channel {string} should be reported unrestricted', 'server', function(ctx, raw)
    ctx:equal(K.export(RESOURCE, 'isChannelRestricted', tonumber(raw) or raw), false, 'isChannelRestricted ' .. raw)
end)

-- `list` is comma separated; numeric entries are sent as numbers.
K.step('granting me the voice radio channels {string} should count {int}', 'server', function(ctx, list, expected)
    local voice, tester = exports.kora_voice, ctx.tester
    K.started(RESOURCE)
    if not ctx.state.voiceGrantCleanup then
        ctx.state.voiceGrantCleanup = true
        ctx:cleanup(function() voice:revokeRadioChannels(tester) end)
    end
    local channels = {}
    for entry in (list .. ','):gmatch('([^,]*),') do
        entry = entry:gsub('^%s+', ''):gsub('%s+$', '')
        if entry ~= '' then channels[#channels + 1] = tonumber(entry) or entry end
    end
    ctx:equal(voice:grantRadioChannels(tester, channels), expected, 'grantRadioChannels count')
end)
K.step('revoking my voice radio grants should count 0', 'server', function(ctx)
    ctx:equal(K.export(RESOURCE, 'revokeRadioChannels', ctx.tester), 0, 'revokeRadioChannels count')
end)

-- ---------------------------------------------------------------------------
-- Server: other exports
-- ---------------------------------------------------------------------------

K.step('refreshing my voice targets should succeed', 'server', function(ctx)
    local ok, reason = K.export(RESOURCE, 'refreshVoiceTargets', ctx.tester)
    ctx:equal(ok, true, 'refreshVoiceTargets result (' .. tostring(reason) .. ')')
end)
K.step('refreshing voice targets for {string} should fail with {string}', 'server', function(ctx, raw, message)
    local ok, reason = K.export(RESOURCE, 'refreshVoiceTargets', raw)
    ctx:equal(ok, false, 'refreshVoiceTargets result')
    ctx:equal(reason, message, 'refreshVoiceTargets reason')
end)

-- The pma-voice export identity (server/compat.lua, Kora.compat.provideExport).
-- Called directly: GetResourceState on a provided name is not reliable.
local function pma(name, ...)
    local args = table.pack(...)
    local results = table.pack(pcall(function() return exports['pma-voice'][name](exports['pma-voice'], table.unpack(args, 1, args.n)) end))
    if not results[1] then error(('exports[\'pma-voice\']:%s failed: %s'):format(name, tostring(results[2])), 0) end
    return table.unpack(results, 2, results.n)
end
K.step('the pma-voice export should report voice radio channel {int} for me', 'server', function(ctx, channel)
    ctx:equal(pma('getRadioChannel', ctx.tester), channel, "exports['pma-voice']:getRadioChannel")
end)
K.step('the pma-voice export puts me on radio channel {int}', 'server', function(ctx, channel)
    requireEmptyRadio(ctx, channel)
    local ok, err = pma('setPlayerRadio', ctx.tester, channel)
    if ok ~= true then error("exports['pma-voice']:setPlayerRadio failed: " .. tostring(err), 0) end
end)

-- ---------------------------------------------------------------------------
-- Client: requests (paced) and the client's published mirror
-- ---------------------------------------------------------------------------

K.step('I hang up my voice call and it should return {word}', 'client', function(ctx, expected)
    ctx:equal(K.export(RESOURCE, 'removePlayerFromCall'), truth(expected), 'Leave call result')
end)
K.step('leaving my voice radio channel should return {word}', 'client', function(ctx, expected)
    paceRadio(ctx)
    ctx:equal(K.export(RESOURCE, 'removePlayerFromRadio'), truth(expected), 'Leave request result')
end)

-- pma-voice client events (server/compat.lua). Each is an untrusted request
-- for `source`.
local LEGACY = {
    ['set'] = 'pma-voice:setPlayerRadio',
    ['add'] = 'pma-voice:addPlayerToRadio',
    ['remove'] = 'pma-voice:removePlayerFromRadio',
}
K.step('I send the legacy voice {word} radio event for channel {int}', 'client', function(ctx, kind, channel)
    local event = assert(LEGACY[kind], 'Use set, add or remove')
    K.started(RESOURCE)
    paceRadio(ctx)
    TriggerServerEvent(event, channel)
end)
K.step('I send the legacy voice call removal event', 'client', function()
    K.started(RESOURCE)
    TriggerServerEvent('pma-voice:removePlayerFromCall')
end)

-- client/state.lua mirrors only what the server published (client/sync.lua).
K.step('my voice client should mirror radio channel {int}', 'client', function(ctx, channel)
    ctx:waitUntil(function() return K.export(RESOURCE, 'getRadioChannel') == channel end,
        'Client radio mirror is ' .. tostring((K.export(RESOURCE, 'getRadioChannel'))), 5000)
    ctx:equal(K.export(RESOURCE, 'getVoiceProperty', 'radioChannel'), channel, 'radioChannel property')
end)
K.step('my voice client should mirror no radio channel', 'client', function(ctx)
    ctx:waitUntil(function() return K.export(RESOURCE, 'getRadioChannel') == false end,
        'Client radio mirror is ' .. tostring((K.export(RESOURCE, 'getRadioChannel'))), 5000)
end)
K.step('my voice client should mirror call {int}', 'client', function(ctx, channel)
    ctx:waitUntil(function() return K.export(RESOURCE, 'getCallChannel') == channel end,
        'Client call mirror is ' .. tostring((K.export(RESOURCE, 'getCallChannel'))), 5000)
    ctx:equal(K.export(RESOURCE, 'getVoiceProperty', 'callChannel'), channel, 'callChannel property')
end)
K.step('my voice client should mirror no call', 'client', function(ctx)
    ctx:waitUntil(function() return K.export(RESOURCE, 'getCallChannel') == false end,
        'Client call mirror is ' .. tostring((K.export(RESOURCE, 'getCallChannel'))), 5000)
end)

-- ---------------------------------------------------------------------------
-- Client: radio item dialog answers (client/radio_item.lua)
-- ---------------------------------------------------------------------------

-- Numeric text is sent as a number, anything else as typed. Paced because a
-- valid frequency or a leave becomes a radio request.
K.step('I enter the voice radio frequency {string}', 'client', function(ctx, raw)
    ctx:waitUntil(function() return K.uiState().input end, 'No input dialog opened')
    paceRadio(ctx)
    K.must(K.ui('input.submit', { channel = tonumber(raw) or raw }))
end)

-- ---------------------------------------------------------------------------
-- Client: proximity and local audio properties
-- ---------------------------------------------------------------------------

K.step('I cycle my voice mode by {int}', 'client', function(_, step)
    K.export(RESOURCE, 'cycleTalkingMode', step)
end)

K.step('switching my voice megaphone {word} again should report no change', 'client', function(ctx, word)
    assert(word == 'on' or word == 'off', 'Use on or off')
    ctx:equal(K.export(RESOURCE, 'setMegaphone', word == 'on'), false, 'setMegaphone changed')
end)

-- client/state.lua setVolume: >1 is a percentage, then clamped to 0-1;
-- non-numbers become 1.0. Raw text is passed through so that branch runs.
K.step('I set my voice {word} volume to {string}', 'client', function(ctx, which, raw)
    assert(which == 'radio' or which == 'call', 'Use radio or call')
    if not ctx.state.voiceCallVolume then
        local voice = exports.kora_voice
        local original = voice:getVoiceProperty('callVolume')
        ctx.state.voiceCallVolume = true
        ctx:cleanup(function() if type(original) == 'number' then voice:setCallVolume(original) end end)
    end
    local value = tonumber(raw) or raw
    K.export(RESOURCE, which == 'radio' and 'setRadioVolume' or 'setCallVolume', value)
end)
K.step('my voice {word} volume property should be {float}', 'client', function(ctx, which, volume)
    assert(which == 'radio' or which == 'call', 'Use radio or call')
    local actual = K.export(RESOURCE, 'getVoiceProperty', which .. 'Volume')
    assert(type(actual) == 'number' and math.abs(actual - volume) < 0.0001,
        ('%s volume is %s, expected %s'):format(which, tostring(actual), tostring(volume)))
end)

-- Local toggles that write Config on this client (client/exports.lua
-- properties). The original value is put back in cleanup.
local TOGGLES = { micClicks = true, submix = true, muffling = true }
K.step('I set the voice property {string} to {word}', 'client', function(ctx, name, word)
    assert(word == 'true' or word == 'false', 'Use true or false')
    local voice = exports.kora_voice
    ctx.state.voiceToggles = ctx.state.voiceToggles or {}
    if TOGGLES[name] and ctx.state.voiceToggles[name] == nil then
        local original = voice:getVoiceProperty(name)
        ctx.state.voiceToggles[name] = true
        ctx:cleanup(function() voice:setVoiceProperty(name, original == true) end)
    end
    ctx:equal(K.export(RESOURCE, 'setVoiceProperty', name, word == 'true'), true, 'setVoiceProperty result')
end)
K.step('I set the voice property {string} to the value {string}', 'client', function(ctx, name, raw)
    ctx:equal(K.export(RESOURCE, 'setVoiceProperty', name, tonumber(raw) or raw), true, 'setVoiceProperty result')
end)
K.step('the voice property {string} should be {word}', 'client', function(ctx, name, word)
    local actual = K.export(RESOURCE, 'getVoiceProperty', name)
    if word == 'nothing' then
        ctx:equal(actual, nil, 'getVoiceProperty ' .. name)
    else
        assert(word == 'true' or word == 'false', 'Use true, false or nothing')
        ctx:equal(actual, word == 'true', 'getVoiceProperty ' .. name)
    end
end)
K.step('the voice property {string} should be the number {int}', 'client', function(ctx, name, value)
    ctx:equal(K.export(RESOURCE, 'getVoiceProperty', name), value, 'getVoiceProperty ' .. name)
end)

-- ---------------------------------------------------------------------------
-- Server: channel checks and radio policy hooks (kora_voice/server/policy.lua)
-- A channel check owns its frequency and is consulted before hooks and grants.
-- Hooks run in registration order and the first definite answer wins. Only
-- client requests reach policy.canJoin; the trusted setPlayerRadio path does not.
-- Every hook and check registered here is removed in cleanup.
-- ---------------------------------------------------------------------------

local function policyHandles(ctx)
    ctx.state.voicePolicyHandles = ctx.state.voicePolicyHandles or {}
    return ctx.state.voicePolicyHandles
end

local function addCheck(ctx, channel, fn)
    K.started(RESOURCE)
    local voice = exports.kora_voice
    ctx:cleanup(function() voice:removeChannelCheck(channel) end)
    K.export(RESOURCE, 'addChannelCheck', channel, fn)
end

local function addPolicy(ctx, name, fn)
    K.started(RESOURCE)
    local handle = K.export(RESOURCE, 'addRadioPolicy', fn)
    assert(math.type(handle) == 'integer', 'addRadioPolicy returned ' .. tostring(handle))
    policyHandles(ctx)[name] = handle
    local voice = exports.kora_voice
    ctx:cleanup(function() voice:removeRadioPolicy(handle) end)
end

K.step('I register a voice channel check on {int} that refuses', 'server', function(ctx, channel)
    addCheck(ctx, channel, function() return false end)
end)

K.step('I register a voice channel check on {int} that allows', 'server', function(ctx, channel)
    addCheck(ctx, channel, function() return true end)
end)

K.step('I remove the voice channel check on {int}', 'server', function(ctx, channel)
    K.export(RESOURCE, 'removeChannelCheck', channel)
end)

K.step('registering a voice channel check on {int} with a non-callable should fail', 'server', function(ctx, channel)
    K.expectConsoleError(ctx, 'channel check must be callable', RESOURCE)
    local ok = pcall(function() return exports.kora_voice:addChannelCheck(channel, 'not a function') end)
    ctx:equal(ok, false, 'addChannelCheck accepted a non-callable')
end)

K.step('registering a voice channel check on {string} should fail', 'server', function(ctx, raw)
    K.expectConsoleError(ctx, 'channel must be a valid radio channel number', RESOURCE)
    local ok = pcall(function() return exports.kora_voice:addChannelCheck(tonumber(raw) or raw, function() return true end) end)
    ctx:equal(ok, false, 'addChannelCheck accepted ' .. raw)
end)

K.step('I register a voice radio policy {string} that refuses channel {int} with {string}', 'server', function(ctx, name, channel, reason)
    addPolicy(ctx, name, function(_, asked)
        if asked == channel then return false, reason end
    end)
end)

K.step('I register a voice radio policy {string} that allows channel {int}', 'server', function(ctx, name, channel)
    addPolicy(ctx, name, function(_, asked)
        if asked == channel then return true end
    end)
end)

K.step('I register a voice radio policy {string} that abstains', 'server', function(ctx, name)
    addPolicy(ctx, name, function() return nil end)
end)

-- A hook that throws must abstain, so the request falls through to the config.
-- The error is printed as "radio policy hook from fft errored" without the word
-- "error" on its own, so it is deliberately not declared as an expected console line.
K.step('I register a voice radio policy {string} that errors', 'server', function(ctx, name)
    addPolicy(ctx, name, function() error('deliberate policy fault from the FFT suite', 0) end)
end)

K.step('registering a voice radio policy with a non-callable should fail', 'server', function(ctx)
    K.expectConsoleError(ctx, 'radio policy hook must be callable', RESOURCE)
    local ok = pcall(function() return exports.kora_voice:addRadioPolicy('not a function') end)
    ctx:equal(ok, false, 'addRadioPolicy accepted a non-callable')
end)

K.step('I remove the voice radio policy {string} should return {word}', 'server', function(ctx, name, expected)
    local handle = policyHandles(ctx)[name]
    assert(handle, 'No voice radio policy named ' .. name .. ' in this scenario')
    ctx:equal(K.export(RESOURCE, 'removeRadioPolicy', handle), truth(expected), 'removeRadioPolicy result')
end)

-- Handles that were never issued, or 0, must be refused without touching a live hook.
K.step('removing voice radio policy handle {int} should return {word}', 'server', function(ctx, handle, expected)
    ctx:equal(K.export(RESOURCE, 'removeRadioPolicy', handle), truth(expected), 'removeRadioPolicy result')
end)

-- ---------------------------------------------------------------------------
-- Client: transmitting is separate from holding a channel
-- ---------------------------------------------------------------------------

K.step('the voice export isRadioActive should be {word}', 'client', function(ctx, expected)
    K.started(RESOURCE)
    ctx:equal(exports.kora_voice:isRadioActive(), truth(expected), 'isRadioActive')
end)
