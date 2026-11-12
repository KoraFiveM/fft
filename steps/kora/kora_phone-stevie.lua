-- kora_phone-stevie: the phone as seen by a character who holds NO handset.
-- No resource hook. Server steps call the real exports (server/main.lua,
-- server/handsets.lua). Client steps use the client exports (client/main.lua)
-- and run the phone's own NUI callbacks (client/nui.lua) the way its browser
-- page does (web/src/api.ts: a JSON POST to https://kora_phone-stevie/<route>),
-- with a real fetch through K.nui, so every server check and rate limit stays
-- in force.
--
-- Why no handset: the first bootstrap with a handset item inserts phone_devices
-- and phone_handsets rows (Handsets.current in server/handsets.lua) and the
-- resource has no way to delete them, so a run would leave rows behind for a
-- handset item the cleanup then removes. Every scenario therefore starts by
-- proving the tester holds no handset, which also guarantees that no route
-- here can send a message, mail, call, post or transfer.
local K = FFT.kora
if not K then return end
K.feature('kora_phone-stevie')

local RESOURCE = 'kora_phone-stevie'
-- Config.Handsets in kora_phone-stevie/config/handsets.lua.
local HANDSET_ITEMS = { 'phone', 'phone_standard', 'phone_flip', 'phone_fold' }
-- Config.Client.UiBlockBag in kora_phone-stevie/config/client.lua.
local UI_BLOCK_BAG = 'koraUiBlocked'

-- Routes a step may call. Send, call, post and transfer routes are listed only
-- because the suite asserts they are refused without a handset; the payloads in
-- the feature are invalid as well.
local ROUTES = {
    ['bootstrap'] = true, ['handset:action'] = true, ['contacts:list'] = true, ['contacts:create'] = true,
    ['messages:getConversations'] = true, ['messages:send'] = true, ['mail:list'] = true, ['mail:send'] = true,
    ['bank:getData'] = true, ['bank:transfer'] = true, ['wallet:get'] = true, ['items:save'] = true,
    ['settings:save'] = true, ['moderation:getQueue'] = true,
    ['waypoint'] = true, ['weather:get'] = true, ['location:mine'] = true, ['phone:ready'] = true,
    -- Further server routes (client/nui.lua callbacks table, client/compat.lua mail:accept).
    ['blocks:list'] = true, ['blocks:set'] = true, ['property:list'] = true, ['garage:list'] = true,
    ['gallery:list'] = true, ['gallery:delete'] = true, ['calls:history'] = true, ['bank:getTransactions'] = true,
    ['jobs:getData'] = true, ['jobs:setDuty'] = true, ['messages:getPage'] = true, ['messages:startDirect'] = true,
    ['messages:markRead'] = true, ['messages:deleteForSelf'] = true, ['messages:createGroup'] = true,
    ['messages:addMember'] = true, ['messages:leaveGroup'] = true, ['contacts:update'] = true,
    ['contacts:delete'] = true, ['mail:read'] = true, ['mail:delete'] = true, ['mail:accept'] = true,
    ['items:remove'] = true, ['wallet:show'] = true, ['security:unlock'] = true, ['security:lock'] = true,
    ['security:setPin'] = true, ['share:answer'] = true, ['media:request'] = true, ['media:complete'] = true,
    ['calls:start'] = true, ['calls:hangup'] = true, ['calls:signal'] = true, ['calls:videoControl'] = true,
    ['social:getFeed'] = true, ['social:getComments'] = true, ['social:createPost'] = true,
    ['market:getListings'] = true, ['market:getListing'] = true, ['market:createListing'] = true,
    ['moderation:resolve'] = true, ['legacy:mailList'] = true, ['legacy:activity'] = true,
    -- Client-only routes (client/nui.lua).
    ['route:changed'] = true, ['phone:close'] = true, ['notify'] = true, ['alarm'] = true,
    ['calls:setMuted'] = true, ['calls:setSpeaker'] = true, ['camera:zoom'] = true, ['camera:facing'] = true,
    ['camera:recording'] = true, ['camera:close'] = true, ['camera:open'] = true, ['map:blips'] = true,
    ['customList'] = true, ['customLifecycle'] = true, ['quiet'] = true,
}

-- ---------------------------------------------------------------------------
-- Server
-- ---------------------------------------------------------------------------

K.step('I carry no phone handset', 'server', function(ctx)
    for _, item in ipairs(HANDSET_ITEMS) do
        if K.count(ctx, item) > 0 then
            error(('The tester holds a %s; this suite only runs without a handset'):format(item), 0)
        end
    end
end)

K.step('my phone number export should report no number', 'server', function(ctx)
    ctx:equal(K.export(RESOURCE, 'GetPhoneNumber', ctx.tester), nil, 'GetPhoneNumber')
end)

K.step('the phone number lookup for {string} should find nobody', 'server', function(ctx, number)
    ctx:equal(K.export(RESOURCE, 'GetSourceByPhoneNumber', number), nil, 'GetSourceByPhoneNumber')
end)

K.step('inventory slot {int} should not hold a resellable phone handset', 'server', function(ctx, slot)
    ctx:equal(K.export(RESOURCE, 'CanResellHandset', ctx.tester, slot), false, 'CanResellHandset')
end)

K.step('the phone command {string} should be registered on the server', 'server', function(_, name)
    for _, command in ipairs(GetRegisteredCommands()) do
        if command.name == name then return end
    end
    error('Server command /' .. name .. ' is not registered', 0)
end)

-- SendNotification only reaches the target player (server/main.lua).
K.step('the phone sends me the notification {string} with body {string}', 'server', function(ctx, title, body)
    local sent = K.export(RESOURCE, 'SendNotification', ctx.tester, { app = 'system', title = title, body = body })
    ctx:equal(sent, true, 'SendNotification result')
end)

K.step('the phone should refuse to send me a malformed notification', 'server', function(ctx)
    ctx:equal(K.export(RESOURCE, 'SendNotification', ctx.tester, 'not a table'), false, 'SendNotification result')
end)

-- ---------------------------------------------------------------------------
-- Client: open state
-- ---------------------------------------------------------------------------

local function isOpen() return K.export(RESOURCE, 'IsPhoneOpen') == true end

local function closeIfOpen()
    if GetResourceState(RESOURCE) ~= 'started' then return end
    pcall(function()
        if exports[RESOURCE]:IsPhoneOpen() then exports[RESOURCE]:ClosePhone() end
    end)
end

K.step('my phone is put away', 'client', function(ctx)
    ctx:cleanup(closeIfOpen)
    closeIfOpen()
    ctx:waitUntil(function() return not isOpen() end, 'The phone did not close', 3000)
end)

K.step('my phone should be put away', 'client', function(ctx)
    ctx:waitUntil(function() return not isOpen() end, 'The phone is still open', 8000)
end)

K.step('the phone command {string} should be registered on my client', 'client', function(_, name)
    for _, command in ipairs(GetRegisteredCommands()) do
        if command.name == name then return end
    end
    error('Client command /' .. name .. ' is not registered', 0)
end)

-- KoraPhone.Open answers true when the interface was told to open. Without a
-- handset the phone page then fails its bootstrap and closes itself.
K.step('I open the phone through its export', 'client', function(ctx)
    ctx:cleanup(closeIfOpen)
    ctx:equal(K.export(RESOURCE, 'OpenPhone'), true, 'OpenPhone result')
end)

K.step('opening the phone through its export should be refused', 'client', function(ctx)
    ctx:cleanup(closeIfOpen)
    ctx:equal(K.export(RESOURCE, 'OpenPhone'), false, 'OpenPhone result')
    ctx:equal(isOpen(), false, 'IsPhoneOpen')
end)

-- The same local state bag another resource sets while its own camera or editor
-- is up. Set without replication and restored afterwards.
K.step('another interface is blocking the phone', 'client', function(ctx)
    local previous = LocalPlayer.state[UI_BLOCK_BAG]
    ctx:cleanup(function() LocalPlayer.state:set(UI_BLOCK_BAG, previous, false) end)
    LocalPlayer.state:set(UI_BLOCK_BAG, true, false)
    ctx:waitUntil(function() return LocalPlayer.state[UI_BLOCK_BAG] == true end, 'The block bag was not set', 2000)
end)

K.step('I push the local phone notification {string} with message {string}', 'client', function(ctx, title, message)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { title = title, message = message }), true, 'PushNotification result')
end)

