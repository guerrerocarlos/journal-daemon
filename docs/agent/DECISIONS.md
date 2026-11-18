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

- Keep installation instructions in repository-owned `docs/index.html`. GitHub Pages publication requires a supported private-repository plan or explicit approval to make the repository public.
- Ship a small Swift bootstrap CLI and a Homebrew `HEAD` formula before the device and API milestones.
- Require `brew install --HEAD --build-from-source journal-daemon` so Homebrew clones source and Swift compiles the binary on the target Mac.
- Run the implemented daemon as a per-user Homebrew service with `keep_alive true`; restart recovery comes from its local SQLite state and atomic spool.

## 2026-11-18: Ingestion runtime

- Poll mounted volumes every 15 seconds as the portable first implementation of live device discovery. A startup scan and durable state make restarts safe.
- Copy eligible stable files into the local spool before any network operation, compute SHA-256 while copying, and record the copy in SQLite before upload.
- Use Keychain for the destination bearer token, HTTPS-only destination URLs, an idempotency key derived from SHA-256, and bounded retry backoff in SQLite.
- Keep source-device files immutable and reject configuration that requests source deletion.

## 2026-11-18: Tailscale bell bridge

- Use strict-host-checked system SSH over Tailscale MagicDNS as the first remote sound transport instead of adding an HTTP listener to every Mac. Tailscale SSH server mode was not enabled on the first target Mac.
- Restrict sound selection to an allowlist of macOS system sound names and validate destination hostnames before spawning a process.
- Require ordinary SSH key and host-key authorization over the tailnet. Do not add a shared bearer token, inbound port, or arbitrary remote command execution.
