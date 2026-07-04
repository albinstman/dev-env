---
name: camoufox
description: >-
  Drive Camoufox stealth browser over the
  Playwright protocol. Use to automate a real browser, scrape a site, or run
  Playwright against bot-protected pages. 
---

# Camoufox stealth browser

`camoufox:local` runs a [Camoufox](https://github.com/daijro/camoufox) session
manager: `POST /sessions` spawns an isolated browser and returns a Playwright ws
endpoint. Connect with plain `playwright` (the `camoufox` package is not needed
client-side).

## Step 1 — reach the manager over a shared network

```bash
docker network create camoufox-net 2>/dev/null || true

if ! docker ps -a --format '{{.Names}}' | grep -qx camoufox; then
  docker run -d --name camoufox --network camoufox-net --shm-size=2gb \
    --restart unless-stopped -e CAMOUFOX_FF_VERSION=152 camoufox:local
else
  docker network connect camoufox-net camoufox 2>/dev/null || true
fi

docker network connect camoufox-net "$(hostname)" 2>/dev/null || true
until curl -fsS http://camoufox:9222/healthz >/dev/null 2>&1; do sleep 1; done

echo "CAMOUFOX_MANAGER=http://camoufox:9222"
```

## Step 2 — install the matching Playwright client

```bash
pip install "playwright==1.60.0" requests
```

## Step 3 — create a session and connect

```python
import os, requests
from playwright.sync_api import sync_playwright

mgr = os.environ["CAMOUFOX_MANAGER"]
session = requests.post(f"{mgr}/sessions", json={"options": {"os": "macos"}}).json()

with sync_playwright() as p:
    browser = p.firefox.connect(session["ws_endpoint"])
    page = browser.new_page()
    page.goto("https://example.com")
    print(page.title())
    browser.close()

requests.delete(f"{mgr}/sessions/{session['id']}")
```

```javascript
const mgr = process.env.CAMOUFOX_MANAGER;
const session = await (await fetch(`${mgr}/sessions`, {method: 'POST'})).json();
const { firefox } = require('playwright');
const browser = await firefox.connect(session.ws_endpoint);
```

## Configure (per session)

`POST /sessions` body — all fields optional; `options` accepts any
[Camoufox option](https://camoufox.com/python/parameters/):

```json
{
  "idle_timeout": 300,
  "ttl": 0,
  "options": {
    "headless": true,
    "os": "windows",
    "locale": "en-US",
    "geoip": true,
    "humanize": true,
    "block_images": false,
    "block_webrtc": false,
    "block_webgl": false,
    "disable_coop": false,
    "enable_cache": false,
    "proxy": {
      "server": "http://host:8080",
      "username": "user",
      "password": "pass",
      "bypass": "localhost,127.0.0.1"
    },
    "fonts": ["Arial", "Helvetica"],
    "custom_fonts_only": false,
    "addons": ["/path/to/addon"],
    "exclude_addons": ["UBO"],
    "fingerprint": {},
    "config": {},
    "firefox_user_prefs": {},
    "ff_version": "152",
    "window": [1280, 720]
  }
}
```

| Field | Type | Notes |
|---|---|---|
| `idle_timeout` | number (s) | Reap after no connection this long. Default `300`, `0` disables. |
| `ttl` | number (s) | Hard max lifetime. Default `0` (none). |
| `options.headless` | `true` \| `false` \| `"virtual"` | `virtual` uses Xvfb. |
| `options.os` | string \| string[] | `windows` / `macos` / `linux`; list = random pick. |
| `options.locale` | string \| string[] | e.g. `en-US`. |
| `options.geoip` | `true` \| `false` \| string | `true` = auto, or an explicit IP. |
| `options.humanize` | `true` \| `false` \| number | number = max cursor-move seconds. |
| `options.proxy` | object | `server`, `username`, `password`, `bypass`. |
| `options.*` | — | Any other Camoufox option (e.g. `window`, `fingerprint`). |

If `fingerprint`/`config` are not set, Camoufox generates a realistic randomized
fingerprint sampled from real-world browser distributions — so each session gets
a unique, plausible identity by default. Prefer this default: only set an
explicit `fingerprint`/`config` when the user specifically asks for one, since a
fixed or hand-crafted identity is usually less convincing than the randomized
default.

Networking (`host`/`port`/`ws_path`) is managed and ignored if set. Container
`CAMOUFOX_*` env vars (set with `-e` on `docker run`) are defaults that each
session's `options` override.

## Notes

- Each session is its own browser process with its own fingerprint; run as many
  as `MAX_SESSIONS` (default 10) allows.
- One manager is shared by all callers on `camoufox-net`. It has no auth, so any
  caller can list/delete any session — fine for mutually-trusted agents. Always
  `DELETE` your session when done (or rely on `idle_timeout`) so slots free up.
- `--shm-size=2gb` guards against Firefox crashes on engines that default
  `/dev/shm` to 64 MB (Docker Desktop, vanilla `dockerd`). Redundant where shm is
  already larger (e.g. OrbStack = 4 GB) but harmless — keep it.
- Client/server Playwright versions must match (1.60 — see step 2); bump both in
  lockstep if the `camoufox:local` image is upgraded.
