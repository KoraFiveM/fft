-- kora_hud: client-only status HUD with its own NUI page (React).
-- The hook only observes; the page's callbacks (kora_hud:ready,
-- kora_hud:finishLayout) are driven from here with K.nui.
-- Needs kora_hud/fft_hooks.lua: every outgoing message goes through the raw
-- SendNUIMessage native from file-local code, so the hook wraps the global and
-- keeps a log. All HUD assertions here are Lua -> NUI PAYLOAD assertions; they
-- do not prove what the page renders. kora_hud has no server realm, so the
-- only authoritative checks are the kora_core values the payloads mirror.
local K = FFT.kora
if not K then return end
K.feature('kora_hud')

local HUD = 'kora_hud'

local function hudState()
    local state = K.hook(HUD, 'state')
    assert(type(state) == 'table', 'kora_hud FFT hook returned no state (is fft_kora_hooks true and kora_hud restarted?)')
    return state
end

-- Moves the "since" cursor to now. Every acting step of this file calls it, so
-- an assertion only sees messages its own When produced.
local function mark(ctx)
    local state = hudState()
    assert(state.wrapped, 'kora_hud FFT hook could not wrap SendNUIMessage; a send seam is needed in client/hud.lua')
    ctx.state.hudSeq = state.sequence
    -- Same cursor for the local events recorded by listen() further down.
    ctx.state.hudEventMark = {}
    for name, list in pairs(ctx.state.hudEvents or {}) do ctx.state.hudEventMark[name] = #list end
    return state
end

local function since(ctx)
    return assert(ctx.state.hudSeq, 'Start watching the HUD page messages first')
end

local function messages(ctx, action)
    local list = K.hook(HUD, 'log', since(ctx), action)
    assert(type(list) == 'table', 'kora_hud FFT hook returned no log')
    return list
end

---Waits for a message of `action` since the cursor whose data satisfies `test`.
local function waitMessage(ctx, action, test, what, timeout)
    return ctx:waitUntil(function()
        for _, entry in ipairs(messages(ctx, action)) do
            if not test or test(entry.data) then return entry end
        end
    end, ('The HUD page was not sent %s%s'):format(action, what and (' with ' .. what) or ''), timeout or 8000)
end

-- The page's own callbacks (RegisterNUICallback in kora_hud/client/hud.lua) are
-- run with a real fetch through K.nui, with the bodies web/src/lib/hudState.tsx
-- posts. Both answer `{}`; K.nui raises when a callback is not answered.
local function nui(name, body) K.nui(HUD, name, body or {}) end

-- Cleanup-safe cancel: kora_hud:finishLayout answers and then does nothing when
-- the editor is already closed (client/hud.lua `if not layoutEditing then return end`).
local function cancelEditor()
    pcall(K.nui, HUD, 'kora_hud:finishLayout', { confirmed = false }, 2000)
end

local function visible() return K.export(HUD, 'isVisible') == true end

local function near(a, b) return type(a) == 'number' and math.abs(a - b) < 0.0005 end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b or (type(a) == 'number' and near(a, b)) end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

-- ---------------------------------------------------------------------------
-- Observation
-- ---------------------------------------------------------------------------

K.step('I start watching the HUD page messages', 'client', function(ctx) mark(ctx) end)

K.step('the HUD should be visible', 'client', function(ctx)
    ctx:waitUntil(visible, 'exports.kora_hud:isVisible() is false', 5000)
end)
K.step('the HUD should be hidden', 'client', function(ctx)
    ctx:waitUntil(function() return not visible() end, 'exports.kora_hud:isVisible() is still true', 5000)
end)

K.step('the HUD page should receive {string}', 'client', function(ctx, action) waitMessage(ctx, action) end)
K.step('the HUD page should not receive {string} within {int} milliseconds', 'client', function(ctx, action, duration)
    assert(duration >= 0 and duration <= 10000, 'Quiet period is limited to 10 seconds')
    local deadline = GetGameTimer() + duration
    while GetGameTimer() < deadline do ctx:check() Wait(100) end
    local list = messages(ctx, action)
    assert(#list == 0, ('The HUD page was sent %s %d times'):format(action, #list))
end)

K.step('the HUD page should be told it is shown', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:visibility', function(data) return data == true end, 'true')
end)
K.step('the HUD page should be told it is not shown', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:visibility', function(data) return data == false end, 'false')
end)

-- ---------------------------------------------------------------------------
-- Visibility exports (hide is paired with show in cleanup)
-- ---------------------------------------------------------------------------

K.step('I force the HUD hidden through its export', 'client', function(ctx)
    assert(visible(), 'The HUD is not visible, so something else is already hiding it')
    mark(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_hud:show() end) end)
    K.export(HUD, 'hide')
end)
K.step('I release the forced HUD hide through its export', 'client', function(ctx)
    mark(ctx)
    K.export(HUD, 'show')
end)

-- ---------------------------------------------------------------------------
-- Page handshake and payloads
-- ---------------------------------------------------------------------------

-- kora_hud:ready is the page's mount ping; client/hud.lua answers with a full,
-- unthrottled push (sendInitialState).
K.step('the HUD page asks for its initial state', 'client', function(ctx)
    mark(ctx)
    nui('kora_hud:ready')
end)
K.step('the HUD page should receive its full initial state', 'client', function(ctx)
    for _, action in ipairs({ 'kora_hud:config', 'kora_hud:visibility', 'kora_hud:compat', 'kora_hud:vitals', 'kora_hud:update' }) do
        waitMessage(ctx, action)
    end
end)
K.step('the HUD configuration payload should carry the layout command {string}', 'client', function(ctx, command)
    local entry = waitMessage(ctx, 'kora_hud:config')
    local layout = type(entry.data) == 'table' and entry.data.layout or nil
    assert(type(layout) == 'table', 'kora_hud:config carries no layout block')
    ctx:equal(layout.command, command, 'Layout command')
    local unit = entry.data.speedUnit
    assert(unit == 'mph' or unit == 'kmh', 'kora_hud:config speedUnit is ' .. tostring(unit))
end)

