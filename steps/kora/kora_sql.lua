-- kora_sql: database layer. Strictly read-only: readiness, version, statistics
-- and constant SELECTs through the real exports. Nothing here writes, alters or
-- drops, resets statistics or flushes queues. No resource hook.
local K = FFT.kora
if not K then return end
K.feature('kora_sql')

local READ_TIMEOUT = 10000

local function assertReadOnly(sql)
    local head = sql:match('^%s*(%a+)')
    assert(head and head:upper() == 'SELECT', 'kora_sql test steps only run SELECT statements')
end

-- Runs a callback-style read export and waits for its `cb(result, err)`.
local function read(ctx, resource, method, sql, params)
    assertReadOnly(sql)
    local reply = { done = false }
    local ok, failure = pcall(function()
        exports[resource][method](exports[resource], sql, params or {}, function(result, err)
            reply.result, reply.err, reply.done = result, err, true
        end)
    end)
    if not ok then error(('exports.%s:%s failed: %s'):format(resource, method, tostring(failure)), 0) end
    ctx:waitUntil(function() return reply.done end,
        ('exports.%s:%s did not answer "%s"'):format(resource, method, sql), READ_TIMEOUT)
    return reply.result, reply.err
end

local function remember(ctx, result, err)
    ctx.state.sqlAnswered, ctx.state.sqlResult, ctx.state.sqlError = true, result, err
end

local function answered(ctx)
    assert(ctx.state.sqlAnswered, 'Run a database read first')
    return ctx.state.sqlResult, ctx.state.sqlError
end

local function totalQueries()
    local stats = K.export('kora_sql', 'stats')
    assert(type(stats) == 'table' and type(stats.queries) == 'table', 'stats() returned no query counters')
    assert(type(stats.queries.total) == 'number', 'stats().queries.total is not a number')
    return stats.queries.total, stats
end

K.step('the database layer should be ready', 'server', function()
    assert(K.export('kora_sql', 'isReady') == true, 'exports.kora_sql:isReady() is not true')
end)

K.step('the database layer should report its server version and driver {string}', 'server', function(ctx, driver)
    local version = K.export('kora_sql', 'version')
    assert(type(version) == 'table', 'version() did not return a table')
    ctx:equal(version.driver, driver, 'Driver')
    assert(type(version.server) == 'string' and version.server ~= '' and version.server ~= 'starting',
        'Database server version is ' .. tostring(version.server))
    assert(type(version.isMariaDB) == 'boolean', 'version().isMariaDB is not a boolean')
end)

K.step('I read the database scalar {string}', 'server', function(ctx, sql)
    remember(ctx, read(ctx, 'kora_sql', 'scalar', sql, {}))
end)
K.step('I read the database scalar {string} with the parameter {int}', 'server', function(ctx, sql, value)
    remember(ctx, read(ctx, 'kora_sql', 'scalar', sql, { value }))
end)
K.step('I read the database rows {string}', 'server', function(ctx, sql)
    remember(ctx, read(ctx, 'kora_sql', 'query', sql, {}))
end)
K.step('I read the single database row {string}', 'server', function(ctx, sql)
    remember(ctx, read(ctx, 'kora_sql', 'single', sql, {}))
end)
K.step('I read the database scalar {string} through the oxmysql bridge', 'server', function(ctx, sql)
    remember(ctx, read(ctx, 'oxmysql', 'scalar', sql, {}))
end)

