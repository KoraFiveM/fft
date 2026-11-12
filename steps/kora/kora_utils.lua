-- kora_utils: seatbelt and race harness, vehicle blacklist, hold-to-prone,
-- wanted-level suppression, the qb-smallresources control and HUD exports, and
-- server timed jobs.
-- No resource hook: every flow here is reachable through the resource's own
-- commands, key-mapping commands and exports, and results are read through
-- exports, natives and the inventory.
local K = FFT.kora
if not K then return end
K.feature('kora_utils')

-- ---------------------------------------------------------------------------
-- Seatbelt (modules/seatbelt/client.lua: command `toggleseatbelt`, export HasSeatbeltOn)
-- ---------------------------------------------------------------------------

local function seatbeltOn() return K.export('kora_utils', 'HasSeatbeltOn') == true end
local function harnessOn() return K.export('kora_utils', 'HasHarness') == true end

-- The module learns about the vehicle from kora_lib's cache a moment after the
-- ped is seated, so the key is pressed again only while the belt is still off.
K.step('I buckle my seatbelt', 'client', function(ctx)
    assert(not seatbeltOn(), 'Seatbelt is already on')
    ctx:waitUntil(function()
        if seatbeltOn() then return true end
        ExecuteCommand('toggleseatbelt')
        Wait(400)
        return seatbeltOn()
    end, 'Seatbelt did not buckle', 6000)
end)
K.step('I press the seatbelt key', 'client', function()
    K.started('kora_utils')
    ExecuteCommand('toggleseatbelt')
    Wait(400)
end)
K.step('my seatbelt should be on', 'client', function(ctx)
    ctx:waitUntil(seatbeltOn, 'Seatbelt is off', 2000)
end)
K.step('my seatbelt should be off', 'client', function(ctx)
    ctx:waitUntil(function() return not seatbeltOn() end, 'Seatbelt is on', 2000)
end)

-- ---------------------------------------------------------------------------
-- Race harness (command Config.seatbelt.harness.command = 'raceharness')
-- ---------------------------------------------------------------------------

K.step('my race harness should be attached', 'client', function(ctx)
    ctx:waitUntil(harnessOn, 'Race harness is not attached', 3000)
end)
K.step('my race harness should not be attached', 'client', function(ctx)
    ctx:waitUntil(function() return not harnessOn() end, 'Race harness is attached', 3000)
end)
-- A fresh harness has Config.HarnessUses = 20; attaching it spends one.
K.step('my race harness item should have {int} uses left', 'server', function(ctx, uses)
    local function remaining()
        for _, entry in pairs(K.player(ctx).items or {}) do
            if entry and entry.name == 'harness' then return type(entry.info) == 'table' and entry.info.uses or nil end
        end
        return false
    end
    ctx:waitUntil(function() return remaining() == uses end,
        ('Harness uses are %s, expected %d'):format(tostring(remaining()), uses), 3000)
end)

-- ---------------------------------------------------------------------------
-- Vehicle blacklist (modules/blacklist/server.lua cancels entityCreating)
-- ---------------------------------------------------------------------------

-- Config.blacklist.vehicles in kora_utils/config.lua. Only these may be requested.
local BLACKLISTED = {
    rhino = true, lazer = true, hydra = true, savage = true, buzzard = true, oppressor = true, oppressor2 = true,
    scramjet = true, deluxo = true, insurgent = true, blimp = true, blimp2 = true, blimp3 = true,
}

K.step('I try to spawn the blacklisted vehicle {string}', 'client', function(ctx, model)
    K.started('kora_utils')
    assert(BLACKLISTED[model], model .. ' is not in the vehicle blacklist')
    local hash = GetHashKey(model)
    assert(IsModelInCdimage(hash) and IsModelAVehicle(hash), 'Unknown vehicle model: ' .. model)
    RequestModel(hash)
    ctx:waitUntil(function() return HasModelLoaded(hash) end, 'Vehicle model did not load: ' .. model, 10000)
    local ped = PlayerPedId()
    local at = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.5)
    local vehicle = CreateVehicle(hash, at.x, at.y, at.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(hash)
    ctx.state.blockedVehicle = vehicle or 0
    ctx:cleanup(function()
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end)
end)
K.step('the blacklisted vehicle should not exist', 'client', function(ctx)
    local vehicle = assert(ctx.state.blockedVehicle, 'Try to spawn a blacklisted vehicle first')
    ctx:waitUntil(function() return vehicle == 0 or not DoesEntityExist(vehicle) end,
        'The blacklisted vehicle still exists', 8000)
end)

