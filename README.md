# Journal Daemon

Source-built bootstrap for a small macOS background agent that will detect configured DJI Mic storage volumes, copy new recordings into a durable local spool, and upload them to a journal API.

The proposed application is installed through Homebrew and compiled from source on the target Mac. No precompiled executable or Homebrew bottle is planned.

## Current status

This repository now contains a source-built bootstrap CLI, its Homebrew formula, configuration example, and an installation page. It does not yet contain device ingestion, a background service, a working upload API, or hardware acceptance evidence.

## Install from source

Open [`docs/index.html`](docs/index.html) for the repository-owned installation page with copyable commands and scope notes. Publishing it through GitHub Pages requires either a plan that supports Pages for this private repository or explicit approval to change repository visibility.

```bash
brew tap guerrerocarlos/journal-daemon git@github.com:guerrerocarlos/journal-daemon.git
brew trust guerrerocarlos/journal-daemon
brew install --HEAD --build-from-source journal-daemon
```

This intentionally uses the formula's `HEAD` source and compiles with Swift on the target Mac. No bottle or precompiled executable is published.

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
