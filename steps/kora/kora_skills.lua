-- kora_skills: skill progression read model, exports and the /skills app.
-- No resource hook: the exports are authoritative and the panel is a kora_lib
-- AppShell app.
--
-- HAZARD: skill XP has no delete or decrease API, so nothing here may award
-- XP. The only addRep calls are ones server/main.lua refuses before it touches
-- the database (unknown skill, or an amount that is not a positive integer),
-- and the step checks that itself before calling the export.
local K = FFT.kora
if not K then return end
K.feature('kora_skills')

-- Config.skillOrder and Config.maxLevel in kora_skills/config.lua.
local SKILLS = { 'mining', 'smelting', 'fishing', 'crafting', 'cooking', 'metaldetecting', 'computing', 'hacking' }
local MAX_LEVEL = 99

local function known(skill)
    for _, name in ipairs(SKILLS) do if name == skill then return true end end
    return false
end

local function allSkills(ctx)
    local skills, err = K.export('kora_skills', 'getAllRep', ctx.tester)
    if type(skills) ~= 'table' then error('Skills are unavailable: ' .. tostring(err), 0) end
    return skills
end

local function xpSnapshot(ctx)
    local snapshot = {}
    for name, data in pairs(allSkills(ctx)) do snapshot[name] = type(data) == 'table' and data.xp or nil end
    return snapshot
end

