# Journal Daemon State

Last updated: 2026-11-23

- Repository: `guerrerocarlos/journal-daemon` (public as of 2026-11-18)
- Local workspace: `/home/gnu/journal-daemon`
- LIFE Telegram topic: `journal-daemon` / topic ID `6232`
- Phase: local ingestion daemon, Tailscale bell bridge, and Homebrew service implemented
- A Swift bootstrap CLI and HEAD-only Homebrew formula exist. The formula compiles from source during target-Mac installation, with no bottles or precompiled executables.
- `docs/index.html` is deployed through GitHub Pages at `https://guerrerocarlos.github.io/journal-daemon/`. Workflow run `44371486972` succeeded and the live page was verified on 2026-11-18.
- The daemon polls mounted volumes every 15 seconds, but only accepts a matching source whose volume root contains a `.journal-daemon` directory. It rejects unstable files, atomically spools and hashes eligible recordings, stores state in SQLite, and retries idempotent multipart uploads to the private Tailscale receiver.
- The per-user LaunchAgent runs as an accessory macOS app. A menu-bar drive icon appears only while a configured matching volume is mounted, identifies the matching source, and offers a manual scan. During API upload it stays visible with an upload icon, filename, and URLSession byte progress.
- The formula defines a per-user `brew services` LaunchAgent with `keep_alive true`. Its approved upload API is the `codex-cli-over-telegram` bridge's Tailscale HTTPS endpoint. Each destination carries an explicit Telegram group and topic route, which the bridge validates before posting and mechanically archiving audio. The private tailnet and Tailscale Serve, rather than an application token, authorize delivery.
- `pro13` was installed from `HEAD-7a4250b` on 2026-11-23 using the public explicit-URL tap, passed `brew test`, and runs as `carlosguerrero` through `sh.brew.journal-daemon`. Its mode-`0600` configuration uses the private bridge and LIFE Journal route `-1004361900873` / topic `5701`, with no `auth` setting. Its standalone `swift test` is blocked by a missing XCTest utility in the host Command Line Tools installation; `swift build -c release` passed.
- `journal-daemon bell ring` plays an allowlisted local macOS system sound. `journal-daemon bell send --device NAME` reaches another enrolled Mac through strict-host-checked SSH over Tailscale MagicDNS.
- macOS acceptance on `air15` passed on 2026-11-18: Swift tests, source-only Homebrew install at `HEAD-b89edf5`, `brew test`, sound enumeration, and audible local `Glass` playback. A successful remote-send acceptance remains pending an authorized SSH key on a separate caller machine; a self-call on `air15` correctly failed because it has no credential authorized for `carlos@air15`.
- Ingestion acceptance on `air15` passed on 2026-11-18: a synthetic stable WAV was atomically spooled once, persisted as `pending` in SQLite across a second scan, and the source-built `HEAD-d6e1b08` formula passed `brew test`. The Homebrew LaunchAgent was started and restarted successfully. Real DJI and live upload acceptance remain pending.
- The installed `air15` formula was refreshed to `HEAD-93c49a6` and its LaunchAgent was started. The pending update removes the obsolete application-token configuration.
- Proposed implementation is a native Swift executable installed from source by Homebrew and run as a per-user LaunchAgent through `brew services`.
- Configuration is strict versioned JSON at `~/.config/journal-daemon/config.json`; its receiver must be a private Tailscale HTTPS endpoint protected by Tailscale Serve and tailnet policy.
- Source recordings remain unchanged. The MVP does not delete files from DJI devices.
- Real DJI-media and live bridge acceptance remain required before relying on production ingestion.
