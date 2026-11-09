---
layout: post
date: 2026-11-09 00:00:00
modified_date: 2026-11-09 00:00:00
title: Driving Google Chrome Via Playwright MCP From WSL
tags: wsl playwright chrome mcp
author: Can Güvendiren
---

Here's how to make Playwright MCP drive the Chrome profile you're already signed
into on Windows, from WSL, through the extension relay.

## Prerequisites

- [Playwright extension](https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm)
  installed in the Chrome profile that `chrome.exe` opens by default.
- The token from the extension's status page.
- Mirrored networking. The relay binds a random port on loopback inside WSL and
  puts that address in the connect URL it opens, the extension resolves that
  `127.0.0.1` against Windows' loopback. Under NAT the VM has its own loopback
  behind a virtual adapter, so the address points at the host's loopback where
  nothing is listening. Mirrored mode attaches WSL to the host's interfaces, so
  both sides share one loopback.

Edit `C:\Users\<you>\.wslconfig` and add the lines below.

```ini
[wsl2]
networkingMode=mirrored
```

`wsl --shutdown` and start WSL again.

## Running It

```bash
PLAYWRIGHT_MCP_EXTENSION_TOKEN=<token> \
PLAYWRIGHT_MCP_USER_DATA_DIR='C:\Users\<you>\AppData\Local\Google\Chrome\User Data' \
playwright-mcp --extension \
--executable-path "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
```

- `--extension` selects the extension branch, without it you get the persistent
  profile branch and a Linux Chromium.
- `--executable-path` points at `chrome.exe`, WSL executes `.exe` files
  directly, so the connect tab opens in Windows. Without it Playwright launches
  its own Linux Chromium, where the extension doesn't exist.
- `PLAYWRIGHT_MCP_USER_DATA_DIR` has to be the profile path Chrome is already
  running with, Chrome matches its singleton lock on the user data directory and
  forwards the connect URL to that instance. A different path starts a new
  browser without the extension, and you get `ERR_BLOCKED_BY_CLIENT`.
- `PLAYWRIGHT_MCP_EXTENSION_TOKEN` the relay only waits for a connection when a
  token is set, and the extension rejects a mismatched one. Without it you wait
  30 seconds for "did not connect".

The default channel is already `chrome`, so bare `--extension` is enough. Don't
add `--cdp-endpoint`, `--port`, `--host`, `--user-data-dir`, `--isolated`,
`--browser`, `--profile-dir-name` or `--no-sandbox`, the last one only applies to
the Linux `chromium` channel anyway.

A `chrome-extension://<id>/connect.html?...` tab opens in Chrome and it says
"Playwright Extension started debugging this browser", from there the tools
operate on that profile.

## Tool Calls

- Fire them in order and wait for each response, navigate, wait for the
  navigation response, `browser_wait_for` for a few seconds, then
  `browser_evaluate`. Firing them together gets you
  `Execution context was destroyed` or `No open pages available`.
- The relay binds port `0` and generates a random UUID path on every start, so a
  new connect tab opens each run.
- The token is per install, reinstalling the extension changes it.

## Client Configuration

The server speaks MCP over stdio, point your client at the command above.

- Command: `playwright-mcp`
- Arguments: `--extension` and `--executable-path "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"`
- Environment: `PLAYWRIGHT_MCP_USER_DATA_DIR` and `PLAYWRIGHT_MCP_EXTENSION_TOKEN`

For example, this is how it looks in OpenCode's `opencode.json`, with the token
read from the environment:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "playwright": {
        "type": "local",
        "command": [
          "playwright-mcp",
          "--extension",
          "--executable-path", "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
        ],
        "environment": {
          "PLAYWRIGHT_MCP_USER_DATA_DIR": "C:\\Users\\<you>\\AppData\\Local\\Google\\Chrome\\User Data",
          "PLAYWRIGHT_MCP_EXTENSION_TOKEN": "{env:PLAYWRIGHT_MCP_EXTENSION_TOKEN}"
        }
      }
    }
  }
}
```