-- ---------------------------------------------------------------------------
-- Prone (modules/crouch/client.lua: Kora.keybind 'kora_utils_crouch';
-- holding it past Config.crouch.holdDuration = 500 ms goes prone)
-- ---------------------------------------------------------------------------

local CROUCH_KEY = 'kora_utils_crouch'

-- Config.crouch.proneAnimDict / proneForwardAnim.
local function isProne()
    return IsEntityPlayingAnim(PlayerPedId(), 'move_crawl', 'onfront_fwd', 3) == true
end

local function tapStanceKey()
    ExecuteCommand('+' .. CROUCH_KEY)
    Wait(50)
    ExecuteCommand('-' .. CROUCH_KEY)
end

K.step('I hold the stance key long enough to go prone', 'client', function(ctx)
    K.started('kora_utils')
    ctx.state.stanceKeyHeld = true
    ctx:cleanup(function()
        if ctx.state.stanceKeyHeld then ExecuteCommand('-' .. CROUCH_KEY) end
        Wait(200)
        -- A tap while prone stands the ped up again.
        if isProne() then tapStanceKey() end
    end)
    ExecuteCommand('+' .. CROUCH_KEY)
    -- Held like a player does: past the 500 ms hold, and then until the ped is
    -- down. prone() first loads the move_crawl dictionary (modules/crouch/client.lua),
    -- and a release during that load counts as a tap, whose crouch() then replaces
    -- the prone stance. The hold is bounded; the next step asserts the result.
    local earliest, deadline = GetGameTimer() + 1200, GetGameTimer() + 6000
    while GetGameTimer() < deadline and (GetGameTimer() < earliest or not isProne()) do
        -- Seated, the resource refuses the stance outright: nothing to wait for.
        if GetGameTimer() >= earliest and IsPedInAnyVehicle(PlayerPedId(), false) then break end
        ctx:check()
        Wait(50)
    end
    ExecuteCommand('-' .. CROUCH_KEY)
    ctx.state.stanceKeyHeld = false
end)
K.step('I tap the stance key', 'client', function()
    K.started('kora_utils')
    tapStanceKey()
    Wait(300)
end)
K.step('I should be lying prone', 'client', function(ctx)
    -- The detail lists what modules/crouch/client.lua canChangeStance refuses on.
    ctx:waitUntil(isProne, 'The ped is not playing the prone animation', 3000, function()
        local ped = PlayerPedId()
        local function flag(value) return (value == true or value == 1) and 'yes' or 'no' end
        return (' (ragdoll %s, falling %s, jumping %s, climbing %s, swimming %s, in vehicle %s, dead %s, emote active %s, crawl dictionary loaded %s)')
            :format(flag(IsPedRagdoll(ped)), flag(IsPedFalling(ped)), flag(IsPedJumping(ped)), flag(IsPedClimbing(ped)),
                flag(IsPedSwimming(ped)), flag(IsPedInAnyVehicle(ped, false)), flag(IsEntityDead(ped)),
                flag(LocalPlayer.state['kora_emotemenu:active'] ~= nil and LocalPlayer.state['kora_emotemenu:active'] ~= false),
                flag(HasAnimDictLoaded('move_crawl')))
    end)
end)
K.step('I should not be lying prone', 'client', function(ctx)
    ctx:waitUntil(function() return not isProne() end, 'The ped is still prone', 3000)
end)

