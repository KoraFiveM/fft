-- kora_lib: notifications, text UI, menus, input dialogs, alerts, progress
-- bars, the interact selector, callbacks and stateless utility exports.
--
-- No new hook: kora_lib already ships fft_hooks.lua (v1), which observes every
-- Kora.nui.send and answers surfaces through the browser's own NUI callbacks.
-- These steps open the surfaces through the real consumer exports
-- (exports.kora_lib:<module>_<function>, built by build/finalise.lua), so the
-- surfaces are owned by `fft` exactly as they would be by any other resource.
-- Blocking exports (menus, dialogs, alerts, progress bars) run in their own
-- thread; the step that answers them is a generic hook step from steps/kora.lua
-- and the value the export returned is asserted afterwards.
local K = FFT.kora
if not K then return end
K.feature('kora_lib')

local LIB = 'kora_lib'

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Runs a blocking kora_lib export in its own thread and records what it returned.
local function begin(ctx, kind, name, ...)
    K.started(LIB)
    local call = { kind = kind, done = false }
    local args = table.pack(...)
    ctx.state.libCall = call
    CreateThread(function()
        local results = table.pack(pcall(function()
            return exports[LIB][name](exports[LIB], table.unpack(args, 1, args.n))
        end))
        call.ok = results[1]
        if results[1] then
            call.result, call.extra = results[2], results[3]
        else
            call.err = tostring(results[2])
        end
        call.done = true
    end)
    return call
end

-- Waits for the export started by `begin` to return and gives back its value.
local function settled(ctx, kind)
    local call = ctx.state.libCall
    assert(call and call.kind == kind, 'No kora_lib ' .. kind .. ' was opened by this scenario')
    ctx:waitUntil(function() return call.done end, 'The kora_lib ' .. kind .. ' export did not return', 5000)
    if not call.ok then error(('kora_lib %s export failed: %s'):format(kind, call.err), 0) end
    return call.result, call.extra
end

-- An export that raises WITHOUT yielding loses its message at the resource
-- boundary: the callee's SetCallRefRoutine returns msgpack nil and the caller's
-- function reference raises error() with no value (citizen/scripting/lua/
-- scheduler.lua), so the caller only ever sees
--   An error occurred while calling export `<name>` in resource `kora_lib`:\n  nil
-- and the real text is printed to the callee's console. An export that yielded
-- first (callback_trigger) keeps its message. So a refusal is: the export
-- raised through the export wrapper, and its reason matches whenever one
-- survived. Each caller also asserts that nothing changed.
local function assertRefusal(name, err, expected)
    local text = tostring(err)
    assert(K.contains(text, ('calling export `%s` in resource `%s`'):format(name, LIB)),
        ('exports.kora_lib:%s failed outside the export itself: %s'):format(name, text))
    assert(text:find(':\n  nil\n', 1, true) or K.contains(text, expected),
        ('exports.kora_lib:%s failed with "%s", expected it to mention "%s"'):format(name, text, expected))
end

-- Asserts that an export raises an error containing `expected`. The call runs
-- in a thread so an export that wrongly accepts the payload (and then blocks
-- on a surface) cannot hang the step; `undo` closes whatever it opened.
local function refusedExport(ctx, name, expected, undo, ...)
    local call = begin(ctx, 'refusal', name, ...)
    local deadline = GetGameTimer() + 2000
    while not call.done and GetGameTimer() < deadline do ctx:check() Wait(50) end
    if not call.done or call.ok then
        if undo then pcall(undo, call) end
        error(('exports.kora_lib:%s accepted an invalid payload'):format(name), 0)
    end
    assertRefusal(name, call.err, expected)
end

local function hookSilently(action, ...)
    local args = table.pack(...)
    pcall(function() return exports[LIB]:fftAction(action, table.unpack(args, 1, args.n)) end)
end

local function prompts(ctx)
    ctx.state.libPrompts = ctx.state.libPrompts or {}
    return ctx.state.libPrompts
end

local function promptId(ctx, text)
    return assert(prompts(ctx)[text], 'This scenario did not show the text prompt "' .. text .. '"')
end

local function showPrompt(ctx, text, options)
    local id = K.export(LIB, 'textui_show', text, options)
    assert(type(id) == 'number', 'textui_show did not return a handle')
    prompts(ctx)[text] = id
    ctx:cleanup(function() pcall(function() exports[LIB]:textui_hide(id) end) end)
end

-- Test callbacks are namespaced so they can never shadow a real one.
local function testCallbackName(name)
    assert(name:sub(1, 13) == 'fft:kora_lib:', 'Test callback names must start with fft:kora_lib:')
    return name
end

-- ---------------------------------------------------------------------------
-- Notifications (modules/notify)
-- ---------------------------------------------------------------------------

-- Client Kora.notify.send(payload). A payload that fails validation is printed
-- and dropped, never raised (modules/notify/client.lua), so this step cannot fail
-- on an invalid type: assert the outcome with the notification steps.
K.step('I send a kora_lib notification titled {string} with message {string} of type {string}', 'client',
    function(_, title, message, kind)
        K.export(LIB, 'notify_send', { title = title, message = message, type = kind, duration = 3000 })
    end)

-- Server Kora.notify.send(src, payload), addressed to the tester only.
K.step('the server sends me a kora_lib notification titled {string} with message {string}', 'server',
    function(ctx, title, message)
        assert(type(ctx.tester) == 'number' and ctx.tester >= 1, 'No tester source')
        K.export(LIB, 'notify_send', ctx.tester, { title = title, message = message, duration = 3000 })
    end)

-- Types are info, success, warning, error; inform and warn are aliases
-- (modules/notify/shared.lua). Config.notify.defaultType is "info" (config.lua).
K.step('the kora_lib notification titled {string} should have type {string}', 'client', function(ctx, title, kind)
    local entry = ctx:waitUntil(function()
        for _, item in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            if item.title == title then return item end
        end
    end, 'No notification titled "' .. title .. '"')
    ctx:equal(entry.type, kind, 'Notification type')
end)

-- ---------------------------------------------------------------------------
-- Text UI (modules/textui/client.lua)
-- ---------------------------------------------------------------------------

K.step('I show the kora_lib text prompt {string}', 'client', function(ctx, text) showPrompt(ctx, text) end)
K.step('I show the kora_lib text prompt {string} with key {string}', 'client', function(ctx, text, key)
    showPrompt(ctx, text, { key = key })
end)
K.step('I change the kora_lib text prompt {string} to {string}', 'client', function(ctx, text, replacement)
    local id = promptId(ctx, text)
    ctx:equal(K.export(LIB, 'textui_update', id, replacement), true, 'textui_update result')
    prompts(ctx)[replacement] = id
end)
K.step('I hide the kora_lib text prompt {string}', 'client', function(ctx, text)
    ctx:equal(K.export(LIB, 'textui_hide', promptId(ctx, text)), true, 'textui_hide result')
end)
-- The default position is right-center (normalize in modules/textui/client.lua).
K.step('the kora_lib text prompt should show key {string} at {string}', 'client', function(ctx, key, position)
    local prompt = ctx:waitUntil(function()
        local current = K.uiState().textui
        return type(current) == 'table' and current
    end, 'No text prompt is shown')
    ctx:equal(prompt.key, key, 'Text prompt key')
    ctx:equal(prompt.position, position, 'Text prompt position')
end)
K.step('the kora_lib text prompt {string} should be the visible one', 'client', function(ctx, text)
    ctx:equal(K.export(LIB, 'textui_isVisible', promptId(ctx, text)), true, 'textui_isVisible')
end)
K.step('the kora_lib text prompt {string} should be gone', 'client', function(ctx, text)
    local id = promptId(ctx, text)
    ctx:equal(K.export(LIB, 'textui_isOpen', id), false, 'textui_isOpen')
    local current = K.uiState().textui
    assert(type(current) ~= 'table' or current.id ~= id, 'The hidden text prompt is still rendered')
end)
-- Handles are owner-tracked: a handle fft does not own (here, one that does not
-- exist) is refused with `false`.
K.step('hiding a kora_lib text prompt that was never shown should be refused', 'client', function(ctx)
    ctx:equal(K.export(LIB, 'textui_hide', 2147480000), false, 'textui_hide result')
end)
K.step('showing a kora_lib text prompt at position {string} should be refused', 'client', function(ctx, position)
    refusedExport(ctx, 'textui_show', 'Text UI position must be', function(call)
        if type(call.result) == 'number' then exports[LIB]:textui_hide(call.result) end
    end, 'FFT invalid position', { position = position })
    local current = K.uiState().textui
    assert(type(current) ~= 'table' or current.text ~= 'FFT invalid position', 'An invalid text prompt was shown')
end)

-- ---------------------------------------------------------------------------
-- Menus (Kora.nui.openMenu, openContextMenu in modules/nui/client.lua)
-- Doc string: JSON array of items { id, label, description?, disabled?, submenu? }.
-- ---------------------------------------------------------------------------

K.step('I open a kora_lib menu titled {string} with:', 'client', function(ctx, title, argument)
    local items = K.json(argument)
    ctx:cleanup(function() hookSilently('menu.cancel') end)
    begin(ctx, 'menu', 'nui_openMenu', items, title)
end)
K.step('I open a kora_lib context menu with:', 'client', function(ctx, argument)
    local items = K.json(argument)
    ctx:cleanup(function() hookSilently('menu.cancel') end)
    begin(ctx, 'menu', 'nui_openContextMenu', items)
end)
K.step('the open kora_lib menu should be a {string} menu', 'client', function(ctx, kind)
    -- kind is the NUI action: openMenu, openContextMenu or openRadialMenu.
    ctx:equal(K.waitMenu(ctx).kind, kind, 'Menu kind')
end)
-- The hook refuses what the rendered menu would not let a player pick: codes
-- `disabled`, `submenu` (a parent row) and `not_visible`. The menu stays open.
K.step('choosing {string} in the kora_lib menu should be refused as {string}', 'client', function(ctx, label, code)
    K.waitMenu(ctx)
    local ok, err, why = K.ui('menu.select', label)
    assert(not ok, 'The menu accepted ' .. label)
    assert(why == code, ('Menu refused %s as %s (%s), expected %s'):format(label, tostring(why), tostring(err), code))
    assert(K.uiState().menu, 'The menu closed after a refused selection')
end)
K.step('the kora_lib menu should return the selection {string} with path {string}', 'client', function(ctx, id, path)
    local result = settled(ctx, 'menu')
    assert(type(result) == 'table', 'openMenu returned ' .. tostring(result))
    ctx:equal(result.selectedId, id, 'Selected id')
    ctx:equal(table.concat(type(result.path) == 'table' and result.path or {}, ' > '), path, 'Selection path')
end)
K.step('the kora_lib menu should return a cancellation', 'client', function(ctx)
    local result = settled(ctx, 'menu')
    assert(type(result) == 'table', 'The menu export returned ' .. tostring(result))
    ctx:equal(result.cancelled, true, 'Menu cancelled')
    ctx:equal(result.selectedId, nil, 'Selected id')
end)
K.step('opening a kora_lib menu whose item has no id should be refused', 'client', function(ctx)
    refusedExport(ctx, 'nui_openMenu', 'requires a non-empty string id', function() hookSilently('menu.cancel') end,
        { { label = 'FFT item without id' } }, 'FFT invalid menu')
    assert(not K.uiState().menu, 'An invalid menu was opened')
end)

-- ---------------------------------------------------------------------------
-- Input dialog (Kora.nui.openInputDialog)
-- Doc string: JSON array of fields { id, label, type, required?, default? }.
-- ---------------------------------------------------------------------------

K.step('I open a kora_lib input dialog titled {string} with fields:', 'client', function(ctx, title, argument)
    local fields = K.json(argument)
    ctx:cleanup(function() hookSilently('input.cancel') end)
    begin(ctx, 'input dialog', 'nui_openInputDialog', fields, title)
end)
K.step('the kora_lib input dialog should be titled {string}', 'client', function(ctx, title)
    local input = ctx:waitUntil(function() return K.uiState().input end, 'No input dialog opened')
    ctx:equal(input.title, title, 'Input dialog title')
end)
K.step('the kora_lib input dialog should have the field {string}', 'client', function(ctx, id)
    local input = ctx:waitUntil(function() return K.uiState().input end, 'No input dialog opened')
    for _, field in ipairs(type(input.fields) == 'table' and input.fields or {}) do
        if field.id == id then return end
    end
    error('Input dialog has no field ' .. id, 0)
end)
-- Hook codes: `invalid` (an empty required field) and `not_visible` (a field
-- the dialog does not have). The dialog stays open.
K.step('submitting the kora_lib input dialog should be refused as {string} with:', 'client', function(ctx, code, argument)
    ctx:waitUntil(function() return K.uiState().input end, 'No input dialog opened')
    local ok, err, why = K.ui('input.submit', K.json(argument))
    assert(not ok, 'The input dialog accepted the values')
    assert(why == code, ('Input dialog refused as %s (%s), expected %s'):format(tostring(why), tostring(err), code))
    assert(K.uiState().input, 'The input dialog closed after a refused submit')
end)
K.step('the kora_lib input dialog should be closed', 'client', function(ctx)
    ctx:waitUntil(function() return not K.uiState().input end, 'An input dialog is still open', 3000)
end)
K.step('the kora_lib input dialog should return {string} as {string}', 'client', function(ctx, field, expected)
    local result = settled(ctx, 'input dialog')
    assert(type(result) == 'table' and type(result.values) == 'table', 'openInputDialog returned no values')
    ctx:equal(tostring(result.values[field]), expected, 'Input value ' .. field)
end)
K.step('the kora_lib input dialog should return a cancellation', 'client', function(ctx)
    local result = settled(ctx, 'input dialog')
    assert(type(result) == 'table', 'openInputDialog returned ' .. tostring(result))
    ctx:equal(result.cancelled, true, 'Input cancelled')
    ctx:equal(result.values, nil, 'Input values')
end)

-- ---------------------------------------------------------------------------
-- Alert (Kora.nui.openAlert)
-- ---------------------------------------------------------------------------

K.step('I open a kora_lib confirmation titled {string} with message {string}', 'client', function(ctx, title, message)
    ctx:cleanup(function() hookSilently('alert.answer', false) end)
    begin(ctx, 'confirmation', 'nui_openAlert', { title = title, message = message })
end)
-- cancellable = false: only the confirm button can settle it, so cleanup confirms.
K.step('I open a kora_lib acknowledgement titled {string} with message {string}', 'client', function(ctx, title, message)
    ctx:cleanup(function() hookSilently('alert.answer', true) end)
    begin(ctx, 'confirmation', 'nui_openAlert', { title = title, message = message, cancellable = false })
end)
K.step('the kora_lib confirmation should be titled {string}', 'client', function(ctx, title)
    local alert = ctx:waitUntil(function() return K.uiState().alert end, 'No confirmation opened')
    ctx:equal(alert.title, title, 'Confirmation title')
end)
-- Registers a confirming cleanup too, for alerts another resource opened as
-- acknowledge-only (the generic cleanup declines, which such an alert refuses).
K.step('declining the kora_lib confirmation should be refused as locked', 'client', function(ctx)
    ctx:cleanup(function() hookSilently('alert.answer', true) end)
    ctx:waitUntil(function() return K.uiState().alert end, 'No confirmation opened')
    local ok, err, why = K.ui('alert.answer', false)
    assert(not ok, 'The acknowledge-only alert accepted a decline')
    assert(why == 'locked', ('Alert refused as %s (%s), expected locked'):format(tostring(why), tostring(err)))
    assert(K.uiState().alert, 'The alert closed after a refused decline')
end)
K.step('the kora_lib confirmation should be closed', 'client', function(ctx)
    ctx:waitUntil(function() return not K.uiState().alert end, 'A confirmation is still open', 3000)
end)
K.step('the kora_lib confirmation should return {word}', 'client', function(ctx, answer)
    assert(answer == 'confirmed' or answer == 'declined', 'Use "confirmed" or "declined"')
    local result = settled(ctx, 'confirmation')
    assert(type(result) == 'table', 'openAlert returned ' .. tostring(result))
    ctx:equal(result.confirmed, answer == 'confirmed', 'Alert confirmed')
end)

