-- kora_jobcreator: admin-built businesses, exercised read-only against the
-- shipped Burger Shot seed (shared/businesses/burgershot.lua).
--
-- Nothing here creates, edits or deletes a business: every such change is
-- broadcast to all clients, written to the permanent business log, and a
-- deleted seed leaves a marker that stops it from ever being re-seeded. The
-- seed is first-boot only, so an admin may have changed or removed it; the
-- "unchanged" step below turns that into a readable precondition failure
-- instead of a scenario that stands in the wrong place.
-- kora_jobcreator has no FFT hook: its exports, the /jobcreator command and
-- kora_lib's surfaces are enough.
local K = FFT.kora
if not K then return end
K.feature('kora_jobcreator')

local RESOURCE = 'kora_jobcreator'
local SEED = 'burgershot'
-- shared/businesses/burgershot.lua
local PERIMETER = { x = -1193.0, y = -893.0, z = 13.9, radius = 22.0 }
local GRILL = { x = -1197.0, y = -900.5, z = 13.9 }

-- ---------------------------------------------------------------------------
-- Server: registry exports
-- ---------------------------------------------------------------------------

local function seedBusiness()
    local business = K.export(RESOURCE, 'getBusiness', SEED)
    if type(business) ~= 'table' then
        error('The Burger Shot seed business does not exist on this server (deleted in-game?)', 0)
    end
    return business
end

local function findModule(business, moduleType, label)
    for _, module in ipairs(business.modules or {}) do
        if module.moduleType == moduleType and (label == nil or module.label == label) then return module end
    end
end

local function sameSpot(coords, expected)
    return type(coords) == 'table' and math.abs((tonumber(coords.x) or 0) - expected.x) < 0.05
        and math.abs((tonumber(coords.y) or 0) - expected.y) < 0.05
        and math.abs((tonumber(coords.z) or 0) - expected.z) < 0.05
end

