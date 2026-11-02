#!/bin/sh
# Continuum installer.
#
#   ./install.sh                 install into the current directory
#   ./install.sh /path/to/proj   install into that project
#   ./install.sh --global        also install the skills for every project
#                                (~/.claude/skills) and the CLI on PATH
#
# Installs: .continuum/ state + CLI, .claude/hooks/continuum-*.sh,
# .claude/skills/continuum*/, and the hook wiring in .claude/settings.json.
# Re-running is safe: existing state files are never overwritten.

set -eu

SRC=$(cd "$(dirname "$0")" && pwd)
GLOBAL=0
TARGET=""

for a in "$@"; do
  case $a in
    --global) GLOBAL=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGET=$a ;;
  esac
done

[ -n "$TARGET" ] || TARGET=$(pwd)
[ -d "$TARGET" ] || { printf 'install: no such directory: %s\n' "$TARGET" >&2; exit 1; }
TARGET=$(cd "$TARGET" && pwd)

# The installer needs the repo's own files; refuse to half-install without them.
for d in bin hooks skills templates; do
  [ -d "$SRC/$d" ] || { printf 'install: %s/%s missing. Clone the repo and run install.sh from inside it.\n' "$SRC" "$d" >&2; exit 1; }
done

printf 'Continuum -> %s\n' "$TARGET"

# ------------------------------------------------------------------ CLI + state

mkdir -p "$TARGET/.continuum/bin" "$TARGET/.continuum/.templates"
cp "$SRC/bin/continuum" "$TARGET/.continuum/bin/continuum"
chmod +x "$TARGET/.continuum/bin/continuum"
cp -R "$SRC/templates/." "$TARGET/.continuum/.templates/"
printf '  ok  .continuum/bin/continuum\n'

CLI="$TARGET/.continuum/bin/continuum"

# ---------------------------------------------------------------------- hooks

mkdir -p "$TARGET/.claude/hooks"
for h in session-start stop-checkpoint pre-compact session-end; do
  cp "$SRC/hooks/$h.sh" "$TARGET/.claude/hooks/continuum-$h.sh"
  chmod +x "$TARGET/.claude/hooks/continuum-$h.sh"
done
printf '  ok  .claude/hooks/continuum-*.sh\n'

# ---------------------------------------------------------------------- skills

install_skills() {
  dest=$1
  mkdir -p "$dest"
  for s in "$SRC"/skills/*/; do
    name=$(basename "$s")
    mkdir -p "$dest/$name"
    cp "$s/SKILL.md" "$dest/$name/SKILL.md"
  done
  printf '  ok  %s/continuum*\n' "$dest"
}

install_skills "$TARGET/.claude/skills"
if [ "$GLOBAL" = "1" ]; then
  install_skills "$HOME/.claude/skills"
  mkdir -p "$HOME/.local/bin"
  cp "$SRC/bin/continuum" "$HOME/.local/bin/continuum"
  chmod +x "$HOME/.local/bin/continuum"
  printf '  ok  ~/.local/bin/continuum (ensure ~/.local/bin is on PATH)\n'
fi

# -------------------------------------------------------------- settings.json

SETTINGS="$TARGET/.claude/settings.json"

merge_settings_python() {
  python3 - "$SETTINGS" <<'PY'
import json, os, sys

path = sys.argv[1]
data = {}
if os.path.exists(path):
    with open(path) as f:
        text = f.read().strip()
    if text:
        try:
            data = json.loads(text)
        except json.JSONDecodeError as e:
            sys.stderr.write("install: %s is not valid JSON (%s); leaving it alone\n" % (path, e))
            sys.exit(2)

hooks = data.setdefault("hooks", {})

wanted = {
    "SessionStart": ("startup|resume|clear|compact|fork",
                     "continuum-session-start.sh", "Loading project state..."),
    "Stop":         (None, "continuum-stop-checkpoint.sh", None),
    "PreCompact":   (None, "continuum-pre-compact.sh", None),
    "SessionEnd":   (None, "continuum-session-end.sh", None),
}

added = []
for event, (matcher, script, status) in wanted.items():
    cmd = "${CLAUDE_PROJECT_DIR}/.claude/hooks/" + script
    groups = hooks.setdefault(event, [])
    if any(cmd in json.dumps(g) for g in groups):
        continue
    handler = {"type": "command", "command": cmd, "timeout": 20}
    if status:
        handler["statusMessage"] = status
    group = {"hooks": [handler]}
    if matcher:
        group["matcher"] = matcher
    groups.append(group)
    added.append(event)

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("  ok  .claude/settings.json" + (" (+%s)" % ", ".join(added) if added else " (already wired)"))
PY
}

if command -v python3 >/dev/null 2>&1; then
  merge_settings_python || printf '  !!  settings.json not modified, see the snippet in README.md\n'
elif [ ! -f "$SETTINGS" ]; then
  cat > "$SETTINGS" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup|resume|clear|compact|fork",
        "hooks": [ { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/continuum-session-start.sh", "timeout": 20, "statusMessage": "Loading project state..." } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/continuum-stop-checkpoint.sh", "timeout": 20 } ] }
    ],
    "PreCompact": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/continuum-pre-compact.sh", "timeout": 20 } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/continuum-session-end.sh", "timeout": 20 } ] }
    ]
  }
}
JSON
  printf '  ok  .claude/settings.json (created)\n'
else
  printf '  !!  python3 not found and settings.json exists: add the hooks block from README.md yourself\n'
fi

# ------------------------------------------------------------------------ init

( cd "$TARGET" && "$CLI" init | sed 's/^continuum: /  ok  /' )

printf '\nNext: open Claude Code in %s and run /continuum\n' "$TARGET"
printf 'Check anytime with: .continuum/bin/continuum doctor\n'