K.step('the phone should reject a local notification without a title', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { message = 'fft phone probe' }), false, 'PushNotification result')
end)

-- ---------------------------------------------------------------------------
-- Client: NUI routes (callback level, not the rendered phone page)
-- ---------------------------------------------------------------------------

local function route(_, name, body)
    assert(ROUTES[name], 'Phone route is not on the suite allow-list: ' .. tostring(name))
    -- Most routes answer after a server round trip (KoraPhone.ServerCallback in
    -- client/main.lua), so allow K.nui's longest wait. It raises when unanswered.
    local result = K.nui(RESOURCE, name, body or {}, 10000)
    assert(type(result) == 'table', 'The phone answered ' .. name .. ' with ' .. type(result))
    return result
end

local function describe(reply)
    local err = reply.error
    if type(err) == 'table' then return ('%s: %s'):format(tostring(err.code), tostring(err.message)) end
    return tostring(err)
end

K.step('I call the phone route {string}', 'client', function(ctx, name)
    ctx.state.phoneReply = route(ctx, name, {})
end)

K.step('I call the phone route {string} with:', 'client', function(ctx, name, argument)
    local body = K.json(argument)
    assert(type(body) == 'table', 'The route payload must be a JSON object')
    ctx.state.phoneReply = route(ctx, name, body)
end)

