## Usage

```bash
./sync.sh [TARGET_DIR] [NAME]
```

- `TARGET_DIR` — where to sync (default: current directory)
- `NAME` — container name, used as `NAME-devcontainer` in `devcontainer.json`'s
  `name` and `runArgs` (default: the target directory's name)

```bash
./sync.sh ~/code/my-project              # name: my-project-devcontainer
./sync.sh ~/code/my-project custom-name  # name: custom-name-devcontainer
```