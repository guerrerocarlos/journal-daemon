# Journal Daemon State

Last updated: 2026-11-18

- Repository: `guerrerocarlos/journal-daemon` (private initially)
- Local workspace: `/home/gnu/journal-daemon`
- LIFE Telegram topic: `journal-daemon` / topic ID `6232`
- Phase: bootstrap installation implemented, functional daemon pending
- A Swift bootstrap CLI and HEAD-only Homebrew formula exist. The formula compiles from source during target-Mac installation, with no bottles or precompiled executables.
- `docs/index.html` provides the repository-owned installation page. GitHub Pages publishing is blocked because the current plan does not support it for this private repository. MacOS installation acceptance remains pending.
- No device ingestion, LaunchAgent, API integration, deployment, or hardware validation exists yet.
- Proposed implementation is a native Swift executable installed from source by Homebrew and run as a per-user LaunchAgent through `brew services`.
- Proposed configuration is strict versioned JSON at `~/.config/journal-daemon/config.json`; secrets belong in macOS Keychain.
- Source recordings remain unchanged. The MVP does not delete files from DJI devices.
- The first implementation milestone requires actual DJI volume metadata and an approved upload API contract.
