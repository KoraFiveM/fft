-- kora_ambulance: hospital check-in care, EMS duty, facility target options,
-- first-aid item guards and the house-call commands.
--
-- No resource hook. Check-in, duty and the facility options are kora_target
-- zones and commands; results are asserted through the getPatientStatus export,
-- money, job duty and the resource's own local server events
-- (kora_ambulance:server:onPatientCheckedIn / onBedReleased / onBedCareCompleted,
-- server/hospital.lua).
--
-- The tester is never downed or killed: entering laststand or dying raises an
-- automatic EMS dispatch call to every on-duty medic (Config.dispatch.autoCall).
local K = FFT.kora
if not K then return end
K.feature('kora_ambulance')

local RESOURCE = 'kora_ambulance'

-- ---------------------------------------------------------------------------
-- Server: patient ledger
-- ---------------------------------------------------------------------------

-- exports.kora_ambulance:getPatientStatus (server/death.lua): { state, wounds, bleeding, ... }.
local function patient(ctx)
    local status = K.export(RESOURCE, 'getPatientStatus', ctx.tester)
    assert(type(status) == 'table', 'Patient status is unavailable')
    return status
end

K.step('my patient status should be {string}', 'server', function(ctx, state)
    ctx:waitUntil(function() return patient(ctx).state == state end,
        ('Patient state is %s, expected %s'):format(tostring(patient(ctx).state), state), 3000)
end)

-- The server closes the wounds of a player at full health on its 5 s sweep
-- (Config.injuries.clearWhenHealthy), so allow for one pass.
K.step('I should have no open wounds', 'server', function(ctx)
    ctx:waitUntil(function()
        local status = patient(ctx)
        return next(status.wounds or {}) == nil and status.bleeding ~= true
    end, 'The patient ledger still lists an open wound', 8000)
end)

-- ---------------------------------------------------------------------------
-- Server: hospital care sessions
-- ---------------------------------------------------------------------------

local CHECKED_IN = 'kora_ambulance:server:onPatientCheckedIn'   -- (src, hospital, bedIndex)
local RELEASED = 'kora_ambulance:server:onBedReleased'          -- (src, hospital, bedIndex, reason)
local COMPLETED = 'kora_ambulance:server:onBedCareCompleted'    -- (src, hospital, bedIndex, cost)

K.step('I watch my hospital care events', 'server', function(ctx)
    K.started(RESOURCE)
    local tester = ctx.tester
    local mine = function(src) return src == tester end
    K.capture(ctx, CHECKED_IN, mine)
    K.capture(ctx, RELEASED, mine)
    K.capture(ctx, COMPLETED, mine)
end)

local function watched(ctx, event)
    assert(ctx.state.captured and ctx.state.captured[event], 'Watch the hospital care events before acting')
    return K.captured(ctx, event)
end

K.step('my hospital check-in at {string} should have been recorded', 'server', function(ctx, hospital)
    ctx:waitUntil(function()
        for _, record in ipairs(watched(ctx, CHECKED_IN)) do
            if record[2] == hospital and type(record[3]) == 'number' then return true end
        end
    end, 'No check-in was recorded at ' .. hospital, 5000)
end)

