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

`docs/index.html` is published by `.github/workflows/pages.yml` through GitHub Pages after the repository's Pages source is configured for GitHub Actions. The expected URL is `https://guerrerocarlos.github.io/journal-daemon/`.
