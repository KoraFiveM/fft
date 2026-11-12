-- kora_chat: message dispatch, message types, commands and composer callbacks.
-- No resource hook. Server steps call the real exports (kora_chat/server/main.lua)
-- and only ever target the tester. Client steps run kora_chat's own NUI
-- callbacks (`kora_chat:submit`, `kora_chat:suggest` in kora_chat/client/main.lua) the
-- way the browser does, with a real fetch through `K.nui`. The bodies match
-- kora_chat/web/src/App.tsx (`{ cancelled, message }` and
-- `{ command, argumentIndex, query, args }`).
--
-- Safety: nothing here runs /ooc, /me with text or a plain local message, because
-- those reach other players. Composer submissions always start with "/" and an
-- unregistered command name, so a message that is unexpectedly accepted becomes
-- an unknown command instead of local chat.
local K = FFT.kora
if not K then return end
K.feature('kora_chat')

local RESOURCE = 'kora_chat'
-- An unregistered command: a composer submission that slips past a guard runs
-- this instead of being sent as chat.
local SAFE_PREFIX = '/fft_chat_probe_unregistered '

-- ---------------------------------------------------------------------------
-- Server: dispatch log
-- ---------------------------------------------------------------------------

-- dispatchMessage fires the local server event chatMessage(source, author, message)
-- just before delivery (kora_chat/server/main.lua).
K.step('I watch the chat dispatch log', 'server', function(ctx)
    if ctx.state.chatLog then return end
    local log = {}
    ctx.state.chatLog = log
    ctx:on('chatMessage', function(source, author, message)
        if #log < 50 then log[#log + 1] = { source = tonumber(source), author = tostring(author), message = tostring(message) } end
    end)
end)

local function chatLog(ctx)
    return assert(ctx.state.chatLog, 'Add "I watch the chat dispatch log" before this step')
end

local function send(ctx, typeName, message, author)
    return K.export(RESOURCE, 'sendMessage', ctx.tester, typeName, message, { author = author })
end

K.step('chat delivers a {string} message {string} from {string} to me', 'server', function(ctx, typeName, message, author)
    local ok, reason = send(ctx, typeName, message, author)
    if ok ~= true then error(('sendMessage refused the %s message: %s'):format(typeName, tostring(reason)), 0) end
end)

K.step('the chat dispatch log should hold {string} from {string}', 'server', function(ctx, message, author)
    local log = chatLog(ctx)
    ctx:waitUntil(function()
        for _, entry in ipairs(log) do
            if entry.message == message and entry.author == author then return true end
        end
    end, ('No dispatched chat message "%s" from "%s"'):format(message, author), 2000)
end)

K.step('the chat dispatch log should not hold {string}', 'server', function(ctx, message)
    for _, entry in ipairs(chatLog(ctx)) do
        if entry.message == message then error('Chat dispatched "' .. message .. '"', 0) end
    end
end)

K.step('chat should refuse to deliver a {string} message {string} to me with {string}', 'server', function(ctx, typeName, message, reason)
    local ok, why = send(ctx, typeName, message, 'FFT')
    ctx:equal(ok, false, 'sendMessage result')
    ctx:equal(why, reason, 'sendMessage refusal reason')
end)

-- cleanMessage strips control characters before the empty check.
K.step('chat should refuse to deliver a message of only control characters to me with {string}', 'server', function(ctx, reason)
    local ok, why = send(ctx, 'say', '\1\2\3\31', 'FFT')
    ctx:equal(ok, false, 'sendMessage result')
    ctx:equal(why, reason, 'sendMessage refusal reason')
end)

