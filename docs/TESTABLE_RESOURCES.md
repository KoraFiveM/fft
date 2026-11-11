# Write resources that FFT can test

Keep domain decisions in server functions with explicit inputs, bounded results
and a stable public API. Resolve the player from the server source. Authenticate
and authorize every operation, validate revisions, leases, distance and routing
bucket, and commit once. Return structured rejection codes such as
`insufficient_funds` so tests can distinguish a correct rejection from a crash.
Test pure rules with ordinary Lua unit tests; reserve FFT for real integration
paths that require a player, network, world entities or NUI.

Keep presentation separate from authority. A browser sends intent; the server
owns balances, stock, items and permissions. Provide stable semantic UI selectors,
accessible labels and visible/enabled/pending state. Route keyboard, pointer and
test actions through the same handler. A hook that sets successful state directly
can hide a broken gameplay path. Separate tests for domain outcomes, rendered
state and actual pointer gestures; describe what each test really proves.

Emit observations only after successful commit. Include a correlation ID and
bounded receipt, and expose read-only authoritative snapshots through narrow
server APIs. Client animations and optimistic UI are not transaction receipts.
Subscribe before acting so a fast completion cannot be missed. A rejection test
should assert its reason and unchanged inventory, balances and stock.

Make fixtures explicit and scoped to a tester. Seed through normal APIs rather
than direct database writes. Use unique operation/entity IDs; isolate shared shop
stock, jobs, weather and other global state or serialize affected tests. Restore
what you changed and delete created fixtures. Design cleanup to tolerate partial
setup, repeated execution, lost entities and disconnected players. Never run
destructive setup against ordinary player records. FFT's current Kora runner
restocks shared vending stock, so use a dedicated server for those scenarios.

Represent asynchronous work as pending, committed or rejected with bounded
completion. Avoid fixed sleeps and infinite loops. Check cancellation before
writes, reject stale operation IDs and release locks on failure. Make time and
randomness injectable into pure domain code where practical. World fixtures need
explicit models, coordinates, approach positions and streaming checks.

Keep optional development hooks in a separate file and load it only on opt-in.
Leave normal server validation intact and default hooks off. Test disabled mode
as seriously as enabled mode. Removing FFT must not break ordinary resource
startup or gameplay. Version hook contracts and document action inputs, results,
event receipts, timeouts and cleanup so another developer can add scenarios
without reading private implementation state.

Start coverage with one success and one rejection, then add duplicate requests,
stale revisions, exhausted stock, capacity boundaries, wrong job, range and bucket
changes, cancellation and restart recovery. Assert the durable result and restored
fixture state, not merely that a callback fired.