-- ---------------------------------------------------------------------------
-- Wanted level (modules/wantedlevel/client.lua calls SetMaxWantedLevel(0))
-- ---------------------------------------------------------------------------

K.step('my maximum wanted level should be {int}', 'client', function(ctx, level)
    K.started('kora_utils')
    ctx:equal(GetMaxWantedLevel(), level, 'Maximum wanted level')
end)

-- ---------------------------------------------------------------------------
-- qb-smallresources control and HUD exports (client/compat.lua, client/hud.lua)
-- ---------------------------------------------------------------------------

local LISTS = {
    control = { add = 'addDisableControls', remove = 'removeDisableControls', get = 'getDisableControls' },
    hud = { add = 'addDisableHudComponents', remove = 'removeDisableHudComponents', get = 'getDisableHudComponents' },
}

local function occurrences(kind, id)
    local list = K.export('kora_utils', LISTS[kind].get)
    assert(type(list) == 'table', LISTS[kind].get .. ' returned no list')
    local total = 0
    for _, value in ipairs(list) do if value == id then total = total + 1 end end
    return total, #list
end

local function addEntry(ctx, kind, id)
    assert(id >= 0 and id <= 400, 'Id out of range')
    local before = occurrences(kind, id)
    ctx.state.utilsListBefore = before
    ctx:cleanup(function()
        local now = occurrences(kind, id)
        while now > before do
            exports.kora_utils[LISTS[kind].remove](exports.kora_utils, id)
            now = now - 1
        end
    end)
    K.export('kora_utils', LISTS[kind].add, id)
    ctx:equal(occurrences(kind, id), before + 1, 'Entries for ' .. kind .. ' ' .. id)
end

local function removeEntry(ctx, kind, id)
    local before = assert(ctx.state.utilsListBefore, 'Add the entry first')
    K.export('kora_utils', LISTS[kind].remove, id)
    ctx:equal(occurrences(kind, id), before, 'Entries for ' .. kind .. ' ' .. id)
end

-- Entries that client/compat.lua and client/hud.lua must ignore: a negative id,
-- a fractional id and a non-number.
local function assertInvalidIgnored(ctx, kind)
    local _, before = occurrences(kind, -1)
    K.export('kora_utils', LISTS[kind].add, { -1 })
    K.export('kora_utils', LISTS[kind].add, { 1.5 })
    K.export('kora_utils', LISTS[kind].add, 'fft')
    local _, after = occurrences(kind, -1)
    ctx:equal(after, before, 'Disabled ' .. kind .. ' entries')
end

K.step('I add the control {int} to the disabled controls', 'client', function(ctx, id) addEntry(ctx, 'control', id) end)
K.step('I remove the control {int} from the disabled controls', 'client', function(ctx, id) removeEntry(ctx, 'control', id) end)
K.step('the control {int} should be disabled every frame', 'client', function(ctx, id)
    assert(occurrences('control', id) > 0, 'Control is not listed')
    ctx:waitUntil(function() return not IsControlEnabled(2, id) end,
        'Control ' .. id .. ' is still enabled', 2000)
end)
K.step('invalid entries should not reach the disabled controls', 'client', function(ctx) assertInvalidIgnored(ctx, 'control') end)

K.step('I add the HUD component {int} to the hidden HUD components', 'client', function(ctx, id) addEntry(ctx, 'hud', id) end)
K.step('I remove the HUD component {int} from the hidden HUD components', 'client', function(ctx, id) removeEntry(ctx, 'hud', id) end)
K.step('invalid entries should not reach the hidden HUD components', 'client', function(ctx) assertInvalidIgnored(ctx, 'hud') end)

K.step('a non-boolean ammo display setting should be ignored', 'client', function(ctx)
    local before = K.export('kora_utils', 'getDisplayAmmo')
    ctx:equal(type(before), 'boolean', 'getDisplayAmmo type')
    K.export('kora_utils', 'setDisplayAmmo', 'fft')
    K.export('kora_utils', 'setDisplayAmmo', 1)
    ctx:equal(K.export('kora_utils', 'getDisplayAmmo'), before, 'Ammo display setting')
end)