-- Trusted sends are truncated to Config.chat.maxMessageLength, never rejected.
K.step('chat delivers a trusted message of {int} characters starting with {string} to me', 'server', function(ctx, length, marker)
    assert(length > #marker and length <= 2000, 'Length must be longer than the marker and at most 2000')
    local ok, reason = send(ctx, 'say', marker .. string.rep('a', length - #marker), 'FFT')
    if ok ~= true then error('sendMessage refused the long message: ' .. tostring(reason), 0) end
end)

K.step('the chat dispatch log should hold a message of {int} characters starting with {string}', 'server', function(ctx, length, marker)
    local log = chatLog(ctx)
    local found
    ctx:waitUntil(function()
        for _, entry in ipairs(log) do
            if entry.message:sub(1, #marker) == marker then found = entry return true end
        end
    end, 'No dispatched chat message starting with "' .. marker .. '"', 2000)
    ctx:equal(utf8.len(found.message), length, 'Dispatched message length')
end)

K.step('I should have dispatched no chat message', 'server', function(ctx)
    local tester = ctx.tester
    for _, entry in ipairs(chatLog(ctx)) do
        if entry.source == tester then error('The tester dispatched a chat message: ' .. entry.message, 0) end
    end
end)

-- ---------------------------------------------------------------------------
-- Server: commands and message type ownership
-- ---------------------------------------------------------------------------

K.step('the chat command {string} should be registered on the server', 'server', function(_, name)
    for _, command in ipairs(GetRegisteredCommands()) do
        if command.name == name then return end
    end
    error('Server command /' .. name .. ' is not registered', 0)
end)

-- Built-in types are owned by kora_chat. The definition repeats the built-in
-- "say" registration so even a broken ownership check would not change it.
K.step('registering the chat message type {string} from the test runner should fail', 'server', function(ctx, name)
    K.started(RESOURCE)
    assert(name == 'say', 'Only the built-in "say" type is safe to probe')
    -- The refusal is an assert inside the export, which kora_chat prints as a
    -- SCRIPT ERROR. Text from kora_chat/server/main.lua:264-265.
    K.expectConsoleError(ctx, ("Message type '%s' is owned by '%s'."):format(name, RESOURCE), RESOURCE)
    local ok = pcall(function()
        return exports.kora_chat:registerMessageType(name, {
            label = 'Local', command = false, scope = 'local',
            identity = 'character', icon = 'message', permission = 'user',
        })
    end)
    if ok then error('kora_chat let another resource re-register its "' .. name .. '" type', 0) end
end)

K.step('unregistering the chat message type {string} from the test runner should be refused', 'server', function(ctx, name)
    ctx:equal(K.export(RESOURCE, 'unregisterMessageType', name), false, 'unregisterMessageType result')
end)

-- command = false: no command is created; the only broadcast is the
-- kora_chat:typeAdded / kora_chat:typeRemoved type list update.
K.step('the test runner registers the commandless chat message type {string}', 'server', function(ctx, name)
    assert(name:match('^fft_[%w_]+$'), 'Test message types must be named fft_*')
    K.started(RESOURCE)
    ctx:cleanup(function() pcall(function() exports.kora_chat:unregisterMessageType(name) end) end)
    local ok = K.export(RESOURCE, 'registerMessageType', name, { label = 'FFT probe', command = false, scope = 'local' })
    ctx:equal(ok, true, 'registerMessageType result')
end)

K.step('the test runner unregisters the chat message type {string}', 'server', function(ctx, name)
    assert(name:match('^fft_[%w_]+$'), 'Test message types must be named fft_*')
    ctx:equal(K.export(RESOURCE, 'unregisterMessageType', name), true, 'unregisterMessageType result')
end)

-- ---------------------------------------------------------------------------
-- Client: composer callbacks (NUI-callback level, not the rendered input)
-- ---------------------------------------------------------------------------

-- K.nui fetches https://kora_chat/<name> from the FFT page, exactly like
-- kora_chat/web/src/lib/nui.ts does, and raises when the callback is unanswered.
local function nui(_, name, body)
    return K.nui(RESOURCE, name, body)
end

local function submit(ctx, body)
    local result = nui(ctx, 'kora_chat:submit', body)
    assert(type(result) == 'table' and result.ok == true, 'kora_chat:submit was not acknowledged')
end

K.step('I submit a chat composer message of {int} characters', 'client', function(ctx, length)
    assert(length > #SAFE_PREFIX and length <= 2000, 'Length is out of range')
    submit(ctx, { message = SAFE_PREFIX .. string.rep('a', length - #SAFE_PREFIX) })
end)

K.step('I cancel the chat composer', 'client', function(ctx)
    submit(ctx, { cancelled = true, message = SAFE_PREFIX .. 'cancelled' })
end)

K.step('I submit a blank chat composer message', 'client', function(ctx)
    submit(ctx, { message = '   ' })
end)

K.step('chat argument suggestions for {string} argument {int} should be empty', 'client', function(ctx, command, index)
    local result = nui(ctx, 'kora_chat:suggest', { command = command, argumentIndex = index, query = '', args = {} })
    assert(type(result) == 'table', 'kora_chat:suggest did not answer with a list')
    ctx:equal(next(result), nil, 'First suggestion')
end)

K.step('the chat command {string} should be registered on my client', 'client', function(_, name)
    for _, command in ipairs(GetRegisteredCommands()) do
        if command.name == name then return end
    end
    error('Client command /' .. name .. ' is not registered', 0)
end)

-- ---------------------------------------------------------------------------
-- Round 3: dispatch details, sendMessage argument checks, message type
-- validation, compatibility exports and client receipts.
-- ---------------------------------------------------------------------------

-- Delivered with no author override: a source-0 send is named after the
-- type's label (server/main.lua authorFor: definition.label or 'System').
K.step('chat delivers a {string} message {string} to me without an author', 'server', function(ctx, typeName, message)
    local ok, reason = K.export(RESOURCE, 'sendMessage', ctx.tester, typeName, message)
    if ok ~= true then error(('sendMessage refused the %s message: %s'):format(typeName, tostring(reason)), 0) end
end)

-- opts.source names the sender: character name for identity 'character'
-- (kora_core getPlayerData name), FiveM player name for identity 'account'.
K.step('chat delivers a {string} message {string} to me as myself', 'server', function(ctx, typeName, message)
    local ok, reason = K.export(RESOURCE, 'sendMessage', ctx.tester, typeName, message, { source = ctx.tester })
    if ok ~= true then error(('sendMessage refused the %s message: %s'):format(typeName, tostring(reason)), 0) end
end)

K.step('the chat dispatch log should hold {string} from my {word} name', 'server', function(ctx, message, identity)
    local expected
    if identity == 'character' then
        expected = exports.kora_core:getPlayerData(ctx.tester, { 'name' })
        if type(expected) ~= 'string' or expected == '' then expected = GetPlayerName(ctx.tester) end
    elseif identity == 'account' then
        expected = GetPlayerName(ctx.tester)
    else
        error('Identity must be character or account', 0)
    end
    local log, tester = chatLog(ctx), ctx.tester
    ctx:waitUntil(function()
        for _, entry in ipairs(log) do
            if entry.message == message and entry.author == expected and entry.source == tester then return true end
        end
    end, ('No dispatched chat message "%s" from %s as "%s"'):format(message, identity, tostring(expected)), 2000)
end)

-- An array of player ids is accepted and normalised (sendMessage).
K.step('chat delivers a {string} message {string} to a list holding only me', 'server', function(ctx, typeName, message)
    local ok, reason = K.export(RESOURCE, 'sendMessage', { ctx.tester }, typeName, message, { author = 'FFT Sender' })
    if ok ~= true then error(('sendMessage refused the list message: %s'):format(tostring(reason)), 0) end
end)

-- Fixed bodies, so nothing in a feature can type arbitrary text to chat.
local SHAPED = {
    padded = '   fft chat padded   ',
    control = 'fft\1chat\31control',
    slash_after_spaces = '   /fft_chat_probe padded',
}
K.step('chat delivers the {word} probe message to me', 'server', function(ctx, kind)
    local body = assert(SHAPED[kind], 'Unknown probe message ' .. kind)
    local ok, reason = send(ctx, 'say', body, 'FFT Sender')
    ctx.state.chatShaped = { ok = ok, reason = reason }
end)
K.step('chat should have accepted the probe message', 'server', function(ctx)
    local result = assert(ctx.state.chatShaped, 'Send a probe message first')
    ctx:equal(result.ok, true, 'sendMessage result (' .. tostring(result.reason) .. ')')
end)
K.step('chat should have refused the probe message with {string}', 'server', function(ctx, reason)
    local result = assert(ctx.state.chatShaped, 'Send a probe message first')
    ctx:equal(result.ok, false, 'sendMessage result')
    ctx:equal(result.reason, reason, 'sendMessage refusal reason')
end)

-- Trusted text of an exact length in a multi-byte character, to check the
-- limit counts characters (utf8.len / Kora.util.truncateUtf8), not bytes.
K.step('chat delivers a trusted message of {int} {string} characters to me', 'server', function(ctx, length, char)
    assert(length > 0 and length <= 2000, 'Length must be 1-2000')
    assert(utf8.len(char) == 1, 'Give exactly one character')
    local ok, reason = send(ctx, 'say', string.rep(char, length), 'FFT Sender')
    if ok ~= true then error('sendMessage refused the message: ' .. tostring(reason), 0) end
end)
K.step('the chat dispatch log should hold a message of {int} {string} characters', 'server', function(ctx, length, char)
    local log, found = chatLog(ctx), nil
    ctx:waitUntil(function()
        for _, entry in ipairs(log) do
            if entry.message:sub(1, #char) == char then found = entry return true end
        end
    end, 'No dispatched chat message made of "' .. char .. '"', 2000)
    ctx:equal(utf8.len(found.message), length, 'Dispatched message length in characters')
    ctx:equal(found.message, string.rep(char, length), 'Dispatched message')
end)

-- sendMessage argument asserts (server/main.lua sendMessage). Each raises
-- inside the export before anything is dispatched; kora_chat prints it.
local BAD_SEND = {
    target_text = { message = 'target must be -1, a player id, or an array of player ids',
        call = function(tester) return 'everyone', 'say', 'fft chat bad target' end },
    target_fraction = { message = 'target must be an integer player id',
        call = function(tester) return tester + 0.5, 'say', 'fft chat bad target' end },
    target_list = { message = 'target at index 2 must be a player id',
        call = function(tester) return { tester, 'nobody' }, 'say', 'fft chat bad target' end },
    type_number = { message = 'typeName must be a string',
        call = function(tester) return tester, 42, 'fft chat bad type' end },
    options_text = { message = 'opts must be a table',
        call = function(tester) return tester, 'say', 'fft chat bad options', 'loud' end },
}
K.step('chat should reject a send with a bad {word}', 'server', function(ctx, kind)
    local bad = assert(BAD_SEND[kind], 'Unknown bad send ' .. kind)
    K.started(RESOURCE)
    K.expectConsoleError(ctx, bad.message, RESOURCE)
    local ok, err = pcall(function() return exports.kora_chat:sendMessage(bad.call(ctx.tester)) end)
    assert(not ok, 'sendMessage accepted a bad ' .. kind)
    assert(K.raisedWith(ctx, err, bad.message), ('sendMessage failed with "%s", expected "%s"'):format(tostring(err), bad.message))
end)

-- Message type definition validation (server/main.lua validateDefinition and
-- the command-collision assert in registerMessageType). All checks run
-- before any state changes, so a refusal registers nothing and broadcasts
-- nothing. Base definition is commandless and local.
local BAD_DEFINITION = {
    name = { name = 'fft bad name', message = 'Message type name must contain only letters, numbers, underscore, or hyphen.' },
    definition = { definition = 'loud', message = 'Message type definition must be a table.' },
    label = { field = 'label', value = '', message = 'Message type label must be a non-empty string.' },
    command = { field = 'command', value = 'bad command', message = 'Message type command must be a command name or false.' },
    command_taken = { field = 'command', value = 'me', message = "Message command '/me' is already used by type 'me'." },
    scope = { field = 'scope', value = 'region', message = 'Message type scope must be local or global.' },
    range_zero = { field = 'range', value = 0, message = 'Message type range must be between 0 and 1000.' },
    range_huge = { field = 'range', value = 1001, message = 'Message type range must be between 0 and 1000.' },
    identity = { field = 'identity', value = 'nickname', message = 'Message type identity must be character or account.' },
    permission = { field = 'permission', value = '', message = 'Message type permission must be a non-empty string.' },
    icon = { field = 'icon', value = 'skull', message = 'Message type icon is not supported.' },
    color_name = { field = 'color', value = 'red', message = 'Message type color must be #RRGGBB.' },
    color_short = { field = 'color', value = '#FFF', message = 'Message type color must be #RRGGBB.' },
    duration_zero = { field = 'overheadDuration', value = 0, message = 'overheadDuration must be between 1 and 30000ms.' },
    duration_huge = { field = 'overheadDuration', value = 30001, message = 'overheadDuration must be between 1 and 30000ms.' },
}
K.step('registering a chat message type with a bad {word} should fail', 'server', function(ctx, kind)
    local bad = assert(BAD_DEFINITION[kind], 'Unknown bad definition ' .. kind)
    K.started(RESOURCE)
    local name = bad.name or ('fft_bad_' .. kind)
    local definition = bad.definition or { label = 'FFT bad', command = false, scope = 'local' }
    if bad.field then definition[bad.field] = bad.value end
    -- Should the check ever pass, remove the type again.
    ctx:cleanup(function() pcall(function() exports.kora_chat:unregisterMessageType(name) end) end)
    K.expectConsoleError(ctx, bad.message, RESOURCE)
    local ok, err = pcall(function() return exports.kora_chat:registerMessageType(name, definition) end)
    assert(not ok, 'kora_chat accepted a message type with a bad ' .. kind)
    assert(K.raisedWith(ctx, err, bad.message), ('Registration failed with "%s", expected "%s"'):format(tostring(err), bad.message))
    local sent, why = send(ctx, name, 'fft chat probe after bad type', 'FFT')
    ctx:equal(sent, false, 'Delivery with the refused type')
    ctx:equal(why, 'invalid message', 'Delivery refusal reason')
end)

-- Re-registration by the same owner updates the type in place.
K.step('the test runner registers the commandless chat message type {string} again', 'server', function(ctx, name)
    assert(name:match('^[Ff][Ff][Tt]_[%w_]+$'), 'Test message types must be named fft_*')
    local ok = K.export(RESOURCE, 'registerMessageType', name, { label = 'FFT probe again', command = false, scope = 'global' })
    ctx:equal(ok, true, 'registerMessageType result')
end)

-- Names are lower-cased on register, unregister and send. The cleanup
-- unregisters the lower-case name.
K.step('the test runner registers the commandless chat message type {string} in mixed case', 'server', function(ctx, name)
    assert(name:lower():match('^fft_[%w_]+$') and name ~= name:lower(), 'Give a mixed-case fft_* name')
    K.started(RESOURCE)
    ctx:cleanup(function() pcall(function() exports.kora_chat:unregisterMessageType(name:lower()) end) end)
    ctx:equal(K.export(RESOURCE, 'registerMessageType', name, { label = 'FFT case', command = false, scope = 'local' }),
        true, 'registerMessageType result')
end)

K.step('unregistering the chat message type {string} should report nothing to remove', 'server', function(ctx, name)
    ctx:equal(K.export(RESOURCE, 'unregisterMessageType', name), false, 'unregisterMessageType result')
end)

K.step('unregistering a chat message type that is not text should fail', 'server', function(ctx)
    K.started(RESOURCE)
    K.expectConsoleError(ctx, 'name must be a string', RESOURCE)
    local ok = pcall(function() return exports.kora_chat:unregisterMessageType(42) end)
    assert(not ok, 'unregisterMessageType accepted a number')
end)

-- Stock compatibility: server export addMessage(target, message) sends
-- chat:addMessage to the target (server/main.lua addCompatMessage), on both the
-- kora_chat and the provided `chat` identity.
K.step('the chat compatibility export on {string} sends me the message {string}', 'server', function(ctx, identity, text)
    assert(identity == 'kora_chat' or identity == 'chat', 'Identity must be kora_chat or chat')
    K.started(RESOURCE)
    local ok, result = pcall(function()
        return exports[identity]:addMessage(ctx.tester, { args = { 'FFT', text } })
    end)
    if not ok then error(('exports.%s:addMessage failed: %s'):format(identity, tostring(result)), 0) end
    ctx:equal(result, true, 'addMessage result')
end)

-- addMessage(nil, nil): no message, nothing is sent (the one-argument form
-- would broadcast, so it is never used here).
K.step('the chat compatibility export should refuse a missing message', 'server', function(ctx)
    ctx:equal(K.export(RESOURCE, 'addMessage', nil, nil), false, 'addMessage result')
end)

-- ---------------------------------------------------------------------------
-- Client: receipts of what the server sent to this client
-- ---------------------------------------------------------------------------

-- kora_chat's client registers these as net events; registering them here
-- too lets the FFT resource listen without changing what kora_chat does.
local WATCHED = {
    ['chat:addMessage'] = true, ['chat:addSuggestion'] = true,
    ['kora_chat:types'] = true, ['kora_chat:typeAdded'] = true, ['kora_chat:typeRemoved'] = true,
}
K.step('my client watches the chat event {string}', 'client', function(ctx, event)
    assert(WATCHED[event], event .. ' is not a watched chat event')
    ctx.state.chatEvents = ctx.state.chatEvents or {}
    if ctx.state.chatEvents[event] then return end
    local list = {}
    ctx.state.chatEvents[event] = list
    RegisterNetEvent(event)
    ctx:on(event, function(...)
        if #list < 100 then list[#list + 1] = table.pack(...) end
    end)
end)

local function received(ctx, event)
    return assert(ctx.state.chatEvents and ctx.state.chatEvents[event], 'Watch ' .. event .. ' first')
end

local function mentions(value, text, depth)
    depth = depth or 0
    if type(value) == 'string' then return value == text or value:find(text, 1, true) ~= nil end
    if type(value) ~= 'table' or depth > 4 then return false end
    for _, item in pairs(value) do if mentions(item, text, depth + 1) then return true end end
    return false
end

K.step('my client should receive {string} mentioning {string}', 'client', function(ctx, event, text)
    local list = received(ctx, event)
    ctx:waitUntil(function()
        for _, args in ipairs(list) do if mentions(args, text) then return true end end
    end, ('%s mentioning "%s" was not received (%d received)'):format(event, text, #list), 3000)
end)

K.step('my client should not have received {string} mentioning {string}', 'client', function(ctx, event, text)
    Wait(500)
    for _, args in ipairs(received(ctx, event)) do
        if mentions(args, text) then error(event .. ' mentioning "' .. text .. '" was received', 0) end
    end
end)

-- The type list kora_chat sends in answer to chat:init (server/main.lua),
-- which its page sends once it is ready.
K.step('my client should receive the chat type list with {string}', 'client', function(ctx, name)
    local list = received(ctx, 'kora_chat:types')
    ctx:waitUntil(function()
        for _, args in ipairs(list) do
            for _, entry in ipairs(type(args[1]) == 'table' and args[1] or {}) do
                if type(entry) == 'table' and entry.name == name then return true end
            end
        end
    end, 'The chat type list did not include ' .. name, 3000)
end)

K.step('my client asks chat for its initial state', 'client', function()
    K.started(RESOURCE)
    TriggerServerEvent('chat:init')
end)

-- ---------------------------------------------------------------------------
-- Client: more composer and callback edges
-- ---------------------------------------------------------------------------

K.step('I submit a chat composer message of only control characters', 'client', function(ctx)
    submit(ctx, { message = '\1\2\3\31' })
end)
K.step('I submit a lone slash in the chat composer', 'client', function(ctx)
    submit(ctx, { message = '/' })
end)
K.step('I submit a chat composer message that is not text', 'client', function(ctx)
    submit(ctx, { message = 42 })
end)

-- Only commands whose empty form is refused locally by kora_chat, so nothing
-- reaches other players.
local EMPTY_COMMANDS = { me = true, ooc = true }
K.step('I submit the chat command {string} without a message in the composer', 'client', function(ctx, name)
    assert(EMPTY_COMMANDS[name], name .. ' is not a safe empty chat command')
    submit(ctx, { message = '/' .. name })
end)

-- kora_chat:suggest forwards to the kora_chat:commandSuggestions callback,
-- which answers {} for every malformed request (server/main.lua).
local BAD_SUGGEST = {
    index_zero = { command = 'me', argumentIndex = 0, query = '', args = {} },
    index_over = { command = 'me', argumentIndex = 17, query = '', args = {} },
    index_fraction = { command = 'me', argumentIndex = 1.5, query = '', args = {} },
    index_text = { command = 'me', argumentIndex = 'one', query = '', args = {} },
    long_command = { command = string.rep('m', 65), argumentIndex = 1, query = '', args = {} },
    long_query = { command = 'me', argumentIndex = 1, query = string.rep('q', 129), args = {} },
    many_args = { command = 'me', argumentIndex = 1, query = '', args = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q' } },
    unknown_command = { command = 'fft_no_such_command', argumentIndex = 1, query = '', args = {} },
}
K.step('chat argument suggestions for a request with a bad {word} should be empty', 'client', function(ctx, kind)
    local body = assert(BAD_SUGGEST[kind], 'Unknown bad suggestion request ' .. kind)
    local result = nui(ctx, 'kora_chat:suggest', body)
    assert(type(result) == 'table', 'kora_chat:suggest did not answer with a list')
    ctx:equal(next(result), nil, 'First suggestion')
end)

-- kora_chat:geometry always acknowledges, and ignores a malformed body.
K.step('the chat geometry callback should acknowledge a malformed report', 'client', function(ctx)
    local result = nui(ctx, 'kora_chat:geometry', { rect = 'wide', defaultOffset = 7 })
    assert(type(result) == 'table' and result.ok == true, 'kora_chat:geometry was not acknowledged')
end)
