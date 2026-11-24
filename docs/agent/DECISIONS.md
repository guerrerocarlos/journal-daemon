# Journal Daemon Decisions

## 2026-11-18: Planning baseline

- Use native Swift and Swift Package Manager for macOS integration and source builds.
- Use Apple Disk Arbitration callbacks plus a startup scan for mounted-volume discovery.
- Use a per-user LaunchAgent managed by `brew services`, not a privileged LaunchDaemon.
- Compile from source during Homebrew installation. Do not publish Homebrew bottles or precompiled executables.
- Use strict versioned JSON configuration to avoid a third-party configuration parser in the first source build.
- Use a private Tailscale HTTPS receiver as the ingestion authorization boundary. Do not store an application API credential in configuration or Keychain.
- Copy stable recordings to an atomic local spool before upload.
- Use SQLite and SHA-256 for crash recovery, acknowledgement state, and deduplication.
- Never delete or modify DJI source files in the MVP.
- Keep the repository private initially. Public visibility for simpler distribution requires explicit approval.

## 2026-11-18: Bootstrap source installation

- Make the repository public so anyone can install from source through Homebrew and access the GitHub Pages installation page.
- Ship a small Swift bootstrap CLI and a Homebrew `HEAD` formula before the device and API milestones.
- Require `brew install --HEAD --build-from-source journal-daemon` so Homebrew clones source and Swift compiles the binary on the target Mac.
- Run the implemented daemon as a per-user Homebrew service with `keep_alive true`; restart recovery comes from its local SQLite state and atomic spool.

## 2026-11-18: Ingestion runtime

- Poll mounted volumes every 15 seconds as the portable first implementation of live device discovery. A startup scan and durable state make restarts safe.
- Copy eligible stable files into the local spool before any network operation, compute SHA-256 while copying, and record the copy in SQLite before upload.
- Use HTTPS-only destination URLs, an idempotency key derived from SHA-256, and bounded retry backoff in SQLite.
- Keep source-device files immutable and reject configuration that requests source deletion.
- Require a `.journal-daemon` directory at each source volume root as an explicit physical-media opt-in. A matching volume without the marker is ignored. The default volume matcher may accept any removable volume because the marker, rather than a potentially generic DJI volume label, is the safety boundary.
- Treat all files below known removable-media trash directories as ineligible, independent of source extension or configured filename exclusion. Never copy, hash, spool, or upload them.
- Run the per-user service as an accessory app so it can show a menu-bar indicator only while a configured matching USB volume is connected. During a network upload it remains visible with active filename and byte-level URLSession progress. The indicator is informational and never alters source media.

## 2026-11-24: Per-volume acknowledged-media cursor

- Store `.journal-daemon/last-processed.json` only after a timestamped DJI recording has been acknowledged by the receiver. The file contains the newest processed capture timestamp and relative path, so future scans of that same opted-in volume skip timestamped media at or before it.
- The cursor is daemon control metadata inside the explicit marker directory, never a change to DJI recordings. Files without a recognized DJI timestamp retain normal digest-based processing.
- Ignore AppleDouble `._*` sidecar files even when their names end in an included media extension.
- When a recorder timestamp is ahead of the Mac clock, require two consecutive scans with the same byte size before considering that future-dated file stable. This prevents a clock mismatch from blocking ingestion indefinitely without weakening protection for an active recording.

## 2026-11-18: Tailscale bell bridge

- Use strict-host-checked system SSH over Tailscale MagicDNS as the first remote sound transport instead of adding an HTTP listener to every Mac. Tailscale SSH server mode was not enabled on the first target Mac.
- Restrict sound selection to an allowlist of macOS system sound names and validate destination hostnames before spawning a process.
- Require ordinary SSH key and host-key authorization over the tailnet. Do not add a shared bearer token, inbound port, or arbitrary remote command execution.

## 2026-11-18: Telegram bridge media ingestion

- Deliver spool files to the existing Telegram bridge over Tailscale HTTPS, not directly to the Journal Git repository.
- Use the private tailnet access policy and Tailscale Serve as the authorization boundary, plus SHA-256 idempotency and an explicit configured Telegram chat and forum-topic route in each daemon destination. Do not expose this endpoint through Funnel or a public proxy.
- The bridge must reject unbound routes, then send the audio into the requested topic and feed the same bytes through the Journal archival pipeline.

## 2026-11-23: Fleet update policy

- Treat `air15` and `pro13` as the deployment fleet. Every daemon improvement should be installed and verified on both Macs when they are reachable, and any unavailable machine must be reported explicitly.
- Have the running per-user daemon check its approved public Homebrew tap every 24 hours. When a new HEAD revision is available, source-build it and restart only after Homebrew completes the upgrade successfully.

## 2026-11-23: Multipart upload construction

- Construct multipart request bodies on disk so large spool files do not enter process memory.
- After writing the metadata and file-part header, explicitly seek to the end before appending recording bytes. Reopening at offset zero overwrites the metadata header and makes the receiver correctly reject the request as malformed.
- Set `Content-Length` from the completed on-disk body before starting the URLSession upload, so the Tailscale proxy receives a bounded multipart request rather than relying on transfer framing.
