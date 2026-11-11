-- kora_cards: City Legends app (/cards) and the Card Studio job stations.
-- No resource hook: the binder, deck, shop and studio pages are one kora_lib
-- AppShell app ('kora_cards:city-legends', kora_cards/client/main.lua), the studio
-- stations are kora_target sphere zones, and every mutation is checked by the
-- 'kora_cards:server:action' callback that those app actions trigger.
local K = FFT.kora
if not K then return end
K.feature('kora_cards')

-- Config.supplies (kora_cards/config.lua), bought with the studio app actions.
local SUPPLIES = { 'card_film', 'blank_card', 'card_ink' }

-- Hands back whatever the supply counter sells during the scenario.
K.step('Card Studio supplies I buy are returned afterwards', 'server', function(ctx)
    local core, tester = exports.kora_core, ctx.tester
    local before = {}
    for _, item in ipairs(SUPPLIES) do before[item] = K.count(ctx, item) end
    ctx:cleanup(function()
        for _, item in ipairs(SUPPLIES) do
            local extra = (core:getItemCount(tester, item) or 0) - before[item]
            if extra > 0 then core:removeItem(tester, item, extra, nil, 'functional test cleanup') end
        end
    end)
end)

-- For refusals whose wording belongs to another resource (the cash provider).
K.step('the Card Studio app should decline the action', 'client', function(ctx)
    local notice = (ctx.state.appResult or {}).notice
    assert(type(notice) == 'table', 'The last app action returned no notice')
    ctx:equal(notice.tone, 'destructive', 'Notice tone')
    assert(type(notice.message) == 'string' and notice.message ~= '', 'The refusal carries no message')
end)

K.step('the City Legends app should show the {string} page', 'client', function(ctx, view)
    ctx:waitUntil(function()
        local app = K.uiState().app
        return app and app.id == 'kora_cards:city-legends' and app.viewId == view
    end, 'City Legends is not open on the ' .. view .. ' page', 5000)
end)

-- ---------------------------------------------------------------------------
-- Round 3: the 'kora_cards:server:action' callback, called directly.
--
-- Every app action and studio target goes through this one server callback
-- (kora_cards/server/main.lua handlers table), which re-checks job, duty,
-- grade, station distance, ownership and payload. Calling it as the tester
-- proves those checks independently of what the app shows or disables. Only
-- refusals and restorable mutations (supplies, the studio camera, duty) are
-- driven; anything that writes prints, decks, catalog rows or starter claims
-- is not.
-- ---------------------------------------------------------------------------

local ACTION = 'kora_cards:server:action'

-- kora_lib callback_triggerPacked keeps a leading nil, so `nil, reason`
-- refusals arrive intact.
local function cardsAction(ctx, action, payload)
    local ok, packed = pcall(function()
        return exports.kora_lib:callback_triggerPacked(ACTION, action, payload)
    end)
    local answer
    if not ok then
        answer = { raised = true, err = tostring(packed) }
    elseif type(packed) == 'table' and packed.__kora_lib_rejected then
        -- A raised handler error (kora_lib KoraLibCallbackEnvelope).
        answer = { raised = true, err = tostring(packed.error) }
    else
        packed = type(packed) == 'table' and packed or {}
        answer = { raised = false, result = packed[1], err = packed[2] }
    end
    ctx.state.cardsAnswer = answer
    return answer
end

local function lastAnswer(ctx)
    return assert(ctx.state.cardsAnswer, 'Send a City Legends server action first')
end

local function describe(answer)
    if answer.raised then return 'raised: ' .. tostring(answer.err) end
    return ('answered %s, %s'):format(type(answer.result) == 'table' and 'a result' or tostring(answer.result), tostring(answer.err))
end

K.step('I send the City Legends server action {string}', 'client', function(ctx, action)
    cardsAction(ctx, action, {})
end)

K.step('I send the City Legends server action {string} with:', 'client', function(ctx, action, argument)
    cardsAction(ctx, action, K.json(argument))
end)

-- server/matches.lua Play.challenge: the target must be another player.
K.step('I challenge myself to a City Legends match', 'client', function(ctx)
    cardsAction(ctx, 'challenge', { target = GetPlayerServerId(PlayerId()), mode = 'casual', deckId = 'fft-missing-deck' })
end)

-- server/main.lua: a non-string action is refused like an unknown one.
K.step('I send the City Legends server a numeric action', 'client', function(ctx)
    cardsAction(ctx, 42, {})
end)

K.step('the City Legends server should refuse with {string}', 'client', function(ctx, text)
    local answer = lastAnswer(ctx)
    assert(not answer.raised and answer.result == nil, 'Expected a refusal, ' .. describe(answer))
    assert(K.contains(answer.err, text), ('Refusal is "%s", expected "%s"'):format(tostring(answer.err), text))
end)

-- For refusals whose wording belongs to another resource (cash, inventory).
K.step('the City Legends server should refuse the action', 'client', function(ctx)
    local answer = lastAnswer(ctx)
    assert(not answer.raised and answer.result == nil, 'Expected a refusal, ' .. describe(answer))
end)

K.step('the City Legends server should accept the action', 'client', function(ctx)
    local answer = lastAnswer(ctx)
    assert(not answer.raised and type(answer.result) == 'table', 'Expected a result, ' .. describe(answer))
end)

