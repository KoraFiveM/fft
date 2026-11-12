-- kora_theme: shared palette/token exports and the personal /theme colour.
-- Expected colours are read from kora_theme's own theme.json at run time, so the
-- suite follows the file instead of pinning a palette.
-- No resource hook: the palette exports are authoritative, and the picker frame's
-- callbacks (kora_theme:set / kora_theme:close, kora_theme/client/main.lua) are driven
-- with a real fetch through K.nui, with the bodies kora_theme/web/app.js posts.
-- Nothing clicks the DOM.
local K = FFT.kora
if not K then return end
K.feature('kora_theme')

local function themeFile()
    local raw = LoadResourceFile('kora_theme', 'theme.json')
    assert(type(raw) == 'string' and raw ~= '', 'kora_theme/theme.json could not be read')
    local ok, data = pcall(json.decode, raw)
    assert(ok and type(data) == 'table' and type(data.colors) == 'table', 'kora_theme/theme.json has no "colors" object')
    return data
end

local function isHex(value) return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil end

-- ---------------------------------------------------------------------------
-- Palette and tokens (server; the same shared exports exist on the client)
-- ---------------------------------------------------------------------------

K.step('the theme primary colour should match the theme file', 'server', function(ctx)
    local expected = themeFile().colors.primary
    assert(isHex(expected), 'theme.json primary is not #RRGGBB; the resource falls back to its emergency colour')
    ctx:equal(K.export('kora_theme', 'getPrimaryColor'), expected:upper(), 'Primary colour')
end)

K.step('the theme palette should match every colour in the theme file', 'server', function(ctx)
    local palette = K.export('kora_theme', 'getColours')
    assert(type(palette) == 'table', 'getColours() did not return a table')
    local checked = 0
    for key, value in pairs(themeFile().colors) do
        if isHex(value) then
            ctx:equal(palette[key], value:upper(), 'Palette colour ' .. key)
            checked = checked + 1
        end
    end
    assert(checked > 0, 'theme.json has no valid colours to compare')
    for key, value in pairs(palette) do
        assert(isHex(value), ('Palette colour %s is %s, not #RRGGBB'):format(tostring(key), tostring(value)))
    end
end)

K.step('the theme palette with the primary override {string} should use {string} as primary', 'server', function(ctx, override, expected)
    local palette = K.export('kora_theme', 'getColours', override)
    ctx:equal(palette.primary, expected, 'Overridden primary')
    local base = K.export('kora_theme', 'getColours')
    ctx:equal(palette.background, base.background, 'Background after a primary-only override')
end)

K.step('the theme palette should ignore the invalid primary override {string}', 'server', function(ctx, override)
    local palette = K.export('kora_theme', 'getColours', { primary = override })
    ctx:equal(palette.primary, K.export('kora_theme', 'getPrimaryColor'), 'Primary after an invalid override')
end)

K.step('the theme token {string} should be {string}', 'server', function(ctx, token, expected)
    local tokens = K.export('kora_theme', 'getTokens')
    assert(type(tokens) == 'table', 'getTokens() did not return a table')
    ctx:equal(tokens[token], expected, 'Token ' .. token)
end)

K.step('the theme token {string} for the primary {string} should be {string}', 'server', function(ctx, token, primary, expected)
    local tokens = K.export('kora_theme', 'getTokens', primary)
    assert(type(tokens) == 'table', 'getTokens() did not return a table')
    ctx:equal(tokens[token], expected, 'Token ' .. token .. ' for ' .. primary)
end)

K.step('the theme should resolve a body, heading and mono font', 'server', function()
    local fonts = K.export('kora_theme', 'getFonts')
    assert(type(fonts) == 'table', 'getFonts() did not return a table')
    local sources = { config = true, ['theme.json'] = true, default = true }
    for _, slot in ipairs({ 'body', 'heading', 'mono' }) do
        local font = fonts[slot]
        assert(type(font) == 'table', 'No font resolved for ' .. slot)
        assert(type(font.stack) == 'string' and font.stack ~= '', 'Font ' .. slot .. ' has no CSS stack')
        assert(sources[font.source], ('Font %s has the unknown source %s'):format(slot, tostring(font.source)))
    end
end)

