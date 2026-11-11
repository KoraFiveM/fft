fx_version 'cerulean'
game 'gta5'
author 'FiveM Functional Testing contributors'
description 'Gherkin scenarios, Lua steps, in-game recording and UI replay'
version '0.1.0'

-- JS exports must exist before Lua parses features. Registration occurs on start.
server_script 'dist/parser.js'
shared_scripts {
    'config.lua', 'shared/core.lua', 'shared/adapters.lua', 'steps/builtin.lua',
    -- Kora suites: common helpers first, then one file per resource. Each file
    -- registers its own steps and its feature, so adding a suite needs no edit here.
    'steps/kora.lua', 'steps/kora/*.lua',
}
server_script 'server/main.lua'
client_script 'client/main.lua'
ui_page 'ui/index.html'
files { 'ui/index.html', 'ui/style.css', 'ui/app.js', 'import.lua', 'features/*.feature', 'features/kora/*.feature' }