K.step('the database read should answer the number {int}', 'server', function(ctx, expected)
    local result, err = answered(ctx)
    assert(err == nil, 'Database read failed: ' .. tostring(err))
    -- Drivers may return integers, BIGINT strings or floats for a constant.
    ctx:equal(tonumber(result), expected, 'Scalar result')
end)
K.step('the database read should answer exactly {int} rows', 'server', function(ctx, expected)
    local result, err = answered(ctx)
    assert(err == nil, 'Database read failed: ' .. tostring(err))
    assert(type(result) == 'table', 'Query did not return a row list')
    ctx:equal(#result, expected, 'Row count')
end)
K.step('database row {int} should have {string} equal to the number {int}', 'server', function(ctx, index, column, expected)
    local result = answered(ctx)
    local row = type(result) == 'table' and result[index]
    assert(type(row) == 'table', 'There is no row ' .. index)
    ctx:equal(tonumber(row[column]), expected, 'Column ' .. column)
end)
K.step('the database read should answer no row', 'server', function(ctx)
    local result, err = answered(ctx)
    assert(err == nil, 'Database read failed: ' .. tostring(err))
    assert(result == nil, 'Expected no row, got ' .. type(result))
end)
K.step('the database read should fail with an error', 'server', function(ctx)
    local result, err = answered(ctx)
    assert(result == nil, 'The read returned a result instead of failing')
    assert(type(err) == 'string' and err ~= '', 'The read failed without an error message')
end)

K.step('I remember how many database queries were counted', 'server', function(ctx)
    ctx.state.sqlTotal = totalQueries()
end)
K.step('the counted database queries should have grown', 'server', function(ctx)
    local before = assert(ctx.state.sqlTotal, 'Remember the query count first')
    ctx:waitUntil(function() return totalQueries() > before end,
        'stats().queries.total did not grow after a read', 3000)
end)
K.step('the database statistics should include error and queue counters', 'server', function()
    local _, stats = totalQueries()
    assert(type(stats.queries.errors) == 'number', 'stats().queries.errors is not a number')
    assert(type(stats.queue) == 'table', 'stats().queue is missing')
end)
K.step('the slow query log should answer a list of at most {int} entries', 'server', function(_, limit)
    local slow = K.export('kora_sql', 'slowQueries', limit)
    assert(type(slow) == 'table', 'slowQueries() did not return a list')
    assert(#slow <= limit, ('slowQueries(%d) returned %d entries'):format(limit, #slow))
end)

K.step('my character should have no active database operation', 'server', function(ctx)
    local citizenid = K.player(ctx).citizenid
    ctx:waitUntil(function() return K.export('kora_sql', 'hasActivePlayerOperation', citizenid) == false end,
        'hasActivePlayerOperation stayed true for the idle tester', 5000)
end)

-- The oxmysql bridge refuses anything that looks like two statements before it
-- reaches the database. Both statements are constant SELECTs in case the server
-- has opted in to multi-statement queries.
K.step('the oxmysql bridge should refuse the two-statement read {string}', 'server', function(ctx, sql)
    assertReadOnly(sql)
    for statement in sql:gmatch('[^;]+') do
        if statement:match('%S') then assertReadOnly(statement) end
    end
    local allowed = GetConvar('kora_sql_allow_multiple_statements', ''):lower()
    if allowed == 'true' or allowed == '1' or allowed == 'yes' then
        error('kora_sql_allow_multiple_statements is enabled on this server; this refusal does not apply', 0)
    end
    -- The bridge prints the refusal in red before answering. Text from
    -- kora_sql/server/compat/oxmysql.lua:86 (the caller it names is this resource).
    K.expectConsoleError(ctx, ("multi-statement query refused from '%s'"):format(GetCurrentResourceName()), 'kora_sql')
    local result, err = read(ctx, 'oxmysql', 'query', sql, {})
    assert(result == nil, 'The bridge answered a two-statement query (is Config.compat.allowMultipleStatements enabled in kora_sql?)')
    ctx:equal(err, 'multi-statement refused', 'Refusal reason')
end)

-- ---------------------------------------------------------------------------
-- Round 3. Still read-only: every statement is a SELECT (checked by
-- assertReadOnly), transactions only wrap SELECTs, and nothing resets
-- statistics, flushes queues, warms the statement cache or creates tables.
-- Sources: kora_sql/server/js/exports.js (export surface and callback shape),
-- execute.js (parameters, result shapes), transaction.js, stats.js, schema.js,
-- typecast.js and server/compat/*.lua (legacy bridges).
-- ---------------------------------------------------------------------------

local SELF_SQL = 'kora_sql'

-- Calls a callback-style export with arbitrary leading arguments and waits for
-- `cb(result, err)`. The caller has already checked the SQL is a SELECT.
local function call(ctx, resource, method, ...)
    local reply = { done = false }
    local args = table.pack(...)
    local ok, failure = pcall(function()
        args[args.n + 1] = function(result, err) reply.result, reply.err, reply.done = result, err, true end
        exports[resource][method](exports[resource], table.unpack(args, 1, args.n + 1))
    end)
    if not ok then error(('exports.%s:%s failed: %s'):format(resource, method, tostring(failure)), 0) end
    ctx:waitUntil(function() return reply.done end, ('exports.%s:%s did not answer'):format(resource, method), READ_TIMEOUT)
    return reply.result, reply.err
end

local function readOnlyList(list)
    for _, sql in ipairs(list) do assertReadOnly(sql) end
end

local function ok(ctx)
    local result, err = answered(ctx)
    assert(err == nil, 'Database read failed: ' .. tostring(err))
    return result
end

local function row(ctx, index)
    local result = ok(ctx)
    local entry = type(result) == 'table' and result[index]
    assert(type(entry) == 'table', 'There is no row ' .. index)
    return entry
end

local function oxTypeCastOn()
    -- getBoolConvar in server/js/config.js: unset means the default (true).
    local raw = GetConvar('kora_sql_ox_typecast', '')
    if raw ~= '' and raw ~= 'true' and raw ~= '1' and raw ~= 'yes' then
        error('kora_sql_ox_typecast is disabled on this server; the oxmysql conversions do not apply', 0)
    end
end

-- Days from 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's algorithm).
local function epochDays(y, m, d)
    y = m <= 2 and y - 1 or y
    local era = (y >= 0 and y or y - 399) // 400
    local yoe = y - era * 400
    local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end
local function utcMillis(text)
    local y, mo, d, h, mi, s = text:match('^(%d+)%-(%d+)%-(%d+)%s*(%d*):?(%d*):?(%d*)$')
    assert(y, 'Use YYYY-MM-DD or YYYY-MM-DD HH:MM:SS')
    local seconds = epochDays(tonumber(y), tonumber(mo), tonumber(d)) * 86400
        + (tonumber(h) or 0) * 3600 + (tonumber(mi) or 0) * 60 + (tonumber(s) or 0)
    return seconds * 1000
end

-- Readiness and identity -----------------------------------------------------

K.step('the database layer should report the same server version as the database itself', 'server', function(ctx)
    local version = K.export(SELF_SQL, 'version')
    local live, err = read(ctx, SELF_SQL, 'scalar', 'SELECT VERSION() AS v', {})
    assert(err == nil, 'SELECT VERSION() failed: ' .. tostring(err))
    ctx:equal(version.server, live, 'version().server')
    ctx:equal(version.isMariaDB, live:lower():find('mariadb', 1, true) ~= nil, 'version().isMariaDB')
end)
K.step('the database layer should confirm readiness through its ready callback', 'server', function(ctx)
    local ready, err = call(ctx, SELF_SQL, 'awaitReady')
    ctx:equal(ready, true, 'awaitReady result')
    ctx:equal(err, nil, 'awaitReady error')
end)
-- server/compat/oxmysql.lua isReady and server/compat/mysql-async.lua is_ready.
K.step('the {string} bridge should report the database as ready', 'server', function(_, bridge)
    local method = ({ oxmysql = 'isReady', ['mysql-async'] = 'is_ready' })[bridge]
    assert(method, 'Use the oxmysql or mysql-async bridge')
    K.started(SELF_SQL)
    local okCall, ready = pcall(function() return exports[bridge][method](exports[bridge]) end)
    assert(okCall, ('exports[%q]:%s failed: %s'):format(bridge, method, tostring(ready)))
    assert(ready == true, ('exports[%q]:%s returned %s'):format(bridge, method, tostring(ready)))
end)
K.step('the character {string} should have no active database operation', 'server', function(_, citizenid)
    assert(K.export(SELF_SQL, 'hasActivePlayerOperation', citizenid) == false, 'hasActivePlayerOperation is not false for ' .. citizenid)
end)

-- Parameters -----------------------------------------------------------------

K.step('I read the database scalar {string} with the text parameter {string}', 'server', function(ctx, sql, value)
    assertReadOnly(sql)
    remember(ctx, read(ctx, SELF_SQL, 'scalar', sql, { value }))
end)
K.step('I read the database scalar {string} with a {int} character text parameter', 'server', function(ctx, sql, length)
    assertReadOnly(sql)
    assert(length >= 1 and length <= 4000, 'Use 1-4000 characters')
    remember(ctx, read(ctx, SELF_SQL, 'scalar', sql, { string.rep('k', length) }))
end)
K.step('I read the database scalar {string} with the parameters {int} and {int}', 'server', function(ctx, sql, a, b)
    remember(ctx, read(ctx, SELF_SQL, 'scalar', sql, { a, b }))
end)
-- normalizeNamedPlaceholders (execute.js) accepts name, :name and @name keys.
K.step('I read the database scalar {string} with the named parameter {string} set to {int}', 'server', function(ctx, sql, key, value)
    assert(key:match('^[@:]?[%a_][%w_]*$'), 'Use a plain, :name or @name key')
    remember(ctx, read(ctx, SELF_SQL, 'scalar', sql, { [key] = value }))
end)
-- A Lua table with a hole crosses as a map with numeric keys; normalizeParams
-- (execute.js) turns it into a positional list with NULL in the gap.
K.step('I read the database rows {string} with only the parameters 1 and 3 set to {int} and {int}', 'server', function(ctx, sql, first, third)
    remember(ctx, read(ctx, SELF_SQL, 'query', sql, { [1] = first, [3] = third }))
end)
-- An ordinary read sends a list bind over the binary protocol (docs.md
-- "Protocol choice").
K.step('I read the database scalar {string} with the list parameter {int}, {int} and {int}', 'server', function(ctx, sql, a, b, c)
    remember(ctx, read(ctx, SELF_SQL, 'scalar', sql, { { a, b, c } }))
end)
-- batch() runs on the transaction runner, whose runOnConnection switches to the
-- text protocol for list and object binds (execute.js needsTextProtocol). The
-- first statement's row list is remembered as the read's answer.
local function batchOne(ctx, sql, params)
    assertReadOnly(sql)
    local result, err = call(ctx, SELF_SQL, 'batch', { { sql, params } }, {})
    remember(ctx, type(result) == 'table' and result[1] or result, err)
end
K.step('I run the database read {string} as a batch with the list parameter {int}, {int} and {int}', 'server', function(ctx, sql, a, b, c)
    batchOne(ctx, sql, { { a, b, c } })
end)
K.step('I run the database read {string} as a batch with an object parameter whose {string} is {int}', 'server', function(ctx, sql, key, value)
    batchOne(ctx, sql, { { [key] = value } })
end)
K.step('database row {int} should have {string} as JSON text whose {string} is the number {int}', 'server', function(ctx, index, column, key, expected)
    local value = row(ctx, index)[column]
    assert(type(value) == 'string', ('Column %s is %s, expected JSON text'):format(column, type(value)))
    local decoded = json.decode(value)
    assert(type(decoded) == 'table', 'Column is not a JSON object: ' .. value)
    ctx:equal(tonumber(decoded[key]), expected, 'JSON ' .. key)
end)

-- Other read exports -----------------------------------------------------------

K.step('I prepare the database read {string} with the parameter {int}', 'server', function(ctx, sql, value)
    assertReadOnly(sql)
    remember(ctx, call(ctx, SELF_SQL, 'prepare', sql, { value }))
end)
K.step('I prepare the database read {string} with the parameter sets {int} and {int}', 'server', function(ctx, sql, a, b)
    assertReadOnly(sql)
    remember(ctx, call(ctx, SELF_SQL, 'prepare', sql, { { a }, { b } }))
end)
K.step('I run the database read {string} through the {word} export', 'server', function(ctx, sql, method)
    assert(({ execute = true, update = true, insert = true })[method], 'Use the execute, update or insert export')
    assertReadOnly(sql)
    remember(ctx, call(ctx, SELF_SQL, method, sql, {}))
end)
K.step('the execute answer should report 0 affected rows and {int} rows', 'server', function(ctx, count)
    local result = ok(ctx)
    assert(type(result) == 'table', 'execute() returned no table')
    ctx:equal(result.affectedRows, 0, 'affectedRows')
    ctx:equal(result.insertId, 0, 'insertId')
    assert(type(result.rows) == 'table', 'execute() on a read carries no rows')
    ctx:equal(#result.rows, count, 'Row count')
end)
-- store() keeps the text in memory and returns a numeric handle (index.js HandleStore).
K.step('I store the database read {string} and run it with the parameter {int}', 'server', function(ctx, sql, value)
    assertReadOnly(sql)
    local handle = K.export(SELF_SQL, 'store', sql)
    assert(math.type(handle) == 'integer' and handle > 0, 'store() returned no handle: ' .. tostring(handle))
    remember(ctx, call(ctx, SELF_SQL, 'rawExecute', handle, { value }))
end)
K.step('I run the unknown stored statement handle {int}', 'server', function(ctx, handle)
    assert(handle >= 100000000, 'Use a handle far above any issued one')
    remember(ctx, call(ctx, SELF_SQL, 'rawExecute', handle, {}))
end)
K.step('I run the database reads {string} and {string} as a batch', 'server', function(ctx, first, second)
    readOnlyList({ first, second })
    remember(ctx, call(ctx, SELF_SQL, 'batch', { first, second }, {}))
end)
K.step('batch result {int} should have {string} equal to the number {int}', 'server', function(ctx, index, column, expected)
    local result = ok(ctx)
    local rows = type(result) == 'table' and result[index]
    assert(type(rows) == 'table' and type(rows[1]) == 'table', 'Batch result ' .. index .. ' has no row')
    ctx:equal(tonumber(rows[1][column]), expected, 'Column ' .. column)
end)

-- Result shapes ----------------------------------------------------------------

K.step('the database read should answer the text {string}', 'server', function(ctx, expected)
    ctx:equal(ok(ctx), expected, 'Text result')
end)
K.step('the database read should answer a text of {int} characters', 'server', function(ctx, length)
    local result = ok(ctx)
    assert(type(result) == 'string', 'Result is not text: ' .. type(result))
    ctx:equal(#result, length, 'Text length')
end)
K.step('the database read should answer the decimal {float}', 'server', function(ctx, expected)
    local result = ok(ctx)
    -- pool.js sets decimalNumbers: true, so DECIMAL arrives as a number, not text.
    assert(type(result) == 'number', 'DECIMAL result is not a number: ' .. type(result) .. ' ' .. tostring(result))
    assert(math.abs(result - expected) < 1e-9, ('Decimal is %s, expected %s'):format(tostring(result), tostring(expected)))
end)
K.step('the database read should answer an empty value', 'server', function(ctx)
    local result, err = answered(ctx)
    ctx:equal(err, nil, 'Read error')
    ctx:equal(result, nil, 'Result')
end)
K.step('the database read should answer the numbers {int} and {int}', 'server', function(ctx, a, b)
    local result = ok(ctx)
    assert(type(result) == 'table', 'Expected a list of results, got ' .. type(result))
    ctx:equal(#result, 2, 'Result count')
    ctx:equal(tonumber(result[1]), a, 'First result')
    ctx:equal(tonumber(result[2]), b, 'Second result')
end)
K.step('the database read should answer a row with {string} equal to the number {int}', 'server', function(ctx, column, expected)
    local result = ok(ctx)
    assert(type(result) == 'table' and result[column] ~= nil, 'The answer is not a row with ' .. column)
    ctx:equal(tonumber(result[column]), expected, 'Column ' .. column)
end)
K.step('database row {int} should have {string} equal to the text {string}', 'server', function(ctx, index, column, expected)
    ctx:equal(row(ctx, index)[column], expected, 'Column ' .. column)
end)
K.step('database row {int} should have no {string}', 'server', function(ctx, index, column)
    ctx:equal(row(ctx, index)[column], nil, 'Column ' .. column)
end)
K.step('the database read should answer JSON text whose {string} is the number {int}', 'server', function(ctx, key, expected)
    local result = ok(ctx)
    assert(type(result) == 'string', 'Expected JSON text, got ' .. type(result))
    local decoded = json.decode(result)
    assert(type(decoded) == 'table', 'Result is not a JSON object: ' .. result)
    ctx:equal(tonumber(decoded[key]), expected, 'JSON ' .. key)
end)
-- typecast.js converts DATETIME/DATE with new Date(text).getTime(), i.e. in the
-- server process's own time zone, so allow any offset up to 14 hours.
K.step('the database read should answer a millisecond timestamp for {string} in some time zone', 'server', function(ctx, text)
    local result = ok(ctx)
    assert(type(result) == 'number', 'Expected a millisecond timestamp, got ' .. type(result) .. ' ' .. tostring(result))
    local delta = math.abs(result - utcMillis(text))
    assert(delta <= 14 * 3600 * 1000, ('Timestamp %s is %d ms from %s UTC'):format(tostring(result), delta, text))
    ctx:equal(delta % (15 * 60 * 1000), 0, 'Offset is a whole number of quarter hours')
end)
K.step('the database read should fail with an error containing {string}', 'server', function(ctx, text)
    local result, err = answered(ctx)
    ctx:equal(result, nil, 'Result')
    assert(K.contains(err, text), ('Error is "%s", expected it to contain "%s"'):format(tostring(err), text))
end)

-- Legacy bridges -------------------------------------------------------------------

-- Every export named here is registered by kora_sql/server/compat/*.lua.
local LEGACY_READS = {
    oxmysql = { query = true, single = true, scalar = true, prepare = true, fetch = true },
    ['mysql-async'] = { mysql_fetch_all = true, mysql_fetch_scalar = true },
    ghmattimysql = { execute = true, scalar = true },
}
local LEGACY_BLOCKING = {
    oxmysql = { scalarSync = true, querySync = true, singleSync = true },
    ghmattimysql = { scalarSync = true, executeSync = true },
}
local function legacyMethod(table_, bridge, method)
    assert(table_[bridge] and table_[bridge][method], ('%s is not a read export of the %s bridge'):format(method, bridge))
    K.started(SELF_SQL)
end
K.step('I read {string} through the legacy {string} export {string}', 'server', function(ctx, sql, bridge, method)
    assertReadOnly(sql)
    legacyMethod(LEGACY_READS, bridge, method)
    remember(ctx, read(ctx, bridge, method, sql, {}))
end)
K.step('I read {string} with the parameter {int} through the legacy {string} export {string}', 'server', function(ctx, sql, value, bridge, method)
    assertReadOnly(sql)
    legacyMethod(LEGACY_READS, bridge, method)
    remember(ctx, read(ctx, bridge, method, sql, { value }))
end)
-- The *Sync exports block on Citizen.Await and answer directly, nil on failure.
K.step('I read {string} through the blocking legacy {string} export {string}', 'server', function(ctx, sql, bridge, method)
    assertReadOnly(sql)
    legacyMethod(LEGACY_BLOCKING, bridge, method)
    local okCall, result = pcall(function() return exports[bridge][method](exports[bridge], sql, {}) end)
    if not okCall then error(('exports[%q]:%s failed: %s'):format(bridge, method, tostring(result)), 0) end
    remember(ctx, result, nil)
end)
K.step('the oxmysql bridge typecast is enabled', 'server', function() oxTypeCastOn() end)

-- Same refusal as the existing query step, for the other guarded oxmysql exports
-- (guarded() in server/compat/oxmysql.lua wraps query, scalar, single, insert,
-- update and prepare).
K.step('the oxmysql bridge {word} export should refuse the two-statement read {string}', 'server', function(ctx, method, sql)
    assert(({ scalar = true, single = true, prepare = true })[method], 'Use scalar, single or prepare')
    for statement in sql:gmatch('[^;]+') do
        if statement:match('%S') then assertReadOnly(statement) end
    end
    local allowed = GetConvar('kora_sql_allow_multiple_statements', ''):lower()
    if allowed == 'true' or allowed == '1' or allowed == 'yes' then
        error('kora_sql_allow_multiple_statements is enabled on this server; this refusal does not apply', 0)
    end
    -- server/compat/oxmysql.lua:86.
    K.expectConsoleError(ctx, ("multi-statement query refused from '%s'"):format(GetCurrentResourceName()), SELF_SQL)
    local result, err = read(ctx, 'oxmysql', method, sql, {})
    ctx:equal(result, nil, 'Bridge answer')
    ctx:equal(err, 'multi-statement refused', 'Refusal reason')
end)

-- Transactions over SELECTs only ------------------------------------------------------

K.step('I run the database reads {string} and {string} in a transaction', 'server', function(ctx, first, second)
    readOnlyList({ first, second })
    local runner = GetCurrentResourceName()
    -- transaction.js emits oxmysql:transaction-error after a rollback.
    K.capture(ctx, 'oxmysql:transaction-error', function(info) return type(info) == 'table' and info.resource == runner end)
    remember(ctx, call(ctx, SELF_SQL, 'transaction', { first, second }, {}))
end)
K.step('the database transaction should have committed', 'server', function(ctx)
    ctx:equal(ok(ctx), true, 'transaction() result')
    Wait(300)
    ctx:equal(#K.captured(ctx, 'oxmysql:transaction-error'), 0, 'Transaction error events')
end)
K.step('the database transaction should have rolled back reporting {string}', 'server', function(ctx, text)
    ctx:equal(ok(ctx), false, 'transaction() result')
    local info = ctx:waitUntil(function() return K.captured(ctx, 'oxmysql:transaction-error')[1] end,
        'No oxmysql:transaction-error event for this runner', 3000)[1]
    assert(K.contains(info.message, text), ('Transaction error is "%s", expected "%s"'):format(tostring(info.message), text))
    assert(K.contains(info.query, 'SELECT'), 'Transaction error carries no statement list')
end)

local function checkedQuery(sql, expected, code)
    assertReadOnly(sql)
    return { query = sql, expectedRows = expected, failureCode = code }
end
K.step('I run the checked database read {string}', 'server', function(ctx, sql)
    remember(ctx, call(ctx, SELF_SQL, 'transactionChecked', { checkedQuery(sql) }, nil))
end)
K.step('I run the checked database read {string} expecting {int} rows', 'server', function(ctx, sql, expected)
    remember(ctx, call(ctx, SELF_SQL, 'transactionChecked', { checkedQuery(sql, expected) }, nil))
end)
K.step('I run the checked database read {string} expecting {int} rows with the failure code {string}', 'server', function(ctx, sql, expected, code)
    assert(code:match('^fft_[%w_]+$'), 'Test failure codes start with fft_')
    remember(ctx, call(ctx, SELF_SQL, 'transactionChecked', { checkedQuery(sql, expected, code) }, nil))
end)
K.step('I run an empty checked database transaction', 'server', function(ctx)
    remember(ctx, call(ctx, SELF_SQL, 'transactionChecked', {}, nil))
end)
K.step('the checked database operation should succeed with {int} result', 'server', function(ctx, count)
    local result = ok(ctx)
    assert(type(result) == 'table', 'transactionChecked returned no table')
    ctx:equal(result.success, true, 'success')
    ctx:equal(#(result.results or {}), count, 'Result count')
end)
K.step('the checked database operation should fail with the code {string} at statement {int}', 'server', function(ctx, code, statement)
    local result = ok(ctx)
    assert(type(result) == 'table', 'transactionChecked returned no table')
    ctx:equal(result.success, false, 'success')
    ctx:equal(result.code, code, 'code')
    ctx:equal(result.statement, statement, 'statement')
end)
K.step('the checked database operation message should be {string}', 'server', function(ctx, message)
    ctx:equal((ok(ctx) or {}).message, message, 'message')
end)

-- An operation key claims the tester's citizenid while a 2 s SELECT SLEEP runs
-- (transaction.js checkedInFlight). Nothing is written; the claim ends with it.
local SLEEP_SQL = 'SELECT SLEEP(2) AS fft_checked_sleep'
K.step('I start a slow checked database read claimed for my character', 'server', function(ctx)
    local citizenid = K.player(ctx).citizenid
    local key = ('fft_sql:%s:%d'):format(tostring(ctx.id), GetGameTimer())
    local slow = { done = false, citizenid = citizenid, key = key }
    ctx.state.sqlSlowOperation = slow
    exports.kora_sql:transactionChecked({ { query = SLEEP_SQL } },
        { key = key, fingerprint = 'fft-a', citizenids = { citizenid } },
        function(result, err) slow.result, slow.err, slow.done = result, err, true end)
    -- Let the claim settle before the scenario ends, whatever happens next.
    ctx:cleanup(function()
        local deadline = GetGameTimer() + 4000
        while not slow.done and GetGameTimer() < deadline do Wait(50) end
    end)
end)
local function slowOperation(ctx) return assert(ctx.state.sqlSlowOperation, 'Start the slow checked read first') end
K.step('my character should have an active database operation', 'server', function(ctx)
    local slow = slowOperation(ctx)
    ctx:waitUntil(function() return K.export(SELF_SQL, 'hasActivePlayerOperation', slow.citizenid) == true end,
        'hasActivePlayerOperation never became true during the claimed read', 1500)
    assert(not slow.done, 'The slow read finished before it could be observed')
end)
K.step('another request with the same operation key should be refused as indeterminate', 'server', function(ctx)
    local slow = slowOperation(ctx)
    local result, err = call(ctx, SELF_SQL, 'transactionChecked', { { query = 'SELECT 1 AS n' } },
        { key = slow.key, fingerprint = 'fft-b', citizenids = {} })
    assert(err == nil, 'transactionChecked failed: ' .. tostring(err))
    ctx:equal(result.success, false, 'success')
    ctx:equal(result.code, 'indeterminate', 'code')
    ctx:equal(result.message, 'Another request owns this operation key', 'message')
    assert(not slow.done, 'The slow read finished before the duplicate was refused')
end)
K.step('waiting on the operation key with another fingerprint should report it indeterminate', 'server', function(ctx)
    local slow = slowOperation(ctx)
    local result, err = call(ctx, SELF_SQL, 'awaitCheckedOperation', slow.key, 'fft-b')
    assert(err == nil, 'awaitCheckedOperation failed: ' .. tostring(err))
    ctx:equal(result.active, true, 'active')
    ctx:equal((result.result or {}).code, 'indeterminate', 'code')
end)
K.step('the slow checked database read should succeed', 'server', function(ctx)
    local slow = slowOperation(ctx)
    ctx:waitUntil(function() return slow.done end, 'The slow checked read did not finish', 6000)
    assert(slow.err == nil, 'The slow checked read failed: ' .. tostring(slow.err))
    ctx:equal(slow.result.success, true, 'success')
end)
K.step('the operation key should no longer be active', 'server', function(ctx)
    local slow = slowOperation(ctx)
    local result, err = call(ctx, SELF_SQL, 'awaitCheckedOperation', slow.key, nil)
    assert(err == nil, 'awaitCheckedOperation failed: ' .. tostring(err))
    ctx:equal(result.active, false, 'active')
    ctx:waitUntil(function() return K.export(SELF_SQL, 'hasActivePlayerOperation', slow.citizenid) == false end,
        'hasActivePlayerOperation stayed true after the read finished', 2000)
end)
K.step('waiting for checked operations with the prefix {string} should settle {int}', 'server', function(ctx, prefix, count)
    assert(prefix:match('^fft_'), 'Use an fft_ prefix')
    local result, err = call(ctx, SELF_SQL, 'awaitCheckedOperations', prefix)
    assert(err == nil, 'awaitCheckedOperations failed: ' .. tostring(err))
    ctx:equal(result.settled, count, 'settled')
end)
K.step('I wait for checked operations without a prefix', 'server', function(ctx)
    remember(ctx, call(ctx, SELF_SQL, 'awaitCheckedOperations', ''))
end)

-- Schema reads (information_schema only) ------------------------------------------------

-- index.js creates both tables at boot.
K.step('the database tables {string} and {string} should exist', 'server', function(ctx, first, second)
    local result, err = call(ctx, SELF_SQL, 'awaitTables', { first, second }, 2000)
    assert(err == nil, 'awaitTables failed: ' .. tostring(err))
    ctx:equal(result, true, 'awaitTables result')
end)
K.step('I wait {int} milliseconds for the database table {string}', 'server', function(ctx, timeout, name)
    assert(timeout >= 100 and timeout <= 3000, 'Use a 100-3000 ms timeout')
    remember(ctx, call(ctx, SELF_SQL, 'awaitTables', { name }, timeout))
end)

-- Statistics ------------------------------------------------------------------------------------

K.step('I remember the database error count', 'server', function(ctx)
    local _, stats = totalQueries()
    ctx.state.sqlErrors = stats.queries.errors
end)
K.step('the database error count should have grown', 'server', function(ctx)
    local before = assert(ctx.state.sqlErrors, 'Remember the error count first')
    ctx:waitUntil(function()
        local _, stats = totalQueries()
        return stats.queries.errors > before
    end, 'stats().queries.errors did not grow after a failed read', 3000)
end)
K.step('I remember the prepared statement cache hits', 'server', function(ctx)
    local _, stats = totalQueries()
    assert(type(stats.statementCache) == 'table' and type(stats.statementCache.hits) == 'number', 'stats().statementCache.hits is missing')
    ctx.state.sqlHits = stats.statementCache.hits
end)
K.step('the prepared statement cache hits should have grown', 'server', function(ctx)
    local before = assert(ctx.state.sqlHits, 'Remember the cache hits first')
    local _, stats = totalQueries()
    assert(stats.statementCache.hits > before, ('statementCache.hits stayed at %d'):format(stats.statementCache.hits))
    assert(stats.statementCache.size <= stats.statementCache.maxSize, 'Statement cache is larger than its maximum')
end)
-- A SELECT SLEEP just over stats().queries.slowThreshold is recorded in the slow
-- ring with the calling resource (stats.js record, exports.js verifiedCaller).
K.step('I run a database read slower than the slow query threshold', 'server', function(ctx)
    local _, stats = totalQueries()
    local threshold = stats.queries.slowThreshold
    assert(type(threshold) == 'number' and threshold >= 0 and threshold <= 5000, 'Slow threshold is unusable: ' .. tostring(threshold))
    local sql = ('SELECT SLEEP(%.3f) AS fft_slow_probe_%d'):format((threshold + 150) / 1000, GetGameTimer())
    ctx.state.sqlSlowProbe, ctx.state.sqlSlowThreshold = sql, threshold
    remember(ctx, read(ctx, SELF_SQL, 'scalar', sql, {}))
end)
K.step('the slow query log should list that read for this test runner', 'server', function(ctx)
    local sql = assert(ctx.state.sqlSlowProbe, 'Run the slow read first')
    local slow = K.export(SELF_SQL, 'slowQueries', 20)
    for _, entry in ipairs(slow or {}) do
        if entry.sql == sql then
            ctx:equal(entry.resource, GetCurrentResourceName(), 'Slow query attributed to')
            assert(type(entry.ms) == 'number' and entry.ms >= ctx.state.sqlSlowThreshold,
                ('Slow entry took %s ms, threshold %s'):format(tostring(entry.ms), tostring(ctx.state.sqlSlowThreshold)))
            return
        end
    end
    error('The slow read is not among the 20 newest slow queries', 0)
end)
