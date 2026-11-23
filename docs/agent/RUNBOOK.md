# Journal Daemon Runbook

## Current proposal verification

```bash
git status --short --branch
git diff --check
python3 -m json.tool config/config.example.json >/dev/null
```

The executable service scans mounted volumes every 15 seconds. It only uploads after a file has been atomically spooled and recorded in local SQLite state.

Before connecting an intended source drive, create its required opt-in marker at the volume root:

```bash
mkdir /Volumes/YOUR_DRIVE/.journal-daemon
```

Without that exact directory, the daemon ignores the volume, including its menu-bar connection status.

The example configuration uses `nameRegex: ".*"` because DJI commonly stores its identity in folders such as `DJI_Audio_001` inside a generically named volume. The required marker and removable-media rule are the safety boundary. Narrow `nameRegex` only when a specific volume name is reliable.

The scanner permanently excludes files below `.Trashes`, `.Trash`, `$RECYCLE.BIN`, `Trash`, `Trashed`, and `Deleted Items` directories. This is not configurable and applies before copying or hashing.

When a configured matching removable volume is mounted, the running per-user service shows a menu-bar drive icon. Open it to see the matching source and select **Scan now**. During API upload, the icon switches to an upload indicator and displays the active filename plus byte progress, remaining visible even if the source volume is later unmounted. The drive icon disappears after all matching volumes are unmounted and no upload is active.

## Bootstrap developer checks

```bash
swift build
swift test
swift run journal-daemon config validate --config config/config.example.json
swift run journal-daemon doctor
swift run journal-daemon bell sounds
swift run journal-daemon scan --dry-run --config config/config.example.json
```

## Bootstrap Homebrew checks

```bash
brew tap guerrerocarlos/journal-daemon https://github.com/guerrerocarlos/journal-daemon.git
brew trust guerrerocarlos/journal-daemon
brew install --HEAD --build-from-source journal-daemon
brew test journal-daemon
journal-daemon doctor
mkdir -p ~/.config/journal-daemon
cp "$(brew --prefix journal-daemon)/share/journal-daemon/config.example.json" ~/.config/journal-daemon/config.json
chmod 600 ~/.config/journal-daemon/config.json
journal-daemon config validate --config ~/.config/journal-daemon/config.json
brew services start journal-daemon
brew services list
journal-daemon status --config ~/.config/journal-daemon/config.json
```

The formula runs `swift build --configuration release` during installation. Before enabling uploads, set the private Tailscale bridge hostname plus a bound Telegram `chatId` and `messageThreadId`. No application token is required: the bridge must remain localhost-bound behind Tailscale Serve, with access limited by tailnet policy.

On 2026-11-23, `pro13` passed `brew install --HEAD --build-from-source journal-daemon`, `brew test guerrerocarlos/journal-daemon/journal-daemon`, configuration validation, and per-user service startup. Its active route is the LIFE Journal chat `-1004361900873`, topic `5701`, with no `auth` field. The host's standalone `swift test` is currently unavailable because its Command Line Tools installation does not provide XCTest, although its release build completed successfully.

## Fleet rollout and daily updates

Every daemon change must be rolled out to both fleet Macs, `air15` and `pro13`, whenever they are reachable. Report an unreachable machine rather than treating it as updated. The per-user daemon performs a daily Homebrew update check after it has been running for 24 hours. If the approved public tap has a newer HEAD build, it builds from source and restarts its own per-user service after a successful upgrade. It leaves the service running unchanged when the installed revision is current.

To force an immediate source refresh on a reachable Mac:

```bash
brew update
brew upgrade --fetch-HEAD --build-from-source guerrerocarlos/journal-daemon/journal-daemon
brew services restart guerrerocarlos/journal-daemon/journal-daemon
```

## Telegram bridge ingestion

The daemon uploads multipart audio to `https://<bridge-tailnet-name>/journal-daemon/v1/imports`. Its `destination.route` selects the Telegram group and forum topic. The LIFE Journal route is chat `-1004361900873`, topic `5701`. The bridge checks the exact route is currently bound and configured for Journal media, then posts the audio and archives it. The endpoint is Tailscale-only. Never use Funnel or a public proxy.

```bash
brew services restart journal-daemon
journal-daemon status --config ~/.config/journal-daemon/config.json
```

## Tailscale bell bridge

Install `journal-daemon` and Tailscale on each destination Mac. The caller needs a normal SSH key authorized on the destination and a trusted SSH host key. Tailscale provides the private network and MagicDNS destination.

```bash
# On the destination Mac, verify local audio.
journal-daemon bell ring --sound Glass

# From an authorized Tailscale machine, request a bell on air15.
journal-daemon bell send --device air15 --user carlos --sound Glass
```

The implementation invokes `/usr/bin/ssh -o BatchMode=yes carlos@air15 journal-daemon bell ring --sound Glass`. It does not open a TCP listener, accept arbitrary shell arguments, or store a shared token. Validate Tailscale connectivity, host-key verification, SSH authorization, and audible output manually on the target Macs before relying on it for agent completion notifications.

### Current acceptance evidence

On 2026-11-18, `air15` passed `swift test`, `brew install --HEAD --build-from-source journal-daemon`, `brew test journal-daemon`, `journal-daemon bell sounds`, and audible `journal-daemon bell ring --sound Glass`. Tailscale was connected as `air15.amarok-peacock.ts.net`. The remote-send success case remains pending a separate caller with an SSH key authorized for `carlos@air15`; self-SSH correctly rejected an absent key.

## Ingestion and restart acceptance evidence

On 2026-11-18, `air15` compiled the runtime with `swift test`. A synthetic stable WAV under a temporary mounted-root fixture was spooled exactly once and reported `pending=1` after a second scan, proving durable SQLite deduplication. The current source-only formula installed as `HEAD-d6e1b08`; `brew test journal-daemon`, `brew services start journal-daemon`, and `brew services restart journal-daemon` succeeded. The configured destination is still the non-routable example endpoint, so no live media upload has been attempted.

The installed `air15` formula was subsequently refreshed to `HEAD-93c49a6` and its LaunchAgent was started. A later revision removes the obsolete application-token configuration.

## Installation page

`docs/index.html` is published by `.github/workflows/pages.yml` through GitHub Pages at `https://guerrerocarlos.github.io/journal-daemon/`. Workflow `44371486972` completed successfully on 2026-11-18; a cache-busted live fetch confirmed the current installation and configuration copy.
