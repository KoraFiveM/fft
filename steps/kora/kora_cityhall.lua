-- kora_cityhall: City Hall kiosk (ped target, AppShell app qb-cityhall:kiosk).
-- No resource hook: the ped is a kora_target entity option, the kiosk is a
-- kora_lib AppShell app, and the results are items, cash and the job roster.
--
-- HAZARD: starter items are one-shot per character. Nothing here triggers
-- qb-cityhall:client:getIds or qb-cityhall:server:getIDs.
local K = FFT.kora
if not K then return end
K.feature('kora_cityhall')

-- Config.Cityhalls[1].licenses in kora_cityhall/shared/config.lua.
local LICENSES = { id_card = true, driver_license = true, weaponlicense = true }

-- Removes whatever a scenario buys, on top of the runner's own item reset.
K.step('any city hall {string} I buy is removed afterwards', 'server', function(ctx, license)
    assert(LICENSES[license], license .. ' is not sold at the City Hall')
    local core, tester = exports.kora_core, ctx.tester
    local before = K.count(ctx, license)
    ctx:cleanup(function()
        local extra = (core:getItemCount(tester, license) or 0) - before
        if extra > 0 then core:removeItem(tester, license, extra, nil, 'functional test cleanup') end
    end)
end)

local function rosterEntry(ctx, name)
    local view = K.export('kora_multijob', 'getRoster', ctx.tester)
    assert(type(view) == 'table' and type(view.jobs) == 'table', 'Job roster is unavailable')
    for _, job in ipairs(view.jobs) do if job.name == name then return job end end
end

-- Applying calls kora_multijob:addJob(src, job, 1), which has no undo in the
-- kiosk. This fixture requires the tester not to hold the job already, then
-- removes it from the roster and restores the previous active job afterwards.
K.step('any city hall job {string} I am given is withdrawn afterwards', 'server', function(ctx, name)
    K.started('kora_multijob')
    assert(not rosterEntry(ctx, name), 'The test character already holds ' .. name .. '; refusing to touch it')
    local core, tester = exports.kora_core, ctx.tester
    local before = K.player(ctx)
    local previous = before.job or {}
    assert(previous.name ~= name, 'The test character already works as ' .. name)
    local previousGrade = type(previous.grade) == 'table' and previous.grade.level or previous.grade
    local citizenid = before.citizenid
    ctx:cleanup(function()
        local current = core:getPlayerData(tester, { 'job' })
        if previous.name and type(current) == 'table' and current.name ~= previous.name then
            core:setJob(tester, previous.name, previousGrade)
            core:setJobDuty(tester, previous.onduty == true)
        end
        pcall(function() exports.kora_multijob:removeEmployeeJob(citizenid, name) end)
    end)
end)

K.step('the city hall should have added {string} to my jobs at grade {int}', 'server', function(ctx, name, grade)
    local job
    ctx:waitUntil(function() job = rosterEntry(ctx, name) return job end, 'City Hall did not add the job ' .. name, 5000)
    ctx:equal(job.level, grade, 'Grade of ' .. name)
end)

K.step('the city hall should not have added {string} to my jobs', 'server', function(ctx, name)
    Wait(1000)
    assert(not rosterEntry(ctx, name), 'City Hall added the job ' .. name)
end)

-- exports.kora_cityhall:AddCityJob has no removal counterpart, so only its
-- refusals are exercised: a job that is already offered, and a non-string name.
K.step('offering the job {string} at the city hall again should be refused', 'server', function(ctx, name)
    local ok, why = K.export('kora_cityhall', 'AddCityJob', name, { label = 'FFT' })
    ctx:equal(ok, false, 'AddCityJob result')
    ctx:equal(why, 'already added', 'AddCityJob reason')
end)
K.step('offering a job without a name at the city hall should be refused', 'server', function(ctx)
    local ok, why = K.export('kora_cityhall', 'AddCityJob', 42, { label = 'FFT' })
    ctx:equal(ok, false, 'AddCityJob result')
    ctx:equal(why, 'already added', 'AddCityJob reason')
end)

