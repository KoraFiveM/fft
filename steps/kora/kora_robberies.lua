-- kora_robberies: house break-ins (door target, progress bar, shared house state)
-- and the police gate on store registers and safes.
--
-- Hook: kora_robberies/fft_hooks_server.lua, built on the approved RobberyFFT
-- seam in server/robbery.lua. It reports a house or store as the server holds
-- it (houses and stores live in the database and can be edited in the creator,
-- so the feature's coordinates are checked against live data first) and resets
-- a house the test itself claimed. Doors, registers and safes are selected
-- through kora_target; the break-in progress bar runs for its real 8 seconds.
local K = FFT.kora
if not K then return end
K.feature('kora_robberies')

local RESOURCE = 'kora_robberies'

local function house(ctx, id)
    local info, err = K.hook(RESOURCE, 'house', ctx.tester, id)
    if type(info) ~= 'table' then error(tostring(err or 'kora_robberies hook returned no house'), 0) end
    return info
end

local function shop(ctx, id)
    local info, err = K.hook(RESOURCE, 'store', ctx.tester, id)
    if type(info) ~= 'table' then error(tostring(err or 'kora_robberies hook returned no store'), 0) end
    return info
end

local function near(at, x, y, z)
    return type(at) == 'table' and at.x and at.y and at.z
        and math.abs(at.x - x) < 0.5 and math.abs(at.y - y) < 0.5 and math.abs(at.z - z) < 0.5
end

local function claim(ctx, id)
    local tester = ctx.tester
    ctx:cleanup(function() pcall(function() exports[RESOURCE]:fftAction('reset', tester, id) end) end)
    K.must(K.hook(RESOURCE, 'claim', tester, id))
end

-- Precondition: the live house matches what the scenario was written against
-- and nobody is using it. Fails with the difference instead of misfiring later.
K.step('the robbery house {string} is free at {float} {float} {float}', 'server', function(ctx, id, x, y, z)
    local info = house(ctx, id)
    assert(near(info.coords, x, y, z), ('House %s has moved: it is at %s %s %s'):format(id,
        tostring(info.coords and info.coords.x), tostring(info.coords and info.coords.y), tostring(info.coords and info.coords.z)))
    ctx:equal(info.hasExit, true, 'House shell has an exit')
    ctx:equal(info.timeLimited, false, 'House has opening hours')
    ctx:equal(info.security, false, 'House has a security system')
    ctx:equal(info.state, 'available', 'House state')
    ctx:equal(info.otherPlayers, 0, 'Other players inside')
end)

K.step('the robbery house {string} should need {string} and {int} police to break in', 'server', function(ctx, id, item, police)
    local info = house(ctx, id)
    ctx:equal(info.breakItem, item, 'Break-in item')
    ctx:equal(info.minPolice, police, 'Minimum police')
    ctx:equal(info.consumeBreakItem, true, 'Break-in item is consumed')
end)

-- Precondition rather than a fixture: the tester's own items are not taken away.
K.step('I carry no {string} for the robbery', 'server', function(ctx, item)
    local held = K.count(ctx, item)
    assert(held == 0, ('The tester holds %d %s; drop or store them before this scenario'):format(held, item))
end)

K.step('I claim the robbery house {string} for this test', 'server', function(ctx, id) claim(ctx, id) end)

-- The state a finished robbery leaves behind, broadcast by the resource's own setState.
K.step('the robbery house {string} is on a test cooldown', 'server', function(ctx, id)
    if not house(ctx, id).claimed then claim(ctx, id) end
    K.must(K.hook(RESOURCE, 'cooldown', ctx.tester, id, 120))
end)

K.step('the robbery house {string} should be {string}', 'server', function(ctx, id, state)
    ctx:waitUntil(function() return house(ctx, id).state == state end,
        ('House %s is %s, expected %s'):format(id, tostring(house(ctx, id).state), state), 5000)
end)
K.step('the robbery house {string} should stay {string}', 'server', function(ctx, id, state)
    Wait(1000)
    ctx:equal(house(ctx, id).state, state, 'House state')
end)

K.step('I should be inside the robbery house {string}', 'server', function(ctx, id)
    ctx:waitUntil(function() return house(ctx, id).testerInside end, 'The tester is not in the house session', 5000)
end)
K.step('I should not be inside the robbery house {string}', 'server', function(ctx, id)
    ctx:equal(house(ctx, id).testerInside, false, 'Tester in the house session')
end)

K.step('the robbery house {string} test state is reset', 'server', function(ctx, id)
    K.must(K.hook(RESOURCE, 'reset', ctx.tester, id))
end)

K.step('the robbery store {string} should have register {int} at {float} {float} {float}', 'server', function(ctx, id, index, x, y, z)
    local register = shop(ctx, id).registers[index]
    assert(register, ('Store %s has no register %d'):format(id, index))
    assert(near(register, x, y, z), ('Register %d of %s has moved: %s %s %s'):format(index, id,
        tostring(register.x), tostring(register.y), tostring(register.z)))
    ctx:equal(register.label, 'Rob Register', 'Register label')
end)
K.step('the robbery store {string} should have safe {int} at {float} {float} {float}', 'server', function(ctx, id, index, x, y, z)
    local safe = shop(ctx, id).safes[index]
    assert(safe, ('Store %s has no safe %d'):format(id, index))
    assert(near(safe, x, y, z), ('Safe %d of %s has moved: %s %s %s'):format(index, id,
        tostring(safe.x), tostring(safe.y), tostring(safe.z)))
end)

-- Precondition, not a fixture: uses the resource's own count (on-duty `police`).
K.step('the robbery store {string} needs more police than are on duty', 'server', function(ctx, id)
    local info = shop(ctx, id)
    assert(info.police < info.minPolice, ('%d police are on duty and store %s needs %d; this scenario needs fewer')
        :format(info.police, id, info.minPolice))
end)

-- Doors, registers and safes are small box zones whose surroundings differ per
-- map, so the camera sweeps around the tester until the option is under the
-- crosshair. Targeting is left active for the following `I target` step.
K.step('I look around for the robbery option {string}', 'client', function(ctx, label)
    ctx:cleanup(function() pcall(function() exports.kora_target:fftAction('stop') end) end)
    local ped = PlayerPedId()
    local base = GetEntityHeading(ped)
    for _, pitch in ipairs({ -20.0, -45.0, -70.0 }) do
        for turn = 0, 7 do
            ctx:check()
            SetEntityHeading(ped, (base + turn * 45.0) % 360.0)
            SetGameplayCamRelativeHeading(0.0)
            SetGameplayCamRelativePitch(pitch, 1.0)
            Wait(250)
            if exports.kora_target:fftAction('start') then
                Wait(100)
                local hover = exports.kora_target:fftAction('hovering')
                if hover and (hover.label == label or hover.optionCount > 1) then return end
            end
        end
    end
    error('Robbery option was not found around the tester: ' .. label, 0)
end)

-- Store registers and safes are 1 m box zones on the counter or floor
-- (client/store.lua addZone), so standing on the point itself puts the tester
-- inside the counter. K.face stands beside the point, trying each side, until
-- the option is under the crosshair. `lift` raises the stand point for a safe
-- whose saved z is near the floor.
local function faceStoreSpot(ctx, label, x, y, z, lift)
    K.face(ctx, label, x, y, z, { distance = 1.2, lift = lift })
end
K.step('I face the robbery store register at {float} {float} {float}', 'client', function(ctx, x, y, z)
    faceStoreSpot(ctx, 'Rob Register', x, y, z, 0.0)
end)
K.step('I face the robbery store safe at {float} {float} {float}', 'client', function(ctx, x, y, z)
    faceStoreSpot(ctx, 'Enter Code', x, y, z, 0.6)
end)

-- The shell is spawned far from the door (kora_interior), so being inside shows
-- as distance from where the tester stood.
K.step('I should have been moved away from {float} {float} {float}', 'client', function(ctx, x, y, z)
    ctx:waitUntil(function()
        return #(GetEntityCoords(PlayerPedId()) - vector3(x, y, z)) > 10.0
    end, 'The tester is still at the door', 10000)
end)
K.step('I should be back near {float} {float} {float}', 'client', function(ctx, x, y, z)
    ctx:waitUntil(function()
        return #(GetEntityCoords(PlayerPedId()) - vector3(x, y, z)) < 6.0
    end, 'The tester was not sent back to the door', 10000)
end)

-- ---------------------------------------------------------------------------
-- The resource's own callbacks, asked directly from the tester's client with
-- the arguments client/robbery.lua and client/store.lua send. The server
-- decides (server/robbery.lua, server/store.lua); answers are kept in order so
-- a scenario can assert each refusal message exactly. Rate limits from
-- server/_functions.lua startCooldown: breakin 2 s, search/register 0.5 s, safe 1 s.
-- ---------------------------------------------------------------------------

-- kora_lib callback_triggerPacked keeps every value (a `nil, reason` refusal
-- included) and turns a raised handler error or rate-limit rejection into
-- { __kora_lib_rejected = true, error } (local/callback/shared.lua
-- KoraLibCallbackEnvelope). Normalised to table.pack(pcall(...)) shape:
-- { true, values... } or { false, message }.
local function packedCall(name, ...)
    local args = table.pack(...)
    local ok, packed = pcall(function()
        return exports.kora_lib:callback_triggerPacked(name, table.unpack(args, 1, args.n))
    end)
    if not ok then return { n = 2, false, tostring(packed) } end
    if type(packed) ~= 'table' then return { n = 2, true, packed } end
    if packed.__kora_lib_rejected then return { n = 2, false, tostring(packed.error) } end
    local count = math.tointeger(packed.n) or #packed
    local results = { n = count + 1, true }
    for index = 1, count do results[index + 1] = packed[index] end
    return results
end

local function ask(ctx, name, ...)
    K.started(RESOURCE)
    local results = packedCall(name, ...)
    ctx.state.robberyAnswers = ctx.state.robberyAnswers or {}
    table.insert(ctx.state.robberyAnswers, { name = name, results = results })
end
local function answer(ctx, index)
    local entry = (ctx.state.robberyAnswers or {})[index]
    assert(entry, ('There is no robbery answer %d'):format(index))
    assert(entry.results[1], ('%s failed: %s'):format(entry.name, tostring(entry.results[2])))
    return entry.results[2], entry.results[3], entry.name
end

K.step('I try to break into the robbery house {string} directly', 'client', function(ctx, id)
    ask(ctx, 'kora_robberies:breakin', id)
end)
K.step('I leave the robbery house {string} directly', 'client', function(ctx, id)
    ask(ctx, 'kora_robberies:leave', id)
end)
K.step('I try to start searching spot {int} of the robbery house {string}', 'client', function(ctx, index, id)
    ctx:cleanup(function() TriggerServerEvent('kora_robberies:prop:cancel', id, index) end)
    ask(ctx, 'kora_robberies:prop:begin', id, index)
end)
K.step('I try to finish searching spot {int} of the robbery house {string}', 'client', function(ctx, index, id)
    ask(ctx, 'kora_robberies:prop:finish', id, index)
end)
-- client/robbery.lua sends this when the search progress bar is cancelled.
K.step('I stop searching spot {int} of the robbery house {string}', 'client', function(_, index, id)
    TriggerServerEvent('kora_robberies:prop:cancel', id, index)
    Wait(300)
end)
K.step('I try to start robbing register {int} of the robbery store {string}', 'client', function(ctx, index, id)
    ctx:cleanup(function() TriggerServerEvent('kora_robberies:register:cancel', id, index) end)
    ask(ctx, 'kora_robberies:register:begin', id, index)
end)
K.step('I try to finish robbing register {int} of the robbery store {string}', 'client', function(ctx, index, id)
    ask(ctx, 'kora_robberies:register:finish', id, index)
end)
K.step('I try the code {int} on safe {int} of the robbery store {string}', 'client', function(ctx, code, index, id)
    ask(ctx, 'kora_robberies:safe:code', id, index, code)
end)
K.step('I try to blow safe {int} of the robbery store {string}', 'client', function(ctx, index, id)
    ask(ctx, 'kora_robberies:safe:blow', id, index)
end)
K.step('I try to loot safe {int} of the robbery store {string}', 'client', function(ctx, index, id)
    ask(ctx, 'kora_robberies:safe:loot', id, index)
end)

K.step('robbery answer {int} should be refused with {string}', 'client', function(ctx, index, message)
    local value, reason, name = answer(ctx, index)
    ctx:equal(value, false, name .. ' accepted')
    ctx:equal(reason, message, name .. ' refusal')
end)
K.step('robbery answer {int} should be refused without a reason', 'client', function(ctx, index)
    local value, reason, name = answer(ctx, index)
    ctx:equal(value, false, name .. ' accepted')
    ctx:equal(reason, nil, name .. ' refusal reason')
end)
K.step('robbery answer {int} should be accepted', 'client', function(ctx, index)
    local value, reason, name = answer(ctx, index)
    assert(value ~= false and value ~= nil, ('%s was refused: %s'):format(name, tostring(reason)))
end)
-- server/robbery.lua entryInfo: what the client needs to build the inside.
K.step('robbery answer {int} should describe the inside of a {string}', 'client', function(ctx, index, shell)
    local info = answer(ctx, index)
    assert(type(info) == 'table', 'The break-in returned no house description')
    ctx:equal(info.shell, shell, 'Shell')
    assert(type(info.exit) == 'table' and type(info.props) == 'table', 'The description has no exit or props')
end)
-- server/robbery.lua prop:begin: { duration, label, ... } from the shell's prop row.
K.step('robbery answer {int} should start a search lasting {int} milliseconds', 'client', function(ctx, index, duration)
    local info = answer(ctx, index)
    assert(type(info) == 'table', 'The search did not start')
    ctx:equal(info.duration, duration, 'Search duration')
end)

-- Read-only listings the clients load their target zones from.
K.step('the robbery house listing should show {string} available at {float} {float} {float}', 'client', function(ctx, id, x, y, z)
    ask(ctx, 'kora_robberies:world')
    local list = answer(ctx, #ctx.state.robberyAnswers)
    assert(type(list) == 'table', 'kora_robberies:world returned no list (data not loaded?)')
    for _, house in ipairs(list) do
        if house.id == id then
            assert(near(house.coords, x, y, z), 'House ' .. id .. ' is listed elsewhere')
            ctx:equal(house.state, nil, 'Listed state')
            return
        end
    end
    error('House ' .. id .. ' is not listed', 0)
end)
K.step('the robbery store listing should show {string} with {int} registers and {int} safe with nothing in use', 'client',
    function(ctx, id, registers, safes)
        ask(ctx, 'kora_robberies:stores')
        local list = answer(ctx, #ctx.state.robberyAnswers)
        assert(type(list) == 'table', 'kora_robberies:stores returned no list (data not loaded?)')
        for _, store in ipairs(list) do
            if store.id == id then
                ctx:equal(#store.registers, registers, 'Registers')
                ctx:equal(#store.safes, safes, 'Safes')
                ctx:equal(next(store.states.registers), nil, 'Register in use')
                ctx:equal(next(store.states.safes), nil, 'Safe in use')
                return
            end
        end
        error('Store ' .. id .. ' is not listed', 0)
    end)

-- server/creator.lua adminCallback('kora_robberies:creator:get', payload): read only.
K.step('the robbery creator data should list the house {string} and the store {string}', 'client', function(ctx, houseId, storeId)
    ask(ctx, 'kora_robberies:creator:get')
    local value, reason = answer(ctx, #ctx.state.robberyAnswers)
    assert(type(value) == 'table', 'The creator refused: ' .. tostring(reason))
    local function has(list, id)
        for _, entry in ipairs(list or {}) do if entry.id == id then return true end end
    end
    assert(has(value.houses, houseId), 'Creator data does not list house ' .. houseId)
    assert(has(value.stores, storeId), 'Creator data does not list store ' .. storeId)
end)

-- Precondition: Config.Creator.ace ('command') via isAdmin in server/_functions.lua.
K.step('I have the robbery creator permission', 'server', function(ctx)
    assert(IsPlayerAceAllowed(ctx.tester, 'command'), 'The tester lacks the "command" ace the robbery creator needs')
end)

-- Precondition, not a fixture: the resource's own PoliceOnDuty() count.
K.step('the robbery house {string} needs more police than are on duty', 'server', function(ctx, id)
    local info = house(ctx, id)
    assert(info.police < info.minPolice, ('%d police are on duty and house %s needs %d; this scenario needs fewer')
        :format(info.police, id, info.minPolice))
end)
K.step('the robbery store {string} should need {int} police', 'server', function(ctx, id, police)
    ctx:equal(shop(ctx, id).minPolice, police, 'Store minimum police')
end)
