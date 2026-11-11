-- kora_police: duty point, job and grade gating of the station options (armoury,
-- evidence locker, fleet), citations the tester holds, and the impound lot.
--
-- No resource hook and no seam: duty and job state are read through kora_core,
-- citations through exports.kora_police:getCitations, and station options are
-- reached through kora_target.
--
-- Scope: the tester is the only subject. Nothing here cuffs, escorts, searches,
-- fines, jails or robs anyone, and nothing raises a dispatch call (/backup is
-- only exercised off duty, where the client refuses before any server call).
local K = FFT.kora
if not K then return end
K.feature('kora_police')

-- ---------------------------------------------------------------------------
-- Station options (client)
-- ---------------------------------------------------------------------------

local function stopTargeting()
    pcall(function() exports.kora_target:fftAction('stop') end)
    pcall(function() exports.kora_lib:fftAction('interact.close') end)
end

-- Whether `label` is among the options under the crosshair right now. With one
-- option the hover label is exact; with several, the release opens kora_lib's
-- selector, whose list is read and then closed again.
local function offeredNow(label)
    if not exports.kora_target:fftAction('start') then return false end
    Wait(100)
    local hover = exports.kora_target:fftAction('hovering')
    if not hover then return false end
    if hover.optionCount == 1 then return hover.label == label end
    exports.kora_target:fftAction('select', label)
    local deadline, found = GetGameTimer() + 1000, false
    while GetGameTimer() < deadline and not found do
        for _, option in ipairs(K.uiState().interact or {}) do
            if option.label == label then found = true end
        end
        Wait(50)
    end
    pcall(function() exports.kora_lib:fftAction('interact.close') end)
    return found
end

-- Station zones are small boxes and spheres whose surroundings (desks, door
-- frames) differ per map, so the camera sweeps around the tester. Returns true
-- with targeting still active on the option, or false after a full sweep.
local function sweep(ctx, label)
    ctx:cleanup(stopTargeting)
    local ped = PlayerPedId()
    local base = GetEntityHeading(ped)
    for _, pitch in ipairs({ -20.0, -45.0, -70.0 }) do
        for turn = 0, 7 do
            ctx:check()
            SetEntityHeading(ped, (base + turn * 45.0) % 360.0)
            SetGameplayCamRelativeHeading(0.0)
            SetGameplayCamRelativePitch(pitch, 1.0)
            Wait(200)
            if offeredNow(label) then return true end
        end
    end
    return false
end

K.step('I look around the police station for {string}', 'client', function(ctx, label)
    assert(sweep(ctx, label), 'Police station option was not found around the tester: ' .. label)
end)
K.step('the police station should not offer {string} here', 'client', function(ctx, label)
    local found = sweep(ctx, label)
    stopTargeting()
    assert(not found, 'Police station option is offered: ' .. label)
end)

