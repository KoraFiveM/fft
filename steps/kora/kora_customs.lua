-- kora_customs: public custom shops (cosmetic AppShell app + self-service repair).
-- The shop zones are kora_target box zones and the shop is a kora_lib AppShell
-- app, so kora_target's and kora_lib's hooks drive them. The only resource hook
-- is server-side (kora_customs/fft_hooks_server.lua, approved seam): it clears
-- the tester's own entry of the file-local repair cooldown table so the repair
-- scenarios can be repeated inside Config.selfRepair.cooldownSeconds (120).
local K = FFT.kora
if not K then return end
K.feature('kora_customs')

local function drivenVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    assert(vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped, 'The tester is not driving a vehicle')
    return vehicle
end

-- client/main.lua needsRepair(): engine, body or petrol tank health below 1000.
local function needsRepair(vehicle)
    return GetVehicleEngineHealth(vehicle) < 1000.0 or GetVehicleBodyHealth(vehicle) < 1000.0
        or GetVehiclePetrolTankHealth(vehicle) < 1000.0
end

-- Clears the tester's repair cooldown before the scenario and again afterwards.
K.step('my custom shop repair cooldown is cleared', 'server', function(ctx)
    local tester = ctx.tester
    ctx:equal(K.export('kora_customs', 'fftVersion'), 1, 'kora_customs server hook version')
    K.must(K.hook('kora_customs', 'resetRepairCooldown', tester))
    ctx:cleanup(function() pcall(function() exports.kora_customs:fftAction('resetRepairCooldown', tester) end) end)
end)

-- Opens the shop through the resource's public client export (the same open()
-- the target option runs). Shop ids come from Config.shops in config.lua.
K.step('I open the custom shop {string}', 'client', function(ctx, shopId)
    ctx:cleanup(function()
        pcall(function()
            exports.kora_lib:fftAction('app.action', 'discard')
            exports.kora_lib:fftAction('app.close')
        end)
    end)
    K.export('kora_customs', 'open', shopId)
end)

-- "Discard changes" (client/main.lua onAction: `restore() return { close = true }`)
-- rolls the previews back and answers close = true. kora_lib hands that answer
-- to the browser (modules/nui/client.lua "kora_lib:app:action" returns
-- { ok = true, result = result }) and the browser closes the shell by settling
-- the openApp request. No browser reads the answer at the callback level, so
-- this step asserts the answer and then settles the app as the browser would.
K.step('I discard the custom shop changes', 'client', function()
    local _, result = K.must(K.ui('app.action', 'discard'))
    assert(type(result) == 'table' and result.close == true, 'Discard did not answer close = true')
    K.ui('app.close') -- no-op when kora_lib's hook already settled the close
end)

K.step('the vehicle I am driving is damaged for the custom shop', 'client', function()
    local vehicle = drivenVehicle()
    SetVehicleEngineHealth(vehicle, 600.0)
    SetVehicleBodyHealth(vehicle, 700.0)
    assert(needsRepair(vehicle), 'The vehicle did not take damage')
end)
K.step('the vehicle I am driving should be fully repaired', 'client', function(ctx)
    local vehicle = drivenVehicle()
    ctx:waitUntil(function() return not needsRepair(vehicle) end,
        ('Vehicle still needs a repair (engine %.0f, body %.0f)'):format(GetVehicleEngineHealth(vehicle), GetVehicleBodyHealth(vehicle)), 3000)
end)
K.step('the vehicle I am driving should still need a repair', 'client', function()
    Wait(500)
    assert(needsRepair(drivenVehicle()), 'The vehicle was repaired')
end)

-- Both shop options live on one box zone. kora_target reports the hovered
-- option and how many options passed canInteract, so "only" means count 1.
K.step('the custom shop zone should offer only {string}', 'client', function(ctx, label)
    local function stop() pcall(function() exports.kora_target:fftAction('stop') end) end
    ctx:cleanup(stop)
    local seen
    -- Seated, the zone is only reached where the camera ray hits inside it;
    -- turn towards kora_target's own aim points like K.target does.
    local aim = K.aimer(label)
    ctx:waitUntil(function()
        aim()
        if not exports.kora_target:fftAction('start') then return false end
        seen = exports.kora_target:fftAction('hovering')
        return seen and seen.optionCount == 1 and seen.label == label
    end, ('Custom shop zone does not offer only "%s"'):format(label), 8000, function()
        return (' | offers %s option(s), top "%s"'):format(tostring(seen and seen.optionCount or 0), tostring(seen and seen.label))
            .. K.targetProbe(label)
    end)
    stop()
end)

