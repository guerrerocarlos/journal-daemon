# Journal Daemon Proposal

Status: proposal for approval

Date: 2026-11-18

## 1. Objective

Build a small macOS background agent that notices when a configured DJI Mic transmitter or storage volume becomes available, discovers recordings that have not been processed before, copies each recording safely to local storage, and uploads it to a configured HTTP API.

The application should be easy to install on another Mac with Homebrew. Homebrew must compile the executable from source on that Mac. The normal install and runtime must not require root access.

DJI documents that its transmitters expose recorded audio for export when connected to a computer. Current DJI generations store WAV recordings, with model-dependent splitting intervals and naming rules. Device names and layouts must therefore be configuration, not assumptions embedded in code.

## 2. Proposed outcome

The intended operator flow is:

```bash
brew tap guerrerocarlos/journal-daemon https://github.com/guerrerocarlos/journal-daemon.git
brew install --build-from-source journal-daemon
mkdir -p ~/.config/journal-daemon
cp "$(brew --prefix journal-daemon)/share/journal-daemon/config.example.json" \
  ~/.config/journal-daemon/config.json
journal-daemon config validate
brew services start journal-daemon
journal-daemon status
```

After that, connecting a matching DJI device causes the agent to:

1. Detect the mounted volume.
2. Wait until candidate recordings are no longer changing.
3. Copy each new file into an atomic local spool.
4. Hash and record it in a local SQLite state database.
5. Upload it with an idempotency key and metadata.
6. Mark it acknowledged only after a successful server response.
7. Remove the spool copy according to retention configuration.
8. Leave the original DJI recording untouched.

## 3. Scope

### MVP

- macOS 13 or later on Apple Silicon and Intel Macs.
- DJI storage presented as a mounted volume under macOS.
- WAV, MP3, and M4A discovery, configurable per source.
- Multiple configured devices and volume matching rules.
- Startup scan plus live volume appearance notifications.
- Stable-file detection before copying.
- Atomic local spool and crash-safe SQLite state.
- SHA-256 content identity and server idempotency.
- HTTPS upload to a private receiver protected by Tailscale Serve and tailnet policy.
- Retry with bounded concurrency and exponential backoff.
- Structured local logs with secret redaction.
- CLI commands for validation, status, scanning, retrying, and diagnostics.
- Homebrew source build and `brew services` integration.
- Tailscale SSH bell bridge for agent completion notifications, using only allowlisted macOS system sounds.

### Not in the MVP

- Deleting or formatting recordings on a DJI device.
- Audio editing, transcoding, transcription, or summarization on the Mac.
- A graphical application or menu bar interface.
- A privileged system LaunchDaemon.
- Automatic API provisioning.
- Homebrew bottles or other precompiled distributions.
- Uploading files that do not match an explicit source rule.
- An unauthenticated or token-authenticated inbound sound HTTP endpoint.

## 4. Architecture decision

### Native Swift executable

Use a Swift Package Manager executable targeting macOS. Swift provides direct access to Foundation, URLSession, CryptoKit, Security, OSLog, SQLite through the system library, and Apple frameworks without shipping a separate runtime.

The first implementation should avoid third-party runtime dependencies. JSON is selected for configuration because `Codable` can validate it without adding a package-manager dependency during Homebrew installation. A later version can add TOML only if the usability gain justifies the parser and source-fetch complexity.

Proposed package layout:

```text
Package.swift
Sources/
  JournalDaemon/
    Main.swift
    Commands/
    Config/
    DeviceDiscovery/
    FileDiscovery/
    Spool/
    State/
    Upload/
    Logging/
Tests/
  JournalDaemonTests/
Formula/
  journal-daemon.rb
config/
  config.example.json
```

### User LaunchAgent

Run as the logged-in user through `brew services`, which generates and manages a user LaunchAgent. A system LaunchDaemon is unnecessary and would create avoidable privilege, ownership, Keychain, and per-user configuration problems.

The service command will be equivalent to:

```text
journal-daemon run --config ~/.config/journal-daemon/config.json
```

The agent should stay running, respond to `SIGTERM`, finish or checkpoint active spool work within a short grace period, and resume safely on its next launch.

### Tailscale bell bridge

The daemon CLI also provides a small completion-notification bridge independent of the future long-running ingestion service:

```bash
journal-daemon bell ring --sound Glass
journal-daemon bell send --device air15 --sound Glass
```

`bell ring` plays one of the checked allowlisted files in `/System/Library/Sounds` through `afplay`. `bell send` invokes strict-host-checked system SSH over Tailscale MagicDNS, for example `ssh carlos@air15 journal-daemon bell ring ...`. The destination SSH key policy and known-host verification authorize the action. This avoids adding a listening port, shared API token, or generic remote shell facility to the daemon. Each target Mac still needs Tailscale, this command, SSH authorization, and a manual audio test.

