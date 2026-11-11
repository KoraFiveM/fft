-- kora_doorlock: door state, access and the interaction prompt.
-- Config.Doors ships empty and a fresh database has no doors, so the suite brings
-- its own: each "... is available" step creates one fixture door through the real
-- exports.kora_doorlock:createDoor export (id `fft-test-door`, labelled as FFT test
-- data, on the vanilla Mission Row PD front door) and cleanup removes it again
-- with exports.kora_doorlock:removeDoor. Creating, toggling and removing a door
-- are broadcast to every client, so the scenarios that toggle it are @global.
-- No resource hook. The server publishes the door's id and position to the
-- tester's client in a player state bag (`fftDoorlock`), because the two realms
-- do not share ctx.state.
local K = FFT.kora
if not K then return end
K.feature('kora_doorlock')

local BAG = 'fftDoorlock'

-- The fixture. The id satisfies kora_doorlock's own rule (server/main.lua validId)
-- and cannot collide with a generated id for a real label by accident.
local FIXTURE_ID = 'fft-test-door'
local FIXTURE_LABEL = 'FFT test door (safe to delete)'
-- Vanilla Mission Row PD front door, left leaf (no MLO needed).
local FIXTURE_MODEL = 'v_ilev_ph_door01'
local FIXTURE_COORDS = { x = 434.7479, y = -980.6184, z = 30.83926 }
local FIXTURE_HEADING = 270.0
local FIXTURE_PASSCODE = 'fft-fixture-pin'

-- ---------------------------------------------------------------------------
-- Server: the fixture door
-- ---------------------------------------------------------------------------

local function allDoors()
    local doors = K.export('kora_doorlock', 'getAllDoors')
    assert(type(doors) == 'table', 'getAllDoors() did not return a list')
    return doors
end

local function testerHasRole(ctx, name)
    local player = K.player(ctx)
    for _, role in ipairs({ player.job or false, player.gang or false }) do
        if role and type(role.name) == 'string' and role.name:lower() == name then return true end
    end
    return false
end

local function aceAllowed(source, object)
    local allowed = IsPlayerAceAllowed(source, object)
    return allowed == true or allowed == 1
end

local function choose(ctx, door)
    ctx.state.door = { id = door.id, label = door.label, original = door.locked == true, coords = door.coords }
    return ctx.state.door
end

-- Every door this suite creates carries the fixture label, or the fixture label
-- followed by more text after a rename; cleanup only removes doors labelled so.
local function isFixtureLabel(label)
    return type(label) == 'string' and label:sub(1, #FIXTURE_LABEL) == FIXTURE_LABEL
end

local function removeFixture()
    local removed, err = exports.kora_doorlock:removeDoor(FIXTURE_ID)
    return removed == true, err
end

-- Creates the fixture door and registers its removal before anything else can
-- fail. `extra` adds the access rule a scenario needs (groups, passcode).
local function createFixture(ctx, extra)
    assert(ctx.state.door == nil, 'This scenario already has a doorlock door')
    local stale = K.export('kora_doorlock', 'getDoor', FIXTURE_ID)
    if type(stale) == 'table' then
        -- Only ever a leftover of this suite (server stopped mid-scenario): the
        -- label is checked so a real door that happens to share the id survives.
        if not isFixtureLabel(stale.label) then
            error(('A door with the id %s exists and is not the FFT fixture ("%s"); refusing to replace it')
                :format(FIXTURE_ID, tostring(stale.label)), 0)
        end
        local removed, err = removeFixture()
        assert(removed, 'Could not remove the leftover FFT fixture door: ' .. tostring(err))
    end

    local raw = {
        id = FIXTURE_ID,
        label = FIXTURE_LABEL,
        model = GetHashKey(FIXTURE_MODEL),
        coords = { x = FIXTURE_COORDS.x, y = FIXTURE_COORDS.y, z = FIXTURE_COORDS.z },
        heading = FIXTURE_HEADING,
        distance = 2.5,
        locked = false, -- nobody is locked out of the police station while a scenario runs
    }
    for key, value in pairs(extra or {}) do raw[key] = value end

    -- Registered before the create call: a create that persisted but whose
    -- result never came back is still removed.
    ctx:cleanup(function()
        pcall(function()
            local door = exports.kora_doorlock:getDoor(FIXTURE_ID)
            if type(door) == 'table' and isFixtureLabel(door.label) then removeFixture() end
        end)
    end)
    local id = K.export('kora_doorlock', 'createDoor', raw)
    if id ~= FIXTURE_ID then
        error('exports.kora_doorlock:createDoor refused the FFT fixture door (returned ' .. tostring(id)
            .. '); is the doorlock database ready?', 0)
    end
    local door = K.export('kora_doorlock', 'getDoor', FIXTURE_ID)
    assert(type(door) == 'table', 'The fixture door was created but getDoor does not return it')
    assert(type(door.coords) == 'table' or type(door.coords) == 'vector3', 'The fixture door has no coords')
    -- Unlocked unless the scenario asks for a locked door (the lockpick refusal).
    ctx:equal(door.locked, raw.locked == true, 'Fixture door lock state after creation')
    return choose(ctx, door)
end

local function chosen(ctx)
    return assert(ctx.state.door, 'Choose a doorlock door first')
end

-- Puts the lock state back to what it was before the scenario. Registered before
-- anything can change the door.
local function restoreAfterwards(ctx)
    local door = chosen(ctx)
    if door.restoring then return end
    door.restoring = true
    local id, original = door.id, door.original
    ctx:cleanup(function()
        pcall(function()
            if (exports.kora_doorlock:getDoorState(id) == true) ~= original then exports.kora_doorlock:setDoorState(id, original) end
        end)
    end)
end

local function watchChanges(ctx)
    local id = chosen(ctx).id
    K.capture(ctx, 'kora_doorlock:stateChanged', function(_, changedId) return changedId == id end)
end

local function publish(ctx, expected)
    local door, tester = chosen(ctx), ctx.tester
    if not door.published then
        door.published = true
        ctx:cleanup(function() pcall(function() Player(tester).state:set(BAG, nil, true) end) end)
    end
    Player(tester).state:set(BAG, {
        id = door.id, label = door.label, locked = expected, x = door.coords.x, y = door.coords.y, z = door.coords.z,
    }, true)
end

local function announced(ctx, locked, source)
    local door = chosen(ctx)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, 'kora_doorlock:stateChanged')) do
            if record[2] == door.id and record[3] == locked and (source == nil or record[1] == source) then return true end
        end
    end, ('No kora_doorlock:stateChanged for %s becoming %s'):format(door.id, locked and 'locked' or 'unlocked'), 5000)
end

K.step('a doorlock door is available', 'server', function(ctx)
    createFixture(ctx)
end)

