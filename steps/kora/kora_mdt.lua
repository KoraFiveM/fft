-- kora_mdt: who may open the records terminal, and what each role is shown.
--
-- No resource hook. The terminal is a kora_lib app ("kora_mdt:terminal") opened by
-- the real /mdt command; it is read through kora_lib's hook and driven at the
-- NUI-callback level by the generic app steps in steps/kora.lua.
--
-- Read-only on purpose: the MDT has no delete API, so no step here files a
-- report, case, warrant, BOLO, charge or record.
local K = FFT.kora
if not K then return end
K.feature('kora_mdt')

local RESOURCE = 'kora_mdt'
local APP = 'kora_mdt:terminal'

-- The open app's browser definition as kora_lib sent it to the NUI
-- (title, navigation = { { id, label, content }, ... }).
local function terminal()
    local payload = K.ui('app')
    assert(type(payload) == 'table', 'The MDT terminal is not open')
    local app = payload.app
    assert(type(app) == 'table' and app.id == APP, 'The open app is not the MDT terminal')
    return app
end

local function page(app, id)
    for _, view in pairs(type(app) == 'table' and type(app.navigation) == 'table' and app.navigation or {}) do
        if type(view) == 'table' and view.id == id then return view end
    end
end

K.step('the MDT terminal should be titled {string}', 'client', function(ctx, title)
    K.started(RESOURCE)
    ctx:waitUntil(function()
        local app = K.uiState().app
        return app and app.id == APP
    end, 'The MDT terminal did not open')
    ctx:equal(terminal().title, title, 'Terminal title')
end)

K.step('the MDT terminal should offer the page {string}', 'client', function(_, id)
    assert(page(terminal(), id), 'The MDT terminal has no page ' .. id)
end)

K.step('the MDT terminal should not offer the page {string}', 'client', function(_, id)
    assert(not page(terminal(), id), 'The MDT terminal offers the page ' .. id)
end)

-- The two steps below read what the last app action answered: the page it
-- navigated to and the refreshed page content (client/terminal.lua `update`).
K.step('the MDT terminal should have moved to the page {string}', 'client', function(ctx, id)
    local navigate = (ctx.state.appResult or {}).navigate
    assert(type(navigate) == 'table', 'The last MDT action did not navigate')
    ctx:equal(navigate.viewId, id, 'MDT page')
end)

K.step('the MDT page {string} should be headed {string}', 'client', function(ctx, id, title)
    local view = page((ctx.state.appResult or {}).app, id)
    assert(view, 'The last MDT action did not refresh the page ' .. id)
    ctx:equal(type(view.content) == 'table' and view.content.title or nil, title, 'MDT page heading')
end)

-- ---------------------------------------------------------------------------
-- Round 3: page content as opened, last-action details.
--
-- kora_lib's hook summarises payloads to a bounded depth (kora_lib/fft_hooks.lua
-- `summary`): from the opened app (K.ui('app')) a page's content and its block
-- titles are readable, actions inside blocks are not; from an action result
-- only a page's content title/description are. The steps below stay inside
-- what is readable.
-- ---------------------------------------------------------------------------

local function openedPage(id)
    local view = page(terminal(), id)
    assert(view, 'The MDT terminal has no page ' .. id)
    return view
end

K.step('the MDT terminal should be described as {string}', 'client', function(ctx, text)
    ctx:equal(terminal().description, text, 'Terminal description')
end)

-- client/terminal.lua:272 ('Patients' for a medic, 'Search' otherwise).
K.step('the MDT terminal page {string} should be labelled {string}', 'client', function(ctx, id, label)
    ctx:equal(openedPage(id).label, label, 'MDT page label')
end)

K.step('the MDT terminal page {string} should open headed {string}', 'client', function(ctx, id, title)
    local content = openedPage(id).content
    ctx:equal(type(content) == 'table' and content.title or nil, title, 'MDT page heading')
end)

K.step('the MDT terminal page {string} should open described as {string}', 'client', function(ctx, id, text)
    local content = openedPage(id).content
    ctx:equal(type(content) == 'table' and content.description or nil, text, 'MDT page description')
end)

-- A list that loaded is a titled table block; a list that failed is replaced by
-- an empty block titled "Could not load ..." (client/terminal.lua:355-364).
K.step('the MDT terminal page {string} should show the list {string}', 'client', function(_, id, title)
    local content = openedPage(id).content
    local seen = {}
    for _, block in pairs(type(content) == 'table' and type(content.blocks) == 'table' and content.blocks or {}) do
        if type(block) == 'table' then
            if block.title == title then return end
            seen[#seen + 1] = tostring(block.title)
        end
    end
    error(('The MDT page %s does not show "%s" (blocks: %s)'):format(id, title, table.concat(seen, ', ')), 0)
end)

K.step('the MDT page {string} should be described with {string}', 'client', function(ctx, id, text)
    local view = page((ctx.state.appResult or {}).app, id)
    assert(view, 'The last MDT action did not refresh the page ' .. id)
    local description = type(view.content) == 'table' and view.content.description or nil
    assert(K.contains(description, text), ('Page description is "%s", expected it to contain "%s"'):format(tostring(description), text))
end)

-- A refused action answers only a notice (client/terminal.lua:7-9 message()):
-- it neither navigates nor refreshes a page.
K.step('the last MDT action should have changed no page', 'client', function(ctx)
    local result = ctx.state.appResult or {}
    assert(result.navigate == nil, 'The last MDT action navigated to ' .. tostring(type(result.navigate) == 'table' and result.navigate.viewId))
    assert(result.app == nil, 'The last MDT action refreshed the terminal')
end)