-- ---------------------------------------------------------------------------
-- Progress bar (modules/progressbar/client.lua). Bars always run to the end:
-- Kora.progressbar.cancel is owner-gated and is used here only as cleanup for
-- the bar this scenario started itself.
-- ---------------------------------------------------------------------------

K.step('I start a kora_lib progress bar labelled {string} lasting {int} milliseconds', 'client', function(ctx, label, duration)
    assert(duration >= 500 and duration <= 10000, 'Test progress bars last 500-10000 ms')
    assert(not K.export(LIB, 'progressbar_isActive'), 'Another progress bar is already running')
    ctx:cleanup(function() pcall(function() exports[LIB]:progressbar_cancel() end) end)
    begin(ctx, 'progress bar', 'progressbar_start', { label = label, duration = duration, canCancel = false })
end)
-- Kora.progressbar.start returns `false, "A progress bar is already active."`
-- while one runs. Guarded so it can never start (and block on) a bar itself.
K.step('starting a second kora_lib progress bar should be refused', 'client', function(ctx)
    assert(K.export(LIB, 'progressbar_isActive'), 'No progress bar is running, so nothing would be refused')
    local started, reason = K.export(LIB, 'progressbar_start', { label = 'FFT second bar', duration = 500, canCancel = false })
    ctx:equal(started, false, 'Second progress bar started')
    assert(K.contains(reason, 'already active'), 'Unexpected refusal reason: ' .. tostring(reason))
end)
K.step('the kora_lib progress bar should report completion', 'client', function(ctx)
    local completed, reason = settled(ctx, 'progress bar')
    assert(completed == true, 'progressbar_start returned ' .. tostring(completed) .. ' ' .. tostring(reason or ''))
    ctx:equal(K.export(LIB, 'progressbar_isActive'), false, 'progressbar_isActive')
end)
K.step('starting a kora_lib progress bar lasting {int} milliseconds should be refused', 'client', function(ctx, duration)
    assert(duration <= 0, 'Use a non-positive duration for the refusal')
    refusedExport(ctx, 'progressbar_start', 'duration must be a positive integer',
        function() exports[LIB]:progressbar_cancel() end, { label = 'FFT invalid bar', duration = duration })
    ctx:equal(K.export(LIB, 'progressbar_isActive'), false, 'progressbar_isActive')
end)

-- ---------------------------------------------------------------------------
-- Interact selector (modules/interact/client.lua). Rows whose canInteract
-- fails are filtered out before the selector opens.
-- ---------------------------------------------------------------------------

K.step('the kora_lib interact selector should not offer {string}', 'client', function(ctx, label)
    local options = ctx:waitUntil(function()
        local state = K.uiState()
        return state.interactActive and type(state.interact) == 'table' and state.interact
    end, 'The interact selector is not open')
    for _, option in ipairs(options) do
        if option.label == label then error('Interact selector offers ' .. label, 0) end
    end
end)
K.step('the kora_lib interact selector should be closed', 'client', function(ctx)
    ctx:waitUntil(function() return not K.uiState().interactActive end, 'The interact selector is still open', 3000)
end)

-- ---------------------------------------------------------------------------
-- Callbacks (local/callback). The handlers registered here are fft's own echo
-- functions under the fft:kora_lib: prefix; the transport, the handshake token
-- and the registry are kora_lib's.
-- ---------------------------------------------------------------------------

-- Server Kora.callback.register(name, handler): handler(src, ...).
K.step('the server registers the kora_lib callback {string}', 'server', function(ctx, name)
    testCallbackName(name)
    local seen = {}
    ctx.state.libCallbackSeen = ctx.state.libCallbackSeen or {}
    ctx.state.libCallbackSeen[name] = seen
    K.export(LIB, 'callback_register', name, function(src, message)
        if #seen < 10 then seen[#seen + 1] = { src = src, message = message } end
        return 'server echo: ' .. tostring(message)
    end)
    ctx:cleanup(function() pcall(function() exports[LIB]:callback_unregister(name) end) end)
end)
-- Client Kora.callback.trigger(name, ...), asked through callback_triggerPacked:
-- a rejection (handler error, rate limit) is returned as
-- { __kora_lib_rejected = true, error } (local/callback/shared.lua
-- KoraLibCallbackEnvelope), so its message survives the export boundary.
local function packedOutcome(ok, packed)
    if not ok then return { ok = false, value = packed } end
    if type(packed) ~= 'table' then return { ok = true, value = packed } end
    if packed.__kora_lib_rejected then return { ok = false, value = packed.error } end
    return { ok = true, value = packed[1] }