-- The passcode is only there so "does not reveal a passcode" has one to hide.
K.step('a doorlock door with a passcode is available', 'server', function(ctx)
    createFixture(ctx, { passcode = FIXTURE_PASSCODE }).passcode = true
end)

K.step('a doorlock door I can be let through is available', 'server', function(ctx)
    local door = createFixture(ctx)
    restoreAfterwards(ctx)
    watchChanges(ctx)
    -- The fixture has no groups, items or characters, and
    -- Config.UnrestrictedDoorsOpenToAll is off, so nobody may toggle it. The
    -- tester is let through with kora_doorlock's public extension point: a
    -- doorAuthorization hook that returns true grants access. It is limited to
    -- the tester and this door and removed in cleanup.
    local id, tester = door.id, ctx.tester
    local hookId = K.export('kora_doorlock', 'registerHook', 'doorAuthorization', function(payload)
        if type(payload) == 'table' and payload.source == tester and payload.doorId == id then return true end
    end)
    assert(type(hookId) == 'number', 'registerHook did not return a hook id')
    ctx:cleanup(function() pcall(function() exports.kora_doorlock:removeHook(hookId) end) end)
    publish(ctx, door.original)
end)

K.step('a doorlock door restricted to a group I am not in is available', 'server', function(ctx)
    -- Both are real kora_core jobs; the door asks for whichever the tester is not in.
    local group
    for _, name in ipairs({ 'police', 'ambulance' }) do
        if not group and not testerHasRole(ctx, name) then group = name end
    end
    assert(group, 'The tester is in both police and ambulance; no group is left to restrict the door to')
    for _, object in ipairs({ 'doorlock.' .. FIXTURE_ID, 'doorlock.' .. FIXTURE_LABEL }) do
        if aceAllowed(ctx.tester, object) then
            error('The tester holds the ACE ' .. object .. ', which opens the fixture door; this scenario needs a tester without it', 0)
        end
    end
    local door = createFixture(ctx, { groups = { [group] = 0 } })
    restoreAfterwards(ctx)
    watchChanges(ctx)
    publish(ctx, door.original)
end)

-- ---------------------------------------------------------------------------
-- Server: read-only exports
-- ---------------------------------------------------------------------------

K.step('the chosen door should be described with its lock state and position', 'server', function(ctx)
    local id = chosen(ctx).id
    local door = K.export('kora_doorlock', 'getDoor', id)
    assert(type(door) == 'table', 'getDoor did not return the door')
    ctx:equal(door.id, id, 'Door id')
    assert(type(door.label) == 'string' and door.label ~= '', 'The door has no label')
    assert(type(door.locked) == 'boolean', 'door.locked is not a boolean')
    ctx:equal(door.state, door.locked and 1 or 0, 'Numeric door state')
    ctx:equal(K.export('kora_doorlock', 'getDoorState', id) == true, door.locked, 'getDoorState against getDoor')
    assert(type(door.coords) == 'table', 'The door has no coords')
    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        assert(type(door.coords[axis]) == 'number', 'Door coordinate ' .. axis .. ' is not a number')
    end
    assert(type(door.distance) == 'number' and door.distance > 0, 'The door has no interaction distance')
    ctx:equal(door.maxDistance, door.distance, 'Legacy maxDistance alias')
end)

K.step('the chosen door should not reveal a passcode', 'server', function(ctx)
    local door = K.export('kora_doorlock', 'getDoor', chosen(ctx).id)
    assert(type(door) == 'table' and type(door.definition) == 'table', 'getDoor returned no definition')
    assert(door.definition.passcode == nil, 'The public door definition exposes its passcode')
    assert(type(door.definition.hasPasscode) == 'boolean', 'definition.hasPasscode is not a boolean')
    ctx:equal(door.definition.hasPasscode, chosen(ctx).passcode == true, 'definition.hasPasscode')
end)

K.step('no listed doorlock door should reveal a passcode', 'server', function()
    for _, door in ipairs(allDoors()) do
        assert(type(door.definition) == 'table', 'Door ' .. tostring(door.id) .. ' has no definition')
        assert(door.definition.passcode == nil, 'Door ' .. tostring(door.id) .. ' exposes its passcode')
    end
end)

K.step('the doorlock door list should include the chosen door', 'server', function(ctx)
    local id, count = chosen(ctx).id, 0
    for _, door in ipairs(allDoors()) do if door.id == id then count = count + 1 end end
    ctx:equal(count, 1, 'Entries for ' .. id .. ' in getAllDoors')
end)

K.step('the doorlock door list should be ordered by id without duplicates', 'server', function()
    local previous
    for _, door in ipairs(allDoors()) do
        assert(type(door.id) == 'string' and door.id ~= '', 'A listed door has no id')
        assert(previous == nil or previous < door.id, ('Door list is not strictly ordered at %s'):format(door.id))
        previous = door.id
    end
end)

K.step('the chosen door should be found again by its label', 'server', function(ctx)
    local door = chosen(ctx)
    local found = K.export('kora_doorlock', 'getDoorFromName', door.label)
    assert(type(found) == 'table', 'getDoorFromName did not find "' .. tostring(door.label) .. '"')
    -- Labels are not unique, so only the label is compared.
    ctx:equal(found.label, door.label, 'Label of the door found by name')
end)

K.step('the doorlock should know no door with the id {string}', 'server', function(ctx, id)
    ctx:equal(K.export('kora_doorlock', 'getDoor', id), false, 'getDoor for an unknown id')
    ctx:equal(K.export('kora_doorlock', 'getDoorState', id), nil, 'getDoorState for an unknown id')
    ctx:equal(K.export('kora_doorlock', 'getDoorFromName', id), nil, 'getDoorFromName for an unknown label')
end)

K.step('setting the lock state of the unknown door {string} should be refused', 'server', function(ctx, id)
    assert(K.export('kora_doorlock', 'getDoor', id) == false, 'A door with the id ' .. id .. ' exists; refusing to touch it')
    ctx:equal(K.export('kora_doorlock', 'setDoorState', id, true), false, 'setDoorState for an unknown id')
end)

