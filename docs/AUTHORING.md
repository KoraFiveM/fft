# Create FFT hooks and resource tests

Read the resource's README and AGENTS.md, then inspect its normal command,
interaction, domain API and UI path. Write down the user action, observable
completion, authoritative result and cleanup before implementing anything.

## Generate a first scenario

Use Record for an existing supported flow, or write a short Given/When/Then
feature by hand. Use Scenario Outline and Examples for meaningful input cases.
Validate in `/fft`: undefined steps require a definition, ambiguous steps require
narrower wording. Copy generated drafts out of the panel; preserve the timeline
locally for diagnosis. Never equate a recorded browser click with server success.

A useful request for an agent is:

> Read this resource's instructions and normal action path. Produce one happy
> path and one rejection scenario with server assertions, bounded client hooks,
> deterministic fixture setup and cleanup. Reuse FFT's catalogue. Keep hook code
> in fft_hooks.lua behind fft_kora_hooks. List required companion changes and
> report which checks ran and which require a live server. Do not invent exports.

## Register custom definitions

Copy `examples/fft_example` beside FFT for a complete native-mode example. Its
manifest loads `@fft/import.lua` before shared definitions and declares FFT as a
dependency. Feature registration runs only on the server, after definitions.
List client-readable files in the manifest. Avoid circular dependencies: Kora
resources must start before FFT; use a separate test resource depending on both.

```lua
Then('my custom balance is {int}', {realm='server'}, function(ctx, expected)
    local actual = exports.my_resource:getBalance(ctx.tester) -- implement this API
    ctx:equal(actual, expected, 'Authoritative balance')
end)
```

That API is illustrative, not supplied by FFT. Never invent a resource API and
assume it exists. `Given`, `When` and `Then` take a Cucumber expression, options
and a callback. Always set `realm='client'` or `realm='server'`; patterns must
match exactly one definition. `{int}` and quoted `{string}` values become typed
callback arguments. Optional `requires={'capability.name'}` checks adapter
operations before execution. Use `ctx:call` for an existing adapter operation,
not a resource export name. New operations need a registered adapter; built-in
`kora` extends `native`. `exports.fft:registerAdapter(id, definition)` registers
in the calling realm; its `operations` functions receive `(ctx, ...)`.

`Before` and `After` have the same signature. They are currently global hooks,
not tag-scoped: the pattern is a label, not a filter. Avoid resource-specific
mutations in global hooks. After hooks use a fresh context and may be skipped
on cancellation. Register restoration with `ctx:cleanup(fn)` as soon as a
fixture is acquired; cleanup runs in reverse order even after step failure.

Contexts expose `id`, `tester`, `fixture` and `adapterId` plus:

- `ctx:get(key)` / `ctx:set(key,value)` retain state across exported callbacks.
  Cross-resource tables are snapshots; use these methods rather than modifying
  `ctx.state` from an imported definition. Client and server contexts are separate.
- `ctx:waitUntil(predicate, message, timeout)` polls with cancellation and a
  bounded deadline; `ctx:check()` makes longer loops cooperate with cancellation.
- `ctx:equal(actual, expected, message)` records assertion details on failure.
- `ctx:on(localEvent, callback)` registers an automatically removed listener.
- `ctx:expectConsoleError(text, resource?)` (server realm only) declares a
  server console error the scenario provokes on purpose. A matching error line
  and its traceback are reported under the scenario's `expectedConsole` instead
  of as a `CONSOLE` error. `text` is a plain substring of 16 to 300 characters;
  the declaration ends with the scenario. A declaration that never matched is
  noted in the report and does not fail the scenario. With the Kora adapter the
  same is available as the step `I expect a console error containing {string}`.
- `ctx:cleanup(fn)` registers bounded restoration. Do not call `ctx:check`,
  `ctx:set` or `ctx:call` inside cleanup: its scenario context is cancelled.

A timeout stops accepting results; it cannot forcibly kill arbitrary yielding
Lua. Avoid unbounded loops and late writes. Use request IDs, session IDs and
normal server validation to reject stale completions.

## Add a resource hook

Keep optional Lua hooks in `fft_hooks.lua`. Include it in manifest `files`, not
unconditionally in `client_scripts`, then load it after normal client setup:

```lua
if GetConvar('fft_kora_hooks', 'false') == 'true' then
    local code = assert(LoadResourceFile(GetCurrentResourceName(), 'fft_hooks.lua'))
    assert(load(code, '@my_resource/fft_hooks.lua', 't'))()
end
```

Every action still checks the convar, `GetResourceState('fft') == 'started'`,
`GetInvokingResource() == 'fft'`, and an active string-valued
`LocalPlayer.state.fftSession`. These client checks gate development tooling;
they do not authorize server mutations. The server derives source, confirms
`fft_enabled`, ACE and server-owned session, and validates its regular gameplay
rules. Never trust a client-supplied session bag, owner or inventory record as
server authority. Do not register a generic client-controlled mutation event.

Use bounded action names and validated argument schemas. For NUI, correlate
request + FFT session + inventory lease token, reject expired replies, always
acknowledge callbacks, and require visible/enabled controls. Run the normal UI
handler and intent transport; do not forge success or bypass locks, revisions,
distance, funds or capacity. Inventory's `dragBuy` calls its normal drop handler;
it does not simulate OS pointer input and does not prove physical drag behavior.

Observe successful mutations through a local post-commit server event with a
small receipt (tester, operation ID, item/count or revision). Subscribe before
the action, correlate the tester and operation, wait for completion and assert
both the receipt and final authoritative state. Do not turn observations into
network-authorized mutation APIs. Do not record secrets or whole player records.

## Validate and share

Run syntax checks and deterministic resource tests, regenerate frontend artifacts
when required by that resource, then exercise installation in an isolated live
server. Cover disabled hooks, wrong caller/session, stale replies, success,
rejection, timeout, cancellation, disconnect and resource restart. Export a report
and inspect cleanup errors. Document unmet dependencies rather than marking
proposed hooks as working. Commit resource hooks in their owning repositories,
features in their test repository, and exclude local credentials and reports.