end
K.step('I trigger the kora_lib server callback {string} with {string}', 'client', function(ctx, name, message)
    testCallbackName(name)
    K.started(LIB)
    ctx.state.libCallback = packedOutcome(pcall(function() return exports[LIB]:callback_triggerPacked(name, message) end))
end)
K.step('the kora_lib server callback should answer {string}', 'client', function(ctx, expected)
    local call = assert(ctx.state.libCallback, 'Trigger a kora_lib callback first')
    assert(call.ok, 'The callback failed: ' .. tostring(call.value))
    ctx:equal(call.value, expected, 'Callback answer')
end)
K.step('the kora_lib server callback should fail with {string}', 'client', function(ctx, expected)
    local call = assert(ctx.state.libCallback, 'Trigger a kora_lib callback first')
    assert(not call.ok, 'The callback answered: ' .. tostring(call.value))
    assert(K.contains(tostring(call.value), expected),
        ('Callback failed with "%s", expected it to mention "%s"'):format(tostring(call.value), expected))
end)
K.step('the kora_lib callback {string} should have been called by me with {string}', 'server', function(ctx, name, message)
    local seen = assert(ctx.state.libCallbackSeen and ctx.state.libCallbackSeen[name], 'Register the callback first')
    ctx:equal(#seen, 1, 'Handler call count')
    ctx:equal(seen[1].src, ctx.tester, 'Callback source')
    ctx:equal(seen[1].message, message, 'Callback argument')
end)
K.step('the kora_lib callback {string} should not have been called', 'server', function(ctx, name)
    local seen = ctx.state.libCallbackSeen and ctx.state.libCallbackSeen[name] or {}
    ctx:equal(#seen, 0, 'Handler call count')
end)

-- Client Kora.callback.register(name, handler), asked by the server with
-- Kora.callback.trigger(target, name, ...).
K.step('my client registers the kora_lib callback {string}', 'client', function(ctx, name)
    testCallbackName(name)
    K.export(LIB, 'callback_register', name, function(message) return 'client echo: ' .. tostring(message) end)
    ctx:cleanup(function() pcall(function() exports[LIB]:callback_unregister(name) end) end)
end)
K.step('the server asking my client for the kora_lib callback {string} with {string} should get {string}', 'server',
    function(ctx, name, message, expected)
        testCallbackName(name)
        ctx:equal(K.export(LIB, 'callback_trigger', ctx.tester, name, message), expected, 'Client callback answer')
    end)
K.step('the server asking my client for the kora_lib callback {string} should fail with {string}', 'server',
    function(ctx, name, expected)
        testCallbackName(name)
        K.started(LIB)
        local tester = ctx.tester
        local outcome = packedOutcome(pcall(function() return exports[LIB]:callback_triggerPacked(tester, name, 'fft') end))
        local ok, value = outcome.ok, outcome.value
        assert(not ok, 'The client answered an unregistered callback: ' .. tostring(value))
        assert(K.contains(tostring(value), expected),
            ('Callback failed with "%s", expected it to mention "%s"'):format(tostring(value), expected))
    end)

-- ---------------------------------------------------------------------------
-- Stateless utility exports on the server (modules/util/shared.lua)
-- ---------------------------------------------------------------------------

K.step('kora_lib should clamp {int} between {int} and {int} to {int}', 'server', function(ctx, value, min, max, expected)
    ctx:equal(K.export(LIB, 'util_clamp', value, min, max), expected, 'util_clamp')
end)
K.step('kora_lib should refuse to clamp {int} between {int} and {int}', 'server', function(ctx, value, min, max)
    K.started(LIB)
    -- The assert is printed on kora_lib's console as a SCRIPT ERROR (see
    -- assertRefusal). Text from kora_lib/modules/util/shared.lua:144-145.
    K.expectConsoleError(ctx, 'Kora.util.clamp requires finite bounds where min is at most max.', LIB)
    local ok, err = pcall(function() return exports[LIB]:util_clamp(value, min, max) end)
    assert(not ok, 'util_clamp accepted min above max and returned ' .. tostring(err))
    assertRefusal('util_clamp', err, 'min is at most max')
end)
K.step('kora_lib should round {float} to {int} decimal places as {float}', 'server', function(_, value, decimals, expected)
    local actual = K.export(LIB, 'util_round', value, decimals)
    assert(type(actual) == 'number' and math.abs(actual - expected) < 1e-9,
        ('util_round returned %s, expected %s'):format(tostring(actual), tostring(expected)))
end)
K.step('kora_lib should trim {string} to {string}', 'server', function(ctx, value, expected)
    ctx:equal(K.export(LIB, 'util_trim', value), expected, 'util_trim')
end)
K.step('kora_lib should truncate {string} to {int} characters as {string}', 'server', function(ctx, value, maximum, expected)
    ctx:equal(K.export(LIB, 'util_truncateUtf8', value, maximum), expected, 'util_truncateUtf8')
end)
K.step('kora_lib should treat the callback name {string} as valid', 'server', function(_, name)
    K.export(LIB, 'callback_assertName', name)
end)
K.step('kora_lib should refuse an empty callback name', 'server', function(ctx)
    K.started(LIB)
    -- Same mechanism as the clamp refusal. Text from kora_lib/local/callback/shared.lua:7.
    K.expectConsoleError(ctx, 'Callback name must not be empty.', LIB)
    local ok, err = pcall(function() return exports[LIB]:callback_assertName('') end)
    assert(not ok, 'callback_assertName accepted an empty name')
    assertRefusal('callback_assertName', err, 'must not be empty')
end)

-- ===========================================================================
-- Edge cases: validation refusals, ownership, rate limits, events, status
-- effects, timers and the remaining stateless exports.
-- ===========================================================================

-- Test event, push and status names share the callback prefix.
local testName = testCallbackName

-- Calls a non-blocking export that must raise (see assertRefusal).
local function refusedSync(name, expected, ...)
    K.started(LIB)
    local args = table.pack(...)
    local results = table.pack(pcall(function()
        return exports[LIB][name](exports[LIB], table.unpack(args, 1, args.n))
    end))
    assert(not results[1], ('exports.kora_lib:%s accepted an invalid argument and returned %s')
        :format(name, tostring(results[2])))
    assertRefusal(name, results[2], expected)
end

-- Server-realm refusal: the assert text is printed on kora_lib's server console
-- as a SCRIPT ERROR, so it is declared as expected first. `text` is the full
-- message quoted from the source line named at each call site.
local function serverRefusal(ctx, name, text, ...)
    K.expectConsoleError(ctx, text, LIB)
    refusedSync(name, text, ...)
end

local function near(actual, expected)
    return type(actual) == 'number' and math.abs(actual - expected) < 1e-6
end

local function assertNear(actual, expected, label)
    assert(near(actual, expected), ('%s is %s, expected %s'):format(label, tostring(actual), tostring(expected)))
end

local function lookup(cases, name, what)
    local case = cases[name]
    if not case then
        local known = {}
        for key in pairs(cases) do known[#known + 1] = key end
        table.sort(known)
        error(('Unknown %s case "%s"; use one of: %s'):format(what, name, table.concat(known, ', ')), 0)
    end
    return case
end

-- ---------------------------------------------------------------------------
-- Notifications: defaults and dropped payloads (modules/notify/shared.lua)
-- ---------------------------------------------------------------------------

local function notifyLog(since, match)
    for _, entry in ipairs(K.ui('log', since) or {}) do
        if entry.action == 'notify' and type(entry.data) == 'table' and match(entry.data) then return entry.data end
    end
end

K.step('I send a kora_lib notification with only the message {string}', 'client', function(_, message)
    K.export(LIB, 'notify_send', { message = message })
end)
-- Kora.notify.withDefaults fills type, position and duration from Config.notify
-- (config.lua:43-48: info, top-right, 5000) before the payload reaches the NUI.
K.step('the kora_lib notification with message {string} should use position {string} and last {int} milliseconds', 'client',
    function(ctx, message, position, duration)
        local data = ctx:waitUntil(function()
            return notifyLog(ctx.state.uiBaseline or 0, function(item) return item.message == message end)
        end, 'No notification with message "' .. message .. '" reached the NUI')
        ctx:equal(data.position, position, 'Notification position')
        ctx:equal(data.duration, duration, 'Notification duration')
        ctx:equal(data.title, nil, 'Notification title')
    end)

-- Each payload breaks one Kora.notify.assert rule (modules/notify/shared.lua:63-92).
-- Kora.notify.send prints and drops it, so nothing may reach the NUI. The id
-- marks the payload so it is found even when it has no title or message.
local DROPPED_ID = 'fft:kora_lib:dropped'
local DROPPED_NOTIFICATIONS = {
    ['no title or message'] = { id = DROPPED_ID },
    ['a zero duration'] = { id = DROPPED_ID, title = 'FFT lib dropped', duration = 0 },
    ['a fractional duration'] = { id = DROPPED_ID, title = 'FFT lib dropped', duration = 1500.5 },
    -- Config.notify.maxDuration is 120000 (config.lua:45).
    ['a duration above the maximum'] = { id = DROPPED_ID, title = 'FFT lib dropped', duration = 120001 },
    ['an unknown position'] = { id = DROPPED_ID, title = 'FFT lib dropped', position = 'middle' },
    ['a non-string title'] = { id = DROPPED_ID, title = 42, message = 'FFT lib dropped' },
    ['an unknown icon animation'] = { id = DROPPED_ID, title = 'FFT lib dropped', iconAnimation = 'fft_wobble' },
}
K.step('sending a kora_lib notification with {string} should be dropped', 'client', function(ctx, name)
    local payload = lookup(DROPPED_NOTIFICATIONS, name, 'notification')
    local since = K.uiState().sequence or 0
    K.export(LIB, 'notify_send', payload)
    local deadline = GetGameTimer() + 400
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
    assert(not notifyLog(since, function(item) return item.id == DROPPED_ID end),
        'A notification with ' .. name .. ' reached the NUI')
end)

-- Server Kora.notify.send validates before pushing (modules/notify/server.lua:5-18).
K.step('the server sends me a kora_lib notification titled {string} lasting {int} milliseconds', 'server',
    function(ctx, title, duration)
        assert(type(ctx.tester) == 'number' and ctx.tester >= 1, 'No tester source')
        K.export(LIB, 'notify_send', ctx.tester, { title = title, message = 'Sent by the functional tests', duration = duration })
    end)

-- ---------------------------------------------------------------------------
-- Text UI: positions, handle lifetime and refusals (modules/textui/client.lua)
-- ---------------------------------------------------------------------------

K.step('I show the kora_lib text prompt {string} with key {string} at position {string}', 'client',
    function(ctx, text, key, position)
        showPrompt(ctx, text, { key = key, position = position })
    end)
-- Kora.textui.isOpen() without an id reports whether any handle is live (:149-152).
K.step('a kora_lib text prompt should be open', 'client', function(ctx)
    ctx:equal(K.export(LIB, 'textui_isOpen'), true, 'textui_isOpen')
end)
K.step('the kora_lib text prompt {string} should not be the visible one', 'client', function(ctx, text)
    local id = promptId(ctx, text)
    ctx:equal(K.export(LIB, 'textui_isOpen', id), true, 'textui_isOpen')
    ctx:equal(K.export(LIB, 'textui_isVisible', id), false, 'textui_isVisible')
end)
-- A removed handle no longer exists, so a second hide returns false (remove, :81-82).
K.step('hiding the kora_lib text prompt {string} again should be refused', 'client', function(ctx, text)
    ctx:equal(K.export(LIB, 'textui_hide', promptId(ctx, text)), false, 'textui_hide result')
end)
K.step('changing a kora_lib text prompt that was never shown should be refused', 'client', function(ctx)
    ctx:equal(K.export(LIB, 'textui_update', 2147480000, 'FFT never shown'), false, 'textui_update result')
    local current = K.uiState().textui
    assert(type(current) ~= 'table' or current.text ~= 'FFT never shown', 'An unknown text prompt was rendered')
end)
-- normalize() in modules/textui/client.lua:24-41.
local INVALID_PROMPTS = {
    ['empty text'] = { '', nil, 'Text UI text must be a non-empty string.' },
    ['an empty key'] = { 'FFT invalid prompt', { key = '' }, 'Text UI key must be a non-empty string.' },
    ['an unknown icon animation'] = { 'FFT invalid prompt', { iconAnimation = 'fft_wobble' }, 'Text UI iconAnimation is unsupported.' },
    ['a numeric icon'] = { 'FFT invalid prompt', { icon = 7 }, 'Text UI icon must be a non-empty string.' },
}
K.step('showing a kora_lib text prompt with {string} should be refused', 'client', function(ctx, name)
    local case = lookup(INVALID_PROMPTS, name, 'text prompt')
    refusedExport(ctx, 'textui_show', case[3], function(call)
        if type(call.result) == 'number' then exports[LIB]:textui_hide(call.result) end
    end, case[1], case[2])
    local current = K.uiState().textui
    assert(type(current) ~= 'table' or current.text ~= 'FFT invalid prompt', 'An invalid text prompt was shown')
end)

-- ---------------------------------------------------------------------------
-- Menus: radial menus, locked menus and item validation (modules/nui/client.lua)
-- ---------------------------------------------------------------------------

K.step('I open a kora_lib radial menu with:', 'client', function(ctx, argument)
    local items = K.json(argument)
    ctx:cleanup(function() hookSilently('menu.cancel') end)
    begin(ctx, 'menu', 'nui_openRadialMenu', items)
end)
-- opts.canClose = false (assertMenuGeometry, :1148). Such a menu can only be
-- settled by a selection, so cleanup picks its first entry.
K.step('I open a kora_lib menu titled {string} that cannot be closed with:', 'client', function(ctx, title, argument)
    local items = K.json(argument)
    local first = assert(type(items[1]) == 'table' and items[1].id, 'The menu needs a first item with an id')
    ctx:cleanup(function() hookSilently('menu.select', first) end)
    begin(ctx, 'menu', 'nui_openMenu', items, title, { canClose = false })
end)
-- Hook code `locked`: the rendered menu offers no way to close it.
K.step('closing the kora_lib menu should be refused as locked', 'client', function(ctx)
    K.waitMenu(ctx)
    local ok, err, why = K.ui('menu.cancel')
    assert(not ok, 'The locked menu accepted a cancel')
    assert(why == 'locked', ('Menu refused the cancel as %s (%s), expected locked'):format(tostring(why), tostring(err)))
    assert(K.uiState().menu, 'The menu closed after a refused cancel')
end)

-- assertMenuItems in modules/nui/client.lua:1085-1139; the text is the part of
-- the message that does not depend on the item index.
local INVALID_MENUS = {
    ['a duplicate item id'] = { { { id = 'fft_same', label = 'FFT first' }, { id = 'fft_same', label = 'FFT second' } },
        "is duplicated" },
    ['an empty label'] = { { { id = 'fft_item', label = '' } }, 'requires a non-empty string label' },
    ['an empty id'] = { { { id = '', label = 'FFT item' } }, 'requires a non-empty string id' },
    ['progress above 100'] = { { { id = 'fft_item', label = 'FFT item', progress = 101 } }, 'progress must be between 0 and 100' },
    ['a negative progress'] = { { { id = 'fft_item', label = 'FFT item', progress = -1 } }, 'progress must be between 0 and 100' },
    ['a default index without values'] = { { { id = 'fft_item', label = 'FFT item', defaultIndex = 1 } },
        'cannot have defaultIndex without values' },
    ['a default index beyond its values'] = { { { id = 'fft_item', label = 'FFT item', values = { 'one', 'two' }, defaultIndex = 3 } },
        'defaultIndex must reference a value' },
    ['a non-boolean disabled flag'] = { { { id = 'fft_item', label = 'FFT item', disabled = 'yes' } }, 'disabled must be a boolean' },
    ['an invalid submenu item'] = { { { id = 'fft_parent', label = 'FFT parent', submenu = { items = { { label = 'FFT no id' } } } } },
        'requires a non-empty string id' },
    ['no items table'] = { 'fft-not-a-table', 'openMenu' },
}
K.step('opening a kora_lib menu with {string} should be refused', 'client', function(ctx, name)
    local case = lookup(INVALID_MENUS, name, 'menu')
    refusedExport(ctx, 'nui_openMenu', case[2], function() hookSilently('menu.cancel') end, case[1], 'FFT invalid menu')
    assert(not K.uiState().menu, 'An invalid menu was opened')
end)
-- Menu geometry and options (assertMenuGeometry, :1144-1171).
local INVALID_MENU_OPTIONS = {
    ['a non-boolean canClose'] = { { canClose = 'no' }, 'Menu canClose must be a boolean.' },
    ['an unknown presentation'] = { { presentation = 'fft_sheet' }, 'Menu presentation must be dialog or panel.' },
    ['a zero start index'] = { { startIndex = 0 }, 'Menu startIndex must be a positive integer.' },
    ['a negative width'] = { { maxWidth = -10 }, 'Menu maxWidth must be a positive finite number.' },
    ['an unknown horizontal position'] = { { position = { horizontal = 'middle' } },
        'Menu horizontal position must be left, center, or right.' },
}
K.step('opening a kora_lib menu with the option {string} should be refused', 'client', function(ctx, name)
    local case = lookup(INVALID_MENU_OPTIONS, name, 'menu option')
    refusedExport(ctx, 'nui_openMenu', case[2], function() hookSilently('menu.cancel') end,
        { { id = 'fft_item', label = 'FFT item' } }, 'FFT invalid menu', case[1])
    assert(not K.uiState().menu, 'An invalid menu was opened')
end)
-- Kora.nui.openRadialMenu options (:1218-1223).
local INVALID_RADIALS = {
    ['a zero radius'] = { { radius = 0 }, 'openRadialMenu radius must be a positive number.' },
    ['five label lines'] = { { labelLines = 5 }, 'openRadialMenu labelLines must be a number from 1 to 4.' },
    ['zero label lines'] = { { labelLines = 0 }, 'openRadialMenu labelLines must be a number from 1 to 4.' },
}
K.step('opening a kora_lib radial menu with {string} should be refused', 'client', function(ctx, name)
    local case = lookup(INVALID_RADIALS, name, 'radial menu')
    refusedExport(ctx, 'nui_openRadialMenu', case[2], function() hookSilently('menu.cancel') end,
        { { id = 'fft_item', label = 'FFT item' } }, case[1])
    assert(not K.uiState().menu, 'An invalid radial menu was opened')
end)
-- Kora.nui.openContextMenu x and y must be finite numbers (:1203-1204).
K.step('opening a kora_lib context menu at a non-numeric position should be refused', 'client', function(ctx)
    refusedExport(ctx, 'nui_openContextMenu', 'openContextMenu x must be a finite number.',
        function() hookSilently('menu.cancel') end, { { id = 'fft_item', label = 'FFT item' } }, 'left', 10)
    assert(not K.uiState().menu, 'An invalid context menu was opened')
end)

-- ---------------------------------------------------------------------------
-- Alerts and input dialogs: payload validation (modules/nui/client.lua)
-- ---------------------------------------------------------------------------

-- Kora.nui.openAlert (:1238-1253).
local INVALID_ALERTS = {
    ['an empty message'] = { { title = 'FFT invalid alert', message = '' }, 'openAlert requires a message string.' },
    ['no message'] = { { title = 'FFT invalid alert' }, 'openAlert requires a message string.' },
    ['an unknown size'] = { { message = 'FFT invalid alert', size = 'huge' }, 'openAlert size is invalid.' },
    ['a non-boolean cancellable flag'] = { { message = 'FFT invalid alert', cancellable = 'no' },
        'openAlert cancellable must be a boolean.' },
    ['a numeric title'] = { { message = 'FFT invalid alert', title = 7 }, 'openAlert title must be a string.' },
}
K.step('opening a kora_lib confirmation with {string} should be refused', 'client', function(ctx, name)
    local case = lookup(INVALID_ALERTS, name, 'confirmation')
    refusedExport(ctx, 'nui_openAlert', case[2], function() hookSilently('alert.answer', true) end, case[1])
    assert(not K.uiState().alert, 'An invalid confirmation was opened')
end)

-- assertInputFields (:137-287); the text is the part after the field location.
local INVALID_INPUTS = {
    ['a duplicate field id'] = { { { id = 'fft_same', label = 'One', type = 'text' }, { id = 'fft_same', label = 'Two', type = 'text' } },
        "field id 'fft_same' is duplicated." },
    ['an unknown field type'] = { { { id = 'fft_field', label = 'Field', type = 'fft_slider' } }, 'has an invalid type.' },
    ['a field without a label'] = { { { id = 'fft_field', type = 'text' } }, 'requires a label.' },
    ['a minimum above its maximum'] = { { { id = 'fft_field', label = 'Field', type = 'number', min = 10, max = 1 } },
        'min cannot exceed max.' },
    ['a select without options'] = { { { id = 'fft_field', label = 'Field', type = 'select' } }, 'requires options.' },
    ['a vector without dimensions'] = { { { id = 'fft_field', label = 'Field', type = 'vector' } }, 'vector requires dimensions.' },
    ['a dependency on an unknown field'] = { { { id = 'fft_field', label = 'Field', type = 'text', dependsOn = 'fft_missing' } },
        'depends on an unknown field.' },
    ['a non-boolean checkbox default'] = { { { id = 'fft_field', label = 'Field', type = 'checkbox', default = 'yes' } },
        'checkbox default must be a boolean.' },
    ['a non-numeric number default'] = { { { id = 'fft_field', label = 'Field', type = 'number', default = 'three' } },
        'numeric default must be a finite number.' },
    ['a non-boolean required flag'] = { { { id = 'fft_field', label = 'Field', type = 'text', required = 'yes' } },
        'required must be a boolean.' },
}
K.step('opening a kora_lib input dialog with {string} should be refused', 'client', function(ctx, name)
    local case = lookup(INVALID_INPUTS, name, 'input dialog')
    refusedExport(ctx, 'nui_openInputDialog', case[2], function() hookSilently('input.cancel') end, case[1], 'FFT invalid input')
    assert(not K.uiState().input, 'An invalid input dialog was opened')
end)

-- ---------------------------------------------------------------------------
-- Progress bar: owner cancel and Kora.progressbar.validate
-- (modules/progressbar/client.lua)
-- ---------------------------------------------------------------------------

-- Kora.progressbar.cancel() is owner-gated; fft owns the bar it started (:482-490).
K.step('I cancel the kora_lib progress bar', 'client', function(ctx)
    assert(K.export(LIB, 'progressbar_isActive'), 'No progress bar is running')
    ctx:equal(K.export(LIB, 'progressbar_cancel'), true, 'progressbar_cancel result')
end)
-- A cancelled bar makes Kora.progressbar.start return false (:464-466).
K.step('the kora_lib progress bar should report a cancellation', 'client', function(ctx)
    local completed = settled(ctx, 'progress bar')
    ctx:equal(completed, false, 'progressbar_start result')
    ctx:waitUntil(function() return K.export(LIB, 'progressbar_isActive') == false end,
        'The cancelled progress bar is still active', 3000)
end)
K.step('cancelling a kora_lib progress bar when none is running should be refused', 'client', function(ctx)
    assert(not K.export(LIB, 'progressbar_isActive'), 'A progress bar is running')
    ctx:equal(K.export(LIB, 'progressbar_cancel'), false, 'progressbar_cancel result')
end)
-- Kora.progressbar.validate returns true or raises; it never starts a bar (:170-173).
K.step('kora_lib should accept a progress bar lasting {int} milliseconds', 'client', function(ctx, duration)
    ctx:equal(K.export(LIB, 'progressbar_validate', { label = 'FFT validated bar', duration = duration }), true,
        'progressbar_validate')
    ctx:equal(K.export(LIB, 'progressbar_isActive'), false, 'progressbar_isActive')
end)
-- maxDuration = false lifts Config.progressbar.maxDuration (600000, config.lua:80).
K.step('kora_lib should accept a progress bar lasting {int} milliseconds with no maximum', 'client', function(ctx, duration)
    ctx:equal(K.export(LIB, 'progressbar_validate',
        { label = 'FFT validated bar', duration = duration, maxDuration = false }), true, 'progressbar_validate')
    ctx:equal(K.export(LIB, 'progressbar_isActive'), false, 'progressbar_isActive')
end)
-- assertPayload (:74-143).
local INVALID_BARS = {
    ['an empty label'] = { { label = '', duration = 1000 }, 'Progress bar requires a label string.' },
    ['a fractional duration'] = { { label = 'FFT invalid bar', duration = 1000.5 }, 'Progress bar duration must be a positive integer.' },
    ['a negative duration'] = { { label = 'FFT invalid bar', duration = -1000 }, 'Progress bar duration must be a positive integer.' },
    ['a duration above the maximum'] = { { label = 'FFT invalid bar', duration = 600001 },
        'Progress bar duration must be at most 600000 ms.' },
    ['a duration above its own maximum'] = { { label = 'FFT invalid bar', duration = 2000, maxDuration = 1000 },
        'Progress bar duration must be at most 1000 ms.' },
    ['a zero maximum'] = { { label = 'FFT invalid bar', duration = 1000, maxDuration = 0 },
        'Progress bar maxDuration must be a positive integer or false.' },
    ['an unknown presentation'] = { { label = 'FFT invalid bar', duration = 1000, presentation = 'ring' },
        "Progress bar presentation must be 'bar' or 'circle'." },
    ['an unknown position'] = { { label = 'FFT invalid bar', duration = 1000, position = 'top' },
        "Progress bar position must be 'middle' or 'bottom'." },
    ['a non-boolean canCancel'] = { { label = 'FFT invalid bar', duration = 1000, canCancel = 'yes' },
        'Progress bar canCancel must be a boolean.' },
    ['both an animation and a scenario'] = { { label = 'FFT invalid bar', duration = 1000,
        anim = { dict = 'fft_dict', clip = 'fft_clip' }, scenario = { name = 'FFT_SCENARIO' } },
        'Progress bar cannot play both anim and scenario' },
}
K.step('validating a kora_lib progress bar with {string} should be refused', 'client', function(ctx, name)
    local case = lookup(INVALID_BARS, name, 'progress bar')
    refusedSync('progressbar_validate', case[2], case[1])
    ctx:equal(K.export(LIB, 'progressbar_isActive'), false, 'progressbar_isActive')
end)

-- ---------------------------------------------------------------------------
-- Callbacks: rate limits, unregistering, several return values and refusals
-- (local/callback/server.lua, local/callback/shared.lua)
-- ---------------------------------------------------------------------------

-- opts.rateLimit = { max, window } is counted per player (consumeRateLimit); a
-- refused call answers 'Callback rate limit exceeded; retry in %dms.' (:249-250).
K.step('the server registers the kora_lib callback {string} limited to {int} calls per {int} milliseconds', 'server',
    function(ctx, name, max, window)
        testCallbackName(name)
        local seen = {}
        ctx.state.libCallbackSeen = ctx.state.libCallbackSeen or {}
        ctx.state.libCallbackSeen[name] = seen
        ctx:cleanup(function() pcall(function() exports[LIB]:callback_unregister(name) end) end)
        K.export(LIB, 'callback_register', name, function(src, message)
            if #seen < 10 then seen[#seen + 1] = { src = src, message = message } end
            return 'server echo: ' .. tostring(message)
        end, { rateLimit = { max = max, window = window } })
    end)
K.step('the kora_lib callback {string} should have been called {int} times by me', 'server', function(ctx, name, count)
    local seen = assert(ctx.state.libCallbackSeen and ctx.state.libCallbackSeen[name], 'Register the callback first')
    ctx:equal(#seen, count, 'Handler call count')
    for _, call in ipairs(seen) do ctx:equal(call.src, ctx.tester, 'Callback source') end
end)
-- Kora.callback.unregister returns true for the owner and false for a name the
-- caller does not own, which includes one nobody registered (:152-160).
K.step('the server unregisters the kora_lib callback {string}', 'server', function(ctx, name)
    ctx:equal(K.export(LIB, 'callback_unregister', testCallbackName(name)), true, 'callback_unregister result')
end)
K.step('the server unregistering the kora_lib callback {string} it never registered should be refused', 'server',
    function(ctx, name)
        ctx:equal(K.export(LIB, 'callback_unregister', testCallbackName(name)), false, 'callback_unregister result')
    end)
-- A cross-resource caller receives the handler's own return values, unpacked
-- (Kora.callback.trigger doc, local/callback/server.lua:186-200).
K.step('the server registers the kora_lib callback {string} answering false and {string}', 'server', function(ctx, name, reason)
    testCallbackName(name)
    ctx:cleanup(function() pcall(function() exports[LIB]:callback_unregister(name) end) end)
    K.export(LIB, 'callback_register', name, function() return false, reason end)
end)
K.step('triggering the kora_lib server callback {string} should answer false and {string}', 'client', function(ctx, name, reason)
    testCallbackName(name)
    local first, second = K.export(LIB, 'callback_trigger', name)
    ctx:equal(first, false, 'First callback value')
    ctx:equal(second, reason, 'Second callback value')
end)

K.step('kora_lib should refuse a callback name longer than 128 bytes', 'server', function(ctx)
    -- local/callback/shared.lua:8.
    serverRefusal(ctx, 'callback_assertName', 'Callback name must be at most 128 bytes.', 'fft:kora_lib:' .. ('x'):rep(116))
    -- Exactly 128 bytes is still valid.
    K.export(LIB, 'callback_assertName', 'fft:kora_lib:' .. ('x'):rep(115))
end)
K.step('kora_lib should refuse a non-string callback name', 'server', function(ctx)
    -- local/callback/shared.lua:6.
    serverRefusal(ctx, 'callback_assertName', 'Callback name must be a string.', 42)
end)
K.step('kora_lib should refuse to register the callback {string} with a rate limit of {int} calls', 'server',
    function(ctx, name, max)
        testCallbackName(name)
        assert(max < 1 or max > 10000, 'Use a limit outside 1-10000 for the refusal')
        ctx:cleanup(function() pcall(function() exports[LIB]:callback_unregister(name) end) end)
        -- normalizeRateLimit, local/callback/server.lua:26-27 (MAX_RATE_LIMIT = 10000).
        serverRefusal(ctx, 'callback_register', 'Callback rateLimit.max must be a positive integer no greater than 10000.',
            name, function() return 'fft' end, { rateLimit = { max = max, window = 1000 } })
        -- Nothing was registered, so fft owns nothing to unregister.
        ctx:equal(K.export(LIB, 'callback_unregister', name), false, 'callback_unregister result')
    end)
K.step('kora_lib should refuse to register the callback {string} without a handler', 'server', function(ctx, name)
    testCallbackName(name)
    ctx:cleanup(function() pcall(function() exports[LIB]:callback_unregister(name) end) end)
    -- local/callback/server.lua:132.
    serverRefusal(ctx, 'callback_register', 'Callback handler must be a function.', name, 'fft-not-a-function')
    ctx:equal(K.export(LIB, 'callback_unregister', name), false, 'callback_unregister result')
end)
K.step('the server asking player 0 for a kora_lib callback should be refused', 'server', function(ctx)
    -- request(), local/callback/server.lua:164.
    serverRefusal(ctx, 'callback_trigger', 'target must be a positive finite player server ID.', 0, 'fft:kora_lib:client-echo', 'fft')
end)

-- ---------------------------------------------------------------------------
-- Events gateway and pushes (local/events). Handlers are fft's own recorders
-- under the fft:kora_lib: prefix; the token gateway and registry are kora_lib's.
-- ---------------------------------------------------------------------------

local function registerEvent(ctx, name, opts)
    testName(name)
    local seen = {}
    ctx.state.libEventSeen = ctx.state.libEventSeen or {}
    ctx.state.libEventSeen[name] = seen
    ctx:cleanup(function() pcall(function() exports[LIB]:events_unregister(name) end) end)
    K.export(LIB, 'events_register', name, function(src, message)
        if #seen < 20 then seen[#seen + 1] = { src = src, message = message } end
    end, opts)
end

-- Server Kora.events.register(name, handler, opts): handler(src, ...).
K.step('the server registers the kora_lib event {string}', 'server', function(ctx, name) registerEvent(ctx, name) end)
K.step('the server registers the kora_lib event {string} limited to {int} calls per {int} milliseconds', 'server',
    function(ctx, name, max, window)
        registerEvent(ctx, name, { rateLimit = { max = max, window = window } })
    end)
-- Client Kora.events.trigger(name, ...) returns true once the request was sent;
-- the gateway drops unknown names and rate-limited calls without an answer
-- (dispatchGateway, local/events/server.lua:150-168).
K.step('I trigger the kora_lib server event {string} with {string}', 'client', function(ctx, name, message)
    ctx:equal(K.export(LIB, 'events_trigger', testName(name), message), true, 'events_trigger result')
end)
-- Waits for the expected deliveries, then a little longer so a delivery that
-- should have been dropped would have arrived.
K.step('the kora_lib event {string} should have reached the server {int} times from me', 'server', function(ctx, name, count)
    local seen = assert(ctx.state.libEventSeen and ctx.state.libEventSeen[name], 'Register the event first')
    if count > 0 then
        ctx:waitUntil(function() return #seen >= count end,
            ('The event %s reached the server %d times, expected %d'):format(name, #seen, count), 5000)
    end
    local deadline = GetGameTimer() + 1000
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
    ctx:equal(#seen, count, 'Event delivery count')
    for _, call in ipairs(seen) do ctx:equal(call.src, ctx.tester, 'Event source') end
end)
K.step('the first kora_lib event {string} should have carried {string}', 'server', function(ctx, name, message)
    local seen = assert(ctx.state.libEventSeen and ctx.state.libEventSeen[name], 'Register the event first')
    assert(seen[1], 'The event ' .. name .. ' never reached the server')
    ctx:equal(seen[1].message, message, 'Event argument')
end)
K.step('the server unregisters the kora_lib event {string}', 'server', function(ctx, name)
    ctx:equal(K.export(LIB, 'events_unregister', testName(name)), true, 'events_unregister result')
end)

-- Client Kora.events.onPush(name, handler), fed by server Kora.events.push.
K.step('my client listens for the kora_lib push {string}', 'client', function(ctx, name)
    testName(name)
    local seen = {}
    ctx.state.libPushSeen = ctx.state.libPushSeen or {}
    ctx.state.libPushSeen[name] = seen
    ctx:cleanup(function() pcall(function() exports[LIB]:events_offPush(name) end) end)
    K.export(LIB, 'events_onPush', name, function(message)
        if #seen < 20 then seen[#seen + 1] = message end
    end)
end)
K.step('the server pushes the kora_lib event {string} to me with {string}', 'server', function(ctx, name, message)
    assert(type(ctx.tester) == 'number' and ctx.tester >= 1, 'No tester source')
    K.export(LIB, 'events_push', ctx.tester, testName(name), message)
end)
K.step('my client should have received {int} kora_lib pushes named {string}', 'client', function(ctx, count, name)
    local seen = assert(ctx.state.libPushSeen and ctx.state.libPushSeen[name], 'Listen for the push first')
    if count > 0 then
        ctx:waitUntil(function() return #seen >= count end,
            ('The push %s arrived %d times, expected %d'):format(name, #seen, count), 5000)
    end
    local deadline = GetGameTimer() + 1000
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
    ctx:equal(#seen, count, 'Push delivery count')
end)
K.step('the last kora_lib push named {string} should carry {string}', 'client', function(ctx, name, message)
    local seen = assert(ctx.state.libPushSeen and ctx.state.libPushSeen[name], 'Listen for the push first')
    assert(#seen > 0, 'The push ' .. name .. ' never arrived')
    ctx:equal(seen[#seen], message, 'Push argument')
end)
-- Kora.events.offPush: true for the owner, false for a name the caller does not
-- own (local/events/client.lua:88-95).
K.step('my client stops listening for the kora_lib push {string}', 'client', function(ctx, name)
    ctx:equal(K.export(LIB, 'events_offPush', testName(name)), true, 'events_offPush result')
end)
K.step('my client stopping the kora_lib push {string} it never listened for should be refused', 'client', function(ctx, name)
    ctx:equal(K.export(LIB, 'events_offPush', testName(name)), false, 'events_offPush result')
end)

K.step('kora_lib should refuse an empty event name', 'server', function(ctx)
    -- local/events/shared.lua:7.
    serverRefusal(ctx, 'events_assertName', 'Event name must not be empty.', '')
    K.export(LIB, 'events_assertName', 'fft:kora_lib:event')
end)
K.step('kora_lib should refuse an event name longer than 128 bytes', 'server', function(ctx)
    -- local/events/shared.lua:8.
    serverRefusal(ctx, 'events_assertName', 'Event name must be at most 128 bytes.', 'fft:kora_lib:' .. ('x'):rep(116))
end)
K.step('kora_lib should refuse to push an event to player 0', 'server', function(ctx)
    -- local/events/server.lua:188-189.
    serverRefusal(ctx, 'events_push', 'target must be -1 or a positive finite player server ID.', 0, 'fft:kora_lib:push', 'fft')
end)
K.step('kora_lib should refuse to register the event {string} without a handler', 'server', function(ctx, name)
    testName(name)
    ctx:cleanup(function() pcall(function() exports[LIB]:events_unregister(name) end) end)
    -- local/events/server.lua:105.
    serverRefusal(ctx, 'events_register', 'Event handler must be a function.', name, 'fft-not-a-function')
    ctx:equal(K.export(LIB, 'events_unregister', name), false, 'events_unregister result')
end)

-- ---------------------------------------------------------------------------
-- Status effects (modules/status). The test effects are empty definitions (no
-- fx, anim or movement), so applying one changes nothing a player can feel.
-- Kora.status has no unregister: a definition lives until fft stops.
-- ---------------------------------------------------------------------------

local function statusActive(name)
    for _, entry in ipairs(K.export(LIB, 'status_getActive') or {}) do
        if entry.name == name then return true end
    end
    return false
end

K.step('my client registers the kora_lib status effect {string}', 'client', function(ctx, name)
    ctx:equal(K.export(LIB, 'status_registerEffect', testName(name), {}), true, 'status_registerEffect result')
end)
K.step('the server registers the kora_lib status effect {string}', 'server', function(ctx, name)
    ctx:equal(K.export(LIB, 'status_registerEffect', testName(name), {}), true, 'status_registerEffect result')
end)
-- Client Kora.status.apply(name, { duration }) (modules/status/client.lua:108-170).
K.step('I apply the kora_lib status effect {string} for {int} milliseconds', 'client', function(ctx, name, duration)
    testName(name)
    assert(duration >= 100 and duration <= 10000, 'Test status effects last 100-10000 ms')
    ctx:cleanup(function() pcall(function() exports[LIB]:status_remove(name) end) end)
    ctx:equal(K.export(LIB, 'status_apply', name, { duration = duration }), true, 'status_apply result')
end)
K.step('I apply the kora_lib status effect {string}', 'client', function(ctx, name)
    testName(name)
    ctx:cleanup(function() pcall(function() exports[LIB]:status_remove(name) end) end)
    ctx:equal(K.export(LIB, 'status_apply', name), true, 'status_apply result')
end)
K.step('the kora_lib status effect {string} should be active on my client', 'client', function(ctx, name)
    testName(name)
    ctx:waitUntil(function() return K.export(LIB, 'status_isActive', name) == true end,
        'The status effect ' .. name .. ' is not active', 5000)
    assert(statusActive(name), 'status_getActive does not list ' .. name)
end)
K.step('the kora_lib status effect {string} should be inactive on my client', 'client', function(ctx, name)
    testName(name)
    ctx:waitUntil(function() return K.export(LIB, 'status_isActive', name) == false end,
        'The status effect ' .. name .. ' is still active', 6000)
    assert(not statusActive(name), 'status_getActive still lists ' .. name)
end)
-- Kora.status.remove: true for the resource that applied it, false when nothing
-- is active or another resource owns it (removeStatus, :172-182).
K.step('I remove the kora_lib status effect {string}', 'client', function(ctx, name)
    ctx:equal(K.export(LIB, 'status_remove', testName(name)), true, 'status_remove result')
end)
K.step('removing the kora_lib status effect {string} from my client should be refused', 'client', function(ctx, name)
    ctx:equal(K.export(LIB, 'status_remove', testName(name)), false, 'status_remove result')
end)
-- Client apply asserts on an unregistered name (:118-119).
K.step('applying the unregistered kora_lib status effect {string} should be refused', 'client', function(ctx, name)
    testName(name)
    ctx:cleanup(function() pcall(function() exports[LIB]:status_remove(name) end) end)
    refusedSync('status_apply', 'Unknown status effect', name)
    ctx:equal(K.export(LIB, 'status_isActive', name), false, 'status_isActive')
end)
-- Kora.status.onChange(handler): handler(name, applied) (:233-240).
K.step('my client listens for kora_lib status changes', 'client', function(ctx)
    local heard = {}
    ctx.state.libStatusHeard = heard
    local id = K.export(LIB, 'status_onChange', function(name, applied)
        if #heard < 40 then heard[#heard + 1] = { name = name, applied = applied } end
    end)
    assert(type(id) == 'number', 'status_onChange did not return a listener id')
    ctx.state.libStatusListener = id
    ctx:cleanup(function() pcall(function() exports[LIB]:status_offChange(id) end) end)
end)
K.step('my client should have heard the kora_lib status effect {string} applied then removed', 'client', function(ctx, name)
    local heard = assert(ctx.state.libStatusHeard, 'Listen for status changes first')
    local function sequence()
        local out = {}
        for _, change in ipairs(heard) do
            if change.name == name then out[#out + 1] = change.applied and 'applied' or 'removed' end
        end
        return table.concat(out, ' > ')
    end
    ctx:waitUntil(function() return sequence() == 'applied > removed' end,
        'Status changes heard for ' .. name .. ' were not exactly applied then removed', 5000,
        function() return ' | heard: ' .. sequence() end)
end)
K.step('my client stops listening for kora_lib status changes', 'client', function(ctx)
    local id = assert(ctx.state.libStatusListener, 'Listen for status changes first')
    ctx:equal(K.export(LIB, 'status_offChange', id), true, 'status_offChange result')
    -- The listener is gone, so fft no longer owns that id (:242-249).
    ctx:equal(K.export(LIB, 'status_offChange', id), false, 'Second status_offChange result')
end)

-- Server Kora.status.apply(target, name, opts) pushes the effect to that player
-- (modules/status/server.lua). The client applies it as kora_lib, so only the
-- server can remove it again.
K.step('the server applies the kora_lib status effect {string} to me', 'server', function(ctx, name)
    testName(name)
    local tester = ctx.tester
    assert(type(tester) == 'number' and tester >= 1, 'No tester source')
    ctx:cleanup(function() pcall(function() exports[LIB]:status_remove(tester, name) end) end)
    ctx:equal(K.export(LIB, 'status_apply', tester, name), true, 'status_apply result')
    ctx:equal(K.export(LIB, 'status_isActive', tester, name), true, 'Server status_isActive')
end)
K.step('the server removes the kora_lib status effect {string} from me', 'server', function(ctx, name)
    ctx:equal(K.export(LIB, 'status_remove', ctx.tester, testName(name)), true, 'status_remove result')
    ctx:equal(K.export(LIB, 'status_isActive', ctx.tester, name), false, 'Server status_isActive')
    -- Nothing is left to remove.
    ctx:equal(K.export(LIB, 'status_remove', ctx.tester, name), false, 'Second status_remove result')
end)
-- An unregistered name is answered, not raised: false, "Unknown status effect: %s" (:34-36).
K.step('the server applying the unregistered kora_lib status effect {string} to me should be refused', 'server',
    function(ctx, name)
        testName(name)
        local tester = ctx.tester
        ctx:cleanup(function() pcall(function() exports[LIB]:status_remove(tester, name) end) end)
        local applied, reason = K.export(LIB, 'status_apply', tester, name)
        ctx:equal(applied, false, 'status_apply result')
        assert(K.contains(reason, 'Unknown status effect: ' .. name), 'Unexpected refusal reason: ' .. tostring(reason))
        ctx:equal(K.export(LIB, 'status_isActive', tester, name), false, 'Server status_isActive')
    end)
K.step('kora_lib should refuse a status effect with the stacking mode {string}', 'server', function(ctx, mode)
    -- modules/status/shared.lua:26.
    serverRefusal(ctx, 'status_registerEffect', 'Invalid stacking mode: ' .. mode, 'fft:kora_lib:status-invalid', { stacking = mode })
    ctx:equal(K.export(LIB, 'status_getEffectDef', 'fft:kora_lib:status-invalid'), nil, 'status_getEffectDef')
end)

-- ---------------------------------------------------------------------------
-- Timers (modules/timers/shared.lua), exercised on the server. Callbacks are
-- fft functions that only count; every timer is cleared during cleanup.
-- ---------------------------------------------------------------------------

local function pause(ctx, ms)
    local deadline = GetGameTimer() + ms
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
end

K.step('a kora_lib timeout of {int} milliseconds should fire exactly once', 'server', function(ctx, delay)
    assert(delay >= 0 and delay <= 3000, 'Test timeouts last 0-3000 ms')
    local fired = 0
    local id = K.export(LIB, 'timers_setTimeout', function() fired = fired + 1 end, delay)
    assert(type(id) == 'number', 'timers_setTimeout did not return an id')
    ctx:cleanup(function() pcall(function() exports[LIB]:timers_clearTimeout(id) end) end)
    ctx:waitUntil(function() return fired >= 1 end, 'The timeout never fired', delay + 3000)
    pause(ctx, 500)
    ctx:equal(fired, 1, 'Timeout fire count')
    -- A fired timeout no longer exists (scheduleTimeout drops its record, :58-59).
    ctx:equal(K.export(LIB, 'timers_clearTimeout', id), false, 'timers_clearTimeout after firing')
end)
K.step('a cleared kora_lib timeout should never fire', 'server', function(ctx)
    local fired = 0
    local id = K.export(LIB, 'timers_setTimeout', function() fired = fired + 1 end, 600)
    ctx:cleanup(function() pcall(function() exports[LIB]:timers_clearTimeout(id) end) end)
    ctx:equal(K.export(LIB, 'timers_clearTimeout', id), true, 'timers_clearTimeout result')
    ctx:equal(K.export(LIB, 'timers_clearTimeout', id), false, 'Second timers_clearTimeout result')
    pause(ctx, 1200)
    ctx:equal(fired, 0, 'Timeout fire count')
end)
K.step('a kora_lib interval of {int} milliseconds should tick until it is cleared', 'server', function(ctx, interval)
    assert(interval >= 50 and interval <= 1000, 'Test intervals last 50-1000 ms')
    local ticks = 0
    local id = K.export(LIB, 'timers_setInterval', function() ticks = ticks + 1 end, interval)
    assert(type(id) == 'number', 'timers_setInterval did not return an id')
    ctx:cleanup(function() pcall(function() exports[LIB]:timers_clearInterval(id) end) end)
    ctx:waitUntil(function() return ticks >= 2 end, 'The interval did not tick twice', interval * 2 + 3000)
    ctx:equal(K.export(LIB, 'timers_clearInterval', id), true, 'timers_clearInterval result')
    local stoppedAt = ticks
    pause(ctx, interval * 3)
    ctx:equal(ticks, stoppedAt, 'Ticks after clearing')
    ctx:equal(K.export(LIB, 'timers_clearInterval', id), false, 'Second timers_clearInterval result')
end)
K.step('clearing a kora_lib timer that was never set should be refused', 'server', function(ctx)
    -- clearTimer: unknown ids and non-integers return false (:104-107).
    ctx:equal(K.export(LIB, 'timers_clearTimeout', 2147480000), false, 'timers_clearTimeout unknown id')
    ctx:equal(K.export(LIB, 'timers_clearInterval', 'fft-not-an-id'), false, 'timers_clearInterval non-integer id')
end)
K.step('kora_lib should refuse a timeout with a negative delay', 'server', function(ctx)
    -- assertInterval, :25-27.
    serverRefusal(ctx, 'timers_setTimeout', 'Kora.timers.setTimeout requires a non-negative integer millisecond interval.',
        function() end, -1)
end)
K.step('kora_lib should refuse an interval without a callable', 'server', function(ctx)
    -- :73.
    serverRefusal(ctx, 'timers_setInterval', 'Kora.timers.setInterval requires a callable.', 'fft-not-a-function', 1000)
end)
-- Kora.timers.cooldown(interval) returns { use, remaining, reset }, keyed (:204-235).
K.step('a kora_lib cooldown of {int} milliseconds should gate each key separately', 'server', function(ctx, interval)
    assert(interval >= 5000, 'Use a cooldown long enough to outlast the step')
    local cooldown = K.export(LIB, 'timers_cooldown', interval)
    assert(type(cooldown) == 'table' and cooldown.use and cooldown.remaining and cooldown.reset,
        'timers_cooldown did not return use, remaining and reset')
    ctx:equal(cooldown.remaining('fft-a'), 0, 'Remaining before first use')
    ctx:equal(cooldown.use('fft-a'), true, 'First use')
    ctx:equal(cooldown.use('fft-a'), false, 'Second use inside the cooldown')
    ctx:equal(cooldown.use('fft-b'), true, 'First use of another key')
    local remaining = cooldown.remaining('fft-a')
    assert(type(remaining) == 'number' and remaining > 0 and remaining <= interval,
        'Remaining cooldown is ' .. tostring(remaining))
    cooldown.reset('fft-a')
    ctx:equal(cooldown.remaining('fft-a'), 0, 'Remaining after reset')
    ctx:equal(cooldown.use('fft-a'), true, 'Use after reset')
    ctx:equal(cooldown.use('fft-b'), false, 'Other key is still cooling down')
    cooldown.reset()
    ctx:equal(cooldown.use('fft-b'), true, 'Use after a full reset')
end)

-- ---------------------------------------------------------------------------
-- More stateless exports on the server: util, random, rewards, vehicle plates
-- ---------------------------------------------------------------------------

-- Kora.util.fnv1a: 32-bit FNV-1a as 8 lower-case hex digits (modules/util/shared.lua).
K.step('kora_lib should hash {string} as {string}', 'server', function(ctx, value, expected)
    ctx:equal(K.export(LIB, 'util_fnv1a', value), expected, 'util_fnv1a')
end)
-- Kora.util.cleanText: control characters become spaces, whitespace collapses, ends are trimmed.
K.step('kora_lib should clean {string} to {string}', 'server', function(ctx, value, expected)
    ctx:equal(K.export(LIB, 'util_cleanText', value), expected, 'util_cleanText')
end)
K.step('kora_lib should clean {string} to at most {int} characters as {string}', 'server', function(ctx, value, maximum, expected)
    ctx:equal(K.export(LIB, 'util_cleanText', value, { maxLength = maximum }), expected, 'util_cleanText')
end)
-- Returns nil, reason. The reason follows a nil and may not survive the export
-- boundary, so it is compared only when it arrived.
K.step('kora_lib should clean {string} to nothing because it is {string}', 'server', function(ctx, value, expected)
    local text, reason = K.export(LIB, 'util_cleanText', value)
    ctx:equal(text, nil, 'util_cleanText')
    assert(reason == nil or reason == expected, ('util_cleanText gave the reason %s, expected %s'):format(tostring(reason), expected))
end)
K.step('kora_lib should refuse to clean a number as text', 'server', function(ctx)
    local text, reason = K.export(LIB, 'util_cleanText', 42)
    ctx:equal(text, nil, 'util_cleanText')
    assert(reason == nil or reason == 'invalid_type', 'util_cleanText gave the reason ' .. tostring(reason))
    -- options.empty = "allow" keeps an empty result.
    ctx:equal(K.export(LIB, 'util_cleanText', '   ', { empty = 'allow' }), '', 'util_cleanText with empty allowed')
end)
K.step('kora_lib should decode valid JSON and report broken JSON as invalid', 'server', function(ctx)
    local decoded = K.export(LIB, 'util_decodeJson', '{"fft":[1,2,3],"name":"lib"}')
    assert(type(decoded) == 'table' and type(decoded.fft) == 'table', 'util_decodeJson did not return the object')
    ctx:equal(#decoded.fft, 3, 'Decoded array length')
    ctx:equal(decoded.name, 'lib', 'Decoded string')
    local broken, reason = K.export(LIB, 'util_decodeJson', '{"fft":')
    ctx:equal(broken, nil, 'util_decodeJson of broken JSON')
    assert(reason == nil or reason == 'invalid_json', 'util_decodeJson gave the reason ' .. tostring(reason))
end)
K.step('kora_lib should tell finite numbers and integers apart', 'server', function(ctx)
    ctx:equal(K.export(LIB, 'util_isFiniteNumber', 1.5), true, 'isFiniteNumber 1.5')
    ctx:equal(K.export(LIB, 'util_isFiniteNumber', '1.5'), false, 'isFiniteNumber "1.5"')
    ctx:equal(K.export(LIB, 'util_isFiniteNumber', nil), false, 'isFiniteNumber nil')
    ctx:equal(K.export(LIB, 'util_isInteger', 2), true, 'isInteger 2')
    ctx:equal(K.export(LIB, 'util_isInteger', -7), true, 'isInteger -7')
    ctx:equal(K.export(LIB, 'util_isInteger', 2.5), false, 'isInteger 2.5')
    ctx:equal(K.export(LIB, 'util_isInteger', '2'), false, 'isInteger "2"')
    ctx:equal(K.export(LIB, 'util_tableContains', { 'a', 'b' }, 'b'), true, 'tableContains b')
    ctx:equal(K.export(LIB, 'util_tableContains', { 'a', 'b' }, 'c'), false, 'tableContains c')
end)
K.step('kora_lib should interpolate from {int} to {int} at {float} as {float}', 'server', function(_, from, to, t, expected)
    assertNear(K.export(LIB, 'util_lerp', from, to, t), expected, 'util_lerp')
end)
K.step('kora_lib vector helpers should agree on a 3-4-5 triangle', 'server', function()
    local origin, corner, raised = { x = 0, y = 0, z = 0 }, { x = 3, y = 4, z = 0 }, { x = 3, y = 4, z = 12 }
    assertNear(K.export(LIB, 'util_vecDistance', origin, corner), 5, 'vecDistance')
    assertNear(K.export(LIB, 'util_vecDistance', origin, raised), 13, 'vecDistance in 3D')
    assertNear(K.export(LIB, 'util_vecDistance2d', origin, raised), 5, 'vecDistance2d')
    -- A point without z makes vecDistance planar (hasZ).
    assertNear(K.export(LIB, 'util_vecDistance', { x = 0, y = 0 }, raised), 5, 'vecDistance with a 2D point')
    assertNear(K.export(LIB, 'util_vecLength', raised), 13, 'vecLength')
    local sum = K.export(LIB, 'util_vecAdd', corner, raised)
    assert(type(sum) == 'table' and near(sum.x, 6) and near(sum.y, 8) and near(sum.z, 12), 'vecAdd is wrong')
    local difference = K.export(LIB, 'util_vecSub', raised, corner)
    assert(type(difference) == 'table' and near(difference.x, 0) and near(difference.y, 0) and near(difference.z, 12), 'vecSub is wrong')
    local scaled = K.export(LIB, 'util_vecScale', corner, 2)
    assert(type(scaled) == 'table' and near(scaled.x, 6) and near(scaled.y, 8) and near(scaled.z, 0), 'vecScale is wrong')
    local unit = K.export(LIB, 'util_vecNormalize', corner)
    assert(type(unit) == 'table' and near(unit.x, 0.6) and near(unit.y, 0.8) and near(unit.z, 0), 'vecNormalize is wrong')
    local zero = K.export(LIB, 'util_vecNormalize', origin)
    assert(type(zero) == 'table' and near(zero.x, 0) and near(zero.y, 0) and near(zero.z, 0), 'vecNormalize of zero is not zero')
end)
-- GTA headings: 0 faces +y, 90 faces -x (headingToDirection, directionToHeading).
K.step('kora_lib headings and directions should round-trip', 'server', function()
    local north = K.export(LIB, 'util_headingToDirection', 0)
    assert(type(north) == 'table' and near(north.x, 0) and near(north.y, 1), 'Heading 0 does not face +y')
    local west = K.export(LIB, 'util_headingToDirection', 90)
    assert(type(west) == 'table' and near(west.x, -1) and near(west.y, 0), 'Heading 90 does not face -x')
    assertNear(K.export(LIB, 'util_directionToHeading', { x = -1, y = 0, z = 0 }), 90, 'directionToHeading -x')
    assertNear(K.export(LIB, 'util_directionToHeading', { x = 1, y = 0, z = 0 }), 270, 'directionToHeading +x')
    assertNear(K.export(LIB, 'util_bearing', { x = 10, y = 10, z = 0 }, { x = 10, y = 20, z = 0 }), 0, 'bearing to +y')
    assertNear(K.export(LIB, 'util_bearing', { x = 10, y = 10, z = 0 }, { x = 10, y = 0, z = 0 }), 180, 'bearing to -y')
end)
K.step('kora_lib random helpers should stay inside their bounds', 'server', function(ctx)
    for _ = 1, 25 do
        local value = K.export(LIB, 'util_randomFloat', 2, 3)
        assert(type(value) == 'number' and value >= 2 and value <= 3, 'util_randomFloat returned ' .. tostring(value))
    end
    assertNear(K.export(LIB, 'util_randomFloat', 4, 4), 4, 'util_randomFloat with equal bounds')
    ctx:equal(K.export(LIB, 'util_weightedChoice', { { 'fft-only', 5 } }), 'fft-only', 'util_weightedChoice')
    -- Kora.random.pick (modules/random/shared.lua): count 1 returns the value, more return an array.
    ctx:equal(K.export(LIB, 'random_pick', { 'fft-single' }), 'fft-single', 'random_pick')
    local picked = K.export(LIB, 'random_pick', { 'fft-a', 'fft-b', 'fft-c' }, { count = 6, maxIndex = 1 })
    assert(type(picked) == 'table', 'random_pick with a count did not return an array')
    ctx:equal(#picked, 6, 'random_pick count')
    for _, value in ipairs(picked) do ctx:equal(value, 'fft-a', 'random_pick limited to the first entry') end
    for _ = 1, 25 do
        local value = K.export(LIB, 'random_pick', { 'fft-a', 'fft-b', 'fft-c' }, { maxIndex = 2 })
        assert(value == 'fft-a' or value == 'fft-b', 'random_pick ignored maxIndex and returned ' .. tostring(value))
    end
end)
K.step('kora_lib should refuse invalid random arguments', 'server', function(ctx)
    -- modules/util/shared.lua (randomFloat, weightedChoice) and modules/random/shared.lua.
    serverRefusal(ctx, 'util_randomFloat', 'Kora.util.randomFloat requires finite bounds where min is at most max.', 3, 2)
    serverRefusal(ctx, 'util_weightedChoice', 'Kora.util.weightedChoice requires a non-empty dense array of pairs.', {})
    serverRefusal(ctx, 'util_weightedChoice', 'Every weightedChoice entry needs a positive finite weight.', { { 'fft', 0 } })
    serverRefusal(ctx, 'random_pick', 'Kora.random.pick requires a non-empty dense array.', {})
    serverRefusal(ctx, 'random_pick', 'Kora.random.pick count must be an integer between 1 and 10000.', { 'fft' }, { count = 10001 })
    serverRefusal(ctx, 'random_pick', 'Kora.random.pick maxIndex must be an integer between 1 and the array length.',
        { 'fft' }, { maxIndex = 2 })
end)
K.step('kora_lib should refuse invalid text arguments', 'server', function(ctx)
    -- modules/util/shared.lua: fnv1a, truncateUtf8, cleanText, decodeJson, lerp.
    serverRefusal(ctx, 'util_fnv1a', 'Kora.util.fnv1a requires a string.', 42)
    serverRefusal(ctx, 'util_truncateUtf8', 'Kora.util.truncateUtf8 requires a non-negative integer maximum.', 'fft', -1)
    serverRefusal(ctx, 'util_cleanText', 'Kora.util.cleanText maxLength must be a non-negative integer.', 'fft', { maxLength = -1 })
    serverRefusal(ctx, 'util_cleanText', "Kora.util.cleanText whitespace must be 'collapse' or 'preserve'.", 'fft', { whitespace = 'fft' })
    serverRefusal(ctx, 'util_decodeJson', 'Kora.util.decodeJson requires a string.', 42)
    serverRefusal(ctx, 'util_lerp', 'Kora.util.lerp requires finite numbers.', 0, 'ten', 0.5)
end)

-- Kora.rewards.generate (modules/rewards/shared.lua). Only deterministic
-- shapes are asserted: a single weighted item, and percent chances of 100.
K.step('kora_lib should generate deterministic rewards', 'server', function(ctx)
    local single = K.export(LIB, 'rewards_generate', { { name = 'fft_reward', amount = 3, chance = 7 } })
    assert(type(single) == 'table', 'rewards_generate did not return an array')
    ctx:equal(#single, 1, 'Weighted reward count')
    ctx:equal(single[1].name, 'fft_reward', 'Reward name')
    ctx:equal(single[1].amount, 3, 'Reward amount')
    ctx:equal(single[1].chance, nil, 'Reward chance is stripped')

    local defaulted = K.export(LIB, 'rewards_generate', { { name = 'fft_reward' } }, { rolls = 4 })
    ctx:equal(#defaulted, 4, 'Reward count for four rolls')
    for _, reward in ipairs(defaulted) do ctx:equal(reward.amount, 1, 'Default reward amount') end

    local certain = K.export(LIB, 'rewards_generate', {
        { name = 'fft_first', chance = 100, amount = { min = 2, max = 2 } },
        { name = 'fft_second', chance = 100, amount = { min = 5, max = 9 } },
    }, { mode = 'percent', rolls = 2 })
    ctx:equal(#certain, 4, 'Percent reward count')
    for _, reward in ipairs(certain) do
        if reward.name == 'fft_first' then
            ctx:equal(reward.amount, 2, 'Fixed range amount')
        else
            ctx:equal(reward.name, 'fft_second', 'Reward name')
            assert(type(reward.amount) == 'number' and reward.amount >= 5 and reward.amount <= 9 and reward.amount % 1 == 0,
                'Ranged reward amount is ' .. tostring(reward.amount))
        end
    end
end)
K.step('kora_lib should refuse invalid reward tables', 'server', function(ctx)
    serverRefusal(ctx, 'rewards_generate', 'items must be a non-empty dense array', {})
    serverRefusal(ctx, 'rewards_generate', 'item.chance must not exceed 100 in percent mode',
        { { name = 'fft_reward', chance = 101 } }, { mode = 'percent' })
    serverRefusal(ctx, 'rewards_generate', 'item.chance must be a positive number', { { name = 'fft_reward', chance = 0 } })
    serverRefusal(ctx, 'rewards_generate', 'opts.rolls must be an integer between 1 and 10000', { { name = 'fft_reward' } }, { rolls = 0 })
    serverRefusal(ctx, 'rewards_generate', 'opts.mode must be "weighted" or "percent"', { { name = 'fft_reward' } }, { mode = 'fft' })
    serverRefusal(ctx, 'rewards_generate', 'item.amount.min must not be greater than item.amount.max',
        { { name = 'fft_reward', amount = { min = 5, max = 1 } } })
end)

-- Kora.vehicle.normalizePlate (modules/vehicle/shared.lua): trims, upper-cases,
-- collapses whitespace; at most 8 characters, alphanumeric by default.
K.step('kora_lib should normalise the plate {string} to {string}', 'server', function(ctx, value, expected)
    ctx:equal(K.export(LIB, 'vehicle_normalizePlate', value), expected, 'vehicle_normalizePlate')
end)
K.step('kora_lib should normalise the plate {string} without whitespace to {string}', 'server', function(ctx, value, expected)
    ctx:equal(K.export(LIB, 'vehicle_normalizePlate', value, { whitespace = 'remove' }), expected, 'vehicle_normalizePlate')
end)
-- Returns nil, reason; see the cleanText note about the reason.
K.step('kora_lib should reject the plate {string} as {string}', 'server', function(ctx, value, expected)
    local plate, reason = K.export(LIB, 'vehicle_normalizePlate', value)
    ctx:equal(plate, nil, 'vehicle_normalizePlate')
    assert(reason == nil or reason == expected,
        ('vehicle_normalizePlate gave the reason %s, expected %s'):format(tostring(reason), expected))
end)
K.step('kora_lib should accept the plate {string} with any characters up to {int} long as {string}', 'server',
    function(ctx, value, maximum, expected)
        ctx:equal(K.export(LIB, 'vehicle_normalizePlate', value, { characters = 'any', maxLength = maximum }), expected,
            'vehicle_normalizePlate')
    end)

-- ---------------------------------------------------------------------------
-- Permissions (modules/permissions/server.lua), read-only, for the tester.
-- The made-up level has no ACE, so it is never held; "user" is always held.
-- ---------------------------------------------------------------------------

local function levelList(text)
    local levels = {}
    for level in text:gmatch('[^,%s]+') do levels[#levels + 1] = level end
    return levels
end

K.step('I should hold the kora_lib permission {string}', 'server', function(ctx, permission)
    ctx:equal(K.export(LIB, 'permissions_hasPermission', ctx.tester, permission), true, 'permissions_hasPermission')
end)
-- Levels are listed highest first, comma-separated. getLevel returns the first
-- level held and falls back to "user"; explain returns the same level.
K.step('my kora_lib permission level among {string} should be {string}', 'server', function(ctx, levels, expected)
    local list = levelList(levels)
    ctx:equal(K.export(LIB, 'permissions_getLevel', ctx.tester, list), expected, 'permissions_getLevel')
    local checks, explained = K.export(LIB, 'permissions_explain', ctx.tester, list)
    assert(type(checks) == 'table', 'permissions_explain did not return its checks')
    ctx:equal(#checks, #list, 'Explained check count')
    ctx:equal(checks[1].object, 'group.' .. list[1], 'First explained ACE object')
    ctx:equal(explained, expected, 'Explained level')
end)
K.step('I should meet the kora_lib level {string} among {string}', 'server', function(ctx, required, levels)
    ctx:equal(K.export(LIB, 'permissions_hasLevel', ctx.tester, required, levelList(levels)), true, 'permissions_hasLevel')
end)
K.step('I should not meet the kora_lib level {string} among {string}', 'server', function(ctx, required, levels)
    ctx:equal(K.export(LIB, 'permissions_hasLevel', ctx.tester, required, levelList(levels)), false, 'permissions_hasLevel')
end)
K.step('kora_lib should refuse permission checks without a valid player or level list', 'server', function(ctx)
    -- assertPlayerSource and assertLevels, modules/permissions/server.lua.
    serverRefusal(ctx, 'permissions_hasPermission', 'Permission source must be a positive finite player server ID.', 0, 'user')
    serverRefusal(ctx, 'permissions_hasPermission', 'Permission must be a non-empty string.', ctx.tester, '')
    serverRefusal(ctx, 'permissions_getLevel', 'Permission levels must be a non-empty array.', ctx.tester, {})
    serverRefusal(ctx, 'permissions_getLevel', 'Each permission level must be a non-empty string.', ctx.tester, { 'user', '' })
    serverRefusal(ctx, 'permissions_hasLevel', 'Required permission level must be a non-empty string.', ctx.tester, '', { 'user' })
end)

-- ---------------------------------------------------------------------------
-- Coverage expansion: debounce, throttle, rate limiter, nearest, lookup,
-- locales, notify aliases, minigame motion, controlled loops, GlobalState
-- waits and server distance checks. Every export here is stateless or owns
-- only the handles it returns; nothing is written to any player or to the
-- world, and every timer a step creates is cleared in cleanup.
-- ---------------------------------------------------------------------------

-- Kora.timers.debounce(fn, wait) returns { run, cancel, isPending }
-- (modules/timers/shared.lua). __call does not cross the export boundary, so
-- consumers use .run(...), exactly as the module documents.
K.step('a kora_lib debounce of {int} milliseconds should run once with the last arguments of a burst', 'server',
    function(ctx, wait)
        assert(wait >= 50 and wait <= 2000, 'Test debounces last 50-2000 ms')
        local calls, last = 0, nil
        local handle = K.export(LIB, 'timers_debounce', function(value) calls = calls + 1 last = value end, wait)
        assert(type(handle) == 'table' and handle.run and handle.cancel and handle.isPending,
            'timers_debounce did not return run, cancel and isPending')
        ctx:cleanup(function() pcall(function() handle.cancel() end) end)
        ctx:equal(handle.isPending(), false, 'isPending before the first run')
        handle.run('fft-first')
        handle.run('fft-second')
        handle.run('fft-third')
        ctx:equal(handle.isPending(), true, 'isPending inside the burst')
        ctx:waitUntil(function() return calls >= 1 end, 'The debounced function never ran', wait + 3000)
        pause(ctx, wait + 300)
        ctx:equal(calls, 1, 'Debounced run count')
        ctx:equal(last, 'fft-third', 'Arguments of the debounced run')
        ctx:equal(handle.isPending(), false, 'isPending after the run')
    end)
K.step('a cancelled kora_lib debounce should never run', 'server', function(ctx)
    local calls = 0
    local handle = K.export(LIB, 'timers_debounce', function() calls = calls + 1 end, 400)
    ctx:cleanup(function() pcall(function() handle.cancel() end) end)
    ctx:equal(handle.cancel(), false, 'cancel with nothing pending')
    handle.run()
    ctx:equal(handle.cancel(), true, 'cancel with a run pending')
    ctx:equal(handle.isPending(), false, 'isPending after cancel')
    pause(ctx, 900)
    ctx:equal(calls, 0, 'Debounced run count after cancel')
end)
-- Kora.timers.throttle(fn, interval) returns { run, remaining, reset }.
K.step('a kora_lib throttle of {int} milliseconds should let one call through until it is reset', 'server',
    function(ctx, interval)
        assert(interval >= 5000, 'Use a throttle long enough to outlast the step')
        local calls = 0
        local handle = K.export(LIB, 'timers_throttle', function() calls = calls + 1 end, interval)
        assert(type(handle) == 'table' and handle.run and handle.remaining and handle.reset,
            'timers_throttle did not return run, remaining and reset')
        ctx:equal(handle.remaining(), 0, 'remaining before the first call')
        ctx:equal(handle.run(), true, 'First throttled call')
        ctx:equal(handle.run(), false, 'Second throttled call inside the interval')
        ctx:equal(calls, 1, 'Throttled run count')
        local remaining = handle.remaining()
        assert(type(remaining) == 'number' and remaining > 0 and remaining <= interval,
            'Throttle remaining is ' .. tostring(remaining))
        handle.reset()
        ctx:equal(handle.remaining(), 0, 'remaining after reset')
        ctx:equal(handle.run(), true, 'Throttled call after reset')
        ctx:equal(calls, 2, 'Throttled run count after reset')
    end)
-- Kora.timers.count(): every live timer record, whoever owns it.
K.step('the kora_lib timer count should include a pending timeout until it is cleared', 'server', function(ctx)
    local id = K.export(LIB, 'timers_setTimeout', function() end, 60000)
    ctx:cleanup(function() pcall(function() exports[LIB]:timers_clearTimeout(id) end) end)
    local withTimer = K.export(LIB, 'timers_count')
    assert(type(withTimer) == 'number' and withTimer >= 1, 'timers_count is ' .. tostring(withTimer))
    ctx:equal(K.export(LIB, 'timers_clearTimeout', id), true, 'timers_clearTimeout result')
    -- Other resources may add or drop timers meanwhile; ours is gone, so the
    -- count cannot still include it unless something else started one.
    local after = K.export(LIB, 'timers_count')
    assert(type(after) == 'number' and after >= 0, 'timers_count is ' .. tostring(after))
end)
K.step('kora_lib should refuse debounce and throttle without a callable or with a negative wait', 'server', function(ctx)
    -- modules/timers/shared.lua debounce/throttle asserts; assertInterval :32-35.
    serverRefusal(ctx, 'timers_debounce', 'Kora.timers.debounce requires a callable.', 'fft-not-a-function', 100)
    serverRefusal(ctx, 'timers_throttle', 'Kora.timers.throttle requires a callable.', 'fft-not-a-function', 100)
    serverRefusal(ctx, 'timers_debounce', 'Kora.timers.debounce requires a non-negative integer millisecond interval.',
        function() end, -5)
    serverRefusal(ctx, 'timers_throttle', 'Kora.timers.throttle requires a non-negative integer millisecond interval.',
        function() end, 1.5)
end)

-- Kora.util.rateLimiter(max, window): limiter:consume(key, now) takes the
-- caller's clock, so these checks are deterministic (modules/util/shared.lua).
K.step('a kora_lib rate limiter of {int} calls per {int} milliseconds should refuse the next call until the window passes',
    'server', function(ctx, max, window)
        assert(max >= 1 and max <= 20 and window >= 1, 'Use 1-20 calls and a positive window')
        local limiter = K.export(LIB, 'util_rateLimiter', max, window)
        assert(type(limiter) == 'table' and limiter.consume, 'util_rateLimiter did not return consume')
        local function consume(key, now) return limiter.consume(limiter, key, now) end
        for call = 1, max do
            ctx:equal(consume('fft-a', 1000 + call), true, ('Call %d inside the limit'):format(call))
        end
        local allowed, retry = consume('fft-a', 1000 + max)
        ctx:equal(allowed, false, 'Call beyond the limit')
        assert(type(retry) == 'number' and retry > 0 and retry <= window, 'Retry-after is ' .. tostring(retry))
        ctx:equal(consume('fft-b', 1000 + max), true, 'Another key has its own bucket')
        -- The first stamp (1001) falls out of the window at 1001 + window.
        ctx:equal(consume('fft-a', 1001 + window), true, 'Call after the oldest stamp left the window')
    end)
K.step('kora_lib should refuse a rate limiter with an invalid limit or window', 'server', function(ctx)
    serverRefusal(ctx, 'util_rateLimiter', 'Kora.util.rateLimiter requires a positive integer max.', 0, 1000)
    serverRefusal(ctx, 'util_rateLimiter', 'Kora.util.rateLimiter requires a positive integer max.', 2.5, 1000)
    serverRefusal(ctx, 'util_rateLimiter', 'Kora.util.rateLimiter requires a positive finite window.', 3, 0)
end)

-- Kora.util.nearest(list, position, { coordsOf, radius?, bucketOf?, bucket? }).
local NEAREST_POINTS = {
    { id = 'fft-near', bucket = 1, coords = { x = 3.0, y = 4.0, z = 0.0 } },  -- 5 from the origin
    { id = 'fft-mid', bucket = 2, coords = { x = 6.0, y = 8.0, z = 0.0 } },   -- 10
    { id = 'fft-far', bucket = 1, coords = { x = 30.0, y = 40.0, z = 0.0 } }, -- 50
}
local function nearestOf(opts)
    opts.coordsOf = function(entry) return entry.coords end
    local entry, distance = K.export(LIB, 'util_nearest', NEAREST_POINTS, { x = 0.0, y = 0.0, z = 0.0 }, opts)
    return entry and entry.id or nil, distance
end
K.step('kora_lib should find the nearest entry to the origin as {string} at {float}', 'server', function(ctx, id, distance)
    local found, at = nearestOf({})
    ctx:equal(found, id, 'util_nearest entry')
    assertNear(at, distance, 'util_nearest distance')
end)
K.step('kora_lib should find no entry within {float} of the origin', 'server', function(ctx, radius)
    ctx:equal(nearestOf({ radius = radius }), nil, 'util_nearest entry inside the radius')
end)
K.step('kora_lib should find the nearest entry in bucket {int} as {string}', 'server', function(ctx, bucket, id)
    ctx:equal(nearestOf({ bucket = bucket, bucketOf = function(entry) return entry.bucket end }), id,
        'util_nearest entry in the bucket')
end)
K.step('kora_lib should refuse a nearest search without a list or coordinate reader', 'server', function(ctx)
    serverRefusal(ctx, 'util_nearest', 'Kora.util.nearest requires a list.', 'fft-not-a-list', { x = 0, y = 0, z = 0 },
        { coordsOf = function() end })
    serverRefusal(ctx, 'util_nearest', 'Kora.util.nearest requires opts.coordsOf.', {}, { x = 0, y = 0, z = 0 }, {})
    serverRefusal(ctx, 'util_nearest', 'Kora.util.nearest opts.bucketOf must be callable when provided.', {},
        { x = 0, y = 0, z = 0 }, { coordsOf = function() end, bucketOf = 'fft-not-a-function' })
end)

-- Kora.lookup (modules/lookup/shared.lua, base data in modules/lookup/data).
-- Names and hashes are asserted; labels may be overridden by server overlays.
K.step('kora_lib should look up the weapon {string} with hash {int}', 'server', function(ctx, value, hash)
    local record, reason = K.export(LIB, 'lookup_weapon', value)
    assert(type(record) == 'table', ('lookup_weapon(%s) found nothing (%s)'):format(value, tostring(reason)))
    ctx:equal(record.namespace, 'weapon', 'Record namespace')
    ctx:equal(record.hash, hash, 'Record hash')
    ctx:equal(record.hexHash, ('0x%08X'):format(hash), 'Record hexadecimal hash')
    ctx:equal(record.name, 'WEAPON_PISTOL', 'Record name')
end)
K.step('kora_lib should look up the vehicle model {string} as {string}', 'server', function(ctx, value, name)
    local record, reason = K.export(LIB, 'lookup_model', value)
    assert(type(record) == 'table', ('lookup_model(%s) found nothing (%s)'):format(value, tostring(reason)))
    ctx:equal(record.namespace, 'vehicle', 'Record namespace')
    ctx:equal(record.name, name, 'Record name')
    local scoped = K.export(LIB, 'lookup_model', value, 'vehicle')
    ctx:equal(type(scoped) == 'table' and scoped.hash, record.hash, 'Vehicle-scoped lookup hash')
end)
K.step('kora_lib should report the weapon {string} as not found', 'server', function(ctx, value)
    local record, reason = K.export(LIB, 'lookup_weapon', value)
    ctx:equal(record, nil, 'lookup_weapon record')
    -- The reason follows a nil and may not survive the export boundary.
    assert(reason == nil or reason == 'not_found' or reason == 'catalog_pending',
        'lookup_weapon gave the reason ' .. tostring(reason))
end)
K.step('the kora_lib lookup catalogue should be ready', 'server', function(ctx)
    ctx:equal(K.export(LIB, 'lookup_awaitReady', 5000), true, 'lookup_awaitReady')
    ctx:equal(K.export(LIB, 'lookup_ready'), true, 'lookup_ready')
end)
K.step('kora_lib should refuse lookups with an unknown namespace or a malformed hash', 'server', function(ctx)
    serverRefusal(ctx, 'lookup_get', 'Unknown lookup namespace: fft_never', 'fft_never', 'adder')
    serverRefusal(ctx, 'lookup_model', 'Model lookup kind must be vehicle, ped, or object.', 'adder', 'weapon')
    serverRefusal(ctx, 'lookup_weapon', 'Lookup value must not be empty.', '   ')
    serverRefusal(ctx, 'lookup_weapon', 'Lookup hexadecimal hash is malformed.', '0xZZ')
    serverRefusal(ctx, 'lookup_weapon', 'Lookup decimal hash is malformed.', '12.5')
    serverRefusal(ctx, 'lookup_weapon', 'Lookup hash must be an integer.', 1.5)
    serverRefusal(ctx, 'lookup_weapon', 'Lookup hash must fit a signed or unsigned 32-bit integer.', 4294967296)
    serverRefusal(ctx, 'lookup_awaitReady', 'Lookup readiness timeout must be a non-negative integer.', -1)
end)

-- Kora.locale (modules/locales/shared.lua).
K.step('kora_lib should report English among the server languages', 'server', function(ctx)
    local languages = K.export(LIB, 'locale_getLanguages')
    assert(type(languages) == 'table', 'locale_getLanguages did not return a list')
    local found = false
    for _, code in ipairs(languages) do if code == 'en' then found = true end end
    assert(found, 'locale_getLanguages does not include en')
    local current = K.export(LIB, 'locale_getLanguage')
    assert(type(current) == 'string' and current ~= '', 'locale_getLanguage returned ' .. tostring(current))
end)
K.step('kora_lib should translate the unknown key {string} to the key itself', 'server', function(ctx, key)
    ctx:equal(K.export(LIB, 'locale_translate', LIB, key), key, 'locale_translate of an unknown key')
end)
K.step('kora_lib should refuse to translate without a resource or key', 'server', function(ctx)
    serverRefusal(ctx, 'locale_translate', 'locale resource must be a valid resource name.', '', 'fft.key')
    serverRefusal(ctx, 'locale_translate', 'locale key must be a non-empty string.', LIB, '')
end)

-- Kora.notify.normalizeType / normalize (modules/notify/shared.lua).
K.step('kora_lib should normalise the notification type {string} to {string}', 'server', function(ctx, value, expected)
    ctx:equal(K.export(LIB, 'notify_normalizeType', value), expected, 'notify_normalizeType')
    local payload = K.export(LIB, 'notify_normalize', { title = 'fft', type = value })
    ctx:equal(type(payload) == 'table' and payload.type, expected, 'notify_normalize type')
    ctx:equal(type(payload) == 'table' and payload.title, 'fft', 'notify_normalize keeps the other fields')
end)

-- Kora.minigames.triangleWave(elapsedMs, speedHz): 0 -> 1 -> 0 each cycle.
K.step('the kora_lib minigame wave at {int} milliseconds and {float} Hz should be {float}', 'server',
    function(_, elapsed, speed, expected)
        assertNear(K.export(LIB, 'minigames_triangleWave', elapsed, speed), expected, 'minigames_triangleWave')
    end)

-- Kora.loops.controlled(call, tries, timeout, backoff) (modules/loops/shared.lua).
K.step('a kora_lib controlled loop should return the first truthy value after {int} attempts', 'server',
    function(ctx, attempts)
        assert(attempts >= 1 and attempts <= 8, 'Use 1-8 attempts')
        local calls = 0
        local value = K.export(LIB, 'loops_controlled', function()
            calls = calls + 1
            return calls >= attempts and 'fft-ready' or false
        end, 10, 5000, 10)
        ctx:equal(value, 'fft-ready', 'loops_controlled value')
        ctx:equal(calls, attempts, 'Predicate calls')
    end)
K.step('a kora_lib controlled loop should give up after {int} tries', 'server', function(ctx, tries)
    local calls = 0
    local value, reason = K.export(LIB, 'loops_controlled', function() calls = calls + 1 return false end, tries, 5000, 5)
    ctx:equal(value, false, 'loops_controlled value')
    ctx:equal(calls, tries, 'Predicate calls')
    ctx:equal(reason, 'Loop failed due to exceeding try count.', 'loops_controlled reason')
end)
K.step('a kora_lib controlled loop should time out after {int} milliseconds', 'server', function(ctx, timeout)
    assert(timeout >= 50 and timeout <= 3000, 'Use a 50-3000 ms timeout')
    local started = GetGameTimer()
    local value, reason = K.export(LIB, 'loops_controlled', function() return false end, false, timeout, 25)
    local elapsed = GetGameTimer() - started
    ctx:equal(value, false, 'loops_controlled value')
    ctx:equal(reason, 'Loop timed out.', 'loops_controlled reason')
    assert(elapsed >= timeout - 50 and elapsed <= timeout + 2000, 'The loop stopped after ' .. elapsed .. ' ms')
end)
K.step('kora_lib should refuse a controlled loop with invalid limits', 'server', function(ctx)
    serverRefusal(ctx, 'loops_controlled', 'Loop predicate must be callable.', 'fft-not-a-function')
    serverRefusal(ctx, 'loops_controlled', 'Loop tries must be a positive integer or false.', function() return true end, 0)
    serverRefusal(ctx, 'loops_controlled', 'Loop timeout must be a non-negative integer or false.',
        function() return true end, 1, -1)
    serverRefusal(ctx, 'loops_controlled', 'Loop backoff must be a non-negative integer, boolean, or nil.',
        function() return true end, 1, 100, 'fft')
end)

-- Kora.state.awaitGlobal(key, timeoutMs, pollIntervalMs) (modules/state/shared.lua).
K.step('waiting {int} milliseconds for the kora_lib GlobalState key {string} should time out', 'server',
    function(ctx, timeout, key)
        assert(key:sub(1, 13) == 'fft:kora_lib:', 'Use a GlobalState key under fft:kora_lib:')
        assert(GlobalState[key] == nil, 'The GlobalState key is unexpectedly set: ' .. key)
        local value, reason = K.export(LIB, 'state_awaitGlobal', key, timeout, 25)
        ctx:equal(value, nil, 'state_awaitGlobal value')
        assert(reason == nil or reason == 'timeout', 'state_awaitGlobal gave the reason ' .. tostring(reason))
    end)
K.step('kora_lib should refuse to wait for GlobalState with invalid arguments', 'server', function(ctx)
    serverRefusal(ctx, 'state_awaitGlobal', 'Kora.state.awaitGlobal requires a state key.', '')
    serverRefusal(ctx, 'state_awaitGlobal', 'timeoutMs must be a non-negative integer.', 'fft:kora_lib:wait', -1)
    serverRefusal(ctx, 'state_awaitGlobal', 'pollIntervalMs must be a non-negative integer.', 'fft:kora_lib:wait', 10, 2.5)
end)

-- Kora.distance on the server (modules/distancecheck/server.lua): the tester's
-- own ped is read where it stands; nothing is moved.
local function testerCoords(ctx)
    local ped = GetPlayerPed(ctx.tester)
    assert(ped and ped ~= 0, 'The tester has no ped on the server')
    local at = GetEntityCoords(ped)
    return { x = at.x, y = at.y, z = at.z }
end
K.step('kora_lib should place me within {float} of where I stand and not {float} away', 'server',
    function(ctx, radius, offset)
        local at = testerCoords(ctx)
        ctx:equal(K.export(LIB, 'distance_player', ctx.tester, at, radius), true, 'distance_player at my position')
        local away = { x = at.x + offset, y = at.y, z = at.z }
        ctx:equal(K.export(LIB, 'distance_player', ctx.tester, away, radius), false, 'distance_player far away')
        ctx:equal(K.export(LIB, 'distance_x', ctx.tester, { x = at.x }, radius), true, 'distance_x')
        ctx:equal(K.export(LIB, 'distance_y', ctx.tester, { y = at.y + offset }, radius), false, 'distance_y far away')
        ctx:equal(K.export(LIB, 'distance_xy', ctx.tester, { x = at.x, y = at.y, z = at.z + 50.0 }, radius), true,
            'distance_xy ignores height')
    end)
K.step('kora_lib should find a known spot beside me among far ones', 'server', function(ctx)
    local at = testerCoords(ctx)
    local spots = {
        { id = 'fft-far', coords = { x = at.x + 500.0, y = at.y, z = at.z } },
        { id = 'fft-here', coords = { x = at.x + 1.0, y = at.y, z = at.z } },
    }
    local found, entry = K.export(LIB, 'distance_playerNearAny', ctx.tester, spots,
        { radius = 3.0, coordsOf = function(spot) return spot.coords end })
    ctx:equal(found, true, 'distance_playerNearAny found')
    ctx:equal(type(entry) == 'table' and entry.id, 'fft-here', 'distance_playerNearAny entry')
    local none = K.export(LIB, 'distance_playerNearAny', ctx.tester, { spots[1] },
        { radius = 3.0, coordsOf = function(spot) return spot.coords end })
    ctx:equal(none, false, 'distance_playerNearAny with only far spots')
end)
K.step('kora_lib should compare two coordinates within {float}', 'server', function(ctx, radius)
    local a, b = { x = 0.0, y = 0.0, z = 0.0 }, { x = 3.0, y = 4.0, z = 0.0 }
    ctx:equal(K.export(LIB, 'distance_coords', a, b, radius), radius >= 5, 'distance_coords')
    ctx:equal(K.export(LIB, 'distance_coords', a, a), true, 'distance_coords with the default radius')
end)
K.step('kora_lib should refuse server distance checks with invalid input', 'server', function(ctx)
    local origin = { x = 0.0, y = 0.0, z = 0.0 }
    serverRefusal(ctx, 'distance_player', 'Source must be a positive integer server ID.', 0, origin, 1.0)
    serverRefusal(ctx, 'distance_coords', 'First set of coordinates must include finite x, y, and z values.', { x = 1 }, origin)
    serverRefusal(ctx, 'distance_coords', 'Distance must be a finite non-negative number.', origin, origin, -1)
    serverRefusal(ctx, 'distance_x', 'Point must include a finite x value.', ctx.tester, { y = 1 })
    serverRefusal(ctx, 'distance_playerNearAny', 'Kora.distance.playerNearAny requires a list.', ctx.tester, 'fft', {})
    serverRefusal(ctx, 'distance_playerNearAny', 'Kora.distance.playerNearAny requires opts.coordsOf.', ctx.tester, {}, {})
    serverRefusal(ctx, 'distance_entity', 'Entity must be a positive integer handle.', ctx.tester, 0)
end)
K.step('kora_lib should refuse closest searches with an invalid source or distance', 'server', function(ctx)
    -- modules/closest/server.lua resolveCoords / resolveDistance.
    serverRefusal(ctx, 'closest_vehicle', 'Closest-search source must be a positive player ID.', 0)
    serverRefusal(ctx, 'closest_object', 'Closest-search distance must be a positive finite number.', ctx.tester, nil, 0)
    serverRefusal(ctx, 'closest_ped', 'Closest-search coordinates must be a finite vector3.', ctx.tester, { x = 1 })
end)

-- ---------------------------------------------------------------------------
-- Coverage expansion (client): the player cache and streaming loaders.
-- The cache refreshes on Config.cache.tickInterval, so reads poll briefly.
-- ---------------------------------------------------------------------------

K.step('the kora_lib player cache should agree with the game about me', 'client', function(ctx)
    ctx:equal(K.export(LIB, 'cache_playerId'), PlayerId(), 'cache_playerId')
    ctx:equal(K.export(LIB, 'cache_serverId'), GetPlayerServerId(PlayerId()), 'cache_serverId')
    ctx:waitUntil(function() return K.export(LIB, 'cache_ped') == PlayerPedId() end, 'cache_ped is not my ped', 3000)
    ctx:waitUntil(function()
        local health = K.export(LIB, 'cache_health')
        return type(health) == 'number' and math.abs(health - GetEntityHealth(PlayerPedId())) <= 5
    end, 'cache_health does not follow my health', 3000)
    ctx:waitUntil(function() return K.export(LIB, 'cache_armour') == GetPedArmour(PlayerPedId()) end,
        'cache_armour does not follow my armour', 3000)
    local coords = K.export(LIB, 'cache_coords')
    assert(type(coords) ~= 'nil', 'cache_coords is empty')
    local here = GetEntityCoords(PlayerPedId())
    assert(#(vector3(coords.x, coords.y, coords.z) - here) < 25.0, 'cache_coords is far from my position')
    ctx:equal(K.export(LIB, 'cache_isDead'), false, 'cache_isDead')
    ctx:waitUntil(function() return K.export(LIB, 'cache_weapon') == GetSelectedPedWeapon(PlayerPedId()) end,
        'cache_weapon does not follow my selected weapon', 3000)
end)
K.step('the kora_lib player cache should show me on foot', 'client', function(ctx)
    ctx:waitUntil(function() return K.export(LIB, 'cache_vehicle') == false end, 'cache_vehicle is not false on foot', 3000)
    ctx:equal(K.export(LIB, 'cache_seat'), false, 'cache_seat on foot')
end)
K.step('the kora_lib player cache should show me in the driver seat of my vehicle', 'client', function(ctx)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    assert(vehicle ~= 0, 'I am not in a vehicle')
    ctx:waitUntil(function() return K.export(LIB, 'cache_vehicle') == vehicle end, 'cache_vehicle is not my vehicle', 3000)
    ctx:waitUntil(function() return K.export(LIB, 'cache_seat') == -1 end, 'cache_seat is not the driver seat', 3000)
end)
-- Custom keys: set, get and onChange (modules/cache/client.lua:140-212).
K.step('a custom kora_lib cache key should store values and report changes', 'client', function(ctx)
    local key = 'fft:kora_lib:cache'
    local heard = {}
    ctx:cleanup(function()
        pcall(function() exports[LIB]:cache_offChange(key) end)
        pcall(function() exports[LIB]:cache_set(key, nil) end)
    end)
    K.export(LIB, 'cache_onChange', key, function(value) heard[#heard + 1] = value end)
    K.export(LIB, 'cache_set', key, 'fft-one')
    ctx:equal(K.export(LIB, 'cache_get', key), 'fft-one', 'cache_get after set')
    K.export(LIB, 'cache_set', key, 'fft-two')
    ctx:waitUntil(function() return heard[#heard] == 'fft-two' end, 'onChange did not report the second value', 2000)
    local count = #heard
    K.export(LIB, 'cache_set', key, 'fft-two')
    Wait(300)
    ctx:equal(#heard, count, 'onChange fired for an unchanged value')
    K.export(LIB, 'cache_offChange', key)
    K.export(LIB, 'cache_set', key, 'fft-three')
    Wait(300)
    ctx:equal(#heard, count, 'onChange fired after offChange')
    ctx:equal(K.export(LIB, 'cache_get', key), 'fft-three', 'cache_get after offChange')
end)
K.step('setting the reserved kora_lib cache key {string} should be ignored', 'client', function(ctx, key)
    local before = K.export(LIB, 'cache_get', key)
    K.export(LIB, 'cache_set', key, 'fft-not-allowed')
    ctx:equal(K.export(LIB, 'cache_get', key) ~= 'fft-not-allowed', true, 'Reserved key ' .. key .. ' was overwritten')
    ctx:equal(type(K.export(LIB, 'cache_get', key)), type(before), 'Reserved key ' .. key .. ' type')
end)
K.step('kora_lib should refuse cache keys that are empty or too long', 'client', function(ctx)
    refusedSync('cache_get', 'Cache key must be a non-empty string up to 256 bytes.', '')
    refusedSync('cache_set', 'Cache key must be a non-empty string up to 256 bytes.', ('k'):rep(257), true)
    refusedSync('cache_onChange', 'onChange handler must be a function.', 'fft:kora_lib:cache', 'fft-not-a-function')
end)

-- Kora.stream loaders (modules/stream/client.lua): a loaded asset is
-- returned by name or hash; invalid names are refused before any request.
K.step('kora_lib should stream the model {string} and the anim dict {string}', 'client', function(ctx, model, dict)
    local hash = K.export(LIB, 'stream_loadModel', model, nil, { timeout = 10000 })
    ctx:equal(hash, GetHashKey(model), 'stream_loadModel result')
    ctx:equal(HasModelLoaded(hash), true, 'Model loaded')
    SetModelAsNoLongerNeeded(hash)
    ctx:equal(K.export(LIB, 'stream_loadAnimDict', dict, nil, { timeout = 10000 }), dict, 'stream_loadAnimDict result')
    RemoveAnimDict(dict)
end)
K.step('kora_lib should release a streamed model after its callback runs', 'client', function(ctx)
    local seen
    local hash = K.export(LIB, 'stream_loadModel', 'prop_cs_cardbox_01', function(value) seen = value end, { timeout = 10000 })
    ctx:equal(seen, hash, 'Callback received the model hash')
end)
K.step('kora_lib should refuse to stream unknown or malformed assets', 'client', function(ctx)
    refusedSync('stream_loadModel', 'Invalid model', 'fft_never_a_model_name')
    refusedSync('stream_loadModel', 'Invalid model', '')
    refusedSync('stream_loadAnimDict', 'Anim dict does not exist: fft_never_a_dict', 'fft_never_a_dict')
    refusedSync('stream_loadAnimDict', 'Kora.stream callback must be callable.', 'mp_common', 'fft-not-a-function')
    refusedSync('stream_loadModel', 'Kora.stream timeout must be a non-negative integer.', 'adder', nil, { timeout = -1 })
end)

-- ---------------------------------------------------------------------------
-- Coverage expansion (client): owned blips, vehicle getters and the keybind
-- registry (read only: adding a key mapping persists in the player's FiveM
-- settings, so it is not exercised).
-- ---------------------------------------------------------------------------

-- Kora.blips create/getRegistered/hide/show/remove (modules/blips/client.lua:464-720).
K.step('kora_lib should create, track, hide, show and remove a blip owned by fft', 'client', function(ctx)
    local at = GetEntityCoords(PlayerPedId())
    local blip = K.export(LIB, 'blips_create', { x = at.x, y = at.y, z = at.z }, { label = 'FFT blip probe', sprite = 1 })
    assert(type(blip) == 'number' and blip ~= 0, 'blips_create returned no handle')
    ctx:cleanup(function() pcall(function() exports[LIB]:blips_remove(blip) end) end)
    ctx:equal(DoesBlipExist(blip), true, 'Native blip exists')
    local tracked
    for _, record in ipairs(K.export(LIB, 'blips_getRegistered') or {}) do
        if record.handle == blip then tracked = record end
    end
    assert(tracked, 'blips_getRegistered does not list the new blip')
    ctx:equal(tracked.resource, 'fft', 'Blip owner')
    ctx:equal(K.export(LIB, 'blips_hide', blip), true, 'blips_hide')
    ctx:equal(K.export(LIB, 'blips_show', blip), true, 'blips_show')
    ctx:equal(K.export(LIB, 'blips_remove', blip), true, 'blips_remove')
    ctx:equal(DoesBlipExist(blip), false, 'Native blip after remove')
    local again = K.export(LIB, 'blips_remove', blip)
    ctx:equal(again, false, 'Second blips_remove')
end)
K.step('kora_lib should refuse blips without coordinates or handles', 'client', function(ctx)
    refusedSync('blips_create', 'Invalid coords: expected a vector3/vector4 or {x, y, z} table.', { x = 1 }, {})
    refusedSync('blips_create', 'Blip options must be a table.', { x = 1.0, y = 1.0, z = 1.0 }, 'fft')
    refusedSync('blips_hide', 'Invalid blip: fft', 'fft')
    local ok = K.export(LIB, 'blips_hide', 2147480000)
    ctx:equal(ok, false, 'blips_hide of an untracked handle')
end)

-- Kora.vehicle getters (modules/vehicle/client.lua:162-192).
K.step('kora_lib vehicle getters should describe the {string} I am driving', 'client', function(ctx, model)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    assert(vehicle ~= 0, 'I am not in a vehicle')
    ctx:equal(K.export(LIB, 'vehicle_isDriver', vehicle), true, 'vehicle_isDriver')
    ctx:equal(K.export(LIB, 'vehicle_model', vehicle), GetHashKey(model), 'vehicle_model')
    local plate = K.export(LIB, 'vehicle_plate', vehicle)
    ctx:equal(plate, (GetVehicleNumberPlateText(vehicle):gsub('^%s+', ''):gsub('%s+$', '')), 'vehicle_plate')
    local label = K.export(LIB, 'vehicle_label', vehicle)
    assert(type(label) == 'string' and label ~= '', 'vehicle_label returned ' .. tostring(label))
    local props = K.export(LIB, 'vehicle_getProperties', vehicle)
    assert(type(props) == 'table', 'vehicle_getProperties returned no table')
    ctx:equal(props.model, GetHashKey(model), 'Property model')
end)
K.step('kora_lib vehicle getters should reject something that is not a vehicle', 'client', function(ctx)
    for _, value in ipairs({ PlayerPedId(), 0 }) do
        ctx:equal(K.export(LIB, 'vehicle_isDriver', value), false, 'vehicle_isDriver(' .. tostring(value) .. ')')
        ctx:equal(K.export(LIB, 'vehicle_model', value), false, 'vehicle_model(' .. tostring(value) .. ')')
        ctx:equal(K.export(LIB, 'vehicle_plate', value), false, 'vehicle_plate(' .. tostring(value) .. ')')
    end
end)

-- Kora.keybind list/remove (modules/keybind/client.lua:184-205).
K.step('kora_lib should list key bindings sorted by name and refuse to remove one fft does not own', 'client', function(ctx)
    local bindings = K.export(LIB, 'keybind_list')
    assert(type(bindings) == 'table', 'keybind_list returned no list')
    for index = 2, #bindings do
        assert(bindings[index - 1].name <= bindings[index].name, 'keybind_list is not sorted by name')
    end
    for _, binding in ipairs(bindings) do
        if binding.resource ~= 'fft' then
            ctx:equal(K.export(LIB, 'keybind_remove', binding.name), false, 'keybind_remove of ' .. binding.name)
            break
        end
    end
    ctx:equal(K.export(LIB, 'keybind_remove', 'fft_never_a_binding'), false, 'keybind_remove of an unknown binding')
end)

-- ---------------------------------------------------------------------------
-- Coverage expansion (server): command registry reads, chat suggestions,
-- logging statistics and the QA run-state guard.
-- ---------------------------------------------------------------------------

K.step('kora_lib should list its registered commands sorted by name', 'server', function(ctx)
    local list = K.export(LIB, 'commands_list')
    assert(type(list) == 'table', 'commands_list returned no list')
    for index, entry in ipairs(list) do
        assert(type(entry.name) == 'string' and entry.name ~= '', ('Command %d has no name'):format(index))
        if index > 1 then assert(list[index - 1].name <= entry.name, 'commands_list is not sorted by name') end
    end
end)
K.step('kora_lib should suggest nothing for unknown or malformed command lookups', 'server', function(ctx)
    local function none(value, label) ctx:equal(type(value) == 'table' and #value or -1, 0, label) end
    none(K.export(LIB, 'commands_suggest', ctx.tester, 'fft_never_a_command', 1, ''), 'Suggestions for an unknown command')
    none(K.export(LIB, 'commands_suggest', ctx.tester, 'fft_never_a_command', 0, ''), 'Suggestions for argument 0')
    none(K.export(LIB, 'commands_suggest', 0, 'fft_never_a_command', 1, ''), 'Suggestions for player 0')
    none(K.export(LIB, 'commands_suggest', ctx.tester, 42, 1, ''), 'Suggestions for a numeric name')
end)
K.step('kora_lib logging statistics should be well formed', 'server', function(ctx)
    local stats = K.export(LIB, 'logging_getStats')
    assert(type(stats) == 'table', 'logging_getStats returned no table')
    ctx:equal(type(stats.counts), 'table', 'Statistics counts')
    ctx:equal(type(stats.ringSize), 'number', 'Statistics ring size')
    ctx:equal(type(K.export(LIB, 'logging_isEnabled', 'error')), 'boolean', 'logging_isEnabled(error)')
end)
K.step('kora_lib should refuse to let fft change the QA run state', 'server', function(ctx)
    local before = K.export(LIB, 'qa_active', ctx.tester)
    serverRefusal(ctx, 'qa_setActive', 'Only kora_qa may change the QA run state.', ctx.tester, true)
    ctx:equal(K.export(LIB, 'qa_active', ctx.tester), before, 'QA run state after the refusal')
end)