K.step('setting the chosen door to an invalid lock state should be refused and change nothing', 'server', function(ctx)
    local door = chosen(ctx)
    restoreAfterwards(ctx)
    watchChanges(ctx)
    for _, invalid in ipairs({ 'open', 2, -1 }) do
        ctx:equal(K.export('kora_doorlock', 'setDoorState', door.id, invalid), false, 'setDoorState with ' .. tostring(invalid))
    end
    ctx:equal(K.export('kora_doorlock', 'getDoorState', door.id) == true, door.original, 'Lock state after the refusals')
    ctx:equal(#K.captured(ctx, 'kora_doorlock:stateChanged'), 0, 'State change announcements')
end)

-- ---------------------------------------------------------------------------
-- Server: changing a door (@global)
-- ---------------------------------------------------------------------------

K.step('the doorlock export flips the chosen door', 'server', function(ctx)
    local door = chosen(ctx)
    restoreAfterwards(ctx)
    watchChanges(ctx)
    door.expected = not door.original
    publish(ctx, door.expected)
    ctx:equal(K.export('kora_doorlock', 'setDoorState', door.id, door.expected), true, 'setDoorState result')
end)

K.step('the chosen door should report the flipped lock state', 'server', function(ctx)
    local door = chosen(ctx)
    assert(door.expected ~= nil, 'Flip the chosen door first')
    ctx:equal(K.export('kora_doorlock', 'getDoorState', door.id) == true, door.expected, 'getDoorState')
    ctx:equal(K.export('kora_doorlock', 'getDoor', door.id).locked, door.expected, 'getDoor().locked')
end)

K.step('the flip of the chosen door should have been announced to other resources', 'server', function(ctx)
    local door = chosen(ctx)
    assert(door.expected ~= nil, 'Flip the chosen door first')
    announced(ctx, door.expected, nil)
end)

K.step('the chosen door should have changed lock state because of me', 'server', function(ctx)
    local door = chosen(ctx)
    ctx:waitUntil(function() return (K.export('kora_doorlock', 'getDoorState', door.id) == true) ~= door.original end,
        'The server did not toggle the door ' .. door.id, 5000)
    announced(ctx, not door.original, ctx.tester)
end)

K.step('the chosen door should have kept its lock state', 'server', function(ctx)
    local door = chosen(ctx)
    Wait(1000)
    ctx:equal(K.export('kora_doorlock', 'getDoorState', door.id) == true, door.original, 'Lock state after the refusal')
    ctx:equal(#K.captured(ctx, 'kora_doorlock:stateChanged'), 0, 'State change announcements')
end)

-- ---------------------------------------------------------------------------
-- Client
-- ---------------------------------------------------------------------------

local function published(ctx)
    return ctx:waitUntil(function()
        local door = LocalPlayer.state[BAG]
        if type(door) == 'table' and type(door.id) == 'string' then return door end
    end, 'The server step did not publish the chosen door to this client', 5000)
end

local function promptFor(locked) return locked and 'Unlock Door' or 'Lock Door' end

K.step('my game should show the chosen door in the lock state the server set', 'client', function(ctx)
    local door = published(ctx)
    ctx:waitUntil(function() return K.export('kora_doorlock', 'getDoorState', door.id) == door.locked end,
        ('Client does not see door %s as %s'):format(door.id, tostring(door.locked)), 5000,
        function() return ' | it sees ' .. tostring((K.export('kora_doorlock', 'getDoorState', door.id))) end)
end)

K.step('I stand at the chosen door', 'client', function(ctx)
    local door = published(ctx)
    -- The door was created a moment ago; its definition reaches clients by event.
    ctx:waitUntil(function() return K.export('kora_doorlock', 'getDoorState', door.id) ~= nil end,
        'This client has no definition for door ' .. door.id, 5000)
    K.teleport(ctx, door.x, door.y, door.z)
    ctx:waitUntil(function() return K.export('kora_doorlock', 'getClosestDoorId') == door.id end,
        ('Door %s is not the closest door in reach'):format(door.id), 8000,
        -- getClosestDoorId returns nil when no door is in reach, which arrives
        -- as no value; read it lazily and adjusted to one value.
        function() return (' (closest: %s)'):format(tostring((K.export('kora_doorlock', 'getClosestDoorId')))) end)
    -- The server checks the distance against its own copy of the ped position.
    Wait(1000)
end)

K.step('the door prompt should offer what the chosen door allows', 'client', function(ctx)
    local door = published(ctx)
    ctx:waitUntil(function()
        local prompt = K.uiState().textui
        local locked = K.export('kora_doorlock', 'getDoorState', door.id)
        return type(prompt) == 'table' and locked ~= nil and K.contains(prompt.text, promptFor(locked))
    end, 'The door prompt does not match the lock state of ' .. door.id, 5000)
end)

K.step('the door prompt should have switched for the chosen door', 'client', function(ctx)
    local door = published(ctx)
    ctx:waitUntil(function()
        local prompt = K.uiState().textui
        return K.export('kora_doorlock', 'getDoorState', door.id) == not door.locked
            and type(prompt) == 'table' and K.contains(prompt.text, promptFor(not door.locked))
    end, 'The door prompt did not switch after the toggle', 5000)
end)

K.step('I use the closest door', 'client', function(ctx)
    local door = published(ctx)
    ctx:equal(K.export('kora_doorlock', 'getClosestDoorId'), door.id, 'Closest door')
    ctx:equal(K.export('kora_doorlock', 'useClosestDoor'), true, 'useClosestDoor result')
end)

K.step('my game should still show the chosen door in its original lock state', 'client', function(ctx)
    local door = published(ctx)
    Wait(1000)
    ctx:equal(K.export('kora_doorlock', 'getDoorState', door.id), door.locked, 'Client lock state after the refusal')
end)

K.step('using or picking the closest door should do nothing while no door is in reach', 'client', function(ctx)
    if K.export('kora_doorlock', 'getClosestDoorId') ~= nil then
        error('The tester is standing at a door; move away for this scenario', 0)
    end
    ctx:equal(K.export('kora_doorlock', 'useClosestDoor'), false, 'useClosestDoor with no door in reach')
    ctx:equal(K.export('kora_doorlock', 'pickClosestDoor'), false, 'pickClosestDoor with no door in reach')
end)

-- ===========================================================================
-- Round 3: definitions, ids, edits, auto-lock, hooks, policies and access
-- ===========================================================================

-- Spare doors: server-side fixtures that never need a player at them. They use
-- the commented example leaves of kora_doorlock/config.lua:21-22 (README.md:159-160):
-- v_ilev_ph_door01 at 434.7,-983.2,30.8 (heading 90) and 434.7,-985.0,30.8
-- (heading 270), so a spare door may be locked without locking the station's
-- real left leaf, which the main fixture uses. They carry the fixture label
-- and are removed with the same label check.
local SPARE_ID = 'fft-test-door-spare'
local SPARE_LEAVES = {
    { coords = { x = 434.7, y = -983.2, z = 30.8 }, heading = 90.0 },
    { coords = { x = 434.7, y = -985.0, z = 30.8 }, heading = 270.0 },
}
-- server/main.lua:387-398 uniqueSlug: the id createDoor makes from FIXTURE_LABEL.
local SLUG_ID = 'fft-test-door-safe-to-delete'
local RENAMED_LABEL = FIXTURE_LABEL .. ' renamed'

local function removeIfFixture(id)
    pcall(function()
        local door = exports.kora_doorlock:getDoor(id)
        if type(door) == 'table' and isFixtureLabel(door.label) then exports.kora_doorlock:removeDoor(id) end
    end)
end

-- Removes a leftover of this suite with the id; refuses to touch a real door.
local function clearStale(id)
    local stale = K.export('kora_doorlock', 'getDoor', id)
    if type(stale) ~= 'table' then return end
    if not isFixtureLabel(stale.label) then
        error(('A door with the id %s exists and is not an FFT fixture ("%s"); refusing to replace it')
            :format(id, tostring(stale.label)), 0)
    end
    local removed, err = exports.kora_doorlock:removeDoor(id)
    assert(removed == true, 'Could not remove the leftover FFT door ' .. id .. ': ' .. tostring(err))
end

local function leaf(index)
    local spare = SPARE_LEAVES[index]
    return {
        model = GetHashKey(FIXTURE_MODEL), heading = spare.heading,
        coords = { x = spare.coords.x, y = spare.coords.y, z = spare.coords.z },
    }
end

local function spareRaw(extra)
    local raw = leaf(1)
    raw.label, raw.distance = FIXTURE_LABEL, 2.5
    for key, value in pairs(extra or {}) do raw[key] = value end
    return raw
end

-- Creates a spare door with cleanup registered before the create call.
local function createSpare(ctx, id, extra)
    clearStale(id)
    ctx:cleanup(function() removeIfFixture(id) end)
    local raw = spareRaw(extra)
    raw.id = id
    local created = K.export('kora_doorlock', 'createDoor', raw)
    if created ~= id then
        error(('exports.kora_doorlock:createDoor refused the spare door %s (returned %s); is the doorlock database ready?')
            :format(id, tostring(created)), 0)
    end
    local door = K.export('kora_doorlock', 'getDoor', id)
    assert(type(door) == 'table', 'The spare door was created but getDoor does not return it')
    return door
end

local function current(ctx)
    local door = K.export('kora_doorlock', 'getDoor', chosen(ctx).id)
    assert(type(door) == 'table', 'getDoor no longer returns the chosen door ' .. chosen(ctx).id)
    return door
end

local function near(a, b) return math.abs(a - b) < 0.001 end

-- Restarts this scenario's record of state changes (after a setup step changed the door).
local function forgetAnnouncements(ctx)
    local list = K.captured(ctx, 'kora_doorlock:stateChanged')
    for index = #list, 1, -1 do list[index] = nil end
end

local function roleGrade(role)
    -- The same reading as kora_doorlock/shared/access.lua:313.
    local grade = type(role.grade) == 'table' and role.grade.level or role.grade or role.gradeLevel
    return tonumber(grade) or 0
end

local function refuseAce(ctx)
    for _, object in ipairs({ 'doorlock.' .. FIXTURE_ID, 'doorlock.' .. FIXTURE_LABEL }) do
        if aceAllowed(ctx.tester, object) then
            error('The tester holds the ACE ' .. object .. ', which opens the fixture door; this scenario needs a tester without it', 0)
        end
    end
end

-- A fixture at the real door, watched, restored and published, with the given access rule.
local function accessFixture(ctx, extra)
    local door = createFixture(ctx, extra)
    restoreAfterwards(ctx)
    watchChanges(ctx)
    publish(ctx, door.original)
    return door
end

local function grantWithHook(ctx, answer, options)
    local door, tester = chosen(ctx), ctx.tester
    local id = door.id
    local hookId = K.export('kora_doorlock', 'registerHook', 'doorAuthorization', function(payload)
        if type(payload) == 'table' and payload.source == tester and payload.doorId == id then return answer end
    end, options)
    assert(type(hookId) == 'number', 'registerHook did not return a hook id')
    ctx:cleanup(function() pcall(function() exports.kora_doorlock:removeHook(hookId) end) end)
    return hookId
end

-- ---------------------------------------------------------------------------
-- Server: creating doors
-- ---------------------------------------------------------------------------

-- Each case breaks one rule of DoorlockSchema.normalize (shared/schema.lua);
-- the line of the rule is noted. createDoor answers false for all of them
-- (server/main.lua:826-829).
local INVALID = {
    ['a blank label'] = function(raw) raw.label = '   ' end,                               -- :162-163
    ['a 97 character label'] = function(raw) raw.label = FIXTURE_LABEL .. string.rep('x', 97 - #FIXTURE_LABEL) end,
    ['no model'] = function(raw) raw.model = nil end,                                      -- :36-38
    ['model 0'] = function(raw) raw.model = 0 end,
    ['coordinates that are not numbers'] = function(raw) raw.coords = { x = 'west', y = -983.2, z = 30.8 } end, -- :17-19
    ['a 0.4 metre reach'] = function(raw) raw.distance = 0.4 end,                          -- :192-193
    ['a 21 metre reach'] = function(raw) raw.distance = 21 end,
    ['a negative auto-lock'] = function(raw) raw.autoLock = -1 end,                        -- :199
    ['an auto-lock over a day'] = function(raw) raw.autoLock = 86400001 end,
    ['a door rate of 11'] = function(raw) raw.doorRate = 11 end,                           -- :200-201
    ['a 129 character passcode'] = function(raw) raw.passcode = string.rep('9', 129) end,  -- :202-203
    ['a negative group grade'] = function(raw) raw.groups = { police = -1 } end,           -- :52
    ['groups that are not a table'] = function(raw) raw.groups = 'police' end,             -- :45
    ['33 groups'] = function(raw)                                                          -- :49
        raw.groups = {}
        for index = 1, 33 do raw.groups['fft-group-' .. index] = 0 end
    end,
    ['a character id that is a table'] = function(raw) raw.characters = { {} } end,       -- :64-65
    ['items with a gap'] = function(raw) raw.items = { [1] = 'lockpick', [3] = 'lockpick' } end, -- :99-100
    ['item metadata that holds a table'] = function(raw) raw.items = { { name = 'lockpick', metadata = { tier = {} } } } end, -- :89,107-108
    ['one leaf in a double door'] = function(raw) raw.doors = { leaf(1) } end,             -- :167-168
    ['three leaves in a double door'] = function(raw) raw.doors = { leaf(1), leaf(2), leaf(1) } end,
    ['an upper case category'] = function(raw) raw.category = 'Police' end,                -- :216
    ['an unknown lockpick difficulty'] = function(raw) raw.lockpickDifficulty = 'impossible' end, -- :142
    ['a lockpick pin count of 13'] = function(raw) raw.lockpickDifficulty = { pinCount = 13 } end, -- :127
}

K.step('the doorlock should refuse to create a door with {string}', 'server', function(ctx, case)
    local breakRule = assert(INVALID[case], 'No invalid door case named "' .. case .. '"')
    clearStale(SPARE_ID)
    ctx:cleanup(function() removeIfFixture(SPARE_ID) end)
    local raw = spareRaw({ id = SPARE_ID })
    breakRule(raw)
    ctx:equal(K.export('kora_doorlock', 'createDoor', raw), false, 'createDoor with ' .. case)
    ctx:equal(K.export('kora_doorlock', 'getDoor', SPARE_ID), false, 'getDoor after the refusal')
end)

K.step('the doorlock export creates a spare door with the requested id {string}', 'server', function(ctx, requested)
    for _, id in ipairs({ SPARE_ID, SLUG_ID }) do
        clearStale(id)
        ctx:cleanup(function() removeIfFixture(id) end)
    end
    local created = K.export('kora_doorlock', 'createDoor', spareRaw({ id = requested }))
    if type(created) == 'string' then ctx:cleanup(function() removeIfFixture(created) end) end
    ctx.state.createdId = created
end)

K.step('the spare door should have the id {string}', 'server', function(ctx, id)
    ctx:equal(ctx.state.createdId, id, 'Id returned by createDoor')
    local door = K.export('kora_doorlock', 'getDoor', id)
    assert(type(door) == 'table', 'getDoor does not return the door ' .. id)
    ctx:equal(door.label, FIXTURE_LABEL, 'Label of ' .. id)
end)

K.step('a spare doorlock door is available', 'server', function(ctx)
    choose(ctx, createSpare(ctx, SPARE_ID, { locked = true }))
end)

K.step('a spare doorlock door that locks itself after {int} milliseconds is available', 'server', function(ctx, delay)
    assert(delay >= 500 and delay <= 10000, 'Keep the auto-lock delay between 500 and 10000 ms')
    choose(ctx, createSpare(ctx, SPARE_ID, { locked = true, autoLock = delay })).autoLock = delay
end)

K.step('creating the spare door again unlocked should be refused', 'server', function(ctx)
    local before = current(ctx)
    ctx:equal(K.export('kora_doorlock', 'createDoor', spareRaw({ id = SPARE_ID, locked = false, distance = 3.0 })), false,
        'createDoor with an id in use')
    local after = current(ctx)
    ctx:equal(after.locked, before.locked, 'Lock state of the existing door')
    ctx:equal(after.distance, before.distance, 'Reach of the existing door')
end)

K.step('the doorlock export creates a spare door with loose access rules', 'server', function(ctx)
    -- Each value takes a normalising branch of shared/schema.lua: a padded upper
    -- case group with a fractional grade (:50-53), a repeated and a numeric
    -- character id (:63-72), an item given as a bare upper case name (:98,110),
    -- the legacy maxDistance (:192), state = 1 instead of locked (:207-208) and
    -- auto-lock in seconds through `autolock` (:195-198).
    choose(ctx, createSpare(ctx, SPARE_ID, {
        distance = false, maxDistance = 3, state = 1, autolock = 3,
        groups = { [' POLICE '] = 2.9 }, characters = { 'FFT0000A', 'FFT0000A', 42 }, items = 'LOCKPICK',
    }))
end)

K.step('the spare door should hold the normalised access rules', 'server', function(ctx)
    local door = current(ctx)
    ctx:equal(door.locked, true, 'state = 1 locks the door')
    ctx:equal(door.distance, 3, 'Reach from maxDistance')
    assert(type(door.groups) == 'table', 'The door has no groups')
    ctx:equal(door.groups.police, 2, 'Grade of the lower-cased, trimmed group')
    ctx:equal(door.groups[' POLICE '], nil, 'The raw group name is kept')
    assert(type(door.characters) == 'table', 'The door has no characters')
    ctx:equal(#door.characters, 2, 'Character ids after removing the repeat')
    ctx:equal(door.characters[1], 'FFT0000A', 'First character id')
    ctx:equal(door.characters[2], '42', 'Numeric character id as text')
    ctx:equal(door.citizenIds and #door.citizenIds, 2, 'Legacy citizenIds alias')
    assert(type(door.items) == 'table' and type(door.items[1]) == 'table', 'The door has no items')
    ctx:equal(#door.items, 1, 'Item count')
    ctx:equal(door.items[1].name, 'lockpick', 'Item name, lower-cased')
    ctx:equal(door.items[1].remove, nil, 'A bare item name is not consumed')
    ctx:equal(door.definition.autoLock, 3000, 'Auto-lock in milliseconds')
end)

K.step('the doorlock export creates a spare double door', 'server', function(ctx)
    choose(ctx, createSpare(ctx, SPARE_ID, { locked = true, model = false, coords = false, heading = false, doors = { leaf(1), leaf(2) } }))
end)

K.step('the spare double door should sit between its two leaves', 'server', function(ctx)
    local door = current(ctx)
    local a, b = SPARE_LEAVES[1].coords, SPARE_LEAVES[2].coords
    -- shared/schema.lua:175-176: a double door's coords are the midpoint.
    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        assert(near(door.coords[axis], (a[axis] + b[axis]) / 2),
            ('Door %s is %s, expected the midpoint %s'):format(axis, tostring(door.coords[axis]), tostring((a[axis] + b[axis]) / 2)))
    end
    local leaves = door.definition.doors
    assert(type(leaves) == 'table', 'The definition has no door leaves')
    ctx:equal(#leaves, 2, 'Door leaves')
    ctx:equal(door.definition.model, nil, 'A double door keeps no single model')
    for index = 1, 2 do
        ctx:equal(leaves[index].model, GetHashKey(FIXTURE_MODEL), 'Model of leaf ' .. index)
        assert(near(leaves[index].coords.y, SPARE_LEAVES[index].coords.y), 'Leaf ' .. index .. ' moved')
    end
end)

K.step('the chosen door should be found by a table holding its id', 'server', function(ctx)
    local door = K.export('kora_doorlock', 'getDoor', { id = chosen(ctx).id })
    assert(type(door) == 'table', 'getDoor({ id = ... }) did not return the door')
    ctx:equal(door.id, chosen(ctx).id, 'Door id')
    ctx:equal(K.export('kora_doorlock', 'getDoor', { id = 'fft_no_such_door' }), false, 'getDoor({ id = unknown })')
end)

-- ---------------------------------------------------------------------------
-- Server: lock state, the local setState event and auto-lock
-- ---------------------------------------------------------------------------

local LOCK_WORDS = { locked = true, unlocked = false }
local function lockWord(word) return assert(LOCK_WORDS[word], 'Use "locked" or "unlocked"') end

K.step('I watch the chosen door for state changes', 'server', function(ctx)
    restoreAfterwards(ctx)
    watchChanges(ctx)
end)

K.step('the doorlock export sets the chosen door to {int}', 'server', function(ctx, state)
    -- server/main.lua:789-792 accepts 0 and 1 as well as booleans.
    ctx:equal(K.export('kora_doorlock', 'setDoorState', chosen(ctx).id, state), true, 'setDoorState(' .. state .. ')')
end)

K.step('the kora_doorlock:setState event sets the chosen door to {int}', 'server', function(ctx, state)
    -- server/main.lua:894-896: a local server event for other resources.
    TriggerEvent('kora_doorlock:setState', chosen(ctx).id, state)
end)

K.step('the kora_doorlock:setState event with the state {string} should change nothing', 'server', function(ctx, state)
    local door = chosen(ctx)
    local before = K.export('kora_doorlock', 'getDoorState', door.id)
    local announcements = #K.captured(ctx, 'kora_doorlock:stateChanged')
    TriggerEvent('kora_doorlock:setState', door.id, state)
    Wait(500)
    ctx:equal(K.export('kora_doorlock', 'getDoorState', door.id), before, 'Lock state after setState with "' .. state .. '"')
    ctx:equal(#K.captured(ctx, 'kora_doorlock:stateChanged'), announcements, 'State change announcements')
end)

K.step('the chosen door should be {string}', 'server', function(ctx, word)
    local locked = lockWord(word)
    local door = current(ctx)
    ctx:equal(door.locked, locked, 'getDoor().locked')
    ctx:equal(door.state, locked and 1 or 0, 'getDoor().state')
    ctx:equal(K.export('kora_doorlock', 'getDoorState', door.id), locked, 'getDoorState')
end)

K.step('the doorlock should have announced the chosen door as {string}', 'server', function(ctx, word)
    announced(ctx, lockWord(word), nil)
end)

K.step('the chosen door should still be unlocked a moment later', 'server', function(ctx)
    Wait(500)
    ctx:equal(K.export('kora_doorlock', 'getDoorState', chosen(ctx).id), false, 'Lock state before the auto-lock delay')
end)

K.step('the chosen door should lock itself within {int} milliseconds', 'server', function(ctx, timeout)
    assert(timeout <= 14000, 'A step may wait at most 14000 ms')
    local door = chosen(ctx)
    ctx:waitUntil(function() return K.export('kora_doorlock', 'getDoorState', door.id) == true end,
        'The door did not lock itself', timeout)
    -- server/main.lua:234-236: the timer relocks with no player as the source.
    local last = K.captured(ctx, 'kora_doorlock:stateChanged')
    last = last[#last]
    assert(last, 'The auto-lock was not announced')
    ctx:equal(last[3], true, 'Last announcement locks the door')
    ctx:equal(last[1], nil, 'Source of the auto-lock announcement')
end)

-- ---------------------------------------------------------------------------
-- Server: editDoor
-- ---------------------------------------------------------------------------

K.step('the doorlock export edits the chosen door with:', 'server', function(ctx, argument)
    local patch = K.json(argument)
    assert(type(patch) == 'table', 'The edit must be a JSON object')
    -- Only renames that keep the fixture label prefix, so cleanup still recognises the door.
    local label = patch.name or patch.label
    if label ~= nil and label ~= '' then assert(isFixtureLabel(label), 'Renamed doors must keep the FFT fixture label prefix') end
    ctx.state.edited = K.export('kora_doorlock', 'editDoor', chosen(ctx).id, patch)
end)

K.step('the edit should have been accepted', 'server', function(ctx) ctx:equal(ctx.state.edited, true, 'editDoor result') end)
K.step('the edit should have been refused', 'server', function(ctx) ctx:equal(ctx.state.edited, false, 'editDoor result') end)

K.step('the chosen door should be labelled with the renamed fixture label', 'server', function(ctx)
    local door = current(ctx)
    ctx:equal(door.label, RENAMED_LABEL, 'Label after the edit')
    ctx:equal(door.name, RENAMED_LABEL, 'Legacy name alias')
    local found = K.export('kora_doorlock', 'getDoorFromName', RENAMED_LABEL)
    ctx:equal(type(found) == 'table' and found.id, door.id, 'getDoorFromName with the new label')
end)

K.step('the chosen door should still carry the fixture label', 'server', function(ctx)
    ctx:equal(current(ctx).label, FIXTURE_LABEL, 'Label')
end)

K.step('the chosen door should have a reach of {float} metres', 'server', function(ctx, reach)
    local door = current(ctx)
    assert(near(door.distance, reach), ('Reach is %s, expected %s'):format(tostring(door.distance), tostring(reach)))
    assert(near(door.maxDistance, reach), 'Legacy maxDistance does not match')
end)

K.step('the chosen door should auto-lock after {int} milliseconds', 'server', function(ctx, delay)
    ctx:equal(current(ctx).definition.autoLock, delay, 'definition.autoLock')
end)

K.step('the chosen door should not auto-lock', 'server', function(ctx)
    ctx:equal(current(ctx).definition.autoLock, nil, 'definition.autoLock')
end)

K.step('editing the chosen door with a patch that is not a table should be refused', 'server', function(ctx)
    ctx:equal(K.export('kora_doorlock', 'editDoor', chosen(ctx).id, 'locked'), false, 'editDoor with a string patch')
end)

K.step('editing the unknown door {string} should be refused', 'server', function(ctx, id)
    assert(K.export('kora_doorlock', 'getDoor', id) == false, 'A door with the id ' .. id .. ' exists; refusing to touch it')
    ctx:equal(K.export('kora_doorlock', 'editDoor', id, { distance = 3.0 }), false, 'editDoor for an unknown id')
    ctx:equal(K.export('kora_doorlock', 'getDoor', id), false, 'getDoor after the refused edit')
end)

-- ---------------------------------------------------------------------------
-- Server: removeDoor
-- ---------------------------------------------------------------------------

-- locales/en.json:117 err_door_not_configured, returned by server/main.lua:325.
K.step('removing the unknown door {string} should be refused with {string}', 'server', function(ctx, id, reason)
    assert(K.export('kora_doorlock', 'getDoor', id) == false, 'A door with the id ' .. id .. ' exists; refusing to touch it')
    local removed, err = K.export('kora_doorlock', 'removeDoor', id)
    ctx:equal(removed, false, 'removeDoor for an unknown id')
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('the doorlock export removes the chosen door', 'server', function(ctx)
    local removed, err = K.export('kora_doorlock', 'removeDoor', chosen(ctx).id)
    ctx:equal(removed, true, 'removeDoor result (' .. tostring(err) .. ')')
end)

K.step('removing the chosen door again should be refused with {string}', 'server', function(ctx, reason)
    local removed, err = K.export('kora_doorlock', 'removeDoor', chosen(ctx).id)
    ctx:equal(removed, false, 'Second removeDoor')
    ctx:equal(err, reason, 'Refusal reason')
end)

-- ---------------------------------------------------------------------------
-- Server: doorAuthorization hooks
-- ---------------------------------------------------------------------------

-- The assert messages of registerHook, server/main.lua:79-84.
local BAD_HOOKS = {
    ['an unsupported event'] = { 'doorOpened', true, nil, 'kora_doorlock only supports the doorAuthorization hook.' },
    ['a callback that is not callable'] = { 'doorAuthorization', 'not a function', nil, 'kora_doorlock hook callback must be callable.' },
    ['options that are not a table'] = { 'doorAuthorization', true, 'print', 'kora_doorlock hook options must be a table.' },
    ['an empty name filter'] = { 'doorAuthorization', true, { nameFilter = '' }, 'kora_doorlock hook nameFilter must be a non-empty Lua pattern.' },
    ['a broken name filter pattern'] = { 'doorAuthorization', true, { nameFilter = '[' }, 'kora_doorlock hook nameFilter is not a valid Lua pattern.' },
}

K.step('registering a doorlock hook with {string} should be refused', 'server', function(ctx, case)
    local bad = assert(BAD_HOOKS[case], 'No bad hook case named "' .. case .. '"')
    local callback = bad[2] == true and function() return nil end or bad[2]
    K.started('kora_doorlock')
    K.expectConsoleError(ctx, bad[4], 'kora_doorlock')
    local ok, result = pcall(function() return exports.kora_doorlock:registerHook(bad[1], callback, bad[3]) end)
    if ok then
        if type(result) == 'number' then ctx:cleanup(function() pcall(function() exports.kora_doorlock:removeHook(result) end) end) end
        error('registerHook accepted ' .. case .. ' (hook ' .. tostring(result) .. ')', 0)
    end
    assert(K.raisedWith(ctx, result, bad[4]), ('registerHook failed with "%s", expected "%s"'):format(tostring(result), bad[4]))
end)

K.step('a doorlock hook with a name filter can be removed exactly once', 'server', function(ctx)
    local hookId = K.export('kora_doorlock', 'registerHook', 'doorAuthorization', function() return nil end,
        { nameFilter = '^FFT test door' })
    assert(type(hookId) == 'number', 'registerHook did not return a hook id')
    ctx:cleanup(function() pcall(function() exports.kora_doorlock:removeHook(hookId) end) end)
    ctx:equal(K.export('kora_doorlock', 'removeHook', hookId), true, 'First removeHook')
    ctx:equal(K.export('kora_doorlock', 'removeHook', hookId), false, 'Second removeHook')
end)

-- ---------------------------------------------------------------------------
-- Server: door policies (server/main.lua:841-879)
-- ---------------------------------------------------------------------------

local function registerPolicy(ctx, callback)
    local id = chosen(ctx).id
    local ok, err = K.export('kora_doorlock', 'RegisterDoorPolicy', id, callback)
    -- Released before the door is removed; the removal also drops it (server/main.lua:338).
    ctx:cleanup(function() pcall(function() exports.kora_doorlock:ReleaseDoorPolicy(id) end) end)
    return ok, err
end

K.step('the doorlock export puts a door policy on the chosen door', 'server', function(ctx)
    local ok, err = registerPolicy(ctx, function() return false end)
    ctx:equal(ok, true, 'RegisterDoorPolicy result (' .. tostring(err) .. ')')
end)

K.step('the chosen door should be owned by the fft door policy', 'server', function(ctx)
    ctx:equal(current(ctx).definition.policyOwner, GetCurrentResourceName(), 'definition.policyOwner')
end)

K.step('the chosen door should have no door policy owner', 'server', function(ctx)
    ctx:equal(current(ctx).definition.policyOwner, nil, 'definition.policyOwner')
end)

K.step('registering a door policy on the unknown door {string} should be refused with {string}', 'server', function(ctx, id, reason)
    assert(K.export('kora_doorlock', 'getDoor', id) == false, 'A door with the id ' .. id .. ' exists; refusing to touch it')
    local ok, err = K.export('kora_doorlock', 'RegisterDoorPolicy', id, function() return true end)
    ctx:equal(ok, false, 'RegisterDoorPolicy for an unknown door')
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('registering a door policy that is not callable on the chosen door should be refused with {string}', 'server', function(ctx, reason)
    local ok, err = registerPolicy(ctx, 'allow')
    ctx:equal(ok, false, 'RegisterDoorPolicy with a string')
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('the doorlock export clears the door policy of the chosen door', 'server', function(ctx)
    local ok, err = K.export('kora_doorlock', 'ClearDoorPolicy', chosen(ctx).id)
    ctx:equal(ok, true, 'ClearDoorPolicy result (' .. tostring(err) .. ')')
end)

K.step('the doorlock export releases the door policy of the chosen door', 'server', function(ctx)
    local ok, err = K.export('kora_doorlock', 'ReleaseDoorPolicy', chosen(ctx).id)
    ctx:equal(ok, true, 'ReleaseDoorPolicy result (' .. tostring(err) .. ')')
end)

K.step('releasing the door policy of the chosen door should be refused with {string}', 'server', function(ctx, reason)
    local ok, err = K.export('kora_doorlock', 'ReleaseDoorPolicy', chosen(ctx).id)
    ctx:equal(ok, false, 'ReleaseDoorPolicy result')
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('clearing the door policy of the chosen door should be refused with {string}', 'server', function(ctx, reason)
    local ok, err = K.export('kora_doorlock', 'ClearDoorPolicy', chosen(ctx).id)
    ctx:equal(ok, false, 'ClearDoorPolicy result')
    ctx:equal(err, reason, 'Refusal reason')
end)

-- The first registration locks the door (server/main.lua:855); the scenario's
-- starting state becomes "locked" and that announcement is not counted.
local function policyGuards(ctx, allow)
    local door, tester = chosen(ctx), ctx.tester
    local id = door.id
    local ok, err = registerPolicy(ctx, function(source, doorId)
        return allow and source == tester and doorId == id
    end)
    ctx:equal(ok, true, 'RegisterDoorPolicy result (' .. tostring(err) .. ')')
    ctx:waitUntil(function() return exports.kora_doorlock:getDoorState(id) == true end, 'The new policy did not lock the door', 3000)
    door.original = true
    forgetAnnouncements(ctx)
    publish(ctx, true)
end

K.step('the chosen door is guarded by a door policy that lets me through', 'server', function(ctx) policyGuards(ctx, true) end)
K.step('the chosen door is guarded by a door policy that refuses me', 'server', function(ctx) policyGuards(ctx, false) end)

-- ---------------------------------------------------------------------------
-- Server: access fixtures at the real door (shared/access.lua, server/main.lua:140-191)
-- ---------------------------------------------------------------------------

K.step('a doorlock door for my job at my grade is available', 'server', function(ctx)
    local job = K.player(ctx).job
    assert(type(job) == 'table' and type(job.name) == 'string', 'The tester has no job')
    accessFixture(ctx, { groups = { [job.name] = roleGrade(job) } })
end)

K.step('a doorlock door for my job one grade above mine is available', 'server', function(ctx)
    local job = K.player(ctx).job
    assert(type(job) == 'table' and type(job.name) == 'string', 'The tester has no job')
    refuseAce(ctx)
    accessFixture(ctx, { groups = { [job.name] = roleGrade(job) + 1 } })
end)

K.step('a doorlock door for my gang at my grade is available', 'server', function(ctx)
    local gang = K.player(ctx).gang
    assert(type(gang) == 'table' and type(gang.name) == 'string', 'The tester has no gang')
    accessFixture(ctx, { groups = { [gang.name] = roleGrade(gang) } })
end)

K.step('a doorlock door for my character is available', 'server', function(ctx)
    local citizenid = K.player(ctx).citizenid
    assert(type(citizenid) == 'string' and citizenid ~= '', 'The tester has no citizenid')
    accessFixture(ctx, { characters = { citizenid } })
end)

K.step('a doorlock door for another character is available', 'server', function(ctx)
    local citizenid = K.player(ctx).citizenid
    assert(type(citizenid) == 'string' and citizenid ~= '', 'The tester has no citizenid')
    refuseAce(ctx)
    -- Built from the tester's own id, so it can never be the tester's.
    accessFixture(ctx, { characters = { citizenid .. '-FFT' } })
end)

K.step('a doorlock door opened by a {string} key is available', 'server', function(ctx, item)
    refuseAce(ctx)
    accessFixture(ctx, { items = { item } })
end)

K.step('a doorlock door that takes a {string} key is available', 'server', function(ctx, item)
    refuseAce(ctx)
    accessFixture(ctx, { items = { { name = item, remove = true } } })
end)

K.step('a doorlock door with the passcode {string} is available', 'server', function(ctx, passcode)
    refuseAce(ctx)
    accessFixture(ctx, { passcode = passcode }).passcode = true
end)

K.step('a doorlock door with no access rule is available', 'server', function(ctx)
    refuseAce(ctx)
    accessFixture(ctx)
end)

K.step('a doorlock door that can be picked is available locked', 'server', function(ctx)
    refuseAce(ctx)
    local door = createFixture(ctx, { lockpick = true, locked = true })
    restoreAfterwards(ctx)
    -- restoreAfterwards puts it back to locked; the door is removed in cleanup anyway.
    watchChanges(ctx)
    publish(ctx, door.original)
end)

K.step('a doorlock door that can be picked is available unlocked', 'server', function(ctx)
    accessFixture(ctx, { lockpick = true })
end)

K.step('a doorlock door without a prompt is available', 'server', function(ctx)
    accessFixture(ctx, { hideUi = true })
end)

K.step('a doorlock hook answers no for me at the chosen door', 'server', function(ctx)
    -- server/main.lua:70-71,178: only a true answer changes the decision.
    grantWithHook(ctx, false)
end)

K.step('a doorlock hook for another door would let me through', 'server', function(ctx)
    refuseAce(ctx)
    -- server/main.lua:63: a nameFilter that does not match the label skips the hook.
    grantWithHook(ctx, true, { nameFilter = '^FFT door that is not the fixture$' })
end)

-- ---------------------------------------------------------------------------
-- Client: definitions, compat exports, lockpick and the prompt
-- ---------------------------------------------------------------------------

K.step('my game should know the door {string}', 'client', function(ctx, id)
    ctx:waitUntil(function() return K.export('kora_doorlock', 'getDoorState', id) ~= nil end,
        'This client has no definition for door ' .. id, 5000)
end)

K.step('my game should forget the door {string}', 'client', function(ctx, id)
    ctx:waitUntil(function() return K.export('kora_doorlock', 'getDoorState', id) == nil end,
        'This client still knows the removed door ' .. id, 5000)
end)

-- qb-doorlock compatibility exports from kora_doorlock/client/main.lua:471-495,
-- registered with Kora.compat.provideExport (an __cfx_export_ handler).
local function compat(name)
    local ok, result = pcall(function() return exports['qb-doorlock'][name](exports['qb-doorlock']) end)
    if not ok then error('exports["qb-doorlock"]:' .. name .. ' failed: ' .. tostring(result), 0) end
    return result
end

K.step('the qb-doorlock compatibility exports should describe the chosen door', 'client', function(ctx)
    local door = published(ctx)
    local states = compat('GetDoorStates')
    assert(type(states) == 'table', 'GetDoorStates returned no table')
    ctx:equal(states[door.id], K.export('kora_doorlock', 'getDoorState', door.id), 'GetDoorStates entry')
    local list = compat('GetDoorList')
    assert(type(list) == 'table' and type(list[door.id]) == 'table', 'GetDoorList does not list ' .. door.id)
    ctx:equal(list[door.id].doorLabel, door.label, 'GetDoorList doorLabel')
    ctx:equal(list[door.id].entities, nil, 'GetDoorList exposes entity handles')
    local nearby = compat('GetNearbyDoors')
    ctx:equal(type(nearby) == 'table' and nearby[door.id], true, 'GetNearbyDoors entry')
    local closest = compat('GetClosestDoor')
    ctx:equal(type(closest) == 'table' and closest.id, door.id, 'GetClosestDoor id')
    assert(type(closest.distance) == 'number' and closest.distance <= 2.5, 'GetClosestDoor distance is not within reach')
end)

K.step('my game should not know the passcode of the chosen door', 'client', function(ctx)
    local door = published(ctx)
    local closest = K.export('kora_doorlock', 'getClosestDoor')
    assert(type(closest) == 'table' and closest.id == door.id, 'The chosen door is not the closest door')
    ctx:equal(closest.passcode, nil, 'Client definition passcode')
    -- The client re-normalises the definition (client/main.lua:240), which keeps
    -- neither the passcode nor hasPasscode, so only the absence is asserted.
    local listed = compat('GetDoorList')[door.id]
    ctx:equal(type(listed) == 'table' and listed.passcode, nil, 'GetDoorList passcode')
end)

K.step('picking the closest door should be refused at once', 'client', function(ctx)
    local door = published(ctx)
    ctx:equal(K.export('kora_doorlock', 'getClosestDoorId'), door.id, 'Closest door')
    ctx:equal(K.export('kora_doorlock', 'pickClosestDoor'), false, 'pickClosestDoor result')
end)

K.step('I try to pick the closest door', 'client', function(ctx)
    local door = published(ctx)
    ctx:equal(K.export('kora_doorlock', 'getClosestDoorId'), door.id, 'Closest door')
    ctx:equal(K.export('kora_doorlock', 'pickClosestDoor'), true, 'pickClosestDoor result')
end)

-- server/main.lua:678 passes the used key's name as the fourth argument of kora_doorlock:stateChanged.
K.step('the toggle of the chosen door should name the {string} key', 'server', function(ctx, item)
    local door = chosen(ctx)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, 'kora_doorlock:stateChanged')) do
            if record[2] == door.id and record[1] == ctx.tester and record[4] == item then return true end
        end
    end, 'No kora_doorlock:stateChanged from the tester naming the key ' .. item, 5000)
end)