local function reply(ctx)
    return assert(ctx.state.phoneReply, 'Call a phone route first')
end

K.step('the phone route should be refused with code {string} and message {string}', 'client', function(ctx, code, message)
    local result = reply(ctx)
    if result.ok ~= false then error('The phone accepted the request', 0) end
    if type(result.error) ~= 'table' then error('Unexpected refusal: ' .. describe(result), 0) end
    ctx:equal(result.error.code, code, 'Error code')
    ctx:equal(result.error.message, message, 'Error message')
end)

K.step('the phone route should succeed', 'client', function(ctx)
    local result = reply(ctx)
    if result.ok ~= true then error('The phone refused the request: ' .. describe(result), 0) end
end)

-- phone:ready answers with KoraPhone.State.Public() (client/phone_state.lua).
K.step('the phone route should report a loaded character and a closed phone', 'client', function(ctx)
    local data = reply(ctx).data
    assert(type(data) == 'table', 'phone:ready returned no state')
    ctx:equal(data.playerLoaded, true, 'playerLoaded')
    ctx:equal(data.open, false, 'open')
end)

K.step('the phone route should report my current position', 'client', function(ctx)
    local data = reply(ctx).data
    assert(type(data) == 'table' and type(data.x) == 'number' and type(data.y) == 'number', 'location:mine returned no position')
    local at = GetEntityCoords(PlayerPedId())
    assert(math.abs(data.x - at.x) < 5.0 and math.abs(data.y - at.y) < 5.0,
        ('Reported %.1f, %.1f but the tester is at %.1f, %.1f'):format(data.x, data.y, at.x, at.y))
    assert(type(data.label) == 'string' and data.label ~= '', 'location:mine returned no label')
end)

K.step('the phone route should report the game clock and weather', 'client', function(ctx)
    local data = reply(ctx).data
    assert(type(data) == 'table', 'weather:get returned no data')
    assert(type(data.condition) == 'string' and data.condition ~= '', 'No weather condition')
    assert(type(data.hour) == 'number' and data.hour >= 0 and data.hour <= 23, 'Hour out of range: ' .. tostring(data.hour))
    assert(type(data.minute) == 'number' and data.minute >= 0 and data.minute <= 59, 'Minute out of range: ' .. tostring(data.minute))
end)