-- ---------------------------------------------------------------------------
-- Round 3: previews, prices, session guards and more shops.
-- ---------------------------------------------------------------------------

local SHOP_APP = 'kora_customs:shop'

-- Puts the temporary vehicle on a known palette look before the shop reads it
-- (client/main.lua open() snapshots Kora.vehicle.getProperties), so previews
-- and their revert can be checked against fixed numbers.
K.step('the vehicle I am driving has plain paint {int} and {int}', 'client', function(_, primary, secondary)
    local vehicle = drivenVehicle()
    SetVehicleModKit(vehicle, 0)
    ClearVehicleCustomPrimaryColour(vehicle)
    ClearVehicleCustomSecondaryColour(vehicle)
    SetVehicleColours(vehicle, primary, secondary)
    SetVehicleExtraColours(vehicle, 0, 0)
    local a, b = GetVehicleColours(vehicle)
    assert(a == primary and b == secondary, 'The vehicle did not take the paint')
end)
K.step('the vehicle I am driving should have primary paint {int}', 'client', function(ctx, colour)
    local vehicle = drivenVehicle()
    ctx:waitUntil(function()
        local primary = GetVehicleColours(vehicle)
        return primary == colour and not GetIsVehiclePrimaryColourCustom(vehicle)
    end, ('Primary paint is %s, expected %d'):format(tostring((GetVehicleColours(vehicle))), colour), 3000)
end)
K.step('the vehicle I am driving should have custom primary paint {int} {int} {int}', 'client', function(ctx, r, g, b)
    local vehicle = drivenVehicle()
    ctx:waitUntil(function()
        if not GetIsVehiclePrimaryColourCustom(vehicle) then return false end
        local cr, cg, cb = GetVehicleCustomPrimaryColour(vehicle)
        return cr == r and cg == g and cb == b
    end, 'The vehicle does not show that custom primary paint', 3000)
end)

-- Passengers use kora_scrapyard's generic 'I sit as a passenger in a temporary {string}'
-- step; client/main.lua vehicleIsUsable() needs the driver seat (-1).

-- Pulls the tester out of the seat at once; the shop's session guard
-- (client/main.lua open(), every 250 ms) must notice.
K.step('I leave the driver seat', 'client', function(ctx)
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    ctx:waitUntil(function() return not IsPedInAnyVehicle(PlayerPedId(), false) end, 'The tester is still in the vehicle', 3000)
end)

