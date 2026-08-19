#!/bin/sh
# Focused regression tests for VSCode JSONC settings handling.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." >/dev/null 2>&1 && pwd -P)
temp=$(mktemp -d "${TMPDIR:-/tmp}/claude-router-vscode-jsonc-XXXXXX")
trap 'rm -rf "$temp"' EXIT INT TERM

settings="$temp/settings.json"
config="$temp/config.json"

cat > "$config" <<'JSON'
{
  "baseUrl": "https://router.test/",
  "authToken": "test-token",
  "mainModel": "vendor/main-model"
}
JSON

cat > "$settings" <<'JSONC'
{
  // VSCode accepts comments in settings.json.
  "description": "https://example.test//not-a-comment",
  "claudeCode.environmentVariables": [
    { "name": "ANTHROPIC_BASE_URL", "value": "https://router.test" },
    { "name": "ANTHROPIC_MODEL", "value": "vendor/main-model" },
  ],
  /* And block comments too. */
}
JSONC

if out=$("$root/scripts/vscode-switch" status --settings "$settings" 2>&1); then
    case "$out" in
        *"VSCode Claude Code -> router enabled"*) ;;
        *) echo "FAIL: status did not detect router state"; exit 1 ;;
    esac
    case "$out" in
        *"Base URL: https://router.test"*) ;;
        *) echo "FAIL: status did not parse JSONC values"; exit 1 ;;
    esac
else
    echo "FAIL: status rejected valid JSONC"
    echo "$out"
    exit 1
fi

after_status=$(cat "$settings")

if out=$(CLAUDE_ROUTER_CONFIG="$config" "$root/scripts/vscode-switch" on --settings "$settings" 2>&1); then
    echo "FAIL: on accepted JSONC for writing"
    exit 1
fi
case "$out" in
    *"Refusing to modify JSONC VSCode settings"*) ;;
    *) echo "FAIL: JSONC refusal message was not clear"; echo "$out"; exit 1 ;;
esac

[ "$(cat "$settings")" = "$after_status" ] || {
    echo "FAIL: JSONC file changed after refused write"
    exit 1
}
[ ! -e "$settings.bak-claude-router" ] || {
    echo "FAIL: JSONC refusal created a backup"
    exit 1
}

cat > "$settings" <<'JSON'
{
  "description": "https://example.test//not-a-comment",
  "claudeCode.environmentVariables": [
    { "name": "ANTHROPIC_BASE_URL", "value": "https://router.test" }
  ]
}
JSON

if out=$(CLAUDE_ROUTER_CONFIG="$config" "$root/scripts/vscode-switch" on --settings "$settings" 2>&1); then
    case "$out" in
        *"ON  - VSCode Claude Code now routes through the configured endpoint."*) ;;
        *) echo "FAIL: valid JSON was not writable"; exit 1 ;;
    esac
else
    echo "FAIL: valid JSON write failed"
    echo "$out"
    exit 1
fi

[ -e "$settings.bak-claude-router" ] || {
    echo "FAIL: valid JSON write did not create a backup"
    exit 1
}

cat > "$settings" <<'JSON'
{
  "claudeCode.environmentVariables": [
    { "name": "ANTHROPIC_BASE_URL", "value": "https://router.test", }
  ]
JSON

if out=$("$root/scripts/vscode-switch" status --settings "$settings" 2>&1); then
    echo "FAIL: malformed JSON was accepted"
    exit 1
fi
case "$out" in
    *"Invalid JSON in VSCode settings"*) ;;
    *) echo "FAIL: malformed JSON error changed unexpectedly"; echo "$out"; exit 1 ;;
esac

echo "All vscode-switch JSONC tests passed."