-- Config.Server.RateLimits.bootstrap is a bucket of 4 refilling at 0.5 per second
-- (config/server.lua). Every answer before the limit must be the handset refusal.
K.step('repeated phone bootstrap requests should end in a rate limit', 'client', function(ctx)
    for attempt = 1, 8 do
        local result = route(ctx, 'bootstrap', {})
        if result.ok ~= false or type(result.error) ~= 'table' then
            error(('Bootstrap attempt %d was not refused: %s'):format(attempt, describe(result)), 0)
        end
        if result.error.code == 'RATE_LIMITED' then
            ctx:equal(result.error.message, 'Too many requests', 'Rate limit message')
            return
        end
        ctx:equal(result.error.code, 'FORBIDDEN', 'Error code before the limit')
    end
    error('Eight bootstrap requests in a row were never rate limited', 0)
end)

-- ---------------------------------------------------------------------------
-- More route answers
-- ---------------------------------------------------------------------------

-- Client-only routes that answer { ok = false } with no error, e.g. calls:setMuted
-- (client/integrations/voice.lua) or camera:zoom while no camera is up (client/camera.lua).
K.step('the phone route should answer without success', 'client', function(ctx)
    local result = reply(ctx)
    ctx:equal(result.ok, false, 'ok')
    ctx:equal(result.error, nil, 'error')
end)

-- camera:open answers { ok = false, error = '<CODE>' } (client/nui.lua, client/camera.lua).
K.step('the phone route should be refused with the bare error {string}', 'client', function(ctx, code)
    local result = reply(ctx)
    ctx:equal(result.ok, false, 'ok')
    ctx:equal(result.error, code, 'error')
end)

-- Phone.lock in server/services/phone.lua answers PhoneResult({ locked = true }).
K.step('the phone route should report the phone locked', 'client', function(ctx)
    local result = reply(ctx)
    if result.ok ~= true then error('The phone refused the request: ' .. describe(result), 0) end
    ctx:equal(type(result.data) == 'table' and result.data.locked, true, 'data.locked')
end)

-- Config.PhoneServices.shops in kora_phone-stevie/config/handsets.lua (only the
-- fields the steps check; every shop uses distance 2.0 and the same prices).
local SHOPS = {
    legion = { x = 127.4, y = -1029.2, z = 29.4, label = 'Circuit Mobile', business = false },
    digitalDenVinewood = { x = -509.49, y = 278.57, z = 83.32, label = 'Circuit Mobile', business = false },
    digitalDenMirrorPark = { x = 1137.82, y = -470.77, z = 66.67, label = 'Circuit Mobile', business = false },
    digitalDenSinnerSt = { x = 392.61, y = -831.76, z = 29.29, label = 'Circuit Mobile', business = false },
    technician = { x = -40.1, y = -1090.7, z = 26.4, label = 'Mobile Workshop', business = true },
}
local SHOP_REACH = 2.0
local PHONE_STANDARD_PRICE = 1200

local function statusData(ctx)
    local result = reply(ctx)
    if result.ok ~= true then error('handset:action status was refused: ' .. describe(result), 0) end
    assert(type(result.data) == 'table', 'handset:action status returned no data')
    return result.data
end