### Disk Arbitration discovery

Use Apple Disk Arbitration callbacks to observe disk appearance, disappearance, and mount-path changes. At process startup, also scan already mounted volumes so a service restart cannot miss a connected transmitter.

The callback only schedules work. File enumeration, hashing, copying, and network traffic happen outside the Disk Arbitration callback on bounded asynchronous workers.

Matching is based on configuration:

- Volume name regular expression.
- Optional volume UUID for a specific transmitter.
- Removable-device requirement.
- Configured relative roots.
- Allowed file extensions.
- Excluded filename expression.

This avoids depending on a single DJI model or firmware naming convention. The CLI will provide `journal-daemon devices list --verbose` so the operator can inspect the volume properties and generate a precise rule.

## 5. File ingestion and data safety

### Stable-file rule

A recording is eligible only when:

- It is a regular readable file inside a configured mounted volume.
- Its extension and path match the source rule.
- Its size and modification time remain unchanged for `stableForSeconds`.
- It can be opened for reading.
- It is not already acknowledged in local state.

The copier reads from a file descriptor, writes to a temporary spool file, computes SHA-256 during the copy, calls `fsync`, and atomically renames the temporary file. Upload never reads directly from removable storage.

### Identity and deduplication

SQLite records:

- Source ID.
- Volume UUID when available.
- Original relative path and filename.
- Original size and timestamps.
- SHA-256 digest.
- Spool path and byte count.
- Discovery, copied, upload-attempt, acknowledged, and failure timestamps.
- Server import ID and response digest.
- Retry count and last redacted error.

The primary durable identity is the SHA-256 digest plus destination. The preliminary path, size, and modification tuple avoids unnecessary re-hashing during a single connection but is never sufficient by itself to declare a file uploaded.

The API request uses an idempotency key derived from the content digest and destination. A repeated file, service crash, lost response, reconnect, or device rename must not create a duplicate journal entry.

### Source preservation

`deleteSourceAfterUpload` is fixed to `false` in the MVP even though it appears in the versioned schema. Configuration validation rejects `true`. Deletion can be designed later with explicit confirmation, server acknowledgement evidence, retention age, and a dry-run report.

## 6. Proposed upload API contract

The daemon should depend on a narrow import contract rather than the implementation details of the journal application.

### Request

```http
POST /v1/journal/imports HTTP/1.1
Idempotency-Key: sha256:<hex digest>
Content-Type: multipart/form-data
```

Multipart fields:

- `file`: the original recording bytes and filename.
- `metadata`: UTF-8 JSON containing schema version, source ID, volume metadata, original relative path, original filename, byte count, SHA-256, file timestamps, discovery time, client version, and host-generated upload ID.

The daemon does not send arbitrary custom headers from configuration in the MVP. This prevents the config file from becoming an unstructured secret store or header-injection surface.

### Successful response

```json
{
  "version": 1,
  "importId": "imp_123",
  "status": "accepted",
  "sha256": "<same digest>",
  "receivedAt": "2026-11-18T12:00:00Z"
}
```

- `200` or `201`: acknowledged after schema and digest validation.
- `409`: treated as acknowledged only when the response identifies the same digest and an existing import ID.
- `202`: remains pending unless the response provides a status URL and the daemon confirms completion later.

### Failure policy

- Retry transport errors, timeouts, `408`, `425`, `429`, and `5xx` responses.
- Honor a valid bounded `Retry-After` value.
- Use exponential backoff with jitter and a configurable maximum interval.
- Treat other `4xx` responses as operator-action failures, retain the spool, and surface them in `status` and logs.
- Never log private response bodies that may contain media metadata.

The API must independently authenticate the client, enforce maximum body size, stream uploads instead of buffering them, validate the declared digest, use its own idempotency store, and scan or quarantine unexpected media before downstream processing.

## 7. Configuration

Default path:

```text
~/.config/journal-daemon/config.json
```

The checked-in example is `config/config.example.json`. The schema is versioned and unknown keys are rejected so typos do not silently weaken matching or retention behavior.

Configuration controls:

- Source IDs and volume matchers.
- Scan roots, file extensions, exclusions, and stability window.
- API base URL, import path, timeout, and explicit destination route.
- Spool location and maximum size.
- Upload concurrency and spool retention.
- Log level and directory.

Environment-variable expansion is intentionally excluded from the MVP. It makes LaunchAgent behavior harder to reason about. The upload receiver must be HTTPS, remain localhost-bound behind Tailscale Serve, and be reachable only under the tailnet access policy. The daemon does not send an application bearer token.

Validation commands:

```bash
journal-daemon config validate
journal-daemon devices list --verbose
journal-daemon scan --dry-run
journal-daemon doctor
```

## 8. CLI surface