-- ---------------------------------------------------------------------------
-- Timed jobs (server/timedjobs.lua: CreateTimedJob / ForceRunTimedJob / StopTimedJob)
-- ---------------------------------------------------------------------------

K.step('I schedule a timed job that is not due soon', 'server', function(ctx)
    -- Half an hour away, so the minute scheduler cannot fire it during the scenario.
    local due = os.date('*t', os.time() + 1800)
    local record = { runs = 0 }
    ctx.state.timedJob = record
    local id = K.export('kora_utils', 'CreateTimedJob', due.hour, due.min, function(day, hour, minute)
        record.runs = record.runs + 1
        record.day, record.hour, record.minute = day, hour, minute
    end)
    assert(type(id) == 'number', 'CreateTimedJob returned no id: ' .. tostring(id))
    record.id = id
    ctx:cleanup(function() pcall(function() exports.kora_utils:StopTimedJob(id) end) end)
end)
K.step('I force the timed job to run', 'server', function(ctx)
    local record = assert(ctx.state.timedJob, 'Schedule a timed job first')
    K.export('kora_utils', 'ForceRunTimedJob', record.id)
end)
K.step('I stop the timed job', 'server', function(ctx)
    local record = assert(ctx.state.timedJob, 'Schedule a timed job first')
    K.export('kora_utils', 'StopTimedJob', record.id)
end)
K.step('the timed job should have run {int} time with the current clock', 'server', function(ctx, runs)
    local record = assert(ctx.state.timedJob, 'Schedule a timed job first')
    ctx:waitUntil(function() return record.runs >= runs end, 'Timed job ran ' .. record.runs .. ' times', 2000)
    Wait(300)
    ctx:equal(record.runs, runs, 'Timed job runs')
    assert(math.type(record.day) == 'integer' and record.day >= 1 and record.day <= 7, 'Day argument out of range: ' .. tostring(record.day))
    assert(math.type(record.hour) == 'integer' and record.hour >= 0 and record.hour <= 23, 'Hour argument out of range: ' .. tostring(record.hour))
    assert(math.type(record.minute) == 'integer' and record.minute >= 0 and record.minute <= 59, 'Minute argument out of range: ' .. tostring(record.minute))
end)
K.step('scheduling a timed job with invalid arguments should return nothing', 'server', function()
    local function refused(...)
        local id = K.export('kora_utils', 'CreateTimedJob', ...)
        if id ~= nil then
            pcall(function() exports.kora_utils:StopTimedJob(id) end)
            error('CreateTimedJob accepted invalid arguments', 0)
        end
    end
    refused('noon', 0, function() end)
    refused(12, '30', function() end)
    refused(12, 30, 'not a function')
end)

-- ===========================================================================
-- Deeper coverage. Sources: modules/seatbelt/client.lua and server.lua,
-- client/compat.lua, client/hud.lua, modules/crouch/client.lua,
-- modules/wantedlevel/client.lua, server/timedjobs.lua, config.lua.
-- ===========================================================================

local ALIAS = 'qb-smallresources' -- provided by kora_utils through Kora.compat.provideExport

-- Seatbelt -------------------------------------------------------------------

-- AddEventHandler('kora_utils:client:toggleSeatbelt', toggleSeatbelt) in modules/seatbelt/client.lua.
K.step('I buckle my seatbelt through the kora_utils toggle event', 'client', function(ctx)
    K.started('kora_utils')
    assert(not seatbeltOn(), 'Seatbelt is already on')
    ctx:waitUntil(function()
        if seatbeltOn() then return true end
        TriggerEvent('kora_utils:client:toggleSeatbelt')
        Wait(400)
        return seatbeltOn()
    end, 'Seatbelt did not buckle through the toggle event', 6000)
end)
K.step('I toggle my seatbelt through the kora_utils toggle event', 'client', function()
    K.started('kora_utils')
    TriggerEvent('kora_utils:client:toggleSeatbelt')
    Wait(400)
end)
-- announce() sets LocalPlayer.state.seatbelt / .harness (not replicated).
K.step('my seatbelt state should read {string}', 'client', function(ctx, expected)
    ctx:waitUntil(function() return tostring(LocalPlayer.state.seatbelt == true) == expected end,
        'LocalPlayer.state.seatbelt is ' .. tostring(LocalPlayer.state.seatbelt), 2000)
end)
K.step('my harness state should read {string}', 'client', function(ctx, expected)
    ctx:waitUntil(function() return tostring(LocalPlayer.state.harness == true) == expected end,
        'LocalPlayer.state.harness is ' .. tostring(LocalPlayer.state.harness), 2000)
end)

