#!/bin/sh
# Remove Continuum from a project.
#
#   ./uninstall.sh [/path/to/project]            hooks + skills, state kept
#   ./uninstall.sh --purge [/path/to/project]    state removed too
#
# Hook entries are stripped from .claude/settings.json; the rest of that file is
# left exactly as it was.

set -eu

PURGE=0
TARGET=""
for a in "$@"; do
  case $a in
    --purge) PURGE=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGET=$a ;;
  esac
done
[ -n "$TARGET" ] || TARGET=$(pwd)
TARGET=$(cd "$TARGET" && pwd)

rm -f "$TARGET"/.claude/hooks/continuum-*.sh 2>/dev/null || true
printf '  removed  .claude/hooks/continuum-*.sh\n'

for s in continuum continuum-onboard continuum-resume continuum-checkpoint continuum-handoff continuum-verify; do
  rm -rf "$TARGET/.claude/skills/$s"
done
printf '  removed  .claude/skills/continuum*\n'

SETTINGS="$TARGET/.claude/settings.json"
if [ -f "$SETTINGS" ] && command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception as e:
    sys.stderr.write("  kept     settings.json (unreadable: %s)\n" % e)
    sys.exit(0)

hooks = data.get("hooks", {})
for event in list(hooks):
    kept = [g for g in hooks[event] if "continuum-" not in json.dumps(g)]
    if kept:
        hooks[event] = kept
    else:
        del hooks[event]
if "hooks" in data and not data["hooks"]:
    del data["hooks"]

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("  cleaned  .claude/settings.json")
PY
else
  printf '  !!       remove the continuum hook entries from settings.json by hand\n'
fi

if [ "$PURGE" = "1" ]; then
  rm -rf "$TARGET/.continuum"
  printf '  removed  .continuum/ (state is gone)\n'
else
  printf '  kept     .continuum/ (use --purge to delete the project state)\n'
fi
