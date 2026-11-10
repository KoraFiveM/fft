-- kora_admin: staff permission tiers, the self-targeted staff commands, the
-- admin menu command and the player report commands.
-- No resource hook: the tester's level is read through the resource's own
-- kora_admin:server:requestLevel / kora_admin:client:level sync, commands are run as
-- typed, and results are read from kora_lib notifications, the chat event the
-- resource sends, natives and kora_core metadata.
--
-- The tester's staff level is whatever the server has configured, and nothing
-- here may change it. Steps that depend on it learn the level first and then
-- assert the outcome the server must give that level: the action for staff,
-- the refusal for everyone else. Only the tester is ever targeted.
local K = FFT.kora
if not K then return end
K.feature('kora_admin')

-- Config.permissions.roles in kora_admin/config.lua (rank per role). A server
-- that adds a custom role must add it here before these scenarios can judge it.
local RANKS = { user = 0, support = 10, moderator = 20, admin = 30, owner = 40 }
-- Config.permissions gates: 'mod' resolves to moderator, /admin needs support.
local MOD_RANK, SUPPORT_RANK = 20, 10

local DENIED = 'You do not have permission for this command.'
local BRIDGE_REFUSAL = 'this temporary-access bridge is reserved for kora_lib-playground'

-- ---------------------------------------------------------------------------
-- Server: playground temporary-access bridge and admin duty baseline
-- ---------------------------------------------------------------------------

-- server/permissions.lua: both exports refuse any caller but kora_lib-playground
-- before looking at the role, so no access is ever granted here.
K.step('the playground access bridge should refuse to grant me temporary access', 'server', function(ctx)
    local expires, err = K.export('kora_admin', 'grantPlaygroundTemporaryAccess', ctx.tester, 'admin', 1)
    if expires ~= nil then
        pcall(function() exports.kora_admin:revokePlaygroundTemporaryAccess(ctx.tester, 'admin') end)
        error('Temporary access was granted to a caller other than the playground', 0)
    end
    -- FiveM can drop the second value of an export that returns nil first, so the
    -- reason is only checked when it arrives. The revoke step proves the reason.
    if err ~= nil then ctx:equal(err, BRIDGE_REFUSAL, 'Grant refusal') end
end)
K.step('the playground access bridge should refuse to revoke my temporary access', 'server', function(ctx)
    local revoked, err = K.export('kora_admin', 'revokePlaygroundTemporaryAccess', ctx.tester, 'admin')
    ctx:equal(revoked, false, 'Revoke result')
    ctx:equal(err, BRIDGE_REFUSAL, 'Revoke refusal')
end)

local function adminDuty(ctx)
    return exports.kora_core:getMetaData(ctx.tester, 'adminDuty') == true
end

K.step('I remember my admin duty status', 'server', function(ctx)
    K.started('kora_admin')
    local before = adminDuty(ctx)
    local tester = ctx.tester
    ctx.state.adminDutyBefore = before
    ctx:cleanup(function()
        if (exports.kora_core:getMetaData(tester, 'adminDuty') == true) ~= before then
            exports.kora_core:setMetaData(tester, 'adminDuty', before)
        end
    end)
end)
K.step('my admin duty status should be back to what it was', 'server', function(ctx)
    local before = ctx.state.adminDutyBefore
    assert(before ~= nil, 'Remember the admin duty status first')
    ctx:waitUntil(function() return adminDuty(ctx) == before end, 'Admin duty status did not return to its baseline', 3000)
end)

-- ---------------------------------------------------------------------------
-- Client: staff level
-- ---------------------------------------------------------------------------

local function rank(ctx)
    return assert(ctx.state.adminRank, 'Learn the staff level first')
end
local function isMod(ctx) return rank(ctx) >= MOD_RANK end

-- Runs an admin command as typed. Names only; arguments are fixed by the caller.
local function run(command)
    K.started('kora_admin')
    ExecuteCommand(command)
end

local function expectDenied(ctx)
    K.waitNotification(ctx, DENIED, 5000)
end

-- server/core.lua answers kora_admin:server:requestLevel with kora_admin:client:level,
-- the same read-only sync the resource's own client uses.
K.step('I learn my staff level', 'client', function(ctx)
    K.started('kora_admin')
    local answer = {}
    RegisterNetEvent('kora_admin:client:level')
    ctx:on('kora_admin:client:level', function(level)
        answer.level = level
        answer.received = true
    end)
    TriggerServerEvent('kora_admin:server:requestLevel')
    ctx:waitUntil(function() return answer.received end, 'The server did not answer the staff level request', 5000)
    local level = answer.level
    assert(type(level) == 'string', 'Staff level is not a role name: ' .. tostring(level))
    local held = RANKS[level]
    assert(held, 'Staff level "' .. level .. '" is not one of the default roles; add its rank to steps/kora/kora_admin.lua')
    ctx.state.adminLevel = level
    ctx.state.adminRank = held
end)