-- ---------------------------------------------------------------------------
-- Personal colour (client). It is stored in kora_theme's client KVP, so the
-- value found before the scenario is put back afterwards.
-- ---------------------------------------------------------------------------

local function protectPersonalTheme(ctx)
    if ctx.state.themeProtected then return end
    ctx.state.themeProtected = true
    local original = K.export('kora_theme', 'getPlayerTheme')
    ctx:cleanup(function()
        pcall(function() exports.kora_theme:setPlayerTheme(original or 'reset') end)
    end)
end

-- Cleanup-safe: kora_theme:close answers `{}` whether or not the picker is open
-- (kora_theme/client/main.lua), and the short timeout stays inside the cleanup limit.
local function closePicker()
    pcall(K.nui, 'kora_theme', 'kora_theme:close', {}, 2000)
end

K.step('I run the theme command {string}', 'client', function(ctx, command)
    assert(command == 'theme' or command:sub(1, 6) == 'theme ', 'This step only runs the theme command')
    protectPersonalTheme(ctx)
    -- Registered for every form: a command whose argument is lost opens the
    -- picker (RegisterCommand handler in kora_theme/client/main.lua), and a picker
    -- left open would keep NUI focus for the scenarios that follow.
    if not ctx.state.themePickerCleanup then
        ctx.state.themePickerCleanup = true
        ctx:cleanup(closePicker)
    end
    ExecuteCommand(command)
end)

K.step('my personal theme colour should be {string}', 'client', function(ctx, expected)
    -- An export returning nil crosses the boundary as no value at all, so the
    -- reads are adjusted to one value and made lazily for the failure message.
    ctx:waitUntil(function() return K.export('kora_theme', 'getPlayerTheme') == expected end,
        'Personal theme is not ' .. expected, 3000,
        function() return ' | it is ' .. tostring((K.export('kora_theme', 'getPlayerTheme'))) end)
end)

K.step('I should have no personal theme colour', 'client', function(ctx)
    ctx:waitUntil(function() return K.export('kora_theme', 'getPlayerTheme') == nil end,
        'A personal theme is still set', 3000,
        function() return ': ' .. tostring((K.export('kora_theme', 'getPlayerTheme'))) end)
end)

K.step('my personal theme colour is {string}', 'client', function(ctx, colour)
    protectPersonalTheme(ctx)
    local ok, err = K.export('kora_theme', 'setPlayerTheme', colour)
    if not ok then error('setPlayerTheme refused ' .. colour .. ': ' .. tostring(err), 0) end
end)

K.step('setting my personal theme colour to {string} should be refused with {string}', 'client', function(ctx, colour, reason)
    protectPersonalTheme(ctx)
    local before = K.export('kora_theme', 'getPlayerTheme')
    local ok, err = K.export('kora_theme', 'setPlayerTheme', colour)
    ctx:equal(ok, false, 'setPlayerTheme result')
    ctx:equal(err, reason, 'Refusal reason')
    ctx:equal(K.export('kora_theme', 'getPlayerTheme'), before, 'Personal theme after the refusal')
end)

-- Picker frame. kora_theme exposes no "picker is open" state, so the only signal
-- is the NUI focus it takes and releases.
K.step('the theme picker should hold the cursor', 'client', function(ctx)
    if not ctx.state.themePickerCleanup then
        ctx.state.themePickerCleanup = true
        ctx:cleanup(closePicker)
    end
    ctx:waitUntil(function() return IsNuiFocused() end, 'The theme picker did not take NUI focus', 3000)
end)

-- web/app.js posts kora_theme:close with no payload; K.nui raises when unanswered.
K.step('I close the theme picker', 'client', function()
    K.nui('kora_theme', 'kora_theme:close', {})
end)

K.step('the theme picker should have released the cursor', 'client', function(ctx)
    ctx:waitUntil(function() return not IsNuiFocused() end, 'NUI focus is still held after closing the picker', 3000)
end)

