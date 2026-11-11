-- kora_newsjob: Weazel News door, equipment point and garage (job "news").
-- No resource hook: the door is a kora_target box zone, the equipment point and
-- garages are kora_lib interact zones, the garage is a kora_lib AppShell app
-- (qb-newsjob:garage), and the results are items and a networked vehicle.
--
-- Every option is gated on the job name "news" (client canInteract and the
-- server handlers). That job must exist in the running job registry.
local K = FFT.kora
if not K then return end
K.feature('kora_newsjob')

-- Config.Locations.inside in kora_newsjob/config.lua.
local INSIDE = { x = -77.46, y = -833.77, z = 243.38 }
-- Config.Locations.vehicle.vehicles[1].name / Config.Locations.heli.vehicles[1].name.
local MODELS = { rumpo = true, conada = true }
-- server/main.lua: local equipment = { newscam, newsmic, newsbmic }.
local EQUIPMENT = { newscam = true, newsmic = true, newsbmic = true }

local function vehicles()
    local seen = {}
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do seen[vehicle] = true end
    return seen
end

local function isNewsModel(vehicle)
    local model = GetEntityModel(vehicle)
    for name in pairs(MODELS) do if model == GetHashKey(name) then return true end end
    return false
end

-- Vehicles of the two garage models that appeared since the snapshot.
local function taken(before)
    local found = {}
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if not before[vehicle] and isNewsModel(vehicle) then found[#found + 1] = vehicle end
    end
    return found
end

-- The garage has no "store" entry (storeCurrentVehicle is never offered), so a
-- spawned vehicle stays in the world. Place this step AFTER "I stand at" so it
-- runs before the teleport is undone. It deletes only rumpo/conada vehicles that
-- did not exist when the step ran, and hands back the key the spawn granted,
-- the same way the resource's own store routine does.
K.step('any news vehicle I take out is deleted afterwards', 'client', function(ctx)
    local before = vehicles()
    ctx.state.newsVehiclesBefore = before
    ctx:cleanup(function()
        for _, vehicle in ipairs(taken(before)) do
            local plate = GetVehicleNumberPlateText(vehicle)
            if type(plate) == 'string' then
                plate = plate:gsub('^%s+', ''):gsub('%s+$', '')
                if plate:sub(1, 4) == 'WZNW' then TriggerServerEvent('qb-vehiclekeys:server:RemoveVehicleKeys', plate) end
            end
            NetworkRequestControlOfEntity(vehicle)
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end)
end)

K.step('I should be piloting a news {string}', 'client', function(ctx, model)
    assert(MODELS[model], model .. ' is not a Weazel News garage vehicle')
    local before = assert(ctx.state.newsVehiclesBefore, 'Use "any news vehicle I take out is deleted afterwards" first')
    local hash = GetHashKey(model)
    local vehicle
    ctx:waitUntil(function()
        vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        return vehicle ~= 0 and not before[vehicle] and GetEntityModel(vehicle) == hash
            and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId()
    end, 'The news garage did not put me in the driver seat of a ' .. model, 10000)
    local plate = GetVehicleNumberPlateText(vehicle) or ''
    assert(plate:find('WZNW', 1, true), 'News vehicle plate is "' .. plate .. '", expected a WZNW plate')
end)

K.step('the news garage should not have released a vehicle', 'client', function(ctx)
    local before = assert(ctx.state.newsVehiclesBefore, 'Use "any news vehicle I take out is deleted afterwards" first')
    local deadline = GetGameTimer() + 2500
    while GetGameTimer() < deadline do
        ctx:check()
        assert(#taken(before) == 0, 'The news garage released a vehicle')
        assert(not IsPedInAnyVehicle(PlayerPedId(), false), 'I was put in a vehicle')
        Wait(100)
    end
end)

-- The door runs Kora.visuals.fade(Config.Locations.inside, 500).
K.step('I should arrive inside the news building', 'client', function(ctx)
    ctx:waitUntil(function()
        local at = GetEntityCoords(PlayerPedId())
        return #(at - vector3(INSIDE.x, INSIDE.y, INSIDE.z)) < 3.0 and IsScreenFadedIn()
    end, 'I did not arrive inside the Weazel News building', 10000)
end)

K.step('the news equipment point should not offer {string}', 'client', function(ctx, label)
    local deadline = GetGameTimer() + 1500
    while GetGameTimer() < deadline do
        ctx:check()
        for _, option in ipairs(K.uiState().interact or {}) do
            assert(option.label ~= label, 'The equipment point offers ' .. label)
        end
        Wait(100)
    end
end)

-- The selector option only fires this server event; sending it directly checks
-- the server's own job and item rules. Only the three real items and one
-- harmless unknown name can be sent.
K.step('I ask the news equipment clerk for {string} directly', 'client', function(_, item)
    K.started('kora_newsjob')
    assert(EQUIPMENT[item] or item == 'fft_no_such_equipment', item .. ' cannot be requested by this step')
    TriggerServerEvent('qb-newsjob:server:requestedEquipment', item)
    Wait(1000)
end)

-- ---------------------------------------------------------------------------
-- Round 3
-- ---------------------------------------------------------------------------

-- Config.Locations.outside in kora_newsjob/config.lua (where the exit door fades to).
local OUTSIDE = { x = -598.25, y = -929.86, z = 23.86 }
-- Prop models per usable item in kora_newsjob/client/camera.lua (newscam is left
-- out: it opens the full-screen Kora.camera recording view).
local PROPS = { newsmic = 'prop_v_bmike_01', newsbmic = 'p_ing_microphonel_01' }

-- kora_core/shared/upstream/jobs.lua: news = { label = 'Weazel News', grades = { ['0'] = ... } }.
K.step('the job registry should define {string} labelled {string}', 'server', function(ctx, name, label)
    local job = K.export('kora_core', 'getShared', 'jobs', name)
    assert(type(job) == 'table', ('kora_core has no job %s (getShared returned %s)'):format(name, type(job)))
    ctx:equal(job.label, label, 'Job label')
end)
K.step('the job {string} should have {int} grade', 'server', function(ctx, name, count)
    local job = assert(K.export('kora_core', 'getShared', 'jobs', name), 'kora_core has no job ' .. name)
    local grades = 0
    for _ in pairs(job.grades or {}) do grades = grades + 1 end
    ctx:equal(grades, count, 'Grades of ' .. name)
end)

-- Names the server must refuse: equipment[item] in server/main.lua is an exact
-- lookup, so case and surrounding spaces are not forgiven.
local MALFORMED = { NEWSCAM = true, [' newscam'] = true, ['newscam '] = true, [''] = true, Newsmic = true }
K.step('I ask the news equipment clerk for the malformed item {string}', 'client', function(_, item)
    K.started('kora_newsjob')
    assert(MALFORMED[item], item .. ' is not one of the malformed names this step may send')
    TriggerServerEvent('qb-newsjob:server:requestedEquipment', item)
    Wait(1000)
end)

K.step('the news garage point should not offer {string}', 'client', function(ctx, label)
    local deadline = GetGameTimer() + 1500
    while GetGameTimer() < deadline do
        ctx:check()
        for _, option in ipairs(K.uiState().interact or {}) do
            assert(option.label ~= label, 'The news garage point offers ' .. label)
        end
        Wait(100)
    end
end)

-- menuGarage(location) opens the app with { viewId = location }.
K.step('the news garage should open on the {string} view', 'client', function(ctx, view)
    ctx:waitUntil(function()
        local app = K.uiState().app
        return app and app.id == 'qb-newsjob:garage' and app.viewId == view
    end, 'The Weazel News garage did not open on the ' .. view .. ' view', 5000)
end)

-- The inside door is registered with Kora.lang('text.exit'). Kora.lang returns
-- the key itself when no locale has it (kora_lib/modules/locales/shared.lua).
local function exitDoorHover(ctx)
    local hover
    ctx:cleanup(function() pcall(function() exports.kora_target:fftAction('stop') end) end)
    ctx:waitUntil(function()
        if not exports.kora_target:fftAction('start') then return false end
        hover = exports.kora_target:fftAction('hovering')
        return hover
    end, 'No target option is visible at the news exit door', 11000, K.targetProbe)
    return hover
end
-- Config.Locations.inside (config.lua:7) and its label, locales/en.lua
-- text.go_outside (with its leading space). The old stand point 1.6 m east of
-- the door is over a drop: the tester fell 4 m to the floor below. K.face
-- tries each side and skips one over a drop.
local INSIDE_DOOR = { x = -77.46, y = -833.77, z = 243.38 }
K.step('I face the news exit door', 'client', function(ctx)
    K.face(ctx, ' Go outside', INSIDE_DOOR.x, INSIDE_DOOR.y, INSIDE_DOOR.z, { distance = 1.2 })
end)
K.step('the news exit door should be labelled from the locale', 'client', function(ctx)
    local hover = exitDoorHover(ctx)
    pcall(function() exports.kora_target:fftAction('stop') end)
    assert(hover.label ~= 'text.exit', 'The exit door shows the raw locale key "text.exit"')
    assert(type(hover.label) == 'string' and hover.label:match('%S'), 'The exit door has no label')
end)
K.step('I use the news exit door', 'client', function(ctx)
    local hover = exitDoorHover(ctx)
    pcall(function() exports.kora_target:fftAction('stop') end)
    K.target(ctx, hover.label, nil)
end)
K.step('I should arrive outside the news building', 'client', function(ctx)
    ctx:waitUntil(function()
        local at = GetEntityCoords(PlayerPedId())
        return #(at - vector3(OUTSIDE.x, OUTSIDE.y, OUTSIDE.z)) < 3.0 and IsScreenFadedIn()
    end, 'I did not arrive outside the Weazel News building', 10000)
end)

-- Item use goes through the same server event kora_inventory's hotbar sends
-- (client/hotbar.lua: TriggerServerEvent('QBCore:Server:UseItem', { slot, name })).
-- The server checks the slot really holds that item before using it.
local function itemSlot(item)
    for _, entry in pairs(exports.kora_core:getPlayerData({ 'items' }) or {}) do
        if entry and entry.name == item and entry.slot then return entry.slot end
    end
end
local function attachedProp(model)
    local ped, hash = PlayerPedId(), GetHashKey(model)
    for _, object in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(object) == hash and IsEntityAttachedToEntity(object, ped) then return object end
    end
end
K.step('I use my {string} from my inventory', 'client', function(ctx, item)
    local model = assert(PROPS[item], item .. ' is not a news prop item this step may use')
    local slot
    ctx:waitUntil(function() slot = itemSlot(item) return slot end, 'I hold no ' .. item, 5000)
    ctx:cleanup(function()
        -- Leave no prop or held animation behind: the resource removes them when
        -- the job changes, but a reporter tester keeps them, so tidy up here.
        local object = attachedProp(model)
        if object then
            SetEntityAsMissionEntity(object, true, true)
            DeleteEntity(object)
            ClearPedSecondaryTask(PlayerPedId())
        end
    end)
    TriggerServerEvent('QBCore:Server:UseItem', { slot = slot, name = item })
end)
K.step('I should be holding the news prop for {string}', 'client', function(ctx, item)
    local model = assert(PROPS[item], item .. ' has no news prop')
    ctx:waitUntil(function() return attachedProp(model) end, 'No ' .. model .. ' is attached to me', 8000)
end)
K.step('I should not be holding the news prop for {string}', 'client', function(ctx, item)
    local model = assert(PROPS[item], item .. ' has no news prop')
    local deadline = GetGameTimer() + 2000
    while GetGameTimer() < deadline do
        ctx:check()
        if not attachedProp(model) then
            Wait(300)
            if not attachedProp(model) then return end
        end
        Wait(100)
    end
    error(model .. ' is still attached to me', 0)
end)

-- kora_inventory/server.lua fires this local event after a useable handler accepted the use.
K.step('I watch for news item use on the server', 'server', function(ctx)
    local tester = ctx.tester
    K.capture(ctx, 'kora_inventory:server:usedItem', function(src) return src == tester end)
end)
K.step('the server should have recorded a use of {string}', 'server', function(ctx, item)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, 'kora_inventory:server:usedItem')) do
            if record[2] == item then return true end
        end
    end, 'kora_inventory did not record a use of ' .. item, 5000)
end)
