# Journal Daemon Linked Repositories

## Journal

- Repository: `guerrerocarlos/journal`
- Relationship: intended downstream owner of journal media or metadata, subject to an approved API boundary.
- Current contract: none. The daemon must not push directly into the Journal Git repository unless a later decision explicitly chooses that design.

## LIFE Manager

- Repository: `guerrerocarlos/life-manager`
- Relationship: household worklog and durable cross-project context.

## Upload API

- Repository and service: not selected.
- Required boundary: authenticated, streaming, idempotent media import with a durable acknowledgement.