-- The belt and harness frame task calls DisableControlAction(0, 75) (INPUT_VEH_EXIT).
K.step('the vehicle exit control should be usable', 'client', function(ctx)
    ctx:waitUntil(function() return IsControlEnabled(0, 75) == true end,
        'Control 75 (vehicle exit) is disabled by something else', 2000)
end)
K.step('the vehicle exit control should be blocked', 'client', function(ctx)
    ctx:waitUntil(function() return IsControlEnabled(0, 75) == false end, 'Control 75 (vehicle exit) is enabled', 2000)
    for _ = 1, 10 do
        ctx:check()
        Wait(50)
        assert(IsControlEnabled(0, 75) == false, 'Control 75 (vehicle exit) was enabled again')
    end
end)

K.step('I leave my temporary vehicle', 'client', function(ctx)
    local vehicle = assert(ctx.state.vehicle, 'Drive a temporary vehicle first')
    TaskLeaveVehicle(PlayerPedId(), vehicle, 16) -- 16: warp out
    ctx:waitUntil(function() return not IsPedInAnyVehicle(PlayerPedId(), false) end, 'Could not leave the vehicle', 5000)
end)

K.step('the qb-smallresources seatbelt and harness exports should match kora_utils', 'client', function(ctx)
    K.started('kora_utils')
    ctx:equal(exports[ALIAS]:HasSeatbeltOn(), K.export('kora_utils', 'HasSeatbeltOn'), 'qb-smallresources HasSeatbeltOn')
    ctx:equal(exports[ALIAS]:HasHarness(), K.export('kora_utils', 'HasHarness'), 'qb-smallresources HasHarness')
end)

-- Race harness ---------------------------------------------------------------

-- modules/seatbelt/server.lua harnessItem: info.uses must be a whole number 1..Config.HarnessUses (20).
K.step('I hold a race harness with {int} uses', 'server', function(ctx, uses)
    assert(uses >= -5 and uses <= 50, 'Harness uses must be -5..50 for this step')
    local core, tester = exports.kora_core, ctx.tester
    local ok, err = core:addItem(tester, 'harness', 1, nil, { uses = uses }, 'functional test')
    if not ok then error('Could not grant a harness: ' .. tostring(err), 0) end
    ctx:cleanup(function()
        local left = core:getItemCount(tester, 'harness') or 0
        if left > 0 then core:removeItem(tester, 'harness', left, nil, 'functional test cleanup') end
    end)
end)

-- Vehicle blacklist ----------------------------------------------------------
-- (reuses the steps above with every Config.blacklist.vehicles entry)

-- Control and HUD lists ------------------------------------------------------

local function count(kind, id, source)
    local list = source == ALIAS and exports[ALIAS][LISTS[kind].get](exports[ALIAS]) or K.export('kora_utils', LISTS[kind].get)
    assert(type(list) == 'table', LISTS[kind].get .. ' returned no list')
    local total = 0
    for _, value in ipairs(list) do if value == id then total = total + 1 end end
    return total
end

-- Removes entries of `id` added during the scenario, down to `baseline`.
local function restoreTo(ctx, kind, id, baseline)
    ctx:cleanup(function()
        local now = count(kind, id)
        while now > baseline do
            exports.kora_utils[LISTS[kind].remove](exports.kora_utils, id)
            now = now - 1
        end
    end)
end

