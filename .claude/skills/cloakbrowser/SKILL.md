---
name: cloakbrowser
description: >-
  Drive CloakBrowser stealth browser (patched Chromium) over the Chrome DevTools
  Protocol (CDP). Use to automate a real browser, scrape a site, or run automation
  against bot-protected pages.
---

# CloakBrowser stealth browser

`cloakhq/cloakbrowser` (Docker Hub, prebuilt) runs [CloakBrowser](https://github.com/CloakHQ/cloakbrowser),
a patched Chromium, as a Chrome DevTools Protocol (CDP) server. Drive it with any
CDP/WebSocket client — no Playwright or `cloakbrowser` package needed.

## Step 1 — start cloakbrowser on the devcontainer's network

Reuses a running `cloak`; starts one if absent. Prints the endpoint:

```bash
SELF=$(hostname)
NET=$(docker inspect "$SELF" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' | head -1)
if ! docker ps --format '{{.Names}}' | grep -qx cloak; then
  docker rm -f cloak 2>/dev/null
  docker run -d --name cloak --network "$NET" cloakhq/cloakbrowser cloakserve
fi
IP=$(docker inspect cloak --format "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}")
until python3 -c "import urllib.request; urllib.request.urlopen('http://$IP:9222/json/version',timeout=2)" 2>/dev/null; do sleep 1; done
echo "CLOAK_CDP=http://${IP}:9222"
```

On a user-defined network you may use `http://cloak:9222`; on the default
`bridge`, use the IP.

## Step 2 — connect over raw CDP

Fetch the browser WebSocket URL from `/json/version` (append config as query
params — see below), open it **with no `Origin` header** (`suppress_origin=True`;
cloakbrowser rejects a set Origin with `403 untrusted WebSocket origin`), then
speak CDP as JSON: open a target, attach, evaluate.

```python
import json, os, urllib.request, websocket  # pip install websocket-client

CDP = os.environ["CLOAK_CDP"]   # http://<ip>:9222
# per-connection config goes here; each distinct `fingerprint` seed is its own
# isolated identity (same seed reuses the same Chrome process; omit for default)
q = "fingerprint=11111&platform=windows&timezone=America/New_York&locale=en-US&geoip=true"
info = json.load(urllib.request.urlopen(f"{CDP}/json/version?{q}"))
ws = websocket.create_connection(info["webSocketDebuggerUrl"], suppress_origin=True)

_id = 0
def send(method, params=None, sid=None):
    global _id; _id += 1
    m = {"id": _id, "method": method, "params": params or {}}
    if sid: m["sessionId"] = sid
    ws.send(json.dumps(m)); return _id
def wait(want_id=None, event=None):
    while True:
        m = json.loads(ws.recv())
        if want_id is not None and m.get("id") == want_id: return m.get("result", {})
        if event is not None and m.get("method") == event: return m.get("params", {})

tid = wait(send("Target.createTarget", {"url": "about:blank"}))["targetId"]
sid = wait(send("Target.attachToTarget", {"targetId": tid, "flatten": True}))["sessionId"]
send("Page.enable", sid=sid)
send("Page.navigate", {"url": "https://example.com"}, sid=sid)
wait(event="Page.loadEventFired")
res = wait(send("Runtime.evaluate",
                {"expression": "document.title", "returnByValue": True}, sid))
print(res["result"]["value"])
ws.close()
```

## Configure per connection (query params on `/json/version`)

Put params in the `q` string above. Verified to apply: `platform=windows` →
`navigator.platform=Win32`, `locale=ja-JP`, `timezone=Asia/Tokyo`.

| Param | Example | Meaning |
|---|---|---|
| `fingerprint` | `11111` | Deterministic identity seed. |
| `platform` | `windows` / `macos` / `linux` | Spoofed OS (default `windows` — best-patched, see Notes). |
| `timezone` | `America/New_York` | Timezone. |
| `locale` | `en-US` | Locale. |
| `geoip` | `true` | Derive locale/timezone from proxy IP. |
| `proxy` | `http://host:8080` | HTTP/SOCKS5 proxy (this connection only). |
| `hardware-concurrency` / `device-memory` | `4` / `8` | CPU cores / RAM (GB). |
| `gpu-vendor` / `gpu-renderer` | — | WebGL GPU strings. |
| `screen-width` / `screen-height` | `1920` / `1080` | Screen size. |

Server-wide options go on the `cloakserve` command in step 1:
`--proxy-server=http://host:8080`, `--headless=false`, `--idle-timeout=300`,
`--data-dir=/profile`. Pro binary: `-e CLOAKBROWSER_LICENSE_KEY=cb_xxx`.

## Notes

- Raw CDP over WebSocket; any language with a WS client works (must omit the
  `Origin` header). The example uses `websocket-client`.
- Prebuilt public image; pin with `cloakhq/cloakbrowser:<version>`. No `--shm-size` needed.
- One `cloak` container serves many connections; isolate identities with distinct
  `fingerprint` seeds rather than multiple containers.
- **`platform=windows` has the most stealth patches** and
  is the default when `platform` is omitted.