K.step('the Burger Shot seed business is registered', 'server', function()
    local business = seedBusiness()
    assert(business.id == SEED, 'Business id is ' .. tostring(business.id))
    assert(type(business.job) == 'string' and business.job ~= '', 'The business has no job')
    assert(type(business.modules) == 'table' and #business.modules > 0, 'The business has no modules')
    assert(findModule(business, 'Zone'), 'The business has no perimeter zone')
end)

-- Precondition for every scenario that stands inside the seed's zones.
K.step('the Burger Shot seed business is unchanged', 'server', function()
    local business = seedBusiness()
    assert(business.job == SEED, 'The seed business now uses job ' .. tostring(business.job))
    local zone = findModule(business, 'Zone')
    assert(zone and zone.zoneType == 'sphere' and sameSpot(zone.coords, PERIMETER)
        and math.abs((tonumber(zone.radius) or 0) - PERIMETER.radius) < 0.05 and zone.controlDuty ~= false,
        'The seed perimeter was edited in-game; these scenarios only know the shipped layout')
    local grill = findModule(business, 'Crafting', 'Grill')
    assert(grill and grill.zoneType == 'box' and sameSpot(grill.coords, GRILL),
        'The seed Grill bench was edited in-game; these scenarios only know the shipped layout')
end)

K.step('the business directory should list Burger Shot under its job', 'server', function()
    local business = seedBusiness()
    local all = K.export(RESOURCE, 'getBusinesses')
    assert(type(all) == 'table', 'getBusinesses did not return a table')
    local listed = false
    for key, entry in pairs(all) do
        if key == SEED or (type(entry) == 'table' and entry.id == SEED) then listed = true end
    end
    assert(listed, 'getBusinesses does not include the seed business')
    local byJob = K.export(RESOURCE, 'getBusinessesByJob', business.job)
    local found = false
    for _, id in ipairs(type(byJob) == 'table' and byJob or {}) do if id == SEED then found = true end end
    assert(found, 'getBusinessesByJob does not return the seed business for job ' .. tostring(business.job))
end)

K.step('the business registry should not know {string}', 'server', function(_, id)
    assert(K.export(RESOURCE, 'getBusiness', id) == nil, 'getBusiness returned a business for ' .. id)
    local byJob = K.export(RESOURCE, 'getBusinessesByJob', id)
    assert(type(byJob) == 'table' and #byJob == 0, 'getBusinessesByJob returned businesses for ' .. id)
end)

-- Only ever called with an id that does not exist: a successful call writes a
-- permanent row to the business log.
K.step('a business log entry for the unknown business {string} should be refused', 'server', function(_, id)
    assert(K.export(RESOURCE, 'getBusiness', id) == nil, id .. ' is a real business; refusing to write to its log')
    local ok, reason = K.export(RESOURCE, 'recordBusinessLog', id, 'admin', 'functional test', 0)
    assert(ok == false, 'recordBusinessLog accepted an unknown business')
    assert(reason == 'unknown business', 'Refusal reason is ' .. tostring(reason))
end)

-- /jobcreator opens for admins whatever their job, so the "does not manage"
-- scenario only means something for a tester without that permission.
--
-- This is a precondition, not a fixture, and deliberately so: the tester's
-- admin cannot be taken away for one scenario from here.
--   * On the stock server.cfg it comes from `group.admin`, the same group that
--     grants `fft.use`; removing the tester from it stops the run, and fft may
--     not run add_principal / remove_principal anyway.
--   * exports.kora_core:removePermission only removes the
--     `identifier.<primary> kora_core.<level>` principal that addPermission
--     adds, which is one of several routes (named below when they apply).
--   * The client caches the answer: client/main.lua hydrate() asks the server
--     once at resource start and client/creator.lua Creator.open reads that
--     cached flag, so an ACL change mid-session would not reach /jobcreator
--     without restarting kora_jobcreator on the client.
-- Run this scenario with a tester who holds `fft.use` but none of the ACEs
-- kora_lib's hasPermission accepts for Config.adminPermission ('admin').
local ADMIN_ACES = { 'kora_core.admin', 'group.admin', 'command.admin' }

K.step('I am not a job creator admin', 'server', function(ctx)
    local admin = exports.kora_core:hasPermission(ctx.tester, 'admin') == true -- Config.adminPermission
    if not admin then return end
    local routes = {}
    for _, object in ipairs(ADMIN_ACES) do
        local allowed = IsPlayerAceAllowed(ctx.tester, object)
        if allowed == true or allowed == 1 then routes[#routes + 1] = object end
    end
    error(('The tester has the admin permission (%s), so /jobcreator always opens; this scenario needs a tester '
        .. 'with fft.use who is not an admin, connected that way since kora_jobcreator last started on their client')
        :format(#routes > 0 and ('ACE ' .. table.concat(routes, ', ')) or 'through a route this step does not know'), 0)
end)

-- ---------------------------------------------------------------------------
-- Server: staff presence (server/staff.lua)
-- ---------------------------------------------------------------------------

local function staffPresent()
    local counts = K.export(RESOURCE, 'getStaffCounts')
    return type(counts) == 'table' and tonumber(counts[SEED]) or 0
end

K.step('I remember how many Burger Shot staff are present', 'server', function(ctx)
    ctx.state.jobcreatorStaff = staffPresent()
end)
K.step('one more Burger Shot staff member should be present', 'server', function(ctx)
    local before = assert(ctx.state.jobcreatorStaff, 'Remember the staff count first')
    ctx:waitUntil(function() return staffPresent() == before + 1 end,
        ('Staff present: %d, expected %d'):format(staffPresent(), before + 1), 8000)
end)
K.step('the Burger Shot staff count should be back to what it was', 'server', function(ctx)
    local before = assert(ctx.state.jobcreatorStaff, 'Remember the staff count first')
    -- Either the client's leave callback or the server's 5 s prune removes the tester.
    ctx:waitUntil(function() return staffPresent() == before end,
        ('Staff present: %d, expected %d'):format(staffPresent(), before), 10000)
end)
K.step('the Burger Shot staff count should not have changed', 'server', function(ctx)
    local before = assert(ctx.state.jobcreatorStaff, 'Remember the staff count first')
    Wait(2500)
    ctx:equal(staffPresent(), before, 'Burger Shot staff present')
end)

-- ---------------------------------------------------------------------------
-- Client: standing in the seed's zones
-- ---------------------------------------------------------------------------

-- The ped is held in place rather than dropped onto the floor: the zones are
-- plain coordinate tests, and holding it keeps these steps independent of
-- which Burger Shot interior (if any) the server streams.
local function hold(ctx, x, y, z)
    if not ctx.state.jobcreatorHeld then
        ctx.state.jobcreatorHeld = true
        K.teleport(ctx, PERIMETER.x, PERIMETER.y, PERIMETER.z) -- records the origin and restores it afterwards
        ctx:cleanup(function() FreezeEntityPosition(PlayerPedId(), false) end)
    end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
end

K.step('I stand inside the Burger Shot perimeter', 'client', function(ctx)
    hold(ctx, PERIMETER.x, PERIMETER.y, PERIMETER.z)
    Wait(1500) -- entering builds the business's module zones (client/business.lua Business.enter)
end)
K.step('I leave the Burger Shot perimeter', 'client', function(ctx)
    hold(ctx, PERIMETER.x, PERIMETER.y, PERIMETER.z + PERIMETER.radius + 30.0)
    Wait(1000)
end)
-- Enters the perimeter first so the bench zone exists before the ped walks into it.
K.step('I stand at the Burger Shot grill', 'client', function(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('interact.close') end) end)
    hold(ctx, PERIMETER.x, PERIMETER.y, PERIMETER.z)
    Wait(1500)
    hold(ctx, GRILL.x, GRILL.y, GRILL.z)
    Wait(1000)
end)

local function notOffered(label)
    Wait(1500)
    for _, option in ipairs(K.uiState().interact or {}) do
        assert(option.label ~= label, 'The interact selector offers ' .. label)
    end
end
K.step('the business bench {string} should not be offered to me', 'client', function(_, label) notOffered(label) end)
K.step('the business option {string} should not be offered to me', 'client', function(_, label) notOffered(label) end)

-- client/business.lua openCraftingMenu disables a recipe whose ingredients the
-- player lacks; kora_lib then refuses to select it.
K.step('the business bench recipe {string} should be unavailable', 'client', function(ctx, label)
    local menu = K.waitMenu(ctx)
    local entry
    for _, item in ipairs(menu.items or {}) do if item.label == label then entry = item end end
    assert(entry, 'The bench menu does not list ' .. label)
    assert(entry.disabled == true, label .. ' can be selected without its ingredients')
end)

-- ---------------------------------------------------------------------------
-- Client: management console (/jobcreator, app kora_jobcreator:management)
-- ---------------------------------------------------------------------------

-- kora_lib answers an app action with { ok, result = { notice } }; accept a
-- bare result too so the step survives a hook contract change.
K.step('the business console should answer with a {string} notice containing {string}', 'client', function(ctx, tone, text)
    local result = ctx.state.appResult
    local inner = type(result) == 'table' and (type(result.result) == 'table' and result.result or result) or {}
    local notice = inner.notice
    assert(type(notice) == 'table', 'The business console returned no notice')
    ctx:equal(notice.tone, tone, 'Notice tone')
    assert(K.contains(notice.message, text),
        ('Notice is "%s", expected it to contain "%s"'):format(tostring(notice.message), text))
end)

-- ---------------------------------------------------------------------------
-- Server: more registry checks (server/admin.lua exports, server/state.lua)
-- ---------------------------------------------------------------------------

-- The shipped seed's modules (shared/businesses/burgershot.lua), by label.
local MODULES = {
    ['Burger Shot'] = { moduleType = 'Zone', zoneType = 'sphere', x = -1193.0, y = -893.0, z = 13.9 },
    ['Front Till'] = { moduleType = 'POS', id = 'burgershot_till', zoneType = 'box', x = -1194.1, y = -899.4, z = 13.9 },
    ['Walk-in Fridge'] = { moduleType = 'Stash', id = 'burgershot_fridge', zoneType = 'box', x = -1198.5, y = -896.0, z = 13.9 },
    ['Grill'] = { moduleType = 'Crafting', zoneType = 'box', x = -1197.0, y = -900.5, z = 13.9 },
    ['Manager Desk'] = { moduleType = 'BossMenu', zoneType = 'sphere', x = -1200.5, y = -894.0, z = 13.9 },
}

local function seedModule(label)
    local expected = assert(MODULES[label], 'Not a seed module with a world zone: ' .. label)
    local module = findModule(seedBusiness(), expected.moduleType, label)
    assert(module, ('The seed has no %s module labelled %s'):format(expected.moduleType, label))
    return module, expected
end

K.step('the Burger Shot seed should have a {string} module labelled {string}', 'server', function(_, moduleType, label)
    assert(findModule(seedBusiness(), moduleType, label), ('The seed has no %s module labelled %s'):format(moduleType, label))
end)

-- Precondition for scenarios that stand in one module's zone.
K.step('the Burger Shot {string} module is where the seed put it', 'server', function(ctx, label)
    local module, expected = seedModule(label)
    ctx:equal(module.zoneType, expected.zoneType, label .. ' zone type')
    assert(sameSpot(module.coords, expected), label .. ' was moved in-game; these scenarios only know the shipped layout')
    if expected.id then ctx:equal(module.id, expected.id, label .. ' inventory id') end
    assert(not module.public, label .. ' was made public in-game')
end)

K.step('the Burger Shot grill should offer the recipes {string}', 'server', function(ctx, list)
    local grill = assert(findModule(seedBusiness(), 'Crafting', 'Grill'), 'The seed has no Grill')
    local expected = {}
    for id in list:gmatch('[^,%s]+') do expected[#expected + 1] = id end
    ctx:equal(#(grill.recipes or {}), #expected, 'Number of Grill recipes')
    for index, id in ipairs(expected) do ctx:equal(grill.recipes[index], id, 'Grill recipe ' .. index) end
end)

K.step('the business directory entry for Burger Shot should match the registry', 'server', function(ctx)
    local business = seedBusiness()
    local listed
    for _, entry in ipairs(K.export(RESOURCE, 'getBusinesses') or {}) do if entry.id == SEED then listed = entry end end
    assert(listed, 'getBusinesses does not include the seed business')
    ctx:equal(listed.label, business.label, 'Directory label')
    ctx:equal(listed.job, business.job, 'Directory job')
    ctx:equal(#(listed.modules or {}), #business.modules, 'Directory module count')
    assert(listed.rev ~= nil and listed.rev == business.rev, 'Directory revision is ' .. tostring(listed.rev)
        .. ', registry revision is ' .. tostring(business.rev))
end)

K.step('the business directory should be sorted by id', 'server', function()
    local all = K.export(RESOURCE, 'getBusinesses')
    assert(type(all) == 'table', 'getBusinesses did not return a table')
    for index = 2, #all do
        assert(all[index - 1].id < all[index].id, 'Business directory is not sorted by id at entry ' .. index)
    end
end)

-- getBusiness returns a JSON copy; changing it must not touch the registry.
K.step('changing a copy of the Burger Shot business should not change the registry', 'server', function(ctx)
    local copy = seedBusiness()
    local label, modules = copy.label, #copy.modules
    copy.label = 'FFT changed copy'
    copy.modules[#copy.modules + 1] = { moduleType = 'Zone', label = 'FFT' }
    local fresh = seedBusiness()
    ctx:equal(fresh.label, label, 'Registry label after changing a copy')
    ctx:equal(#fresh.modules, modules, 'Registry module count after changing a copy')
end)

K.step('the business list for job {string} should be sorted and only hold that job', 'server', function(_, job)
    local ids = K.export(RESOURCE, 'getBusinessesByJob', job)
    assert(type(ids) == 'table', 'getBusinessesByJob did not return a table')
    for index, id in ipairs(ids) do
        local business = K.export(RESOURCE, 'getBusiness', id)
        assert(business and business.job == job, id .. ' is listed under job ' .. job .. ' but is not one of its businesses')
        if index > 1 then assert(ids[index - 1] < id, 'Business list is not sorted at entry ' .. index) end
    end
end)

K.step('every business staff count should be a positive whole number', 'server', function()
    local counts = K.export(RESOURCE, 'getStaffCounts')
    assert(type(counts) == 'table', 'getStaffCounts did not return a table')
    for id, total in pairs(counts) do
        assert(type(total) == 'number' and total >= 1 and total % 1 == 0, ('Staff count for %s is %s'):format(tostring(id), tostring(total)))
        assert(K.export(RESOURCE, 'getBusiness', id), 'Staff are counted at an unknown business: ' .. tostring(id))
    end
end)

-- kora_core setJobDuty fires QBCore:Server:SetDuty, which server/staff.lua
-- uses to forget off-duty staff. The job fixture restores the duty state.
K.step('I go off duty through kora_core', 'server', function(ctx)
    local ok, err = exports.kora_core:setJobDuty(ctx.tester, false)
    assert(ok, 'Could not go off duty: ' .. tostring(err))
end)

-- ---------------------------------------------------------------------------
-- Client: standing at other seed modules
-- ---------------------------------------------------------------------------

K.step('I stand at the Burger Shot module {string}', 'client', function(ctx, label)
    local spot = assert(MODULES[label], 'Not a seed module with a world zone: ' .. label)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('interact.close') end) end)
    hold(ctx, PERIMETER.x, PERIMETER.y, PERIMETER.z)
    Wait(1500) -- the perimeter builds the module zones first
    hold(ctx, spot.x, spot.y, spot.z)
    Wait(1000)
end)

-- ---------------------------------------------------------------------------
-- Client: management console views and actions (client/creator.lua)
-- ---------------------------------------------------------------------------

local function navigation(ctx, fromResult)
    local app
    if fromResult then
        app = type(ctx.state.appResult) == 'table' and ctx.state.appResult.app
    else
        local payload = K.ui('app')
        app = type(payload) == 'table' and payload.app
    end
    return type(app) == 'table' and type(app.navigation) == 'table' and app.navigation or {}
end

local function view(list, id)
    for _, entry in ipairs(list) do if type(entry) == 'table' and entry.id == id then return entry end end
end

K.step('the business console directory should list at least {int} business', 'client', function(ctx, minimum)
    local directory = assert(view(navigation(ctx), 'businesses'), 'The console has no business directory')
    local total = tonumber(directory.badge) or 0
    assert(total >= minimum, ('The directory lists %d businesses, expected at least %d'):format(total, minimum))
end)

-- businesses:select answers with the management view and navigates to it.
K.step('the business console should show the management view for {string} of job {string}', 'client', function(ctx, label, job)
    local result = ctx.state.appResult or {}
    local navigate = type(result.navigate) == 'table' and result.navigate or {}
    ctx:equal(navigate.viewId, 'management', 'View the console navigated to')
    local management = assert(view(navigation(ctx, true), 'management'), 'The console has no management view')
    ctx:equal(management.label, label, 'Managed business')
    ctx:equal(management.description, job, 'Managed business job')
end)

K.step('the business console should show the modules tab', 'client', function(ctx)
    local navigate = type((ctx.state.appResult or {}).navigate) == 'table' and ctx.state.appResult.navigate or {}
    ctx:equal(navigate.viewId, 'management', 'View the console navigated to')
    ctx:equal(navigate.tabId, 'modules', 'Tab the console navigated to')
end)

-- Toggles the local world outlines and back; the two notices must disagree.
K.step('toggling the business console world debug twice should switch it and switch it back', 'client', function(ctx)
    local function toggle()
        local _, result = K.must(K.ui('app.action', 'businesses:toggle-debug'))
        local notice = type(result) == 'table' and result.notice or {}
        assert(notice.tone == 'success', 'Debug toggle answered ' .. tostring(notice.message))
        return notice.message
    end
    local first = toggle()
    local pending = true
    ctx:cleanup(function()
        if not pending then return end
        local app = exports.kora_lib:fftAction('state').app
        if app and app.id == 'kora_jobcreator:management' then exports.kora_lib:fftAction('app.action', 'businesses:toggle-debug') end
    end)
    local second = toggle()
    pending = false
    local messages = { [first] = true, [second] = true }
    assert(messages['Local world debug enabled.'] and messages['Local world debug hidden.'],
        ('Debug toggles answered "%s" then "%s"'):format(tostring(first), tostring(second)))
end)
