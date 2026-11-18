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
```

## Bootstrap Homebrew checks

```bash
brew tap guerrerocarlos/journal-daemon git@github.com:guerrerocarlos/journal-daemon.git
brew install --HEAD --build-from-source journal-daemon
brew test journal-daemon
journal-daemon doctor
```

The formula runs `swift build --configuration release` during installation. It has not yet been accepted on macOS hardware. `brew services` remains a later milestone because `run` is not implemented.

## Installation page

`docs/index.html` is the repository-owned installation page. GitHub returned `422` when enabling Pages because the current plan does not support Pages for this private repository. Do not add a Pages deployment workflow until the repository is made public with approval or the account supports private-repository Pages.
