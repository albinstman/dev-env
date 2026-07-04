## Usage

```bash
./sync.sh [--mirror] [TARGET_DIR] [NAME]
```

- `TARGET_DIR` — where to sync (default: current directory)
- `NAME` — container name, used as `NAME-devcontainer` in `devcontainer.json`'s
  `name` and `runArgs` (default: the target directory's name)
- `--mirror` — overwrite mode (see below)

```bash
./sync.sh ~/code/my-project              # name: my-project-devcontainer
./sync.sh ~/code/my-project custom-name  # name: custom-name-devcontainer
```

### Merge (default) vs mirror

By default, sync **only copies what's missing** — existing files in the target
are left untouched, and new template files are merged into existing folders. A
`devcontainer.json` that already exists is preserved as-is (its name is not
re-stamped).

Pass `--mirror` to make the target match the template exactly: existing files
are overwritten, `devcontainer.json` is re-stamped, and anything not in the
template is deleted (`rsync --delete`).

```bash
./sync.sh --mirror ~/code/my-project     # overwrite + delete extras
```