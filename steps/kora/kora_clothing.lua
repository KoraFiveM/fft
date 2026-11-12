-- kora_clothing: clothing shops, wardrobe and the private fitting room.
--
-- The fitting room is a NUI page. Sessions are opened through the public
-- exports (OpenClothingRoom / OpenWardrobe, the same openSession path the shop
-- prompt and target option call). The page's own callbacks (RegisterNUICallback
-- in kora_clothing/client/client.lua) are run with a real fetch through K.nui,
-- with the bodies web/src/App.tsx posts; kora_clothing/fft_hooks.lua only
-- observes what the page is sent. Authoritative checks are made on
-- the server: money through kora_core, the routing bucket, and the
-- playerskins / playeroutfits rows through kora_clothing/fft_hooks_server.lua.
--
-- Cleanup, in every scenario that opens a session:
--   * an open session is cancelled,
--   * the ped's components and props are set back to what it wore before,
--   * the saved appearance row is rewritten exactly as it was (or removed if
--     the character had none) and outfits named "fft-..." are deleted.
-- Only clothing sessions are opened; barber, tattoo, first-character and admin
-- sessions are not driven.
local K = FFT.kora
if not K then return end
K.feature('kora_clothing')

local CLOTHING = 'kora_clothing'
local NUI = 'kora_clothing:nui:'
local BUCKET_BASE = 1000000 -- Config.bucket.base in kora_clothing/config.lua
local JACKET = 11 -- Shared.components[11] = 'Jackets', category 'tops'
local OUTFIT_PREFIX = 'fft-' -- the only names fft_hooks_server.lua will delete

-- ---------------------------------------------------------------------------
-- Client helpers
-- ---------------------------------------------------------------------------
local function hook(action, ...) return K.hook(CLOTHING, action, ...) end
local function isOpen() return K.export(CLOTHING, 'IsClothingMenuOpen') == true end

-- The page callbacks this suite runs, each a `sendIntent` in web/src/App.tsx.
local PAGE_CALLBACKS = {
    setVariation = true, camera = true, deleteOutfit = true, confirm = true, cancel = true,
    loadOutfit = true, setTattoos = true, setUndress = true, setClothingToggle = true,
    setHairColor = true, setHead = true, rotateStart = true, recenter = true,
}

-- K.nui raises when the callback is not answered.
local function nui(name, body)
    assert(PAGE_CALLBACKS[name], 'Fitting room callback is not on the suite allow-list: ' .. tostring(name))
    local result = K.nui(CLOTHING, NUI .. name, body or {})
    return type(result) == 'table' and result or {}
end

---Cancels an open session and waits for it to end. Never raises, so it is safe
---in cleanup; it stays inside the 5 s cleanup limit. kora_clothing:nui:cancel
---sends kora_clothing:server:cancelSession and the server answers with
---kora_clothing:client:closeSession (client/client.lua).
local function closeSession()
    pcall(function()
        if not exports[CLOTHING]:IsClothingMenuOpen() then return end
        pcall(K.nui, CLOTHING, NUI .. 'cancel', {}, 2000)
        local deadline = GetGameTimer() + 2000
        while exports[CLOTHING]:IsClothingMenuOpen() and GetGameTimer() < deadline do Wait(50) end
    end)
end

local function mark(ctx)
    local state = hook('state')
    assert(type(state) == 'table' and state.wrapped == true, 'kora_clothing FFT hook could not observe SendNUIMessage')
    ctx.state.clothingSeq = state.sequence or 0
end

local function messages(ctx, action)
    local entries = hook('log', ctx.state.clothingSeq or 0, NUI .. action)
    return type(entries) == 'table' and entries or {}
end

