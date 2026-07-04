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

# Name used in devcontainer.json (before "-devcontainer").
# Defaults to the target repo's directory name.
NAME="${2:-$(basename "$TARGET_DIR")}"

if [ "$SCRIPT_DIR" = "$TARGET_DIR" ]; then
  echo "Error: target directory is the dev-env repo itself." >&2
  exit 1
fi

# Files/dirs to sync (relative to repo root).
# Use "src:dest" to copy under a different name in the target.
SYNC_PATHS=(
  .devcontainer
  .claude
  copy.gitignore:.gitignore
)

for entry in "${SYNC_PATHS[@]}"; do
  src_path="${entry%%:*}"
  dest_path="${entry#*:}"
  src="$SCRIPT_DIR/$src_path"
  dest="$TARGET_DIR/$dest_path"

  if [ ! -e "$src" ]; then
    echo "Skip (not found): $src_path"
    continue
  fi

  if [ -d "$src" ]; then
    mkdir -p "$dest"
    rsync -a --delete "$src/" "$dest/"
  else
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  fi

  if [ "$src_path" = "$dest_path" ]; then
    echo "Synced: $src_path"
  else
    echo "Synced: $src_path -> $dest_path"
  fi
done

# Stamp the container name into the freshly-copied devcontainer.json.
devcontainer_json="$TARGET_DIR/.devcontainer/devcontainer.json"
if [ -f "$devcontainer_json" ]; then
  # Escape chars that are special on sed's replacement side.
  esc_name="$(printf '%s' "$NAME" | sed 's/[&|\\]/\\&/g')"
  tmp="$(mktemp)"
  sed "s|\"-devcontainer\"|\"${esc_name}-devcontainer\"|g" "$devcontainer_json" > "$tmp"
  mv "$tmp" "$devcontainer_json"
  echo "Set devcontainer name: ${NAME}-devcontainer"
fi

echo "Done. Dev environment files synced to $TARGET_DIR"
