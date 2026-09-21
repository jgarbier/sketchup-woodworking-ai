#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
plugin_dir=${SKETCHUP_PLUGINS_DIR:-"$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins"}
if [ ! -d "$plugin_dir" ]; then
  echo "SketchUp 2026 Plugins directory not found: $plugin_dir. Open SketchUp 2026 once." >&2
  exit 1
fi
# Check both destinations before changing anything. Never replace an existing installation.
for item in woodworking_ai.rb woodworking_ai; do
  destination="$plugin_dir/$item"
  source_path="$repo_root/sketchup-extension/$item"
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    if [ ! -L "$destination" ] || [ "$(readlink "$destination")" != "$source_path" ]; then
      echo "Refusing to replace existing path: $destination" >&2
      exit 1
    fi
  fi
done
for item in woodworking_ai.rb woodworking_ai; do
  destination="$plugin_dir/$item"
  if [ ! -L "$destination" ]; then
    ln -s "$repo_root/sketchup-extension/$item" "$destination"
  fi
done
echo "Development extension installed in $plugin_dir"
echo "Restart SketchUp, then choose Extensions > Woodworking AI > Verify 48 × 18 × 1 Tabletop."
