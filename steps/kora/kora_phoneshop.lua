-- kora_phoneshop: streamed map (ytyp + models) with no scripts, exports, events
-- or commands. The only thing a runner can assert is that both realms started
-- it; whether the interior renders or collides is not observable from Lua.
local K = FFT.kora
if not K then return end
K.feature('kora_phoneshop')

K.step('my game should have started the map resource {string}', 'client', function(ctx, resource)
    ctx:waitUntil(function() return GetResourceState(resource) == 'started' end,
        ('%s is %s on the client'):format(resource, GetResourceState(resource)), 5000)
end)

K.step('the map resource {string} should declare the type file {string}', 'server', function(_, resource, file)
    local declared = {}
    for index = 0, GetNumResourceMetadata(resource, 'data_file') - 1 do
        if GetResourceMetadata(resource, 'data_file', index) == 'DLC_ITYP_REQUEST' then
            declared[#declared + 1] = GetResourceMetadata(resource, 'data_file_extra', index)
        end
    end
    for _, path in ipairs(declared) do
        if type(path) == 'string' and path:find(file, 1, true) then return end
    end
    error(('%s does not declare %s as DLC_ITYP_REQUEST (declares: %s)'):format(resource, file, table.concat(declared, ', ')), 0)
end)

-- A streamed drawable whose archetype was registered from the ytyp is known to
-- the game's model index. This proves the assets were mounted, not that the
-- interior is placed or visible.
K.step('my game should know the phone shop model {string}', 'client', function(_, model)
    local hash = GetHashKey(model)
    assert(IsModelInCdimage(hash) and IsModelValid(hash), 'The game does not know the streamed model ' .. model)
end)

-- ---------------------------------------------------------------------------
-- Round 3
-- ---------------------------------------------------------------------------

-- this_is_a_map 'yes' and no script entries in kora_phoneshop/fxmanifest.lua.
K.step('the map resource {string} should be flagged as a map', 'server', function(ctx, resource)
    K.started(resource)
    ctx:equal(GetResourceMetadata(resource, 'this_is_a_map', 0), 'yes', resource .. ' this_is_a_map')
end)
K.step('the map resource {string} should declare no {string} entries', 'server', function(ctx, resource, key)
    K.started(resource)
    ctx:equal(GetNumResourceMetadata(resource, key), 0, resource .. ' ' .. key .. ' entries')
end)
K.step('the map resource {string} should ship the stream file {string}', 'server', function(_, resource, file)
    K.started(resource)
    local content = LoadResourceFile(resource, 'stream/' .. file)
    assert(type(content) == 'string' and #content > 0, ('%s has no stream/%s'):format(resource, file))
end)

-- Placement decoded from kora_phoneshop/stream/kora_phoneshop.ymap: the
-- CMloInstanceDef of archetype "kora_phoneshop" (declared in phoneshop.ytyp)
-- sits at 94.338, -1427.313, 28.45, and a phoneshop_ramp entity at
-- 88.679, -1434.13, 28.311. These are unverified until a live run.
local MLO = { x = 94.338, y = -1427.313, z = 28.45, name = 'kora_phoneshop' }
local RAMP = { x = 88.679, y = -1434.13, z = 28.311, model = 'phoneshop_ramp' }

local function shopInterior(x, y, z)
    local interior = GetInteriorAtCoords(x + 0.0, y + 0.0, z + 0.0)
    if not interior or interior == 0 or not IsValidInterior(interior) then return nil end
    local position, nameHash = GetInteriorInfo(interior)
    if nameHash ~= GetHashKey(MLO.name) then return nil end
    return interior, position
end

K.step('the phone shop interior should be placed where its map puts it', 'client', function(ctx)
    local position
    ctx:waitUntil(function()
        local interior
        interior, position = shopInterior(94.6, -1427.26, 30.0)
        return interior and IsInteriorReady(interior)
    end, 'No ready kora_phoneshop interior at the phone shop', 10000)
    local distance = #(vector3(position.x, position.y, position.z) - vector3(MLO.x, MLO.y, MLO.z))
    assert(distance < 1.0, ('The phone shop interior is %.2f m from where its ymap places it'):format(distance))
end)
K.step('I should be standing inside the phone shop interior', 'client', function(ctx)
    ctx:waitUntil(function()
        local interior = GetInteriorFromEntity(PlayerPedId())
        if interior == 0 then return false end
        local _, nameHash = GetInteriorInfo(interior)
        return nameHash == GetHashKey(MLO.name)
    end, 'The tester is not inside the kora_phoneshop interior', 10000)
end)
K.step('the phone shop ramp should be placed where its map puts it', 'client', function(ctx)
    local hash = GetHashKey(RAMP.model)
    ctx:waitUntil(function()
        return GetClosestObjectOfType(RAMP.x, RAMP.y, RAMP.z, 2.0, hash, false, false, false) ~= 0
    end, 'No phoneshop_ramp within 2 m of where the ymap places it', 10000)
end)
