-- kora_loading: the loadscreen resource. It has no server realm and its page
-- only exists while the client loads, so nothing about the screen itself can
-- be observed once a tester is in game. What is left is asserted here:
--   * the manifest contract the loadscreen depends on (server-readable),
--   * that the manual shutdown has happened for this session,
--   * the two NUI callbacks its pages fetch (RegisterNUICallback in
--     kora_loading/client.lua), run with a real fetch through K.nui and the same
--     empty body html/app.js and html/sync.js post. No hook is used.
local K = FFT.kora
if not K then return end
K.feature('kora_loading')

local LOADING = 'kora_loading'

-- Values are the manifest lines in kora_loading/fxmanifest.lua.
K.step('the loading screen manifest should declare the page {string} with manual shutdown', 'server', function(ctx, page)
    K.started(LOADING)
    ctx:equal(GetResourceMetadata(LOADING, 'loadscreen', 0), page, 'loadscreen')
    ctx:equal(GetResourceMetadata(LOADING, 'loadscreen_manual_shutdown', 0), 'yes', 'loadscreen_manual_shutdown')
    assert(LoadResourceFile(LOADING, page), 'Loadscreen page is missing from the resource: ' .. page)
end)
K.step('the loading screen resource should ship the file {string}', 'server', function(_, path)
    K.started(LOADING)
    assert(#path <= 120 and not path:find('..', 1, true), 'Invalid resource path')
    local content = LoadResourceFile(LOADING, path)
    assert(content and #content > 0, 'kora_loading does not ship ' .. path)
end)

K.step('the loading screen should have been shut down', 'client', function(ctx)
    -- loadscreen_manual_shutdown is on: the screen stays until client.lua's
    -- shutdown() (or another resource) calls ShutdownLoadingScreen.
    ctx:equal(GetIsLoadingScreenActive() == true, false, 'Loading screen active')
end)

local function fetch(ctx, name)
    local result = K.nui(LOADING, name, {})
    assert(type(result) == 'table', name .. ' answered with ' .. type(result))
    ctx.state.loading = ctx.state.loading or {}
    ctx.state.loading[name] = result
    return result
end

local function isList(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' then return false end
        count = count + 1
    end
    return count == #value
end

K.step('the loading screen page fetches its settings', 'client', function(ctx) fetch(ctx, 'loadingscreen:getTheme') end)
K.step('the loading screen settings should be complete', 'client', function(ctx)
    local theme = assert(ctx.state.loading and ctx.state.loading['loadingscreen:getTheme'], 'Fetch the loading screen settings first')
    assert(type(theme.serverName) == 'string' and #theme.serverName > 0, 'serverName is empty')
    assert(isList(theme.tips), 'tips is not a plain list')
    for index, tip in ipairs(theme.tips) do
        assert(type(tip) == 'string' and #tip > 0, 'tip ' .. index .. ' is not a non-empty string')
    end
    ctx:equal(type(theme.showProgressText), 'boolean', 'showProgressText type')
    assert(type(theme.theme) == 'table' and type(theme.theme.fonts) == 'boolean', 'theme.fonts is not a boolean')
    assert(type(theme.media) == 'table' and isList(theme.media.images), 'media.images is not a plain list')
    assert(type(theme.musicPlayer) == 'table' and isList(theme.musicPlayer.tracks), 'musicPlayer.tracks is not a plain list')
    local colour = theme.playerTheme
    assert(colour == false or (type(colour) == 'string' and colour:match('^#%x%x%x%x%x%x$')),
        'playerTheme is neither false nor #RRGGBB: ' .. tostring(colour))
end)
K.step('the loading screen settings should keep their numbers within the configured ranges', 'client', function(ctx)
    local theme = assert(ctx.state.loading and ctx.state.loading['loadingscreen:getTheme'], 'Fetch the loading screen settings first')
    -- Ranges are the Kora.config.number bounds in kora_loading/config.lua.
    local function within(label, value, min, max)
        assert(type(value) == 'number' and value >= min and value <= max,
            ('%s is %s, expected %s-%s'):format(label, tostring(value), min, max))
    end
    within('media.slideSeconds', theme.media.slideSeconds, 2, 120)
    within('media.musicVolume', theme.media.musicVolume, 0, 1)
    within('media.dim', theme.media.dim, 0, 1)
    within('musicPlayer.volume', theme.musicPlayer.volume, 0, 1)
end)
K.step('the loading screen sync page should be given the same player colour', 'client', function(ctx)
    local theme = assert(ctx.state.loading and ctx.state.loading['loadingscreen:getTheme'], 'Fetch the loading screen settings first')
    local sync = fetch(ctx, 'loadingscreen:syncTheme')
    ctx:equal(sync.colour, theme.playerTheme, 'Player theme colour')
end)

-- ---------------------------------------------------------------------------
-- Round 3: manifest metadata, shipped theme/media copies, settings contract,
-- body handling and the personal-colour round trip through both callbacks.
-- ---------------------------------------------------------------------------

-- Keys and values are the manifest lines in kora_loading/fxmanifest.lua.
K.step('the loading screen manifest entry {string} should be {string}', 'server', function(ctx, key, expected)
    K.started(LOADING)
    ctx:equal(GetResourceMetadata(LOADING, key, 0), expected, 'Manifest ' .. key)
end)

K.step('the loading screen manifest should depend on {string}', 'server', function(_, dependency)
    K.started(LOADING)
    local found = {}
    for index = 0, GetNumResourceMetadata(LOADING, 'dependency') - 1 do
        local value = GetResourceMetadata(LOADING, 'dependency', index)
        found[#found + 1] = tostring(value)
        if value == dependency then return end
    end
    error(('kora_loading does not depend on %s (dependencies: %s)'):format(dependency, table.concat(found, ', ')), 0)
end)

K.step('the loading screen should register no server script', 'server', function(ctx)
    K.started(LOADING)
    ctx:equal(GetNumResourceMetadata(LOADING, 'server_script'), 0, 'server_script entries')
    ctx:equal(GetNumResourceMetadata(LOADING, 'server_scripts'), 0, 'server_scripts entries')
end)

-- theme.json is the synced copy of kora_theme's theme.json (fxmanifest comment).
K.step('the loading screen theme copy should be valid JSON', 'server', function()
    K.started(LOADING)
    local content = LoadResourceFile(LOADING, 'html/kora_theme/theme.json')
    assert(content and #content > 0, 'kora_loading does not ship html/kora_theme/theme.json')
    local ok, decoded = pcall(json.decode, content)
    assert(ok and type(decoded) == 'table', 'html/kora_theme/theme.json is not a JSON object')
end)

local function settings(ctx)
    return assert(ctx.state.loading and ctx.state.loading['loadingscreen:getTheme'], 'Fetch the loading screen settings first')
end

-- Same callback as above, but with a body the pages never send: the handler in
-- kora_loading/client.lua ignores its first argument.
K.step('the loading screen page fetches its settings with an unexpected body', 'client', function(ctx)
    local result = K.nui(LOADING, 'loadingscreen:getTheme', { serverName = 'FFT', playerTheme = '#000000', tips = 5 })
    assert(type(result) == 'table', 'loadingscreen:getTheme answered with ' .. type(result))
    ctx.state.loadingOdd = result
end)
K.step('the loading screen settings should not echo the unexpected body', 'client', function(ctx)
    local theme, odd = settings(ctx), assert(ctx.state.loadingOdd, 'Fetch with an unexpected body first')
    ctx:equal(odd.serverName, theme.serverName, 'serverName')
    ctx:equal(odd.playerTheme, theme.playerTheme, 'playerTheme')
    ctx:equal(#odd.tips, #theme.tips, 'Number of tips')
end)

K.step('fetching the loading screen settings again should give the same answer', 'client', function(ctx)
    local first = settings(ctx)
    local again = K.nui(LOADING, 'loadingscreen:getTheme', {})
    assert(type(again) == 'table', 'Second fetch answered with ' .. type(again))
    ctx:equal(again.serverName, first.serverName, 'serverName')
    ctx:equal(again.showProgressText, first.showProgressText, 'showProgressText')
    ctx:equal(again.playerTheme, first.playerTheme, 'playerTheme')
    ctx:equal(json.encode(again.tips), json.encode(first.tips), 'tips')
    ctx:equal(json.encode(again.media.images), json.encode(first.media.images), 'media.images')
    ctx:equal(again.media.video, first.media.video, 'media.video')
    ctx:equal(#again.musicPlayer.tracks, #first.musicPlayer.tracks, 'Number of music player tracks')
end)

-- Field types follow the Kora.config declarations in kora_loading/config.lua.
K.step('the loading screen media settings should have the configured types', 'client', function(ctx)
    local media, player = settings(ctx).media, settings(ctx).musicPlayer
    for _, key in ipairs({ 'backdrop', 'themeWallpaper' }) do
        ctx:equal(type(media[key]), 'boolean', 'media.' .. key .. ' type')
    end
    for _, key in ipairs({ 'defaultWallpaper', 'video', 'music' }) do
        ctx:equal(type(media[key]), 'string', 'media.' .. key .. ' type')
    end
    ctx:equal(type(player.enabled), 'boolean', 'musicPlayer.enabled type')
    for index, image in ipairs(media.images) do
        assert(type(image) == 'string' and #image > 0, 'media.images[' .. index .. '] is not a non-empty string')
    end
    for index, track in ipairs(player.tracks) do
        assert(type(track) == 'table', 'musicPlayer.tracks[' .. index .. '] is not an object')
    end
end)

-- config.lua: "Use a WebM (VP8 or VP9) file: FiveM cannot play H.264, so an mp4 will not show."
K.step('the loading screen video should be empty or a WebM file', 'client', function(ctx)
    local video = settings(ctx).media.video
    assert(video == '' or video:lower():match('%.webm$') or video:lower():match('%.webm[?#]'),
        'media.video is not a WebM file: ' .. tostring(video))
end)

K.step('the loading screen settings should give the player colour {string}', 'client', function(ctx, colour)
    ctx:equal(settings(ctx).playerTheme, colour, 'playerTheme')
end)
K.step('the loading screen settings should give no player colour', 'client', function(ctx)
    -- playerTheme() in client.lua answers false, never nil, for the server default.
    ctx:equal(settings(ctx).playerTheme, false, 'playerTheme')
end)
K.step('the loading screen sync page should be given the player colour {string}', 'client', function(ctx, colour)
    local sync = K.nui(LOADING, 'loadingscreen:syncTheme', {})
    assert(type(sync) == 'table', 'loadingscreen:syncTheme answered with ' .. type(sync))
    ctx:equal(sync.colour, colour, 'Sync colour')
end)
K.step('the loading screen sync page should be given no player colour', 'client', function(ctx)
    local sync = K.nui(LOADING, 'loadingscreen:syncTheme', {})
    assert(type(sync) == 'table', 'loadingscreen:syncTheme answered with ' .. type(sync))
    ctx:equal(sync.colour, false, 'Sync colour')
end)