K.step('the City Legends server should report {string} as {string}', 'client', function(ctx, key, expected)
    local answer = lastAnswer(ctx)
    assert(not answer.raised and type(answer.result) == 'table', 'Expected a result, ' .. describe(answer))
    ctx:equal(tostring(answer.result[key]), expected, 'Result field ' .. key)
end)

-- server/cards.lua saveDeck: 60 (or `count`) print ids that are not in the
-- tester's binder. Refused before any deck row is written.
K.step('I try to save a City Legends deck of {int} unknown prints', 'client', function(ctx, count)
    local ids = {}
    for i = 1, count do ids[i] = ('fft-missing-print-%03d'):format(i) end
    cardsAction(ctx, 'saveDeck', { name = 'FFT deck', printIds = ids })
end)

-- ---------------------------------------------------------------------------
-- Snapshot (server/cards.lua Cards.snapshot)
-- ---------------------------------------------------------------------------

local function snapshot(ctx)
    local answer = cardsAction(ctx, 'snapshot', {})
    assert(not answer.raised and type(answer.result) == 'table', 'No snapshot: ' .. describe(answer))
    return answer.result
end

K.step('my City Legends snapshot should not include the studio', 'client', function(ctx)
    ctx:equal(snapshot(ctx).studio, nil, 'Studio section')
end)

K.step('my City Legends snapshot should show the studio {string} at grade {int}', 'client', function(ctx, duty, grade)
    local studio = snapshot(ctx).studio
    assert(type(studio) == 'table' and studio.enabled == true, 'The snapshot has no studio section')
    ctx:equal(studio.onDuty, duty == 'on duty', 'Studio duty')
    ctx:equal(tonumber(studio.grade), grade, 'Studio grade')
end)

-- Config.starters: each starter is an exact 60-card list.
K.step('my City Legends snapshot should offer the {string} starter of 60 cards', 'client', function(ctx, key)
    local starter = (snapshot(ctx).starters or {})[key]
    assert(type(starter) == 'table', 'The snapshot does not offer the starter ' .. key)
    local total = 0
    for _, count in pairs(starter.cards or {}) do total = total + count end
    ctx:equal(total, 60, key .. ' card count')
end)

-- Every shop entry is an active, shop-enabled catalog design.
K.step('the City Legends shop should only list active designs for sale', 'client', function(ctx)
    for _, design in ipairs(snapshot(ctx).shop or {}) do
        ctx:equal(design.status, 'active', ('Status of shop design %s'):format(tostring(design.id)))
        assert(design.shopEnabled, ('Shop design %s is not shop-enabled'):format(tostring(design.id)))
    end
end)

-- The studio catalog only lists drafts while on duty (publicList(includeDrafts)).
K.step('the City Legends studio catalog should list no drafts', 'client', function(ctx)
    local studio = assert(snapshot(ctx).studio, 'The snapshot has no studio section')
    for _, design in ipairs(studio.designs or {}) do
        assert(design.status ~= 'draft', ('Draft %s is listed off duty'):format(tostring(design.id)))
    end
end)

-- An existing active design id from the studio catalog, for refusals that
-- must get past the "unknown design" check. The scenario never completes an
-- action on it.
-- Only designs below their lifetime print cap qualify, so a print refusal is
-- about supplies, not the cap (server/cards.lua Cards.print order of checks).
K.step('I note an active City Legends design that can still be printed', 'client', function(ctx)
    local studio = assert(snapshot(ctx).studio, 'The snapshot has no studio section')
    for _, design in ipairs(studio.designs or {}) do
        local limit = tonumber(design.printLimit) or 0
        if design.status == 'active' and (limit <= 0 or (tonumber(design.printedCount) or 0) < limit) then
            ctx.state.cardsDesign = design.id
            return
        end
    end
    error('The catalog has no printable active design')
end)

K.step('I send the City Legends server action {string} for the noted design', 'client', function(ctx, action)
    cardsAction(ctx, action, { designId = assert(ctx.state.cardsDesign, 'Note an active design first') })
end)

-- The physical trading_card granted by 'I hold' has no print metadata, so the
-- snapshot lists it as unverified.
K.step('my City Legends snapshot should list an unverified physical card', 'client', function(ctx)
    for _, card in ipairs(snapshot(ctx).physicalCards or {}) do
        if card.serial == 'UNVERIFIED' and card.valid == false then
            ctx.state.cardsSlot = card.slot
            return
        end
    end
    error('No unverified physical card in the snapshot')
end)

K.step('I send the City Legends server action {string} for that physical card', 'client', function(ctx, action)
    cardsAction(ctx, action, { slot = assert(ctx.state.cardsSlot, 'Find the physical card first') })
end)

-- ---------------------------------------------------------------------------
-- Studio camera (server/studio.lua checkoutCamera / removeAllCameras)
-- ---------------------------------------------------------------------------

K.step('any Card Studio camera issued to me is handed back afterwards', 'server', function(ctx)
    local core, tester = exports.kora_core, ctx.tester
    local before = K.count(ctx, 'card_camera')
    ctx:cleanup(function()
        local extra = (core:getItemCount(tester, 'card_camera') or 0) - before
        if extra > 0 then core:removeItem(tester, 'card_camera', extra, nil, 'functional test cleanup') end
    end)
end)
