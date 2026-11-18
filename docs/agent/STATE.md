# Journal Daemon State

Last updated: 2026-11-18

- Repository: `guerrerocarlos/journal-daemon` (private initially)
- Local workspace: `/home/gnu/journal-daemon`
- LIFE Telegram topic: `journal-daemon` / topic ID `6232`
- Phase: local ingestion daemon, Tailscale bell bridge, and Homebrew service implemented
- A Swift bootstrap CLI and HEAD-only Homebrew formula exist. The formula compiles from source during target-Mac installation, with no bottles or precompiled executables.
- `docs/index.html` provides the repository-owned installation page. GitHub Pages publishing is blocked because the current plan does not support it for this private repository. MacOS installation acceptance remains pending.
- The daemon polls mounted volumes every 15 seconds, rejects unstable files, atomically spools and hashes eligible recordings, stores state in SQLite, and retries idempotent multipart uploads using a Keychain token.
- The formula defines a per-user `brew services` LaunchAgent with `keep_alive true`. A real DJI device and approved upload API still require hardware and live-service acceptance.
- `journal-daemon bell ring` plays an allowlisted local macOS system sound. `journal-daemon bell send --device NAME` reaches another enrolled Mac through strict-host-checked SSH over Tailscale MagicDNS.
- macOS acceptance on `air15` passed on 2026-11-18: Swift tests, source-only Homebrew install at `HEAD-b89edf5`, `brew test`, sound enumeration, and audible local `Glass` playback. A successful remote-send acceptance remains pending an authorized SSH key on a separate caller machine; a self-call on `air15` correctly failed because it has no credential authorized for `carlos@air15`.
- Ingestion acceptance on `air15` passed on 2026-11-18: a synthetic stable WAV was atomically spooled once, persisted as `pending` in SQLite across a second scan, and the source-built `HEAD-d6e1b08` formula passed `brew test`. The Homebrew LaunchAgent was started and restarted successfully. Real DJI and live upload acceptance remain pending.
- The installed `air15` formula was refreshed to `HEAD-93c49a6` and its LaunchAgent was started after the no-echo Keychain token prompt update.
- Proposed implementation is a native Swift executable installed from source by Homebrew and run as a per-user LaunchAgent through `brew services`.
- Proposed configuration is strict versioned JSON at `~/.config/journal-daemon/config.json`; secrets belong in macOS Keychain.
- Source recordings remain unchanged. The MVP does not delete files from DJI devices.
- The first implementation milestone requires actual DJI volume metadata and an approved upload API contract.
