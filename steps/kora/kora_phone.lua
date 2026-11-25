-- kora_phone (the folder-app rework, KoraFiveM/kora_phone PR #54): the phone as seen by a character who holds NO handset.
-- No resource hook. Server steps call the real exports (server/main.lua, server/sdk/exports.lua). Client steps run the
-- phone's own NUI callbacks the way its page does (a JSON POST to https://kora_phone/<route>) through K.nui, so every
-- server check and rate limit stays in force. App callbacks go through `apps:call`, app client handlers through
-- `apps:client` (client/nui.lua).
--
-- Why no handset: the first bootstrap with a handset item inserts phone_devices and phone_handsets rows that the
-- resource cannot delete (see kora_phone-stevie.lua). Every scenario therefore starts by proving the tester holds no
-- handset, which also guarantees that nothing here can message, call, mail, post or transfer.
--
-- Step wording is "kora_phone ..." on purpose: kora_phone-stevie.lua owns the "phone route" wording for the older fork.
local K = FFT.kora
if not K then return end
K.feature('kora_phone')

local RESOURCE = 'kora_phone'
-- Routes a step may call. Every one is in shared/routes.json or client/nui.lua of kora_phone.
local ROUTES = {
    ['bootstrap'] = true, ['handset:action'] = true, ['settings:save'] = true,
    ['security:unlock'] = true, ['security:lock'] = true, ['security:setPin'] = true, ['security:removePin'] = true,
    ['contacts:list'] = true, ['contacts:create'] = true, ['contacts:update'] = true, ['contacts:delete'] = true,
    ['blocks:list'] = true, ['blocks:set'] = true, ['gallery:list'] = true, ['share:answer'] = true,
    ['calls:start'] = true, ['calls:accept'] = true, ['calls:reject'] = true, ['calls:hangup'] = true,
    ['calls:signal'] = true, ['calls:videoControl'] = true, ['media:request'] = true, ['media:complete'] = true,
    ['apps:list'] = true, ['apps:install'] = true, ['apps:uninstall'] = true, ['apps:call'] = true,
    ['apps:storage:get'] = true, ['apps:storage:list'] = true, ['apps:storage:set'] = true, ['apps:storage:remove'] = true,
    ['apps:contacts:list'] = true, ['apps:contacts:save'] = true, ['apps:notify'] = true,
    -- Client-only routes (client/nui.lua).
    ['phone:ready'] = true, ['phone:close'] = true, ['route:changed'] = true, ['apps:client'] = true,
    ['location:mine'] = true, ['weather:get'] = true, ['waypoint'] = true, ['notify'] = true, ['quiet'] = true,
    ['customList'] = true, ['customLifecycle'] = true, ['camera:close'] = true,
}

-- Routes that were removed when their apps became folder apps. They must stay gone: a request now goes unanswered.
local REMOVED = {
    'messages:getConversations', 'messages:send', 'mail:list', 'bank:getData', 'bank:transfer', 'wallet:get', 'items:save',
    'moderation:getQueue', 'social:getFeed', 'market:getListings', 'property:list', 'garage:list', 'gallery:delete',
    'calls:history', 'jobs:getData', 'map:blips', 'alarm',
}

-- ---------------------------------------------------------------------------
-- Server
-- ---------------------------------------------------------------------------

-- Config.Handsets items (kora_phone/config/handsets.lua).
local HANDSET_ITEMS = { 'phone', 'phone_standard', 'phone_flip', 'phone_fold' }

K.step('I hold no kora_phone handset', 'server', function(ctx)
    for _, item in ipairs(HANDSET_ITEMS) do
        if K.count(ctx, item) > 0 then
            error(('The tester holds a %s; this suite only runs without a handset'):format(item), 0)
        end
    end
end)

K.step('the kora_phone number export should report no number for me', 'server', function(ctx)
    ctx:equal(K.export(RESOURCE, 'GetPhoneNumber', ctx.tester), nil, 'GetPhoneNumber')
end)

K.step('the kora_phone number lookup for {string} should find nobody', 'server', function(ctx, number)
    ctx:equal(K.export(RESOURCE, 'GetSourceByPhoneNumber', number), nil, 'GetSourceByPhoneNumber')
end)

K.step('kora_phone should not resell inventory slot {int}', 'server', function(ctx, slot)
    ctx:equal(K.export(RESOURCE, 'CanResellHandset', ctx.tester, slot), false, 'CanResellHandset')
end)

K.step('the kora_phone command {string} should be registered', 'server', function(_, name)
    for _, command in ipairs(GetRegisteredCommands()) do
        if command.name == name then return end
    end
    error('Server command /' .. name .. ' is not registered', 0)
end)

-- SendNotification only reaches the target player (server/main.lua).
K.step('kora_phone sends me the notification {string} with body {string}', 'server', function(ctx, title, body)
    ctx:equal(K.export(RESOURCE, 'SendNotification', ctx.tester, { app = 'system', title = title, body = body }), true, 'SendNotification result')
end)

K.step('kora_phone should refuse to send me a malformed notification', 'server', function(ctx)
    ctx:equal(K.export(RESOURCE, 'SendNotification', ctx.tester, 'not a table'), false, 'SendNotification result')
end)

-- server/sdk/exports.lua: SDK.Registry.register returns `false, 'INVALID_MANIFEST: ...'` for a bad manifest.
K.step('kora_phone should refuse the app manifest:', 'server', function(_, argument)
    local manifest = K.json(argument)
    assert(type(manifest) == 'table', 'The manifest must be a JSON object')
    local ok, err = K.export(RESOURCE, 'RegisterApp', manifest)
    if ok then
        pcall(function() exports[RESOURCE]:RemoveApp(manifest.id) end)
        error('kora_phone accepted a manifest it should refuse', 0)
    end
    assert(type(err) == 'string' and err:find('INVALID_MANIFEST', 1, true), 'Expected INVALID_MANIFEST, got ' .. tostring(err))
end)

K.step('kora_phone should not remove the unknown app {string}', 'server', function(_, id)
    local removed = K.export(RESOURCE, 'RemoveApp', id)
    assert(removed == false or removed == nil, 'RemoveApp reported removing an app that was never registered')
end)

K.step('kora_phone should refuse an app event to the unknown app {string}', 'server', function(ctx, id)
    ctx:equal(K.export(RESOURCE, 'SendAppEvent', ctx.tester, id, 'ping', {}), false, 'SendAppEvent result')
end)

K.step('kora_phone should list no installed apps for me', 'server', function(ctx)
    local list = K.export(RESOURCE, 'GetInstalledApps', ctx.tester)
    assert(type(list) == 'table' and next(list) == nil, 'A character without a handset has installed apps')
end)

-- ---------------------------------------------------------------------------
-- Client: NUI routes
-- ---------------------------------------------------------------------------

local function describe(reply)
    local err = reply.error
    if type(err) == 'table' then return ('%s: %s'):format(tostring(err.code), tostring(err.message)) end
    return tostring(err)
end

local function call(name, body, timeout)
    assert(ROUTES[name], 'kora_phone route is not on the suite allow-list: ' .. tostring(name))
    local result = K.nui(RESOURCE, name, body or {}, timeout or 10000)
    assert(type(result) == 'table', 'kora_phone answered ' .. name .. ' with ' .. type(result))
    return result
end

local function remember(ctx, result) ctx.state.koraPhoneReply = result return result end
local function last(ctx) return assert(ctx.state.koraPhoneReply, 'Call a kora_phone route first') end

K.step('I call the kora_phone route {string}', 'client', function(ctx, name)
    remember(ctx, call(name, {}))
end)

K.step('I call the kora_phone route {string} with:', 'client', function(ctx, name, argument)
    local body = K.json(argument)
    assert(type(body) == 'table', 'The route payload must be a JSON object')
    remember(ctx, call(name, body))
end)

-- apps:call reaches an app's server callback (server/sdk/routes.lua routes.call).
K.step('I call the kora_phone app {string} callback {string}', 'client', function(ctx, app, name)
    remember(ctx, call('apps:call', { app = app, name = name, payload = {} }))
end)

K.step('I call the kora_phone app {string} callback {string} with:', 'client', function(ctx, app, name, argument)
    local payload = K.json(argument)
    assert(type(payload) == 'table', 'The callback payload must be a JSON object')
    remember(ctx, call('apps:call', { app = app, name = name, payload = payload }))
end)

-- apps:client reaches an app's client handler (apps/<id>/client.lua) with no server round trip and no handset check.
K.step('I ask the kora_phone app {string} on the client for {string}', 'client', function(ctx, app, name)
    remember(ctx, call('apps:client', { app = app, name = name, payload = {} }))
end)

K.step('I ask the kora_phone app {string} on the client for {string} with:', 'client', function(ctx, app, name, argument)
    local payload = K.json(argument)
    assert(payload ~= nil, 'The handler payload must be JSON')
    remember(ctx, call('apps:client', { app = app, name = name, payload = payload }))
end)

K.step('the kora_phone route should be refused with code {string}', 'client', function(ctx, code)
    local result = last(ctx)
    if result.ok ~= false then error('kora_phone accepted the request', 0) end
    if type(result.error) ~= 'table' then error('Unexpected refusal: ' .. describe(result), 0) end
    ctx:equal(result.error.code, code, 'Error code')
end)

K.step('the kora_phone route should be refused with code {string} and message {string}', 'client', function(ctx, code, message)
    local result = last(ctx)
    if result.ok ~= false then error('kora_phone accepted the request', 0) end
    if type(result.error) ~= 'table' then error('Unexpected refusal: ' .. describe(result), 0) end
    ctx:equal(result.error.code, code, 'Error code')
    ctx:equal(result.error.message, message, 'Error message')
end)

K.step('the kora_phone route should succeed', 'client', function(ctx)
    local result = last(ctx)
    if result.ok ~= true then error('kora_phone refused the request: ' .. describe(result), 0) end
end)

K.step('the kora_phone route should answer without success', 'client', function(ctx)
    local result = last(ctx)
    -- A client handler answers `{ ok = true, data = { ok = false } }` or `{ ok = true, data = false }`; a bare route answers `{ ok = false }`.
    local data = result.data
    local failed = result.ok == false or data == false or data == nil or (type(data) == 'table' and data.ok == false)
    if not failed then error('Expected the request to report no success', 0) end
end)

K.step('the kora_phone app client answer should be {string}', 'client', function(ctx, expected)
    local result = last(ctx)
    if result.ok ~= true then error('kora_phone refused the request: ' .. describe(result), 0) end
    ctx:equal(tostring(result.data), expected, 'Client handler answer')
end)

-- A removed route has no NUI callback any more, so K.nui raises its "unanswered" error.
K.step('the removed kora_phone route {string} should stay unanswered', 'client', function(_, name)
    local listed = false
    for _, removed in ipairs(REMOVED) do if removed == name then listed = true end end
    assert(listed, 'Not a route this suite tracks as removed: ' .. name)
    local ok = pcall(K.nui, RESOURCE, name, {}, 1500)
    if ok then error('The removed route ' .. name .. ' answered; it should be an app callback now', 0) end
end)

-- phone:ready answers with KoraPhone.State.Public() (client/phone_state.lua).
K.step('the kora_phone route should report a loaded character and a closed phone', 'client', function(ctx)
    local data = last(ctx).data
    assert(type(data) == 'table', 'phone:ready returned no state')
    ctx:equal(data.playerLoaded, true, 'playerLoaded')
    ctx:equal(data.open, false, 'open')
end)

K.step('the kora_phone route should report my current position', 'client', function(ctx)
    local data = last(ctx).data
    assert(type(data) == 'table' and type(data.x) == 'number' and type(data.y) == 'number', 'No position was returned')
    local at = GetEntityCoords(PlayerPedId())
    assert(math.abs(data.x - at.x) < 5.0 and math.abs(data.y - at.y) < 5.0,
        ('Reported %.1f, %.1f but the tester is at %.1f, %.1f'):format(data.x, data.y, at.x, at.y))
    assert(type(data.label) == 'string' and data.label ~= '', 'No street label was returned')
end)

K.step('the kora_phone route should report the game clock and weather', 'client', function(ctx)
    local data = last(ctx).data
    assert(type(data) == 'table' and type(data.condition) == 'string' and type(data.hour) == 'number', 'weather:get returned no clock')
end)

-- ---------------------------------------------------------------------------
-- Client: put the phone away, commands, notifications
-- ---------------------------------------------------------------------------

local function isOpen() return K.export(RESOURCE, 'IsPhoneOpen') == true end

K.step('my kora_phone is put away', 'client', function(ctx)
    if GetResourceState(RESOURCE) ~= 'started' then return end
    pcall(function() exports[RESOURCE]:ClosePhone() end)
    ctx:waitUntil(function() return not isOpen() end, 'The phone did not close', 3000)
end)

K.step('my kora_phone should be put away', 'client', function(ctx)
    ctx:waitUntil(function() return not isOpen() end, 'The phone is still open', 5000)
end)

K.step('I open the kora_phone through its export', 'client', function(ctx)
    K.export(RESOURCE, 'OpenPhone')
    ctx:cleanup(function() pcall(function() exports[RESOURCE]:ClosePhone() end) end)
end)

K.step('I push the local kora_phone notification {string} with message {string}', 'client', function(ctx, title, message)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { title = title, message = message }), true, 'PushNotification result')
end)