K.step('I add the control {int} twice in one list', 'client', function(ctx, id)
    assert(id >= 0 and id <= 400, 'Id out of range')
    local before = count('control', id)
    restoreTo(ctx, 'control', id, before)
    K.export('kora_utils', 'addDisableControls', { id, id })
    ctx:equal(count('control', id), before + 2, 'Entries for control ' .. id)
    ctx.state.utilsListBefore = before + 1 -- one removal from here should leave one entry
end)
K.step('I add the HUD component {int} twice in one list', 'client', function(ctx, id)
    assert(id >= 0 and id <= 30, 'Id out of range')
    local before = count('hud', id)
    restoreTo(ctx, 'hud', id, before)
    K.export('kora_utils', 'addDisableHudComponents', { id, id })
    ctx:equal(count('hud', id), before + 2, 'Entries for HUD component ' .. id)
    ctx.state.utilsListBefore = before + 1
end)

-- visitControls / components reject the whole call when any entry is invalid.
local INVALID = { -1, 1.5, 'fft' }
local function mixedRefused(ctx, kind, id)
    local before = count(kind, id)
    restoreTo(ctx, kind, id, before)
    for _, bad in ipairs(INVALID) do
        K.export('kora_utils', LISTS[kind].add, { id, bad })
        K.export('kora_utils', LISTS[kind].add, { bad, id })
    end
    ctx:equal(count(kind, id), before, ('Entries for %s %d after mixed lists'):format(kind, id))
end
K.step('a control list mixing {int} with invalid entries should be ignored whole', 'client', function(ctx, id)
    mixedRefused(ctx, 'control', id)
end)
K.step('a HUD component list mixing {int} with invalid entries should be ignored whole', 'client', function(ctx, id)
    mixedRefused(ctx, 'hud', id)
end)