K.step('my skill profile should list every configured skill', 'server', function(ctx)
    local skills = allSkills(ctx)
    local count = 0
    for _ in pairs(skills) do count = count + 1 end
    ctx:equal(count, #SKILLS, 'Number of skills')
    for _, name in ipairs(SKILLS) do
        local data = skills[name]
        assert(type(data) == 'table', 'Skill missing from the profile: ' .. name)
        ctx:equal(data.name, name, 'Skill name')
        ctx:equal(data.maxLevel, MAX_LEVEL, 'Max level of ' .. name)
        assert(math.type(data.level) == 'integer' and data.level >= 1 and data.level <= MAX_LEVEL,
            ('%s level out of range: %s'):format(name, tostring(data.level)))
        assert(type(data.xp) == 'number' and data.xp >= 0, name .. ' xp is not a non-negative number')
        assert(data.xp >= data.levelXp and data.xp <= data.nextLevelXp,
            ('%s xp %s is outside its level band %s-%s'):format(name, tostring(data.xp), tostring(data.levelXp), tostring(data.nextLevelXp)))
        assert(type(data.percent) == 'number' and data.percent >= 0 and data.percent <= 100, name .. ' percent out of range')
        ctx:equal(data.xpToNextLevel, math.max(0, data.nextLevelXp - data.xp), name .. ' xp to next level')
    end
end)

K.step('my skill {string} should be reported with the label {string}', 'server', function(ctx, skill, label)
    local data, err = K.export('kora_skills', 'getRep', ctx.tester, skill)
    if type(data) ~= 'table' then error('getRep failed: ' .. tostring(err), 0) end
    ctx:equal(data.label, label, 'Skill label')
    ctx:equal(data.xp, allSkills(ctx)[skill].xp, 'getRep and getAllRep xp')
end)

K.step('asking for my skill {string} should be refused with {string}', 'server', function(ctx, skill, reason)
    local data, err = K.export('kora_skills', 'getRep', ctx.tester, skill)
    ctx:equal(data, nil, 'Skill data')
    -- getRep returns nil, reason; FiveM exports drop values after a leading nil.
    if err ~= nil then ctx:equal(err, reason, 'Refusal reason') end
end)

K.step('my replicated skills should match my skill profile', 'server', function(ctx)
    local skills = allSkills(ctx)
    local replicated = K.export('kora_core', 'getPlayerData', ctx.tester, { 'skills' })
    assert(type(replicated) == 'table', 'PlayerData.skills is not published')
    for _, name in ipairs(SKILLS) do
        assert(type(replicated[name]) == 'table', 'PlayerData.skills is missing ' .. name)
        ctx:equal(replicated[name].xp, skills[name].xp, 'Replicated xp of ' .. name)
        ctx:equal(replicated[name].level, skills[name].level, 'Replicated level of ' .. name)
    end
end)

K.step('I should be at least level {int} in the skill {string}', 'server', function(ctx, level, skill)
    ctx:equal(K.export('kora_skills', 'isLevel', ctx.tester, skill, level), true, 'isLevel')
end)
K.step('I should not count as level {int} in the skill {string}', 'server', function(ctx, level, skill)
    ctx:equal(K.export('kora_skills', 'isLevel', ctx.tester, skill, level), false, 'isLevel')
end)

K.step('I remember my skill experience', 'server', function(ctx)
    ctx.state.skillXp = xpSnapshot(ctx)
end)
K.step('my skill experience should be unchanged', 'server', function(ctx)
    local before = assert(ctx.state.skillXp, 'Remember the skill experience first')
    local after = xpSnapshot(ctx)
    for _, name in ipairs(SKILLS) do ctx:equal(after[name], before[name], 'XP of ' .. name) end
end)

-- The amount is a string so the feature can express 0, negatives, fractions
-- and text. The step refuses to call addRep unless the request is one the
-- server rejects before any write.
K.step('a skill award of {string} to {string} should be refused with {string}', 'server', function(ctx, amountText, skill, reason)
    local amount = tonumber(amountText)
    local harmless = not known(skill) or not amount or amount % 1 ~= 0 or amount <= 0
    assert(harmless, 'This step never sends an award that could be accepted')
    local ok, err = K.export('kora_skills', 'addRep', ctx.tester, skill, amount or amountText)
    ctx:equal(ok, false, 'addRep result')
    ctx:equal(err, reason, 'Refusal reason')
end)

-- getSkillCheckOptions only widens a field the skill configures for that
-- minigame type, scaled by level, and returns the caller's other options as is.
-- Numbers are compared with a tolerance because they cross an export boundary.
local function same(a, b)
    return type(a) == 'number' and type(b) == 'number' and math.abs(a - b) < 0.0001
end
local function baseOptions()
    return { zoneSize = 0.2, tolerance = 0.1, speed = 1.0, timeLimit = 5000 }
end

K.step('the {string} skill should ease a {string} check only through {string}', 'server', function(ctx, skill, gameType, field)
    local base = baseOptions()
    assert(base[field], 'Unknown option field: ' .. field)
    local options, data = K.export('kora_skills', 'getSkillCheckOptions', ctx.tester, skill, gameType, baseOptions())
    assert(type(options) == 'table', 'No options returned')
    assert(type(data) == 'table' and data.name == skill, 'Skill data was not returned with the options')
    for key, value in pairs(base) do
        local got = options[key]
        if key == field and data.level > 1 then
            assert(type(got) == 'number' and got > value - 0.0001,
                ('%s was reduced from %s to %s'):format(key, tostring(value), tostring(got)))
        else
            assert(same(got, value), ('Option %s changed from %s to %s'):format(key, tostring(value), tostring(got)))
        end
    end
end)
K.step('the {string} skill should leave a {string} check unchanged', 'server', function(ctx, skill, gameType)
    local base = baseOptions()
    local options = K.export('kora_skills', 'getSkillCheckOptions', ctx.tester, skill, gameType, baseOptions())
    assert(type(options) == 'table', 'No options returned')
    for key, value in pairs(base) do
        assert(same(options[key], value), ('Option %s changed from %s to %s'):format(key, tostring(value), tostring(options[key])))
    end
end)

-- ---------------------------------------------------------------------------
-- Round 3: deeper coverage. Same hazard as above: every addRep call below is
-- one server/main.lua:158-167 refuses before addRepLocked (the only writer),
-- and each step proves that itself before calling the export.
-- ---------------------------------------------------------------------------

-- Labels from Config.skills in kora_skills/config.lua.
local LABELS = {
    mining = 'Mining', smelting = 'Smelting', fishing = 'Fishing', crafting = 'Crafting', cooking = 'Cooking',
    metaldetecting = 'Metal Detecting', computing = 'Computing', hacking = 'Hacking',
}

-- shared/curve.lua: xpForLevel[1] = 0, then floor(sum(floor(p + 300 * 2^(p / 7))) / 4).
local CURVE = { [1] = 0 }
do
    local accumulated = 0
    for level = 2, MAX_LEVEL do
        local previous = level - 1
        accumulated = accumulated + math.floor(previous + 300 * 2 ^ (previous / 7))
        CURVE[level] = math.floor(accumulated / 4)
    end
end

-- Config.skills[*].skillCheck (config.lua) and CHECK_BOUNDS (server/main.lua:56-67).
local MODIFIERS = {
    mining = { skillbar = { zoneSize = 0.14 }, lockpick = { tolerance = 0.05 } },
    fishing = { skillbar = { zoneSize = 0.10 } },
    crafting = { circuit = { nodeCount = -2 } },
    cooking = { skillbar = { zoneSize = 0.08 }, mash = { requiredPresses = -5 } },
    metaldetecting = { skillbar = { zoneSize = 0.10 } },
    computing = { circuit = { nodeCount = -3 }, hacking = { solutionsize = -1 } },
    hacking = { hacking = { solutionsize = -1 }, circuit = { nodeCount = -1 } },
}
local BOUNDS = {
    lockpick = { tolerance = { 0.03, 0.35 } },
    skillbar = { zoneSize = { 0.05, 0.6 } },
    circuit = { nodeCount = { 2, 8, true } },
    mash = { requiredPresses = { 3, 100, true } },
    hacking = { solutionsize = { 2, 10, true } },
}

local function skill(ctx, name)
    local data = allSkills(ctx)[name]
    assert(type(data) == 'table', 'Skill missing from the profile: ' .. tostring(name))
    return data
end

-- A source with no player behind it, for the refusal outlines. Never a real player.
local function unusedSource()
    for id = 60000, 60200 do
        if GetPlayerName(tostring(id)) == nil then return id end
    end
    error('No unused player source found in 60000-60200', 0)
end

local function sourceFor(ctx, text)
    if text == 'an unused player id' then return unusedSource() end
    local value = tonumber(text)
    if value == nil then return text end
    if value >= 1 and value % 1 == 0 then
        assert(value ~= ctx.tester and GetPlayerName(tostring(value)) == nil, 'Source ' .. text .. ' belongs to a player')
    end
    return value
end

K.step('asking for my skills without naming one should return my whole profile', 'server', function(ctx)
    local data, err = K.export('kora_skills', 'getRep', ctx.tester)
    assert(type(data) == 'table', 'getRep without a skill failed: ' .. tostring(err))
    local profile = allSkills(ctx)
    for _, name in ipairs(SKILLS) do
        assert(type(data[name]) == 'table', 'getRep without a skill is missing ' .. name)
        ctx:equal(data[name].xp, profile[name].xp, 'XP of ' .. name)
        ctx:equal(data[name].level, profile[name].level, 'Level of ' .. name)
    end
end)

-- server/main.lua:1-3 isSource and :34-37 playerSkills.
K.step('skill lookups for the source {string} should be refused with {string}', 'server', function(ctx, text, reason)
    local src = sourceFor(ctx, text)
    local all, allErr = K.export('kora_skills', 'getAllRep', src)
    ctx:equal(all, nil, 'getAllRep result')
    if allErr ~= nil then ctx:equal(allErr, reason, 'getAllRep refusal') end
    local one, oneErr = K.export('kora_skills', 'getRep', src, 'mining')
    ctx:equal(one, nil, 'getRep result')
    if oneErr ~= nil then ctx:equal(oneErr, reason, 'getRep refusal') end
    ctx:equal(K.export('kora_skills', 'isLevel', src, 'mining', 1), false, 'isLevel result')
    local options, data = K.export('kora_skills', 'getSkillCheckOptions', src, 'mining', 'skillbar', { zoneSize = 0.2 })
    assert(type(options) == 'table' and same(options.zoneSize, 0.2), 'Options were changed for a source with no skills')
    ctx:equal(data, nil, 'Skill data for a source with no skills')
end)

-- addRep (server/main.lua:158-178) for a source that is not a loaded player:
-- playerSkills refuses inside addRepLocked before KoraSkillsDatabase.addXp,
-- because there is no citizenid to write to.
K.step('a skill award of 1 to {string} for the source {string} should be refused with {string}', 'server', function(ctx, name, text, reason)
    local src = sourceFor(ctx, text)
    assert(src ~= ctx.tester, 'This step never awards the tester')
    assert(not (type(src) == 'number' and src >= 1 and src % 1 == 0 and exports.kora_core:getPlayer(src)),
        'Source has a loaded character; refusing to send an award')
    local ok, err = K.export('kora_skills', 'addRep', src, name, 1)
    ctx:equal(ok, false, 'addRep result')
    ctx:equal(err, reason, 'Refusal reason')
end)

-- isLevel (server/main.lua:108-113) runs the level through tonumber and refuses
-- anything that is not a whole number of at least 1.
K.step('my {string} level check against {string} should be {string}', 'server', function(ctx, name, level, expected)
    assert(expected == 'true' or expected == 'false', 'Expected true or false')
    ctx:equal(K.export('kora_skills', 'isLevel', ctx.tester, name, level), expected == 'true', 'isLevel(' .. level .. ')')
end)

K.step('I should count as exactly my current level in the skill {string}', 'server', function(ctx, name)
    local level = skill(ctx, name).level
    ctx:equal(K.export('kora_skills', 'isLevel', ctx.tester, name, level), true, 'isLevel at the current level')
    if level < MAX_LEVEL then
        ctx:equal(K.export('kora_skills', 'isLevel', ctx.tester, name, level + 1), false, 'isLevel one level above')
    end
end)

-- KoraSkills.makeSkill (shared/curve.lua) checked against an independent copy of the curve.
K.step('my {string} progress should follow the experience curve', 'server', function(ctx, name)
    local data = skill(ctx, name)
    local xp = data.xp
    assert(math.type(xp) == 'integer' and xp >= 0 and xp <= CURVE[MAX_LEVEL], name .. ' xp is outside the curve: ' .. tostring(xp))
    local level = 1
    while level < MAX_LEVEL and xp >= CURVE[level + 1] do level = level + 1 end
    ctx:equal(data.level, level, name .. ' level for ' .. xp .. ' xp')
    ctx:equal(data.levelXp, CURVE[level], name .. ' level start xp')
    local nextXp = level < MAX_LEVEL and CURVE[level + 1] or CURVE[MAX_LEVEL]
    ctx:equal(data.nextLevelXp, nextXp, name .. ' next level xp')
    local percent = level == MAX_LEVEL and 100 or math.floor((xp - CURVE[level]) / (nextXp - CURVE[level]) * 100)
    ctx:equal(data.percent, percent, name .. ' percent')
    ctx:equal(data.xpToNextLevel, math.max(0, nextXp - xp), name .. ' xp to next level')
    ctx:equal(data.label, LABELS[name], name .. ' label')
end)

-- GetSkillsData (config.lua, shared export): { [name] = label }.
K.step('the skill catalogue should name {string} as {string}', 'server', function(ctx, name, label)
    local catalogue = K.export('kora_skills', 'GetSkillsData')
    assert(type(catalogue) == 'table', 'GetSkillsData returned no table')
    ctx:equal(catalogue[name], label, 'Catalogue label of ' .. name)
end)
K.step('the skill catalogue should list exactly the configured skills', 'server', function(ctx)
    local catalogue = K.export('kora_skills', 'GetSkillsData')
    assert(type(catalogue) == 'table', 'GetSkillsData returned no table')
    local count = 0
    for name in pairs(catalogue) do
        count = count + 1
        assert(known(name), 'Catalogue lists an unconfigured skill: ' .. tostring(name))
    end
    ctx:equal(count, #SKILLS, 'Catalogue size')
end)

-- server/main.lua:69-85: result = clamp(base + delta * (level - 1) / 98), floored for integer fields.
K.step('the {string} skill should scale a {string} check with {string} of {float} by its configured amount', 'server', function(ctx, name, gameType, field, base)
    local delta = assert(MODIFIERS[name] and MODIFIERS[name][gameType] and MODIFIERS[name][gameType][field],
        ('%s does not configure %s for %s'):format(name, field, gameType))
    local bound = assert(BOUNDS[gameType] and BOUNDS[gameType][field], 'No bounds for ' .. field)
    local options, data = K.export('kora_skills', 'getSkillCheckOptions', ctx.tester, name, gameType, { [field] = base, speed = 1.0 })
    assert(type(options) == 'table' and type(data) == 'table', 'No options or skill data returned')
    local expected = math.max(bound[1], math.min(bound[2], base + delta * (data.level - 1) / (MAX_LEVEL - 1)))
    if bound[3] then expected = math.floor(expected) end
    assert(same(options[field], expected), ('%s at level %d: got %s, expected %s'):format(field, data.level, tostring(options[field]), tostring(expected)))
    assert(same(options.speed, 1.0), 'An unconfigured field changed: speed = ' .. tostring(options.speed))
end)

K.step('the {string} skill should keep a text {string} and leave a missing one unset in a {string} check', 'server', function(ctx, name, field, gameType)
    local text = K.export('kora_skills', 'getSkillCheckOptions', ctx.tester, name, gameType, { [field] = 'wide' })
    assert(type(text) == 'table', 'No options returned')
    ctx:equal(text[field], 'wide', 'Text option value')
    local missing = K.export('kora_skills', 'getSkillCheckOptions', ctx.tester, name, gameType, { speed = 1.0 })
    assert(type(missing) == 'table', 'No options returned')
    ctx:equal(missing[field], nil, 'Missing option value')
end)

K.step('the {string} skill should hand back a {string} check unchanged with no skill data', 'server', function(ctx, name, gameType)
    local options, data = K.export('kora_skills', 'getSkillCheckOptions', ctx.tester, name, gameType, baseOptions())
    assert(type(options) == 'table', 'No options returned')
    for key, value in pairs(baseOptions()) do
        assert(same(options[key], value), ('Option %s changed from %s to %s'):format(key, tostring(value), tostring(options[key])))
    end
    ctx:equal(data, nil, 'Skill data for ' .. name)
end)

-- addRep with a location (server/main.lua:115-128, 164-167). The location kinds:
--   'an empty table', 'a text', 'text coordinates': refused by the type check
--   (line 116) before distance is read, whatever the config says;
--   'a point 3000 metres away' / 'a vector 3000 metres away': the step measures
--   the tester's server-side ped against the point and only sends the award when
--   it is far outside the requested radius (tonumber(distance) or 5.0, line 120),
--   so the award can only be refused.
local function awardLocation(ctx, kind)
    if kind == 'an empty table' then return {}, false end
    if kind == 'a text' then return 'here', false end
    if kind == 'text coordinates' then return { x = '1.0', y = 2.0, z = 3.0 }, false end
    local ped = GetPlayerPed(ctx.tester)
    assert(ped and ped ~= 0, 'Tester has no server-side ped')
    local at = GetEntityCoords(ped)
    if kind == 'a point 3000 metres away' then return { x = at.x + 3000.0, y = at.y, z = at.z }, true end
    if kind == 'a vector 3000 metres away' then return vector3(at.x + 3000.0, at.y, at.z), true end
    error('Unknown award location kind: ' .. tostring(kind), 0)
end

K.step('a skill award of {string} to {string} at {string} within {string} should be refused with {string}', 'server', function(ctx, amountText, name, kind, distanceText, reason)
    local amount = tonumber(amountText)
    local location, far = awardLocation(ctx, kind)
    local distance = distanceText ~= 'default' and (tonumber(distanceText) or distanceText) or nil
    local badAmount = not known(name) or not amount or amount % 1 ~= 0 or amount <= 0
    local harmless = badAmount or not far
    if not harmless then
        local radius = tonumber(distance) or 5.0
        local at = GetEntityCoords(GetPlayerPed(ctx.tester))
        local gap = #(vector3(location.x, location.y, location.z) - at)
        harmless = radius <= 0 or radius > 1000 or gap > radius + 100.0
    end
    assert(harmless, 'This step never sends an award that could be accepted')
    local ok, err = K.export('kora_skills', 'addRep', ctx.tester, name, amount or amountText, location, distance)
    ctx:equal(ok, false, 'addRep result')
    ctx:equal(err, reason, 'Refusal reason')
end)

-- Legacy migration (server/main.lua:8-31, server/database.lua importLegacy):
-- the /skills callback re-reads the profile and removes metadata.skills. The
-- blob carries no experience, and importLegacy only inserts xp > 0, so it can
-- never write experience even if the profile marker were missing.
K.step('my metadata holds a legacy skills blob with no experience', 'server', function(ctx)
    local core, tester = exports.kora_core, ctx.tester
    local original = core:getMetaData(tester, 'skills')
    local ok, err = core:setMetaData(tester, 'skills', { mining = { xp = 0, level = 1 } })
    if ok == false then error('Could not set metadata skills: ' .. tostring(err), 0) end
    ctx:cleanup(function() core:setMetaData(tester, 'skills', original) end)
    assert(type(core:getMetaData(tester, 'skills')) == 'table', 'The legacy blob was not stored')
end)
K.step('my legacy skills metadata should have been removed', 'server', function(ctx)
    ctx:waitUntil(function() return exports.kora_core:getMetaData(ctx.tester, 'skills') == nil end,
        'metadata.skills is still present after the skills panel loaded', 5000)
end)

-- ---------------------------------------------------------------------------
-- Client: the panel and the client exports (client/main.lua)
-- ---------------------------------------------------------------------------

local function panel()
    local payload = K.ui('app')
    assert(type(payload) == 'table' and type(payload.app) == 'table', 'No app payload is available')
    return payload.app
end

local function view(app, id)
    for _, entry in pairs(type(app.navigation) == 'table' and app.navigation or {}) do
        if type(entry) == 'table' and entry.id == id then return entry end
    end
    error('The panel has no view ' .. id, 0)
end

local function blockById(entry, key, value)
    local blocks = type(entry.content) == 'table' and entry.content.blocks or {}
    for _, block in pairs(blocks) do
        if type(block) == 'table' and block[key] == value then return block end
    end
    error(('View %s has no block with %s = %s'):format(tostring(entry.id), key, value), 0)
end

local function count(list)
    local n = 0
    for key in pairs(type(list) == 'table' and list or {}) do if key ~= '...' then n = n + 1 end end
    return n
end

-- exports('open', open): Kora.nui.openApp may wait for the panel to close, so it runs in its own thread.
K.step('I open the skills panel through its export', 'client', function()
    K.started('kora_skills')
    CreateThread(function() exports.kora_skills:open() end)
end)

-- client/main.lua appDefinition: Overview (stats + graph) and Details (table), one entry per skill.
K.step('the skills panel should show every configured skill', 'client', function(ctx)
    ctx:waitUntil(function() local app = K.uiState().app return app and app.id == 'kora_skills:progression' end,
        'The skills panel is not open')
    local app = panel()
    ctx:equal(app.title, 'Skills', 'Panel title')
    ctx:equal(app.footer, 'Progress is saved with this character.', 'Panel footer')
    local overview = view(app, 'overview')
    ctx:equal(overview.content.title, 'Your progression', 'Overview title')
    ctx:equal(count(blockById(overview, 'type', 'stats').items), 3, 'Overview stats')
    ctx:equal(count(blockById(overview, 'id', 'skill-graph').items), #SKILLS, 'Experience graph entries')
    local details = view(app, 'details')
    local tableBlock = blockById(details, 'id', 'skills-table')
    ctx:equal(count(tableBlock.rows), #SKILLS, 'Skill table rows')
    ctx:equal(count(tableBlock.columns), 4, 'Skill table columns')
end)

local function clientSkills()
    local all = exports.kora_skills:getAllRep()
    assert(type(all) == 'table', 'Client getAllRep returned no table')
    return all
end

K.step('the client skill exports should mirror my replicated skills', 'client', function(ctx)
    K.started('kora_skills')
    local replicated = exports.kora_core:getPlayerData({ 'skills' })
    assert(type(replicated) == 'table', 'PlayerData.skills is not replicated to the client')
    local all = clientSkills()
    for _, name in ipairs(SKILLS) do
        assert(type(all[name]) == 'table', 'Client getAllRep is missing ' .. name)
        ctx:equal(all[name].xp, replicated[name].xp, 'Client xp of ' .. name)
        local one = exports.kora_skills:getRep(name)
        assert(type(one) == 'table', 'Client getRep returned nothing for ' .. name)
        ctx:equal(one.level, all[name].level, 'Client getRep level of ' .. name)
    end
    local whole = exports.kora_skills:getRep()
    assert(type(whole) == 'table' and type(whole.mining) == 'table', 'Client getRep without a skill is not the whole profile')
    ctx:equal(exports.kora_skills:getRep('fft_no_such_skill'), nil, 'Client getRep for an unknown skill')
end)

K.step('the client level check for {string} against {string} should be {string}', 'client', function(ctx, name, level, expected)
    assert(expected == 'true' or expected == 'false', 'Expected true or false')
    local value = level ~= 'nothing' and (tonumber(level) or level) or nil
    ctx:equal(exports.kora_skills:isLevel(name, value), expected == 'true', 'Client isLevel(' .. level .. ')')
end)

-- client/main.lua getSkillCheckOptions: same ratio as the server, without the clamp.
K.step('the client should scale a {string} check with {string} of {float} for the skill {string}', 'client', function(ctx, gameType, field, base, name)
    local delta = assert(MODIFIERS[name] and MODIFIERS[name][gameType] and MODIFIERS[name][gameType][field], 'Not configured')
    local data = clientSkills()[name]
    assert(type(data) == 'table', 'No client data for ' .. name)
    local options = exports.kora_skills:getSkillCheckOptions(name, gameType, { [field] = base })
    local expected = base + delta * (data.level - 1) / (MAX_LEVEL - 1)
    assert(type(options) == 'table' and same(options[field], expected),
        ('%s: got %s, expected %s'):format(field, tostring(options and options[field]), tostring(expected)))
    local unknown = exports.kora_skills:getSkillCheckOptions('fft_no_such_skill', gameType, { [field] = base })
    assert(type(unknown) == 'table' and same(unknown[field], base), 'Unknown skill changed the options')
end)
