#!/usr/bin/env bash
# Offline checks for the step and feature files. Needs lua 5.4 and node; no
# server. Proves that files load, patterns are unique and every feature step
# resolves to exactly one definition. It does not execute any step. It also
# runs test/console.lua, the deterministic test of the console error log.
set -uo pipefail
cd "$(dirname "$0")/.."
status=0
for file in $(find . -name '*.lua' -not -path './node_modules/*'); do luac -p "$file" || status=1; done
# Console error log and expected console errors (shared/core.lua), run for real.
lua test/console.lua || status=1
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
check() { # adapter, features...
    local adapter="$1"; shift
    echo "== adapter $adapter =="
    lua test/catalogue.lua "$adapter" config.lua shared/core.lua shared/adapters.lua steps/builtin.lua steps/kora.lua steps/kora/*.lua > "$out" || status=1
    node test/validate.cjs "$out" "$@" || status=1
}
shopt -s nullglob
check kora features/*.feature features/kora/*.feature "$@"
check native features/native.feature
exit "$status"
