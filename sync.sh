#!/usr/bin/env bash
set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
TARGET_DIR="${1:-.}"

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if [ "$SCRIPT_DIR" = "$TARGET_DIR" ]; then
  echo "Error: target directory is the dev-env repo itself." >&2
  exit 1
fi

# Files/dirs to sync (relative to repo root)
SYNC_PATHS=(
  .devcontainer
  .claude
)

for path in "${SYNC_PATHS[@]}"; do
  src="$SCRIPT_DIR/$path"
  dest="$TARGET_DIR/$path"

  if [ ! -e "$src" ]; then
    echo "Skip (not found): $path"
    continue
  fi

  if [ -d "$src" ]; then
    mkdir -p "$dest"
    rsync -a --delete "$src/" "$dest/"
  else
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  fi

  echo "Synced: $path"
done

echo "Done. Dev environment files synced to $TARGET_DIR"
