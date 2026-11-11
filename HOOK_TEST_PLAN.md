# Tests awaiting resource hooks

The scenarios in `features/` use existing native APIs and the Kora core, target, and inventory hooks. These additional tests need observable, authorized hooks in the named resources before they can be reliable. Keep hooks behind the existing `fft_kora_hooks` convar and active `fftSession` state bag, and make each action report a result that the test can assert.

| Resource | Proposed scenario | Required hook or observable event |
| --- | --- | --- |
| `kora_inventory` | Move an item between two player slots by dragging | UI action that starts a real slot drag/drop; server move confirmation and final slot snapshot. |
| `kora_inventory` | Reject an over-capacity purchase without charging cash | UI action for a purchase attempt; structured rejection reason and unchanged balance/stock assertion. |
| `kora_target` | Choose between two options on one entity | Test-only visible option snapshot and selection by stable registration ID, with a real visibility recheck. |
| `kora_banking` | Deposit and withdraw cash | UI controls for amounts and submit; server transaction receipt plus account balances. |
| `kora_garages` / `kora_vehiclekeys` | Store and retrieve a vehicle | Test vehicle creation and cleanup; garage transaction receipt and key ownership query. |
| `kora_hud` | Display health, armour, and cash changes | Read-only rendered HUD state or browser observation endpoint, after normal player state updates. |
| `kora_clothing` | Save and reload an outfit | Test-only UI selection and saved appearance snapshot; cleanup of the created outfit. |
| `kora_phone-stevie` | Open and close the phone | UI open/close state and focus assertion, without sending messages to other users. |
| `kora_police` | Gate a restricted action by job | Controlled test job assignment and target option snapshot, with original job restored. |
| `kora_weathersync` | Apply a weather and time change | Scoped test clock/weather override and client observation, restoring server settings afterward. |

Before implementing each hook, check the resource's README and AGENTS.md, then keep its change in that resource repository. Tests should use a seeded test character and clean up any created entities or records.
