-- Offline test of the server console error log: line classification, traceback
-- joining and the per-scenario expected errors (shared/core.lua). Loads the real
-- file with FiveM globals stubbed; the listener glue in server/main.lua (chunk
-- reassembly, the loop over sessions) is not executed here. Usage:
--   lua test/console.lua            (from the fft resource root)
local function load(isServer)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.IsDuplicityVersion = function() return isServer end
    env.GetConvar = function(_, default) return default end
    env.GetCurrentResourceName = function() return 'fft' end
    env.GetInvokingResource = function() return nil end
    env.GetGameTimer = function() return 0 end
    env.AddEventHandler = function() return {} end
    env.exports = setmetatable({}, { __call = function() end })
    for _, file in ipairs({ 'config.lua', 'shared/core.lua' }) do assert(loadfile(file, 't', env))() end
    return env.FFT
end

local FFT = load(true)
local checks, failures = 0, 0
local function check(condition, label)
    checks = checks + 1
    if not condition then failures = failures + 1 io.stderr:write('FAIL ' .. label .. '\n') end
end
local function refused(label, fn)
    local ok = pcall(fn)
    check(not ok, label)
end

-- Mirrors server/main.lua: every running session records the line against its
-- current scenario context, or logs it as an error.
local function harness()
    local h = { track = {}, sessions = {} }
    function h.session(name)
        local s = { name = name, errors = {} }
        h.sessions[#h.sessions + 1] = s
        return s
    end
    function h.line(channel, line, now)
        FFT.consoleLine(h.track, channel, line, now, function(resource, plain)
            local entries = {}
            for _, s in ipairs(h.sessions) do
                local entry = FFT.consoleRecord(s.context, resource, plain, function(e) s.errors[#s.errors + 1] = e return e end)
                if entry then entries[#entries + 1] = entry end
            end
            return entries
        end)
    end
    return h
end

local CLAMP = 'SCRIPT ERROR: @kora_lib/modules/util/shared.lua:144: Kora.util.clamp requires finite bounds where min is at most max.'
local CLAMP_TEXT = 'Kora.util.clamp requires finite bounds where min is at most max.'

-- Validation: plain, single-line, specific.
do
    local ctx = FFT.context('validation', 1, nil, 'native')
    refused('empty text is rejected', function() ctx:expectConsoleError('') end)
    refused('short text is rejected', function() ctx:expectConsoleError('SCRIPT ERROR') end)
    refused('padded short text is rejected', function() ctx:expectConsoleError('      error           ') end)
    refused('punctuation-only text is rejected', function() ctx:expectConsoleError('--------------------') end)
    refused('multi-line text is rejected', function() ctx:expectConsoleError('first line of text\nsecond line of text') end)
    refused('non-string text is rejected', function() ctx:expectConsoleError(12345678901234567890) end)
    refused('over-long text is rejected', function() ctx:expectConsoleError(('x'):rep(301)) end)
    refused('a resource that is not a name is rejected', function() ctx:expectConsoleError(CLAMP_TEXT, 'kora lib') end)
    check(#ctx.expectedConsole == 0, 'rejected expectations are not stored')
    ctx:expectConsoleError(CLAMP_TEXT, 'kora_lib')
    ctx:expectConsoleError('  ' .. CLAMP_TEXT .. '  ', 'kora_lib')
    check(#ctx.expectedConsole == 1, 'a repeated expectation is stored once')
    for i = 2, 8 do ctx:expectConsoleError(('expected refusal number %d'):format(i)) end
    refused('a ninth expectation is rejected', function() ctx:expectConsoleError('expected refusal number 9') end)
    ctx.cancelled = true
    refused('a cancelled context accepts no expectation', function() ctx:expectConsoleError('expected refusal after the end') end)
end

-- Baseline: an undeclared error is logged with its traceback.
do
    local h = harness()
    local s = h.session('a')
    s.context = FFT.context('baseline', 1, nil, 'native')
    h.line('script:kora_lib', '^1' .. CLAMP .. '^7', 1000)
    h.line('script:kora_lib', '> ref (@kora_lib/modules/util/shared.lua:144)', 1010)
    h.line('script:kora_lib', "    [C]: in function 'error'", 1020)
    check(#s.errors == 1, 'an undeclared error is logged once')
    check(s.errors[1].type == 'console' and s.errors[1].resource == 'kora_lib', 'the error names its resource')
    check(s.errors[1].message == CLAMP .. "\n> ref (@kora_lib/modules/util/shared.lua:144)\n    [C]: in function 'error'",
        'colour codes are stripped and the traceback joins the error')
    h.line('script:kora_lib', 'Started resource kora_lib', 1030)
    h.line('script:kora_lib', '[kora_sql:exports] information only', 1040)
    check(#s.errors == 1, 'ordinary output is not logged')
    h.line('citizen-server-impl', 'Server list query returned an error: timeout', 1050)
    check(#s.errors == 1, 'platform chatter is not logged')
end

-- An expected error and its traceback are kept apart from the errors.
do
    local h = harness()
    local s = h.session('a')
    s.context = FFT.context('expected', 1, nil, 'native')
    s.context:expectConsoleError(CLAMP_TEXT, 'kora_lib')
    h.line('script:kora_lib', CLAMP, 1000)
    h.line('script:kora_lib', '> callback (@fft/steps/kora/kora_lib.lua:444)', 1010)
    -- This traceback line contains the word "error": it must join, not be logged.
    h.line('script:kora_lib', "    [C]: in function 'error'", 1020)
    local e = s.context.expectedConsole[1]
    check(#s.errors == 0, 'an expected error is not logged as an error')
    check(e.matched == 1 and #e.lines == 1, 'the expected line is counted and kept')
    check(e.lines[1].message == CLAMP .. "\n> callback (@fft/steps/kora/kora_lib.lua:444)\n    [C]: in function 'error'",
        'the traceback of an expected error is kept with it')

    -- Strict: a different error in the same scenario is still an error.
    h.line('script:kora_lib', 'SCRIPT ERROR: @kora_lib/modules/util/shared.lua:171: Kora.util.randomFloat requires finite bounds where min is at most max.', 2000)
    check(#s.errors == 1, 'a different error is still logged')
    -- Plain text: pattern characters in the expectation are literal.
    s.context:expectConsoleError("Message type '%s' is owned by .*")
    h.line('script:kora_chat', "SCRIPT ERROR: @kora_chat/server/main.lua:265: Message type 'say' is owned by 'kora_chat'.", 3000)
    check(#s.errors == 2, 'expectations are plain text, not patterns')
    -- Resource restriction.
    h.line('script:kora_core', CLAMP, 4000)
    check(#s.errors == 3 and e.matched == 1, 'the same text from another resource is still logged')
    -- Not error-looking output never counts as a match.
    h.line('script:kora_lib', 'note: ' .. CLAMP_TEXT, 5000)
    check(e.matched == 1 and #s.errors == 3, 'a line that is not an error is neither matched nor logged')
    -- A late continuation is not joined.
    h.line('script:kora_lib', CLAMP, 6000)
    h.line('script:kora_lib', "    [C]: in function 'error'", 6400)
    check(e.matched == 2 and #s.errors == 4, 'a traceback line arriving after 250 ms is judged on its own')
    -- Only a bounded number of lines is kept, every match is counted.
    for i = 1, 10 do h.line('script:kora_lib', CLAMP, 7000 + i * 1000) end
    check(e.matched == 12 and #e.lines == 5, 'matches are counted beyond the kept lines')
    check(#s.errors == 4, 'repeats of an expected error stay out of the error log')
end

-- An expectation without a resource matches any channel.
do
    local h = harness()
    local s = h.session('a')
    s.context = FFT.context('any-resource', 1, nil, 'native')
    s.context:expectConsoleError("multi-statement query refused from 'fft'")
    h.line('script:kora_sql', "^1[kora_sql:oxmysql-bridge]^7 multi-statement query refused from 'fft' -- split it. SQL: SELECT 1; SELECT 2", 1000)
    check(#s.errors == 0 and s.context.expectedConsole[1].matched == 1, 'a red line without the word error is matched')
    check(s.context.expectedConsole[1].lines[1].resource == 'kora_sql', 'the kept line names its resource')
end

-- Scope: the next scenario, and another tester's session, see an ordinary error.
do
    local h = harness()
    local a, b = h.session('a'), h.session('b')
    a.context = FFT.context('scenario-1', 1, nil, 'native')
    b.context = FFT.context('other-session', 2, nil, 'native')
    a.context:expectConsoleError(CLAMP_TEXT, 'kora_lib')
    h.line('script:kora_lib', CLAMP, 1000)
    h.line('script:kora_lib', '> ref (@kora_lib/modules/util/shared.lua:144)', 1010)
    check(#a.errors == 0, 'the declaring session does not log the error')
    check(#b.errors == 1 and b.errors[1].message:find('> ref', 1, true) ~= nil, 'another session logs it, traceback included')
    check(#b.context.expectedConsole == 0, 'another session holds no expectation')

    local first = a.context
    FFT.cleanup(first)
    a.context = nil -- between scenarios
    h.line('script:kora_lib', CLAMP, 2000)
    check(#a.errors == 1 and first.expectedConsole[1].matched == 1, 'between scenarios the error is logged')
    a.context = FFT.context('scenario-2', 1, nil, 'native')
    h.line('script:kora_lib', CLAMP, 3000)
    check(#a.errors == 2 and first.expectedConsole[1].matched == 1, 'the next scenario logs the error')
    check(#a.context.expectedConsole == 0, 'a new scenario starts without expectations')
end

-- The console listener is server-side: the client context refuses.
do
    local client = load(false)
    local ctx = client.context('client', 1, nil, 'native')
    refused('a client-realm step cannot declare an expectation', function() ctx:expectConsoleError(CLAMP_TEXT) end)
end

-- Archived report ids become file names: only canonical v4 UUIDs pass.
do
    local server = load(true)
    check(server.reportUuid('3f2b8c1e-9a4d-4c7b-8e21-0a1b2c3d4e5f') == true, 'a v4 uuid is accepted')
    for _, bad in ipairs({ '', '../latest', '3F2B8C1E-9A4D-4C7B-8E21-0A1B2C3D4E5F', '3f2b8c1e-9a4d-1c7b-8e21-0a1b2c3d4e5f',
        '3f2b8c1e-9a4d-4c7b-8e21-0a1b2c3d4e5f/..', '3f2b8c1e-9a4d-4c7b-8e21-0a1b2c3d4e5', 42 }) do
        check(server.reportUuid(bad) == false, 'rejected report id: ' .. tostring(bad))
    end
end

print(('console: %d checks, %d problems'):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
