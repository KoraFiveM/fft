-- kora_multijob: saved job roster (/multijob AppShell app + server exports).
-- No resource hook: the roster app is a kora_lib AppShell app, so kora_lib's
-- hook drives its actions, and exports.kora_multijob:getRoster is authoritative.
--
-- Every roster change made here goes through keepSaved first, which records the
-- tester's saved entry for that job (or its absence) and puts it back during
-- cleanup. Only the tester's own citizenid is ever passed to the employee
-- exports; refusal steps that name another character accept made-up FFT ids only.
local K = FFT.kora
if not K then return end
K.feature('kora_multijob')

local MAX_JOBS = 4 -- Config.maxJobs in kora_multijob/config.lua
-- Jobs used to fill the roster: kora_core/shared/jobs.lua plus qb-core upstream
-- jobs merged by kora_core/shared/upstream/merge.lua. Grade 1 exists for all.
local FILLERS = { 'mechanic', 'tow', 'bodyshop', 'roadside', 'ambulance', 'taxi', 'bus', 'trucker', 'garbage', 'news' }

local function roster(ctx)
    local view = K.export('kora_multijob', 'getRoster', ctx.tester)
    assert(type(view) == 'table' and type(view.jobs) == 'table', 'Job roster is unavailable')
    return view
end

local function find(view, name)
    for _, job in ipairs(view.jobs) do if job.name == name then return job end end
end

local function entry(ctx, name) return find(roster(ctx), name) end

-- Saved jobs other than the civilian fallback, the number Config.maxJobs limits.
local function savedCount(ctx)
    local total = 0
    for _, job in ipairs(roster(ctx).jobs) do if job.name ~= 'unemployed' then total = total + 1 end end
    return total
end

local function citizenid(ctx) return K.player(ctx).citizenid end

-- Records the tester's saved entry for `name` once per scenario and restores it
-- afterwards: the old grade is saved again, or a job that was not saved is
-- removed (never the active one: removeEmployeeJob would make the tester
-- unemployed, and the job fixture that set it restores it anyway).
local function keepSaved(ctx, name)
    ctx.state.multijobKept = ctx.state.multijobKept or {}
    if ctx.state.multijobKept[name] then return end
    ctx.state.multijobKept[name] = true
    local before = entry(ctx, name)
    local level = before and before.level
    local tester, cid = ctx.tester, citizenid(ctx)
    ctx:cleanup(function()
        local mj = exports.kora_multijob
        if level then
            pcall(function() mj:addJob(tester, name, level) end)
            return
        end
        local active = exports.kora_core:getPlayerData(tester, { 'job', 'name' })
        if active ~= name then pcall(function() mj:removeEmployeeJob(cid, name) end) end
    end)
end

local function madeUp(id)
    assert(id == '' or id:sub(1, 3) == 'FFT', 'Use a made-up FFT citizenid (or an empty one)')
end

-- ---------------------------------------------------------------------------
-- Roster contents
-- ---------------------------------------------------------------------------

K.step('my job roster should include {string}', 'server', function(ctx, name)
    ctx:waitUntil(function() return entry(ctx, name) end, 'Roster does not include ' .. name, 3000)
end)
K.step('my job roster should not include {string}', 'server', function(ctx, name)
    ctx:waitUntil(function() return not entry(ctx, name) end, 'Roster still includes ' .. name, 3000)
end)
K.step('my job roster should show {string} at grade {int}', 'server', function(ctx, name, grade)
    ctx:waitUntil(function() local job = entry(ctx, name) return job and job.level == grade end,
        ('Roster does not show %s at grade %d'):format(name, grade), 3000, function()
            local job = entry(ctx, name)
            return job and (' (it shows grade ' .. tostring(job.level) .. ')') or ' (it is not in the roster)'
        end)
end)
K.step('my job roster should mark {string} as the active job', 'server', function(ctx, name)
    ctx:waitUntil(function() return roster(ctx).active.name == name end,
        'Active roster job is ' .. tostring(roster(ctx).active.name), 3000)
end)
K.step('my job roster should say I am on duty', 'server', function(ctx)
    ctx:waitUntil(function() return roster(ctx).active.onDuty == true end, 'Roster reports me off duty', 3000)
end)
K.step('my job roster should say I am off duty', 'server', function(ctx)
    ctx:waitUntil(function() return roster(ctx).active.onDuty == false end, 'Roster reports me on duty', 3000)
end)

