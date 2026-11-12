# FFT — FiveM Functional Testing

FFT runs Gherkin scenarios inside a real FiveM client/server session. Lua steps
execute in an explicit realm; an in-game panel records gameplay, validates
features, replays steps and exports JSON reports. It is a development tool.

## Install

Copy this repository, including `dist/` and `ui/`, to a resource directory named
**fft**. The bundled parser and browser assets need no build for installation.
Do not keep the old `fivem-functional-testing` folder alongside it. Replace old
`ensure`, `@.../import.lua`, dependency, export and resource-state references
with `fft`. Restart dependent hook resources after migrating. FiveM KVP data is
scoped to the resource name: the old test-character pointer will not migrate
automatically. Expect FFT to create another test character; manage obsolete test
characters through normal character tooling.

Copy the settings from `fft.cfg` into a private server config, replace
`YOUR_LICENSE` with your tester's license, uncomment the ACE grant, then start
`fft`. Never commit your personal config. Example:

```cfg
set fft_enabled true
setr fft_adapter native
setr fft_kora_hooks false
setr fft_server_address "localhost:30120"
# Replace this placeholder locally:
add_ace identifier.license:YOUR_LICENSE fft.use allow
ensure fft
```

`fft_enabled` is server-side authorization; `fft.use` restricts access to named
testers. `setr` replicates adapter/hook settings to clients. Configure these
before starting resources. Native mode uses no framework. Select only `@native`
scenarios in native mode: bundled Kora scenarios require the Kora adapter.

For Kora, start compatible `kora_core`, `kora_target` and `kora_inventory`
resources first, set `fft_adapter` to `kora` and `fft_kora_hooks` to `true`, then
start FFT. Inventory, target and kora_lib must expose the `fftVersion()` the adapter expects and
`fftAction(...)`; install the companion changes in those repositories. Inventory
ships `fft_hooks.lua` in its manifest and executes it only when the replicated
hook convar is true at inventory startup. Restart inventory after changing it.
Kora also needs its normal database, item definitions, shop and map setup.

Use an isolated development database/server. Kora runs create a persistent test
character owned by the tester's license (a free character slot is required),
clear its inventory, reset cash/bank before and after scenarios, and restock the
shared `vendingmachine` shop. These writes are real. The runner attempts to
restore the original character; inspect setup, cleanup and restoration errors.
Recording uses the active character; switch to a disposable one yourself.

## Run and record

1. Connect with the authorized FiveM client and enter `/fft`.
2. Set a tag filter, for example `@native` or `@kora and @vending`.
3. Refresh the catalogue, choose a scenario or **Run matching**, and inspect
   Results. Export JSON for review. Client outcomes are labelled client-reported;
   use server assertions to prove inventory, money or other durable effects.
4. For vending, stand near a streamed soda machine and use Record → Capture
   vending fixture. Copy the fixture into `config.lua` if it must survive restart.
5. Record gameplay and press F7 to stop (or use the Stop button). Review the
   original timeline alongside the editable draft. Validate, then replay it.
6. **Debug draft** pauses before every step and keeps the scenario context.
   Press F6 (`fft_step`, rebindable) for the next step, or open `/fft` and use
   **Next step** / **Run to end**.

### Reports and the error log

Every run writes one JSON file with all results and one text log of its errors
to `reports/` inside this resource (the folder must exist; it is git-ignored):
`latest.json` and `latest-errors.log` are rewritten during the run, and each
finished run is kept as `<uuid>.json` / `<uuid>-errors.log`. The same data is
available from the Results and Errors tabs (download or copy).

Each report records its `uuid` and who ran it (`tester.name`, `tester.license`).
`reports/index.json` lists the kept runs. The **Past runs** list on the Results
tab loads any of the tester's own earlier reports, across restarts; a tester is
matched by license and cannot list or load another tester's runs. The newest 50
runs per tester are kept and older ones are deleted.

The error log holds two kinds of entry, each tied to its scenario and step:
`TEST` (a step, hook, cleanup or setup failure) and `CONSOLE` (an error line
printed to the **server** console while that step ran). Console errors do not
fail a step. Client (F8) console output is not readable by scripts and is not
captured. The log is capped at 1000 entries per run.

A scenario that provokes a server console error on purpose can declare it with
`ctx:expectConsoleError(text, resource?)` (see docs/AUTHORING.md). Matching
lines are not counted as `CONSOLE` errors: they are listed per scenario as
`expectedConsole` in the JSON, counted in the summary (`expectedConsole`,
and `unmatchedConsole` for declarations that never matched) and printed as
`[EXPECTED CONSOLE]` blocks at the end of the error log.
   Copy or export the `.feature` into a resource and register it for reuse.

Recording generates a draft for the recognized soda-vending flow. Other events
become comments for manual review; this is not an arbitrary hook or test code
generator. Add Lua definitions for undefined steps using the guide below.
The panel exports files through the browser; it does not write into resource
folders. Reports and fixtures in memory are lost on restart.

## Authoring and handoff

- [Create hooks and tests](docs/AUTHORING.md): API, example resource and generation workflow.
- [Design testable resources](docs/TESTABLE_RESOURCES.md): authority, observability and cleanup.
- [Agent instructions](AGENTS.md): implementation and review checklist.
- [Hook backlog](HOOK_TEST_PLAN.md): proposed scenarios, not implemented coverage.

The runnable `examples/fft_example` resource demonstrates custom client and
server steps using the native adapter. Copy it beside FFT, `ensure fft` then
`ensure fft_example`, refresh `/fft`, and filter `@example`. Never ensure the
example directory inside FFT as a second copy of FFT itself.

## Troubleshooting

- Permission error: verify `fft_enabled` and the tester's `fft.use` ACE.
- Missing Kora hook export: install companion hooks, enable their convar before
  resource startup and restart the resource. All guards must refer to `fft`.
- Undefined/ambiguous step: inspect the catalogue; match one Cucumber expression
  exactly and register it in the correct realm before loading the feature.
- Timeout: inspect streamed fixtures, hook replies and server receipts. Step
  timeout is 15 seconds and cleanup timeout is 5 seconds by default (`config.lua`).
- Restarting FFT clears external registrations. The import re-registers step
  definitions, but feature registration must run again: restart the test resource.
- Existing NUI transparency changes have not been verified in a live client;
  inspect HUD/focus behavior on installation before running a suite.

To disable access, set `fft_enabled false`. Disable `fft_kora_hooks` and restart
hook resources to remove their optional hooks. Stop FFT when finished. No
headless CLI or unattended CI driver is supplied: gameplay runs need a connected
client. The committed parser is a bundled artifact with third-party notices in
`dist/licenses.txt`; parser source/build tooling is not included in this snapshot.
