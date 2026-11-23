# Journal Daemon

Source-built bootstrap for a small macOS background agent that will detect configured DJI Mic storage volumes, copy new recordings into a durable local spool, and upload them to a journal API.

The proposed application is installed through Homebrew and compiled from source on the target Mac. No precompiled executable or Homebrew bottle is planned.

## Current status

This repository contains a source-built macOS daemon, its Homebrew formula, configuration example, and an installation page. It scans matching mounted volumes, atomically spools stable recordings, records durable state in SQLite, retries idempotent uploads, and runs as a per-user Homebrew service. While a configured matching USB volume is connected, the service shows a menu-bar drive icon with the source and a manual scan action. During an API upload, it remains visible with an upload icon, filename, and byte progress. Hardware and live API acceptance remain separate.

## Install from source

Visit the public installation page at [guerrerocarlos.github.io/journal-daemon](https://guerrerocarlos.github.io/journal-daemon/).

```bash
brew tap guerrerocarlos/journal-daemon
brew trust guerrerocarlos/journal-daemon
brew install --HEAD --build-from-source journal-daemon
```

This intentionally uses the formula's `HEAD` source and compiles with Swift on the target Mac. No bottle or precompiled executable is published.

## Configure and run

```bash
mkdir -p ~/.config/journal-daemon
cp "$(brew --prefix journal-daemon)/share/journal-daemon/config.example.json" \
  ~/.config/journal-daemon/config.json
chmod 600 ~/.config/journal-daemon/config.json
journal-daemon config validate --config ~/.config/journal-daemon/config.json
journal-daemon auth set-token --config ~/.config/journal-daemon/config.json
brew services start journal-daemon
```

`auth set-token` uses a no-echo interactive prompt. Check the durable spool and service with `journal-daemon status --config ~/.config/journal-daemon/config.json` and `brew services list`. The checked-in endpoint is a placeholder, so replace `destination.baseURL` only with the approved HTTPS import API before storing a token.

## USB opt-in marker

The daemon ignores every volume unless its root contains a `.journal-daemon` directory. Create it on a drive you intend to ingest before connecting it:

```bash
mkdir /Volumes/YOUR_DRIVE/.journal-daemon
```

The existing source rules still apply, including the configured volume name, removable-media requirement, and audio extensions. The marker prevents an unrelated matching USB volume from being scanned or showing the menu-bar indicator.

## Tailscale bell bridge

Any Mac with this command installed can play a built-in macOS sound locally:

```bash
journal-daemon bell ring --sound Glass
```

To ring another Tailscale device, such as `air15`, install the command on that Mac and allow Tailscale SSH between the calling identity and the destination. Then an agent or service can use:

```bash
journal-daemon bell send --device air15 --user carlos --sound Glass
```

The sender runs strict-host-checked SSH to the Tailscale MagicDNS device, then calls `journal-daemon bell ring --sound Glass`. No listener or shared bearer token is exposed. The caller needs an authorized SSH key and a trusted host key; `--user` defaults to the caller's local macOS user. Run `journal-daemon bell sounds` for the allowlisted sound names.

Read [docs/PROPOSAL.md](docs/PROPOSAL.md) for the architecture, delivery plan, API contract, installation design, security model, test strategy, acceptance gates, and open decisions.

## Privacy

Recordings and credentials must never be committed to this repository. The future agent will preserve source recordings by default and will not delete anything from a DJI device unless a separately reviewed feature explicitly enables it.
