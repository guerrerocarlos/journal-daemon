# Journal Daemon

Source-built bootstrap for a small macOS background agent that will detect configured DJI Mic storage volumes, copy new recordings into a durable local spool, and upload them to a journal API.

The proposed application is installed through Homebrew and compiled from source on the target Mac. No precompiled executable or Homebrew bottle is planned.

## Current status

This repository now contains a source-built bootstrap CLI, its Homebrew formula, configuration example, and an installation page. It does not yet contain device ingestion, a background service, a working upload API, or hardware acceptance evidence.

## Install from source

The [installation page](https://guerrerocarlos.github.io/journal-daemon/) contains the current copyable commands and scope notes.

```bash
brew tap guerrerocarlos/journal-daemon https://github.com/guerrerocarlos/journal-daemon
brew install --HEAD --build-from-source journal-daemon
```

This intentionally uses the formula's `HEAD` source and compiles with Swift on the target Mac. No bottle or precompiled executable is published.

Read [docs/PROPOSAL.md](docs/PROPOSAL.md) for the architecture, delivery plan, API contract, installation design, security model, test strategy, acceptance gates, and open decisions.

## Privacy

Recordings and credentials must never be committed to this repository. The future agent will preserve source recordings by default and will not delete anything from a DJI device unless a separately reviewed feature explicitly enables it.