-- H.action in server/phone_commerce.lua: status without a held handset.
K.step('the handset status should describe a character without a handset', 'client', function(ctx)
    local data = statusData(ctx)
    ctx:equal(type(data.handset) == 'table' and data.handset.id, '', 'handset.id')
    ctx:equal(type(data.handset) == 'table' and data.handset.model, 'standard', 'handset.model')
    ctx:equal(data.cellular, false, 'cellular')
    ctx:equal(data.number, '', 'number')
    for _, key in ipairs({ 'phones', 'sims', 'hotspots' }) do
        ctx:equal(type(data[key]) == 'table' and #data[key] or ('not a list: ' .. type(data[key])), 0, key)
    end
    ctx:equal(data.simSwap, 'both', 'simSwap (Config.SimSwap in config/handsets.lua)')
    assert(type(data.accounts) == 'table', 'status returned no cloud account list')
    assert(type(data.shops) == 'table', 'status returned no shop list')
    for _, shop in ipairs(data.shops) do
        assert(type(shop) == 'table' and SHOPS[shop.id], 'status listed an unknown shop: ' .. tostring(shop and shop.id))
    end
end)

K.step('the handset status should list the {string} phone shop', 'client', function(ctx, id)
    local expected = assert(SHOPS[id], 'Unknown phone shop: ' .. tostring(id))
    local listed = {}
    for _, shop in ipairs(statusData(ctx).shops or {}) do
        listed[#listed + 1] = tostring(shop.id)
        if shop.id == id then
            ctx:equal(shop.label, expected.label, 'shop label')
            ctx:equal(shop.business, expected.business, 'shop business flag')
            ctx:equal(type(shop.prices) == 'table' and shop.prices.phone_standard, PHONE_STANDARD_PRICE, 'phone_standard price')
            return
        end
    end
    error(('status did not list the %s shop (listed: %s)'):format(id, #listed > 0 and table.concat(listed, ', ') or 'none'), 0)
end)

-- near() in server/phone_commerce.lua measures the server's view of the ped, which
-- lags a client teleport, so wait until the server agrees before asking.
K.step('the server should see me within reach of the {string} phone shop', 'server', function(ctx, id)
    local shop = assert(SHOPS[id], 'Unknown phone shop: ' .. tostring(id))
    local last
    ctx:waitUntil(function()
        local ped = GetPlayerPed(ctx.tester)
        if not ped or ped == 0 then return false end
        last = GetEntityCoords(ped)
        return (last.x - shop.x) ^ 2 + (last.y - shop.y) ^ 2 + (last.z - shop.z) ^ 2 <= SHOP_REACH ^ 2
    end, 'The server does not place the tester at the ' .. id .. ' counter', 6000, function()
        return last and (' | server position %.2f %.2f %.2f'):format(last.x, last.y, last.z) or ''
    end)
end)

-- ---------------------------------------------------------------------------
-- Server notifications
-- ---------------------------------------------------------------------------

K.step('the phone should refuse a notification addressed to {string}', 'server', function(ctx, target)
    local sent = K.export(RESOURCE, 'SendNotification', target, { app = 'system', title = 'FFT probe', body = 'fft phone probe' })
    ctx:equal(sent, false, 'SendNotification result')
end)

-- SendNotification cuts the body to 240 characters (server/main.lua).
K.step('the phone sends me the notification {string} with a {int} character body ending in {string}', 'server', function(ctx, title, length, tail)
    assert(length > #tail and length <= 1000, 'Body length must exceed the tail and stay under 1000')
    local body = ('x'):rep(length - #tail) .. tail
    ctx:equal(K.export(RESOURCE, 'SendNotification', ctx.tester, { app = 'system', title = title, body = body }), true, 'SendNotification result')
end)

-- ---------------------------------------------------------------------------
-- Client notifications (client/notifications.lua)
-- ---------------------------------------------------------------------------

K.step('I push the urgent local phone notification {string} with message {string}', 'client', function(ctx, title, message)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { title = title, message = message, urgent = true }), true, 'PushNotification result')
end)

-- native = false keeps the notification inside the phone page only.
K.step('I push the silent local phone notification {string} with message {string}', 'client', function(ctx, title, message)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { title = title, message = message, native = false }), true, 'PushNotification result')
end)

-- valid(): title string of at most 80, message nil or a string of at most 500.
K.step('the phone should accept a local notification with a {int} character title', 'client', function(ctx, length)
    local title = ('FFT title probe '):rep(10):sub(1, length)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { title = title, message = 'fft title length probe' }), true, 'PushNotification result')
end)

K.step('the phone should reject a local notification with a {int} character title', 'client', function(ctx, length)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { title = ('t'):rep(length), message = 'fft phone probe' }), false, 'PushNotification result')
end)

K.step('the phone should reject a local notification with a {int} character message', 'client', function(ctx, length)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { title = 'FFT probe', message = ('m'):rep(length) }), false, 'PushNotification result')
end)

K.step('the phone should reject a local notification whose message is a number', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'PushNotification', { title = 'FFT probe', message = 42 }), false, 'PushNotification result')
end)

