# Kora resource suites

How the functional tests for the `kora_*` resources are laid out, and the rules
every suite follows. Read this with `docs/AUTHORING.md` before adding or
changing a suite. Reference suites: `kora_multijob` (server exports plus a
kora_lib app) and `kora_crypto` (target zone, notifications, no bespoke code).

## Layout

| What | Where |
| --- | --- |
| Scenarios for one resource | `fft/features/kora/<resource>.feature` |
| Steps for one resource | `fft/steps/kora/<resource>.lua` |
| Shared helpers and generic steps | `fft/steps/kora.lua` (`FFT.kora`) |
| A resource's test hook (only when needed) | `<resource>/fft_hooks.lua` |
| Offline validation | `fft/test/validate.sh` |

One step file and one feature file per resource, both named exactly after the
resource. The step file registers its own feature with `K.feature('<resource>')`,
and `fxmanifest.lua` globs both directories, so a new suite touches no shared
file. Do not edit `steps/kora.lua`, `shared/*`, `server/*`, `client/*` or
another resource's suite while writing a suite; report a missing helper instead.

## Rules

1. **No functional edits.** Do not change a resource's existing files. The only
   permitted changes inside a resource are a new `fft_hooks.lua` and the manifest
   line that loads it. Anything more (a "seam") needs explicit approval and is
   listed under *Approved seams* below.
2. **Hooks only when needed.** Most suites need no hook: server exports, events,
   commands, kora_target options and every kora_lib surface (menus, input
   dialogs, alerts, AppShell apps, interact selector, progress bars,
   notifications, text UI) are already reachable. Add a hook only to observe or
   drive something that is otherwise unreachable, such as a resource's own NUI
   page or file-local client state.
3. **Never invent an API.** Open the resource and confirm every export, event,
   callback, command, config key, item name, job name, label and coordinate you
   use. Quote the source file in a comment when a value is copied from config.
4. **Drive the real path.** Use the command, target option, menu or callback a
   player uses. A hook may answer a UI at the callback level; it must not call
   an option's handler directly, set successful state, or skip a server check.
5. **Never force a minigame or skill check.** Do not complete, win or bypass
   one. Leave those success paths uncovered and say so in the feature
   description. Do not start a minigame you cannot let finish inside the limits.
6. **Assert authoritative results.** A notification or menu proves the UI
   reacted. Also assert the server result: items, money, job, metadata, an
   export's snapshot, or a captured server event.
7. **Clean up everything.** Register `ctx:cleanup` the moment a fixture exists.
   Restore jobs, money, items, metadata, position, vehicles and created rows.
   If something cannot be undone (see *Hazards*), do not test it.
8. **One success and one rejection first.** Then add wrong job, missing item,
   insufficient funds, out of range, duplicate request.
9. **Be honest about the level.** Tag and describe what a scenario proves.
   Callback-level UI driving is not a rendered-DOM test.

## Tags

Every scenario carries `@kora` and `@<resource>` (put both on the `Feature`).
Add any that apply:

| Tag | Meaning |
| --- | --- |
| `@server` | Only server steps: exports, events, state. |
| `@ui` | Drives a UI at the NUI-callback level (not DOM clicks). |
| `@world` | Depends on world position, streaming or a camera ray. Coordinates are unverified until run live. |
| `@rejection` | Asserts a refusal and unchanged state. |
| `@slow` | Takes more than about 20 seconds in total. |
| `@global` | Touches state other players can see. Avoid; needs a dedicated server. |
| `@seam` | Depends on an approved seam in the resource. |

## Runtime facts

- Step files are **shared scripts**. Every definition is registered in both
  realms and only the owning realm runs it. File scope may use only `FFT`,
  `K`, plain Lua and `GetResourceState`. Touch `exports`, natives, `Config`,
  `GlobalState`, `LocalPlayer` and `json` inside callbacks only.
  `test/validate.sh` loads each file with those globals absent and fails on a
  violation.