K.step('kora_phone should reject a local notification without a title', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { message = 'fft kora_phone probe' }), false, 'PushNotification result')
end)

-- ---------------------------------------------------------------------------
-- Client: Maps (apps/gps/client.lua)
-- ---------------------------------------------------------------------------

K.step('I add a kora_phone probe blip at {int} {int} titled {string}', 'client', function(ctx, x, y, title)
    local blip = AddBlipForCoord(x + 0.0, y + 0.0, 30.0)
    ctx:cleanup(function()
        if GetResourceState(RESOURCE) == 'started' then pcall(function() exports[RESOURCE]:UnregisterMapBlip(blip) end) end
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
    assert(DoesBlipExist(blip), 'Could not create the probe blip')
    SetBlipDisplay(blip, 2)
    SetBlipAlpha(blip, 255)
    ctx.state.koraPhoneBlip = blip
    ctx:equal(K.export(RESOURCE, 'RegisterMapBlip', blip, title), true, 'RegisterMapBlip result')
end)

local function blipEntry(ctx)
    local blip = assert(ctx.state.koraPhoneBlip, 'Add a probe blip first')
    local result = call('apps:client', { app = 'gps', name = 'blips', payload = {} })
    if result.ok ~= true then error('The Maps blips handler was refused: ' .. describe(result), 0) end
    for _, entry in pairs(result.data or {}) do
        if type(entry) == 'table' and entry.id == blip then return entry end
    end
end

K.step('the kora_phone map should list the probe blip titled {string}', 'client', function(ctx, title)
    local entry
    ctx:waitUntil(function() entry = blipEntry(ctx) return entry ~= nil end, 'The Maps app does not list the probe blip', 3000)
    ctx:equal(entry.label, title, 'Blip label')
end)

K.step('the kora_phone map should not list the probe blip', 'client', function(ctx)
    local entry = blipEntry(ctx)
    if entry then error('The Maps app still lists the probe blip as ' .. tostring(entry.label), 0) end
end)

K.step('I remove the probe blip from the kora_phone map', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'UnregisterMapBlip', assert(ctx.state.koraPhoneBlip)), true, 'UnregisterMapBlip result')
end)