-- Moves the (frozen) vehicle with the tester in it straight ahead, beyond
-- Config.interaction.checkoutDistance (12.0) of the shop it was opened at.
K.step('the vehicle I am driving is moved {int} metres forward', 'client', function(ctx, metres)
    assert(metres > 12 and metres <= 40, 'Move 13-40 metres')
    local vehicle = drivenVehicle()
    local at, forward = GetEntityCoords(vehicle), GetEntityForwardVector(vehicle)
    SetEntityCoordsNoOffset(vehicle, at.x + forward.x * metres, at.y + forward.y * metres, at.z, false, false, false)
    ctx:waitUntil(function() return #(GetEntityCoords(vehicle) - at) > 12.0 end, 'The vehicle did not move', 3000)
end)

-- Shop app actions with a form value. The rows' "Choose" (set:<field>) reads
-- context.value.value and "Pick colour" (color:<field>) context.value.color
-- (client/main.lua setField, pickColor); step/toggle ignore the value.
K.step('I preview the custom shop option {string} with {string}', 'client', function(ctx, actionId, value)
    local _, result = K.must(K.ui('app.action', actionId, { value = { value = tonumber(value) or value, color = value } }))
    ctx.state.appResult = type(result) == 'table' and result or {}
end)

-- The shop's views carry the running total in their description
-- (client/main.lua buildNavigation: "Pending total: $N" or "Nothing selected
-- yet. ..."). The app's open payload holds the first one; every later change
-- is sent with Kora.nui.send('updateApp'), which kora_lib's hook logs.
local function shopState(ctx)
    local latestUpdate, latestOpen
    for _, entry in ipairs(K.ui('log', ctx.state.uiBaseline or 0) or {}) do
        local data = type(entry.data) == 'table' and entry.data or {}
        if entry.action == 'openApp' and type(data.payload) == 'table' and type(data.payload.app) == 'table'
            and data.payload.app.id == SHOP_APP then
            latestOpen = entry.seq
        elseif entry.action == 'updateApp' and data.appId == SHOP_APP and type(data.app) == 'table' then
            latestUpdate = entry
        end
    end
    if latestUpdate and (not latestOpen or latestUpdate.seq > latestOpen) then return latestUpdate.data.app end
    local payload = K.ui('app')
    return type(payload) == 'table' and type(payload.app) == 'table' and payload.app.id == SHOP_APP and payload.app or nil
end
local function shopDescription(ctx)
    local app = shopState(ctx)
    for _, view in pairs(app and type(app.navigation) == 'table' and app.navigation or {}) do
        if type(view) == 'table' and view.id == 'paint' and type(view.content) == 'table' then return view.content.description end
    end
end

K.step('the custom shop should show a pending total of {string}', 'client', function(ctx, amount)
    local seen
    ctx:waitUntil(function()
        seen = shopDescription(ctx)
        return seen == 'Pending total: ' .. amount
    end, 'The shop does not show a pending total of ' .. amount, 3000, function() return ' | it shows: ' .. tostring(seen) end)
end)
K.step('the custom shop should show nothing selected', 'client', function(ctx)
    local seen
    ctx:waitUntil(function()
        seen = shopDescription(ctx)
        return type(seen) == 'string' and seen:sub(1, 21) == 'Nothing selected yet.'
    end, 'The shop shows a pending change', 3000, function() return ' | it shows: ' .. tostring(seen) end)
end)
K.step('the custom shop app should be titled {string}', 'client', function(ctx, title)
    local seen
    ctx:waitUntil(function()
        local app = shopState(ctx)
        seen = app and app.title
        return seen == title
    end, 'The shop app is not titled ' .. title, 3000, function() return ' | title: ' .. tostring(seen) end)
end)

-- "Hide menu" answers close = true and keeps the previews (client/main.lua
-- onAction 'hide', runHidden). kora_lib's hook settles the close like the browser.
K.step('I hide the custom shop menu', 'client', function()
    local _, result = K.must(K.ui('app.action', 'hide'))
    assert(type(result) == 'table' and result.close == true, 'Hide menu did not answer close = true')
    K.ui('app.close')
end)

-- The vehicle from 'I am driving a temporary ...' after the tester left it.
K.step('the temporary vehicle should have primary paint {int}', 'client', function(ctx, colour)
    local vehicle = assert(ctx.state.vehicle, 'No temporary vehicle was spawned')
    assert(DoesEntityExist(vehicle), 'The temporary vehicle is gone')
    ctx:waitUntil(function()
        local primary = GetVehicleColours(vehicle)
        return primary == colour and not GetIsVehiclePrimaryColourCustom(vehicle)
    end, ('Primary paint is %s, expected %d'):format(tostring((GetVehicleColours(vehicle))), colour), 3000)
end)

-- A refused quote never reaches the "Confirm customisation" alert
-- (client/main.lua checkout: abort() before Kora.nui.openAlert).
K.step('no custom shop purchase confirmation should be open', 'client', function()
    Wait(500)
    local alert = K.uiState().alert
    assert(not alert, 'A confirmation is open: ' .. tostring(type(alert) == 'table' and alert.title))
end)

-- Config.selfRepair.durationMs, sent back by kora_customs:repairStart.
K.step('the repair progress bar should last {int} milliseconds', 'client', function(ctx, duration)
    local progress = ctx:waitUntil(function() return K.uiState().progress end, 'No progress bar is running')
    ctx:equal(progress.duration, duration, 'Repair progress duration')
end)
