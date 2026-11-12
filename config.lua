FFTConfig = {
    adapter = GetConvar('fft_adapter','native'), -- explicit; kora composes native
    serverAddress = GetConvar('fft_server_address','localhost:30120'), -- display/connect hint
    stepTimeout = 15000,
    cleanupTimeout = 5000,
    maxRecordingEvents = 500,
    stopRecordKey = 'F7',
    debugStepKey = 'F6', -- default key for 'next step' while debugging a draft (rebindable in GTA settings)
    -- Optional override captured in Record. Otherwise discover a streamed soda prop.
    -- Fallback search area near the Grove Street LTD; custom maps can override it.
    vendingSearch = {x=-47.3,y=-1758.7,z=29.4},
    -- { model=number, coords={x=...,y=...,z=...},
    --   approach={x=...,y=...,z=...,heading=...}, camera={heading=...,pitch=...} }
    vending = nil,
    maxTestBalance = 1000000, -- ceiling for 'I have {int} in my {string} account'
    testCharacter = { cash = 100, bank = 0 }, -- dedicated character is created on first Kora run
}
