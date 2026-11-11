-- kora_crypto: crypto stick exchange (target zone at Crypto.Exchange) and /checkCrypto.
-- No resource hook. Cracking a stick is decided by a kora_lib minigame, which
-- FFT never forces, so the success path is not covered; the server events the
-- minigame ends with are sent directly to prove their guards (distance, and
-- the single-use crack ticket that only qb-crypto:server:hasCryptoStick mints).
local K = FFT.kora
if not K then return end
K.feature('kora_crypto')

K.step('the crypto market should publish a price within its configured bounds', 'server', function(ctx)
    K.started('kora_crypto')
    local market = GlobalState.Qbit
    assert(type(market) == 'table', 'GlobalState.Qbit is not published')
    local worth = tonumber(market.Worth)
    -- Bounds are Crypto.Lower / Crypto.Upper in kora_crypto/shared/config.lua.
    assert(worth and worth >= 500 and worth <= 5000, 'Qbit worth out of bounds: ' .. tostring(market.Worth))
    ctx:equal(type(market.History), 'table', 'Price history type')
end)

-- Price moves in HandlePriceChance() (server/server.lua): casual moves of 1-10,
-- Luck 20-45, Crash 20-80, then clamped to Lower/Upper; the history keeps the
-- last 4 { PreviousWorth, NewWorth } moves and Worth is the newest NewWorth.
local LOWER, UPPER, LARGEST_MOVE, HISTORY = 500, 5000, 80, 4

local function inBounds(value) return type(value) == 'number' and value >= LOWER and value <= UPPER end

K.step('the crypto market history should be a chain of bounded price moves', 'server', function(ctx)
    K.started('kora_crypto')
    local market = assert(GlobalState.Qbit, 'GlobalState.Qbit is not published')
    local history = market.History or {}
    assert(#history <= HISTORY, ('History holds %d moves, at most %d expected'):format(#history, HISTORY))
    for index, move in ipairs(history) do
        local before, after = tonumber(move.PreviousWorth), tonumber(move.NewWorth)
        assert(inBounds(before) and inBounds(after), ('Move %d leaves the price bounds: %s -> %s'):format(index, tostring(move.PreviousWorth), tostring(move.NewWorth)))
        assert(math.abs(after - before) <= LARGEST_MOVE, ('Move %d is larger than any configured move: %d -> %d'):format(index, before, after))
        local nextMove = history[index + 1]
        if nextMove then
            ctx:equal(tonumber(nextMove.PreviousWorth), after, ('Move %d does not start where move %d ended'):format(index + 1, index))
        end
    end
    if #history > 0 then
        ctx:equal(tonumber(history[#history].NewWorth), tonumber(market.Worth), 'Newest NewWorth versus the published worth')
    end
end)

-- RefreshCrypto() publishes the `crypto` row (schema.lua seeds 'qbit' at 1000).
K.step('the crypto market should match its database row', 'server', function(ctx)
    K.started('kora_crypto')
    K.started('kora_sql')
    local reply = {}
    exports.kora_sql:single('SELECT worth, history FROM crypto WHERE crypto = ?', { 'qbit' }, function(result, err)
        reply.result, reply.err, reply.done = result, err, true
    end)
    ctx:waitUntil(function() return reply.done end, 'kora_sql did not answer the crypto row read', 5000)
    local row = reply.result
    assert(type(row) == 'table', 'No crypto row for qbit: ' .. tostring(reply.err))
    local market = assert(GlobalState.Qbit, 'GlobalState.Qbit is not published')
    ctx:equal(tonumber(market.Worth), tonumber(row.worth), 'Published worth versus the database row')
    local stored = type(row.history) == 'string' and row.history ~= '' and json.decode(row.history) or {}
    ctx:equal(#(market.History or {}), #stored, 'Published history length versus the database row')
end)

-- client/client.lua checkCrypto reads the client's PlayerData money.crypto.
K.step('my Qbit wallet should read {int} on the client', 'client', function(ctx, amount)
    ctx:waitUntil(function()
        return tonumber(exports.kora_core:getPlayerData({ 'money', 'crypto' })) == amount
    end, 'The client never saw the Qbit balance ' .. amount, 3000)
end)

-- locales/en.lua notify.crypt_worth: 'You Have %s QBit(s) Total Value: $ %s'
-- with math.ceil(crypto * GlobalState.Qbit.Worth).
K.step('I should see the Qbit wallet value for {int} coins', 'client', function(ctx, amount)
    local worth = tonumber((GlobalState.Qbit or {}).Worth)
    assert(worth, 'GlobalState.Qbit is not published')
    K.waitNotification(ctx, ('QBit(s) Total Value: $ %s'):format(math.ceil(amount * worth)))
end)

-- The events the minigame ends with (client/client.lua). Both assert
-- Kora.distance.player(src, Crypto.Exchange, 5.0) and then need a crack ticket.
K.step('I report a successful crypto crack to the server', 'client', function()
    K.started('kora_crypto')
    TriggerServerEvent('qb-crypto:server:crackCryptoStick')
end)
K.step('I report a failed crypto crack to the server', 'client', function()
    K.started('kora_crypto')
    TriggerServerEvent('qb-crypto:server:ExchangeFail')
end)
