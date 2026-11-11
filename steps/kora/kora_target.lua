-- kora_target: the targeting state machine, driven through kora_target's own
-- FFT hook (start / hovering / select / stop) against options this file
-- registers itself through the real public exports and removes in cleanup.
--
-- Every "hidden" assertion is made against a zone that also carries an
-- always-allowed control option: the gated option counts as hidden only while
-- the control option is the single visible one. An aim that misses the zone
-- therefore fails instead of passing vacuously.
--
-- Not driven here: registerServerAction (server registry shared by every
-- resource), entity/model/global registrations and in-vehicle gating.
local K = FFT.kora
if not K then return end
K.feature('kora_target')

local TARGET = 'kora_target'
local LEGACY = 'qb-target'
local LEGACY_ZONE = 'fft_kora_target_probe'

-- Shared by the option callbacks below. The callbacks run in this resource
-- when kora_target invokes them, so file-local state is what they can reach.
local gates, runs = {}, {}
-- What the option callbacks were handed, keyed by option label (see the
-- deeper-coverage section at the end of this file).
local seen = { canInteract = {}, onSelect = {}, oxCheck = {}, oxSelect = {} }

local function hookStop()
    pcall(function() exports.kora_target:fftAction('stop') end)
    pcall(function() exports.kora_lib:fftAction('interact.close') end)
end

local function hovering()
    if not exports.kora_target:fftAction('start') then return nil end
    return exports.kora_target:fftAction('hovering')
end

-- Ground point 1.5 m in front of the ped: inside reach of a default-distance
-- option (2.5 m) and outside reach of a 0.3 m one.
local function probePoint(ctx)
    if ctx.state.targetPoint then return ctx.state.targetPoint end
    local ped = PlayerPedId()
    assert(not IsPedInAnyVehicle(ped, false), 'Leave the vehicle before running kora_target scenarios')
    local ahead = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    local found, ground = GetGroundZFor_3dCoord(ahead.x, ahead.y, ahead.z + 1.0, false)
    local z = found and ground or (GetEntityCoords(ped).z - 1.0)
    ctx.state.targetPoint = { x = ahead.x, y = ahead.y, z = z }
    return ctx.state.targetPoint
end

local function resetProbes(ctx)
    if ctx.state.targetReset then return end
    ctx.state.targetReset = true
    gates, runs = {}, {}
    seen = { canInteract = {}, onSelect = {}, oxCheck = {}, oxSelect = {} }
    ctx:cleanup(function()
        gates, runs = {}, {}
        seen = { canInteract = {}, onSelect = {}, oxCheck = {}, oxSelect = {} }
    end)
    ctx:cleanup(hookStop)
end

local function removeNativeZone(ctx)
    local id = ctx.state.targetZone
    if not id then return false end
    ctx.state.targetZone = nil
    return exports.kora_target:removeZone(id)
end

-- True when the hover belongs to the zone this scenario registered. The
-- native zone is matched by registration id, the legacy one by its labels.
local function mine(ctx, hover)
    if not hover then return false end
    if ctx.state.targetZone then return hover.zoneId == ctx.state.targetZone end
    return hover.kind == 'zone' and ctx.state.targetLabels ~= nil and ctx.state.targetLabels[hover.label] == true
end

local function describe(hover)
    if not hover then return 'nothing' end
    return ('"%s" with %s option(s)'):format(tostring(hover.label), tostring(hover.optionCount))
end

