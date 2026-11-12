-- Shared helpers and generic steps for the Kora resource suites in steps/kora/.
-- Loaded as a shared script: every definition exists in both realms and only the
-- owning realm executes it, so callbacks must touch realm APIs at call time only.
-- See docs/KORA_TESTS.md for the conventions the per-resource files follow.
if FFTConfig.adapter ~= 'kora' then return end

local server = FFT.realm == 'server'
local K = {}
FFT.kora = K
K.server = server

---Registers a step. `realm` is 'client' or 'server'.
function K.step(pattern, realm, callback, requires)
    return FFT.registerStep({ pattern = pattern, realm = realm, requires = requires or {} }, callback)
end

---Registers features/kora/<name>.feature when the resource it covers is installed.
---Its scenarios fail up front, with one plain line, while that resource is not started.
---@param name string feature file name without extension
---@param resource? string resource that must exist; defaults to `name`
function K.feature(name, resource)
    if not server then return end
    if GetResourceState(resource or name) == 'missing' then return end
    local path = ('features/kora/%s.feature'):format(name)
    local owner = GetCurrentResourceName()
    if not LoadResourceFile(owner, path) then print('[fft] missing ' .. path) return end
    -- `resource` is checked before each scenario of this feature runs (server/main.lua).
    FFT.features[owner .. '/' .. path] = { owner = owner, path = path, resource = resource or name }
end

function K.started(resource)
    local state = GetResourceState(resource)
    if state ~= 'started' then error(('%s is %s; start it before running this scenario'):format(resource, state), 0) end
end

---Calls a resource's FFT hook: exports[resource]:fftAction(action, ...).
function K.hook(resource, action, ...)
    K.started(resource)
    local results = table.pack(pcall(function(...) return exports[resource]:fftAction(action, ...) end, ...))
    if not results[1] then
        error(('%s FFT hook failed on %s (is fft_kora_hooks true and the resource restarted?): %s')
            :format(resource, tostring(action), tostring(results[2])), 0)
    end
    return table.unpack(results, 2, results.n)
end

---Asserts the conventional `ok, err, code` hook result and returns it.
function K.must(ok, err, ...)
    if not ok then error(tostring(err or 'Hook action was refused'), 0) end
    return ok, err, ...
end

---Calls a real export and raises a readable error when the export is absent.
function K.export(resource, name, ...)
    K.started(resource)
    local results = table.pack(pcall(function(...) return exports[resource][name](exports[resource], ...) end, ...))
    if not results[1] then error(('exports.%s:%s failed: %s'):format(resource, name, tostring(results[2])), 0) end
    return table.unpack(results, 2, results.n)
end

function K.contains(text, part)
    return type(text) == 'string' and text:lower():find(tostring(part):lower(), 1, true) ~= nil
end

---True when an error raised by an export carries `expected`. FiveM drops the
---message of an export that raises synchronously (the caller only sees
---"An error occurred while calling export ...: nil"), but the exporting
---resource prints it to its console. On the server that line is accepted as
---the evidence: declare it first with K.expectConsoleError(ctx, expected, resource).
function K.raisedWith(ctx, err, expected)
    local text = tostring(err)
    if K.contains(text, expected) then return true end
    if not server or not text:find('An error occurred while calling export', 1, true) then return false end
    local deadline = GetGameTimer() + 1500
    repeat
        for _, e in ipairs(ctx.expectedConsole or {}) do
            for _, line in ipairs(e.lines or {}) do
                if K.contains(line.message, expected) then return true end
            end
        end
        Wait(50)
    until GetGameTimer() > deadline
    return false
end

-- ---------------------------------------------------------------------------
-- Server helpers
-- ---------------------------------------------------------------------------

function K.core() return exports.kora_core end

---Authoritative PlayerData snapshot for the tester.
function K.player(ctx)
    local data = exports.kora_core:getPlayer(ctx.tester)
    if not data then error('Kora character is not loaded', 0) end
    return data.PlayerData or data
end

function K.count(ctx, item)
    local total = 0
    for _, entry in pairs(K.player(ctx).items or {}) do
        if entry and entry.name == item then total = total + (entry.amount or 0) end
    end
    return total
end

function K.money(ctx, account)
    local value = exports.kora_core:getMoney(ctx.tester, account)
    if type(value) ~= 'number' then error('Money account unavailable: ' .. tostring(account), 0) end
    return value
end