local PLAYER_FIELDS = { cash = true, bank = true, hunger = true, thirst = true, stress = true }
K.step('the HUD player payload should show {string} as {int}', 'client', function(ctx, field, value)
    assert(PLAYER_FIELDS[field], 'Unknown kora_hud:update field: ' .. field)
    waitMessage(ctx, 'kora_hud:update', function(data)
        return type(data) == 'table' and tonumber(data[field]) == value
    end, ('%s = %d'):format(field, value))
end)
K.step('the HUD player payload should name my job {string}', 'client', function(ctx, name)
    waitMessage(ctx, 'kora_hud:update', function(data)
        return type(data) == 'table' and type(data.job) == 'table' and data.job.name == name
    end, 'job ' .. name)
end)

K.step('my ped armour is {int} for the HUD', 'client', function(ctx, amount)
    assert(amount >= 0 and amount <= 100, 'Armour must be 0-100')
    local before = GetPedArmour(PlayerPedId())
    assert(before ~= amount, 'Armour is already ' .. amount .. '; pick another value')
    mark(ctx)
    ctx:cleanup(function() SetPedArmour(PlayerPedId(), before) end)
    SetPedArmour(PlayerPedId(), amount)
end)
K.step('the HUD vitals payload should show armour {int}', 'client', function(ctx, amount)
    waitMessage(ctx, 'kora_hud:vitals', function(data)
        return type(data) == 'table' and data.armour == amount
    end, 'armour ' .. amount)
end)

K.step('the HUD vehicle payload should describe the vehicle I am in', 'client', function(ctx)
    local entry = waitMessage(ctx, 'kora_hud:vehicle', function(data) return type(data) == 'table' end, 'telemetry')
    local data = entry.data
    assert(type(data.speed) == 'number', 'kora_hud:vehicle speed is ' .. tostring(data.speed))
    assert(data.speedUnit == 'mph' or data.speedUnit == 'kmh', 'kora_hud:vehicle speedUnit is ' .. tostring(data.speedUnit))
    assert(data.fuelKind == 'fuel' or data.fuelKind == 'charge', 'kora_hud:vehicle fuelKind is ' .. tostring(data.fuelKind))
    assert(type(data.engineOn) == 'boolean', 'kora_hud:vehicle engineOn is not a boolean')
    assert(type(data.seatbelt) == 'boolean', 'kora_hud:vehicle seatbelt is not a boolean')
end)

-- ---------------------------------------------------------------------------
-- qb-hud compatibility event (display-only overlay, client/compat.lua)
-- ---------------------------------------------------------------------------

K.step('the HUD receives the legacy stress event with {int}', 'client', function(ctx, value)
    assert(value >= 0 and value <= 100, 'Stress must be 0-100')
    -- Learn what the HUD shows now so the overlay can be put back afterwards.
    mark(ctx)
    nui('kora_hud:ready')
    local current = waitMessage(ctx, 'kora_hud:update', function(data) return type(data) == 'table' end)
    local before = tonumber(current.data.stress) or 0
    assert(before ~= value, 'The HUD already shows stress ' .. value .. '; pick another value')
    ctx:cleanup(function() TriggerEvent('hud:client:UpdateStress', before) end)
    Wait(300) -- let the player channel's rate limit lapse so the push is a fresh one
    mark(ctx)
    TriggerEvent('hud:client:UpdateStress', value)
end)

K.step('I remember my server-side stress', 'server', function(ctx)
    ctx.state.hudStress = tonumber(exports.kora_core:getMetaData(ctx.tester, 'stress')) or 0
end)
K.step('my server-side stress should be unchanged by the HUD', 'server', function(ctx)
    local before = assert(ctx.state.hudStress, 'Remember the server-side stress first')
    Wait(500)
    ctx:equal(tonumber(exports.kora_core:getMetaData(ctx.tester, 'stress')) or 0, before, 'Server-side stress')
end)

-- ---------------------------------------------------------------------------
-- /id (session-only toggle; restored to its starting state in cleanup)
-- ---------------------------------------------------------------------------