K.step('a temporary kora_target box zone ahead of me offers:', 'client', function(ctx, argument)
    resetProbes(ctx)
    local point = probePoint(ctx)
    local options, labels = {}, {}
    for index, spec in ipairs(K.json(argument)) do
        local label, gate = spec.label, spec.gate
        assert(type(label) == 'string' and label ~= '', 'Every option needs a label')
        labels[label] = true
        options[index] = {
            label = label,
            name = 'fft_probe_' .. index,
            distance = spec.distance,
            onSelect = function() runs[label] = (runs[label] or 0) + 1 end,
            canInteract = gate and function() return gates[gate] == true end or nil,
        }
    end
    assert(#options > 0, 'The zone needs at least one option')
    local id = K.export(TARGET, 'addBoxZone', {
        coords = { x = point.x, y = point.y, z = point.z + 0.5 },
        size = { x = 1.5, y = 1.5, z = 2.0 },
        rotation = 0.0,
        options = options,
        drawSprite = false,
    })
    assert(type(id) == 'number', 'addBoxZone did not return a registration id')
    ctx.state.targetZone, ctx.state.targetLabels = id, labels
    ctx:cleanup(function() removeNativeZone(ctx) end)
end)

K.step('a temporary legacy qb-target box zone ahead of me offers:', 'client', function(ctx, argument)
    resetProbes(ctx)
    local point = probePoint(ctx)
    local options, labels = {}, {}
    for index, spec in ipairs(K.json(argument)) do
        local label = spec.label
        assert(type(label) == 'string' and label ~= '', 'Every option needs a label')
        labels[label] = true
        options[index] = {
            label = label,
            num = index,
            job = spec.job,
            gang = spec.gang,
            item = spec.item,
            action = function() runs[label] = (runs[label] or 0) + 1 end,
        }
    end
    assert(#options > 0, 'The zone needs at least one option')
    K.started(TARGET)
    ctx:cleanup(function() pcall(function() exports[LEGACY]:RemoveZone(LEGACY_ZONE) end) end)
    local ok, err = pcall(function()
        exports[LEGACY]:AddBoxZone(LEGACY_ZONE, vector3(point.x, point.y, point.z + 0.5), 1.5, 1.5,
            { name = LEGACY_ZONE, heading = 0.0, minZ = point.z - 0.5, maxZ = point.z + 1.5 },
            { options = options, distance = 2.5 })
    end)
    if not ok then error('qb-target AddBoxZone failed: ' .. tostring(err), 0) end
    ctx.state.targetLabels = labels
end)

K.step('the kora_target gate {string} is open', 'client', function(ctx, gate)
    resetProbes(ctx)
    gates[gate] = true
    Wait(400) -- past Config.target.canInteractFailureCacheMs (250)
end)
K.step('the kora_target gate {string} is closed', 'client', function(ctx, gate)
    resetProbes(ctx)
    gates[gate] = false
    Wait(400)
end)

K.step('I look at my temporary target zone', 'client', function(ctx)
    local point = ctx.state.targetPoint
    assert(point, 'Register a temporary zone first')
    for _ = 1, 10 do
        ctx:check()
        K.aimAt(point.x, point.y, point.z + 0.05)
        Wait(100)
    end
end)

K.step('my temporary target zone should show only {string}', 'client', function(ctx, label)
    local last
    ctx:waitUntil(function()
        last = hovering()
        return mine(ctx, last) and last.label == label and last.optionCount == 1
    end, ('Expected only "%s" on the temporary zone'):format(label), 6000)
    -- Hold the observation: a gated option must stay hidden, not flicker in.
    Wait(500)
    last = hovering()
    hookStop()
    if not (mine(ctx, last) and last.label == label and last.optionCount == 1) then
        error(('Temporary zone shows %s, expected only "%s"'):format(describe(last), label), 0)
    end
end)

K.step('my temporary target zone should offer exactly {int} options', 'client', function(ctx, count)
    local last
    local ok = pcall(function()
        ctx:waitUntil(function()
            last = hovering()
            return mine(ctx, last) and last.optionCount == count
        end, 'option count', 6000)
    end)
    hookStop()
    if not ok then error(('Temporary zone shows %s, expected %d option(s)'):format(describe(last), count), 0) end
end)

K.step('my temporary target zone should not be targetable', 'client', function(ctx)
    K.must(exports.kora_target:fftAction('start'))
    local deadline = GetGameTimer() + 1500
    local seen
    while GetGameTimer() < deadline do
        ctx:check()
        local hover = exports.kora_target:fftAction('hovering')
        if hover and hover.kind == 'zone' and ctx.state.targetLabels and ctx.state.targetLabels[hover.label] then
            seen = hover
            break
        end
        Wait(100)
    end
    hookStop()
    if seen then error(('Temporary zone still shows %s'):format(describe(seen)), 0) end
end)

K.step('I open the target selector on my temporary zone', 'client', function(ctx)
    local last
    ctx:waitUntil(function()
        last = hovering()
        return mine(ctx, last) and last.optionCount > 1
    end, 'The temporary zone never showed several options at once', 6000)
    local ok, err, code = exports.kora_target:fftAction('select', last.label, nil)
    if not ok then error(err or 'Target selection rejected', 0) end
    ctx:equal(code, 'menu', 'select result code')
    ctx:waitUntil(function()
        local interact = K.uiState().interact
        return type(interact) == 'table' and #interact > 0
    end, 'The interact selector did not open', 3000)
end)

K.step('the target selector should not list {string}', 'client', function(_, label)
    local interact = K.uiState().interact
    assert(type(interact) == 'table' and #interact > 0, 'The interact selector is not open')
    for _, option in ipairs(interact) do
        if option.label == label then error('The interact selector lists ' .. label, 0) end
    end
end)

K.step('the kora_target option {string} should have run {int} times', 'client', function(ctx, label, count)
    local deadline = GetGameTimer() + 2000
    while (runs[label] or 0) < count and GetGameTimer() < deadline do ctx:check() Wait(50) end
    Wait(300) -- a double run would land here
    ctx:equal(runs[label] or 0, count, ('times "%s" ran'):format(label))
end)

K.step('I remove my temporary target zone', 'client', function(ctx)
    assert(ctx.state.targetZone, 'No native temporary zone is registered')
    ctx.state.removedZone = ctx.state.targetZone
    ctx:equal(removeNativeZone(ctx), true, 'removeZone result')
end)
K.step('removing my temporary target zone again should be refused', 'client', function(ctx)
    assert(ctx.state.removedZone, 'Remove the temporary zone first')
    ctx:equal(K.export(TARGET, 'removeZone', ctx.state.removedZone), false, 'second removeZone result')
end)

K.step('I remove my temporary legacy qb-target zone', 'client', function(ctx)
    ctx:equal(exports[LEGACY]:RemoveZone(LEGACY_ZONE), true, 'RemoveZone result')
end)

-- setEnabled is client-wide, so the previous value is put back in cleanup.
K.step('kora_target is switched off for this scenario', 'client', function(ctx)
    local state = K.export(TARGET, 'getState')
    assert(type(state) == 'table', 'getState did not return a table')
    local previous = state.enabled ~= false
    ctx:cleanup(function() exports.kora_target:setEnabled(previous) end)
    K.export(TARGET, 'setEnabled', false)
end)
K.step('kora_target is switched back on', 'client', function()
    K.export(TARGET, 'setEnabled', true)
end)
K.step('kora_target should report enabled {string}', 'client', function(ctx, expected)
    local state = K.export(TARGET, 'getState')
    assert(type(state) == 'table', 'getState did not return a table')
    ctx:equal(tostring(state.enabled), expected, 'getState().enabled')
end)
K.step('kora_target should report it is not targeting', 'client', function(ctx)
    local state = K.export(TARGET, 'getState')
    assert(type(state) == 'table', 'getState did not return a table')
    ctx:equal(state.active, false, 'getState().active')
    ctx:equal(state.hovering, nil, 'getState().hovering')
end)
K.step('starting to target should be blocked', 'client', function(ctx)
    ctx:cleanup(hookStop)
    local ok, _, code = exports.kora_target:fftAction('start')
    hookStop()
    ctx:equal(ok, false, 'start result')
    ctx:equal(code, 'blocked', 'start result code')
end)
K.step('starting to target should work', 'client', function(ctx)
    ctx:cleanup(hookStop)
    local ok, err = exports.kora_target:fftAction('start')
    local state = exports.kora_target:fftAction('state')
    hookStop()
    if not ok then error(err or 'Targeting did not start', 0) end
    ctx:equal(type(state) == 'table' and state.active, true, 'hook state.active')
end)

K.step('the kora_target server action {string} should be refused with {string}', 'client', function(ctx, name, reason)
    local ok, err = K.export(TARGET, 'runServerAction', name)
    ctx:equal(ok, false, 'runServerAction result')
    ctx:equal(err, reason, 'runServerAction reason')
end)

-- ===========================================================================
-- Deeper coverage: shapes, validation, removal semantics, callback contracts,
-- the vehicle and busy gates, session control, and the qb-target / ox_target
-- compatibility surfaces. Sources: kora_target/client/state.lua (validation,
-- removal), client/loop.lua (gates, resolver, runOption), client/compat/*.lua.
-- ===========================================================================

local OX = 'ox_target'
local OX_ZONE = 'fft_kora_target_ox_probe'
local LEGACY_EVENT = 'fft:kora_target:legacyProbe' -- this suite's own local event, fired by option.event

-- Option table for the native API from a JSON spec. Spec fields:
--   label, name, distance, allowInVehicle, data (passed through to callbacks),
--   gate (canInteract reads a kora_target gate), canInteract = "error" | "nil" | "record",
--   onSelect = "error" (raises after counting the run).
local function nativeOptions(ctx, specs)
    local options, labels = {}, {}
    ctx.state.optionData = ctx.state.optionData or {}
    for index, spec in ipairs(specs) do
        local label, gate, mode = spec.label, spec.gate, spec.canInteract
        assert(type(label) == 'string' and label ~= '', 'Every option needs a label')
        labels[label] = true
        ctx.state.optionData[label] = spec.data
        local canInteract
        if gate then
            canInteract = function() return gates[gate] == true end
        elseif mode == 'error' then
            canInteract = function() error('fft probe canInteract refusal on purpose', 0) end
        elseif mode == 'nil' then
            canInteract = function() return nil end
        elseif mode == 'record' then
            canInteract = function(entity, distance, data, anchor)
                seen.canInteract[label] = { entity = entity, distance = distance, data = data,
                    anchor = anchor and { x = anchor.x, y = anchor.y, z = anchor.z } or nil }
                return true
            end
        end
        local throws = spec.onSelect == 'error'
        options[index] = {
            label = label,
            name = spec.name or ('fft_probe_' .. index),
            distance = spec.distance,
            allowInVehicle = spec.allowInVehicle,
            data = spec.data,
            canInteract = canInteract,
            onSelect = function(entity, data)
                runs[label] = (runs[label] or 0) + 1
                seen.onSelect[label] = { entity = entity, data = data }
                if throws then error('fft probe onSelect failure on purpose', 0) end
            end,
        }
    end
    assert(#options > 0, 'The zone needs at least one option')
    return options, labels
end

-- Registers a native zone of `shape` around the probe point and tracks it like
-- the box zone step above (ctx.state.targetZone, removed in cleanup).
local function nativeZone(ctx, argument, shape, fields)
    assert(not ctx.state.targetZone, 'This scenario already registered a temporary zone')
    resetProbes(ctx)
    local point = probePoint(ctx)
    local options, labels = nativeOptions(ctx, K.json(argument))
    local zone = { options = options, drawSprite = false }
    for key, value in pairs(fields or {}) do zone[key] = value end
    local export
    if shape == 'box' then
        export = 'addBoxZone'
        zone.coords = { x = point.x, y = point.y, z = point.z + 0.5 }
        zone.size = { x = 1.5, y = 1.5, z = 2.0 }
        zone.rotation = 0.0
    elseif shape == 'sphere' then
        export = 'addSphereZone'
        zone.coords = { x = point.x, y = point.y, z = point.z }
        zone.radius = 1.0
    else
        export = 'addPolyZone'
        zone.points = {
            { x = point.x - 0.75, y = point.y - 0.75, z = point.z },
            { x = point.x + 0.75, y = point.y - 0.75, z = point.z },
            { x = point.x + 0.75, y = point.y + 0.75, z = point.z },
            { x = point.x - 0.75, y = point.y + 0.75, z = point.z },
        }
        zone.minZ, zone.maxZ = point.z - 1.0, point.z + 1.0
    end
    local id = K.export(TARGET, export, zone)
    assert(type(id) == 'number', export .. ' did not return a registration id')
    ctx.state.targetZone, ctx.state.targetLabels = id, labels
    ctx:cleanup(function() pcall(function() exports.kora_target:removeZone(id) end) end)
end

K.step('a temporary kora_target sphere zone ahead of me offers:', 'client', function(ctx, argument)
    nativeZone(ctx, argument, 'sphere')
end)
K.step('a temporary kora_target poly zone ahead of me offers:', 'client', function(ctx, argument)
    nativeZone(ctx, argument, 'poly')
end)
-- Zone-level distance: the default for options without their own (state.lua addBoxZone `distance`).
K.step('a temporary kora_target box zone ahead of me with zone distance {float} offers:', 'client', function(ctx, distance, argument)
    nativeZone(ctx, argument, 'box', { distance = distance })
end)
-- Zone-level allowInVehicle: the default for options that do not set their own (state.lua zoneAllowInVehicle).
K.step('a temporary kora_target box zone ahead of me that allows vehicles offers:', 'client', function(ctx, argument)
    nativeZone(ctx, argument, 'box', { allowInVehicle = true })
end)
K.step('a temporary kora_target box zone ahead of me with recorded callbacks offers:', 'client', function(ctx, argument)
    nativeZone(ctx, argument, 'box')
end)

-- ---------------------------------------------------------------------------
-- Validation (client/state.lua validateOptions and the add* asserts). Each case
-- builds a call that must raise; one that succeeds is removed again and fails.
-- ---------------------------------------------------------------------------

local function noop() end
local function hereCoords()
    local at = GetEntityCoords(PlayerPedId())
    return { x = at.x, y = at.y, z = at.z }
end
local function goodOption() return { label = 'FFT probe refused', onSelect = noop } end

local REFUSALS = {
    ['box zone without options'] = function()
        return 'addBoxZone', { coords = hereCoords(), size = { x = 1.0, y = 1.0, z = 1.0 }, options = {} }
    end,
    ['option without a label'] = function()
        return 'addBoxZone', { coords = hereCoords(), size = { x = 1.0, y = 1.0, z = 1.0 }, options = { { onSelect = noop } } }
    end,
    ['option with an empty label'] = function()
        return 'addBoxZone', { coords = hereCoords(), size = { x = 1.0, y = 1.0, z = 1.0 }, options = { { label = '', onSelect = noop } } }
    end,
    ['option without onSelect'] = function()
        return 'addBoxZone', { coords = hereCoords(), size = { x = 1.0, y = 1.0, z = 1.0 }, options = { { label = 'FFT probe refused' } } }
    end,
    ['option with a text canInteract'] = function()
        local option = goodOption()
        option.canInteract = 'yes'
        return 'addBoxZone', { coords = hereCoords(), size = { x = 1.0, y = 1.0, z = 1.0 }, options = { option } }
    end,
    ['option with a text distance'] = function()
        local option = goodOption()
        option.distance = 'far'
        return 'addBoxZone', { coords = hereCoords(), size = { x = 1.0, y = 1.0, z = 1.0 }, options = { option } }
    end,
    ['option with a text allowInVehicle'] = function()
        local option = goodOption()
        option.allowInVehicle = 'yes'
        return 'addBoxZone', { coords = hereCoords(), size = { x = 1.0, y = 1.0, z = 1.0 }, options = { option } }
    end,
    ['zone with a text allowInVehicle'] = function()
        return 'addBoxZone', { coords = hereCoords(), size = { x = 1.0, y = 1.0, z = 1.0 }, options = { goodOption() }, allowInVehicle = 'yes' }
    end,
    ['box zone without coords'] = function()
        return 'addBoxZone', { size = { x = 1.0, y = 1.0, z = 1.0 }, options = { goodOption() } }
    end,
    ['box zone without size'] = function()
        return 'addBoxZone', { coords = hereCoords(), options = { goodOption() } }
    end,
    ['sphere zone with zero radius'] = function()
        return 'addSphereZone', { coords = hereCoords(), radius = 0, options = { goodOption() } }
    end,
    ['sphere zone with negative radius'] = function()
        return 'addSphereZone', { coords = hereCoords(), radius = -1.0, options = { goodOption() } }
    end,
    ['poly zone with two points'] = function()
        local at = hereCoords()
        return 'addPolyZone', { points = { at, { x = at.x + 1.0, y = at.y, z = at.z } }, options = { goodOption() } }
    end,
    ['global type train'] = function() return 'addGlobalType', 'train', { goodOption() } end,
    ['model given as a boolean'] = function() return 'addModel', true, { goodOption() } end,
    ['global bone given as a number'] = function() return 'addGlobalBone', 7, { goodOption() } end,
    ['setEnabled with text'] = function() return 'setEnabled', 'off' end,
    ['server action without a name'] = function() return 'runServerAction', '' end,
}

-- Removes whatever a call that should have been refused registered anyway.
local function undoAccepted(name, id)
    if type(id) ~= 'number' then return end
    pcall(function()
        if name == 'addGlobalType' then exports.kora_target:removeGlobalType('ped', id)
        elseif name == 'addModel' then exports.kora_target:removeModel(nil, id)
        elseif name == 'addGlobalBone' then exports.kora_target:removeGlobalBone(id)
        else exports.kora_target:removeZone(id) end
    end)
end

K.step('the kora_target call {string} should be refused with {string}', 'client', function(ctx, case, reason)
    local build = REFUSALS[case]
    assert(build, 'Unknown refusal case: ' .. case)
    K.started(TARGET)
    local args = table.pack(build())
    local name = args[1]
    if name == 'setEnabled' then
        local before = exports.kora_target:getState().enabled
        ctx:cleanup(function() exports.kora_target:setEnabled(before ~= false) end)
    end
    -- Through the hook: an export's raised message does not survive the export boundary.
    local called, ok, result = pcall(function()
        return exports.kora_target:fftAction('call', name, table.unpack(args, 2, args.n))
    end)
    if not called then error('kora_target call hook failed: ' .. tostring(ok), 0) end
    if ok then
        undoAccepted(name, result)
        error(('%s accepted the "%s" case (returned %s)'):format(name, case, tostring(result)), 0)
    end
    if not K.contains(tostring(result), reason) then
        error(('%s refused with "%s", expected "%s"'):format(name, tostring(result), reason), 0)
    end
end)

-- skipInvalidEntities = true (config.lua): a non-number handle is skipped and nil returned.
K.step('registering kora_target options on a non-number entity handle should register nothing', 'client', function(ctx)
    local id = K.export(TARGET, 'addEntity', 'fft-not-a-handle', { goodOption() })
    if id ~= nil then
        pcall(function() exports.kora_target:removeEntity(0, id) end)
        error('addEntity accepted a text handle and returned ' .. tostring(id), 0)
    end
    ctx:equal(id, nil, 'addEntity result')
end)

-- ---------------------------------------------------------------------------
-- Removal semantics (state.lua mayRemove / removeZone / removeModel)
-- ---------------------------------------------------------------------------

K.step('removing kora_target zones that do not exist should be refused', 'client', function(ctx)
    ctx:equal(K.export(TARGET, 'removeZone', 999999999), false, 'removeZone of an unused id')
    ctx:equal(K.export(TARGET, 'removeZone', -1), false, 'removeZone of a negative id')
    ctx:equal(K.export(TARGET, 'removeZone', 'fft'), false, 'removeZone of a text id')
end)

-- A model name nothing in the game uses, so the registration can never match an entity.
local PROBE_MODEL = 'fft_kora_target_probe_model'

K.step('a temporary kora_target model registration exists', 'client', function(ctx)
    local id = K.export(TARGET, 'addModel', PROBE_MODEL, { goodOption() })
    assert(type(id) == 'number', 'addModel did not return a registration id')
    ctx.state.modelRegistration = id
    ctx:cleanup(function() pcall(function() exports.kora_target:removeModel(PROBE_MODEL) end) end)
end)
K.step('removing my model registration as a zone should be refused', 'client', function(ctx)
    local id = assert(ctx.state.modelRegistration, 'Register the model first')
    ctx:equal(K.export(TARGET, 'removeZone', id), false, 'removeZone of a model registration id')
end)
K.step('removing my model registration by model should succeed once', 'client', function(ctx)
    assert(ctx.state.modelRegistration, 'Register the model first')
    ctx:equal(K.export(TARGET, 'removeModel', PROBE_MODEL), true, 'first removeModel')
    ctx:equal(K.export(TARGET, 'removeModel', PROBE_MODEL), false, 'second removeModel')
end)

-- ---------------------------------------------------------------------------
-- Callback contracts (loop.lua optionAllowed / runOption)
-- ---------------------------------------------------------------------------

K.step('the kora_target option {string} should have been checked with its distance and data', 'client', function(ctx, label)
    local record
    ctx:waitUntil(function() record = seen.canInteract[label]; return record ~= nil end,
        'canInteract was never called for ' .. label, 3000)
    assert(type(record.distance) == 'number', 'canInteract distance is ' .. tostring(record.distance))
    -- Config.target.defaultOptionDistance = 2.5
    assert(record.distance >= 0 and record.distance <= 2.5, ('canInteract distance %.2f is outside 0-2.5'):format(record.distance))
    local expected = ctx.state.optionData and ctx.state.optionData[label]
    assert(type(record.data) == 'table' and type(expected) == 'table', 'canInteract did not receive the option data')
    ctx:equal(record.data.tag, expected.tag, 'canInteract data.tag')
    local point = ctx.state.targetPoint
    assert(record.anchor, 'canInteract did not receive anchor coords')
    local dx, dy = record.anchor.x - point.x, record.anchor.y - point.y
    -- The box is 1.5 m square around the probe point: its corners are 1.06 m from the centre.
    assert(dx * dx + dy * dy <= 1.2 * 1.2, 'canInteract anchor coords are outside the temporary zone')
end)
K.step('the kora_target option {string} should have been selected with its data', 'client', function(ctx, label)
    local record
    ctx:waitUntil(function() record = seen.onSelect[label]; return record ~= nil end, label .. ' was not selected', 3000)
    local expected = ctx.state.optionData and ctx.state.optionData[label]
    assert(type(record.data) == 'table' and type(expected) == 'table', 'onSelect did not receive the option data')
    ctx:equal(record.data.tag, expected.tag, 'onSelect data.tag')
end)

-- ---------------------------------------------------------------------------
-- Busy gate (Config.target.uiBlockBag = 'koraUiBlocked', loop.lua readBusy).
-- Set locally (not replicated) and put back in cleanup.
-- ---------------------------------------------------------------------------

K.step('the koraUiBlocked state is set for this scenario', 'client', function(ctx)
    local previous = LocalPlayer.state.koraUiBlocked
    ctx:cleanup(function() LocalPlayer.state:set('koraUiBlocked', previous, false) end)
    LocalPlayer.state:set('koraUiBlocked', true, false)
end)
K.step('the koraUiBlocked state is cleared', 'client', function()
    LocalPlayer.state:set('koraUiBlocked', false, false)
end)

-- ---------------------------------------------------------------------------
-- Session control: holding the eye, getState, target-reset, setEnabled.
-- ---------------------------------------------------------------------------

-- Leaves targeting running with my zone under the aim (stopped in cleanup).
K.step('I hold targeting on my temporary target zone', 'client', function(ctx)
    resetProbes(ctx)
    local last
    ctx:waitUntil(function()
        last = hovering()
        return mine(ctx, last)
    end, 'The temporary zone never came under the aim', 6000, function() return ' (' .. describe(last) .. ')' end)
end)
K.step('kora_target getState should report my temporary zone under the aim', 'client', function(ctx)
    local state = K.export(TARGET, 'getState')
    assert(type(state) == 'table', 'getState did not return a table')
    ctx:equal(state.enabled, true, 'getState().enabled')
    ctx:equal(state.active, true, 'getState().active')
    ctx:equal(state.success, true, 'getState().success')
    assert(type(state.hovering) == 'table', 'getState().hovering is empty')
    ctx:equal(state.hovering.kind, 'zone', 'getState().hovering.kind')
    ctx:equal(state.hovering.zoneId, ctx.state.targetZone, 'getState().hovering.zoneId')
    ctx:equal(state.hovering.optionCount, 1, 'getState().hovering.optionCount')
end)
-- qb-target IsTargetActive / IsTargetSuccess and ox_target isActive read the same flags.
K.step('the compatibility exports should report targeting {string}', 'client', function(ctx, expected)
    assert(expected == 'on' or expected == 'off', 'Use "on" or "off"')
    local on = expected == 'on'
    K.started(TARGET)
    ctx:waitUntil(function()
        return exports[LEGACY]:IsTargetActive() == on and exports[OX]:isActive() == on
    end, 'qb-target IsTargetActive / ox_target isActive do not report ' .. expected, 2000)
    if on then ctx:equal(exports[LEGACY]:IsTargetSuccess(), true, 'qb-target IsTargetSuccess') end
end)
K.step('kora_target should stop targeting', 'client', function(ctx)
    ctx:waitUntil(function()
        local state = exports.kora_target:getState()
        return state.active == false and state.hovering == nil
    end, 'kora_target is still targeting', 2000)
end)

-- ---------------------------------------------------------------------------
-- qb-target compatibility with every filter (client/compat/qb-target.lua makeCanInteract)
-- Spec fields copied as-is: job, excludejob, jobType, excludejobType, gang,
-- excludegang, item, required_item, citizenid ("@me" = my own citizen id), num,
-- event and type. Options without `event` count their runs through `action`.
-- ---------------------------------------------------------------------------

local LEGACY_FIELDS = { 'job', 'excludejob', 'jobType', 'excludejobType', 'gang', 'excludegang', 'item', 'required_item', 'num', 'type' }

local function legacyOptions(ctx, specs)
    local options, labels = {}, {}
    for index, spec in ipairs(specs) do
        local label = spec.label
        assert(type(label) == 'string' and label ~= '', 'Every option needs a label')
        labels[label] = true
        local option = { label = label }
        for _, field in ipairs(LEGACY_FIELDS) do option[field] = spec[field] end
        if spec.citizenid == '@me' then
            local data = exports.kora_core:getPlayerData()
            assert(type(data) == 'table' and data.citizenid, 'Could not read my citizen id')
            option.citizenid = data.citizenid
        else
            option.citizenid = spec.citizenid
        end
        if spec.event then
            assert(spec.event == LEGACY_EVENT, 'Only ' .. LEGACY_EVENT .. ' may be used as a legacy event')
            option.event = spec.event
            if not ctx.state.legacyEvents then
                local fired = {}
                ctx.state.legacyEvents = fired
                ctx:on(LEGACY_EVENT, function(data)
                    if type(data) == 'table' and type(data.label) == 'string' then fired[data.label] = (fired[data.label] or 0) + 1 end
                end)
            end
        else
            option.action = function() runs[label] = (runs[label] or 0) + 1 end
        end
        options[index] = option
    end
    assert(#options > 0, 'The zone needs at least one option')
    return options, labels
end

local function addLegacyZone(ctx, options)
    local point = probePoint(ctx)
    local ok, err = pcall(function()
        exports[LEGACY]:AddBoxZone(LEGACY_ZONE, vector3(point.x, point.y, point.z + 0.5), 1.5, 1.5,
            { name = LEGACY_ZONE, heading = 0.0, minZ = point.z - 0.5, maxZ = point.z + 1.5 },
            { options = options, distance = 2.5 })
    end)
    if not ok then error('qb-target AddBoxZone failed: ' .. tostring(err), 0) end
end

K.step('a temporary legacy qb-target box zone ahead of me with filters offers:', 'client', function(ctx, argument)
    resetProbes(ctx)
    local options, labels = legacyOptions(ctx, K.json(argument))
    K.started(TARGET)
    ctx:cleanup(function() pcall(function() exports[LEGACY]:RemoveZone(LEGACY_ZONE) end) end)
    addLegacyZone(ctx, options)
    ctx.state.targetLabels = labels
end)
-- AddBoxZone with a name already in use replaces that zone (qb-target.lua AddBoxZone).
K.step('my temporary legacy qb-target zone is registered again offering only {string}', 'client', function(ctx, label)
    local options, labels = legacyOptions(ctx, { { label = label } })
    addLegacyZone(ctx, options)
    ctx.state.targetLabels = labels
end)
K.step('I replace my temporary legacy qb-target zone options with {string}', 'client', function(ctx, label)
    local options, labels = legacyOptions(ctx, { { label = label } })
    ctx:equal(exports[LEGACY]:UpdateZoneData(LEGACY_ZONE, { options = options, distance = 2.5 }), true, 'UpdateZoneData result')
    ctx.state.targetLabels = labels
end)
K.step('the legacy qb-target zone data should describe my temporary zone', 'client', function(ctx)
    local data = exports[LEGACY]:GetZoneData(LEGACY_ZONE)
    assert(type(data) == 'table', 'GetZoneData returned no descriptor')
    ctx:equal(data.name, LEGACY_ZONE, 'GetZoneData().name')
    ctx:equal(data.isBoxZone, true, 'GetZoneData().isBoxZone')
end)
K.step('unknown legacy qb-target zone names should be refused', 'client', function(ctx)
    K.started(TARGET)
    ctx:equal(exports[LEGACY]:GetZoneData('fft_no_such_zone'), nil, 'GetZoneData of an unknown name')
    ctx:equal(exports[LEGACY]:UpdateZoneData('fft_no_such_zone', { options = {} }), false, 'UpdateZoneData of an unknown name')
    ctx:equal(exports[LEGACY]:RemoveZone('fft_no_such_zone'), false, 'RemoveZone of an unknown name')
end)
K.step('removing my temporary legacy qb-target zone again should be refused', 'client', function(ctx)
    ctx:equal(exports[LEGACY]:RemoveZone(LEGACY_ZONE), false, 'second RemoveZone result')
end)
K.step('the legacy qb-target event for {string} should have fired {int} times', 'client', function(ctx, label, count)
    local fired = assert(ctx.state.legacyEvents, 'No legacy event option was registered')
    local deadline = GetGameTimer() + 2000
    while (fired[label] or 0) < count and GetGameTimer() < deadline do ctx:check() Wait(50) end
    Wait(300)
    ctx:equal(fired[label] or 0, count, ('times the legacy event for "%s" fired'):format(label))
end)
K.step('the interact selector should list {string} first', 'client', function(ctx, label)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('interact.close') end) end)
    local interact
    ctx:waitUntil(function()
        interact = K.uiState().interact
        return type(interact) == 'table' and #interact > 0
    end, 'The interact selector is not open', 3000)
    ctx:equal(interact[1].label, label, 'first interact selector entry')
end)

-- AllowTargeting maps onto setEnabled (qb-target.lua AllowTargeting); restored in cleanup.
K.step('legacy qb-target targeting is disallowed for this scenario', 'client', function(ctx)
    local previous = K.export(TARGET, 'getState').enabled ~= false
    ctx:cleanup(function() exports.kora_target:setEnabled(previous) end)
    exports[LEGACY]:AllowTargeting(false)
end)
K.step('legacy qb-target targeting is allowed again', 'client', function()
    exports[LEGACY]:AllowTargeting(true)
end)

-- ---------------------------------------------------------------------------
-- ox_target compatibility (client/compat/ox-target.lua). Spec fields: label,
-- name, groups, items, anyItem, openMenu, menuName, record (true = record the
-- canInteract arguments). Every option counts its runs and keeps its response.
-- ---------------------------------------------------------------------------

K.step('a temporary ox_target box zone ahead of me offers:', 'client', function(ctx, argument)
    resetProbes(ctx)
    local point = probePoint(ctx)
    local options, labels = {}, {}
    for index, spec in ipairs(K.json(argument)) do
        local label = spec.label
        assert(type(label) == 'string' and label ~= '', 'Every option needs a label')
        labels[label] = true
        local option = {
            label = label, name = spec.name or ('fft_ox_probe_' .. index), groups = spec.groups, items = spec.items,
            anyItem = spec.anyItem, openMenu = spec.openMenu, menuName = spec.menuName,
            onSelect = function(response)
                runs[label] = (runs[label] or 0) + 1
                if type(response) == 'table' then
                    seen.oxSelect[label] = { zone = response.zone, distance = response.distance, entity = response.entity,
                        name = response.name, hasCoords = response.coords ~= nil }
                end
            end,
        }
        if spec.record then
            option.canInteract = function(entity, distance, coords, name)
                seen.oxCheck[label] = { entity = entity, distance = distance, hasCoords = coords ~= nil, name = name }
                return true
            end
        end
        options[index] = option
    end
    -- ox-target.lua translateOxOptions appends a "Go back" option to zones that use menus.
    labels['Go back'] = true
    K.started(TARGET)
    ctx:cleanup(function() pcall(function() exports[OX]:removeZone(OX_ZONE) end) end)
    local ok, id = pcall(function()
        return exports[OX]:addBoxZone({
            name = OX_ZONE,
            coords = vector3(point.x, point.y, point.z + 0.5),
            size = vector3(1.5, 1.5, 2.0),
            rotation = 0.0,
            drawSprite = false,
            options = options,
        })
    end)
    if not ok then error('ox_target addBoxZone failed: ' .. tostring(id), 0) end
    assert(type(id) == 'number', 'ox_target addBoxZone did not return a zone id')
    ctx.state.targetZone, ctx.state.targetLabels, ctx.state.oxZone = id, labels, id
    ctx:cleanup(function() pcall(function() exports.kora_target:removeZone(id) end) end)
end)
K.step('I remove my temporary ox_target zone by name', 'client', function(ctx)
    ctx.state.removedZone, ctx.state.targetZone = ctx.state.targetZone, nil
    ctx:equal(exports[OX]:removeZone(OX_ZONE), true, 'ox_target removeZone by name')
end)
K.step('removing my temporary ox_target zone by name again should be refused', 'client', function(ctx)
    ctx:equal(exports[OX]:removeZone(OX_ZONE), false, 'second ox_target removeZone by name')
end)
K.step('the ox_target response for {string} should describe my temporary zone', 'client', function(ctx, label)
    local record
    ctx:waitUntil(function() record = seen.oxSelect[label]; return record ~= nil end, label .. ' got no response', 3000)
    ctx:equal(record.zone, ctx.state.oxZone, 'response.zone')
    ctx:equal(type(record.distance), 'number', 'response.distance type')
    ctx:equal(record.hasCoords, true, 'response.coords present')
    ctx:equal(type(record.entity), 'number', 'response.entity type')
end)
K.step('the ox_target canInteract for {string} should have received the option name {string}', 'client', function(ctx, label, name)
    local record
    ctx:waitUntil(function() record = seen.oxCheck[label]; return record ~= nil end, 'canInteract never ran for ' .. label, 3000)
    ctx:equal(record.name, name, 'canInteract name argument')
    ctx:equal(type(record.entity), 'number', 'canInteract entity argument type')
    ctx:equal(type(record.distance), 'number', 'canInteract distance argument type')
    ctx:equal(record.hasCoords, true, 'canInteract coords argument present')
end)
-- disableTargeting(true) turns targeting OFF (ox-target.lua disableTargeting); restored in cleanup.
K.step('ox_target targeting is disabled for this scenario', 'client', function(ctx)
    local previous = K.export(TARGET, 'getState').enabled ~= false
    ctx:cleanup(function() exports.kora_target:setEnabled(previous) end)
    exports[OX]:disableTargeting(true)
end)
K.step('ox_target targeting is enabled again', 'client', function()
    exports[OX]:disableTargeting(false)
end)