```text
journal-daemon run [--config PATH]
journal-daemon status [--json]
journal-daemon config validate [--config PATH]
journal-daemon devices list [--verbose] [--json]
journal-daemon scan [--dry-run] [--source ID]
journal-daemon retry [--all | --sha256 DIGEST]
journal-daemon doctor [--json]
journal-daemon version
```

`status --json` and `doctor --json` make the agent automatable without requiring a local HTTP server. The background process does not listen on a network port.

## 9. Homebrew source-only installation

The repository will contain its own custom tap layout under `Formula/`. Because the requested repository name is not `homebrew-journal-daemon`, installation uses an explicit tap URL.

The repository is private initially. A new Mac must already have GitHub SSH access, for example through `gh auth login` and `gh auth setup-git`, before it can tap or fetch the source. If completely frictionless installation on arbitrary Macs is desired, the source and formula should later be made public. That visibility change requires explicit approval.

Planned formula shape after the first implementation tag:

```ruby
class JournalDaemon < Formula
  desc "Upload new recordings from configured removable volumes"
  homepage "https://github.com/guerrerocarlos/journal-daemon"
  url "git@github.com:guerrerocarlos/journal-daemon.git",
      tag: "v0.1.0",
      revision: "FULL_COMMIT_HASH"
  license :cannot_represent

  depends_on :macos
  uses_from_macos "swift" => :build
  deny_network_access!

  def install
    system "swift", "build", *std_swift_args
    bin.install ".build/release/journal-daemon"
    pkgshare.install "config/config.example.json"
  end

  service do
    run [opt_bin/"journal-daemon", "run", "--config",
         "#{Dir.home}/.config/journal-daemon/config.json"]
    keep_alive crashed: true
    process_type :background
    working_dir var
    log_path "#{Dir.home}/Library/Logs/com.guerrerocarlos.journal-daemon/service.log"
    error_log_path "#{Dir.home}/Library/Logs/com.guerrerocarlos.journal-daemon/service-error.log"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/journal-daemon version")
    system bin/"journal-daemon", "config", "validate",
           "--config", pkgshare/"config.example.json"
  end
end
```

There will be no `bottle` block or uploaded bottle artifact. Release verification will install with `--build-from-source`. The formula uses Homebrew's current Swift build helper, which selects a release build and the platform-specific sandbox arguments.

The proposed release workflow updates the tag, immutable revision, formula URL metadata, and checksum or revision in one reviewed change. It runs source builds on both Apple Silicon and Intel runners when available, but publishes only source and test evidence.

## 10. Service lifecycle and upgrades

- `brew services start journal-daemon` registers the per-user service.
- `brew services stop journal-daemon` stops it without deleting state or configuration.
- `brew upgrade journal-daemon` builds the new version from source.
- The upgrade workflow restarts the service only after a successful install.
- SQLite migrations are forward-only, transactional, and backed up before schema changes.
- An older binary must refuse to open a newer unsupported state schema.
- Uninstall leaves configuration, state, and unacknowledged spool files in place, and prints explicit cleanup commands.

## 11. Security and privacy

- Use HTTPS only, with normal platform certificate validation.
- Use Tailscale Serve and tailnet access policy as the ingestion authorization boundary. Do not expose the receiver with Funnel or a public proxy.
- Run as the current user with no root requirement.
- Do not listen on local or public network ports.
- Reject source paths that escape the mounted volume through symlinks or path traversal.
- Open files without following unexpected symbolic links where the platform API permits it.
- Validate that the volume is still the same mounted device throughout discovery and copy.
- Bound file size, spool size, concurrent uploads, retry rate, log size, and response body size.
- Redact query strings, home-directory paths when appropriate, and private API bodies.
- Give each source a stable non-secret ID; do not transmit hardware serial numbers unless the user explicitly enables it.
- Preserve recordings on the device and in the spool until server acknowledgement.
- Keep configuration at mode `0600` when it contains private endpoint and route details.

## 12. Observability and recovery

Use unified logging through OSLog plus optional rotating files for operator diagnostics. Every file has a local correlation ID. Logs report state transitions and byte counts but not audio content or secrets.

`journal-daemon status` reports:

- Service version and configuration path.
- Last successful device scan.
- Connected matching volumes.
- Pending, uploading, acknowledged, and failed counts.
- Spool bytes used and configured limit.
- Last successful API acknowledgement.
- Redacted actionable failures.

Recovery guarantees:

- Startup reconciles SQLite with spool files.
- Temporary copies without a completed atomic rename are removed or resumed safely.
- Copied but unacknowledged files are retried.
- Acknowledged files are never uploaded again for the same destination and digest.
- Missing source volumes do not invalidate already spooled work.
- A full spool pauses discovery and reports backpressure rather than discarding files.

## 13. Testing strategy

### Automated unit tests

