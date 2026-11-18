# Journal Daemon Decisions

## 2026-11-18: Planning baseline

- Use native Swift and Swift Package Manager for macOS integration and source builds.
- Use Apple Disk Arbitration callbacks plus a startup scan for mounted-volume discovery.
- Use a per-user LaunchAgent managed by `brew services`, not a privileged LaunchDaemon.
- Compile from source during Homebrew installation. Do not publish Homebrew bottles or precompiled executables.
- Use strict versioned JSON configuration to avoid a third-party configuration parser in the first source build.
- Store API credentials in macOS Keychain and only store their service/account reference in configuration.
- Copy stable recordings to an atomic local spool before upload.
- Use SQLite and SHA-256 for crash recovery, acknowledgement state, and deduplication.
- Never delete or modify DJI source files in the MVP.
- Keep the repository private initially. Public visibility for simpler distribution requires explicit approval.

## 2026-11-18: Bootstrap source installation

- Publish installation instructions from repository-owned `docs/index.html` through GitHub Pages.
- Ship a small Swift bootstrap CLI and a Homebrew `HEAD` formula before the device and API milestones.
- Require `brew install --HEAD --build-from-source journal-daemon` so Homebrew clones source and Swift compiles the binary on the target Mac.
- Do not add a service block until `journal-daemon run` has safe, implemented behavior.
