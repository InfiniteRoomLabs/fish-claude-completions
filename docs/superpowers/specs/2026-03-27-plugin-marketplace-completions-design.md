# Plugin & Marketplace Dynamic Completions

**Date:** 2026-03-27
**Status:** Approved

## Goal

Add dynamic tab completions for installed plugin names and registered marketplace names to the `claude plugin` subcommand tree.

## Data Sources

### Installed Plugins

- **File:** `~/.claude/plugins/installed_plugins.json`
- **Structure:** `{ "version": 2, "plugins": { "name@marketplace": [ { "scope": "user|project", "version": "1.0.0|unknown", ... } ] } }`
- A single plugin key can have multiple entries (one per scope).

### Known Marketplaces

- **File:** `~/.claude/plugins/known_marketplaces.json`
- **Structure:** `{ "marketplace-name": { "source": { "source": "github", "repo": "owner/repo" }, ... } }`

## Design

### Approach: Two standalone helper functions

Add `__fish_claude_installed_plugins` and `__fish_claude_known_marketplaces` as new functions in `completions/claude.fish`, following the same pattern as `__fish_claude_mcp_servers` and `__fish_claude_agents`.

Each reads its respective JSON file with `jq`, extracts keys + metadata, and outputs `name\tdescription` pairs. They are wired into existing completion rules via `-xa "(__fish_claude_installed_plugins)"`.

### `__fish_claude_installed_plugins`

Reads `~/.claude/plugins/installed_plugins.json`. For each entry in the `plugins` object, outputs:

```
name@marketplace\tscope, vVERSION
```

For plugins with multiple scope entries (e.g., installed at both `user` and `project` scope), emits one line per entry so the description reflects the correct scope. If version is `"unknown"`, shows `unknown` (no `v` prefix).

Example output:

```
superpowers@claude-plugins-official	project, v5.0.6
agency@infinite-room-labs	user, unknown
```

Falls back silently to no output if the file doesn't exist or `jq` is unavailable.

### `__fish_claude_known_marketplaces`

Reads `~/.claude/plugins/known_marketplaces.json`. For each top-level key, outputs:

```
marketplace-name\tGitHub repo
```

Extracts the repo from `.source.repo`.

Example output:

```
claude-plugins-official	anthropics/claude-plugins-official
infinite-room-labs	InfiniteRoomLabs/agent-ops
impeccable	pbakaus/impeccable
```

Same fallback behavior -- silent no-op if the file is missing or `jq` is unavailable.

### Completion Wiring

| Subcommand | Completes with |
|---|---|
| `claude plugin uninstall/remove <tab>` | `__fish_claude_installed_plugins` |
| `claude plugin enable <tab>` | `__fish_claude_installed_plugins` |
| `claude plugin disable <tab>` | `__fish_claude_installed_plugins` |
| `claude plugin update <tab>` | `__fish_claude_installed_plugins` |
| `claude plugin marketplace remove/rm <tab>` | `__fish_claude_known_marketplaces` |
| `claude plugin marketplace update <tab>` | `__fish_claude_known_marketplaces` |

No changes to existing scope flag completions -- those stay as-is.

### JSON Parsing

All JSON parsing uses `jq` (not Python). The queries are simple key/value extractions.

## Out of Scope

- `claude plugin install <tab>` -- listing available plugins from marketplace directories is deferred to a future iteration.

## Alternatives Considered

- **Single generic JSON key extractor:** Over-abstraction -- the metadata extraction differs between plugins (scope+version) and marketplaces (repo). Would require special-case logic, violating YAGNI.
- **Inline Python in completion rules:** Unreadable, untestable, breaks established pattern.