- Strict configuration decoding and migration.
- Volume matcher rules.
- Path containment and symlink rejection.
- Stable-file detection.
- Streaming hash and atomic spool copy.
- SQLite state transitions and crash recovery.
- Idempotency-key generation.
- Retry classification, jitter bounds, and `Retry-After` handling.
- Response schema and digest validation.
- Log redaction.

### Automated integration tests

- Temporary directories acting as mounted-volume fixtures.
- Local HTTP test server with success, duplicate, timeout, rate-limit, partial-response, and server-error scenarios.
- Service termination during copy and upload.
- Reconnect and rename of the same simulated device.
- Duplicate content under different filenames.
- Spool quota exhaustion.

### macOS and hardware acceptance

- Fresh Apple Silicon Mac with only Command Line Tools, Homebrew, and GitHub access.
- Intel Mac source build where available.
- Actual DJI model identification using `devices list --verbose`.
- Connection before service startup and connection while service is running.
- Multiple transmitters and repeated reconnection.
- A recording still being finalized when connected.
- Network offline, network restored, Mac sleep/wake, logout/login, and reboot.
- Device unplugged during copy.
- API acknowledgement verified against the journal backend.
- Confirmation that the original recording remains unchanged.

### Homebrew acceptance

```bash
brew audit --strict --online guerrerocarlos/journal-daemon/journal-daemon
brew install --build-from-source --verbose journal-daemon
brew test journal-daemon
brew services start journal-daemon
brew services list
journal-daemon doctor
```

The exact audit command may differ for the explicit-URL tap and will be finalized against the implemented tap layout.

## 14. Delivery milestones

### M0: Decisions and fixtures

- Confirm DJI model and capture actual volume metadata and directory layout.
- Confirm API owner, URL, authentication method, maximum file size, and response contract.
- Decide repository visibility and minimum macOS version.
- Collect synthetic or explicitly approved test recordings without committing personal audio.

### M1: Local ingestion engine

- Swift package, configuration, device discovery, stable-file scan, spool, SQLite, status, dry-run, and tests.
- No network upload or background service yet.

### M2: API uploader

- Tailscale-only receiver checks, streaming multipart upload, idempotency, retry policy, response validation, and fake-server tests.
- Contract test against a non-production API environment.

### M3: Homebrew and LaunchAgent

- Tagged source release, formula, service block, source-only install, upgrade, stop, uninstall guidance, and dual-architecture CI evidence.

### M4: Hardware pilot

- Install on one Mac from scratch.
- Validate with the actual DJI transmitter and real API.
- Observe at least one reconnect, one duplicate, one offline retry, and one restart recovery.

### M5: Reusable release

- Resolve pilot findings.
- Publish installation and troubleshooting documentation.
- Test installation on a second Mac.
- Decide whether making the repository public is appropriate for simpler distribution.

## 15. Acceptance criteria

The MVP is complete only when:

1. Homebrew compiles the executable from source on a clean supported Mac.
2. `brew services start journal-daemon` runs it as the logged-in user without `sudo`.
3. Connecting the configured DJI device is detected without manual scanning.
4. Every eligible stable recording is copied to the spool before upload.
5. A server acknowledgement is durable and duplicate reconnects do not create duplicate imports.
6. Network and API failures retain the spool and recover automatically.
7. Unplugging the device during work does not corrupt state or falsely acknowledge a file.
8. The source recording remains unchanged.
9. The receiver remains private behind Tailscale Serve and tailnet policy, with no application token in configuration, logs, process arguments, or Git.
10. Status and doctor commands provide enough evidence to diagnose a failure.
11. Upgrade and service restart preserve pending work.
12. A second Mac can follow the documented installation without repository-specific manual edits beyond private endpoint and route configuration.

## 16. Open decisions requiring approval

1. Which DJI Mic generation and exact transmitter should be supported first?
2. What volume name, UUID, directory layout, and filename examples appear on the actual Mac?
3. Which API receives the recordings, and does it already exist?
4. Should the API create a Journal repository entry directly, enqueue transcription, or only store raw media?
5. Which tailnet identities and access rules may reach the private API receiver?
6. What is the maximum expected recording size and acceptable local spool limit?
7. Is macOS 13 an acceptable minimum?
8. Should the source repository remain private, or become public for frictionless Homebrew installation, and which source license should apply?
9. Should successful spool copies be retained for a short local recovery period or removed immediately after acknowledgement?
10. Should a future version ever delete acknowledged files from the DJI device? The recommendation is no by default.

## 17. Recommendation

Approve M0 and M1 first. Before implementing uploads, define the receiving API contract and test it independently. Before publishing the Homebrew formula, test the exact DJI device on a Mac and tag an immutable source release.

This sequence keeps device safety, upload correctness, privacy, and source-only installation independently reviewable.