---Sets the tester's job and restores the previous one (and the multijob roster) afterwards.
function K.setJob(ctx, name, grade, onDuty)
    local core = exports.kora_core
    local before = K.player(ctx)
    local previous = before.job or {}
    local previousGrade = type(previous.grade) == 'table' and previous.grade.level or previous.grade
    local citizenid, tester = before.citizenid, ctx.tester
    -- A job the tester already had saved in kora_multijob must survive cleanup.
    local savedLevel
    if GetResourceState('kora_multijob') == 'started' then
        local okRoster, view = pcall(function() return exports.kora_multijob:getRoster(tester) end)
        for _, job in ipairs(okRoster and type(view) == 'table' and type(view.jobs) == 'table' and view.jobs or {}) do
            if job.name == name then savedLevel = job.level end
        end
    end
    local ok, err = core:setJob(tester, name, grade)
    if not ok then error(('Could not set job %s grade %s: %s'):format(name, tostring(grade), tostring(err)), 0) end
    ctx:cleanup(function()
        if previous.name then
            core:setJob(tester, previous.name, previousGrade)
            core:setJobDuty(tester, previous.onduty == true)
        end
        if previous.name ~= name and GetResourceState('kora_multijob') == 'started' then
            if savedLevel then
                pcall(function() exports.kora_multijob:addJob(tester, name, savedLevel) end)
            else
                pcall(function() exports.kora_multijob:removeEmployeeJob(citizenid, name) end)
            end
        end
    end)
    if onDuty ~= nil then
        local dutyOk, dutyErr = core:setJobDuty(tester, onDuty)
        if not dutyOk then error('Could not set duty: ' .. tostring(dutyErr), 0) end
    end
end

---Starts recording a local server event for this scenario. Each record is the
---event's arguments; `filter(...)` decides which firings belong to the tester.
function K.capture(ctx, event, filter)
    ctx.state.captured = ctx.state.captured or {}
    if ctx.state.captured[event] then return end
    local list = {}
    ctx.state.captured[event] = list
    ctx:on(event, function(...)
        if filter and not filter(...) then return end
        if #list < 50 then list[#list + 1] = { ... } end
    end)
end

function K.captured(ctx, event) return ctx.state.captured and ctx.state.captured[event] or {} end

function K.watchMoney(ctx)
    local tester = ctx.tester
    K.capture(ctx, 'QBCore:Server:OnMoneyChange', function(src) return src == tester end)
end

---Declares a server console error this scenario provokes on purpose, so the
---line and its traceback are reported as expected instead of as a CONSOLE
---error. `text` is a plain substring of the error line (16+ characters, copied
---from the resource source); `resource` optionally names the printing resource.
---Lasts until the scenario ends. Call it before the refusing action.
function K.expectConsoleError(ctx, text, resource) ctx:expectConsoleError(text, resource) end

-- ---------------------------------------------------------------------------
-- Client helpers
-- ---------------------------------------------------------------------------

function K.ui(action, ...) return K.hook('kora_lib', action, ...) end
function K.uiState() return K.ui('state') or {} end

---Calls a resource's own NUI callback (one registered with RegisterNUICallback)
---through a real browser fetch from the FFT page, so the registered handler and
---its validation run. Returns the callback's answer; errors when it is not answered.
function K.nui(resource, name, body, timeout)
    K.started(resource)
    local ok, result = FFT.nui(resource, name, body, timeout)
    if not ok then error(tostring(result), 0) end
    return result
end

---Moves the tester and restores the original position during cleanup.
function K.teleport(ctx, x, y, z, heading)
    local ped = PlayerPedId()
    assert(not IsPedInAnyVehicle(ped, false) or ctx.state.vehicle, 'Leave the vehicle before teleporting')
    if not ctx.state.teleported then
        local origin, originHeading = GetEntityCoords(ped), GetEntityHeading(ped)
        ctx.state.teleported = true
        ctx:cleanup(function()
            local current = PlayerPedId()
            FreezeEntityPosition(current, false)
            SetEntityCoordsNoOffset(current, origin.x, origin.y, origin.z, false, false, false)
            SetEntityHeading(current, originHeading)
        end)
    end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false)
    if heading then SetEntityHeading(ped, heading + 0.0) end
    FreezeEntityPosition(ped, true)
    local deadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do ctx:check() Wait(50) end
    -- An interior (MLO) floor streams in after the exterior collision: a store
    -- teleport otherwise drops the tester through it, under the map.
    local interior = GetInteriorAtCoords(x + 0.0, y + 0.0, z + 0.0)
    if interior ~= 0 then
        PinInteriorInMemory(interior)
        while not IsInteriorReady(interior) and GetGameTimer() < deadline do ctx:check() Wait(50) end
        Wait(100)
    end
    FreezeEntityPosition(ped, false)
    Wait(250)
    -- Still falling well below the target: put the tester back once, held a moment longer.
    if GetEntityCoords(ped).z < z - 3.0 then
        SetEntityCoordsNoOffset(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false)
        FreezeEntityPosition(ped, true)
        Wait(1000)
        FreezeEntityPosition(ped, false)
        Wait(250)
    end
end

---Turns the ped and gameplay camera towards a world position.
---The on-foot camera is not on the ped's heading line (it sits about 0.4 m to
---the right), so a ray along the ped's heading passes beside a ped or prop
---1-2 m away. The camera's own heading and pitch are therefore aimed from the
---camera position, a few frames in a row because the camera orbits the ped as
---its relative heading changes.
function K.aimAt(x, y, z)
    local ped = PlayerPedId()
    local from = GetEntityCoords(ped)
    SetEntityHeading(ped, GetHeadingFromVector_2d(x - from.x, y - from.y))
    SetGameplayCamRelativeHeading(0.0)
    for pass = 1, 3 do
        local cam = GetGameplayCamCoord()
        local flat = math.sqrt((x - cam.x) ^ 2 + (y - cam.y) ^ 2)
        if flat > 0.3 then
            local relative = (GetHeadingFromVector_2d(x - cam.x, y - cam.y) - GetEntityHeading(ped) + 540.0) % 360.0 - 180.0
            if math.abs(relative) < 60.0 then SetGameplayCamRelativeHeading(relative) end
        end
        SetGameplayCamRelativePitch(math.deg(math.atan(z - cam.z, math.max(flat, 0.01))), 1.0)
        if pass < 3 then Wait(0) end
    end