-- The kiosk can also be opened by the client event other resources use
-- (client/client.lua registers qb-cityhall:client:openCityhallMenu); it picks
-- the nearest City Hall and leaves the distance rule to the server.
K.step('I open the city hall kiosk away from the building', 'client', function()
    K.started('kora_cityhall')
    TriggerEvent('qb-cityhall:client:openCityhallMenu')
end)

-- ---------------------------------------------------------------------------
-- Round 3: kiosk contents, compat client events, server event validation,
-- roster limit and AddCityJob argument refusals.
-- ---------------------------------------------------------------------------

-- client/client.lua registers these three as aliases that open the kiosk of
-- the nearest City Hall (README: "Client events ... open the nearest hall").
local OPEN_EVENTS = { openCityhallMenu = true, openIdentityMenu = true, openJobMenu = true }
K.step('I open the city hall kiosk through the {string} client event', 'client', function(_, name)
    assert(OPEN_EVENTS[name], name .. ' is not a kora_cityhall open event')
    K.started('kora_cityhall')
    TriggerEvent('qb-cityhall:client:' .. name)
end)

-- The open app's navigation as kora_lib sent it (client/client.lua
-- buildNavigation: views 'identity' and 'jobs', each with one cards list).
-- kora_lib's hook summarises deep tables, so the card entries are counted,
-- not read.
local function kioskView(id)
    local payload = K.ui('app')
    assert(type(payload) == 'table' and type(payload.app) == 'table', 'The City Hall kiosk is not open')
    assert(payload.app.id == 'qb-cityhall:kiosk', 'The open app is not the City Hall kiosk: ' .. tostring(payload.app.id))
    for _, view in pairs(type(payload.app.navigation) == 'table' and payload.app.navigation or {}) do
        if type(view) == 'table' and view.id == id then return view end
    end
    error('The City Hall kiosk has no "' .. id .. '" view', 0)
end

local function kioskCards(view)
    local content = type(view.content) == 'table' and view.content or {}
    local block = type(content.blocks) == 'table' and content.blocks[1] or nil
    local items = type(block) == 'table' and block.items or nil
    assert(type(items) == 'table', 'The kiosk view has no card list')
    local count = 0
    for _ in pairs(items) do count = count + 1 end
    return count
end

-- Config.Cityhalls[1].licenses has 3 entries and Config.AvailableJobs 7
-- (kora_cityhall/shared/config.lua).
K.step('the city hall kiosk should list {int} documents and {int} jobs', 'client', function(ctx, documents, jobs)
    ctx:waitUntil(function() local app = K.uiState().app return app and app.id == 'qb-cityhall:kiosk' end,
        'The City Hall kiosk is not open')
    ctx:equal(kioskCards(kioskView('identity')), documents, 'Documents on the kiosk')
    ctx:equal(kioskCards(kioskView('jobs')), jobs, 'Jobs on the kiosk')
end)

-- Labels from kora_cityhall/locales/en.lua (menus.id_card, menus.job_center).
K.step('the city hall kiosk view {string} should be labelled {string}', 'client', function(_, id, label)
    local view = kioskView(id)
    assert(view.label == label, ('Kiosk view %s is labelled "%s", expected "%s"'):format(id, tostring(view.label), label))
end)

-- Server events. These are the events kora_cityhall's own client and stock
-- qb resources send (server/server.lua: purchaseID, the requestId alias and
-- ApplyJob); every check below is the server's own validation.
local REQUEST_ITEMS = { id_card = true, driver_license = true, weaponlicense = true, fft_no_such_license = true }
local APPLY_JOBS = { trucker = true, taxi = true, tow = true, news = true, garbage = true, bus = true, hotdog = true, police = true }

K.step('I send the stock city hall licence request for {string} at hall {int}', 'client', function(_, item, hall)
    assert(REQUEST_ITEMS[item], item .. ' is not a City Hall test licence')
    K.started('kora_cityhall')
    TriggerServerEvent('qb-cityhall:server:requestId', item, hall)
end)