K.step('I toggle the HUD player id display', 'client', function(ctx)
    mark(ctx)
    ctx.state.hudIdToggles = ctx.state.hudIdToggles or {}
    local toggles = ctx.state.hudIdToggles
    if #toggles == 0 then
        -- An odd number of toggles would leave the display flipped.
        ctx:cleanup(function() if #toggles % 2 == 1 then ExecuteCommand('id') end end)
    end
    ExecuteCommand('id')
    local entry = waitMessage(ctx, 'kora_hud:playerId')
    toggles[#toggles + 1] = { shown = entry.data }
end)
K.step('the HUD player id toggles should alternate between my server id and cleared', 'client', function(ctx)
    local toggles = ctx.state.hudIdToggles or {}
    assert(#toggles >= 2, 'Toggle the HUD player id display at least twice')
    local id = GetPlayerServerId(PlayerId())
    for index = 1, #toggles - 1 do
        local first, second = toggles[index].shown, toggles[index + 1].shown
        assert((first == id and second == nil) or (first == nil and second == id),
            ('Toggles %d and %d sent %s then %s; expected server id %d and a clear'):format(index, index + 1,
                tostring(first), tostring(second), id))
    end
end)

-- ---------------------------------------------------------------------------
-- Layout editor (/hudlayout). The layout is a client KVP on the tester's own
-- machine; the snapshot taken on open is written back through the same
-- kora_hud:finishLayout callback in cleanup.
-- ---------------------------------------------------------------------------

-- LAYOUT_BOUNDS keys in client/hud.lua: writeLayout never carries these over
-- from the stored layout, so a save must send them explicitly.
local LAYOUT_SECTIONS = { gauges = true, vehicle = true, identity = true, status = true, chatInput = true }

-- Only sections the HUD knows right now are sent back. Entries of resources
-- that are not running are left to writeLayout's own carry-over, which keeps
-- their position, scale, visibility and settings; sending them as offsets
-- would make writeLayout drop their settings (it only cleans settings for a
-- registered definition). hidden.minimap is never sent: a boolean there is
-- the player's minimap choice (minimapHooks.setHidden), not a layout field.
local function layoutPayload(layout)
    local known = {}
    local function keep(id)
        if known[id] == nil then
            known[id] = LAYOUT_SECTIONS[id] == true or (type(id) == 'string' and K.export(HUD, 'getUiLayout', id) ~= nil)
        end
        return known[id]
    end
    local function pick(map, skipMinimap)
        local out = {}
        for id, value in pairs(type(map) == 'table' and map or {}) do
            if keep(id) and not (skipMinimap and id == 'minimap') then out[id] = value end
        end
        return out
    end
    return {
        confirmed = true,
        offsets = pick(layout.offsets),
        scales = pick(layout.scales),
        justifications = pick(layout.justifications),
        hidden = pick(layout.hidden, true),
        settings = pick(layout.settings),
        gaugesBottomAnchored = layout.gaugesBottomAnchored,
        minimapVehicleOnly = layout.minimapVehicleOnly,
    }
end

-- Local events kora_hud raises for other resources, recorded per scenario
-- (ctx:on removes the handlers afterwards). mark() moves their cursor too.
--   kora_hud:ui:apply(owner, id, layout, reason)   client/hud.lua emit()
--   kora_hud:ui:editing(open)                      client/hud.lua openLayoutEditor/closeLayout
--   kora_chat:setInputLayout({ x, y, scale })      client/hud.lua syncChatInputLayout
local OWNER = GetCurrentResourceName()

local function listen(ctx)
    if ctx.state.hudEvents then return end
    local events = { apply = {}, editing = {}, chat = {} }
    ctx.state.hudEvents = events
    ctx.state.hudEventMark = ctx.state.hudEventMark or {}
    ctx:on('kora_hud:ui:apply', function(owner, id, layout, reason)
        if owner == OWNER and #events.apply < 100 then
            events.apply[#events.apply + 1] = { id = id, layout = layout, reason = reason }
        end
    end)
    ctx:on('kora_hud:ui:editing', function(open)
        if #events.editing < 100 then events.editing[#events.editing + 1] = open end
    end)
    ctx:on('kora_chat:setInputLayout', function(layout)
        if #events.chat < 100 then events.chat[#events.chat + 1] = layout end
    end)
end

---Events of `name` recorded since the last mark().
local function recorded(ctx, name)
    local list = assert(ctx.state.hudEvents, 'kora_hud events are not being recorded in this scenario')[name]
    local from = (ctx.state.hudEventMark or {})[name] or 0
    local out = {}
    for index = from + 1, #list do out[#out + 1] = list[index] end
    return out
end

---True when every field of `expected` is present in `actual` with the same value.
local function subset(expected, actual)
    if type(expected) ~= 'table' then
        if type(expected) == 'number' then return near(actual, expected) end
        return expected == actual
    end
    if type(actual) ~= 'table' then return false end
    for key, value in pairs(expected) do
        if not subset(value, actual[key]) then return false end
    end
    return true
end

local function describe(value)
    local ok, text = pcall(json.encode, value)
    return ok and text or tostring(value)
end

local EDITOR_COMMANDS = {
    hudlayout = true,   -- Config.layout.command
    ui = true,          -- Config.uiEditor.command
    hudsettings = true, -- Config.uiEditor.aliases
}

local function editorOpen(ctx, command)
    mark(ctx)
    ExecuteCommand(command or 'hudlayout')
    waitMessage(ctx, 'kora_hud:layoutMode', function(data) return data == true end, 'true', 3000)
end

local function openEditor(ctx, command)
    assert(EDITOR_COMMANDS[command], 'Not a kora_hud editor command: ' .. tostring(command))
    assert(visible(), 'The HUD is hidden; the layout editor only opens while it is visible')
    listen(ctx)
    local snapshot = K.export(HUD, 'getLayout')
    assert(type(snapshot) == 'table' and type(snapshot.offsets) == 'table', 'exports.kora_hud:getLayout() returned no layout')
    ctx.state.hudLayout = snapshot
    -- Ignored by client/hud.lua when the editor is already closed; releases NUI focus otherwise.
    ctx:cleanup(cancelEditor)
    -- /hudlayout is ignored while an editor is open (openLayoutEditor in
    -- client/hud.lua), so an editor left behind by an earlier failure is
    -- cancelled first. Cancel never writes the layout.
    nui('kora_hud:finishLayout', { confirmed = false })
    editorOpen(ctx, command)
end

K.step('I open the HUD layout editor', 'client', function(ctx) openEditor(ctx, 'hudlayout') end)
K.step('I open the HUD layout editor with the command {string}', 'client', function(ctx, command)
    openEditor(ctx, command)
end)
K.step('the HUD layout editor should be open', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:layoutMode', function(data) return data == true end, 'true')
    assert(hudState().focused, 'The layout editor did not take NUI focus')
end)
K.step('the HUD layout editor should be closed', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:layoutMode', function(data) return data == false end, 'false')
end)
K.step('the HUD layout editor should have released the cursor', 'client', function(ctx)
    ctx:waitUntil(function() return not hudState().focused end, 'NUI focus is still held after the editor closed', 3000)
end)
K.step('I cancel the HUD layout editor', 'client', function(ctx)
    mark(ctx)
    nui('kora_hud:finishLayout', { confirmed = false })
end)

-- Runs the editor command and records whatever happens. openLayoutEditor
-- returns without a message when the HUD is hidden or an editor is already open.
K.step('I try to open the HUD layout editor', 'client', function(ctx)
    ctx:cleanup(cancelEditor)
    mark(ctx)
    ExecuteCommand('hudlayout')
end)

-- The snapshot restore: reopen the editor if needed and save the snapshot
-- through the normal callback. Registered once, at the first save, so it runs
-- before the cancel cleanups (reverse order) and before an fft element
-- registered earlier is unregistered (a restore while it is registered drops
-- its saved entry, see writeLayout's carry-over).
local function ensureRestore(ctx)
    local snapshot = assert(ctx.state.hudLayout, 'Open the HUD layout editor first')
    if ctx.state.hudLayoutRestore then return end
    ctx.state.hudLayoutRestore = true
    ctx:cleanup(function()
        ExecuteCommand('hudlayout')
        Wait(100)
        pcall(K.nui, HUD, 'kora_hud:finishLayout', layoutPayload(snapshot), 2000)
    end)
end

-- Sections a scenario may write. Anything else would stay in the tester's
-- layout KVP for good: writeLayout carries unknown ids over on every save.
local function assertSavable(ctx, id)
    local owned = ctx.state.hudOwned or {}
    assert(LAYOUT_SECTIONS[id] or owned[id],
        ('Refusing to save "%s": only built-in sections, chatInput and elements this scenario registered are written'):format(tostring(id)))
end

local function saveLayout(ctx, mutate)
    ensureRestore(ctx)
    local payload = layoutPayload(K.export(HUD, 'getLayout'))
    mutate(payload)
    mark(ctx)
    nui('kora_hud:finishLayout', payload)
end

K.step('I save the HUD layout with the {string} section moved to {float} {float}', 'client', function(ctx, section, x, y)
    assertSavable(ctx, section)
    saveLayout(ctx, function(payload) payload.offsets[section] = { x = x, y = y } end)
end)
K.step('I save the HUD layout with the {string} section scaled to {float}', 'client', function(ctx, section, scale)
    assertSavable(ctx, section)
    saveLayout(ctx, function(payload) payload.scales[section] = scale end)
end)
K.step('I save the HUD layout with the {string} section justified {string}', 'client', function(ctx, section, value)
    assertSavable(ctx, section)
    saveLayout(ctx, function(payload) payload.justifications[section] = value end)
end)
K.step('I save the HUD layout with the {string} section hidden', 'client', function(ctx, section)
    assertSavable(ctx, section)
    saveLayout(ctx, function(payload) payload.hidden[section] = true end)
end)
K.step('I save the HUD layout with the gauges no longer bottom anchored', 'client', function(ctx)
    saveLayout(ctx, function(payload) payload.gaugesBottomAnchored = false end)
end)
K.step('I save the HUD layout with minimap only in vehicle switched', 'client', function(ctx)
    local current = K.export(HUD, 'getLayout').minimapVehicleOnly
    assert(type(current) == 'boolean', 'getLayout().minimapVehicleOnly is not a boolean')
    ctx.state.hudVehicleOnly = not current
    saveLayout(ctx, function(payload) payload.minimapVehicleOnly = not current end)
end)
-- Everything about the section is left out so only the offset could create its entry.
K.step('I save the HUD layout with a non-numeric offset for {string}', 'client', function(ctx, section)
    assertSavable(ctx, section)
    assert(section ~= 'gauges', 'gauges also gets an entry from gaugesBottomAnchored; use another section')
    saveLayout(ctx, function(payload)
        payload.offsets[section] = { x = 'left', y = 'up' }
        payload.scales[section], payload.justifications[section] = nil, nil
        payload.hidden[section], payload.settings[section] = nil, nil
    end)
end)
-- A confirmed save with nothing in it, as the page posts after the player
-- reset every element. Entries of resources that are not running are kept
-- by writeLayout's carry-over.
K.step('I save an empty HUD layout', 'client', function(ctx)
    saveLayout(ctx, function(payload)
        for _, key in ipairs({ 'offsets', 'scales', 'justifications', 'hidden', 'settings' }) do payload[key] = {} end
        payload.gaugesBottomAnchored = true
    end)
end)
-- JSON doc string: { "offsets": { id: {x, y} }, "scales": { id: n }, "hidden": { id: bool },
-- "settings": { id: { key: value } }, "justifications": { id: "left" } } merged into the current layout.
K.step('I save the HUD layout with these changes:', 'client', function(ctx, argument)
    local changes = K.json(argument)
    local keys = { 'offsets', 'scales', 'justifications', 'hidden', 'settings' }
    for _, key in ipairs(keys) do
        for id in pairs(type(changes[key]) == 'table' and changes[key] or {}) do assertSavable(ctx, id) end
    end
    saveLayout(ctx, function(payload)
        for _, key in ipairs(keys) do
            for id, value in pairs(type(changes[key]) == 'table' and changes[key] or {}) do payload[key][id] = value end
        end
    end)
end)

-- kora_hud:finishLayout answers and returns at once when no editor is open
-- (client/hud.lua `if not layoutEditing then return end`).
K.step('the HUD page finishes the layout while the editor is closed', 'client', function(ctx)
    local snapshot = K.export(HUD, 'getLayout')
    ctx.state.hudLayout = snapshot
    -- Only acts if the save went through after all.
    ctx:cleanup(function()
        local now = K.export(HUD, 'getLayout')
        local offset = type(now) == 'table' and (now.offsets or {}).gauges or nil
        if type(offset) == 'table' and near(offset.x, 0.31) and near(offset.y, -0.31) then
            ExecuteCommand('hudlayout')
            Wait(100)
            pcall(K.nui, HUD, 'kora_hud:finishLayout', layoutPayload(snapshot), 2000)
        end
    end)
    local payload = layoutPayload(snapshot)
    payload.offsets.gauges = { x = 0.31, y = -0.31 }
    mark(ctx)
    nui('kora_hud:finishLayout', payload)
end)

local function savedLayout() return K.export(HUD, 'getLayout') end

K.step('the saved HUD layout should place {string} at {float} {float}', 'client', function(ctx, section, x, y)
    ctx:waitUntil(function()
        local offset = (savedLayout().offsets or {})[section]
        return type(offset) == 'table' and near(offset.x, x) and near(offset.y, y)
    end, ('Saved layout does not place %s at %s, %s'):format(section, x, y), 3000)
end)
K.step('the saved HUD layout should have no offset for {string}', 'client', function(ctx, section)
    ctx:waitUntil(function() return (savedLayout().offsets or {})[section] == nil end,
        ('Saved layout still has an offset for %s: %s'):format(section, describe((savedLayout().offsets or {})[section])), 3000)
end)
K.step('the saved HUD layout should scale {string} to {float}', 'client', function(ctx, section, scale)
    ctx:waitUntil(function() return near((savedLayout().scales or {})[section], scale) end,
        ('Saved layout scales %s to %s, expected %s'):format(section, tostring((savedLayout().scales or {})[section]), scale), 3000)
end)
K.step('the saved HUD layout should justify {string} to the {string}', 'client', function(ctx, section, value)
    ctx:waitUntil(function() return (savedLayout().justifications or {})[section] == value end,
        ('Saved layout justifies %s %s, expected %s'):format(section, tostring((savedLayout().justifications or {})[section]), value), 3000)
end)
K.step('the saved HUD layout should have no justification for {string}', 'client', function(ctx, section)
    Wait(300)
    local value = (savedLayout().justifications or {})[section]
    assert(value == nil, ('Saved layout justifies %s %s'):format(section, tostring(value)))
end)
K.step('the saved HUD layout should hide {string}', 'client', function(ctx, section)
    ctx:waitUntil(function() return (savedLayout().hidden or {})[section] == true end, 'Saved layout does not hide ' .. section, 3000)
end)
K.step('the saved HUD layout should not anchor the gauges to the bottom', 'client', function(ctx)
    ctx:waitUntil(function() return savedLayout().gaugesBottomAnchored == false end, 'getLayout().gaugesBottomAnchored is still true', 3000)
end)
K.step('the saved HUD layout should have minimap only in vehicle switched', 'client', function(ctx)
    local expected = ctx.state.hudVehicleOnly
    assert(expected ~= nil, 'Switch minimap only in vehicle first')
    ctx:waitUntil(function() return savedLayout().minimapVehicleOnly == expected end,
        'getLayout().minimapVehicleOnly is ' .. tostring(savedLayout().minimapVehicleOnly), 3000)
end)
K.step('the saved HUD layout should be what it was before the editor opened', 'client', function(ctx)
    local snapshot = assert(ctx.state.hudLayout, 'Open the HUD layout editor first')
    Wait(200)
    local now = K.export(HUD, 'getLayout')
    for _, key in ipairs({ 'offsets', 'scales', 'justifications', 'hidden' }) do
        assert(same(snapshot[key] or {}, now[key] or {}), 'Saved HUD layout changed: ' .. key)
    end
end)

K.step('the HUD should announce that the layout editor is open', 'client', function(ctx)
    ctx:waitUntil(function()
        for _, open in ipairs(recorded(ctx, 'editing')) do if open == true then return true end end
    end, 'kora_hud:ui:editing(true) was not raised', 3000)
end)
K.step('the HUD should announce that the layout editor is closed', 'client', function(ctx)
    ctx:waitUntil(function()
        for _, open in ipairs(recorded(ctx, 'editing')) do if open == false then return true end end
    end, 'kora_hud:ui:editing(false) was not raised', 3000)
end)

-- syncChatInputLayout only fires while kora_chat is started.
K.step('the chat composer should be told to move to {float} {float}', 'client', function(ctx, x, y)
    ctx:waitUntil(function()
        for _, layout in ipairs(recorded(ctx, 'chat')) do
            if type(layout) == 'table' and near(layout.x, x) and near(layout.y, y) then return true end
        end
    end, ('kora_chat:setInputLayout was not raised with %s, %s'):format(x, y), 3000)
end)

K.step('the HUD configuration payload should match my saved layout', 'client', function(ctx)
    local entry = waitMessage(ctx, 'kora_hud:config', function(data) return type(data) == 'table' end)
    local config, saved = entry.data, savedLayout()
    local layout = assert(type(config.layout) == 'table' and config.layout, 'kora_hud:config carries no layout block')
    for _, key in ipairs({ 'offsets', 'scales', 'justifications' }) do
        assert(same(layout[key] or {}, saved[key] or {}), 'kora_hud:config layout.' .. key .. ' differs from getLayout()')
    end
    ctx:equal(layout.minimapVehicleOnly, saved.minimapVehicleOnly, 'kora_hud:config layout.minimapVehicleOnly')
    ctx:equal(layout.gaugesBottomAnchored, saved.gaugesBottomAnchored, 'kora_hud:config layout.gaugesBottomAnchored')
    assert(type(config.vitalsInterval) == 'number' and config.vitalsInterval >= 0, 'kora_hud:config vitalsInterval is ' .. tostring(config.vitalsInterval))
    assert(type(config.elements) == 'table', 'kora_hud:config carries no elements table')
    local editor = assert(type(layout.editor) == 'table' and layout.editor, 'kora_hud:config carries no editor block')
    assert(type(editor.enabled) == 'boolean', 'kora_hud:config editor.enabled is not a boolean')
    -- math.max(50, math.min(1000, ...)) in sendInitialState.
    assert(type(editor.previewInterval) == 'number' and editor.previewInterval >= 50 and editor.previewInterval <= 1000,
        'kora_hud:config editor.previewInterval is ' .. tostring(editor.previewInterval))
end)

-- ---------------------------------------------------------------------------
-- Visibility edges
-- ---------------------------------------------------------------------------

K.step('I force the HUD hidden through its export again', 'client', function(ctx)
    assert(not visible(), 'The HUD is visible; hide it first')
    mark(ctx)
    K.export(HUD, 'hide')
end)

-- ---------------------------------------------------------------------------
-- Vitals and player payload
-- ---------------------------------------------------------------------------

K.step('my ped health is {int} for the HUD', 'client', function(ctx, amount)
    local ped = PlayerPedId()
    local maximum = GetEntityMaxHealth(ped)
    -- GTA peds die at or below 100.
    assert(amount > 100 and amount <= maximum, ('Health must be 101-%d'):format(maximum))
    local before = GetEntityHealth(ped)
    assert(before > 100, 'The ped is dead or dying')
    assert(before ~= amount, 'Health is already ' .. amount .. '; pick another value')
    mark(ctx)
    ctx:cleanup(function()
        local current = PlayerPedId()
        if GetEntityHealth(current) > 100 then SetEntityHealth(current, before) end
    end)
    SetEntityHealth(ped, amount)
end)
K.step('the HUD vitals payload should show health {int}', 'client', function(ctx, amount)
    waitMessage(ctx, 'kora_hud:vitals', function(data)
        return type(data) == 'table' and data.health == amount
    end, 'health ' .. amount)
end)
-- refreshMaxHealth in client/hud.lua mirrors GetEntityMaxHealth of the cached ped.
K.step('the HUD vitals payload should carry my ped maximum health', 'client', function(ctx)
    local expected = GetEntityMaxHealth(PlayerPedId())
    waitMessage(ctx, 'kora_hud:vitals', function(data)
        return type(data) == 'table' and data.maxHealth == expected
    end, 'maxHealth ' .. expected)
end)

K.step('the HUD player payload should name my job {string} at grade {int}', 'client', function(ctx, name, grade)
    waitMessage(ctx, 'kora_hud:update', function(data)
        return type(data) == 'table' and type(data.job) == 'table' and data.job.name == name and data.job.grade == grade
    end, ('job %s grade %d'):format(name, grade))
end)
-- snapshotFrom in client/bridge/kora_core.lua: onDuty = job.onduty ~= false.
K.step('the HUD player payload should show me on duty', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:update', function(data)
        return type(data) == 'table' and type(data.job) == 'table' and data.job.onDuty == true
    end, 'onDuty true')
end)
K.step('the HUD player payload should show me off duty', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:update', function(data)
        return type(data) == 'table' and type(data.job) == 'table' and data.job.onDuty == false
    end, 'onDuty false')
end)
-- The 'none' gang is sent as no gang at all (snapshotFrom).
K.step('the HUD player payload should name my gang {string}', 'client', function(ctx, name)
    waitMessage(ctx, 'kora_hud:update', function(data)
        return type(data) == 'table' and type(data.gang) == 'table' and data.gang.name == name
    end, 'gang ' .. name)
end)
K.step('the HUD player payload should show no gang', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:update', function(data)
        return type(data) == 'table' and data.gang == nil
    end, 'no gang')
end)

-- ---------------------------------------------------------------------------
-- More qb-hud compatibility events (client/compat.lua). Each records what the
-- HUD showed or held before and puts it back in cleanup.
-- ---------------------------------------------------------------------------

local function currentPlayerPayload(ctx)
    mark(ctx)
    nui('kora_hud:ready')
    return waitMessage(ctx, 'kora_hud:update', function(data) return type(data) == 'table' end).data
end

K.step('the HUD receives the legacy needs event with hunger {int} and thirst {int}', 'client', function(ctx, hunger, thirst)
    if not ctx.state.hudNeedsRestore then
        ctx.state.hudNeedsRestore = true
        local current = currentPlayerPayload(ctx)
        local before = { tonumber(current.hunger) or 100, tonumber(current.thirst) or 100 }
        ctx:cleanup(function() TriggerEvent('hud:client:UpdateNeeds', before[1], before[2]) end)
        Wait(300) -- let the player channel's rate limit lapse
    end
    mark(ctx)
    TriggerEvent('hud:client:UpdateNeeds', hunger, thirst)
end)
-- clamp() returns nil for non-numbers, and updateNeeds then overlays nothing.
K.step('the HUD receives the legacy needs event with unreadable values', 'client', function(ctx)
    mark(ctx)
    TriggerEvent('hud:client:UpdateNeeds', 'full', 'empty')
end)

K.step('the HUD receives the legacy stress event with the raw value {string}', 'client', function(ctx, raw)
    if not ctx.state.hudStressRestore then
        ctx.state.hudStressRestore = true
        local before = tonumber(currentPlayerPayload(ctx).stress) or 0
        ctx:cleanup(function() TriggerEvent('hud:client:UpdateStress', before) end)
        Wait(300)
    end
    mark(ctx)
    TriggerEvent('hud:client:UpdateStress', tonumber(raw) or raw)
end)

-- Event name -> HudCompat.state key (client/compat.lua).
local COMPAT_TOGGLES = {
    ['hud:client:ToggleHealth'] = 'dynamicHealth',
    ['hud:client:ToggleAirHud'] = 'altitude',
    ['hud:client:ToggleShowSeatbelt'] = 'showSeatbelt',
    ['seatbelt:client:ToggleCruise'] = 'cruise',
}

local function compatState()
    local compat = hudState().compat
    assert(type(compat) == 'table', 'The kora_hud FFT hook reports no compat state')
    return compat
end

K.step('the HUD receives the legacy toggle event {string}', 'client', function(ctx, event)
    local key = assert(COMPAT_TOGGLES[event], 'Not a kora_hud compat toggle event: ' .. event)
    ctx.state.hudToggles = ctx.state.hudToggles or {}
    local entry = ctx.state.hudToggles[key]
    if not entry then
        entry = { before = compatState()[key] == true, count = 0 }
        ctx.state.hudToggles[key] = entry
        ctx:cleanup(function() if entry.count % 2 == 1 then TriggerEvent(event) end end)
    end
    mark(ctx)
    entry.count = entry.count + 1
    TriggerEvent(event)
end)
K.step('the HUD compat flag {string} should be flipped', 'client', function(ctx, key)
    local entry = assert((ctx.state.hudToggles or {})[key], 'Toggle ' .. key .. ' first')
    waitMessage(ctx, 'kora_hud:compat', function(data) return type(data) == 'table' and data[key] == not entry.before end,
        key .. ' = ' .. tostring(not entry.before))
    ctx:equal(compatState()[key] == true, not entry.before, 'HudCompat.state.' .. key)
end)
K.step('the HUD compat flag {string} should be back where it started', 'client', function(ctx, key)
    local entry = assert((ctx.state.hudToggles or {})[key], 'Toggle ' .. key .. ' first')
    waitMessage(ctx, 'kora_hud:compat', function(data) return type(data) == 'table' and (data[key] == true) == entry.before end,
        key .. ' = ' .. tostring(entry.before))
    ctx:equal(compatState()[key] == true, entry.before, 'HudCompat.state.' .. key)
end)

K.step('the HUD receives the legacy nitrous event with level {string} and boost {string}', 'client', function(ctx, level, boost)
    assert(boost == 'on' or boost == 'off', 'Boost is "on" or "off"')
    if not ctx.state.hudNitrousRestore then
        ctx.state.hudNitrousRestore = true
        local before = compatState().nitrous or {}
        local beforeLevel, beforeActive = tonumber(before.level) or 0, before.active == true
        ctx:cleanup(function() TriggerEvent('hud:client:UpdateNitrous', beforeLevel, beforeActive) end)
    end
    mark(ctx)
    TriggerEvent('hud:client:UpdateNitrous', tonumber(level) or level, boost == 'on')
end)
K.step('the HUD compat payload should show nitrous level {float} with boost {string}', 'client', function(ctx, level, boost)
    local active = boost == 'on'
    waitMessage(ctx, 'kora_hud:compat', function(data)
        return type(data) == 'table' and type(data.nitrous) == 'table' and near(data.nitrous.level, level) and data.nitrous.active == active
    end, ('nitrous %s / %s'):format(level, boost))
end)

K.step('the HUD receives the legacy harness event with {string} uses', 'client', function(ctx, uses)
    if not ctx.state.hudHarnessRestore then
        ctx.state.hudHarnessRestore = true
        local before = tonumber(compatState().harness)
        ctx:cleanup(function() TriggerEvent('hud:client:UpdateHarness', before) end)
    end
    mark(ctx)
    TriggerEvent('hud:client:UpdateHarness', tonumber(uses) or uses)
end)
K.step('the HUD compat payload should show {float} harness uses', 'client', function(ctx, uses)
    waitMessage(ctx, 'kora_hud:compat', function(data)
        return type(data) == 'table' and near(data.harness, uses)
    end, 'harness ' .. uses)
end)
K.step('the HUD compat payload should show no harness', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:compat', function(data)
        return type(data) == 'table' and data.harness == nil
    end, 'no harness')
end)

-- HudCompat.showAccount: a notification titled Cash/Bank with "$<amount>".
K.step('the HUD receives the legacy show accounts event for {string}', 'client', function(ctx, account)
    mark(ctx)
    TriggerEvent('hud:client:ShowAccounts', account)
end)

-- ---------------------------------------------------------------------------
-- Vehicle telemetry (client/vehicle.lua, pushVehicleUpdate in client/hud.lua)
-- ---------------------------------------------------------------------------

local function testVehicle(ctx)
    local vehicle = ctx.state.vehicle
    assert(vehicle and DoesEntityExist(vehicle), 'Drive a temporary vehicle first')
    return vehicle
end

K.step('I leave the temporary vehicle', 'client', function(ctx)
    local vehicle = testVehicle(ctx)
    mark(ctx)
    TaskLeaveVehicle(PlayerPedId(), vehicle, 16)
    ctx:waitUntil(function() return not IsPedInAnyVehicle(PlayerPedId(), false) end, 'Could not leave the vehicle', 5000)
end)
-- The on-foot push is a nil payload (onVehicleChange -> pushVehicleUpdate).
K.step('the HUD page should be told I am on foot', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:vehicle', function(data) return data == nil end, 'no vehicle')
end)
K.step('I switch the temporary vehicle engine off', 'client', function(ctx)
    local vehicle = testVehicle(ctx)
    mark(ctx)
    SetVehicleEngineOn(vehicle, false, true, true)
end)
K.step('the HUD vehicle payload should show the engine off', 'client', function(ctx)
    waitMessage(ctx, 'kora_hud:vehicle', function(data)
        return type(data) == 'table' and data.engineOn == false
    end, 'engineOn false')
end)
-- Vehicle.getSnapshot: highbeamsOn -> 'high', lightsOn -> 'low', else 'off'.
K.step('I switch the temporary vehicle headlights to {string}', 'client', function(ctx, mode)
    assert(mode == 'low' or mode == 'high', 'Headlights are "low" or "high"')
    local vehicle = testVehicle(ctx)
    mark(ctx)
    SetVehicleLights(vehicle, 2) -- forced on
    SetVehicleFullbeam(vehicle, mode == 'high')
end)
K.step('the HUD vehicle payload should show headlights {string}', 'client', function(ctx, mode)
    waitMessage(ctx, 'kora_hud:vehicle', function(data)
        return type(data) == 'table' and data.headlights == mode
    end, 'headlights ' .. mode)
end)
K.step('the HUD vehicle payload should show a speed of {int}', 'client', function(ctx, speed)
    waitMessage(ctx, 'kora_hud:vehicle', function(data)
        return type(data) == 'table' and data.speed == speed
    end, 'speed ' .. speed)
end)
K.step('the HUD vehicle payload should show the fuel kind {string}', 'client', function(ctx, kind)
    waitMessage(ctx, 'kora_hud:vehicle', function(data)
        return type(data) == 'table' and data.fuelKind == kind
    end, 'fuelKind ' .. kind)
end)

-- ---------------------------------------------------------------------------
-- /minimap (toggleMinimap in client/hud.lua). The choice is a client KVP; in a
-- vehicle getLayout().hidden.minimap is exactly the player's hide choice.
-- ---------------------------------------------------------------------------

local MINIMAP_COMMAND = 'minimap' -- Config.hud.minimapToggle.command

local function minimapHidden() return (K.export(HUD, 'getLayout').hidden or {}).minimap == true end

-- A toggle in a vehicle clears the saved on-foot override (minimapOnFootChoice),
-- so what the tester saw on foot is recorded before driving and put back once
-- the temporary vehicle is gone (a toggle on foot while the vehicle gate hides
-- the map sets that override again). Must be registered before the vehicle so
-- this cleanup runs after the vehicle's.
K.step('I remember my on-foot minimap view', 'client', function(ctx)
    assert(not IsPedInAnyVehicle(PlayerPedId(), false), 'Remember the on-foot minimap view on foot')
    local hiddenOnFoot = minimapHidden()
    ctx:cleanup(function()
        local deadline = GetGameTimer() + 3000
        while IsPedInAnyVehicle(PlayerPedId(), false) and GetGameTimer() < deadline do Wait(100) end
        if IsPedInAnyVehicle(PlayerPedId(), false) then return end
        Wait(300)
        if not hiddenOnFoot and minimapHidden() then ExecuteCommand(MINIMAP_COMMAND) end
    end)
end)

K.step('I toggle the minimap', 'client', function(ctx)
    assert(IsPedInAnyVehicle(PlayerPedId(), false), 'Toggle the minimap from a vehicle so two toggles round-trip the choice')
    ctx.state.hudMinimap = ctx.state.hudMinimap or { before = minimapHidden(), count = 0 }
    local state = ctx.state.hudMinimap
    if state.count == 0 then
        ctx:cleanup(function() if state.count % 2 == 1 then ExecuteCommand(MINIMAP_COMMAND) end end)
    end
    state.count = state.count + 1
    ExecuteCommand(MINIMAP_COMMAND)
end)
K.step('my minimap choice should have flipped and the HUD should say so', 'client', function(ctx)
    local state = assert(ctx.state.hudMinimap, 'Toggle the minimap first')
    local expected = not state.before
    ctx:waitUntil(function() return minimapHidden() == expected end, 'getLayout().hidden.minimap did not flip', 3000)
    K.waitNotification(ctx, expected and 'Minimap hidden.' or 'Minimap shown.')
end)
K.step('my minimap choice should be back where it started', 'client', function(ctx)
    local state = assert(ctx.state.hudMinimap, 'Toggle the minimap first')
    ctx:waitUntil(function() return minimapHidden() == state.before end, 'getLayout().hidden.minimap did not return', 3000)
    K.waitNotification(ctx, state.before and 'Minimap hidden.' or 'Minimap shown.')
end)

-- ---------------------------------------------------------------------------
-- /ui element registry (client/uiregistry.lua via the exports in client/hud.lua).
-- fft itself is the owner (GetInvokingResource), so nothing of another
-- resource is touched. Every registration is unregistered in cleanup; ids are
-- never written to the layout unless registered by the scenario (assertSavable).
-- ---------------------------------------------------------------------------

local function uiResult(ctx, ok, err)
    ctx.state.hudUi = { ok = ok, err = err }
end

local function register(ctx, def)
    listen(ctx)
    local id = type(def) == 'table' and def.id or nil
    if type(id) == 'string' then
        -- unregisterUiElement only removes an element this resource owns.
        ctx:cleanup(function() pcall(function() exports.kora_hud:unregisterUiElement(id) end) end)
    end
    mark(ctx)
    local ok, err = K.export(HUD, 'registerUiElement', def)
    if ok == true and type(id) == 'string' then
        ctx.state.hudOwned = ctx.state.hudOwned or {}
        ctx.state.hudOwned[id] = true
    end
    uiResult(ctx, ok, err)
    return ok, err
end

local function probe(id)
    return { id = id, label = 'FFT probe', rect = { x = 0.4, y = 0.4, w = 0.1, h = 0.1 } }
end

K.step('I register the HUD UI element {string}', 'client', function(ctx, id)
    local ok, err = register(ctx, probe(id))
    assert(ok == true, ('registerUiElement(%s) was refused: %s'):format(id, tostring(err)))
end)
K.step('I register {int} HUD UI elements named {string}', 'client', function(ctx, count, prefix)
    assert(count >= 1 and count <= 12, 'Register 1-12 elements (MAX_PER_OWNER in client/uiregistry.lua)')
    for index = 1, count do
        local ok, err = register(ctx, probe(prefix .. index))
        assert(ok == true, ('registerUiElement(%s%d) was refused: %s'):format(prefix, index, tostring(err)))
    end
end)
K.step('I register a HUD UI element with:', 'client', function(ctx, argument)
    register(ctx, K.json(argument))
end)
K.step('I register a HUD UI element with the id {string}', 'client', function(ctx, id)
    register(ctx, probe(id))
end)
K.step('I register a HUD UI element that is not a table', 'client', function(ctx)
    register(ctx, 'fftProbe')
end)
K.step('I update the HUD UI element {string} with:', 'client', function(ctx, id, argument)
    listen(ctx)
    mark(ctx)
    uiResult(ctx, K.export(HUD, 'updateUiElement', id, K.json(argument)))
end)
K.step('I update the HUD UI element {string} without a patch', 'client', function(ctx, id)
    mark(ctx)
    uiResult(ctx, K.export(HUD, 'updateUiElement', id, nil))
end)
K.step('I unregister the HUD UI element {string}', 'client', function(ctx, id)
    mark(ctx)
    local ok, err = K.export(HUD, 'unregisterUiElement', id)
    if ok == true and ctx.state.hudOwned then ctx.state.hudOwned[id] = nil end
    uiResult(ctx, ok, err)
end)

K.step('the HUD UI request should succeed', 'client', function(ctx)
    local result = assert(ctx.state.hudUi, 'Make a HUD UI request first')
    assert(result.ok == true, 'The HUD UI request was refused: ' .. tostring(result.err))
end)
K.step('the HUD UI request should be refused', 'client', function(ctx)
    local result = assert(ctx.state.hudUi, 'Make a HUD UI request first')
    ctx:equal(result.ok, false, 'HUD UI request result')
end)
K.step('the HUD UI request should be refused with {string}', 'client', function(ctx, reason)
    local result = assert(ctx.state.hudUi, 'Make a HUD UI request first')
    ctx:equal(result.ok, false, 'HUD UI request result')
    ctx:equal(result.err, reason, 'Refusal reason')
end)

local function listEntry(list, id)
    for _, entry in pairs(type(list) == 'table' and list or {}) do
        if type(entry) == 'table' and entry.id == id then return entry end
    end
end

-- kora_hud:uiElements is coalesced ~100 ms after a registry change (queueUiElements).
K.step('the HUD page element list should include {string} with:', 'client', function(ctx, id, argument)
    local expected = K.json(argument)
    local last
    ctx:waitUntil(function()
        for _, message in ipairs(messages(ctx, 'kora_hud:uiElements')) do
            local entry = listEntry(message.data, id)
            if entry then
                last = entry
                if subset(expected, entry) then return true end
            end
        end
    end, ('kora_hud:uiElements has no matching %s'):format(id), 5000, function() return ' | last: ' .. describe(last) end)
end)
K.step('the HUD page element list should not include {string}', 'client', function(ctx, id)
    ctx:waitUntil(function()
        for _, message in ipairs(messages(ctx, 'kora_hud:uiElements')) do
            if type(message.data) == 'table' and not listEntry(message.data, id) then return true end
        end
    end, 'No kora_hud:uiElements without ' .. id .. ' was sent', 5000)
end)

K.step('the HUD should apply a {string} layout to {string} with:', 'client', function(ctx, reason, id, argument)
    local expected = K.json(argument)
    local last
    ctx:waitUntil(function()
        for _, apply in ipairs(recorded(ctx, 'apply')) do
            if apply.id == id and apply.reason == reason then
                last = apply.layout
                if subset(expected, apply.layout) then return true end
            end
        end
    end, ('kora_hud:ui:apply(%s, %s) with the expected layout was not raised'):format(id, reason), 3000,
        function() return ' | last: ' .. describe(last) end)
end)
K.step('the HUD should not apply a {string} layout to {string}', 'client', function(ctx, reason, id)
    Wait(800)
    for _, apply in ipairs(recorded(ctx, 'apply')) do
        assert(not (apply.id == id and apply.reason == reason), ('kora_hud:ui:apply(%s, %s) was raised'):format(id, reason))
    end
end)

K.step('the HUD UI layout for {string} should include:', 'client', function(ctx, id, argument)
    local expected = K.json(argument)
    ctx:waitUntil(function() return subset(expected, K.export(HUD, 'getUiLayout', id)) end,
        ('getUiLayout(%s) is %s'):format(id, describe(K.export(HUD, 'getUiLayout', id))), 3000)
end)
K.step('there should be no HUD UI layout for {string}', 'client', function(ctx, id)
    local layout = K.export(HUD, 'getUiLayout', id)
    assert(layout == nil, ('getUiLayout(%s) is %s'):format(id, describe(layout)))
end)

-- web posts kora_hud:uiPreview { elements = { [id] = entry } } while dragging.
K.step('the HUD page previews {string} with:', 'client', function(ctx, id, argument)
    listen(ctx)
    mark(ctx)
    nui('kora_hud:uiPreview', { elements = { [id] = K.json(argument) } })
end)