local function pick(ctx, colour)
    protectPersonalTheme(ctx)
    -- Same body as web/app.js: post("kora_theme:set", { colour }). The handler
    -- answers { ok, message, state } (kora_theme/client/main.lua).
    local reply = K.nui('kora_theme', 'kora_theme:set', { colour = colour })
    assert(type(reply) == 'table', 'kora_theme:set answered ' .. type(reply))
    ctx.state.themeReply = reply
end

K.step('I pick the colour {string} in the theme picker', 'client', function(ctx, colour) pick(ctx, colour) end)

K.step('I pick the preset {string} in the theme picker', 'client', function(ctx, label)
    for _, preset in ipairs(themeFile().presets or {}) do
        if preset.label == label then return pick(ctx, preset.colour) end
    end
    error('theme.json has no preset labelled ' .. label, 0)
end)

K.step('the theme picker should accept the choice and show {string} as selected', 'client', function(ctx, colour)
    local reply = assert(ctx.state.themeReply, 'Pick a colour first')
    ctx:equal(reply.ok, true, 'Picker result')
    assert(type(reply.state) == 'table', 'The picker answer carries no state')
    ctx:equal(reply.state.selected, colour, 'Selected colour')
end)

K.step('the theme picker should refuse the choice with {string}', 'client', function(ctx, reason)
    local reply = assert(ctx.state.themeReply, 'Pick a colour first')
    ctx:equal(reply.ok, false, 'Picker result')
    ctx:equal(reply.message, reason, 'Refusal reason')
end)