-- The events the armoury and fleet options send on selection, sent without the
-- option being visible. The option's canInteract is only a convenience; these
-- prove the server refuses on its own. Ids come from kora_police/config.lua.
K.step('I ask the police server to open the armoury {string}', 'client', function(_, shopId)
    assert(#shopId <= 64, 'Armoury id is too long')
    TriggerServerEvent('kora_police:server:openArmory', shopId)
end)
K.step('I ask the police server for fleet vehicle {string}', 'client', function(_, plate)
    assert(plate:match('^POLICE%d%d$'), 'Fleet plates are POLICE01, POLICE02, ...')
    TriggerServerEvent('kora_police:server:spawnDutyVehicle', plate)
end)

-- ---------------------------------------------------------------------------
-- Citations held by the tester (server)
-- ---------------------------------------------------------------------------

local function citations(ctx)
    local list = K.export('kora_police', 'getCitations', ctx.tester)
    assert(type(list) == 'table', 'exports.kora_police:getCitations returned no list')
    return list
end

-- Citations live in the tester's own `citations` metadata. The fixture replaces
-- the list for the scenario and puts the original back afterwards.
local function setCitations(ctx, list)
    local core, tester = exports.kora_core, ctx.tester
    if not ctx.state.citationsSaved then
        local original = core:getMetaData(tester, 'citations')
        ctx.state.citationsSaved = true
        ctx:cleanup(function() core:setMetaData(tester, 'citations', type(original) == 'table' and original or {}) end)
    end
    local ok, err = core:setMetaData(tester, 'citations', list)
    if ok == false then error('Could not set the citations metadata: ' .. tostring(err), 0) end
end

K.step('I have no unpaid police citations', 'server', function(ctx) setCitations(ctx, {}) end)
K.step('I have an unpaid police citation of {int} for {string}', 'server', function(ctx, amount, reason)
    assert(amount > 0 and amount <= 1000, 'Test citation must be 1-1000')
    assert(#reason <= 120, 'Citation reason is limited to 120 characters')
    setCitations(ctx, { { id = 1, amount = amount, reason = reason, officer = 'FFT', issuedAt = os.time() } })
end)
K.step('I should have {int} unpaid police citations', 'server', function(ctx, expected)
    ctx:waitUntil(function() return #citations(ctx) == expected end,
        ('Expected %d unpaid citations, have %d'):format(expected, #citations(ctx)), 3000)
end)
K.step('my unpaid police citation {int} should be {int} for {string}', 'server', function(ctx, id, amount, reason)
    for _, citation in ipairs(citations(ctx)) do
        if tonumber(citation.id) == id then
            ctx:equal(citation.amount, amount, 'Citation amount')
            ctx:equal(citation.reason, reason, 'Citation reason')
            return
        end
    end
    error('No unpaid citation #' .. id, 0)
end)
K.step('paying police citation {int} through the export should be refused with {string}', 'server', function(ctx, id, reason)
    local ok, err = K.export('kora_police', 'payCitation', ctx.tester, id)
    assert(not ok, 'payCitation accepted citation #' .. id)
    ctx:equal(err, reason, 'Refusal reason')
end)

-- More citation fixtures. Each replaces/extends the tester's own `citations`
-- metadata (kora_police/server/bill.lua readCitations) and the original list is
-- put back by setCitations' cleanup.
local function currentList(ctx)
    local list = exports.kora_core:getMetaData(ctx.tester, 'citations')
    return ctx.state.citationsSaved and type(list) == 'table' and list or {}
end
K.step('I have an unpaid police citation {int} of {int} for {string}', 'server', function(ctx, id, amount, reason)
    assert(id > 0 and id <= 100, 'Test citation id must be 1-100')
    assert(amount > 0 and amount <= 1000, 'Test citation must be 1-1000')
    assert(#reason <= 120, 'Citation reason is limited to 120 characters')
    local list = currentList(ctx)
    list[#list + 1] = { id = id, amount = amount, reason = reason, officer = 'FFT', issuedAt = os.time() }
    setCitations(ctx, list)
end)
K.step('I have an unpaid police citation of {int} without a reason', 'server', function(ctx, amount)
    assert(amount > 0 and amount <= 1000, 'Test citation must be 1-1000')
    setCitations(ctx, { { id = 1, amount = amount, officer = 'FFT', issuedAt = os.time() } })
end)
-- Config.Citations.maxUnpaid is 25 (kora_police/config.lua).
K.step('I have {int} unpaid police citations of {int} each', 'server', function(ctx, count, amount)
    assert(count > 0 and count <= 25, 'At most 25 test citations')
    assert(amount > 0 and amount <= 1000, 'Test citation must be 1-1000')
    local list = {}
    for id = 1, count do list[id] = { id = id, amount = amount, reason = 'FFT citation ' .. id, officer = 'FFT', issuedAt = os.time() } end
    setCitations(ctx, list)
end)
-- getCitations treats anything but a table as "no citations" (bill.lua:11-14).
K.step('my police citations record is not a list', 'server', function(ctx) setCitations(ctx, 'fft-not-a-list') end)
K.step('I should have no unpaid police citation {int}', 'server', function(ctx, id)
    for _, citation in ipairs(citations(ctx)) do
        assert(tonumber(citation.id) ~= id, 'Citation #' .. id .. ' is still unpaid')
    end
end)
K.step('my unpaid police citation {int} should have a reason of {int} characters', 'server', function(ctx, id, length)
    for _, citation in ipairs(citations(ctx)) do
        if tonumber(citation.id) == id then return ctx:equal(#tostring(citation.reason), length, 'Reason length') end
    end
    error('No unpaid citation #' .. id, 0)
end)
-- exports.kora_police:payCitation(src, nil) pays the oldest (bill.lua:85-86).
K.step('paying my oldest police citation through the export should succeed', 'server', function(ctx)
    local ok, err = K.export('kora_police', 'payCitation', ctx.tester, nil)
    assert(ok == true, 'payCitation refused: ' .. tostring(err))
end)

-- kora_police:server:bill(target, amount, reason) with the tester as both
-- officer and target: the only player within Config.cuff.distance (2.5 m) of
-- themselves. Issues a real citation into the tester's own metadata, which the
-- fixture `I have no unpaid police citations` must have saved first.
K.step('I ask the police server to fine me {string} for {string}', 'client', function(ctx, amount, reason)
    assert(#amount <= 16 and #reason <= 200, 'Fine arguments are too long')
    TriggerServerEvent('kora_police:server:bill', GetPlayerServerId(PlayerId()), amount, reason)
end)
-- Server id 0 is the console, never a player (getPlayerData(0) is nil).
K.step('I ask the police server to fine an unknown player', 'client', function()
    TriggerServerEvent('kora_police:server:bill', 0, 100, 'FFT unknown player')
end)

-- ---------------------------------------------------------------------------
-- Actions aimed at the tester themselves (client sends, server refuses)
-- ---------------------------------------------------------------------------

-- Officer actions whose server handler takes `target` first. Each refuses a
-- self target or a target that is not restrained before changing anything
-- (server/cuff.lua, escort.lua, rob.lua, seize.lua, compat/police.lua). Jail
-- and setTracker are left out: with the tester on duty they would act for real.
local SELF_TARGET_EVENTS = {
    ['kora_police:server:cuff'] = true, ['kora_police:server:uncuff'] = true,
    ['kora_police:server:escort'] = true, ['kora_police:server:deEscort'] = true,
    ['kora_police:server:startDrag'] = true, ['kora_police:server:rob'] = true,
    ['kora_police:server:search'] = true, ['kora_police:server:seizeCash'] = true,
    ['kora_police:server:seizeDriverLicense'] = true, ['kora_police:server:putInVehicle'] = true,
    ['police:server:SetTracker'] = true,
}
K.step('I send the police event {string} with myself as the target', 'client', function(_, event)
    assert(SELF_TARGET_EVENTS[event], 'Not an allowed self-target police event: ' .. event)
    TriggerServerEvent(event, GetPlayerServerId(PlayerId()))
end)
K.step('I send the police event {string} with no such player as the target', 'client', function(_, event)
    assert(SELF_TARGET_EVENTS[event], 'Not an allowed police target event: ' .. event)
    TriggerServerEvent(event, 0)
end)

-- Restraint state lives in kora_core metadata `ishandcuffed` and the player
-- state bag `koraCuffed` (server/cuff.lua:9-15, 135-137).
K.step('kora_police should not hold me in cuffs', 'server', function(ctx)
    Wait(500)
    ctx:equal(exports.kora_core:getMetaData(ctx.tester, 'ishandcuffed') == true, false, 'ishandcuffed metadata')
    ctx:equal(Player(ctx.tester).state.koraCuffed == true, false, 'koraCuffed state bag')
end)
-- seizeDriverLicense writes licences.driver = false (seize.lua:61-71).
local function driverLicenceSeized(ctx)
    local licences = exports.kora_core:getMetaData(ctx.tester, 'licences')
    return type(licences) == 'table' and licences.driver == false
end
K.step('I remember my driver licence', 'server', function(ctx)
    ctx.state.licenceSeizedBefore = driverLicenceSeized(ctx)
end)
K.step('my driver licence should not have been seized', 'server', function(ctx)
    assert(ctx.state.licenceSeizedBefore ~= nil, 'Remember the driver licence first')
    Wait(500)
    ctx:equal(driverLicenceSeized(ctx), ctx.state.licenceSeizedBefore, 'Driver licence seized')
end)

-- ---------------------------------------------------------------------------
-- Server callbacks, asked the way the resource's own client does
-- (Kora.callback.trigger through kora_lib's envelope export)
-- ---------------------------------------------------------------------------

local function ask(name, ...)
    K.started('kora_lib')
    local packed = exports.kora_lib:callback_triggerPacked(name, ...)
    if type(packed) ~= 'table' then return { n = 1, packed } end
    packed.n = tonumber(packed.n) or #packed
    return packed
end
local function render(value)
    if type(value) == 'table' then return json.encode(value) end
    return tostring(value)
end

-- Read-only callbacks: none of these writes state for a tester who is not
-- cuffed, escorted or tracked (server/callbacks.lua, cuff.lua, compat/police.lua,
-- plate_flag.lua, armory.lua).
local READ_ONLY_CALLBACKS = {
    ['kora_police:server:getCuffed'] = true, ['police:GetCuffed'] = true,
    ['kora_police:server:resyncCuff'] = true, ['kora_police:server:beginBreakCuffs'] = true,
    ['police:GetEscorted'] = true, ['police:GetKidnappedTarget'] = true,
    ['kora_police:server:isPlateFlagged'] = true, ['police:IsPlateFlagged'] = true,
    ['police:server:IsPlateFlagged'] = true, ['police:server:IsPoliceForcePresent'] = true,
    ['kora_police:server:canAccessArmory'] = true, ['kora_police:server:getCops'] = true,
    ['police:GetImpoundedVehicles'] = true, ['kora_police:server:getPlayerStatus'] = true,
}
local function askReadOnly(name, ...)
    assert(READ_ONLY_CALLBACKS[name], 'Not an allowed read-only police callback: ' .. name)
    return ask(name, ...)
end

-- Every returned value, rendered and joined with ", " ("false, false",
-- "nil, not soft-cuffed"). Trailing nils are dropped: isPlateFlagged answers
-- `false, nil` for an unflagged plate (plate_flag.lua:87-92).
local function answerText(result)
    local last = result.n
    while last > 1 and result[last] == nil do last = last - 1 end
    local parts = {}
    for i = 1, math.max(last, 1) do parts[i] = render(result[i]) end
    return table.concat(parts, ', ')
end
K.step('asking the police server {string} should answer {string}', 'client', function(ctx, name, expected)
    local result = askReadOnly(name)
    ctx:equal(answerText(result), expected, name .. ' answer')
end)
K.step('asking the police server {string} about {string} should answer {string}', 'client', function(ctx, name, argument, expected)
    local result = askReadOnly(name, argument)
    ctx:equal(answerText(result), expected, name .. ' answer')
end)
K.step('asking the police server {string} should answer an empty list', 'client', function(_, name)
    local value = askReadOnly(name)[1]
    assert(type(value) == 'table' and next(value) == nil, name .. ' answered ' .. render(value))
end)

-- police:GetCops counts on-duty LEOs for any caller (callbacks.lua:42-44).
K.step('the police server should count at least {int} officer on duty', 'client', function(_, minimum)
    local count = ask('police:GetCops')[1]
    assert(type(count) == 'number' and count >= minimum, 'police:GetCops answered ' .. render(count))
end)
K.step('the police server should list me among the on-duty officers', 'client', function()
    local list, me = askReadOnly('kora_police:server:getCops')[1], GetPlayerServerId(PlayerId())
    assert(type(list) == 'table', 'kora_police:server:getCops answered ' .. render(list))
    for _, src in ipairs(list) do if tonumber(src) == me then return end end
    error('Tester is not in kora_police:server:getCops: ' .. render(list), 0)
end)
-- police:GetDutyPlayers adds citizenid/name/grade only for police callers.
K.step('the police duty roster should show my grade as {int}', 'client', function(ctx, grade)
    local list, me = ask('police:GetDutyPlayers')[1], GetPlayerServerId(PlayerId())
    assert(type(list) == 'table', 'police:GetDutyPlayers answered ' .. render(list))
    for _, entry in ipairs(list) do
        if tonumber(entry.source) == me then
            assert(type(entry.citizenid) == 'string', 'Roster entry has no citizenid for a police caller')
            return ctx:equal(tonumber(entry.grade), grade, 'Roster grade')
        end
    end
    error('Tester is not on the police duty roster', 0)
end)
K.step('my own police status record should show me free and untracked', 'client', function(ctx)
    local record = askReadOnly('kora_police:server:getPlayerStatus')[1]
    assert(type(record) == 'table', 'kora_police:server:getPlayerStatus answered ' .. render(record))
    ctx:equal(record.cuffed, false, 'cuffed')
    ctx:equal(record.tracked, false, 'tracked')
    ctx:equal(record.escortedBy, nil, 'escortedBy')
end)

-- ---------------------------------------------------------------------------
-- Impairment statuses (client/evidence.lua:153-166, server/evidence.lua:330-353)
-- ---------------------------------------------------------------------------

K.step('I report the impairment status {string} for {int} seconds', 'client', function(ctx, id, seconds)
    assert(#id <= 32, 'Status id is too long')
    assert(seconds >= 0 and seconds <= 120, 'Status time must be 0-120 seconds')
    if not ctx.state.statusCleanup then
        ctx.state.statusCleanup = {}
        local list = ctx.state.statusCleanup
        ctx:cleanup(function() for statusId in pairs(list) do TriggerEvent('evidence:client:SetStatus', statusId, 0) end end)
    end
    ctx.state.statusCleanup[id] = true
    TriggerEvent('evidence:client:SetStatus', id, seconds)
end)
-- police:GetPlayerStatus answers an on-duty officer about themselves.
local function statusList()
    local list = ask('police:GetPlayerStatus')[1]
    return type(list) == 'table' and list or {}
end
K.step('the police server should list my status {string}', 'client', function(ctx, label)
    ctx:waitUntil(function()
        for _, text in ipairs(statusList()) do if text == label then return true end end
    end, 'Status not listed: ' .. label .. ' (have ' .. render(statusList()) .. ')', 3000)
end)
K.step('the police server should list no status for me', 'client', function(ctx)
    ctx:waitUntil(function() return #statusList() == 0 end, 'Statuses listed: ' .. render(statusList()), 3000)
end)

-- ---------------------------------------------------------------------------
-- Plate flags, road props, spike strips, fleet and impound refusals
-- ---------------------------------------------------------------------------

-- An accepted flag also writes a kora_mdt BOLO row (plate_flag.lua:30-46), which
-- has no delete API, so only plates the server must refuse are allowed here:
-- blank, longer than 15 characters, or an FFT plate sent while off duty.
K.step('I ask the police server to flag plate {string}', 'client', function(ctx, plate)
    local trimmed = plate:match('^%s*(.-)%s*$')
    assert(trimmed == '' or #trimmed > 15 or trimmed:sub(1, 3) == 'FFT', 'Only refused or FFT plates may be flagged')
    if trimmed:sub(1, 3) == 'FFT' and #trimmed <= 15 then
        ctx:cleanup(function() TriggerServerEvent('kora_police:server:unflagPlate', trimmed) end)
    end
    TriggerServerEvent('kora_police:server:flagPlate', plate, 'FFT refused flag')
end)
K.step('I ask the police server to unflag plate {string}', 'client', function(_, plate)
    assert(plate:sub(1, 3) == 'FFT', 'Unflag test plates start with FFT')
    TriggerServerEvent('kora_police:server:unflagPlate', plate)
end)

-- police:server:spawnObject(type) creates a networked prop for an on-duty
-- officer (server/objects.lua:28-61). Only an unknown type or an off-duty
-- request is sent; a prop that is created anyway is removed again.
K.step('I ask the police server to place a {string} road prop', 'client', function(ctx, objectType)
    assert(objectType == 'cone' or objectType:sub(1, 4) == 'fft-', 'Road prop tests use "cone" off duty or an fft- type')
    if objectType == 'cone' then
        ctx:cleanup(function() TriggerServerEvent('kora_police:server:deleteNearestObject') end)
    end
    TriggerServerEvent('police:server:spawnObject', objectType)
end)
K.step('I ask the police server to remove the nearest road prop', 'client', function()
    TriggerServerEvent('kora_police:server:deleteNearestObject')
end)
-- Prop ids start at 10000 (objects.lua:9), so a smaller id is never known.
K.step('I ask the police server to remove road prop {int}', 'client', function(_, id)
    assert(id >= 0 and id < 10000, 'Use an id below 10000')
    TriggerServerEvent('police:server:deleteObject', id)
end)

-- kora_police:server:deploySpike(coords): refused beyond
-- Config.spikes.deployDistance (5.0 m), so only far positions are sent.
K.step('I ask the police server for a spike strip {int} metres ahead', 'client', function(_, metres)
    assert(metres >= 10 and metres <= 100, 'Spike tests use 10-100 metres (deployDistance is 5)')
    local ped = PlayerPedId()
    local at = GetOffsetFromEntityInWorldCoords(ped, 0.0, metres + 0.0, 0.0)
    TriggerServerEvent('kora_police:server:deploySpike', { x = at.x, y = at.y, z = at.z })
end)
K.step('I ask the police server for a spike strip without a position', 'client', function()
    TriggerServerEvent('kora_police:server:deploySpike', 'fft-no-position')
end)

K.step('I ask the police server to store fleet vehicle {string}', 'client', function(_, plate)
    assert(plate:match('^POLICE%d%d$') or plate:sub(1, 3) == 'FFT', 'Store tests use POLICEnn or FFT plates')
    TriggerServerEvent('kora_police:server:storeDutyVehicle', plate)
end)
K.step('I ask the police server to impound plate {string}', 'client', function(_, plate)
    assert(plate == '' or plate:sub(1, 3) == 'FFT', 'Impound tests use an empty or FFT plate')
    TriggerServerEvent('kora_police:server:impound', plate)
end)
K.step('I ask the police server to take plate {string} out of impound lot {int}', 'client', function(_, plate, lot)
    assert(plate:sub(1, 3) == 'FFT', 'Impound tests use FFT plates')
    TriggerServerEvent('police:server:TakeOutImpound', plate, lot)
end)

-- ---------------------------------------------------------------------------
-- Usable items: body armour and moneybag (server/armour.lua, server/bill.lua)
-- ---------------------------------------------------------------------------

-- The armour handler blocks on the client's progress bar, so the use runs in
-- its own thread (same approach as steps/kora/kora_consumables.lua).
K.step('I start putting on my {string}', 'server', function(ctx, item)
    assert(item == 'armor' or item == 'armour' or item == 'heavyarmor', 'Armour items are armor, armour, heavyarmor')
    local use, tester = { done = false }, ctx.tester
    ctx.state.armourUse = use
    CreateThread(function()
        local ok, result = pcall(function() return exports.kora_core:useItem(tester, item) end)
        use.ok, use.result, use.done = ok, result, true
    end)
end)
K.step('my armour use should succeed', 'server', function(ctx)
    local use = assert(ctx.state.armourUse, 'Start an armour use first')
    ctx:waitUntil(function() return use.done end, 'Armour use did not return', 10000)
    if not use.ok then error('useItem raised: ' .. tostring(use.result), 0) end
    assert(use.result == true, 'useItem refused the armour')
end)
K.step('putting on my {string} now should be refused', 'server', function(ctx, item)
    assert(item == 'armor' or item == 'armour' or item == 'heavyarmor', 'Armour items are armor, armour, heavyarmor')
    ctx:equal(exports.kora_core:useItem(ctx.tester, item), false, 'useItem result')
end)

-- moneybag reads its payout from item info.amount (bill.lua:133-146).
K.step('I hold a moneybag worth {int}', 'server', function(ctx, amount)
    assert(amount >= 0 and amount <= 10000, 'Moneybag test amount must be 0-10000')
    local core, tester = exports.kora_core, ctx.tester
    local ok, err = core:addItem(tester, 'moneybag', 1, nil, { amount = amount }, 'functional test')
    if not ok then error('Could not grant a moneybag: ' .. tostring(err), 0) end
    ctx:cleanup(function()
        if (core:getItemCount(tester, 'moneybag') or 0) > 0 then core:removeItem(tester, 'moneybag', 1, nil, 'functional test cleanup') end
    end)
end)
K.step('using my moneybag should succeed', 'server', function(ctx)
    ctx:equal(exports.kora_core:useItem(ctx.tester, 'moneybag'), true, 'useItem result')
end)
K.step('using my moneybag should be refused', 'server', function(ctx)
    ctx:equal(exports.kora_core:useItem(ctx.tester, 'moneybag'), false, 'useItem result')
end)

-- ---------------------------------------------------------------------------
-- Security cameras and legacy client events (client/camera.lua, client/compat.lua)
-- ---------------------------------------------------------------------------

-- Camera ids are Config.cameras.list keys. Any view that does open is closed
-- with id 0 in cleanup (camera.lua:74-80).
K.step('I ask to view security camera {int}', 'client', function(ctx, id)
    assert(id >= 1 and id <= 1000, 'Camera id must be 1-1000')
    ctx:cleanup(function() TriggerEvent('police:client:ActiveCamera', 0) end)
    TriggerEvent('police:client:ActiveCamera', id)
end)
-- DisableAllCameras only flips this client's online flags; all configured
-- cameras are online (config.lua Config.cameras.list), so EnableAllCameras restores them.
K.step('every security camera is offline on my client', 'client', function(ctx)
    ctx:cleanup(function() TriggerEvent('police:client:EnableAllCameras') end)
    TriggerEvent('police:client:DisableAllCameras')
end)

local UNSUPPORTED_EVENTS = {
    ['police:client:GetCuffed'] = true, ['police:client:GetEscorted'] = true, ['police:client:DeEscort'] = true,
    ['police:client:GetKidnappedTarget'] = true, ['police:client:GetKidnappedDragger'] = true,
    ['police:client:PutInVehicle'] = true, ['police:client:SetOutVehicle'] = true,
    ['police:client:SendToJail'] = true, ['police:client:TakeOutVehicle'] = true,
    ['police:client:VehicleMenuHeader'] = true, ['police:client:ImpoundMenuHeader'] = true,
    ['qb-police:client:spawnHelicopter'] = true,
}
K.step('a script sends me the legacy police event {string}', 'client', function(_, event)
    assert(UNSUPPORTED_EVENTS[event], 'Not one of the unsupported legacy events in client/compat.lua: ' .. event)
    TriggerEvent(event)
end)
