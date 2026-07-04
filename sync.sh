#!/usr/bin/env bash
set -euo pipefail

# Usage: sync.sh [--mirror] [TARGET_DIR] [NAME]
#
# By default, only copies files/dirs that are missing in the target (merge);
# existing files are left untouched. Pass --mirror to overwrite the target and
# delete anything not present in the template (the old behavior).

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

# Parse args: --mirror flag plus positional TARGET_DIR and NAME.
MIRROR=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --mirror) MIRROR=true ;;
    -*) echo "Error: unknown option: $arg" >&2; exit 1 ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done

TARGET_DIR="${POSITIONAL[0]:-.}"

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# Name used in devcontainer.json (before "-devcontainer").
# Defaults to the target repo's directory name.
NAME="${POSITIONAL[1]:-$(basename "$TARGET_DIR")}"

if [ "$SCRIPT_DIR" = "$TARGET_DIR" ]; then
  echo "Error: target directory is the dev-env repo itself." >&2
  exit 1
fi

# Was devcontainer.json already present? Determines whether we stamp the name.
devcontainer_json="$TARGET_DIR/.devcontainer/devcontainer.json"
devcontainer_existed=false
[ -f "$devcontainer_json" ] && devcontainer_existed=true

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
    if $MIRROR; then
      rsync -a --delete "$src/" "$dest/"
    else
      rsync -a --ignore-existing "$src/" "$dest/"
    fi
  else
    if [ -e "$dest" ] && ! $MIRROR; then
      echo "Skip (exists): $dest_path"
      continue
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  fi

  if [ "$src_path" = "$dest_path" ]; then
    echo "Synced: $src_path"
  else
    echo "Synced: $src_path -> $dest_path"
  fi
done

# Stamp the container name into devcontainer.json, but only if we created it
# this run (or in --mirror mode). In merge mode we never touch a pre-existing one.
if [ -f "$devcontainer_json" ] && { $MIRROR || ! $devcontainer_existed; }; then
  # Escape chars that are special on sed's replacement side.
  esc_name="$(printf '%s' "$NAME" | sed 's/[&|\\]/\\&/g')"
  tmp="$(mktemp)"
  sed "s|\"-devcontainer\"|\"${esc_name}-devcontainer\"|g" "$devcontainer_json" > "$tmp"
  mv "$tmp" "$devcontainer_json"
  echo "Set devcontainer name: ${NAME}-devcontainer"
fi

echo "Done. Dev environment files synced to $TARGET_DIR"
