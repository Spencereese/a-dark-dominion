#!/bin/zsh
# Convenience launcher for A Dark Dominion (Mac version)
# - Always cleans .godot cache (prevents stale parse / missing dep errors after edits)
# - Uses the known location of your Godot 4.6+ on this machine
# - Run from the project root: ./launch_godot.sh
#
# NOTE: This is the original Mac/zsh script. On Windows (PowerShell), use launch_godot.ps1 instead.
# See README.md for Windows instructions and the cross-platform manual steps.

set -e

cd "$(dirname "$0")"

echo "=== A Dark Dominion launcher ==="
echo "Cleaning .godot cache (required after any script/theme/resource edits)..."
rm -rf .godot

# For testing the initial darkness / nurture button screen, force a fresh game state.
# This removes any old save that may have advanced phase/ember and hidden the starter action.
# Comment out the next two lines if you want to keep your progress/save between launches.
echo "Preparing clean start for play session (deleting previous save)..."
rm -f "$HOME/Library/Application Support/Godot/app_userdata/A Dark Dominion/save_auto.json" 2>/dev/null || true
rm -f "$HOME/Library/Application Support/Godot/app_userdata/A Dark Dominion/save_auto.json.bak" 2>/dev/null || true

GODOT_BIN="/Users/spencereese/Downloads/Godot.app/Contents/MacOS/Godot"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "ERROR: Godot binary not found or not executable at:"
  echo "  $GODOT_BIN"
  echo ""
  echo "If you installed Godot elsewhere, edit this script or launch manually:"
  echo "  1. rm -rf .godot"
  echo "  2. Open the project folder in your Godot.app"
  echo "On Windows, use launch_godot.ps1 (see README)."
  exit 1
fi

echo "Launching: $GODOT_BIN --path ."
echo "(Clean start. Use the in-game 'Reset (New Game)' button anytime to restart. Look to the right sidebar under 'Actions' for buttons like 'Nurture the Ember'. Watch the log on the left for the story. On Windows use launch_godot.ps1 instead.)"
echo ""

exec "$GODOT_BIN" --path . "$@"