local function removeUnlisted(ctx, kind, id)
    local list = K.export('kora_utils', LISTS[kind].get)
    assert(count(kind, id) == 0, ('%s %d is already listed by another resource; pick an unused id'):format(kind, id))
    K.export('kora_utils', LISTS[kind].remove, id)
    ctx:equal(#K.export('kora_utils', LISTS[kind].get), #list, kind .. ' list length')
end
K.step('removing the unlisted control {int} should change nothing', 'client', function(ctx, id) removeUnlisted(ctx, 'control', id) end)
K.step('removing the unlisted HUD component {int} should change nothing', 'client', function(ctx, id) removeUnlisted(ctx, 'hud', id) end)

K.step('I add the control {int} through the qb-smallresources exports', 'client', function(ctx, id)
    assert(id >= 0 and id <= 400, 'Id out of range')
    K.started('kora_utils')
    local before = count('control', id)
    ctx.state.utilsListBefore = before
    restoreTo(ctx, 'control', id, before)
    exports[ALIAS]:addDisableControls(id)
    ctx:equal(count('control', id), before + 1, 'Entries for control ' .. id)
    ctx:equal(count('control', id, ALIAS), before + 1, 'qb-smallresources getDisableControls entries for ' .. id)
end)
K.step('I add the HUD component {int} through the qb-smallresources exports', 'client', function(ctx, id)
    assert(id >= 0 and id <= 30, 'Id out of range')
    K.started('kora_utils')
    local before = count('hud', id)
    ctx.state.utilsListBefore = before
    restoreTo(ctx, 'hud', id, before)
    exports[ALIAS]:addDisableHudComponents(id)
    ctx:equal(count('hud', id), before + 1, 'Entries for HUD component ' .. id)
    ctx:equal(count('hud', id, ALIAS), before + 1, 'qb-smallresources getDisableHudComponents entries for ' .. id)
end)

-- Ammo display and hands up --------------------------------------------------

K.step('the ammo display setting should round-trip through kora_utils', 'client', function(ctx)
    local before = K.export('kora_utils', 'getDisplayAmmo')
    ctx:equal(type(before), 'boolean', 'getDisplayAmmo type')
    ctx:cleanup(function() exports.kora_utils:setDisplayAmmo(before) end)
    K.export('kora_utils', 'setDisplayAmmo', false)
    ctx:equal(K.export('kora_utils', 'getDisplayAmmo'), false, 'after setDisplayAmmo false')
    ctx:equal(exports[ALIAS]:getDisplayAmmo(), false, 'qb-smallresources getDisplayAmmo')
    K.export('kora_utils', 'setDisplayAmmo', true)
    ctx:equal(K.export('kora_utils', 'getDisplayAmmo'), true, 'after setDisplayAmmo true')
end)

-- client/hud.lua getHandsup reads missminuteman_1ig_2 / handsup_base on the ped.
local HANDSUP_DICT, HANDSUP_CLIP = 'missminuteman_1ig_2', 'handsup_base'
K.step('I raise my hands', 'client', function(ctx)
    RequestAnimDict(HANDSUP_DICT)
    ctx:waitUntil(function() return HasAnimDictLoaded(HANDSUP_DICT) end, 'Hands-up animation did not load', 5000)
    ctx:cleanup(function()
        local ped = PlayerPedId()
        if IsEntityPlayingAnim(ped, HANDSUP_DICT, HANDSUP_CLIP, 3) then StopAnimTask(ped, HANDSUP_DICT, HANDSUP_CLIP, 1.0) end
        RemoveAnimDict(HANDSUP_DICT)
    end)
    TaskPlayAnim(PlayerPedId(), HANDSUP_DICT, HANDSUP_CLIP, 8.0, -8.0, -1, 49, 0.0, false, false, false)
end)
K.step('I lower my hands', 'client', function()
    StopAnimTask(PlayerPedId(), HANDSUP_DICT, HANDSUP_CLIP, 1.0)
end)
K.step('kora_utils should report my hands {string}', 'client', function(ctx, expected)
    assert(expected == 'up' or expected == 'down', 'Use "up" or "down"')
    local want = expected == 'up'
    ctx:waitUntil(function() return K.export('kora_utils', 'getHandsup') == want end, 'getHandsup is not ' .. tostring(want), 3000)
    ctx:equal(exports[ALIAS]:getHandsup(), want, 'qb-smallresources getHandsup')
end)

-- Wanted level ---------------------------------------------------------------

K.step('raising my wanted level should leave it at 0', 'client', function(ctx)
    K.started('kora_utils')
    local player = PlayerId()
    ctx:cleanup(function() ClearPlayerWantedLevel(PlayerId()) end)
    SetPlayerWantedLevel(player, 2, false)
    SetPlayerWantedLevelNow(player, false)
    Wait(500)
    ctx:equal(GetPlayerWantedLevel(player), 0, 'Wanted level after raising it')
end)

-- Crouch and prone crawl -----------------------------------------------------

-- Config.crouch.crouchClipset = 'move_ped_crouched'.
local function crouched()
    local ok, clipset = pcall(GetPedMovementClipset, PlayerPedId())
    assert(ok, 'GetPedMovementClipset is not available on this client build')
    return clipset == GetHashKey('move_ped_crouched')
end
K.step('I tap the stance key to crouch', 'client', function(ctx)
    K.started('kora_utils')
    ctx:cleanup(function() if crouched() then tapStanceKey() end end)
    tapStanceKey()
    Wait(300)
end)
K.step('I should be crouched', 'client', function(ctx)
    ctx:waitUntil(crouched, 'The ped is not using the crouched movement clipset', 3000)
end)
K.step('I should not be crouched', 'client', function(ctx)
    ctx:waitUntil(function() return not crouched() end, 'The ped is still crouched', 3000)
end)

-- Kora.keybind 'kora_utils_prone_backward' drives Config.crouch.proneBackwardAnim = 'onfront_bwd'.
local function crawlingBack() return IsEntityPlayingAnim(PlayerPedId(), 'move_crawl', 'onfront_bwd', 3) == true end
K.step('I hold the crawl backward key', 'client', function(ctx)
    K.started('kora_utils')
    ctx.state.crawlKeyHeld = true
    ctx:cleanup(function()
        if ctx.state.crawlKeyHeld then ExecuteCommand('-kora_utils_prone_backward') end
        Wait(100)
        -- The backward idle keeps onfront_bwd; a tap stands the ped up.
        if crawlingBack() then tapStanceKey() end
    end)
    ExecuteCommand('+kora_utils_prone_backward')
end)
K.step('I release the crawl backward key', 'client', function(ctx)
    ExecuteCommand('-kora_utils_prone_backward')
    ctx.state.crawlKeyHeld = false
    Wait(200)
end)
K.step('I should be crawling backwards', 'client', function(ctx)
    ctx:waitUntil(crawlingBack, 'The ped is not playing the backward crawl', 3000)
end)
K.step('I should not be lying on the ground', 'client', function(ctx)
    ctx:waitUntil(function() return not crawlingBack() and not isProne() end, 'The ped is still lying down', 3000)
end)

-- Named timed jobs (server/timedjobs.lua) -------------------------------------

local function scheduleNamed(ctx, name, source, failing)
    ctx.state.timedJobs = ctx.state.timedJobs or {}
    assert(not ctx.state.timedJobs[name], 'Timed job already scheduled: ' .. name)
    local due = os.date('*t', os.time() + 1800) -- not due during the scenario
    local record = { runs = 0 }
    ctx.state.timedJobs[name] = record
    local callback = function(day, hour, minute)
        record.runs = record.runs + 1
        record.day, record.hour, record.minute = day, hour, minute
        if failing then error('fft timed job failure on purpose', 0) end
    end
    local id
    if source == ALIAS then
        K.started('kora_utils')
        id = exports[ALIAS]:CreateTimedJob(due.hour, due.min, callback)
    else
        id = K.export('kora_utils', 'CreateTimedJob', due.hour, due.min, callback)
    end
    assert(type(id) == 'number', 'CreateTimedJob returned no id: ' .. tostring(id))
    record.id = id
    ctx:cleanup(function() pcall(function() exports.kora_utils:StopTimedJob(id) end) end)
end
local function named(ctx, name)
    return assert(ctx.state.timedJobs and ctx.state.timedJobs[name], 'No timed job named ' .. name)
end

K.step('I schedule a timed job {string} that is not due soon', 'server', function(ctx, name) scheduleNamed(ctx, name) end)
K.step('I schedule a timed job {string} through qb-smallresources that is not due soon', 'server', function(ctx, name)
    scheduleNamed(ctx, name, ALIAS)
end)
K.step('I schedule a failing timed job {string} that is not due soon', 'server', function(ctx, name)
    scheduleNamed(ctx, name, nil, true)
end)
K.step('I force the timed job {string} to run', 'server', function(ctx, name)
    K.export('kora_utils', 'ForceRunTimedJob', named(ctx, name).id)
end)
K.step('I stop the timed job {string}', 'server', function(ctx, name)
    K.export('kora_utils', 'StopTimedJob', named(ctx, name).id)
end)
K.step('the timed job {string} should have run {int} times', 'server', function(ctx, name, runs)
    local record = named(ctx, name)
    local deadline = GetGameTimer() + 2000
    while record.runs < runs and GetGameTimer() < deadline do ctx:check() Wait(50) end
    Wait(300)
    ctx:equal(record.runs, runs, ('Runs of timed job "%s"'):format(name))
end)
K.step('the timed job {string} should have a later id than {string}', 'server', function(ctx, later, earlier)
    local a, b = named(ctx, later).id, named(ctx, earlier).id
    assert(a > b, ('Timed job id %d is not later than %d'):format(a, b))
end)
K.step('forcing and stopping an unknown timed job id should do nothing', 'server', function(ctx)
    ctx:equal(K.export('kora_utils', 'ForceRunTimedJob', 999999999), nil, 'ForceRunTimedJob of an unknown id')
    ctx:equal(K.export('kora_utils', 'StopTimedJob', 999999999), nil, 'StopTimedJob of an unknown id')
end)
