#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="$DIR/godot/Godot.app/Contents/MacOS/Godot"
if [ ! -x "$GODOT" ]; then
  echo "Godot not found at:"
  echo "  $GODOT"
  exit 1
fi
exec "$GODOT" --path "$DIR" "$@"