K.step('no hospital check-in should have been recorded for me', 'server', function(ctx)
    Wait(500)
    ctx:equal(#watched(ctx, CHECKED_IN), 0, 'Recorded check-ins')
end)

K.step('my hospital bed should have been released with the reason {string}', 'server', function(ctx, reason)
    ctx:waitUntil(function()
        for _, record in ipairs(watched(ctx, RELEASED)) do
            if record[4] == reason then return true end
        end
    end, 'No bed release with the reason ' .. reason, 5000)
end)

K.step('my hospital care should have been completed for {int}', 'server', function(ctx, cost)
    ctx:waitUntil(function()
        for _, record in ipairs(watched(ctx, COMPLETED)) do
            if record[4] == cost then return true end
        end
    end, 'No completed care charged at ' .. cost, 5000)
end)

K.step('no hospital care should have been completed for me', 'server', function(ctx)
    Wait(500)
    ctx:equal(#watched(ctx, COMPLETED), 0, 'Completed care sessions')
end)

-- ---------------------------------------------------------------------------
-- Server: first-aid items
-- ---------------------------------------------------------------------------

-- exports.kora_core:useItem runs the handler kora_ambulance registered with
-- createUseable (server/items.lua), as using the item from the inventory does.
K.step('I use my {string} for first aid', 'server', function(ctx, item)
    K.started(RESOURCE)
    assert(K.count(ctx, item) > 0, 'The tester holds no ' .. item)
    exports.kora_core:useItem(ctx.tester, item)
end)

-- ---------------------------------------------------------------------------
-- Client: health fixtures and the bed key
-- ---------------------------------------------------------------------------

local function restoreHealth()
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then SetEntityHealth(ped, GetEntityMaxHealth(ped)) end
end

-- Releases a care session a failed scenario left behind. The key mapping is
-- disabled while no bed is reserved, so this is a no-op otherwise.
local function leaveBed()
    ExecuteCommand('+kora_ambulance_leave_bed')
    Wait(50)
    ExecuteCommand('-kora_ambulance_leave_bed')
end

K.step('I am in full health', 'client', function()
    restoreHealth()
    -- The server reads the replicated ped health for the injury check.
    Wait(1000)
    local ped = PlayerPedId()
    assert(GetEntityHealth(ped) >= GetEntityMaxHealth(ped), 'Health did not return to full')
end)

-- Fixture: lowers the tester's own health without a damage event, so the
-- server sees an injured (never downed) patient. Config.injuries.healthTolerance
-- is 5, so anything above that qualifies for check-in.
K.step('I am hurt by {int} health points', 'client', function(ctx, amount)
    assert(amount >= 10 and amount <= 60, 'Hurt amount must be 10-60')
    local ped = PlayerPedId()
    assert(not IsEntityDead(ped), 'The tester is dead')
    local target = GetEntityMaxHealth(ped) - amount
    assert(target > 120, 'Refusing to lower health near the fatal line (max health ' .. GetEntityMaxHealth(ped) .. ')')
    ctx:cleanup(function()
        pcall(leaveBed)
        restoreHealth()
    end)
    SetEntityHealth(ped, target)
    Wait(1500)
    assert(GetEntityHealth(PlayerPedId()) <= target + 2, 'Health was not lowered')
end)

K.step('I should be back at full health', 'client', function(ctx)
    ctx:waitUntil(function()
        local ped = PlayerPedId()
        return GetEntityHealth(ped) >= GetEntityMaxHealth(ped)
    end, 'Health was not restored', 5000)
end)

-- The real key path: Kora.keybind.add registers +kora_ambulance_leave_bed
-- (client/hospital.lua), enabled only while a bed is reserved.
K.step('I press the hospital leave bed key', 'client', function()
    K.started(RESOURCE)
    leaveBed()
end)

-- ---------------------------------------------------------------------------
-- Client: real wounds
-- ---------------------------------------------------------------------------

-- Fixture: a self-inflicted hit. ApplyDamageToPed raises the same native
-- CEventNetworkEntityDamage a real hit does (client/damage.lua, which notes
-- kora_core's needs damage reaches it the same way), so the resource's own
-- correlator reports the wound and server/death.lua (hitObserved) records it
-- with Wounds.severityFromDamage (thresholds 8/20/40, +1 on a vital part).
-- Config.injuries.healGraceMs (2500) after any heal drops reports, so wait it
-- out first. Health (and so the wound, via the 5 s healthy sweep) is restored
-- in cleanup.
K.step('I take {int} damage', 'client', function(ctx, amount)
    assert(amount >= 3 and amount <= 30, 'Damage must be 3-30 (Config.injuries.minDamage is 3)')
    K.started(RESOURCE)
    local ped = PlayerPedId()
    assert(not IsEntityDead(ped), 'The tester is dead')
    ctx:cleanup(function()
        pcall(leaveBed)
        restoreHealth()
    end)
    Wait(3000)
    local before = GetEntityHealth(ped)
    assert(before - amount > 120, 'Refusing to deal damage near the fatal line')
    ApplyDamageToPed(ped, amount, false)
    ctx:waitUntil(function() return GetEntityHealth(PlayerPedId()) < before end, 'The damage did not land', 3000)
    -- Config.injuries.captureWindow (500 ms) plus replication of the new health.
    Wait(1500)
end)

-- ---------------------------------------------------------------------------
-- Server: wound ledger
-- ---------------------------------------------------------------------------

local function woundTiers(ctx)
    local tiers = {}
    for _, tier in pairs(patient(ctx).wounds or {}) do tiers[#tiers + 1] = tier end
    return tiers
end

-- Wounds are server-owned (exports.kora_ambulance:getPatientStatus). The
-- server-side cleanup is exports.kora_ambulance:fullRevive (server/death.lua
-- Death.fullRevive), which closes every wound of an alive player.
K.step('I should have an open wound of tier {int} or {int}', 'server', function(ctx, low, high)
    local tester = ctx.tester
    ctx:cleanup(function() pcall(function() exports.kora_ambulance:fullRevive(tester) end) end)
    ctx:waitUntil(function()
        local tiers = woundTiers(ctx)
        if #tiers == 0 then return false end
        for _, tier in ipairs(tiers) do
            if tier ~= low and tier ~= high then return false end
        end
        return true
    end, ('Expected open wounds of tier %d or %d'):format(low, high), 5000, function()
        return (' | the ledger lists tiers [%s]'):format(table.concat(woundTiers(ctx), ', '))
    end)
end)

K.step('my open wound should still be listed', 'server', function(ctx)
    Wait(500)
    assert(#woundTiers(ctx) > 0, 'The wound was closed')
end)

K.step('I am fully revived by the server', 'server', function(ctx)
    assert(K.export(RESOURCE, 'fullRevive', ctx.tester) == true, 'fullRevive refused the tester')
end)

-- ---------------------------------------------------------------------------
-- Server: check-ins and bills
-- ---------------------------------------------------------------------------

K.step('only one hospital check-in should have been recorded for me', 'server', function(ctx)
    Wait(500)
    ctx:equal(#watched(ctx, CHECKED_IN), 1, 'Recorded check-ins')
end)

-- server/billing.lua Billing.charge: TriggerEvent('kora_ambulance:server:onBillCharged', src, cost).
local BILLED = 'kora_ambulance:server:onBillCharged'

K.step('I watch my hospital bills', 'server', function(ctx)
    K.started(RESOURCE)
    local tester = ctx.tester
    K.capture(ctx, BILLED, function(src) return src == tester end)
end)

K.step('I should have been billed {int}', 'server', function(ctx, cost)
    assert(ctx.state.captured and ctx.state.captured[BILLED], 'Watch the hospital bills before acting')
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, BILLED)) do
            if record[2] == cost then return true end
        end
    end, 'No hospital bill of ' .. cost, 5000)
end)

-- ---------------------------------------------------------------------------
-- Server: on-duty EMS count (exports.kora_ambulance:GetDoctorCount,
-- server/compat/hospital.lua: #getPlayersByJob('ambulance', onDutyOnly))
-- ---------------------------------------------------------------------------

local function doctors() return K.export(RESOURCE, 'GetDoctorCount') end

K.step('I remember the on-duty EMS count', 'server', function(ctx)
    ctx.state.doctorCount = doctors()
    assert(type(ctx.state.doctorCount) == 'number', 'GetDoctorCount returned no number')
end)

K.step('the on-duty EMS count should have increased by {int}', 'server', function(ctx, amount)
    local before = assert(ctx.state.doctorCount, 'Remember the on-duty EMS count first')
    ctx:waitUntil(function() return doctors() == before + amount end,
        'On-duty EMS count expected ' .. (before + amount), 3000, function() return ' | it is ' .. tostring(doctors()) end)
end)

K.step('the on-duty EMS count should be back to what it was', 'server', function(ctx)
    local before = assert(ctx.state.doctorCount, 'Remember the on-duty EMS count first')
    ctx:waitUntil(function() return doctors() == before end,
        'On-duty EMS count expected ' .. before, 3000, function() return ' | it is ' .. tostring(doctors()) end)
end)

-- ---------------------------------------------------------------------------
-- Server: EMS dispatch calls raised by the tester (kora_dispatch getCalls).
-- /911e: code '911e', data.requester (server/housecall.lua buildAlertPayload).
-- /housecall: code '10-51', data.requester/requestId/note (buildQueuePayload).
-- Config.job.type is 'ems'.
-- ---------------------------------------------------------------------------

local function myCalls(tester, code)
    local found = {}
    for _, call in ipairs(exports.kora_dispatch:getCalls({ service = 'ems', activeOnly = true }) or {}) do
        local data = call.data
        if type(data) == 'table' and data.requester == tester and (code == nil or call.code == code) then
            found[#found + 1] = call
        end
    end
    return found
end

-- Cleanup: a queued house call is claimed through the same server event
-- kora_dispatch fires on accept (kora_ambulance:server:housecallAccepted,
-- server-side TriggerEvent only), which empties the in-memory queue; every
-- call the tester raised is then closed (fft is a trusted dispatch caller).
K.step('I watch my EMS calls', 'server', function(ctx)
    K.started(RESOURCE)
    K.started('kora_dispatch')
    local tester = ctx.tester
    ctx:cleanup(function()
        for _, call in ipairs(myCalls(tester)) do
            if call.code == '10-51' and call.data.requestId then
                pcall(TriggerEvent, 'kora_ambulance:server:housecallAccepted', tester, call.id, call.data)
            end
            pcall(function() exports.kora_dispatch:closeCall(call.id, 'fft cleanup') end)
        end
    end)
end)

K.step('an emergency call from me should be open', 'server', function(ctx)
    ctx:waitUntil(function() return #myCalls(ctx.tester, '911e') > 0 end, 'No open 911e call raised by the tester', 5000)
end)

K.step('only one emergency call from me should be open', 'server', function(ctx)
    Wait(500)
    ctx:equal(#myCalls(ctx.tester, '911e'), 1, 'Open 911e calls raised by the tester')
end)

K.step('no emergency call from me should be open', 'server', function(ctx)
    ctx:waitUntil(function() return #myCalls(ctx.tester, '911e') == 0 end, 'A 911e call raised by the tester is still open', 5000)
end)

K.step('a house call from me should be open with the note {string}', 'server', function(ctx, note)
    ctx:waitUntil(function()
        for _, call in ipairs(myCalls(ctx.tester, '10-51')) do
            if call.data.note == note and type(call.data.requestId) == 'number' then return true end
        end
    end, 'No open house call with the note ' .. note, 5000)
end)

K.step('no house call from me should be open', 'server', function(ctx)
    ctx:waitUntil(function() return #myCalls(ctx.tester, '10-51') == 0 end, 'A house call raised by the tester is still open', 5000)
end)

-- ---------------------------------------------------------------------------
-- Client: legacy qb-ambulancejob compatibility events (server/compat/hospital.lua)
-- These are public net events any client can fire; the adapter validates them.
-- ---------------------------------------------------------------------------

local LEGACY_SERVER_EVENTS = {
    SendToBed = true, LeaveBed = true, RespawnAtHospital = true, SetDeathStatus = true,
    SetLaststandStatus = true, SetArmor = true, AddDoctor = true, RemoveDoctor = true,
    UseFirstAid = true, UseIfaks = true, removeBandage = true, removeIfaks = true,
    removePainkillers = true,
}

local function legacyEvent(name)
    assert(LEGACY_SERVER_EVENTS[name], 'Not a covered legacy hospital event: ' .. tostring(name))
    K.started(RESOURCE)
    return 'hospital:server:' .. name
end

K.step('I send the legacy hospital event {string}', 'client', function(_, name)
    TriggerServerEvent(legacyEvent(name))
end)

K.step('I send the legacy hospital event {string} with {int}', 'client', function(_, name, value)
    TriggerServerEvent(legacyEvent(name), value)
end)

K.step('I send the legacy hospital event {string} with the text {string}', 'client', function(_, name, value)
    TriggerServerEvent(legacyEvent(name), value)
end)

K.step('I send the legacy hospital event {string} with true', 'client', function(_, name)
    TriggerServerEvent(legacyEvent(name), true)
end)

-- Config.compat.acceptClientInjurySync = false: the table is ignored.
K.step('I send a legacy injury sync for my {string} at tier {int}', 'client', function(_, bodyPart, tier)
    K.started(RESOURCE)
    TriggerServerEvent('hospital:server:SyncInjuries', { [bodyPart] = tier })
end)

-- client/compat.lua registers this client event for third-party resources;
-- it is meant to release the bed like the server LeaveBed event.
K.step('a resource fires the legacy client leave bed event', 'client', function()
    K.started(RESOURCE)
    TriggerEvent('hospital:client:leaveBed')
end)

-- ---------------------------------------------------------------------------
-- Client: target option count and the house-call list
-- ---------------------------------------------------------------------------

-- kora_target's hook reports the hovered target and its option count; options
-- whose canInteract fails (client/duty.lua isOnDutyEMS, client/hospital.lua isEMS)
-- are not counted.
K.step('the hovered target should offer {int} options', 'client', function(ctx, count)
    local function stop() pcall(function() exports.kora_target:fftAction('stop') end) end
    ctx:cleanup(stop)
    local last
    ctx:waitUntil(function()
        if not exports.kora_target:fftAction('start') then return false end
        local hover = exports.kora_target:fftAction('hovering')
        last = hover and hover.optionCount
        return last == count
    end, ('Hovered target does not offer %d options'):format(count), 8000, function()
        return (' | last count %s'):format(tostring(last)) .. K.targetProbe()
    end)
    stop()
end)

-- client/housecall.lua renders /housecalls as one notification titled
-- 'Open House Calls' with a '#<id> -- <note>' line per request.
K.step('I accept my house call with the note {string} from the list', 'client', function(ctx, note)
    local id
    ctx:waitUntil(function()
        for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            if entry.title == 'Open House Calls' and type(entry.message) == 'string' then
                for line in entry.message:gmatch('[^\n]+') do
                    local found, text = line:match('^#(%d+) %-%- (.*)$')
                    if found and text == note then id = found return true end
                end
            end
        end
    end, 'The house-call list does not show the note ' .. note, 5000)
    ExecuteCommand('accepthousecall ' .. id)
end)

-- ---------------------------------------------------------------------------
-- Legacy EMS helper exports (kora_ambulance/client/compat.lua). Read-only:
-- the tester is never downed, dragged or treated here.
-- ---------------------------------------------------------------------------

K.step('the EMS helper exports should answer without escorting anyone', 'client', function(ctx)
    K.started(RESOURCE)
    ctx:equal(K.export(RESOURCE, 'isEscorted'), false, 'isEscorted')
    ctx:equal(type(K.export(RESOURCE, 'CanHelp')), 'boolean', 'CanHelp answers a boolean')
    local ok = pcall(function() return exports[RESOURCE]:PainKillerLoop() end)
    ctx:equal(ok, true, 'PainKillerLoop is a no-op and does not raise')
end)