K.step('I send the stock city hall licence request for {string} without a hall', 'client', function(_, item)
    assert(REQUEST_ITEMS[item], item .. ' is not a City Hall test licence')
    K.started('kora_cityhall')
    TriggerServerEvent('qb-cityhall:server:requestId', item, nil)
end)

K.step('I send the city hall purchase for {string} at hall {int}', 'client', function(_, item, hall)
    assert(REQUEST_ITEMS[item], item .. ' is not a City Hall test licence')
    K.started('kora_cityhall')
    TriggerServerEvent('qb-cityhall:server:purchaseID', hall, item)
end)

-- Stock shape ApplyJob(job, coords): the server ignores coords and resolves
-- the hall from the player's own server-side position.
K.step('I send the stock city hall job application for {string}', 'client', function(_, job)
    assert(APPLY_JOBS[job], job .. ' is not a City Hall test job')
    K.started('kora_cityhall')
    TriggerServerEvent('qb-cityhall:server:ApplyJob', job, GetEntityCoords(PlayerPedId()))
end)

K.step('I send a city hall job application for {string} at hall {int}', 'client', function(_, job, hall)
    assert(APPLY_JOBS[job], job .. ' is not a City Hall test job')
    K.started('kora_cityhall')
    TriggerServerEvent('qb-cityhall:server:ApplyJob', hall, job)
end)

-- kora_multijob refuses a new job once the roster holds Config.maxJobs = 4
-- jobs besides unemployed (kora_multijob/config.lua:2, server.lua addJob).
-- Fills the roster with real kora_core jobs the tester does not hold and
-- removes exactly those again.
local MAX_JOBS = 4
local FILLERS = { 'police', 'ambulance', 'mechanic', 'roadside', 'bodyshop', 'vineyard' }
K.step('my job roster is full without {string}', 'server', function(ctx, wanted)
    K.started('kora_multijob')
    local tester, citizenid = ctx.tester, K.player(ctx).citizenid
    local held, count = {}, 0
    for _, job in ipairs((K.export('kora_multijob', 'getRoster', tester) or {}).jobs or {}) do
        held[job.name] = true
        if job.name ~= 'unemployed' then count = count + 1 end
    end
    assert(not held[wanted], 'The test character already holds ' .. wanted)
    local added = {}
    ctx:cleanup(function()
        for _, name in ipairs(added) do pcall(function() exports.kora_multijob:removeEmployeeJob(citizenid, name) end) end
    end)
    for _, name in ipairs(FILLERS) do
        if count >= MAX_JOBS then break end
        if name ~= wanted and not held[name] then
            local ok, err = exports.kora_multijob:addJob(tester, name, 1)
            if not ok then error(('Could not add %s to the roster: %s'):format(name, tostring(err)), 0) end
            added[#added + 1] = name
            count = count + 1
        end
    end
    assert(count >= MAX_JOBS, 'Not enough filler jobs to fill the roster')
    local ok, why = exports.kora_multijob:addJob(tester, wanted, 1)
    if ok then
        pcall(function() exports.kora_multijob:removeEmployeeJob(citizenid, wanted) end)
        error('kora_multijob accepted a fifth job; the roster limit is not ' .. MAX_JOBS, 0)
    end
    ctx:equal(why, 'job roster is full', 'Roster limit reason')
end)

-- AddCityJob refuses any non-string name with 'already added'
-- (server/server.lua exports('AddCityJob')).
local NON_STRING = {
    number = function() return 7 end,
    table = function() return { 'taxi' } end,
    boolean = function() return true end,
    none = function() return nil end,
}
K.step('offering a job named by a {word} at the city hall should be refused', 'server', function(ctx, kind)
    local value = assert(NON_STRING[kind], 'Unknown value kind ' .. kind)()
    local ok, why = K.export('kora_cityhall', 'AddCityJob', value, { label = 'FFT' })
    ctx:equal(ok, false, 'AddCityJob result')
    ctx:equal(why, 'already added', 'AddCityJob reason')
end)
