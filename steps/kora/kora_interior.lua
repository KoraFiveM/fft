-- kora_interior: client-only shell geometry. Scenarios use createGeometry /
-- removeGeometry, which spawn a frozen local object without teleporting anyone.
-- The shell is created far above the tester so nothing collides with it, and it
-- is removed during cleanup. No resource hook.
local K = FFT.kora
if not K then return end
K.feature('kora_interior')

local HEIGHT_ABOVE_TESTER = 250.0

local function shell(ctx)
    return assert(ctx.state.shell, 'Create an interior shell first')
end

-- Built at call time: vector4 does not exist while step files load.
local function defaultExit() return vector4(1.5, -10.0, 0.0, 358.5) end

-- `exit` false means "pass no exit offset". Every shell made in a scenario is
-- also kept in ctx.state.shells for the multi-shell steps.
local function create(ctx, model, placement, exit)
    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    local origin = vector3(at.x, at.y, at.z + HEIGHT_ABOVE_TESTER)
    if exit == nil then exit = defaultExit() elseif exit == false then exit = nil end
    local record = { model = model, origin = origin, exit = exit, testerAt = at }
    ctx.state.shell = record
    ctx.state.shells = ctx.state.shells or {}
    ctx.state.shells[#ctx.state.shells + 1] = record
    -- Registered before the call: a shell that streams in late is still removed.
    ctx:cleanup(function()
        if not record.objects or record.removed then return end
        pcall(function() exports.kora_interior:removeGeometry(record.objects) end)
        for _, entity in ipairs(record.objects) do
            if DoesEntityExist(entity) then DeleteEntity(entity) end
        end
    end)
    local result, err = K.export('kora_interior', 'createGeometry', origin, exit, model, placement)
    if not result then error(('createGeometry refused %s: %s'):format(model, tostring(err)), 0) end
    assert(type(result) == 'table' and type(result[1]) == 'table' and type(result[2]) == 'table',
        'createGeometry did not return { objects, points }')
    record.objects, record.points = result[1], result[2]
    assert(#record.objects == 1 and type(record.objects[1]) == 'number', 'createGeometry did not return one shell entity')
end

K.step('a centered {string} interior shell is created high above me', 'client', function(ctx, model)
    create(ctx, model, 'centered')
end)
K.step('a legacy-placed {string} interior shell is created high above me', 'client', function(ctx, model)
    create(ctx, model, 'legacy')
end)

K.step('the interior shell should exist as a frozen {string} object', 'client', function(ctx, model)
    local entity = shell(ctx).objects[1]
    assert(DoesEntityExist(entity), 'The shell entity does not exist')
    ctx:equal(GetEntityModel(entity), GetHashKey(model), 'Shell model hash')
    assert(IsEntityPositionFrozen(entity), 'The shell is not frozen in place')
    assert(not NetworkGetEntityIsNetworked(entity), 'The shell is networked; it must be a local object')
end)

K.step('the interior shell should sit at the origin I asked for', 'client', function(ctx)
    local record = shell(ctx)
    local distance = #(GetEntityCoords(record.objects[1]) - record.origin)
    assert(distance < 0.5, ('The shell is %.2fm from the requested origin'):format(distance))
end)

K.step('the interior shell should hand back the exit offset I supplied', 'client', function(ctx)
    local record = shell(ctx)
    local exit = record.points.exit
    assert(exit ~= nil, 'createGeometry returned no exit point')
    for _, axis in ipairs({ 'x', 'y', 'z', 'w' }) do
        assert(math.abs(exit[axis] - record.exit[axis]) < 0.001,
            ('Exit %s is %s, expected %s'):format(axis, tostring(exit[axis]), tostring(record.exit[axis])))
    end
end)

K.step('creating the interior shell should not have moved me or faded my screen', 'client', function(ctx)
    local record = shell(ctx)
    Wait(500)
    local moved = #(GetEntityCoords(PlayerPedId()) - record.testerAt)
    assert(moved < 2.0, ('The tester moved %.1fm when the shell was created'):format(moved))
    assert(not IsScreenFadedOut() and not IsScreenFadingOut(), 'The screen faded when the shell was created')
end)

K.step('I remove the interior shell', 'client', function(ctx)
    local record = shell(ctx)
    local removed, err = K.export('kora_interior', 'removeGeometry', record.objects)
    if removed ~= true then error('removeGeometry refused: ' .. tostring(err), 0) end
    record.removed = true
end)

K.step('the interior shell should be gone', 'client', function(ctx)
    local entity = shell(ctx).objects[1]
    ctx:waitUntil(function() return not DoesEntityExist(entity) end, 'The shell entity still exists', 3000)
end)

local function refusedCreate(ctx, expected, origin, placement)
    local result, err = K.export('kora_interior', 'createGeometry', origin, vector4(0.0, 0.0, 0.0, 0.0), 'shell_v16low', placement)
    if result then
        -- Should never happen; do not leave the unexpected shell behind.
        pcall(function() exports.kora_interior:removeGeometry(result[1]) end)
        error('createGeometry created a shell instead of refusing', 0)
    end
    ctx:equal(result, false, 'createGeometry result')
    ctx:equal(err, expected, 'Refusal reason')
end

K.step('creating an interior shell without an origin should be refused with {string}', 'client', function(ctx, expected)
    refusedCreate(ctx, expected, nil, 'centered')
end)
K.step('creating an interior shell at an origin without a height should be refused with {string}', 'client', function(ctx, expected)
    local at = GetEntityCoords(PlayerPedId())
    refusedCreate(ctx, expected, { x = at.x, y = at.y }, 'centered')
end)
K.step('creating an interior shell with the placement {string} should be refused with {string}', 'client', function(ctx, placement, expected)
    local at = GetEntityCoords(PlayerPedId())
    refusedCreate(ctx, expected, vector3(at.x, at.y, at.z + HEIGHT_ABOVE_TESTER), placement)
end)

K.step('removing interior shell geometry without an object list should be refused with {string}', 'client', function(ctx, expected)
    local removed, err = K.export('kora_interior', 'removeGeometry', 'not-a-list')
    ctx:equal(removed, false, 'removeGeometry result')
    ctx:equal(err, expected, 'Refusal reason')
end)

-- The tester's own ped is a real entity that kora_interior never created, so the
-- ownership check must refuse it and leave it alone.
K.step('removing an entity the interior resource did not create for me should be refused with {string}', 'client', function(ctx, expected)
    local ped = PlayerPedId()
    local removed, err = K.export('kora_interior', 'removeGeometry', { ped })
    ctx:equal(removed, false, 'removeGeometry result')
    ctx:equal(err, expected, 'Refusal reason')
    assert(DoesEntityExist(ped), 'The refused entity was deleted')
end)

-- ===========================================================================
-- Round 3 (client/main.lua:14-62, the SHELLS table at :114-131, README.md).
-- ===========================================================================

K.step('a {string} interior shell with the default placement is created high above me', 'client', function(ctx, model)
    create(ctx, model, nil)
end)

K.step('a centered interior shell is created high above me from the model hash of {string}', 'client', function(ctx, model)
    create(ctx, GetHashKey(model), 'centered')
end)

K.step('a centered {string} interior shell without an exit is created high above me', 'client', function(ctx, model)
    create(ctx, model, 'centered', false)
end)

K.step('the interior shell should hand back no exit point', 'client', function(ctx)
    local record = shell(ctx)
    ctx:equal(type(record.points), 'table', 'Points table')
    ctx:equal(record.points.exit, nil, 'Exit point')
end)

-- With no placement, createGeometry uses Config.DefaultGeometryPlacement
-- ('legacy' in kora_interior/config.lua), so both shells land in one spot.
K.step('the default placement should put the shell where the {word} placement does', 'client', function(ctx, mode)
    local shells = ctx.state.shells or {}
    assert(#shells >= 2, 'Create a default-placed shell and a second one first')
    local default, other = shells[#shells - 1], shells[#shells]
    local a, b = GetEntityCoords(default.objects[1]), GetEntityCoords(other.objects[1])
    local distance = #(a - b)
    assert(distance < 0.05, ('The default-placed shell is %.2f m from the %s-placed one'):format(distance, mode))
end)

K.step('a second {string} interior shell with the {word} placement is created high above me', 'client', function(ctx, model, mode)
    assert(mode == 'legacy' or mode == 'centered', 'Placement must be legacy or centered')
    create(ctx, model, mode)
end)

K.step('I remove every interior shell in one call', 'client', function(ctx)
    local all = {}
    for _, record in ipairs(ctx.state.shells or {}) do
        for _, entity in ipairs(record.objects or {}) do all[#all + 1] = entity end
    end
    assert(#all >= 2, 'Create at least two shells first')
    local removed, err = K.export('kora_interior', 'removeGeometry', all)
    if removed ~= true then error('removeGeometry refused: ' .. tostring(err), 0) end
    for _, record in ipairs(ctx.state.shells) do record.removed = true end
end)

K.step('every interior shell should be gone', 'client', function(ctx)
    for _, record in ipairs(ctx.state.shells or {}) do
        local entity = record.objects[1]
        ctx:waitUntil(function() return not DoesEntityExist(entity) end, 'A shell entity still exists', 3000)
    end
end)

K.step('removing the interior shell again should be refused with {string}', 'client', function(ctx, expected)
    local record = shell(ctx)
    assert(record.removed, 'Remove the interior shell first')
    local removed, err = K.export('kora_interior', 'removeGeometry', record.objects)
    ctx:equal(removed, false, 'removeGeometry result')
    ctx:equal(err, expected, 'Refusal reason')
end)

-- removeGeometry checks every entity before it deletes any (client/main.lua:44-46).
K.step('removing my interior shell together with my own ped should be refused with {string}', 'client', function(ctx, expected)
    local record = shell(ctx)
    local ped = PlayerPedId()
    local removed, err = K.export('kora_interior', 'removeGeometry', { record.objects[1], ped })
    ctx:equal(removed, false, 'removeGeometry result')
    ctx:equal(err, expected, 'Refusal reason')
    assert(DoesEntityExist(ped), 'The tester ped was deleted')
end)

K.step('the interior shell should still exist', 'client', function(ctx)
    Wait(300)
    assert(DoesEntityExist(shell(ctx).objects[1]), 'The shell entity was deleted')
end)

K.step('removing an empty interior shell list should succeed', 'client', function(ctx)
    ctx:equal(K.export('kora_interior', 'removeGeometry', {}), true, 'removeGeometry result for an empty list')
end)

local BAD_ORIGINS = {
    nan_z = function(at) return { x = at.x, y = at.y, z = 0 / 0 } end,
    infinite_x = function(at) return { x = math.huge, y = at.y, z = at.z + HEIGHT_ABOVE_TESTER } end,
    negative_infinite_y = function(at) return { x = at.x, y = -math.huge, z = at.z + HEIGHT_ABOVE_TESTER } end,
    text_coordinates = function(at) return { x = tostring(at.x), y = tostring(at.y), z = tostring(at.z + HEIGHT_ABOVE_TESTER) } end,
    empty_table = function() return {} end,
    text_origin = function() return 'here' end,
}

K.step('creating an interior shell at the bad origin {string} should be refused with {string}', 'client', function(ctx, case, expected)
    local build = assert(BAD_ORIGINS[case], 'Unknown bad origin case: ' .. case)
    refusedCreate(ctx, expected, build(GetEntityCoords(PlayerPedId())), 'centered')
end)

K.step('creating an interior shell with a numeric placement should be refused with {string}', 'client', function(ctx, expected)
    local at = GetEntityCoords(PlayerPedId())
    refusedCreate(ctx, expected, vector3(at.x, at.y, at.z + HEIGHT_ABOVE_TESTER), 1)
end)

-- README.md: createGeometry "returns { objects, { exit = exitOffset } } or false, reason".
local function refusedModel(ctx, model)
    local at = GetEntityCoords(PlayerPedId())
    K.started('kora_interior')
    local ok, result, err = pcall(function()
        return exports.kora_interior:createGeometry(vector3(at.x, at.y, at.z + HEIGHT_ABOVE_TESTER), defaultExit(), model, 'centered')
    end)
    if ok and type(result) == 'table' then
        pcall(function() exports.kora_interior:removeGeometry(result[1]) end)
        error('createGeometry created a shell from an unusable model', 0)
    end
    assert(ok, 'createGeometry raised an error instead of returning false, reason: ' .. tostring(result))
    ctx:equal(result, false, 'createGeometry result')
    assert(type(err) == 'string' and err ~= '', 'createGeometry gave no refusal reason')
end

K.step('creating an interior shell from the unknown model {string} should be refused', 'client', function(ctx, model)
    refusedModel(ctx, model)
end)
K.step('creating an interior shell without a model should be refused', 'client', function(ctx)
    refusedModel(ctx, nil)
end)

-- Reads the export without calling it: the legacy factories teleport and fade.
K.step('the interior factory {string} should be exported under {string}', 'client', function(_, name, resource)
    assert(resource == 'kora_interior' or resource == 'qb-interior', 'Only kora_interior and its qb-interior alias')
    K.started('kora_interior')
    local ok, value = pcall(function() return exports[resource][name] end)
    assert(ok, ('exports[%q].%s failed: %s'):format(resource, name, tostring(value)))
    local kind = type(value)
    assert(kind == 'function' or kind == 'table', ('exports[%q].%s is not exported (got %s)'):format(resource, name, kind))
end)