K.step('the kora_phone map should refuse the probe blip with a blank title', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'RegisterMapBlip', assert(ctx.state.koraPhoneBlip), '   '), false, 'RegisterMapBlip result')
end)

K.step('the kora_phone map should refuse the probe blip with a {int} character title', 'client', function(ctx, length)
    ctx:equal(K.export(RESOURCE, 'RegisterMapBlip', assert(ctx.state.koraPhoneBlip), ('b'):rep(length)), false, 'RegisterMapBlip result')
end)

K.step('the kora_phone map should refuse a blip that does not exist', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'RegisterMapBlip', 0, 'FFT missing blip'), false, 'RegisterMapBlip result')
end)

-- Where the game's own waypoint is, or nil. Blip sprite 8 is the waypoint.
local function waypointAt()
    local blip = GetFirstBlipInfoId(8)
    if DoesBlipExist(blip) then return GetBlipInfoIdCoord(blip) end
end

K.step('my kora_phone map waypoint is restored afterwards', 'client', function(ctx)
    local previous = waypointAt()
    ctx:cleanup(function()
        if previous then SetNewWaypoint(previous.x, previous.y) else DeleteWaypoint() end
    end)
end)

K.step('my map waypoint should be at {int} {int} on the kora_phone map', 'client', function(ctx, x, y)
    ctx:waitUntil(function()
        local at = waypointAt()
        return at ~= nil and math.abs(at.x - x) < 2.0 and math.abs(at.y - y) < 2.0
    end, 'The waypoint was not set', 3000)
end)