local function waitMessage(ctx, action, timeout)
    return ctx:waitUntil(function()
        local entries = messages(ctx, action)
        return entries[#entries]
    end, ('The fitting room page was not sent "%s%s"'):format(NUI, action), timeout or 8000)
end

local function openPayload(ctx)
    local data = waitMessage(ctx, 'open').data
    assert(type(data) == 'table', 'The open message carried no data')
    return data
end

local COMPONENT_IDS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROP_IDS = { 0, 1, 2, 6, 7 }

local function wearing()
    local ped = PlayerPedId()
    local look = { model = GetEntityModel(ped), components = {}, props = {} }
    for _, id in ipairs(COMPONENT_IDS) do
        look.components[id] = { GetPedDrawableVariation(ped, id), GetPedTextureVariation(ped, id), GetPedPaletteVariation(ped, id) }
    end
    for _, id in ipairs(PROP_IDS) do
        look.props[id] = { GetPedPropIndex(ped, id), GetPedPropTextureIndex(ped, id) }
    end
    return look
end

local function wear(look)
    local ped = PlayerPedId()
    if GetEntityModel(ped) ~= look.model then
        RequestModel(look.model)
        local deadline = GetGameTimer() + 5000
        while not HasModelLoaded(look.model) and GetGameTimer() < deadline do Wait(50) end
        if not HasModelLoaded(look.model) then return end
        SetPlayerModel(PlayerId(), look.model)
        SetModelAsNoLongerNeeded(look.model)
        ped = PlayerPedId()
    end
    for id, entry in pairs(look.components) do SetPedComponentVariation(ped, id, entry[1], entry[2], entry[3]) end
    for id, entry in pairs(look.props) do
        if entry[1] >= 0 then SetPedPropIndex(ped, id, entry[1], entry[2], true) else ClearPedProp(ped, id) end
    end
end

local function hudVisible()
    if GetResourceState('kora_hud') ~= 'started' then return nil end
    return exports.kora_hud:isVisible() == true
end

---Records the look and registers the cleanup once per scenario.
local function guard(ctx)
    if ctx.state.clothingLook then return end
    -- A session left open by an earlier failure is cancelled rather than
    -- failing every scenario that follows.
    if isOpen() then closeSession() end
    assert(not isOpen(), 'A fitting room session is already open and could not be cancelled')
    ctx.state.clothingLook = wearing()
    ctx.state.clothingHud = hudVisible()
    local look = ctx.state.clothingLook
    ctx:cleanup(function()
        closeSession()
        pcall(wear, look)
    end)
end

local function waitOpen(ctx)
    ctx:waitUntil(isOpen, 'The fitting room did not open (see the notifications for a refusal)', 10000)
    -- Opening applies the saved appearance, which is what Cancel goes back to.
    ctx.state.clothingOpenJacket = GetPedDrawableVariation(PlayerPedId(), JACKET)
    ctx.state.clothingOpenLook = wearing()
end

local function waitClosed(ctx)
    ctx:waitUntil(function() return not isOpen() end, 'The fitting room did not close', 10000)
end

-- ---------------------------------------------------------------------------
-- Opening and closing
-- ---------------------------------------------------------------------------
K.step('the fitting room hooks should be version {int}', 'client', function(ctx, version)
    ctx:equal(K.export(CLOTHING, 'fftVersion'), version, 'kora_clothing fftVersion')
end)

K.step('I open the clothing shop {int}', 'client', function(ctx, shopId)
    guard(ctx)
    mark(ctx)
    K.export(CLOTHING, 'OpenClothingRoom', { shopId = shopId })
    waitOpen(ctx)
end)
K.step('I ask to open the clothing shop {int}', 'client', function(ctx, shopId)
    guard(ctx)
    mark(ctx)
    K.export(CLOTHING, 'OpenClothingRoom', { shopId = shopId })
end)
K.step('I open my wardrobe', 'client', function(ctx)
    guard(ctx)
    mark(ctx)
    K.export(CLOTHING, 'OpenWardrobe')
    waitOpen(ctx)
end)

K.step('the fitting room should not open', 'client', function(ctx)
    local deadline = GetGameTimer() + 2000
    while GetGameTimer() < deadline do
        ctx:check()
        assert(not isOpen(), 'The fitting room opened')
        Wait(100)
    end
    ctx:equal(#messages(ctx, 'open'), 0, 'Open messages sent to the page')
end)
K.step('the fitting room should still be open', 'client', function(ctx)
    Wait(750)
    ctx:equal(isOpen(), true, 'Fitting room open')
end)
K.step('the fitting room should close', 'client', function(ctx)
    waitClosed(ctx)
    waitMessage(ctx, 'close', 3000)
    ctx:waitUntil(function() return not IsNuiFocused() end, 'NUI focus was not released', 3000)
end)

K.step('I cancel the fitting', 'client', function(ctx)
    ctx:equal(nui('cancel').ok, true, 'cancel answer')
end)
K.step('I confirm the fitting', 'client', function(ctx)
    ctx:equal(nui('confirm', {}).ok, true, 'confirm answer')
end)
K.step('I confirm the fitting and save it as {string}', 'client', function(ctx, name)
    assert(name:sub(1, #OUTFIT_PREFIX) == OUTFIT_PREFIX, 'Test outfit names must start with ' .. OUTFIT_PREFIX)
    ctx:equal(nui('confirm', { saveName = name }).ok, true, 'confirm answer')
end)

-- ---------------------------------------------------------------------------
-- What the page is told when a session opens
-- ---------------------------------------------------------------------------
K.step('the fitting room should have opened as a {string} session for the {string} service', 'client', function(ctx, mode, service)
    local data = openPayload(ctx)
    ctx:equal(data.mode, mode, 'Session mode')
    ctx:equal(data.service, service, 'Session service')
    ctx:equal(data.mandatory, false, 'Mandatory session')
    assert((data.categoryCount or 0) > 0, 'The page was given no clothing categories')
end)
K.step('the fitting room should be for the shop {string}', 'client', function(ctx, label)
    ctx:equal(openPayload(ctx).shopLabel, label, 'Shop label')
end)
K.step('the fitting room should price {string} at {int} in {string}', 'client', function(ctx, category, price, currency)
    local data = openPayload(ctx)
    ctx:equal(data.free, false, 'Free session')
    ctx:equal(data.currency, currency, 'Currency')
    ctx:equal(type(data.prices) == 'table' and data.prices[category] or nil, price, 'Price of ' .. category)
end)
K.step('the fitting room camera should be active with the page focused', 'client', function(ctx)
    local state
    local ok = pcall(function()
        ctx:waitUntil(function()
            state = hook('state')
            return type(state) == 'table' and state.cameraActive == true and state.focused == true
        end, 'not ready', 5000)
    end)
    if ok then return end
    ctx:check()
    state = type(state) == 'table' and state or {}
    -- Camera.isActive() in client/camera.lua; IsNuiFocused() after client.lua's SetNuiFocus(true, true).
    error(('The fitting room is not ready: camera active %s, NUI focused %s, session open %s')
        :format(tostring(state.cameraActive), tostring(state.focused), tostring(isOpen())), 0)
end)
K.step('I point the fitting room camera at {string}', 'client', function(ctx, zone)
    ctx:equal(nui('camera', { zone = zone }).zone, zone, 'Camera zone')
end)
K.step('the fitting room camera should be released', 'client', function(ctx)
    ctx:waitUntil(function()
        local state = hook('state')
        return type(state) == 'table' and state.cameraActive == false
    end, 'The fitting camera is still active', 5000)
end)

-- kora_clothing hides a visible kora_hud for the session and shows it again.
K.step('the HUD should be hidden for the fitting', 'client', function(ctx)
    if hudVisible() == nil then return end
    ctx:waitUntil(function() return hudVisible() == false end, 'kora_hud is still visible during the fitting', 5000)
end)
K.step('the HUD should be as it was before the fitting', 'client', function(ctx)
    local before = ctx.state.clothingHud
    if before == nil or hudVisible() == nil then return end
    ctx:waitUntil(function() return hudVisible() == before end,
        'kora_hud visibility was not restored to ' .. tostring(before), 5000)
end)

-- ---------------------------------------------------------------------------
-- Trying clothes on
-- ---------------------------------------------------------------------------
K.step('I try on a different jacket', 'client', function(ctx)
    assert(isOpen(), 'Open a fitting room first')
    local ped = PlayerPedId()
    local current = GetPedDrawableVariation(ped, JACKET)
    local count = GetNumberOfPedDrawableVariations(ped, JACKET)
    assert(count > 1, 'This ped model has no second jacket to try on')
    local drawable = (current + 1) % count
    local answer = nui('setVariation', { kind = 'component', id = JACKET, drawable = drawable, texture = 0 })
    ctx:equal(answer.ok, true, 'setVariation answer')
    ctx:equal(GetPedDrawableVariation(PlayerPedId(), JACKET), drawable, 'Jacket drawable on the ped')
    ctx.state.clothingTried = drawable
end)
K.step('I should be wearing the jacket the fitting started with', 'client', function(ctx)
    local before = assert(ctx.state.clothingOpenJacket, 'Open a fitting room first')
    ctx:waitUntil(function() return GetPedDrawableVariation(PlayerPedId(), JACKET) == before end,
        'The tried-on jacket was not taken off again', 5000)
end)
K.step('I should be wearing the jacket I tried on', 'client', function(ctx)
    local tried = assert(ctx.state.clothingTried, 'Try on a jacket first')
    Wait(500)
    ctx:equal(GetPedDrawableVariation(PlayerPedId(), JACKET), tried, 'Jacket drawable on the ped')
end)

K.step('the fitting room should report an error', 'client', function(ctx)
    local entry = waitMessage(ctx, 'error', 8000)
    local message = type(entry.data) == 'table' and entry.data.message or nil
    assert(type(message) == 'string' and #message > 0, 'The error message is empty')
end)
K.step('the fitting room should not report an error', 'client', function(ctx)
    ctx:equal(#messages(ctx, 'error'), 0, 'Error messages sent to the page')
end)

-- client.lua's handlers answer { ok = false } when no session is open. The
-- bodies are the shapes web/src/App.tsx posts to each callback.
local REFUSED_WITHOUT_SESSION = {
    setVariation = { kind = 'component', id = JACKET, drawable = 0, texture = 0 },
    confirm = {}, cancel = {},
    loadOutfit = { id = 1 },
    setTattoos = { tattoos = { 'hipster_anchor' } }, -- Config.tattoos id
    setUndress = { part = 'top', undressed = true }, -- Config.tattoo.undress.parts id
    setClothingToggle = { id = 'shirt', removed = true }, -- TOGGLE_ORDER in client.lua
    setHairColor = { color = 1, highlight = 1 },
    setHead = { skinTone = 1 },
}
K.step('the fitting room page should be refused {string} without a session', 'client', function(ctx, name)
    local body = REFUSED_WITHOUT_SESSION[name]
    assert(body, 'Unsupported callback: ' .. name)
    assert(not isOpen(), 'A fitting room session is open')
    ctx:equal(nui(name, body).ok, false, name .. ' answer')
end)

-- ---------------------------------------------------------------------------
-- Saved outfits (page side)
-- ---------------------------------------------------------------------------
local function outfitIn(list, name)
    for _, row in pairs(type(list) == 'table' and list or {}) do
        if type(row) == 'table' and (row.outfitname == name or row.name == name) then return row end
    end
end

K.step('the fitting room should list the saved outfit {string}', 'client', function(ctx, name)
    assert(outfitIn(openPayload(ctx).outfits, name), 'The page was not given the outfit ' .. name)
end)
K.step('I delete the saved outfit {string} in the fitting room', 'client', function(ctx, name)
    assert(name:sub(1, #OUTFIT_PREFIX) == OUTFIT_PREFIX, 'Only test outfits may be deleted')
    local row = assert(outfitIn(openPayload(ctx).outfits, name), 'The page was not given the outfit ' .. name)
    nui('deleteOutfit', { id = assert(tonumber(row.id), 'Outfit has no id') })
    ctx:waitUntil(function()
        local updates = messages(ctx, 'outfits')
        local latest = updates[#updates]
        return latest and not outfitIn(latest.data, name)
    end, 'The page was not sent an outfit list without ' .. name, 8000)
end)
K.step('the legacy outfit list should include {string}', 'client', function(_, name)
    local _, rows = K.must(hook('outfits'))
    assert(outfitIn(rows, name), 'qb-clothing:server:getOutfits does not list ' .. name)
end)

-- A paid session only charges a character that has a saved appearance: without
-- one the first confirm is a free sync (server.lua, confirmSession). This step
-- makes that sync happen through the wardrobe when the row is missing. It must
-- come after "my saved appearance and outfits are put back after the
-- scenario", which removes the row again.
K.step('my appearance is on record with the server', 'client', function(ctx)
    local _, saved = K.must(hook('savedSkin'))
    if type(saved) == 'table' and saved.exists then return end
    guard(ctx)
    mark(ctx)
    K.export(CLOTHING, 'OpenWardrobe')
    waitOpen(ctx)
    ctx:equal(nui('confirm', {}).ok, true, 'confirm answer')
    waitClosed(ctx)
    local _, after = K.must(hook('savedSkin'))
    assert(type(after) == 'table' and after.exists, 'The wardrobe confirm did not record an appearance')
end)

-- ---------------------------------------------------------------------------
-- Idle surface
-- ---------------------------------------------------------------------------
K.step('the clothing exports should report no fitting in progress', 'client', function(ctx)
    -- A session left open by an earlier failed scenario is not what this asserts.
    if not ctx.state.clothingLook and isOpen() then closeSession() end
    ctx:equal(K.export(CLOTHING, 'IsClothingMenuOpen'), false, 'IsClothingMenuOpen')
    ctx:equal(K.export(CLOTHING, 'IsCreatingCharacter'), false, 'IsCreatingCharacter')
end)
K.step('the clothing exports should name the ped models {string} and {string}', 'client', function(ctx, male, female)
    local models = K.export(CLOTHING, 'GetPedModels')
    assert(type(models) == 'table', 'GetPedModels answered with ' .. type(models))
    ctx:equal(models.male, male, 'Male model')
    ctx:equal(models.female, female, 'Female model')
end)
K.step('the clothing shop prompt should offer {string}', 'client', function(ctx, text)
    local state = hook('state')
    assert(type(state) == 'table' and state.interactionMode == 'textui',
        'Config.interactionMode is ' .. tostring(type(state) == 'table' and state.interactionMode)
        .. '; this scenario covers the text prompt mode')
    ctx:waitUntil(function()
        local prompt = K.uiState().textui
        return type(prompt) == 'table' and K.contains(prompt.text, text)
    end, 'Text prompt does not show "' .. text .. '"', 8000)
end)

-- ---------------------------------------------------------------------------
-- Server: saved rows, bucket, admin export
-- ---------------------------------------------------------------------------
local function savedSkin(ctx)
    local _, row = K.must(K.hook(CLOTHING, 'skin', ctx.tester))
    assert(type(row) == 'table', 'The saved appearance could not be read')
    return row
end

local function sameSkin(a, b)
    return a.exists == b.exists and a.model == b.model and a.skin == b.skin
end

local function savedOutfit(ctx, name)
    local _, rows = K.must(K.hook(CLOTHING, 'outfits', ctx.tester))
    for _, row in ipairs(type(rows) == 'table' and rows or {}) do
        if row.name == name then return row end
    end
end

K.step('my saved appearance and outfits are put back after the scenario', 'server', function(ctx)
    local tester = ctx.tester
    local snapshot = savedSkin(ctx)
    ctx.state.clothingSnapshotTaken, ctx.state.clothingSnapshot = true, snapshot
    K.must(K.hook(CLOTHING, 'deleteTestOutfits', tester))
    ctx:cleanup(function()
        pcall(function() exports[CLOTHING]:fftAction('restoreSkin', tester, snapshot) end)
        pcall(function() exports[CLOTHING]:fftAction('deleteTestOutfits', tester) end)
    end)
end)
K.step('I remember my saved appearance', 'server', function(ctx)
    ctx.state.clothingSaved = savedSkin(ctx)
end)
K.step('my saved appearance should be unchanged', 'server', function(ctx)
    local before = assert(ctx.state.clothingSaved, 'Remember the saved appearance first')
    Wait(500)
    assert(sameSkin(before, savedSkin(ctx)), 'The playerskins row changed')
end)
K.step('my saved appearance should have changed', 'server', function(ctx)
    local before = assert(ctx.state.clothingSaved, 'Remember the saved appearance first')
    ctx:waitUntil(function() return not sameSkin(before, savedSkin(ctx)) end, 'The playerskins row did not change', 5000)
end)

K.step('I remember my routing bucket before the fitting', 'server', function(ctx)
    ctx.state.clothingBucket = GetPlayerRoutingBucket(ctx.tester)
end)
K.step('I should be in my private fitting bucket', 'server', function(ctx)
    local expected = BUCKET_BASE + ctx.tester
    ctx:waitUntil(function() return GetPlayerRoutingBucket(ctx.tester) == expected end,
        ('Routing bucket is %s, expected %s'):format(GetPlayerRoutingBucket(ctx.tester), expected), 5000)
end)
K.step('I should be back in the routing bucket I came from', 'server', function(ctx)
    local before = assert(ctx.state.clothingBucket, 'Remember the routing bucket first')
    ctx:waitUntil(function() return GetPlayerRoutingBucket(ctx.tester) == before end,
        ('Routing bucket is %s, expected %s'):format(GetPlayerRoutingBucket(ctx.tester), before), 5000)
end)

K.step('I should have a saved outfit named {string}', 'server', function(ctx, name)
    ctx:waitUntil(function() return savedOutfit(ctx, name) end, 'No playeroutfits row named ' .. name, 5000)
end)
K.step('I should have no saved outfit named {string}', 'server', function(ctx, name)
    ctx:waitUntil(function() return not savedOutfit(ctx, name) end, 'A playeroutfits row named ' .. name .. ' still exists', 5000)
end)

K.step('another resource asks for a remote admin fitting of the {string} service on me', 'server', function(ctx, service)
    local ok, err = K.export(CLOTHING, 'OpenAdminSession', ctx.tester, service)
    ctx.state.clothingAdmin = { ok = ok, err = err }
end)
K.step('the remote admin fitting should be refused with {string}', 'server', function(ctx, reason)
    local answer = assert(ctx.state.clothingAdmin, 'Ask for a remote admin fitting first')
    assert(not answer.ok, 'The remote admin fitting was granted')
    ctx:equal(answer.err, reason, 'Refusal reason')
end)

-- ===========================================================================
-- Round 3: deeper coverage. Every value below is quoted from kora_clothing:
-- client/client.lua, client/quicktoggle.lua, server/server.lua, config.lua and
-- shared/components.lua.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Client: opening through the other public routes
-- ---------------------------------------------------------------------------

-- exports('OpenClothingRoom') keeps the numeric qb-clothing form (client.lua).
K.step('I open the clothing shop {int} the legacy way', 'client', function(ctx, shopId)
    guard(ctx)
    mark(ctx)
    K.export(CLOTHING, 'OpenClothingRoom', shopId)
    waitOpen(ctx)
end)
-- A non-numeric id: requestSession's tonumber gives nil and nothing opens.
K.step('I ask to open a clothing shop with the shop id {string}', 'client', function(ctx, shopId)
    guard(ctx)
    mark(ctx)
    K.export(CLOTHING, 'OpenClothingRoom', { shopId = shopId })
end)

-- The wardrobe routes in client.lua: exports OpenWardrobe / getOutfits and the
-- qb-clothing compat event qb-clothing:client:openOutfitMenu.
local WARDROBE_ROUTES = {
    OpenWardrobe = function() K.export(CLOTHING, 'OpenWardrobe') end,
    getOutfits = function() K.export(CLOTHING, 'getOutfits') end,
    ['qb-clothing:client:openOutfitMenu'] = function() TriggerEvent('qb-clothing:client:openOutfitMenu') end,
}
K.step('I open my wardrobe through {string}', 'client', function(ctx, route)
    local open = assert(WARDROBE_ROUTES[route], 'Unknown wardrobe route: ' .. route)
    guard(ctx)
    mark(ctx)
    open()
    waitOpen(ctx)
end)
K.step('I ask to open my wardrobe while the fitting is open', 'client', function(ctx)
    assert(isOpen(), 'Open a fitting room first')
    K.export(CLOTHING, 'OpenWardrobe')
end)
K.step('the fitting room should have been sent only one open message', 'client', function(ctx)
    Wait(1500)
    ctx:equal(#messages(ctx, 'open'), 1, 'Open messages sent to the page')
    ctx:equal(isOpen(), true, 'Fitting room open')
end)

-- qb-clothing:client:openMenu with no argument -> openNearestShop('clothing').
K.step('a third-party script opens the nearest clothing shop', 'client', function(ctx)
    guard(ctx)
    mark(ctx)
    TriggerEvent('qb-clothing:client:openMenu')
    waitOpen(ctx)
end)
-- kora_clothing:client:openNearestShop(service); refuses with
-- ('You are not near a %s shop'):format(service) (client.lua openNearestShop).
K.step('a third-party script asks for the nearest {string} shop', 'client', function(ctx, service)
    assert(service == 'clothing' or service == 'tattoo' or service == 'barber' or service == 'hairdresser', 'Unknown service')
    guard(ctx)
    mark(ctx)
    TriggerEvent('kora_clothing:client:openNearestShop', service)
end)

-- qb-clothing:client:CreateFirstCharacter -> openSession('firstCharacter'); the
-- server ignores it for a citizen with a saved appearance (requestSession).
K.step('a third-party script starts first character creation', 'client', function(ctx)
    local _, saved = K.must(hook('savedSkin'))
    assert(type(saved) == 'table' and saved.exists, 'Refusing to start: the tester has no saved appearance on record')
    guard(ctx)
    mark(ctx)
    TriggerEvent('qb-clothing:client:CreateFirstCharacter')
end)

K.step('the clothing exports should report a fitting in progress', 'client', function(ctx)
    ctx:equal(K.export(CLOTHING, 'IsClothingMenuOpen'), true, 'IsClothingMenuOpen')
    ctx:equal(K.export(CLOTHING, 'IsCreatingCharacter'), false, 'IsCreatingCharacter')
end)

-- ---------------------------------------------------------------------------
-- Client: trying things on
-- ---------------------------------------------------------------------------

K.step('I try on a different component {int}', 'client', function(ctx, id)
    assert(isOpen(), 'Open a fitting room first')
    assert(id >= 0 and id <= 11, 'Shared.components ids are 0-11')
    local ped = PlayerPedId()
    local count = GetNumberOfPedDrawableVariations(ped, id)
    assert(count > 1, ('This ped model has no second drawable for component %d'):format(id))
    local drawable = (GetPedDrawableVariation(ped, id) + 1) % count
    local answer = nui('setVariation', { kind = 'component', id = id, drawable = drawable, texture = 0 })
    ctx:equal(answer.ok, true, 'setVariation answer')
    ctx:equal(GetPedDrawableVariation(PlayerPedId(), id), drawable, ('Component %d drawable on the ped'):format(id))
end)

local PROP_SLOTS = { [0] = true, [1] = true, [2] = true, [6] = true, [7] = true } -- Shared.props
K.step('I try on a different prop {int}', 'client', function(ctx, id)
    assert(isOpen(), 'Open a fitting room first')
    assert(PROP_SLOTS[id], 'Shared.props ids are 0, 1, 2, 6 and 7')
    local ped = PlayerPedId()
    local count = GetNumberOfPedPropDrawableVariations(ped, id)
    assert(count > 1, ('This ped model has no second drawable for prop %d'):format(id))
    local current = GetPedPropIndex(ped, id)
    local drawable = current < 0 and 0 or (current + 1) % count
    local answer = nui('setVariation', { kind = 'prop', id = id, drawable = drawable, texture = 0 })
    ctx:equal(answer.ok, true, 'setVariation answer')
    ctx:equal(GetPedPropIndex(PlayerPedId(), id), drawable, ('Prop %d drawable on the ped'):format(id))
end)

K.step('the fitting room page should refuse the variation:', 'client', function(ctx, argument)
    assert(isOpen(), 'Open a fitting room first')
    ctx:equal(nui('setVariation', K.json(argument)).ok, false, 'setVariation answer')
end)
K.step('the fitting room page should accept the variation:', 'client', function(ctx, argument)
    assert(isOpen(), 'Open a fitting room first')
    local answer = nui('setVariation', K.json(argument))
    ctx:equal(answer.ok, true, 'setVariation answer')
    ctx.state.clothingVariation = answer
end)
K.step('the fitting room page should have answered with drawable {int}', 'client', function(ctx, drawable)
    local answer = assert(ctx.state.clothingVariation, 'Send a variation first')
    ctx:equal(answer.drawable, drawable, 'Answered drawable')
end)
K.step('component {int} should be on drawable {int} on my ped', 'client', function(ctx, id, drawable)
    ctx:equal(GetPedDrawableVariation(PlayerPedId(), id), drawable, ('Component %d drawable'):format(id))
end)
K.step('prop {int} should be removed from my ped', 'client', function(ctx, id)
    ctx:equal(GetPedPropIndex(PlayerPedId(), id), -1, ('Prop %d drawable'):format(id))
end)

local function sameLook(a, b)
    for id, entry in pairs(a.components) do
        local other = b.components[id]
        if not other or other[1] ~= entry[1] or other[2] ~= entry[2] then return false, 'component ' .. id end
    end
    for id, entry in pairs(a.props) do
        local other = b.props[id]
        if not other or other[1] ~= entry[1] or (entry[1] >= 0 and other[2] ~= entry[2]) then return false, 'prop ' .. id end
    end
    return a.model == b.model, 'model'
end
K.step('I should be wearing exactly what the fitting started with', 'client', function(ctx)
    local before = assert(ctx.state.clothingOpenLook, 'Open a fitting room first')
    local why
    ctx:waitUntil(function()
        local same, slot = sameLook(before, wearing())
        why = slot
        return same
    end, 'The ped does not wear what the fitting opened with', 5000, function() return ' (' .. tostring(why) .. ' differs)' end)
end)

-- Callbacks a plain clothing session refuses (client.lua): no hair colour or
-- head edits (Config.services.clothing has no component 2), no tattoos (no
-- `tattoos`), no studio undress (tattoo only) and no preview switches (not in
-- Config.ui.clothingToggles.services, barber/hairdresser by default).
local CLOTHING_REFUSES = {
    setHairColor = true, setHead = true, setTattoos = true, setUndress = true, setClothingToggle = true,
}
K.step('the clothing shop page should refuse {string}', 'client', function(ctx, name)
    assert(CLOTHING_REFUSES[name], 'Unsupported callback: ' .. name)
    assert(isOpen(), 'Open a fitting room first')
    ctx:equal(nui(name, REFUSED_WITHOUT_SESSION[name]).ok, false, name .. ' answer')
end)

-- Without a session rotateStart answers { active = false } and recenter { moved = false }.
K.step('the fitting room page should not start a rotate drag without a session', 'client', function(ctx)
    assert(not isOpen(), 'A fitting room session is open')
    ctx:equal(nui('rotateStart', { button = 0, x = 0.5, y = 0.5 }).active, false, 'rotateStart answer')
    ctx:equal(nui('recenter', {}).moved, false, 'recenter answer')
end)

-- Camera.setZone ignores a name that is not in Config.camera.zones;
-- Camera.setCategory only moves with Config.camera.resetOnCategoryChange (false).
K.step('pointing the fitting room camera at {string} should leave it on {string}', 'client', function(ctx, zone, expected)
    ctx:equal(nui('camera', { zone = zone }).zone, expected, 'Camera zone')
end)
K.step('choosing the {string} category should leave the fitting room camera on {string}', 'client', function(ctx, category, expected)
    ctx:equal(nui('camera', { category = category }).zone, expected, 'Camera zone')
end)

K.step('I confirm the fitting twice in a row', 'client', function(ctx)
    ctx:equal(nui('confirm', {}).ok, true, 'first confirm answer')
    nui('confirm', {}) -- may be refused if the close already arrived
end)

-- confirmSession trims and cuts the name to 50 characters; a blank one saves nothing.
K.step('I confirm the fitting and save it under the raw name {string}', 'client', function(ctx, name)
    local cleaned = name:sub(1, 50):gsub('^%s+', ''):gsub('%s+$', '')
    assert(cleaned == '' or cleaned:sub(1, #OUTFIT_PREFIX) == OUTFIT_PREFIX, 'Test outfit names must start with ' .. OUTFIT_PREFIX)
    ctx:equal(nui('confirm', { saveName = name }).ok, true, 'confirm answer')
end)

local function payloadOutfit(ctx, name)
    local updates = messages(ctx, 'outfits')
    local list = #updates > 0 and updates[#updates].data or openPayload(ctx).outfits
    return outfitIn(list, name)
end
K.step('I put on the saved outfit {string} in the fitting room', 'client', function(ctx, name)
    local row = assert(payloadOutfit(ctx, name), 'The page was not given the outfit ' .. name)
    local answer = nui('loadOutfit', { id = assert(tonumber(row.id), 'Outfit has no id') })
    ctx:equal(answer.ok, true, 'loadOutfit answer')
end)
K.step('the fitting room should refuse to load the outfit id {int}', 'client', function(ctx, id)
    ctx:equal(nui('loadOutfit', { id = id }).ok, false, 'loadOutfit answer')
end)
K.step('I delete the outfit id {int} in the fitting room', 'client', function(ctx, id)
    local before = #messages(ctx, 'outfits')
    nui('deleteOutfit', { id = id })
    -- deleteOutfit always answers with kora_clothing:client:outfitsUpdated.
    ctx:waitUntil(function() return #messages(ctx, 'outfits') > before end, 'The page was not sent an outfit list', 8000)
end)

-- ---------------------------------------------------------------------------
-- Client: looks outside the fitting room
-- ---------------------------------------------------------------------------
local function outsideFixture(ctx)
    assert(not isOpen(), 'Close the fitting room first')
    guard(ctx)
end

K.step('my jacket is changed outside the fitting room', 'client', function(ctx)
    outsideFixture(ctx)
    local ped = PlayerPedId()
    local count = GetNumberOfPedDrawableVariations(ped, JACKET)
    assert(count > 1, 'This ped model has no second jacket')
    local drawable = (GetPedDrawableVariation(ped, JACKET) + 1) % count
    SetPedComponentVariation(ped, JACKET, drawable, 0, 0)
    ctx:equal(GetPedDrawableVariation(ped, JACKET), drawable, 'Jacket drawable')
end)
K.step('I am wearing jacket drawable {int} outside the fitting room', 'client', function(ctx, drawable)
    outsideFixture(ctx)
    local ped = PlayerPedId()
    assert(drawable >= 0 and drawable < GetNumberOfPedDrawableVariations(ped, JACKET), 'No such jacket drawable')
    SetPedComponentVariation(ped, JACKET, drawable, 0, 0)
end)
K.step('I am wearing no hat outside the fitting room', 'client', function(ctx)
    outsideFixture(ctx)
    ClearPedProp(PlayerPedId(), 0)
end)
K.step('my jacket should be drawable {int}', 'client', function(ctx, drawable)
    ctx:waitUntil(function() return GetPedDrawableVariation(PlayerPedId(), JACKET) == drawable end,
        ('Jacket is drawable %d, expected %d'):format(GetPedDrawableVariation(PlayerPedId(), JACKET), drawable), 5000)
end)

local RELOAD_ROUTES = {
    ['refreshskin command'] = function() ExecuteCommand('refreshskin') end,
    ['reloadSkin export'] = function() K.export(CLOTHING, 'reloadSkin') end,
}
K.step('I reload my saved appearance with the {string}', 'client', function(_, route)
    assert(RELOAD_ROUTES[route], 'Unknown reload route: ' .. route)()
end)

-- Quick toggle routes (client.lua): /c <part> (Config.quickToggle.command 'c'),
-- the qb-radialmenu events and qb-clothing:client:adjustfacewear (5 = shirt).
local TOGGLE_ROUTES = {
    ['/c shirt'] = function() ExecuteCommand('c shirt') end,
    ['/c top'] = function() ExecuteCommand('c top') end,
    ['/c jacket'] = function() ExecuteCommand('c jacket') end,
    ['/c torso'] = function() ExecuteCommand('c torso') end,
    ['qb-radialmenu:ToggleClothing top'] = function() TriggerEvent('qb-radialmenu:ToggleClothing', 'top') end,
    ['qb-radialmenu:ToggleClothing shirt by id'] = function() TriggerEvent('qb-radialmenu:ToggleClothing', { id = 'shirt' }) end,
    ['qb-clothing:client:adjustfacewear 5'] = function() TriggerEvent('qb-clothing:client:adjustfacewear', 5) end,
}
K.step('I toggle my shirt through {string}', 'client', function(_, route)
    assert(TOGGLE_ROUTES[route], 'Unknown toggle route: ' .. route)()
end)

K.step('applying an appearance to no ped should be refused with {string}', 'client', function(ctx, reason)
    local ok, err = K.export(CLOTHING, 'ApplyAppearanceToPed', 0, 'mp_m_freemode_01', {})
    ctx:equal(ok, false, 'ApplyAppearanceToPed result')
    ctx:equal(err, reason, 'Refusal reason')
end)
K.step('applying the {string} appearance to my ped should be refused with {string}', 'client', function(ctx, model, reason)
    local ped = PlayerPedId()
    assert(GetEntityModel(ped) ~= joaat(model), 'The ped already uses ' .. model)
    local ok, err = K.export(CLOTHING, 'ApplyAppearanceToPed', ped, model, {})
    ctx:equal(ok, false, 'ApplyAppearanceToPed result')
    ctx:equal(err, reason, 'Refusal reason')
end)
K.step('applying the other freemode appearance to my ped should be refused with {string}', 'client', function(ctx, reason)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped) == joaat('mp_m_freemode_01') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    local ok, err = K.export(CLOTHING, 'ApplyAppearanceToPed', ped, model, {})
    ctx:equal(ok, false, 'ApplyAppearanceToPed result')
    ctx:equal(err, reason, 'Refusal reason')
end)
-- The documented use: a local, non-networked clone (character selectors).
K.step('an appearance applied to a local copy of my ped should dress that copy', 'client', function(ctx)
    local ped = PlayerPedId()
    local hash = GetEntityModel(ped)
    local model = hash == joaat('mp_m_freemode_01') and 'mp_m_freemode_01'
        or hash == joaat('mp_f_freemode_01') and 'mp_f_freemode_01' or nil
    assert(model, 'The tester is not on a freemode model')
    local jacket = GetPedDrawableVariation(ped, JACKET)
    local clone = ClonePed(ped, false, false, true)
    assert(clone and clone ~= 0, 'Could not clone the ped')
    ctx:cleanup(function() if DoesEntityExist(clone) then SetEntityAsMissionEntity(clone, true, true) DeletePed(clone) end end)
    local count = GetNumberOfPedDrawableVariations(clone, JACKET)
    assert(count > 1, 'No second jacket for this model')
    local target = (GetPedDrawableVariation(clone, JACKET) + 1) % count
    local ok, err = K.export(CLOTHING, 'ApplyAppearanceToPed', clone, model, { components = { [tostring(JACKET)] = { d = target, t = 0 } } })
    assert(ok == true, 'ApplyAppearanceToPed refused: ' .. tostring(err))
    ctx:equal(GetPedDrawableVariation(clone, JACKET), target, 'Jacket on the copy')
    ctx:equal(GetPedDrawableVariation(PlayerPedId(), JACKET), jacket, 'Jacket on my own ped')
end)

K.step('the starter appearance should be refused', 'client', function(ctx)
    ctx:equal(K.export(CLOTHING, 'applyStarterAppearance'), false, 'applyStarterAppearance')
end)

-- qb-clothing:server:removeOutfit(outfitName, outfitId), the stock wire event a
-- third-party resource sends; ids come from the legacy outfit list.
local function legacyOutfitId(name)
    local _, rows = K.must(hook('outfits'))
    local row = assert(outfitIn(rows, name), 'qb-clothing:server:getOutfits does not list ' .. name)
    return assert(tonumber(row.id), 'Outfit has no id')
end
K.step('a third-party script removes my saved outfit {string}', 'client', function(_, name)
    assert(name:sub(1, #OUTFIT_PREFIX) == OUTFIT_PREFIX, 'Only test outfits may be removed')
    TriggerServerEvent('qb-clothing:server:removeOutfit', name, legacyOutfitId(name))
end)
K.step('a third-party script removes my saved outfit {string} calling it {string}', 'client', function(_, name, claimed)
    assert(name:sub(1, #OUTFIT_PREFIX) == OUTFIT_PREFIX, 'Only test outfits may be removed')
    TriggerServerEvent('qb-clothing:server:removeOutfit', claimed, legacyOutfitId(name))
end)

-- ---------------------------------------------------------------------------
-- Server: saved slots, outfit counts, charges
-- ---------------------------------------------------------------------------
local function savedSlot(row, bag, id)
    if not row.exists then return nil end
    local ok, skin = pcall(json.decode, row.skin or '')
    if not ok or type(skin) ~= 'table' or type(skin[bag]) ~= 'table' then return nil end
    local entry = skin[bag][tostring(id)]
    if type(entry) ~= 'table' then return nil end
    return ('%s/%s'):format(tostring(entry.d), tostring(entry.t))
end
local function slotStep(bag, changed)
    return function(ctx, id)
        local before = assert(ctx.state.clothingSaved, 'Remember the saved appearance first')
        local was = savedSlot(before, bag, id)
        if changed then
            ctx:waitUntil(function() return savedSlot(savedSkin(ctx), bag, id) ~= was end,
                ('Saved %s %d is still %s'):format(bag, id, tostring(was)), 5000)
        else
            Wait(500)
            ctx:equal(savedSlot(savedSkin(ctx), bag, id), was, ('Saved %s %d'):format(bag, id))
        end
    end
end
K.step('my saved component {int} should be as it was', 'server', slotStep('components', false))
K.step('my saved component {int} should have changed', 'server', slotStep('components', true))
K.step('my saved prop {int} should have changed', 'server', slotStep('props', true))

K.step('I have no saved appearance on record', 'server', function(ctx)
    assert(ctx.state.clothingSnapshotTaken, 'Use "my saved appearance and outfits are put back after the scenario" first')
    K.must(K.hook(CLOTHING, 'restoreSkin', ctx.tester, { exists = false }))
    assert(not savedSkin(ctx).exists, 'The saved appearance is still there')
end)
K.step('my saved appearance should exist', 'server', function(ctx)
    ctx:waitUntil(function() return savedSkin(ctx).exists end, 'No playerskins row', 5000)
end)
K.step('my saved appearance is put back now', 'server', function(ctx)
    local snapshot = assert(ctx.state.clothingSnapshot, 'No saved appearance snapshot')
    K.must(K.hook(CLOTHING, 'restoreSkin', ctx.tester, snapshot))
end)

local function outfitCount(ctx)
    local _, rows = K.must(K.hook(CLOTHING, 'outfits', ctx.tester))
    return #(type(rows) == 'table' and rows or {})
end
K.step('I remember how many outfits I have saved', 'server', function(ctx)
    ctx.state.clothingOutfitCount = outfitCount(ctx)
end)
K.step('I should have as many saved outfits as before', 'server', function(ctx)
    local before = assert(ctx.state.clothingOutfitCount, 'Remember the outfit count first')
    Wait(500)
    ctx:equal(outfitCount(ctx), before, 'Saved outfits')
end)

-- confirmSession charges with reason 'kora_clothing-purchase'; the capture is
-- the one "I remember my {string} balance" starts (QBCore:Server:OnMoneyChange
-- src, account, amount, action, reason).
K.step('exactly one clothing purchase of {int} should have been charged to {string}', 'server', function(ctx, amount, account)
    local function purchases()
        local list = {}
        for _, record in ipairs(K.captured(ctx, 'QBCore:Server:OnMoneyChange')) do
            if record[2] == account and record[5] == 'kora_clothing-purchase' then list[#list + 1] = record end
        end
        return list
    end
    ctx:waitUntil(function() return #purchases() > 0 end, 'No kora_clothing-purchase charge was recorded', 5000)
    Wait(2000)
    local list = purchases()
    ctx:equal(#list, 1, 'kora_clothing-purchase charges')
    ctx:equal(list[1][3], amount, 'Charged amount')
end)
