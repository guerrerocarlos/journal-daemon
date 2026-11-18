# Journal Daemon Runbook

## Current proposal verification

```bash
git status --short --branch
git diff --check
python3 -m json.tool config/config.example.json >/dev/null
```

The executable service scans mounted volumes every 15 seconds. It only uploads after a file has been atomically spooled and recorded in local SQLite state.

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
brew tap guerrerocarlos/journal-daemon
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

The formula runs `swift build --configuration release` during installation. The service will remain healthy without a Keychain token when there are no pending spooled files. Before enabling uploads, replace the example endpoint and use `journal-daemon auth set-token --config ~/.config/journal-daemon/config.json` to save the approved token to Keychain.

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

The installed `air15` formula was subsequently refreshed to `HEAD-93c49a6` and its LaunchAgent was started after the no-echo Keychain token-entry update.

## Installation page

`docs/index.html` is published by `.github/workflows/pages.yml` through GitHub Pages at `https://guerrerocarlos.github.io/journal-daemon/`. Workflow `44371486972` completed successfully on 2026-11-18; a cache-busted live fetch confirmed the current installation and configuration copy.
