# Working on FFT

Read README.md and docs/AUTHORING.md before changing hooks or scenarios.
The canonical FiveM resource name is `fft`; use `@fft/import.lua` for imports.
Keep framework hooks in their own resource repositories and optional files.

Before generating a test, inspect the actual resource APIs, catalogue and owning
AGENTS.md. Define the expected server result, fixture and cleanup. Reuse existing
steps, declare explicit realms, avoid duplicate expressions, and validate drafts.
The recorder recognizes a limited vending flow; it does not generate arbitrary
hooks. Never invent completion receipts or bypass gameplay authorization.

Use ctx:get/set across exported callbacks, bounded polling, session/request
correlation and immediate cleanup registration. Treat client results as
client-reported. Global Before/After hooks are not tag-scoped. Feature registration
must be repeated after an FFT restart; restart the external test resource.

Check JavaScript and Lua syntax, parser validation and deterministic tests before
handoff. Live gameplay validation requires a connected client and isolated dev
server. Record which checks actually ran, including unavailable checks. Do not
start a real server without a request. Do not modify the bundled parser without
source/build tooling and retained third-party notices.

Before staging, inspect the complete diff and file modes; scan for credentials,
license identifiers, private hosts, tokens and database URLs. Commit only example
config. Exclude local configs, environment files, KVP/runtime data, node_modules,
recordings, screenshots and reports. Do not commit or push unless requested.