-- jobRecord()/view() in server.lua: labels and pay come from kora_core's job table.
K.step('my job roster should describe {string} as {string} grade {string} paying {int}', 'server', function(ctx, name, label, grade, pay)
    local job = assert(entry(ctx, name), 'Roster does not include ' .. name)
    ctx:equal(job.jobLabel, label, 'Job label of ' .. name)
    ctx:equal(job.gradeLabel, grade, 'Grade label of ' .. name)
    ctx:equal(job.pay, pay, 'Pay of ' .. name)
end)
K.step('my job roster should give {string} the icon {string}', 'server', function(ctx, name, icon)
    local job = assert(entry(ctx, name), 'Roster does not include ' .. name)
    ctx:equal(job.icon, icon, 'Icon of ' .. name)
end)
K.step('my job roster should mark {string} as duty-locked', 'server', function(ctx, name)
    local job = assert(entry(ctx, name), 'Roster does not include ' .. name)
    ctx:equal(job.dutyLocked, true, 'Duty lock of ' .. name)
end)
K.step('my job roster should not mark {string} as duty-locked', 'server', function(ctx, name)
    local job = assert(entry(ctx, name), 'Roster does not include ' .. name)
    ctx:equal(job.dutyLocked, false, 'Duty lock of ' .. name)
end)
K.step('my job roster should list jobs from the best paid down', 'server', function(ctx)
    local jobs = roster(ctx).jobs
    assert(#jobs >= 2, 'The roster needs two jobs to check its order')
    for index = 2, #jobs do
        assert(jobs[index - 1].pay >= jobs[index].pay, ('Roster lists %s ($%s) before %s ($%s)')
            :format(jobs[index - 1].name, tostring(jobs[index - 1].pay), jobs[index].name, tostring(jobs[index].pay)))
    end
end)

-- getRoster(citizenid) reads the cached roster; there is no online player
-- behind a string, so it reports no active job.
K.step('my job roster looked up by citizenid should include {string} with no active job', 'server', function(ctx, name)
    local view = K.export('kora_multijob', 'getRoster', citizenid(ctx))
    assert(type(view) == 'table' and type(view.jobs) == 'table', 'Roster by citizenid is unavailable')
    assert(find(view, name), 'Roster by citizenid does not include ' .. name)
    ctx:equal(view.active and view.active.name, nil, 'Active job of a roster looked up by citizenid')
end)

K.step('my job roster cache is dropped', 'server', function(ctx)
    ctx:equal(K.export('kora_multijob', 'invalidate', ctx.tester), true, 'invalidate result')
end)

K.step('my job grade should be {int}', 'server', function(ctx, grade)
    ctx:waitUntil(function()
        local job = K.player(ctx).job or {}
        return type(job.grade) == 'table' and job.grade.level == grade
    end, 'Job grade is not ' .. grade, 3000)
end)

-- ---------------------------------------------------------------------------
-- addJob
-- ---------------------------------------------------------------------------

K.step('my job roster also holds {string} at grade {int}', 'server', function(ctx, name, grade)
    keepSaved(ctx, name)
    local ok, err = K.export('kora_multijob', 'addJob', ctx.tester, name, grade)
    if not ok then error(('Could not add %s to the roster: %s'):format(name, tostring(err)), 0) end
end)
K.step('adding {string} at grade {int} to my job roster should be accepted', 'server', function(ctx, name, grade)
    keepSaved(ctx, name)
    local ok, err = K.export('kora_multijob', 'addJob', ctx.tester, name, grade)
    assert(ok == true, ('addJob refused %s grade %d: %s'):format(name, grade, tostring(err)))
end)
K.step('adding {string} at grade {int} to my job roster should be refused with {string}', 'server', function(ctx, name, grade, reason)
    keepSaved(ctx, name)
    local ok, err = K.export('kora_multijob', 'addJob', ctx.tester, name, grade)
    assert(not ok, ('addJob accepted %s grade %d'):format(name, grade))
    ctx:equal(err, reason, 'Refusal reason')
end)

-- Adds grade-1 filler jobs until the roster holds `limit` saved jobs and keeps
-- one filler that is not saved for the refusal step.
K.step('my job roster is filled to its limit of {int} saved jobs', 'server', function(ctx, limit)
    ctx:equal(limit, MAX_JOBS, 'Saved job limit (Config.maxJobs)')
    local view = roster(ctx)
    for _, name in ipairs(FILLERS) do
        if not find(view, name) then
            if savedCount(ctx) < limit then
                keepSaved(ctx, name)
                local ok, err = K.export('kora_multijob', 'addJob', ctx.tester, name, 1)
                if not ok then error(('Could not add filler job %s: %s'):format(name, tostring(err)), 0) end
            elseif not ctx.state.multijobSpare then
                ctx.state.multijobSpare = name
            end
        end
    end
    local saved = savedCount(ctx)
    assert(saved == limit, ('The roster holds %d saved jobs, expected %d'):format(saved, limit))
    assert(ctx.state.multijobSpare, 'Every filler job is already saved; no job is left to refuse')
end)
K.step('adding one more job to my job roster should be refused with {string}', 'server', function(ctx, reason)
    local name = assert(ctx.state.multijobSpare, 'Fill the roster first')
    keepSaved(ctx, name)
    local ok, err = K.export('kora_multijob', 'addJob', ctx.tester, name, 1)
    assert(not ok, 'addJob accepted ' .. name .. ' beyond the roster limit')
    ctx:equal(err, reason, 'Refusal reason')
    assert(not entry(ctx, name), name .. ' was saved beyond the roster limit')
end)

-- ---------------------------------------------------------------------------
-- getEmployees / setEmployeeJob / removeEmployeeJob
-- ---------------------------------------------------------------------------

K.step('the employee list for {string} should include me at grade {int}', 'server', function(ctx, name, grade)
    local rows = K.export('kora_multijob', 'getEmployees', name)
    assert(type(rows) == 'table', 'getEmployees returned ' .. tostring(rows))
    local cid = citizenid(ctx)
    for _, row in ipairs(rows) do
        if row.citizenid == cid then
            ctx:equal(row.level, grade, 'My grade in the employee list')
            assert(type(row.name) == 'string' and row.name ~= '', 'My employee row has no name')
            return
        end
    end
    error('The employee list for ' .. name .. ' does not include me', 0)
end)
K.step('the employee list for {string} should not include me', 'server', function(ctx, name)
    local rows = K.export('kora_multijob', 'getEmployees', name)
    assert(type(rows) == 'table', 'getEmployees returned ' .. tostring(rows))
    local cid = citizenid(ctx)
    for _, row in ipairs(rows) do assert(row.citizenid ~= cid, 'The employee list for ' .. name .. ' includes me') end
end)
K.step('the employee list for {string} should be sorted by name', 'server', function(_, name)
    local rows = K.export('kora_multijob', 'getEmployees', name)
    assert(type(rows) == 'table', 'getEmployees returned ' .. tostring(rows))
    for index = 2, #rows do
        assert(rows[index - 1].name <= rows[index].name, 'Employee list is not sorted by name at row ' .. index)
    end
end)
K.step('the employee list for {string} should be refused', 'server', function(ctx, name)
    local rows, why = K.export('kora_multijob', 'getEmployees', name)
    ctx:equal(rows, nil, 'Employee list for ' .. name)
    -- FiveM exports may drop values after a leading nil.
    if why ~= nil then ctx:equal(why, 'unknown job or job storage is still starting', 'Refusal reason') end
end)

K.step('I set my saved job {string} to grade {int} through the employee export', 'server', function(ctx, name, grade)
    keepSaved(ctx, name)
    local ok, err = K.export('kora_multijob', 'setEmployeeJob', citizenid(ctx), name, grade)
    assert(ok == true, 'setEmployeeJob refused: ' .. tostring(err))
end)
K.step('setting my saved job {string} to grade {int} should be refused with {string}', 'server', function(ctx, name, grade, reason)
    keepSaved(ctx, name)
    local ok, err = K.export('kora_multijob', 'setEmployeeJob', citizenid(ctx), name, grade)
    assert(not ok, ('setEmployeeJob accepted %s grade %d'):format(name, grade))
    ctx:equal(err, reason, 'Refusal reason')
end)
K.step('setting the job of citizen {string} to {string} at grade {int} should be refused with {string}', 'server', function(ctx, id, name, grade, reason)
    madeUp(id)
    local ok, err = K.export('kora_multijob', 'setEmployeeJob', id, name, grade)
    assert(not ok, 'setEmployeeJob accepted citizen "' .. id .. '"')
    ctx:equal(err, reason, 'Refusal reason')
end)

K.step('I remove my job {string} through the employee export', 'server', function(ctx, name)
    keepSaved(ctx, name)
    local ok, err = K.export('kora_multijob', 'removeEmployeeJob', citizenid(ctx), name)
    assert(ok == true, 'removeEmployeeJob refused: ' .. tostring(err))
end)
K.step('removing my job {string} through the employee export should be refused with {string}', 'server', function(ctx, name, reason)
    keepSaved(ctx, name)
    local ok, err = K.export('kora_multijob', 'removeEmployeeJob', citizenid(ctx), name)
    assert(not ok, 'removeEmployeeJob accepted ' .. name)
    ctx:equal(err, reason, 'Refusal reason')
end)
K.step('removing the job {string} of citizen {string} should be refused with {string}', 'server', function(ctx, name, id, reason)
    madeUp(id)
    local ok, err = K.export('kora_multijob', 'removeEmployeeJob', id, name)
    assert(not ok, 'removeEmployeeJob accepted citizen "' .. id .. '"')
    ctx:equal(err, reason, 'Refusal reason')
end)

-- ---------------------------------------------------------------------------
-- Admin commands /givejob and /removejob (server.lua, admin permission)
-- ---------------------------------------------------------------------------

-- Precondition, not a fixture: the commands are gated on kora_core's 'admin'.
K.step('I may manage job rosters', 'server', function(ctx)
    assert(exports.kora_core:hasPermission(ctx.tester, 'admin') == true,
        'The tester lacks the kora_core admin permission /givejob and /removejob require')
end)
-- Registers the restore of the tester's saved entry before a command changes it.
K.step('my saved {string} job is restored afterwards', 'server', function(ctx, name) keepSaved(ctx, name) end)

-- Runs "/<command> <my server id> <rest>"; the server handler receives the id.
K.step('I run the roster command {string} on myself with {string}', 'client', function(_, command, rest)
    assert(command == 'givejob' or command == 'removejob', 'Only /givejob and /removejob are supported')
    assert(#rest <= 100, 'Arguments are too long')
    ExecuteCommand(('%s %d %s'):format(command, GetPlayerServerId(PlayerId()), rest))
end)

-- ---------------------------------------------------------------------------
-- Roster app
-- ---------------------------------------------------------------------------

-- The "My jobs" navigation badge counts every roster entry (client.lua appDefinition).
local function badge(navigation)
    for _, view in ipairs(type(navigation) == 'table' and navigation or {}) do
        if type(view) == 'table' and view.id == 'roster' then return tonumber(view.badge) end
    end
end

K.step('I remember the job roster app count', 'client', function(ctx)
    local payload = K.ui('app')
    local count = badge(type(payload) == 'table' and type(payload.app) == 'table' and payload.app.navigation)
    ctx.state.multijobBadge = assert(count, 'The roster app has no job count')
end)
K.step('the job roster app count should have changed by {int}', 'client', function(ctx, delta)
    local before = assert(ctx.state.multijobBadge, 'Remember the roster app count first')
    local update = (ctx.state.appResult or {}).app
    local count = assert(badge(type(update) == 'table' and update.navigation), 'The last roster action returned no updated view')
    ctx:equal(count, before + delta, 'Roster app job count')
end)