-- ---------------------------------------------------------------------------
-- Client: self-targeted staff commands (server/commands/self.lua, world.lua)
-- Each needs the 'mod' gate; below it kora_lib sends the generic refusal.
-- ---------------------------------------------------------------------------

-- /permission with no id resolves to the caller and answers "<name>: <level>".
K.step('asking for my own permission level should report it to staff only', 'client', function(ctx)
    local staff = isMod(ctx)
    run('permission')
    if staff then
        K.waitNotification(ctx, ': ' .. ctx.state.adminLevel, 5000)
    else
        expectDenied(ctx)
    end
end)

-- /serverinfo prints through Admin.chat: chatMessage('[Admin]', colour, text).
K.step('asking for the server info should list it to staff only', 'client', function(ctx)
    local staff = isMod(ctx)
    local lines = {}
    RegisterNetEvent('chatMessage')
    ctx:on('chatMessage', function(author, _, text)
        if author == '[Admin]' and type(text) == 'string' then lines[#lines + 1] = text end
    end)
    run('serverinfo')
    if not staff then
        expectDenied(ctx)
        ctx:equal(#lines, 0, 'Server info lines sent to a non-staff player')
        return
    end
    local info
    ctx:waitUntil(function()
        for _, text in ipairs(lines) do
            if text:find('Online players: %d+') then info = text return true end
        end
    end, 'No server info arrived in chat', 5000)
    local online = tonumber(info:match('Online players: (%d+)'))
    assert(online and online >= 1, 'Online player count should include the tester: ' .. tostring(online))
    assert(info:find('Uptime: %d+ minutes'), 'Server info has no uptime line')
    assert(info:find('Resources running: %d+'), 'Server info has no resource count')
end)

local function clientDuty()
    return exports.kora_core:getPlayerData({ 'metadata', 'adminDuty' }) == true
end

-- /aduty flips the adminDuty metadata and answers "Admin duty enabled|disabled".
K.step('I toggle admin duty with the staff command', 'client', function(ctx)
    local staff = isMod(ctx)
    local before = clientDuty()
    run('aduty')
    if staff then
        ctx:waitUntil(function() return clientDuty() ~= before end, 'Admin duty did not change', 5000)
        K.waitNotification(ctx, 'Admin duty ' .. (before and 'disabled' or 'enabled'), 5000)
    else
        expectDenied(ctx)
        Wait(500)
        ctx:equal(clientDuty(), before, 'Admin duty for a non-staff player')
    end
end)

-- /armor <percentage> relays kora_admin:client:setArmor to the caller only.
K.step('setting my own armour to {int} should work for staff only', 'client', function(ctx, value)
    assert(value >= 0 and value <= 100, 'Armour must be 0-100')
    local staff = isMod(ctx)
    local before = GetPedArmour(PlayerPedId())
    assert(before ~= value, 'Armour is already ' .. value .. '; pick another value')
    ctx:cleanup(function() SetPedArmour(PlayerPedId(), before) end)
    run('armor ' .. value)
    if staff then
        ctx:waitUntil(function() return GetPedArmour(PlayerPedId()) == value end,
            'Armour is ' .. GetPedArmour(PlayerPedId()) .. ', expected ' .. value, 5000)
    else
        expectDenied(ctx)
        Wait(500)
        ctx:equal(GetPedArmour(PlayerPedId()), before, 'Armour for a non-staff player')
    end
end)

-- ---------------------------------------------------------------------------
-- Client: admin menu (server/commands/player.lua, needs the support tier)
-- ---------------------------------------------------------------------------

K.step('opening the admin menu should work for support staff only', 'client', function(ctx)
    local allowed = rank(ctx) >= SUPPORT_RANK
    ctx:cleanup(function() pcall(function() exports.kora_lib:fftAction('app.close') end) end)
    run('admin')
    if allowed then
        ctx:waitUntil(function()
            local app = K.uiState().app
            return app and app.id == 'kora_admin:menu'
        end, 'The admin menu did not open', 8000)
    else
        -- Admin.menuAccessDeniedMessage names the missing tier and the held role.
        local entry = K.waitNotification(ctx, 'Admin menu unavailable: requires Support', 5000)
        assert(K.contains(entry.message, 'Your highest role is'), 'Refusal does not name the held role: ' .. tostring(entry.message))
        Wait(500)
        local app = K.uiState().app
        assert(not (app and app.id == 'kora_admin:menu'), 'The admin menu opened for a player below support')
    end
end)

-- ===========================================================================
-- Deeper coverage: command registry, validation branches, self-only round trips
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Server: the command registry kora_admin hands to kora_lib
-- ---------------------------------------------------------------------------

-- kora_lib/modules/commands/server.lua:232 Kora.commands.list() returns
-- {name, help, permission} per command; kora_lib/build/finalise.lua exports it
-- as commands_list. kora_admin/server/command_registry.lua:14 passes each
-- command's options.permission through unchanged, so this is the gate the
-- dispatcher (commands/server.lua:95) enforces.
K.step('kora_admin should register the command {string} behind the {string} gate', 'server', function(ctx, name, gate)
    local found
    for _, entry in ipairs(K.export('kora_lib', 'commands_list') or {}) do
        if entry.name == name then found = entry break end
    end
    assert(found, 'Command /' .. name .. ' is not registered with kora_lib')
    ctx:equal(found.permission, gate, 'Permission gate of /' .. name)
    assert(type(found.help) == 'string' and found.help ~= '', 'Command /' .. name .. ' has no help text')
end)

-- ---------------------------------------------------------------------------
-- Server: outcomes that depend on the tester being admin staff
-- ---------------------------------------------------------------------------

-- Server and client scenario state are separate, so server steps cannot read
-- the level the client learned. kora_admin/server/permissions.lua:152 exports
-- canEditConfig = Admin.checkLevel(src, Config.configEditor.level) (true, or
-- nil when refused outside Discord-only mode); config.lua sets that level to
-- 'admin', the same gate as the money/item/gang commands. A server that raises
-- configEditor.level to 'owner' must update this oracle.
local function serverAdmin(ctx)
    return K.export('kora_admin', 'canEditConfig', ctx.tester) == true
end

local function baselineMoney(ctx, account)
    local before = ctx.state.moneyBaseline and ctx.state.moneyBaseline[account]
    assert(before, 'Remember the ' .. account .. ' balance first')
    return before
end

local function expectBalance(ctx, account, expected)
    ctx:waitUntil(function() return K.money(ctx, account) == expected end,
        ('%s balance is %s, expected %s'):format(account, tostring(K.money(ctx, account)), tostring(expected)), 3000)
    if not serverAdmin(ctx) then
        Wait(500)
        ctx:equal(K.money(ctx, account), expected, account .. ' balance for a player below admin')
    end
end

K.step('my {string} balance should have grown by {int} for admin staff and be unchanged otherwise', 'server', function(ctx, account, amount)
    local before = baselineMoney(ctx, account)
    expectBalance(ctx, account, serverAdmin(ctx) and before + amount or before)
end)
K.step('my {string} balance should have shrunk by {int} for admin staff and be unchanged otherwise', 'server', function(ctx, account, amount)
    local before = baselineMoney(ctx, account)
    expectBalance(ctx, account, serverAdmin(ctx) and before - amount or before)
end)
K.step('my {string} balance should be {int} for admin staff and unchanged otherwise', 'server', function(ctx, account, amount)
    local before = baselineMoney(ctx, account)
    expectBalance(ctx, account, serverAdmin(ctx) and amount or before)
end)

-- Restores the exact item count the tester had when the step ran, whatever the
-- admin commands of the scenario did in between.
local function restoreItemCount(ctx, item)
    local tester, before = ctx.tester, K.count(ctx, item)
    local core = exports.kora_core
    ctx:cleanup(function()
        local data = core:getPlayer(tester)
        if not data then return end
        local now = 0
        for _, entry in pairs((data.PlayerData or data).items or {}) do
            if entry and entry.name == item then now = now + (entry.amount or 0) end
        end
        if now > before then core:removeItem(tester, item, now - before, nil, 'functional test cleanup')
        elseif now < before then core:addItem(tester, item, before - now, nil, nil, 'functional test cleanup') end
    end)
end

K.step('my {string} count is put back when the scenario ends', 'server', function(ctx, item)
    restoreItemCount(ctx, item)
end)
K.step('I hold {int} extra {string} until the scenario ends', 'server', function(ctx, amount, item)
    assert(amount > 0 and amount <= 50, 'Extra amount must be 1-50')
    restoreItemCount(ctx, item)
    local ok, err = exports.kora_core:addItem(ctx.tester, item, amount, nil, nil, 'functional test')
    if not ok then error(('Could not grant %d %s: %s'):format(amount, item, tostring(err)), 0) end
end)

local function itemDelta(ctx, item)
    local before = ctx.state.itemBaseline and ctx.state.itemBaseline[item]
    assert(before, 'Remember the item count first')
    return K.count(ctx, item) - before
end
local function expectItemDelta(ctx, item, expected)
    ctx:waitUntil(function() return itemDelta(ctx, item) == expected end,
        ('%s changed by %d, expected %d'):format(item, itemDelta(ctx, item), expected), 3000)
    if expected == 0 then
        Wait(500)
        ctx:equal(itemDelta(ctx, item), 0, item .. ' change for a player below admin')
    end
end
K.step('I should have {int} more {string} for admin staff and the same number otherwise', 'server', function(ctx, amount, item)
    expectItemDelta(ctx, item, serverAdmin(ctx) and amount or 0)
end)
K.step('I should have {int} fewer {string} for admin staff and the same number otherwise', 'server', function(ctx, amount, item)
    expectItemDelta(ctx, item, serverAdmin(ctx) and -amount or 0)
end)

local function gradeLevel(grade)
    if type(grade) == 'table' then return tonumber(grade.level) end
    return tonumber(grade)
end
K.step('my gang should be {string} at grade {int} for admin staff and grade {int} otherwise', 'server', function(ctx, name, adminGrade, otherGrade)
    local expected = serverAdmin(ctx) and adminGrade or otherGrade
    ctx:waitUntil(function()
        local gang = K.player(ctx).gang or {}
        return gang.name == name and gradeLevel(gang.grade) == expected
    end, ('Gang is not %s at grade %d'):format(name, expected), 3000)
end)

-- ---------------------------------------------------------------------------
-- Client: one command, one answer, decided by the learned staff level
-- ---------------------------------------------------------------------------

-- Gates as named in config.lua Config.permissions.roles; 'user' means every player.
local function gateRank(gate)
    local held = RANKS[gate]
    assert(held, 'Unknown staff gate "' .. tostring(gate) .. '"; use user, support, moderator, admin or owner')
    return held
end
local function allowed(ctx, gate) return rank(ctx) >= gateRank(gate) end

-- kora_lib/modules/commands/server.lua:93-101 checks the gate before the argument
-- count and before the handler, so a player below the gate only ever gets DENIED.
K.step('the admin command {string} should answer {string} to {string} staff and be refused to everyone else', 'client',
    function(ctx, command, answer, gate)
        local staff = allowed(ctx, gate)
        run(command)
        if staff then
            -- kora_weathersync/server/commands.lua:45 also registers /time in the one
            -- kora_lib command registry; the resource that registers last owns it.
            -- Its refusal (kora_weathersync/server/state.lua:57) is equally valid.
            local name = command:match('^(%S+)')
            if name == 'time' and GetResourceState('kora_weathersync') == 'started' then
                local alternative = 'hour must be 0-23 and minute must be 0-59'
                ctx:waitUntil(function()
                    for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
                        if K.contains(entry.message, answer) or K.contains(entry.message, alternative) then return true end
                    end
                end, ('No notification containing "%s" (kora_admin) or "%s" (kora_weathersync)'):format(answer, alternative), 6000)
                return
            end
            K.waitNotification(ctx, answer, 6000)
        else
            expectDenied(ctx)
        end
    end)

-- Entries whose message starts with one of `prefixes`, in arrival order.
local function prefixed(ctx, prefixes)
    local out = {}
    for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
        local message = type(entry.message) == 'string' and entry.message or ''
        for key, prefix in pairs(prefixes) do
            if message:sub(1, #prefix) == prefix then out[#out + 1] = key break end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Client: needs, heal, armour (server/commands/player.lua, moderation.lua, self.lua)
-- ---------------------------------------------------------------------------

local function clientMeta(key)
    return tonumber(exports.kora_core:getPlayerData({ 'metadata', key }))
end

-- player.lua:45-64: /sethunger|/setthirst <id> <0-100> sets the metadata and
-- answers "Set <name>'s <need> to <value>". Needs decay over time, so the value
-- may sit up to 2 below what was set by the time it is read.
K.step('setting my {string} to {string} with the admin command should work for admin staff only', 'client', function(ctx, need, value)
    assert(need == 'hunger' or need == 'thirst', 'Need must be hunger or thirst')
    local target = assert(tonumber(value), 'Value must be a number')
    local staff = allowed(ctx, 'admin')
    local before = clientMeta(need)
    run(('set%s me %s'):format(need, value))
    if staff then
        K.waitNotification(ctx, ("'s %s to %s"):format(need, value), 6000)
        ctx:waitUntil(function()
            local now = clientMeta(need)
            return now and now <= target and now >= target - 2
        end, ('%s is %s, expected %s'):format(need, tostring(clientMeta(need)), value), 3000)
    else
        expectDenied(ctx)
        Wait(500)
        local now = clientMeta(need)
        assert(now and before and now <= before and now >= before - 2,
            ('%s changed for a player below admin: %s -> %s'):format(need, tostring(before), tostring(now)))
    end
end)

-- moderation.lua:166-178: /heal relays kora_admin:client:heal (relay.lua:16, full
-- health) and, with Config.heal.restoreNeeds (true in config.lua), sets hunger
-- and thirst to 100 before answering "Healed <name>".
K.step('healing myself should restore my health and needs for moderators only', 'client', function(ctx)
    local staff = isMod(ctx)
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    ctx:cleanup(function()
        local now = PlayerPedId()
        if not IsPedDeadOrDying(now, true) then SetEntityHealth(now, health) end
    end)
    local hunger, thirst = clientMeta('hunger'), clientMeta('thirst')
    assert(hunger and hunger < 90 and thirst and thirst < 90, 'Set hunger and thirst below 90 first')
    run('heal me')
    if staff then
        K.waitNotification(ctx, 'Healed ', 6000)
        ctx:waitUntil(function() return (clientMeta('hunger') or 0) >= 98 and (clientMeta('thirst') or 0) >= 98 end,
            ('Needs not restored: hunger %s, thirst %s'):format(tostring(clientMeta('hunger')), tostring(clientMeta('thirst'))), 3000)
        ctx:waitUntil(function() return GetEntityHealth(PlayerPedId()) == GetEntityMaxHealth(PlayerPedId()) end,
            'Health is not full after /heal', 3000)
    else
        expectDenied(ctx)
        Wait(500)
        assert((clientMeta('hunger') or 0) <= hunger and (clientMeta('thirst') or 0) <= thirst, 'Needs were restored for a player below moderator')
    end
end)

-- self.lua:35 + relay.lua:186: /armor without a value relays nil and the client
-- applies `value or 100`.
K.step('setting my own armour without a value should fill it for staff only', 'client', function(ctx)
    local staff = isMod(ctx)
    local ped = PlayerPedId()
    local before = GetPedArmour(ped)
    ctx:cleanup(function() SetPedArmour(PlayerPedId(), before) end)
    SetPedArmour(ped, 10)
    run('armor')
    if staff then
        ctx:waitUntil(function() return GetPedArmour(PlayerPedId()) == 100 end,
            'Armour is ' .. GetPedArmour(PlayerPedId()) .. ', expected 100', 5000)
    else
        expectDenied(ctx)
        Wait(500)
        ctx:equal(GetPedArmour(PlayerPedId()), 10, 'Armour for a non-staff player')
    end
end)

-- ---------------------------------------------------------------------------
-- Client: toggles (moderation.lua:144-244). Without a state argument each
-- command flips the server's own state (core.lua:22 resolveToggle), so running
-- it twice always ends where it started.
-- ---------------------------------------------------------------------------

local TOGGLES = {
    -- relay.lua:8 FreezeEntityPosition
    freeze = { on = 'Froze ', off = 'Unfroze ',
        native = function() return IsEntityPositionFrozen(PlayerPedId()) end },
    -- relay.lua:58 SetEntityInvincible; no reliable read-back native, the answer is the proof
    god = { on = 'God mode enabled for ', off = 'God mode disabled for ' },
    -- relay.lua:62 SetEntityVisible(ped, not state)
    invisible = { on = 'Invisibility enabled for ', off = 'Invisibility disabled for ',
        native = function() return not IsEntityVisible(PlayerPedId()) end },
    -- kora_core/modules/development/client.lua:68 isDevMode
    devmode = { on = 'Development mode enabled for ', off = 'Development mode disabled for ',
        native = function() return exports.kora_core:isDevMode() == true end },
}

K.step('toggling {string} twice for myself should switch it and switch it back for moderators only', 'client', function(ctx, name)
    local toggle = assert(TOGGLES[name], 'No toggle named ' .. tostring(name))
    local staff = isMod(ctx)
    local prefixes = { on = toggle.on, off = toggle.off }
    if not staff then
        run(name .. ' me')
        expectDenied(ctx)
        Wait(500)
        ctx:equal(#prefixed(ctx, prefixes), 0, 'Toggle answers sent to a non-staff player')
        return
    end
    local flips = 0
    ctx:cleanup(function() if flips == 1 then ExecuteCommand(name .. ' me') end end)
    run(name .. ' me')
    local first = ctx:waitUntil(function() return prefixed(ctx, prefixes)[1] end, 'No answer to /' .. name .. ' me', 6000)
    flips = 1
    if toggle.native then
        ctx:waitUntil(function() return toggle.native() == (first == 'on') end, name .. ' did not take effect on my ped', 3000)
    end
    run(name .. ' me')
    local second = ctx:waitUntil(function() return prefixed(ctx, prefixes)[2] end, 'No answer to the second /' .. name .. ' me', 6000)
    flips = 2
    assert(second ~= first, ('/%s answered "%s" twice instead of switching back'):format(name, first))
    if toggle.native then
        ctx:waitUntil(function() return toggle.native() == (second == 'on') end, name .. ' was not switched back on my ped', 3000)
    end
end)

-- jobgang.lua:43-55: /setduty <id> <on|off> answers "<name> is now on|off duty".
K.step('my job duty should be {string} for moderator staff and {string} otherwise', 'client', function(ctx, staffState, otherState)
    local expected = (isMod(ctx) and staffState or otherState) == 'on'
    ctx:waitUntil(function() return (exports.kora_core:getPlayerData({ 'job', 'onduty' }) == true) == expected end,
        'Job duty is not ' .. (expected and 'on' or 'off'), 3000)
end)

-- ---------------------------------------------------------------------------
-- Client: teleports (teleport.lua:14-94, client/teleport.lua)
-- ---------------------------------------------------------------------------

local function flatDistance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- parseCoordinates (teleport.lua:21) accepts "x y z", "x, y, z", vec3(...) and
-- vector4(...) whose fourth part is a heading. client/teleport.lua:116 records
-- the start for /tpback before every teleport.
local COORD_FORMS = {
    plain = function(x, y, z) return ('%.2f %.2f %.2f'):format(x, y, z) end,
    comma = function(x, y, z) return ('%.2f, %.2f, %.2f'):format(x, y, z) end,
    vec3 = function(x, y, z) return ('vec3(%.2f, %.2f, %.2f)'):format(x, y, z) end,
    vector4 = function(x, y, z, h) return ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(x, y, z, h) end,
}

K.step('teleporting {int} metres east with {string} coordinates and back should work for moderators only', 'client',
    function(ctx, metres, form)
        assert(metres >= 1 and metres <= 10, 'Use a short hop of 1-10 metres')
        local build = assert(COORD_FORMS[form], 'Coordinate form must be plain, comma, vec3 or vector4')
        local staff = isMod(ctx)
        local ped = PlayerPedId()
        assert(not IsPedInAnyVehicle(ped, false), 'Leave the vehicle before teleporting')
        local origin = GetEntityCoords(ped)
        local heading = (GetEntityHeading(ped) + 90.0) % 360.0
        ctx:cleanup(function()
            local now = PlayerPedId()
            if flatDistance(GetEntityCoords(now), origin) > 2.0 then SetEntityCoords(now, origin.x, origin.y, origin.z, false, false, false, false) end
            FreezeEntityPosition(now, false)
            if not IsScreenFadedIn() then DoScreenFadeIn(0) end
        end)
        local target = vector3(origin.x + metres, origin.y, origin.z)
        run('tpcoords ' .. build(target.x, target.y, target.z, heading))
        if not staff then
            expectDenied(ctx)
            Wait(1000)
            assert(flatDistance(GetEntityCoords(PlayerPedId()), origin) < 1.0, 'A non-staff player was teleported')
            return
        end
        ctx:waitUntil(function() return flatDistance(GetEntityCoords(PlayerPedId()), target) < 1.5 and IsScreenFadedIn() end,
            'Did not arrive at the requested coordinates', 10000)
        if form == 'vector4' then
            local diff = math.abs(((GetEntityHeading(PlayerPedId()) - heading + 180.0) % 360.0) - 180.0)
            assert(diff < 5.0, ('Heading is %.1f, expected %.1f'):format(GetEntityHeading(PlayerPedId()), heading))
        end
        run('tpback')
        ctx:waitUntil(function() return flatDistance(GetEntityCoords(PlayerPedId()), origin) < 1.5 and IsScreenFadedIn() end,
            '/tpback did not return me to the start', 10000)
    end)

-- client/teleport.lua:166-176: /tpm with no waypoint answers "no waypoint set".
-- A waypoint the tester had is removed for the check and put back afterwards.
K.step('teleporting to my waypoint without one should be refused for moderators only', 'client', function(ctx)
    local staff = isMod(ctx)
    if IsWaypointActive() then
        local blip = GetFirstBlipInfoId(GetWaypointBlipEnumId())
        local saved = GetBlipInfoIdCoord(blip)
        SetWaypointOff()
        ctx:cleanup(function() SetNewWaypoint(saved.x, saved.y) end)
        ctx:waitUntil(function() return not IsWaypointActive() end, 'The waypoint could not be cleared', 3000)
    end
    local origin = GetEntityCoords(PlayerPedId())
    run('tpm')
    if staff then
        K.waitNotification(ctx, 'no waypoint set', 6000)
    else
        expectDenied(ctx)
    end
    Wait(500)
    assert(flatDistance(GetEntityCoords(PlayerPedId()), origin) < 1.0, 'The tester moved without a waypoint')
end)

-- ---------------------------------------------------------------------------
-- Client: vehicles and spawned entities (vehicle.lua, entities.lua, relay.lua)
-- ---------------------------------------------------------------------------

-- vehicle.lua:217: /fix relays kora_admin:client:fix (relay.lua:65), which sets
-- engine and body health back to 1000.
K.step('repairing my damaged vehicle with the admin command should work for moderators only', 'client', function(ctx)
    local staff = isMod(ctx)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    assert(vehicle ~= 0, 'Sit in a vehicle first')
    SetVehicleEngineHealth(vehicle, 300.0)
    SetVehicleBodyHealth(vehicle, 300.0)
    run('fix')
    if staff then
        K.waitNotification(ctx, 'Repaired your current vehicle', 6000)
        ctx:waitUntil(function() return GetVehicleEngineHealth(vehicle) >= 999.0 and GetVehicleBodyHealth(vehicle) >= 999.0 end,
            'The vehicle was not repaired', 3000)
    else
        expectDenied(ctx)
        Wait(500)
        assert(GetVehicleEngineHealth(vehicle) < 999.0, 'A non-staff player repaired the vehicle')
    end
end)

-- vehicle.lua:91-99 spawns the model server-side, grants keys and seats the
-- caller (relay.lua:118); vehicle.lua:166-180 deletes the vehicle the caller sits in.
K.step('spawning a {string} with the admin command and deleting it again should work for admin staff only', 'client', function(ctx, model)
    local staff = allowed(ctx, 'admin')
    assert(not IsPedInAnyVehicle(PlayerPedId(), false), 'Leave the vehicle before this scenario')
    local hash = GetHashKey(model)
    local spawned
    ctx:cleanup(function()
        if spawned and DoesEntityExist(spawned) then
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == spawned then ExecuteCommand('dv') else
                NetworkRequestControlOfEntity(spawned)
                SetEntityAsMissionEntity(spawned, true, true)
                DeleteVehicle(spawned)
            end
        end
    end)
    run('car ' .. model)
    if not staff then
        expectDenied(ctx)
        Wait(1000)
        assert(not IsPedInAnyVehicle(PlayerPedId(), false), 'A player below admin was given a vehicle')
        return
    end
    K.waitNotification(ctx, 'Spawned ' .. model, 10000)
    spawned = ctx:waitUntil(function()
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle ~= 0 and GetEntityModel(vehicle) == hash then return vehicle end
    end, 'I was not seated in the spawned ' .. model, 10000)
    -- vehicle.lua:166 reads the seat with the server's GetVehiclePedIsIn, which
    -- trails the client by a sync tick; give it a moment. If the server still has
    -- not seen the seat, /dv falls back to the nearest vehicle (vehicle.lua:211),
    -- which is accepted only when that is the spawned one, named by its plate.
    local plate = (GetVehicleNumberPlateText(spawned) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    Wait(1000)
    run('dv')
    ctx:waitUntil(function()
        for _, entry in ipairs(K.ui('notifications', ctx.state.uiBaseline or 0) or {}) do
            if K.contains(entry.message, 'Deleted your current vehicle')
                or (plate ~= '' and K.contains(entry.message, 'Deleted nearby vehicle ' .. plate)) then
                return true
            end
        end
    end, 'No notification that /dv deleted the spawned vehicle ' .. plate, 6000)
    ctx:waitUntil(function() return not DoesEntityExist(spawned) end, 'The spawned vehicle still exists after /dv', 5000)
end)

-- entities.lua:22-47 and relay.lua:79-117: the client spawns a local static
-- entity, remembers the last one and removes it on /deleteentity.
K.step('spawning a {string} entity and deleting it should work for admin staff only', 'client', function(ctx, model)
    local staff = allowed(ctx, 'admin')
    local pending = false
    ctx:cleanup(function() if pending then ExecuteCommand('deleteentity') end end)
    run('entity ' .. model)
    if not staff then
        expectDenied(ctx)
        return
    end
    K.waitNotification(ctx, 'Spawned entity ' .. model, 10000)
    pending = true
    run('deleteentity')
    K.waitNotification(ctx, 'Deleted your last admin-spawned entity', 6000)
    pending = false
    run('deleteentity')
    K.waitNotification(ctx, 'No admin-spawned entity to delete', 6000)
end)

-- ---------------------------------------------------------------------------
-- Client: temporary access on myself (privileged.lua:68-111)
-- ---------------------------------------------------------------------------

-- An admin granting themselves temporary Moderator gains nothing: getLevel
-- (permissions.lua) keeps the higher held role, and syncLevel re-sends it.
K.step('granting and revoking myself temporary moderator access should leave my level unchanged for admin staff only', 'client', function(ctx)
    local staff = allowed(ctx, 'admin')
    local levels = {}
    RegisterNetEvent('kora_admin:client:level')
    ctx:on('kora_admin:client:level', function(level) levels[#levels + 1] = level end)
    local granted = false
    ctx:cleanup(function() if granted then ExecuteCommand('revoketempaccess me moderator') end end)
    run('granttempaccess me moderator 1')
    if not staff then
        expectDenied(ctx)
        Wait(500)
        ctx:equal(#levels, 0, 'Level updates sent to a player below admin')
        return
    end
    K.waitNotification(ctx, 'Granted Moderator access to ', 6000)
    granted = true
    local entry = K.waitNotification(ctx, ' for 1 minute', 1000)
    assert(not K.contains(entry.message, '1 minutes'), 'Singular minute expected: ' .. tostring(entry.message))
    run('revoketempaccess me moderator')
    K.waitNotification(ctx, 'Revoked temporary Moderator access from ', 6000)
    granted = false
    run('revoketempaccess me moderator')
    K.waitNotification(ctx, 'has no temporary Moderator access', 6000)
    ctx:waitUntil(function() return #levels >= 2 end, 'The grant and revoke did not resync my level', 3000)
    for _, level in ipairs(levels) do ctx:equal(level, ctx.state.adminLevel, 'Level after a temporary grant') end
end)

-- ---------------------------------------------------------------------------
-- Client: audit log (world.lua:135-146, audit.lua)
-- ---------------------------------------------------------------------------

-- Each row is printed as "<when> | <action> | <actor> -> <target> | <details>".
K.step('the audit log should list my latest {string} with {string} for admin staff only', 'client', function(ctx, action, detail)
    local staff = allowed(ctx, 'admin')
    local lines = {}
    RegisterNetEvent('chatMessage')
    ctx:on('chatMessage', function(author, _, text)
        if author == '[Admin]' and type(text) == 'string' then lines[#lines + 1] = text end
    end)
    run('adminlog ' .. action)
    if not staff then
        expectDenied(ctx)
        Wait(500)
        ctx:equal(#lines, 0, 'Audit lines sent to a player below admin')
        return
    end
    local me = GetPlayerName(PlayerId())
    ctx:waitUntil(function()
        for _, text in ipairs(lines) do
            if text:find(' | ' .. action .. ' | ' .. me .. ' -> ', 1, true) and text:find(detail, 1, true) then return true end
        end
    end, ('No audit line for %s by %s with %s'):format(action, me, detail), 6000)
end)

-- ---------------------------------------------------------------------------
-- Discord exports (kora_admin/server/discord.lua). discordDispatch is local to
-- kora_admin and refuses any other caller before it touches the handler. The
-- settings export publishes only public identifiers, never the bot token.
-- ---------------------------------------------------------------------------

K.step('the Discord dispatch export should refuse a call from fft', 'server', function(ctx)
    K.started('kora_admin')
    local answered = false
    local ok = K.export('kora_admin', 'discordDispatch', '{}', function() answered = true end)
    ctx:equal(ok, false, 'discordDispatch accepted a call from another resource')
    Wait(200)
    ctx:equal(answered, false, 'the refused dispatch must not call back')
end)

K.step('the Discord settings should publish only an enabled flag and public identifiers', 'server', function(ctx)
    local settings = json.decode(K.export('kora_admin', 'discordSettings'))
    assert(type(settings) == 'table', 'discordSettings did not return a JSON object')
    ctx:equal(type(settings.enabled), 'boolean', 'enabled flag')
    local keys = {}
    for key in pairs(settings) do keys[#keys + 1] = key end
    table.sort(keys)
    ctx:equal(table.concat(keys, ','), 'applicationId,enabled,publicKey', 'published keys')
end)