- Client and server contexts have **separate** `ctx.state`. Pass nothing between
  realms through it; assert on the server what the server knows.
- A step may take at most **15 s**, a cleanup **5 s**. Split longer flows into
  several steps (`I wait {int} milliseconds` is capped at 12000).
  `ctx:waitUntil(fn, message, timeout)` polls every 50 ms.
- A pattern must match **exactly one** definition across all files. Generic
  wording belongs to `steps/kora.lua`; resource steps must name the resource's
  domain ("my job roster should include {string}", not "it should include
  {string}"). Patterns are Cucumber expressions: `{int}`, `{float}`, `{string}`
  (quoted in the feature), `{word}`. Avoid `/`, `(`, `)`, `{` and `}` as literal
  text; they are expression syntax.
- A doc string is passed as the last callback argument; decode it with
  `K.json(argument)`.
- Tests run on a dedicated test character. Between scenarios the runner clears
  its items and resets cash and bank; nothing else is reset.
- kora_core job and gang **grades are one-based** in `setJob`/`setGang`
  (`grade 1` is the lowest grade, config key `'0'`).
- fft starts before some `[standalone]` resources. `K.feature` registers the
  feature when the resource is installed; `K.started` (and the
  `resource {string} is running` step) fails clearly when it is not running.
  Start every feature with `Background: Given resource "<resource>" is running`.

## Helper API (`local K = FFT.kora`)

Begin every step file with:

```lua
local K = FFT.kora
if not K then return end
K.feature('<resource>')
```

| Helper | Realm | Purpose |
| --- | --- | --- |
| `K.step(pattern, realm, fn, requires?)` | both | Register a step. `fn(ctx, ...)`. |
| `K.feature(name, resource?)` | both | Register `features/kora/<name>.feature`. Before each of its scenarios the runner checks that `resource` (default `name`) is started on the server and the client, and fails the scenario with one plain line if not. |
| `K.started(resource)` | both | Error unless the resource is started. |
| `K.export(resource, name, ...)` | both | Call a real export with a readable error. |
| `K.hook(resource, action, ...)` | both | Call `exports[resource]:fftAction(action, ...)`. |
| `K.must(ok, err, ...)` | both | Raise `err` unless `ok`; returns the values. |
| `K.contains(text, part)` | both | Case-insensitive substring test. |
| `K.json(argument)` | both | Decode a doc string. |
| `K.player(ctx)` | server | Authoritative PlayerData (`citizenid`, `job`, `gang`, `money`, `items`, `metadata`). |
| `K.count(ctx, item)` / `K.money(ctx, account)` | server | Item total / account balance. |
| `K.setJob(ctx, name, grade, onDuty?)` | server | Set job, restore job and roster in cleanup. |
| `K.capture(ctx, event, filter?)` / `K.captured(ctx, event)` | server | Record a local server event's arguments for this scenario. Call before acting. |
| `K.expectConsoleError(ctx, text, resource?)` | server | Declare a server console error the scenario provokes on purpose (see *Expected console errors*). |
| `K.watchMoney(ctx)` | server | Capture `QBCore:Server:OnMoneyChange(src, account, amount, action, reason)` for the tester. |
| `K.ui(action, ...)` / `K.uiState()` | client | kora_lib hook: `state`, `log`, `notifications`, `app`, `menu.select`, `menu.cancel`, `input.submit`, `input.cancel`, `alert.answer`, `interact.select`, `interact.close`, `app.action`, `app.close`. |
| `K.nui(resource, name, body?, timeout?)` | client | Call a resource's own `RegisterNUICallback` handler through a real fetch from the FFT page; returns its answer, errors when unanswered. |
| `K.teleport(ctx, x, y, z, heading?)` | client | Move the tester, restore in cleanup. |
| `K.aimAt(x, y, z)` | client | Turn ped and camera to a point. |
| `K.target(ctx, label, entity?)` | client | Select a kora_target option through the real targeting state machine. |
| `K.waitNotification(ctx, text, timeout?)` | client | Wait for a kora_lib notification since the scenario began. |
| `K.waitMenu(ctx, title?)` | client | Wait for a kora_lib menu; returns `{ kind, title, items }`. |

`K.uiState()` returns `{ interact, interactActive, menu, input, alert, app,
progress, textui, minigame, sequence }`; absent surfaces are nil.
`K.ui('log', since)` returns every `Kora.nui.send` action since a sequence
number, which is the way to observe a kora_lib-routed message that has no
dedicated field.

Server steps cannot call a `Kora.callback` handler as the player. To exercise a
server callback, drive the client path that triggers it (command, target, app
action) or add a client hook action that calls `Kora.callback.trigger`.

## Generic steps

Reuse these before writing a step. `(s)` runs on the server, `(c)` on the client.

Environment and fixtures:

- (s) `resource {string} is running`
- (s) `I expect a console error containing {string}` / `I expect a console error from {string} containing {string}` (resource, then text; see *Expected console errors*)
- (s) `my job is {string} at grade {int}` / `I am on duty as {string} at grade {int}` / `I am off duty as {string} at grade {int}`
- (s) `my job should be {string}` / `I should be on duty` / `I should be off duty`
- (s) `my gang is {string} at grade {int}`
- (s) `my metadata {string} is {int}` / `my metadata {string} should be {int}` / `... should be at least {int}` / `... should be at most {int}`
- (s) `I hold {int} {string}` (granted, removed in cleanup)
- (s) `I remember how many {string} I have` then `I should have {int} more {string} than before` / `I should have {int} fewer {string} than before`
- (s) `I should have at least {int} {string}` / `I should have no {string}` / `I should have {int} {string}`
- (s) `I have {int} in my {string} account` (restored in cleanup)
- (s) `I remember my {string} balance` then `my {string} balance should have increased by {int}` / `decreased by {int}` / `should have increased` / `should have decreased` / `should be unchanged`
- (s) `a money change should have been recorded for {string}` (after `I remember my {string} balance`)

Movement, commands, vehicles, timing:

- (c) `I stand at {float} {float} {float} facing {float}` / `I aim at {float} {float} {float}`
- (c) `I run the command {string}` (no leading slash)
- (c) `I am driving a temporary {string}` (client-spawned, deleted in cleanup; it is not an owned or persisted vehicle) / `I should be in a vehicle`
- (c) `I wait {int} milliseconds`

Targeting (kora_target):

- (c) `I target {string}` / `the target option {string} should be visible` / `no target option should be visible`

kora_lib surfaces (callback level):

- (c) `a menu should open` / `a menu titled {string} should open` / `the menu should list {string}` / `the menu should not list {string}` / `I choose {string} in the menu` / `I close the menu` / `no menu should be open`
- (c) `an input dialog should open` / `I submit the input dialog with:` (doc string: JSON object of field id to value) / `I cancel the input dialog`
- (c) `a confirmation should open` / `I confirm` / `I decline`
- (c) `I should see a notification containing {string}` / `I should not see a notification containing {string}`
- (c) `a progress bar should start` / `a progress bar labelled {string} should start` / `the progress bar should finish` / `no progress bar should be running`
- (c) `the text prompt should show {string}` / `no text prompt should be shown`
- (c) `the interact selector should offer {string}` / `I choose {string} in the interact selector`
- (c) `the app {string} should be open` / `I trigger the app action {string}` / `... on {string}` (item id) / `... with:` (doc string `{ "itemId", "value", "viewId", "tabId" }`) / `the app action {string} should be unavailable` / `the app should answer with a {string} notice containing {string}` / `I close the app` / `no app should be open`

Menu items match by label or id. App ids, action ids and item ids come from the
resource's `Kora.nui.registerApp` definition. kora_lib refuses an action the
open app does not currently declare, so an action hidden for the current state
is asserted with `the app action {string} should be unavailable`.

## Expected console errors

Every error-looking line on the **server** console during a run is logged as a
`CONSOLE` error against the running scenario. A rejection scenario that makes a
resource print one on purpose (an `assert` inside an export or event handler, a
red refusal line) declares it, so the error log only holds surprises:

```lua
-- Text from kora_chat/server/main.lua:264-265.
K.expectConsoleError(ctx, ("Message type '%s' is owned by '%s'."):format(name, RESOURCE), RESOURCE)
```

```gherkin
# kora_fishing/server/shops.lua:19
And I expect a console error from "kora_fishing" containing "Your fishing level is too low to purchase this item"
When I trigger the app action "kora_fishing:purchase" with:
```

- Declare it **before** the refusing action. Put the helper in the step when
  the step itself is the refusal; use the Gherkin step when the refusing step
  is generic or runs on the client (the declaration is always server-realm).
- The text is a plain, case-sensitive substring of the error line with colour
  codes removed: no patterns, one line, 16 to 300 characters, at least 8
  letters or digits, at most 8 declarations per scenario. Copy it from the
  resource source and quote `file:line` in a comment. Prefer the message over
  the `SCRIPT ERROR: @file:line:` prefix, and name the resource.
- Only the line that is itself the error is compared. Its continuation lines
  (traceback) follow it; any other error in the scenario is still logged.
- It lasts until the scenario's cleanup has finished and is then gone: the
  same line in the next scenario, or in another tester's run, is an error.
- Nothing disappears. The scenario's result gets
  `expectedConsole = [{ text, resource, matched, lines }]`, the summary counts
  `expectedConsole` (matched lines) and `unmatchedConsole`, and the error log
  ends with one `[EXPECTED CONSOLE]` block per declaration.
- A declaration that never matched is reported as `NEVER SEEN` and does **not**
  fail the scenario. Console capture is asynchronous and advisory (a console
  error never fails a step either, and whether a refusal prints depends on the
  resource's logging), so it must not decide a result. The refusal itself is
  proven by the scenario's own assertions. Treat `NEVER SEEN` as a prompt to
  re-check the text against the source.
- Never declare an error to quieten a scenario that should not provoke one.

## Writing a hook

Create `<resource>/fft_hooks.lua` and list it as the **last** entry of the
realm's script list in the manifest, with this comment:

```lua
    -- Optional FFT hooks: returns immediately unless fft_kora_hooks is true.
    'fft_hooks.lua'
```

Resources whose manifest globs a directory need the file at the resource root
with an explicit entry. Use `fft_hooks.lua` for a client hook; if a server hook
is also needed name it `fft_hooks_server.lua`. Check the resource's own tests
for assertions about manifest contents or load order before editing it.

Client template:

```lua
-- Optional FFT development hooks (client). Listed last in fxmanifest.lua and
-- inert unless `setr fft_kora_hooks true`. No other file references FFT.
if GetConvar('fft_kora_hooks', 'false') ~= 'true' then return end

local RUNNER = 'fft'
local VERSION = 1

local function session()
    if GetResourceState(RUNNER) ~= 'started' then return nil end
    local id = LocalPlayer.state.fftSession
    return type(id) == 'string' and id or nil
end

local actions = {}

-- Read-only snapshot of state the runner cannot otherwise see.
function actions.state()
    return { open = false }
end

exports('fftVersion', function() return VERSION end)
exports('fftAction', function(action, ...)
    if GetInvokingResource() ~= RUNNER or not session() then
        return false, 'FFT hooks are disabled or session is not authorised'
    end
    local handler = actions[action]
    if not handler then return false, 'Unsupported FFT action: ' .. tostring(action) end
    return handler(...)
end)
```

Server hooks use the same shape, check `GetInvokingResource() == 'fft'`, take
the tester's source as the first action argument and verify
`type(Player(src).state.fftSession) == 'string'`.

Hook rules:

- Actions return a value, or `false, message, code` for a refusal. Use short
  stable codes (`not_open`, `not_visible`, `rejected`, `blocked`, `invalid`).
- Validate every argument's type and length. Never accept a function name,
  event name or export name from the caller.
- A hook can only see globals. File-local state in the resource is out of
  reach, and making it reachable is a functional edit. Observe instead:
  - Outgoing messages to the resource's own NUI: wrap the global
    `SendNUIMessage` (works only where the resource calls the global rather
    than a captured local) and keep a bounded log.
  - Drive the resource's own NUI callbacks the way the browser does: call
    `K.nui('<resource>', '<name>', body)` from the step file. It fetches
    `https://<resource>/<name>` from the FFT page, so the registered handler
    and its validation run and no hook is needed for this. Do not fire
    `__cfx_nui:<name>` with `TriggerEvent`: current clients do not answer it.
  - Server round trips: `Kora.callback.trigger(name, ...)` or the same
    `TriggerServerEvent` the resource's client code sends, with the same
    arguments. The server's checks stay in force. Do not send an event the
    normal client would not send in that state.
- Keep buffers bounded, summarise tables before returning them, and never
  return functions or whole player records.
- A hook must not change behaviour when no session is active.
- Bump `VERSION` when an action's contract changes. Have the suite assert it
  in a step if it depends on a specific version.

## Approved seams

These are the only functional-file changes agreed so far. Keep each to the
smallest possible edit and mark the scenarios `@seam`.

| Resource | Seam | Why |
| --- | --- | --- |
| `kora_target` | `Target._fftSelected` call in `runOption` | Observe selections that passed every gate. |
| `kora_inventory` | `web/src/lib/fft.ts` and `data-fft-*` attributes | Drive rendered shop controls. |
| `kora_customs` | Reset of the repair cooldown table | Repeatable repair scenarios. |
| `kora_truckrobbery` | Police-count check and the 10 minute server lock | Run without online police; repeatable. |
| `kora_robberies` | House robbery state reset | Repeatable house scenarios. |
| `kora_dispatch` | `fft` in `Config.trustedCallers` | `createCall`/`closeCall` need a trusted caller. |

## Hazards

Do not write scenarios that trigger these:

- **kora_pawnshop** `exploitBan`: an invalid or out-of-range sell permanently bans the player.
- **kora_drugs** `onCooldown`: the fifth hit drops the player.
- **kora_dispatch** `createCall`/`closeCall`: need a trusted caller (see seams).
- **kora_truckrobbery**: a started robbery locks the server for 10 minutes.
- **kora_skills** XP, **kora_mdt** and **kora_admin** report rows: no delete API. Read only.
- **kora_cards** `claimStarter` and **kora_cityhall** starter items: one-shot per character.
- **Global broadcasts**: `/ooc` and other chat to all players, weather and time changes, announcements, `PlaySoundAll`, the scoreboard busy flag. Tag `@global` if unavoidable, and restore.
- **Bans, kicks, wipes, character deletion, economy-wide resets**: never.
- Anything that messages, charges, jails, cuffs or moves **another player**. The tester is the only subject.

## Validate

```sh
bash test/validate.sh
```

It syntax-checks every Lua file, loads the step files in both realms with
FiveM globals absent, rejects duplicate patterns, and parses every feature with
the server's bundled parser, reporting undefined and ambiguous steps and
features no step file registers. It also runs `test/console.lua`, which
exercises the console error log and expected console errors against the real
`shared/core.lua`. It executes no step: exports, labels,
coordinates and timings are proven only by a live run with a connected client.

After changing a hook or manifest, run that resource's own offline tests
(`test/run.sh` where present) and report the result next to the result on the
unmodified tree if anything fails.

## Handing over a suite

Report, per resource: files created, hook actions added (if any) and why they
were needed, scenarios written with their tags, what is deliberately not
covered and why, values that are unverified until a live run (coordinates,
labels, timings), and which checks ran. Do not commit.
