-- Include as a shared_script before your shared step definitions.
local resource = 'fft'
FFT = {}
local registrations = {}
local function register(kind, pattern, options, callback)
    if type(options) == 'function' then callback, options = options, {} end
    options = options or {}
    local spec = { pattern = pattern, realm = options.realm or 'client', requires = options.requires or {},
        hook = (kind == 'Before' or kind == 'After') and kind or nil }
    registrations[#registrations + 1] = { spec, callback }
    exports[resource]:registerStep(spec, callback)
end
for _, kind in ipairs({ 'Given', 'When', 'Then', 'Before', 'After' }) do
    FFT[kind] = function(pattern, options, callback) return register(kind, pattern, options, callback) end
end
Given, When, Then, Before, After = FFT.Given, FFT.When, FFT.Then, FFT.Before, FFT.After
AddEventHandler(IsDuplicityVersion() and 'onResourceStart' or 'onClientResourceStart', function(name)
    if name == resource then
        for _, registration in ipairs(registrations) do exports[resource]:registerStep(registration[1], registration[2]) end
    end
end)
