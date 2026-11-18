# Journal Daemon Runbook

## Current proposal verification

```bash
git status --short --branch
git diff --check
python3 -m json.tool config/config.example.json >/dev/null
```

There is no executable service to install, test, start, or deploy yet.

## Planned developer checks

```bash
swift build
swift test
swift run journal-daemon config validate --config config/config.example.json
swift run journal-daemon scan --dry-run --config config/config.example.json
```

## Planned Homebrew checks

```bash
brew tap guerrerocarlos/journal-daemon git@github.com:guerrerocarlos/journal-daemon.git
brew install --build-from-source journal-daemon
brew test journal-daemon
brew services start journal-daemon
brew services list
journal-daemon doctor
```

These commands are design targets and must not be reported as successful until the implementation and formula exist and are tested on macOS.
