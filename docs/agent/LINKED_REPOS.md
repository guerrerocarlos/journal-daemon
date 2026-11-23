# Journal Daemon Linked Repositories

## Journal

- Repository: `guerrerocarlos/journal`
- Relationship: intended downstream owner of journal media or metadata, subject to an approved API boundary.
- Current contract: none. The daemon must not push directly into the Journal Git repository unless a later decision explicitly chooses that design.

## LIFE Manager

- Repository: `guerrerocarlos/life-manager`
- Relationship: household worklog, durable cross-project context, and fleet registration for LIFE Telegram topic `journal-daemon` / topic ID `6232`.

## Upload API

- Repository and service: `/home/gnu/codex-cli-over-telegram`.
- Contract: private Tailscale HTTPS `POST /journal-daemon/v1/imports`, multipart `metadata` plus `file`, SHA-256 idempotency key, and a route containing `chatId` and `messageThreadId`.
- Boundary: the bridge validates the route is an existing bound Journal topic, sends audio to that topic, and archives it. Tailscale Serve and the tailnet access policy authorize delivery. The daemon never receives Telegram bot credentials or pushes directly to the Journal Git repository.

## Tailscale tailnet

- Relationship: transport and authorization boundary for the bell bridge between agent machines and destination Macs such as `air15`.
- Contract: callers run `journal-daemon bell send --device NAME`, which invokes strict-host-checked SSH over Tailscale MagicDNS to run `journal-daemon bell ring`. Destination SSH authorization and known-host verification are required.
- Boundary: this repository opens no sound HTTP port and stores no shared tailnet or sound-bridge credential.
