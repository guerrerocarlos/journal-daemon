# Journal Daemon

Planning workspace for a small macOS background agent that detects configured DJI Mic storage volumes, copies new recordings into a durable local spool, and uploads them to a journal API.

The proposed application is installed through Homebrew and compiled from source on the target Mac. No precompiled executable or Homebrew bottle is planned.

## Current status

This repository contains a proposal and configuration example only. It does not yet contain an executable daemon, a working Homebrew formula, or a deployed upload API.

Read [docs/PROPOSAL.md](docs/PROPOSAL.md) for the architecture, delivery plan, API contract, installation design, security model, test strategy, acceptance gates, and open decisions.

## Privacy

Recordings and credentials must never be committed to this repository. The future agent will preserve source recordings by default and will not delete anything from a DJI device unless a separately reviewed feature explicitly enables it.