K.step('the theme picker should offer the server default first and the preset {string}', 'client', function(ctx, label)
    local reply = assert(ctx.state.themeReply, 'Pick a colour first')
    local state = reply.state
    assert(type(state) == 'table' and type(state.presets) == 'table' and #state.presets > 0, 'The picker state lists no presets')
    local file = themeFile()
    ctx:equal(state.default, file.colors.primary:upper(), 'Picker default colour')
    ctx:equal(state.presets[1].colour, file.colors.primary:upper(), 'First preset colour')
    for _, preset in ipairs(state.presets) do
        if preset.label == label then return end
    end
    error('The picker does not offer the preset ' .. label, 0)
end)

-- ---------------------------------------------------------------------------
-- More palette, token and font checks (kora_theme/shared.lua, theme_loader.lua)
-- ---------------------------------------------------------------------------

K.step('the theme token {string} with the {string} override {string} should be {string}', 'server', function(ctx, token, key, colour, expected)
    local tokens = K.export('kora_theme', 'getTokens', { [key] = colour })
    assert(type(tokens) == 'table', 'getTokens() did not return a table')
    ctx:equal(tokens[token], expected, ('Token %s with %s = %s'):format(token, key, colour))
end)

-- resolveColours: a valid override is upper-cased; the other keys keep theme.json.
K.step('the theme palette with the {string} override {string} should use {string} for it', 'server', function(ctx, key, colour, expected)
    local palette = K.export('kora_theme', 'getColours', { [key] = colour })
    local base = K.export('kora_theme', 'getColours')
    ctx:equal(palette[key], expected, 'Overridden ' .. key)
    for name, value in pairs(base) do
        if name ~= key then ctx:equal(palette[name], value, 'Untouched palette colour ' .. name) end
    end
end)

K.step('the theme palette should ignore the invalid {string} override {string}', 'server', function(ctx, key, colour)
    local palette = K.export('kora_theme', 'getColours', { [key] = colour })
    local base = K.export('kora_theme', 'getColours')
    ctx:equal(palette[key], base[key], key .. ' after an invalid override')
end)

-- resolveColours only walks the theme.json keys, so other keys never appear.
K.step('the theme palette should ignore an override for the unknown colour {string}', 'server', function(ctx, key)
    local palette = K.export('kora_theme', 'getColours', { [key] = '#FFFFFF' })
    ctx:equal(palette[key], nil, 'Palette entry for ' .. key)
end)

-- Anything other than a string or a table is treated as no override.
K.step('the theme palette with a numeric override should be the base palette', 'server', function(ctx)
    local palette = K.export('kora_theme', 'getColours', 42)
    local base = K.export('kora_theme', 'getColours')
    for name, value in pairs(base) do ctx:equal(palette[name], value, 'Palette colour ' .. name) end
end)

K.step('the theme token {string} should equal the token {string}', 'server', function(ctx, token, other)
    local tokens = K.export('kora_theme', 'getTokens')
    assert(type(tokens[token]) == 'string', 'Token ' .. token .. ' is missing')
    ctx:equal(tokens[token], tokens[other], ('Token %s compared with %s'):format(token, other))
end)

-- getTokens: radius = shape.radius px, radius-sm = round(0.75 x), radius-lg =
-- round(1.25 x); without a radius the theme.css rem values. theme_loader.lua
-- clamps the radius to 0-24 and rounds it.
K.step('the theme radius tokens should follow the theme file shape', 'server', function(ctx)
    local shape = themeFile().shape
    local radius = type(shape) == 'table' and type(shape.radius) == 'number' and shape.radius or nil
    local tokens = K.export('kora_theme', 'getTokens')
    if radius then
        radius = math.max(0, math.min(24, math.floor(radius + 0.5)))
        ctx:equal(tokens.radius, ('%dpx'):format(radius), 'Token radius')
        ctx:equal(tokens['radius-sm'], ('%dpx'):format(math.floor(radius * 0.75 + 0.5)), 'Token radius-sm')
        ctx:equal(tokens['radius-lg'], ('%dpx'):format(math.floor(radius * 1.25 + 0.5)), 'Token radius-lg')
    else
        ctx:equal(tokens.radius, '0.625rem', 'Token radius')
        ctx:equal(tokens['radius-sm'], '0.375rem', 'Token radius-sm')
        ctx:equal(tokens['radius-lg'], '0.8125rem', 'Token radius-lg')
    end
end)

-- SHADOWS in shared.lua (same values as theme.js), keyed by theme.json shape.shadows.
local SHADOWS = {
    none = { low = '0 0 #0000', floating = '0 0 #0000', modal = '0 0 #0000' },
    soft = { low = '0 2px 8px rgb(0 0 0 / 24%)', floating = '0 10px 28px rgb(0 0 0 / 40%)', modal = '0 20px 56px rgb(0 0 0 / 50%)' },
    default = { low = '0 4px 12px rgb(0 0 0 / 28%)', floating = '0 12px 32px rgb(0 0 0 / 42%)', modal = '0 24px 64px rgb(0 0 0 / 55%)' },
}
K.step('the theme shadow tokens should follow the theme file shape', 'server', function(ctx)
    local shape = themeFile().shape
    local expected = SHADOWS[type(shape) == 'table' and shape.shadows or ''] or SHADOWS.default
    local tokens = K.export('kora_theme', 'getTokens')
    for _, level in ipairs({ 'low', 'floating', 'modal' }) do
        ctx:equal(tokens['shadow-' .. level], expected[level], 'Token shadow-' .. level)
    end
end)

local function fontCatalog()
    local raw = LoadResourceFile('kora_theme', 'fonts/catalog.json')
    assert(type(raw) == 'string' and raw ~= '', 'kora_theme/fonts/catalog.json could not be read')
    local ok, data = pcall(json.decode, raw)
    assert(ok and type(data) == 'table' and type(data.defaults) == 'table', 'fonts/catalog.json has no "defaults"')
    local byId = {}
    for _, font in ipairs(data.fonts or {}) do byId[font.id] = font end
    return data, byId
end

-- chooseFont/getFonts: a "default" slot uses the catalog default stack for its
-- kind, and a default heading uses the body stack; a catalog id uses its stack.
K.step('every theme font should come from the font catalog or its default', 'server', function(ctx)
    local catalog, byId = fontCatalog()
    local fonts = K.export('kora_theme', 'getFonts')
    for _, slot in ipairs({ 'body', 'heading', 'mono' }) do
        local font = fonts[slot]
        assert(type(font) == 'table', 'No font resolved for ' .. slot)
        if font.id == 'default' then
            local expected = slot == 'heading' and fonts.body.stack or catalog.defaults[slot == 'mono' and 'mono' or 'sans']
            ctx:equal(font.stack, expected, 'Default stack for ' .. slot)
            ctx:equal(font.label, 'Default', 'Default label for ' .. slot)
        elseif font.id == 'custom' then
            ctx:equal(font.source, 'config', 'Source of the custom ' .. slot .. ' font')
            local kind = slot == 'mono' and 'mono' or 'sans'
            assert(K.contains(font.stack, catalog.defaults[kind]), 'Custom ' .. slot .. ' stack does not end in the catalog default')
        else
            local entry = byId[font.id]
            assert(entry, ('Font %s has the id %s, which is not in fonts/catalog.json'):format(slot, tostring(font.id)))
            ctx:equal(font.stack, entry.stack, 'Catalog stack for ' .. slot)
            ctx:equal(font.label, entry.label, 'Catalog label for ' .. slot)
        end
    end
end)

K.step('the theme font tokens should match the resolved fonts', 'server', function(ctx)
    local fonts = K.export('kora_theme', 'getFonts')
    local tokens = K.export('kora_theme', 'getTokens')
    ctx:equal(tokens['font-sans'], fonts.body.stack, 'Token font-sans')
    ctx:equal(tokens['font-heading'], fonts.heading.stack, 'Token font-heading')
    ctx:equal(tokens['font-mono'], fonts.mono.stack, 'Token font-mono')
end)

-- The exports are shared scripts, so the client copy reads the same theme.json.
K.step('the client theme palette should match every colour in the theme file', 'client', function(ctx)
    local palette = K.export('kora_theme', 'getColours')
    assert(type(palette) == 'table', 'getColours() did not return a table on the client')
    local checked = 0
    for key, value in pairs(themeFile().colors) do
        if isHex(value) then
            ctx:equal(palette[key], value:upper(), 'Client palette colour ' .. key)
            checked = checked + 1
        end
    end
    assert(checked > 0, 'theme.json has no valid colours to compare')
end)

-- ---------------------------------------------------------------------------
-- More personal colour checks (kora_theme/client/main.lua)
-- ---------------------------------------------------------------------------

-- setPlayerTheme: nil, '', 'reset' and 'default' clear the choice; anything
-- else goes through normaliseHex (trim, add a missing '#', upper-case).
K.step('I set my personal theme colour to {string}', 'client', function(ctx, colour)
    protectPersonalTheme(ctx)
    local ok, err = K.export('kora_theme', 'setPlayerTheme', colour)
    if not ok then error(('setPlayerTheme refused "%s": %s'):format(colour, tostring(err)), 0) end
end)
K.step('I clear my personal theme colour through the export', 'client', function(ctx)
    protectPersonalTheme(ctx)
    local ok, err = K.export('kora_theme', 'setPlayerTheme', nil)
    if not ok then error('setPlayerTheme(nil) refused: ' .. tostring(err), 0) end
end)

-- announceChange raises this local event on every accepted change.
K.step('I watch for personal theme changes', 'client', function(ctx)
    local list = {}
    ctx.state.themeChanges = list
    ctx:on('kora_theme:playerThemeChanged', function() list[#list + 1] = GetGameTimer() end)
end)
K.step('a personal theme change should have been announced', 'client', function(ctx)
    local list = assert(ctx.state.themeChanges, 'Watch for personal theme changes first')
    ctx:waitUntil(function() return #list > 0 end, 'kora_theme:playerThemeChanged was not raised', 3000)
end)
K.step('no personal theme change should have been announced', 'client', function(ctx)
    local list = assert(ctx.state.themeChanges, 'Watch for personal theme changes first')
    Wait(500)
    ctx:equal(#list, 0, 'kora_theme:playerThemeChanged count')
end)

-- The command reports a refused colour with chat:addMessage { args = { 'Theme', message } }.
K.step('I watch for theme chat messages', 'client', function(ctx)
    local list = {}
    ctx.state.themeChat = list
    ctx:on('chat:addMessage', function(message)
        if type(message) == 'table' and type(message.args) == 'table' and #list < 20 then list[#list + 1] = message.args end
    end)
end)
K.step('the theme command should answer in chat with {string}', 'client', function(ctx, text)
    local list = assert(ctx.state.themeChat, 'Watch for theme chat messages first')
    ctx:waitUntil(function()
        for _, args in ipairs(list) do
            if args[1] == 'Theme' and args[2] == text then return true end
        end
    end, 'No Theme chat message "' .. text .. '"', 3000)
end)
K.step('the theme command should not answer in chat', 'client', function(ctx)
    local list = assert(ctx.state.themeChat, 'Watch for theme chat messages first')
    Wait(500)
    for _, args in ipairs(list) do
        assert(args[1] ~= 'Theme', 'The theme command answered in chat: ' .. tostring(args[2]))
    end
end)

-- web/app.js reset button: choose(null) posts { colour: null }, which arrives without a colour.
K.step('I reset my colour in the theme picker', 'client', function(ctx)
    protectPersonalTheme(ctx)
    local reply = K.nui('kora_theme', 'kora_theme:set', {})
    assert(type(reply) == 'table', 'kora_theme:set answered ' .. type(reply))
    ctx.state.themeReply = reply
end)
K.step('the theme picker should accept the choice and show no colour as selected', 'client', function(ctx)
    local reply = assert(ctx.state.themeReply, 'Pick a colour first')
    ctx:equal(reply.ok, true, 'Picker result')
    assert(type(reply.state) == 'table', 'The picker answer carries no state')
    ctx:equal(reply.state.selected, nil, 'Selected colour')
end)

-- configuredPresets: theme.json "name" (or "Server default") with the primary
-- first, then theme.json presets in order; labels 1-40 characters, colours
-- de-duplicated.
local function expectedPresets()
    local file = themeFile()
    local list, seen = {}, {}
    local function add(label, colour)
        colour = isHex(colour) and colour:upper() or nil
        if colour and type(label) == 'string' and label ~= '' and #label <= 40 and not seen[colour] then
            seen[colour] = true
            list[#list + 1] = { label = label, colour = colour }
        end
    end
    add(type(file.name) == 'string' and file.name ~= '' and file.name or 'Server default', file.colors.primary)
    for _, preset in ipairs(file.presets or {}) do
        if type(preset) == 'table' and isHex(preset.colour) and type(preset.label) == 'string' then add(preset.label, preset.colour) end
    end
    return list
end

local function assertPresets(ctx, presets)
    assert(type(presets) == 'table', 'The picker state lists no presets')
    local expected = expectedPresets()
    ctx:equal(#presets, #expected, 'Number of picker presets')
    for index, preset in ipairs(expected) do
        ctx:equal(presets[index].label, preset.label, 'Picker preset ' .. index .. ' label')
        ctx:equal(presets[index].colour, preset.colour, 'Picker preset ' .. index .. ' colour')
    end
end

K.step('the theme picker should list the theme file presets in order', 'client', function(ctx)
    local reply = assert(ctx.state.themeReply, 'Pick a colour first')
    assertPresets(ctx, (reply.state or {}).presets)
end)

-- kora_theme:ready answers { overrides, picker, fonts } (kora_theme/client/main.lua).
K.step('the theme page handshake should report my personal colour, the presets and the fonts', 'client', function(ctx)
    local reply = K.nui('kora_theme', 'kora_theme:ready', {})
    assert(type(reply) == 'table', 'kora_theme:ready answered ' .. type(reply))
    ctx:equal(reply.overrides, K.export('kora_theme', 'getPlayerTheme'), 'Handshake overrides')
    local picker = reply.picker
    assert(type(picker) == 'table', 'The handshake carries no picker state')
    ctx:equal(picker.enabled, true, 'Picker enabled')
    ctx:equal(picker.selected, K.export('kora_theme', 'getPlayerTheme'), 'Picker selected colour')
    ctx:equal(picker.default, themeFile().colors.primary:upper(), 'Picker default colour')
    assertPresets(ctx, picker.presets)
    local fonts = reply.fonts
    assert(type(fonts) == 'table', 'The handshake carries no fonts')
    local resolved = K.export('kora_theme', 'getFonts')
    for _, slot in ipairs({ 'body', 'heading', 'mono' }) do
        assert(type(fonts[slot]) == 'table', 'The handshake has no ' .. slot .. ' font')
        ctx:equal(fonts[slot].stack, resolved[slot].stack, 'Handshake ' .. slot .. ' stack')
    end
end)
