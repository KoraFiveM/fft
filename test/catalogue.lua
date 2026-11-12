-- Offline loader: runs the shared step files in both realms with FiveM globals
-- stubbed and prints the step catalogue as JSON. Usage:
--   lua test/catalogue.lua <adapter> <file>...
-- Catches load-time errors (a step file touching a realm API at file scope),
-- duplicate definitions and feature registrations for missing files.
local adapter = arg[1]
local files = { table.unpack(arg, 2) }

local function encode(v)
    local t = type(v)
    if t == 'table' then
        if #v > 0 or next(v) == nil then
            local out = {}
            for i, item in ipairs(v) do out[i] = encode(item) end
            return '[' .. table.concat(out, ',') .. ']'
        end
        local out = {}
        for k, item in pairs(v) do out[#out + 1] = encode(tostring(k)) .. ':' .. encode(item) end
        table.sort(out)
        return '{' .. table.concat(out, ',') .. '}'
    elseif t == 'string' then
        return '"' .. v:gsub('[%c"\\]', function(c) return ('\\u%04x'):format(c:byte()) end) .. '"'
    elseif t == 'nil' then return 'null' end
    return tostring(v)
end

local function exists(path) local f = io.open(path, 'r') if f then f:close() return true end return false end

-- Any global a step file reads at load time must be listed here. Everything
-- else is nil on purpose: callbacks may use realm APIs, file scope may not.
local function environment(isServer)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.IsDuplicityVersion = function() return isServer end
    env.GetConvar = function(name, default) return name == 'fft_adapter' and adapter or default end
    env.GetCurrentResourceName = function() return 'fft' end
    env.GetInvokingResource = function() return nil end
    env.GetResourceState = function() return 'started' end
    env.LoadResourceFile = function(_, path) return exists(path) and 'x' or nil end
    env.AddEventHandler = function() return {} end
    env.RegisterNetEvent = function() end
    env.exports = setmetatable({}, { __call = function() end, __index = function() return setmetatable({}, { __index = function() return function() end end }) end })
    env.json = { encode = encode, decode = function() return {} end }
    env.print = function(...) io.stderr:write(table.concat({ ... }, ' '), '\n') end
    return env
end

local failed = false
local function fail(message) failed = true io.stderr:write('ERROR ' .. message .. '\n') end

local result = {}
for _, isServer in ipairs({ true, false }) do
    local realm = isServer and 'server' or 'client'
    local env = environment(isServer)
    for _, file in ipairs(files) do
        local chunk, err = loadfile(file, 't', env)
        if not chunk then fail(err) else
            local ok, why = pcall(chunk)
            if not ok then fail(('%s (%s realm, load time): %s'):format(file, realm, tostring(why))) end
        end
    end
    local FFT = env.FFT
    if FFT then
        -- Both realms must agree, and one pattern may only have one owner.
        local patterns, list = {}, FFT.catalogue()
        for _, d in ipairs(list) do
            if not d.hook then
                if patterns[d.pattern] then fail(('pattern registered twice: "%s" (%s and %s)'):format(d.pattern, patterns[d.pattern], d.id)) end
                patterns[d.pattern] = d.id
            end
        end
        result[realm] = list
        if isServer then
            local features = {}
            for _, f in pairs(FFT.features) do features[#features + 1] = f.path end
            table.sort(features)
            result.features = features
        end
    end
end
if result.server and result.client and encode(result.server) ~= encode(result.client) then
    fail('server and client realms registered different step catalogues')
end
io.write(encode({ definitions = result.server or {}, features = result.features or {} }), '\n')
os.exit(failed and 1 or 0)
