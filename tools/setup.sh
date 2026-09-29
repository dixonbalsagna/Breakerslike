#!/bin/sh
# One-command setup for Linux and macOS (Windows: tools\setup.cmd).
# Checks Node and Godot, then installs npm dependencies. Run from anywhere:
#   sh tools/setup.sh
# Exit 0 = ready (warnings allowed). Exit 1 = a required tool is missing or an install failed.
# Docs: docs/tools/README.md

WANT_NODE_MAJOR=24        # the golden hashes were recorded on Node 24.19.0 (ADR 0004)
MIN_NODE_MAJOR=18         # the lowest major qa/ and sim/ run on
WANT_GODOT="4.7"          # ADR 0001

cd "$(dirname "$0")/.." || exit 1
warn=0
say()  { printf '%s\n' "$*"; }
ok()   { say "ok    $*"; }
warnf(){ say "WARN  $*"; warn=$((warn + 1)); }
fail() { say "FAIL  $*"; exit 1; }

# Node (required)
command -v node >/dev/null 2>&1 || fail "node not found. Install Node $WANT_NODE_MAJOR (https://nodejs.org) and re-run."
node_v=$(node -v)
node_major=${node_v#v}; node_major=${node_major%%.*}
[ "$node_major" -ge "$MIN_NODE_MAJOR" ] 2>/dev/null || fail "Node $node_v is too old (need $MIN_NODE_MAJOR or newer, $WANT_NODE_MAJOR recommended)."
if [ "$node_major" -eq "$WANT_NODE_MAJOR" ]; then
  ok "Node $node_v"
else
  warnf "Node $node_v: Node $WANT_NODE_MAJOR is the tested version. The golden-hash check is skipped on other majors, so a pass here proves less."
fi
command -v npm >/dev/null 2>&1 || fail "npm not found (it ships with Node)."
ok "npm $(npm -v)"

# Godot (optional until the GDScript port lands)
godot_bin=""
for c in "${GODOT:-}" godot godot4; do
  [ -n "$c" ] && command -v "$c" >/dev/null 2>&1 && { godot_bin=$c; break; }
done
if [ -z "$godot_bin" ]; then
  warnf "Godot not found. Not needed for the JavaScript suites. For the engine port install Godot $WANT_GODOT.x (standard build, not .NET), or set GODOT=/path/to/godot."
else
  godot_v=$("$godot_bin" --version 2>/dev/null | head -n 1)
  case "$godot_v" in
    "$WANT_GODOT".*) ok "Godot $godot_v ($godot_bin)" ;;
    *) warnf "Godot reports '$godot_v'; the project targets $WANT_GODOT.x (ADR 0001)." ;;
  esac
  case "$godot_v" in *mono*|*.NET*) warnf "This looks like the .NET build; the project uses GDScript, use the standard build." ;; esac
fi

# npm dependencies: `npm ci` in each package that has a lockfile. Today none of
# qa/, sim/ or the root declares dependencies, and prototype/'s only entry is the
# optional screenshot canvas, so this is usually a no-op.
installed=0
for dir in . prototype sim qa; do
  [ -f "$dir/package.json" ] || continue
  if [ -f "$dir/package-lock.json" ]; then
    say "npm ci in $dir"
    (cd "$dir" && npm ci) || fail "npm ci failed in $dir"
    installed=$((installed + 1))
  fi
done
[ "$installed" -eq 0 ] && ok "no lockfiles, nothing to install (the suites use Node built-ins only)"

say ""
if [ "$warn" -eq 0 ]; then say "Setup complete."; else say "Setup complete with $warn warning(s)."; fi
say "Next: node qa/run-all.js --quick   (about 40 s)   or   npm test --prefix sim"
exit 0