-- The 'quiet' NUI route sets KoraPhone.State.quiet (client/nui.lua). The value
-- cannot be read back, so cleanup always turns it off again.
K.step('my phone is set to Do Not Disturb', 'client', function(ctx)
    ctx:cleanup(function() pcall(K.nui, RESOURCE, 'quiet', { quiet = false }, 3000) end)
    local result = route(ctx, 'quiet', { quiet = true })
    if result.ok ~= true then error('The phone refused Do Not Disturb: ' .. describe(result), 0) end
end)

-- client/nui.lua phone:close shows data.error cut to 120 characters.
K.step('the phone page closes with a {int} character error ending in {string}', 'client', function(ctx, length, tail)
    assert(length > #tail and length <= 500, 'Error length must exceed the tail and stay under 500')
    local text = ('fft close probe '):rep(40):sub(1, length - #tail) .. tail
    ctx.state.phoneReply = route(ctx, 'phone:close', { error = text })
end)

-- Local handlers for events the server normally sends (client/compat.lua and
-- client/notifications.lua). Both only push a notification; neither moves money.
K.step('the legacy phone bank event reports {int} removed', 'client', function(_, amount)
    TriggerEvent('qb-phone:client:RemoveBankMoney', amount)
end)

K.step('the phone hears that {string} showed me their ID', 'client', function(_, name)
    TriggerEvent('kora_phone:client:wallet:shown', { name = name, birthdate = '1990-01-01', licences = { { label = 'Driver', valid = true } } })
end)

K.step('the phone hears an ID card from {string} without licences', 'client', function(_, name)
    TriggerEvent('kora_phone:client:wallet:shown', { name = name, birthdate = '1990-01-01' })
end)

-- /phonereset (server/main.lua) answers with QBCore:Notify: "No permission" for a
-- non-moderator, otherwise "No phone found for player <id>" without a handset.
-- Either answer means nothing was reset.
K.step('the phone reset should answer {string} or {string}', 'client', function(ctx, first, second)
    ctx:waitUntil(function()
        for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            for _, text in ipairs({ first, second }) do
                if K.contains(entry.message, text) or K.contains(entry.title, text) then return true end
            end
        end
    end, ('No notification containing "%s" or "%s"'):format(first, second), 6000)
end)

-- ---------------------------------------------------------------------------
-- Client routes with local side effects
-- ---------------------------------------------------------------------------

K.step('the phone call speaker is switched off afterwards', 'client', function(ctx)
    ctx:cleanup(function() pcall(K.nui, RESOURCE, 'calls:setSpeaker', { speaker = false }, 3000) end)
end)

local function closeCamera() pcall(K.nui, RESOURCE, 'camera:close', {}, 3000) end

-- camera:open creates a scripted camera when it is allowed, so close it whatever happens.
K.step('I try to open the phone camera', 'client', function(ctx)
    ctx:cleanup(closeCamera)
    ctx.state.phoneReply = route(ctx, 'camera:open', {})
end)

local function waypoint()
    local blip = GetFirstBlipInfoId(8)
    if DoesBlipExist(blip) then return GetBlipInfoIdCoord(blip) end
end

K.step('my map waypoint is restored afterwards', 'client', function(ctx)
    local previous = waypoint()
    ctx:cleanup(function()
        if previous then SetNewWaypoint(previous.x, previous.y)
        elseif IsWaypointActive() then SetWaypointOff() end
    end)
end)

K.step('my map waypoint should be at {int} {int}', 'client', function(ctx, x, y)
    local last
    ctx:waitUntil(function()
        last = waypoint()
        return last and math.abs(last.x - x) < 1.5 and math.abs(last.y - y) < 1.5
    end, ('No map waypoint at %d, %d'):format(x, y), 3000, function()
        return last and (' | waypoint at %.1f, %.1f'):format(last.x, last.y) or ' | no waypoint'
    end)
end)

-- location:mine reports the waypoint rounded to whole metres (client/nui.lua).
K.step('the phone route should report a waypoint at {int} {int}', 'client', function(ctx, x, y)
    local data = reply(ctx).data
    assert(type(data) == 'table' and type(data.waypoint) == 'table', 'location:mine reported no waypoint')
    ctx:equal(data.waypoint.x, x, 'waypoint.x')
    ctx:equal(data.waypoint.y, y, 'waypoint.y')
end)

-- ---------------------------------------------------------------------------
-- Custom apps (client/customapps.lua)
-- ---------------------------------------------------------------------------

local function removeApp(id)
    if GetResourceState(RESOURCE) ~= 'started' then return end
    pcall(function() exports[RESOURCE]:RemoveApp(id) end)
end

local function customApps(ctx)
    local list = route(ctx, 'customList', {})
    local found = {}
    for _, app in pairs(list) do
        if type(app) == 'table' and app.identifier then found[app.identifier] = app end
    end
    return found
end

local openedApps = {}

K.step('I register the custom phone app {string} with ui {string}', 'client', function(ctx, id, ui)
    ctx:cleanup(function() removeApp(id) end)
    ctx:equal(K.export(RESOURCE, 'RegisterApp', { identifier = id, name = 'FFT probe app', ui = ui }), true, 'RegisterApp result')
end)

K.step('I register the custom phone app {string} for the job {string}', 'client', function(ctx, id, job)
    ctx:cleanup(function() removeApp(id) end)
    ctx:equal(K.export(RESOURCE, 'RegisterApp', { identifier = id, name = 'FFT job app', ui = 'fft_probe/index.html', job = job }), true, 'RegisterApp result')
end)

-- The lifecycle callbacks run when the phone page reports customLifecycle.
K.step('I register the custom phone app {string} that records being opened', 'client', function(ctx, id)
    openedApps[id] = nil
    ctx:cleanup(function() removeApp(id); openedApps[id] = nil end)
    local registered = K.export(RESOURCE, 'RegisterApp', {
        identifier = id, name = 'FFT lifecycle app', ui = 'fft_probe/index.html',
        onOpen = function() openedApps[id] = true end,
    })
    ctx:equal(registered, true, 'RegisterApp result')
end)

K.step('the custom phone app {string} should have recorded being opened', 'client', function(ctx, id)
    ctx:waitUntil(function() return openedApps[id] == true end, 'The onOpen callback of ' .. id .. ' never ran', 3000)
end)

K.step('the custom phone app list should include {string} with ui {string}', 'client', function(ctx, id, ui)
    local app = customApps(ctx)[id]
    assert(app, 'customList does not include ' .. id)
    ctx:equal(app.ui, ui, 'ui')
end)

K.step('the custom phone app list should not include {string}', 'client', function(ctx, id)
    if customApps(ctx)[id] then error('customList still includes ' .. id, 0) end
end)

K.step('I send the custom phone app {string} a message', 'client', function(ctx, id)
    ctx:equal(K.export(RESOURCE, 'SendAppMessage', id, { probe = 'fft' }), true, 'SendAppMessage result')
end)

K.step('I remove the custom phone app {string}', 'client', function(ctx, id)
    ctx:equal(K.export(RESOURCE, 'RemoveApp', id), true, 'RemoveApp result')
end)

K.step('the phone should refuse a custom app without an identifier', 'client', function(ctx)
    local ok, err = K.export(RESOURCE, 'RegisterApp', { identifier = '', ui = 'fft_probe/index.html' })
    ctx:equal(ok, false, 'RegisterApp result')
    ctx:equal(err, 'INVALID_APP', 'RegisterApp error')
end)

K.step('the phone should refuse the custom app {string} without a ui', 'client', function(ctx, id)
    ctx:cleanup(function() removeApp(id) end)
    local ok, err = K.export(RESOURCE, 'RegisterApp', { identifier = id, name = 'FFT probe app' })
    ctx:equal(ok, false, 'RegisterApp result')
    ctx:equal(err, 'INVALID_UI', 'RegisterApp error')
end)

K.step('removing the unknown custom phone app {string} should be refused', 'client', function(ctx, id)
    local ok, err = K.export(RESOURCE, 'RemoveApp', id)
    ctx:equal(ok, false, 'RemoveApp result')
    ctx:equal(err, 'NOT_FOUND', 'RemoveApp error')
end)

K.step('a message to the unknown custom phone app {string} should be refused', 'client', function(ctx, id)
    local ok, err = K.export(RESOURCE, 'SendAppMessage', id, { probe = 'fft' })
    ctx:equal(ok, false, 'SendAppMessage result')
    ctx:equal(err, 'NOT_FOUND', 'SendAppMessage error')
end)

-- The lb-phone alias exports (client/customapps.lua alias(); fxmanifest provide 'lb-phone').
K.step('I register the custom phone app {string} through the lb-phone exports', 'client', function(ctx, id)
    ctx:cleanup(function() removeApp(id) end)
    local ok, result = pcall(function()
        return exports['lb-phone']:AddCustomApp({ identifier = id, name = 'FFT alias app', ui = 'fft_probe/index.html' })
    end)
    if not ok then error('lb-phone AddCustomApp failed: ' .. tostring(result), 0) end
    ctx:equal(result, true, 'AddCustomApp result')
end)

K.step('I remove the custom phone app {string} through the lb-phone exports', 'client', function(ctx, id)
    local ok, result = pcall(function() return exports['lb-phone']:RemoveCustomApp(id) end)
    if not ok then error('lb-phone RemoveCustomApp failed: ' .. tostring(result), 0) end
    ctx:equal(result, true, 'RemoveCustomApp result')
end)

-- ---------------------------------------------------------------------------
-- Map blips (client/map.lua)
-- ---------------------------------------------------------------------------

K.step('I add a probe blip at {int} {int} to the phone map titled {string}', 'client', function(ctx, x, y, title)
    local blip = AddBlipForCoord(x + 0.0, y + 0.0, 30.0)
    ctx:cleanup(function()
        if GetResourceState(RESOURCE) == 'started' then pcall(function() exports[RESOURCE]:UnregisterMapBlip(blip) end) end
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
    assert(DoesBlipExist(blip), 'Could not create the probe blip')
    SetBlipDisplay(blip, 2)
    SetBlipAlpha(blip, 255)
    ctx.state.phoneBlip = blip
    ctx:equal(K.export(RESOURCE, 'RegisterMapBlip', blip, title), true, 'RegisterMapBlip result')
end)

local function probeBlip(ctx) return assert(ctx.state.phoneBlip, 'Add a probe blip first') end

local function mapEntry(ctx)
    local result = route(ctx, 'map:blips', {})
    if result.ok ~= true then error('map:blips was refused: ' .. describe(result), 0) end
    for _, entry in pairs(result.data or {}) do
        if type(entry) == 'table' and entry.id == probeBlip(ctx) then return entry end
    end
end

K.step('the phone map should list the probe blip titled {string}', 'client', function(ctx, title)
    local entry = mapEntry(ctx)
    assert(entry, 'map:blips does not list the probe blip')
    ctx:equal(entry.label, title, 'label')
end)

K.step('the phone map should not list the probe blip', 'client', function(ctx)
    -- Map.Blips only lists blips with a title from RegisterMapBlip or kora_lib's blip registry.
    local entry = mapEntry(ctx)
    if entry then error('map:blips still lists the probe blip as ' .. tostring(entry.label), 0) end
end)

K.step('I remove the probe blip from the phone map', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'UnregisterMapBlip', probeBlip(ctx)), true, 'UnregisterMapBlip result')
end)

K.step('the phone map should refuse the probe blip with a blank title', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'RegisterMapBlip', probeBlip(ctx), '   '), false, 'RegisterMapBlip result')
end)

K.step('the phone map should refuse the probe blip with a {int} character title', 'client', function(ctx, length)
    ctx:equal(K.export(RESOURCE, 'RegisterMapBlip', probeBlip(ctx), ('b'):rep(length)), false, 'RegisterMapBlip result')
end)

K.step('the phone map should refuse a blip that does not exist', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'RegisterMapBlip', 0, 'FFT missing blip'), false, 'RegisterMapBlip result')
end)

K.step('removing an unknown blip from the phone map should be refused', 'client', function(ctx)
    ctx:equal(K.export(RESOURCE, 'UnregisterMapBlip', 0), false, 'UnregisterMapBlip result')
end)
