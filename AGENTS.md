# Journal Daemon Agent Instructions

The repository is planning-only until the implementation milestone is explicitly approved.

- Keep `docs/agent/` current whenever architecture, setup, testing, installation, runtime state, or linked-repository contracts change.
- Never commit recordings, API tokens, Keychain exports, device identifiers, private endpoint credentials, or local state databases.
- Treat DJI media as immutable input. Do not delete or modify source files on a connected device without explicit approval and a separate safety review.
- Keep uploads idempotent and preserve a recoverable local spool until the server acknowledges each file.
- The Homebrew installation must compile from source. Do not publish or consume precompiled binaries or bottles unless the user changes this decision.
- Prefer a per-user LaunchAgent through `brew services`; do not require root privileges for the normal installation or runtime.
- Distinguish proposal, local test, hardware acceptance, API integration, and live-service evidence.
