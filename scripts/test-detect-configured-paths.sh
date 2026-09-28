#!/usr/bin/env bash
# Existing custom install directories must count as detected for --tool all.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/agency-detect-paths.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
mkdir -p "$repo/scripts" "$repo/engineering" "$repo/integrations"
cp "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/lib.sh" "$repo/scripts/"
cat > "$repo/divisions.json" <<'EOF'
{
  "divisions": {
    "engineering": {}
  }
}
EOF
cat > "$repo/engineering/agent.md" <<'EOF'
---
name: Example Agent
description: Example agent
---
Instructions.
EOF

cases=(
  'copilot COPILOT_AGENT_DIR'
  'cursor CURSOR_RULES_DIR'
  'gemini-cli GEMINI_AGENTS_DIR'
  'opencode OPENCODE_AGENTS_DIR'
  'openclaw OPENCLAW_DIR'
  'qwen QWEN_AGENTS_DIR'
  'zcode ZCODE_AGENTS_DIR'
  'codex CODEX_AGENTS_DIR'
  'osaurus OSAURUS_SKILLS_DIR'
  'hermes HERMES_PLUGIN_DIR'
  'dsh DSH_SKILLS_DIR'
)
for entry in "${cases[@]}"; do
  tool="${entry%% *}"
  variable="${entry#* }"
  home="$tmp/home-$tool"
  configured="$home/custom/agents"
  mkdir -p "$configured"
  output="$(env -i HOME="$home" PATH=/usr/bin:/bin "$variable=$configured" \
    /bin/bash "$repo/scripts/install.sh" --no-interactive --tool all --dry-run 2>&1)"
  if [[ "$output" != *"Tools:   $tool"* ]]; then
    printf 'FAIL: %s ignored existing %s\n%s\n' "$tool" "$variable" "$output" >&2
    exit 1
  fi
done
echo "PASS: --tool all detects ${#cases[@]} existing custom tool destinations"

missing_home="$tmp/missing-home"
output="$(env -i HOME="$missing_home" PATH=/usr/bin:/bin QWEN_AGENTS_DIR="$missing_home/not-created" \
  /bin/bash "$repo/scripts/install.sh" --no-interactive --tool all --dry-run 2>&1)"
[[ "$output" == *'No tools selected or detected'* ]] || {
  echo 'FAIL: a nonexistent custom path counted as an installed tool' >&2
  exit 1
}
echo 'PASS: a nonexistent custom destination does not trigger detection'

qwen_home="$tmp/install-home"
qwen_dir="$qwen_home/custom agents"
mkdir -p "$qwen_dir" "$repo/integrations/qwen/agents"
printf 'Qwen agent\n' > "$repo/integrations/qwen/agents/example-agent.md"
env -i HOME="$qwen_home" PATH=/usr/bin:/bin QWEN_AGENTS_DIR="$qwen_dir" \
  /bin/bash "$repo/scripts/install.sh" --no-interactive --tool all --no-convert > "$tmp/install-output" 2>&1
[[ -f "$qwen_dir/example-agent.md" ]] || {
  echo 'FAIL: auto-detected Qwen did not install into its custom directory' >&2
  exit 1
}
echo 'PASS: auto-detected Qwen installs to its configured destination'