-- ---------------------------------------------------------------------------
-- Client: Clock (apps/clock/client.lua rings alarms with the phone closed)
-- ---------------------------------------------------------------------------

-- apps/clock/client.lua checks GetLocalTime once a second and rings at most once per minute; an alarm with no repeat days
-- is one-time. Setting it to the current minute rings within a second, unless the minute turns over first.
K.step('the kora_phone clock has an alarm for this minute labelled {string}', 'client', function(ctx, label)
    local _, _, _, hour, minute = GetLocalTime()
    local alarm = { id = 'fft-alarm-1', label = label, time = ('%02d:%02d'):format(hour, minute), days = {}, enabled = true }
    ctx:cleanup(function() pcall(K.nui, RESOURCE, 'apps:client', { app = 'clock', name = 'sync', payload = {} }, 3000) end)
    local result = call('apps:client', { app = 'clock', name = 'sync', payload = { alarm } })
    if result.ok ~= true then error('The Clock sync handler was refused: ' .. describe(result), 0) end
end)

K.step('the kora_phone clock should drop a malformed alarm list', 'client', function(ctx)
    local result = call('apps:client', { app = 'clock', name = 'sync', payload = { { id = 5 }, 'x', { id = 'b', time = 'bad' } } })
    if result.ok ~= true then error('The Clock sync handler was refused: ' .. describe(result), 0) end
    ctx:equal(result.data, true, 'sync answer')
end)