end

local function stopTargeting()
    pcall(function() exports.kora_target:fftAction('stop') end)
    pcall(function() exports.kora_lib:fftAction('interact.close') end)
end

---Selects a visible target option through the real targeting state machine.
---`entity` restricts the match to one entity handle; nil accepts zones and any entity.
---Describes where the crosshair ray lands, for target timeouts that otherwise say nothing.
local function targetProbe(label)
    local ok, p = pcall(function() return exports.kora_target:fftAction('probe') end)
    if not ok or type(p) ~= 'table' then return ' (no probe: ' .. tostring(ok and 'unsupported' or p) .. ')' end
    local function at(v) return v and ('%.1f %.1f %.1f'):format(v.x, v.y, v.z or 0) or 'none' end
    local hover = p.hovering and ('%s (%d option%s)'):format(tostring(p.hovering.label), p.hovering.optionCount or 1, (p.hovering.optionCount or 1) == 1 and '' or 's') or 'nothing'
    local located = ''
    if type(label) == 'string' then
        local okLocate, points = pcall(function() return exports.kora_target:fftAction('locate', label) end)
        local first = okLocate and type(points) == 'table' and points[1] or nil
        located = (', %d registered aim point(s) within 30 m%s'):format(okLocate and type(points) == 'table' and #points or 0,
            first and (', nearest ' .. at(first)) or '')
    end
    local gates = ''
    if type(p.gates) == 'table' then
        local closed = {}
        for name, value in pairs(p.gates) do
            -- `focused` and `enabled` are open when true; every other gate is closed when true.
            local blocking = (name == 'focused' or name == 'enabled') and not value or (name ~= 'focused' and name ~= 'enabled' and value)
            if blocking then closed[#closed + 1] = name end
        end
        table.sort(closed)
        gates = ', closed gates: ' .. (#closed > 0 and table.concat(closed, ', ') or 'none')
    end
    local refusal = K.lastStartRefusal and (', start refused: ' .. K.lastStartRefusal) or ''
    return (' | probe: targeting %s, hovering %s, ray hit %s, ped %s, camera heading %.0f pitch %.0f%s%s%s')
        :format(p.active and 'on' or 'off', hover, p.hit and at(p.hitCoords) or 'nothing', at(p.ped), p.rot.z, p.rot.x, located, gates, refusal)
end
K.targetProbe = targetProbe

---Returns a function that, on each call, turns the camera towards the next
---world point kora_target reports for `label` (zone samples or the entity),
---like a player looking around. The first call after a scenario's own facing
---leaves the camera alone so an option already under the crosshair is used as is.
function K.aimer(label, entity)
    local points, index, refreshAt, original = nil, 0, 0, nil
    return function()
        -- The scenario's own facing is the first aim and stays in the cycle.
        if not original then
            original = { heading = GetEntityHeading(PlayerPedId()), pitch = GetGameplayCamRelativePitch() }
            return
        end
        if not points or GetGameTimer() >= refreshAt then
            local ok, found = pcall(function() return exports.kora_target:fftAction('locate', label) end)
            points, refreshAt = {}, GetGameTimer() + 2000
            for _, point in ipairs(ok and type(found) == 'table' and found or {}) do
                if entity == nil or point.entity == entity then points[#points + 1] = point end
            end
        end
        index = index % (#points + 1) + 1
        if index > #points then
            SetEntityHeading(PlayerPedId(), original.heading)
            SetGameplayCamRelativeHeading(0.0)
            SetGameplayCamRelativePitch(original.pitch, 1.0)
        else
            local point = points[index]
            K.aimAt(point.x, point.y, point.z)
        end
        Wait(120)
    end
end

---Starts targeting and waits for the resolver to report a hover (at most
---`timeout` ms): `start` clears the previous hover, so an immediate `select`
---would see nothing even with the option under the crosshair.
function K.startTargeting(timeout)
    local started, reason = exports.kora_target:fftAction('start')
    if not started then
        K.lastStartRefusal = tostring(reason or 'start refused')
        return false
    end
    K.lastStartRefusal = nil
    local deadline = GetGameTimer() + (timeout or 350)
    while not exports.kora_target:fftAction('hovering') and GetGameTimer() < deadline do Wait(25) end
    return true
end

---Stands beside a world point, trying each side in turn, until `label` is the
---option under the crosshair; returns the entity it belongs to (if any).
---`opts.find()` returns the entity the option must be on (a ped, prop...).
---Waits for kora_target to report the option near the point, since networked
---shop peds stream in and register their option a few seconds after a teleport.
---opts: heading, distance (1.5), lift (0), aimLift (0), find.
function K.face(ctx, label, x, y, z, opts)
    opts = opts or {}
    ctx:cleanup(stopTargeting)
    local place = vector3(x, y, z)
    local deadline = GetGameTimer() + 11000
    local function located()
        local ok, points = pcall(function() return exports.kora_target:fftAction('locate', label, 40.0) end)
        local near = {}
        for _, point in ipairs(ok and type(points) == 'table' and points or {}) do
            if #(vector3(point.x, point.y, point.z) - place) <= 4.0 then near[#near + 1] = point end
        end
        return near
    end
    local sides = { 0.0, 90.0, -90.0, 180.0 }
    local side = 0
    -- Sides over a drop (the truck robbery dealer stands on a ledge) are skipped:
    -- the tester fell 4 m, landed out of reach and could be hurt. Checked from
    -- the loaded ground; once every side has been skipped the check is dropped.
    local dropped, checkGround = 0, true
    while GetGameTimer() < deadline do
        side = side % #sides + 1
        if side == 1 then
            if dropped == #sides then checkGround = false end
            dropped = 0
        end
        local angle = math.rad((opts.heading or 0.0) + sides[side])
        local distance = opts.distance or 1.5
        local standX, standY, standZ = x - math.sin(angle) * distance, y + math.cos(angle) * distance, z + (opts.lift or 0.0)
        local found, ground = GetGroundZFor_3dCoord(standX, standY, standZ + 1.0, false)
        if checkGround and found and standZ - ground > 3.0 then
            dropped = dropped + 1
            goto nextSide
        end
        K.teleport(ctx, standX, standY, standZ)
        if checkGround and GetEntityCoords(PlayerPedId()).z < standZ - 2.5 then
            dropped = dropped + 1
            goto nextSide
        end
        -- The first side waits longest: that is where streaming happens.
        local ready = GetGameTimer() + (side == 1 and 5000 or 1500)
        local entity, points
        repeat
            ctx:check()
            entity = opts.find and opts.find() or nil
            points = located()
            if (entity or not opts.find) and #points > 0 then break end
            Wait(100)
        until GetGameTimer() > ready or GetGameTimer() > deadline
        if entity or not opts.find then
            local aims = {}
            if entity then
                local at = GetEntityCoords(entity)
                aims[#aims + 1] = vector3(at.x, at.y, at.z + (opts.aimLift or 0.0))
                aims[#aims + 1] = vector3(at.x, at.y, at.z + 0.5)
            else
                aims[#aims + 1] = vector3(x, y, z + (opts.aimLift or 0.0))
            end
            for _, point in ipairs(points) do
                if not entity or point.entity == entity then aims[#aims + 1] = vector3(point.x, point.y, point.z) end
            end
            for _, at in ipairs(aims) do
                ctx:check()
                K.aimAt(at.x, at.y, at.z)
                Wait(150)
                if K.startTargeting() then
                    local hover = exports.kora_target:fftAction('hovering')
                    if hover and (hover.label == label or hover.optionCount > 1) and (not entity or hover.entity == entity) then
                        stopTargeting()
                        return entity
                    end
                end
            end
            stopTargeting()
        end
        ::nextSide::
    end
    error(('Could not bring the target option "%s" under the crosshair near %.2f %.2f %.2f%s'):format(label, x, y, z, targetProbe(label)), 0)
end

function K.target(ctx, label, entity)
    ctx:cleanup(stopTargeting)
    local aim = K.aimer(label, entity)
    ctx:waitUntil(function()
        aim()
        if not K.startTargeting() then return false end
        local ok, err, code = exports.kora_target:fftAction('select', label, entity)
        if not ok then
            if code == 'not_visible' or code == 'rejected' then return false end
            error(err or 'Target selection rejected', 0)
        end
        if code ~= 'menu' then return true end
        -- Several options were visible: the release opened kora_lib's selector.
        local deadline = GetGameTimer() + 1500
        while GetGameTimer() < deadline do
            local chosen, _, why = K.ui('interact.select', label)
            if chosen then return true end
            if why == 'not_visible' then break end
            Wait(50)
        end
        K.ui('interact.close')
        return false
    end, 'Target option did not become selectable: ' .. tostring(label), 11000, function() return targetProbe(label) end)
end

---Waits for a kora_lib notification whose title or message contains `text`.
function K.waitNotification(ctx, text, timeout)
    return ctx:waitUntil(function()
        for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            if K.contains(entry.message, text) or K.contains(entry.title, text) then return entry end
        end
    end, 'No notification containing "' .. tostring(text) .. '"', timeout, function()
        local seen = {}
        for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            if #seen < 5 then seen[#seen + 1] = ('"%s"'):format(tostring(entry.message or entry.title)) end
        end
        return #seen > 0 and (' | seen since the scenario began: ' .. table.concat(seen, ', ')) or ' | no notification since the scenario began'
    end)
end

function K.waitMenu(ctx, title)
    return ctx:waitUntil(function()
        local menu = K.uiState().menu
        if menu and (title == nil or K.contains(menu.title, title)) then return menu end
    end, title and ('No menu titled "' .. title .. '" opened') or 'No menu opened')
end

---Decodes a step's doc string as JSON (the runner passes it as the last argument).
function K.json(argument)
    local text = type(argument) == 'table' and (argument.docString and argument.docString.content or argument.content) or argument
    assert(type(text) == 'string', 'This step needs a JSON doc string')
    local ok, value = pcall(json.decode, text)
    assert(ok and value ~= nil, 'Doc string is not valid JSON')
    return value
end

-- ---------------------------------------------------------------------------
-- Generic steps: environment, character fixtures and assertions (server)
-- ---------------------------------------------------------------------------

K.step('resource {string} is running', 'server', function(_, resource) K.started(resource) end)

-- Server realm because the console listener is; declare it right before the
-- refusing step, whatever realm that step runs in.
K.step('I expect a console error containing {string}', 'server', function(ctx, text) K.expectConsoleError(ctx, text) end)
K.step('I expect a console error from {string} containing {string}', 'server', function(ctx, resource, text)
    K.expectConsoleError(ctx, text, resource)
end)

K.step('my job is {string} at grade {int}', 'server', function(ctx, name, grade) K.setJob(ctx, name, grade) end)
K.step('I am on duty as {string} at grade {int}', 'server', function(ctx, name, grade) K.setJob(ctx, name, grade, true) end)
K.step('I am off duty as {string} at grade {int}', 'server', function(ctx, name, grade) K.setJob(ctx, name, grade, false) end)
K.step('my job should be {string}', 'server', function(ctx, name)
    ctx:equal((K.player(ctx).job or {}).name, name, 'Job name')
end)
K.step('I should be on duty', 'server', function(ctx)
    ctx:equal((K.player(ctx).job or {}).onduty == true, true, 'On duty')
end)
K.step('I should be off duty', 'server', function(ctx)
    ctx:equal((K.player(ctx).job or {}).onduty == true, false, 'On duty')
end)

K.step('my gang is {string} at grade {int}', 'server', function(ctx, name, grade)
    local core, tester = exports.kora_core, ctx.tester
    local previous = K.player(ctx).gang or {}
    local previousGrade = type(previous.grade) == 'table' and previous.grade.level or previous.grade
    local ok, err = core:setGang(tester, name, grade)
    if not ok then error('Could not set gang: ' .. tostring(err), 0) end
    ctx:cleanup(function() if previous.name then core:setGang(tester, previous.name, previousGrade) end end)
end)

K.step('my metadata {string} is {int}', 'server', function(ctx, key, value)
    local core, tester = exports.kora_core, ctx.tester
    local original = core:getMetaData(tester, key)
    local ok, err = core:setMetaData(tester, key, value)
    if ok == false then error('Could not set metadata ' .. key .. ': ' .. tostring(err), 0) end
    ctx:cleanup(function() core:setMetaData(tester, key, original) end)
end)
K.step('my metadata {string} should be {int}', 'server', function(ctx, key, value)
    ctx:waitUntil(function() return exports.kora_core:getMetaData(ctx.tester, key) == value end,
        ('Metadata %s is %s, expected %d'):format(key, tostring((exports.kora_core:getMetaData(ctx.tester, key))), value), 3000)
end)
K.step('my metadata {string} should be at least {int}', 'server', function(ctx, key, value)
    local actual = tonumber(exports.kora_core:getMetaData(ctx.tester, key))
    assert(actual and actual >= value, ('Metadata %s is %s, expected at least %d'):format(key, tostring(actual), value))
end)
K.step('my metadata {string} should be at most {int}', 'server', function(ctx, key, value)
    local actual = tonumber(exports.kora_core:getMetaData(ctx.tester, key))
    assert(actual and actual <= value, ('Metadata %s is %s, expected at most %d'):format(key, tostring(actual), value))
end)

K.step('I hold {int} {string}', 'server', function(ctx, amount, item)
    assert(amount > 0 and amount <= 500, 'Held amount must be 1-500')
    local core, tester = exports.kora_core, ctx.tester
    local ok, err = core:addItem(tester, item, amount, nil, nil, 'functional test')
    if not ok then error(('Could not grant %d %s: %s'):format(amount, item, tostring(err)), 0) end
    ctx:cleanup(function()
        local left = core:getItemCount(tester, item) or 0
        if left > 0 then core:removeItem(tester, item, math.min(left, amount), nil, 'functional test cleanup') end
    end)
end)
K.step('I should have at least {int} {string}', 'server', function(ctx, amount, item)
    ctx:waitUntil(function() return K.count(ctx, item) >= amount end,
        ('Expected at least %d %s, have %d'):format(amount, item, K.count(ctx, item)), 3000)
end)
K.step('I should have no {string}', 'server', function(ctx, item)
    ctx:waitUntil(function() return K.count(ctx, item) == 0 end,
        ('Expected no %s, have %d'):format(item, K.count(ctx, item)), 3000)
end)
K.step('I remember how many {string} I have', 'server', function(ctx, item)
    ctx.state.itemBaseline = ctx.state.itemBaseline or {}
    ctx.state.itemBaseline[item] = K.count(ctx, item)
end)
K.step('I should have {int} more {string} than before', 'server', function(ctx, amount, item)
    local before = assert(ctx.state.itemBaseline and ctx.state.itemBaseline[item], 'Remember the item count first')
    ctx:waitUntil(function() return K.count(ctx, item) - before == amount end,
        ('%s changed by %d, expected +%d'):format(item, K.count(ctx, item) - before, amount), 3000)
end)
K.step('I should have {int} fewer {string} than before', 'server', function(ctx, amount, item)
    local before = assert(ctx.state.itemBaseline and ctx.state.itemBaseline[item], 'Remember the item count first')
    ctx:waitUntil(function() return before - K.count(ctx, item) == amount end,
        ('%s changed by %d, expected -%d'):format(item, K.count(ctx, item) - before, amount), 3000)
end)

K.step('I have {int} in my {string} account', 'server', function(ctx, amount, account)
    assert(amount >= 0 and amount <= (FFTConfig.maxTestBalance or 1000000), 'Test balance out of range')
    local core, tester = exports.kora_core, ctx.tester
    local original = K.money(ctx, account)
    local ok, err = core:setMoney(tester, account, amount, 'functional test')
    if not ok then error('Could not set ' .. account .. ': ' .. tostring(err), 0) end
    ctx:cleanup(function() core:setMoney(tester, account, original, 'functional test cleanup') end)
end)
K.step('I remember my {string} balance', 'server', function(ctx, account)
    ctx.state.moneyBaseline = ctx.state.moneyBaseline or {}
    ctx.state.moneyBaseline[account] = K.money(ctx, account)
    K.watchMoney(ctx)
end)
-- kora_core's paycheck loop (modules/paycheck/server.lua, every
-- Config.jobs.paycheckInterval) pays the tester on its own schedule, e.g. the
-- unemployed grade's 10 cash; it is not caused by the scenario, so receipts
-- with the reason 'paycheck' since the baseline are left out of the delta.
local function paychecks(ctx, account)
    local total = 0
    for _, record in ipairs(K.captured(ctx, 'QBCore:Server:OnMoneyChange')) do
        if record[2] == account and record[5] == 'paycheck' and record[4] ~= 'remove' and type(record[3]) == 'number' then
            total = total + record[3]
        end
    end
    return total
end
local function moneyDelta(ctx, account)
    local before = assert(ctx.state.moneyBaseline and ctx.state.moneyBaseline[account], 'Remember the ' .. account .. ' balance first')
    return K.money(ctx, account) - before - paychecks(ctx, account)
end
K.step('my {string} balance should have increased by {int}', 'server', function(ctx, account, amount)
    ctx:waitUntil(function() return moneyDelta(ctx, account) == amount end,
        ('%s changed by %d, expected +%d'):format(account, moneyDelta(ctx, account), amount), 3000)
end)
K.step('my {string} balance should have decreased by {int}', 'server', function(ctx, account, amount)
    ctx:waitUntil(function() return moneyDelta(ctx, account) == -amount end,
        ('%s changed by %d, expected -%d'):format(account, moneyDelta(ctx, account), amount), 3000)
end)
K.step('my {string} balance should have increased', 'server', function(ctx, account)
    ctx:waitUntil(function() return moneyDelta(ctx, account) > 0 end, account .. ' did not increase', 3000)
end)
K.step('my {string} balance should have decreased', 'server', function(ctx, account)
    ctx:waitUntil(function() return moneyDelta(ctx, account) < 0 end, account .. ' did not decrease', 3000)
end)
K.step('my {string} balance should be unchanged', 'server', function(ctx, account)
    Wait(500)
    ctx:equal(moneyDelta(ctx, account), 0, account .. ' balance change')
end)
K.step('a money change should have been recorded for {string}', 'server', function(ctx, account)
    ctx:waitUntil(function()
        for _, record in ipairs(K.captured(ctx, 'QBCore:Server:OnMoneyChange')) do
            if record[2] == account then return true end
        end
    end, 'No QBCore:Server:OnMoneyChange receipt for ' .. account, 3000)
end)

-- ---------------------------------------------------------------------------
-- Generic steps: movement, commands and timing (client)
-- ---------------------------------------------------------------------------

K.step('I stand at {float} {float} {float} facing {float}', 'client', function(ctx, x, y, z, heading)
    K.teleport(ctx, x, y, z, heading)
end)
K.step('I aim at {float} {float} {float}', 'client', function(_, x, y, z) K.aimAt(x, y, z) Wait(100) end)
K.step('I wait {int} milliseconds', 'client', function(ctx, duration)
    assert(duration >= 0 and duration <= 12000, 'Waits are limited to 12 seconds per step')
    local deadline = GetGameTimer() + duration
    while GetGameTimer() < deadline do ctx:check() Wait(50) end
end)
K.step('I run the command {string}', 'client', function(_, command)
    assert(#command > 0 and #command <= 200, 'Command must be 1-200 characters')
    ExecuteCommand(command)
end)
K.step('I am driving a temporary {string}', 'client', function(ctx, model)
    local hash = GetHashKey(model)
    assert(IsModelInCdimage(hash) and IsModelAVehicle(hash), 'Unknown vehicle model: ' .. model)
    RequestModel(hash)
    ctx:waitUntil(function() return HasModelLoaded(hash) end, 'Vehicle model did not load: ' .. model, 10000)
    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    local vehicle = CreateVehicle(hash, at.x, at.y, at.z + 0.5, GetEntityHeading(ped), true, false)
    assert(vehicle and vehicle ~= 0, 'Vehicle did not spawn')
    ctx.state.vehicle = vehicle
    ctx:cleanup(function()
        if DoesEntityExist(vehicle) then
            TaskLeaveVehicle(PlayerPedId(), vehicle, 16)
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(vehicle)
    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    ctx:waitUntil(function() return GetVehiclePedIsIn(PlayerPedId(), false) == vehicle end, 'Could not enter the vehicle', 3000)
end)
K.step('I should be in a vehicle', 'client', function()
    assert(IsPedInAnyVehicle(PlayerPedId(), false), 'Player is not in a vehicle')
end)

-- ---------------------------------------------------------------------------
-- Generic steps: targeting (client, through kora_target's hook)
-- ---------------------------------------------------------------------------

K.step('I target {string}', 'client', function(ctx, label) K.target(ctx, label, nil) end)
K.step('the target option {string} should be visible', 'client', function(ctx, label)
    ctx:cleanup(stopTargeting)
    local aim = K.aimer(label, nil)
    ctx:waitUntil(function()
        aim()
        if not K.startTargeting() then return false end
        local hover = exports.kora_target:fftAction('hovering')
        return hover and (hover.label == label or hover.optionCount > 1)
    end, 'Target option is not visible: ' .. label, 11000, function() return targetProbe(label) end)
    stopTargeting()
end)
K.step('no target option should be visible', 'client', function(ctx)
    ctx:cleanup(stopTargeting)
    K.must(exports.kora_target:fftAction('start'))
    Wait(1000)
    local hover = exports.kora_target:fftAction('hovering')
    stopTargeting()
    assert(not hover, 'A target option is visible: ' .. tostring(hover and hover.label))
end)

-- ---------------------------------------------------------------------------
-- Generic steps: kora_lib surfaces (client, through kora_lib's hook).
-- These answer at the NUI-callback level. They do not click DOM controls.
-- ---------------------------------------------------------------------------

-- Leftovers from an earlier scenario (a timed-out step's progress bar, fall
-- damage, a frozen ped) would block targeting in this one. Downed state is
-- cleared by the server reset between scenarios.
FFT.registerStep({ pattern = 'kora tester ready', realm = 'client', hook = 'Before' }, function()
    if GetResourceState('kora_lib') == 'started' then
        pcall(function() exports.kora_lib:fftAction('progress.cancel') end)
        local deadline = GetGameTimer() + 2000
        while GetGameTimer() < deadline do
            local ok, active = pcall(function() return exports.kora_lib:progressbar_isActive() end)
            if not ok or not active then break end
            Wait(50)
        end
    end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    if not IsEntityDead(ped) and GetEntityHealth(ped) < GetEntityMaxHealth(ped) then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    end
end)

FFT.registerStep({ pattern = 'kora ui baseline', realm = 'client', hook = 'Before' }, function(ctx)
    if GetResourceState('kora_lib') ~= 'started' then return end
    local ok, state = pcall(function() return exports.kora_lib:fftAction('state') end)
    ctx.state.uiBaseline = ok and type(state) == 'table' and state.sequence or 0
end)

K.step('a menu should open', 'client', function(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('menu.cancel') end) end)
    K.waitMenu(ctx)
end)
K.step('a menu titled {string} should open', 'client', function(ctx, title)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('menu.cancel') end) end)
    K.waitMenu(ctx, title)
end)
K.step('the menu should list {string}', 'client', function(ctx, label)
    local menu = K.waitMenu(ctx)
    for _, item in ipairs(menu.items or {}) do if item.label == label or item.id == label then return end end
    error('Menu does not list ' .. label, 0)
end)
K.step('the menu should not list {string}', 'client', function(ctx, label)
    local menu = K.waitMenu(ctx)
    for _, item in ipairs(menu.items or {}) do
        if item.label == label or item.id == label then error('Menu lists ' .. label, 0) end
    end
end)
K.step('I choose {string} in the menu', 'client', function(ctx, label)
    K.waitMenu(ctx)
    K.must(K.ui('menu.select', label))
end)
K.step('I close the menu', 'client', function() K.must(K.ui('menu.cancel')) end)
K.step('no menu should be open', 'client', function()
    Wait(300)
    assert(not K.uiState().menu, 'A menu is still open')
end)

K.step('an input dialog should open', 'client', function(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('input.cancel') end) end)
    ctx:waitUntil(function() return K.uiState().input end, 'No input dialog opened')
end)
K.step('I submit the input dialog with:', 'client', function(ctx, argument)
    ctx:waitUntil(function() return K.uiState().input end, 'No input dialog opened')
    K.must(K.ui('input.submit', K.json(argument)))
end)
K.step('I cancel the input dialog', 'client', function() K.must(K.ui('input.cancel')) end)

K.step('a confirmation should open', 'client', function(ctx)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('alert.answer', false) end) end)
    ctx:waitUntil(function() return K.uiState().alert end, 'No confirmation opened')
end)
K.step('I confirm', 'client', function(ctx)
    ctx:waitUntil(function() return K.uiState().alert end, 'No confirmation opened')
    K.must(K.ui('alert.answer', true))
end)
K.step('I decline', 'client', function(ctx)
    ctx:waitUntil(function() return K.uiState().alert end, 'No confirmation opened')
    K.must(K.ui('alert.answer', false))
end)

K.step('I should see a notification containing {string}', 'client', function(ctx, text) K.waitNotification(ctx, text) end)
K.step('I should not see a notification containing {string}', 'client', function(ctx, text)
    Wait(1000)
    for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
        if K.contains(entry.message, text) or K.contains(entry.title, text) then
            error('Unexpected notification: ' .. tostring(entry.message or entry.title), 0)
        end
    end
end)

K.step('a progress bar should start', 'client', function(ctx)
    ctx:waitUntil(function() return K.uiState().progress end, 'No progress bar started')
end)
K.step('a progress bar labelled {string} should start', 'client', function(ctx, label)
    ctx:waitUntil(function()
        local progress = K.uiState().progress
        return progress and K.contains(progress.label, label)
    end, 'No progress bar labelled "' .. label .. '" started')
end)
K.step('the progress bar should finish', 'client', function(ctx)
    ctx:waitUntil(function() return not K.uiState().progress end, 'Progress bar did not finish within one step; split the wait')
end)
K.step('no progress bar should be running', 'client', function()
    assert(not K.uiState().progress, 'A progress bar is running')
end)

K.step('the text prompt should show {string}', 'client', function(ctx, text)
    ctx:waitUntil(function()
        local prompt = K.uiState().textui
        return type(prompt) == 'table' and K.contains(prompt.text, text)
    end, 'Text prompt does not show "' .. text .. '"')
end)
K.step('no text prompt should be shown', 'client', function(ctx)
    ctx:waitUntil(function() return not K.uiState().textui end, 'A text prompt is still shown', 3000)
end)

K.step('the interact selector should offer {string}', 'client', function(ctx, label)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('interact.close') end) end)
    ctx:waitUntil(function()
        for _, option in ipairs(K.uiState().interact or {}) do if option.label == label then return true end end
    end, 'Interact selector does not offer ' .. label)
end)
K.step('I choose {string} in the interact selector', 'client', function(ctx, label)
    ctx:waitUntil(function()
        local ok, err, code = K.ui('interact.select', label)
        if ok then return true end
        if code == 'not_open' or code == 'not_visible' then return false end
        error(err, 0)
    end, 'Interact selector does not offer ' .. label)
end)

K.step('the app {string} should be open', 'client', function(ctx, id)
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('app.close') end) end)
    ctx:waitUntil(function()
        local app = K.uiState().app
        return app and app.id == id
    end, 'App is not open: ' .. id)
end)
-- App actions run the app's registered onAction through kora_lib's own NUI
-- callback. A declined action still "succeeds" at this level and reports a
-- notice, so assert the notice or the authoritative state afterwards.
local function appAction(ctx, actionId, context)
    local _, result = K.must(K.ui('app.action', actionId, context))
    ctx.state.appResult = type(result) == 'table' and result or {}
end
K.step('I trigger the app action {string}', 'client', function(ctx, actionId) appAction(ctx, actionId) end)
K.step('I trigger the app action {string} on {string}', 'client', function(ctx, actionId, itemId)
    appAction(ctx, actionId, { itemId = itemId })
end)
K.step('I trigger the app action {string} with:', 'client', function(ctx, actionId, argument)
    appAction(ctx, actionId, K.json(argument))
end)
-- kora_lib refuses actions the open app does not currently declare (a hidden or
-- absent button), before the app's handler runs.
K.step('the app action {string} should be unavailable', 'client', function(_, actionId)
    local ok, err, code = K.ui('app.action', actionId)
    assert(not ok, 'App action is available: ' .. actionId)
    assert(code == 'rejected', 'App action failed for another reason: ' .. tostring(err))
end)
K.step('the app should answer with a {string} notice containing {string}', 'client', function(ctx, tone, text)
    local notice = (ctx.state.appResult or {}).notice
    assert(type(notice) == 'table', 'The last app action returned no notice')
    ctx:equal(notice.tone, tone, 'Notice tone')
    assert(K.contains(notice.message, text), ('Notice is "%s", expected it to contain "%s"'):format(tostring(notice.message), text))
end)
K.step('I close the app', 'client', function()
    if not K.uiState().app then return end -- an action answering close = true already closed it
    K.must(K.ui('app.close'))
end)
K.step('no app should be open', 'client', function(ctx)
    ctx:waitUntil(function() return not K.uiState().app end, 'An app is still open', 3000)
end)
