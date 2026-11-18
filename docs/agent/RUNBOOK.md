# Journal Daemon Runbook

## Current proposal verification

```bash
git status --short --branch
git diff --check
python3 -m json.tool config/config.example.json >/dev/null
```

The bootstrap CLI exists, but there is no executable service, device ingestion, or upload integration yet.

## Bootstrap developer checks

```bash
swift build
swift test
swift run journal-daemon config validate --config config/config.example.json
swift run journal-daemon doctor
swift run journal-daemon bell sounds
```

## Bootstrap Homebrew checks

```bash
brew tap guerrerocarlos/journal-daemon git@github.com:guerrerocarlos/journal-daemon.git
brew trust guerrerocarlos/journal-daemon
brew install --HEAD --build-from-source journal-daemon
brew test journal-daemon
journal-daemon doctor
```

The formula runs `swift build --configuration release` during installation. It has not yet been accepted on macOS hardware. `brew services` remains a later milestone because `run` is not implemented.

## Tailscale bell bridge

Install `journal-daemon` and Tailscale on each destination Mac. Tailscale SSH must be enabled and its ACLs must permit the caller to execute `journal-daemon bell ring` on the destination.

```bash
# On the destination Mac, verify local audio.
journal-daemon bell ring --sound Glass

# From an authorized Tailscale machine, request a bell on air15.
journal-daemon bell send --device air15 --sound Glass
```

The implementation invokes `tailscale ssh air15 journal-daemon bell ring --sound Glass`. It does not open a TCP listener, accept arbitrary shell arguments, or store a shared token. Validate the exact Tailscale ACL and audible output manually on the target Macs before relying on it for agent completion notifications.

## Installation page

`docs/index.html` is the repository-owned installation page. GitHub returned `422` when enabling Pages because the current plan does not support Pages for this private repository. Do not add a Pages deployment workflow until the repository is made public with approval or the account supports private-repository Pages.