-- ---------------------------------------------------------------------------
-- Client: custom apps registered by another resource (client/customapps.lua)
-- ---------------------------------------------------------------------------

local function listed(id)
    local result = call('customList', {})
    for _, app in pairs(result.data or result) do
        if type(app) == 'table' and app.identifier == id then return app end
    end
end

local function removeApp(id)
    if GetResourceState(RESOURCE) == 'started' then pcall(function() exports[RESOURCE]:RemoveApp(id) end) end
end

K.step('I register the kora_phone custom app {string} with ui {string}', 'client', function(ctx, id, ui)
    ctx:cleanup(function() removeApp(id) end)
    ctx:equal(K.export(RESOURCE, 'RegisterApp', { identifier = id, name = 'FFT probe app', ui = ui }), true, 'RegisterApp result')
end)

K.step('the kora_phone custom app list should include {string}', 'client', function(ctx, id)
    ctx:waitUntil(function() return listed(id) ~= nil end, 'The custom app list does not include ' .. id, 3000)
end)

K.step('the kora_phone custom app list should not include {string}', 'client', function(_, id)
    if listed(id) then error('The custom app list still includes ' .. id, 0) end
end)

K.step('I remove the kora_phone custom app {string}', 'client', function(ctx, id)
    ctx:equal(K.export(RESOURCE, 'RemoveApp', id), true, 'RemoveApp result')
end)

K.step('kora_phone should refuse a custom app without an identifier', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'RegisterApp', { identifier = '', ui = 'fft_probe/index.html' }), false, 'RegisterApp result')
end)

-- The lb-phone alias exports (client/customapps.lua alias(); fxmanifest provide 'lb-phone').
K.step('I register the kora_phone custom app {string} through the lb-phone exports', 'client', function(ctx, id)
    ctx:cleanup(function() removeApp(id) end)
    local ok, result = pcall(function()
        return exports['lb-phone']:AddCustomApp({ identifier = id, name = 'FFT alias app', ui = 'fft_probe/index.html' })
    end)
    if not ok then error('lb-phone AddCustomApp failed: ' .. tostring(result), 0) end
    ctx:equal(result, true, 'AddCustomApp result')
end)
