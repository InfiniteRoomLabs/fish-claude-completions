# Fish Shell Completions for Claude Code CLI

**Date:** 2026-03-14
**Status:** Approved
**Repository:** InfiniteRoomLabs/fish-claude-completions

## Purpose

A Fisher plugin that provides comprehensive tab completions for the `claude` CLI (Claude Code). Installable via `fisher install InfiniteRoomLabs/fish-claude-completions`.

Starting point is the community gist by r4ai, enhanced with dynamic completions, full subcommand trees, and build-time config key generation.

## File Structure

```
fish-claude-completions/
  completions/claude.fish                          # All completions + inline helper functions
  scripts/generate-config-keys.py                  # CI/CD: fetches SchemaStore, patches completions
  .github/workflows/update-config-keys.yml         # Scheduled GitHub Actions workflow
  README.md                                        # Installation instructions
  LICENSE                                          # MIT
```

Fisher installs only from `completions/`, `functions/`, and `conf.d/`. The `scripts/` and `.github/` directories are development-only.

## Architecture: Single-File Approach

All completions and helper functions live in `completions/claude.fish`. This is the standard Fisher pattern -- Fish loads the completions file once per shell session. Helper functions are defined inline at the top of the file.

### Helper Functions

#### `__fish_claude_no_subcommand`

Returns true when the commandline has no subcommand yet. Used as a condition for top-level flags and subcommand suggestions.

Checks `commandline -opc` against the known subcommand list: `config`, `mcp`, `auth`, `plugin`, `plugins`, `agents`, `doctor`, `update`, `upgrade`, `install`, `setup-token`, `migrate-installer`.

#### `__fish_claude_mcp_servers`

Returns MCP server names for `mcp get/remove/enable/disable <tab>`.

Resolution order:
1. Parse `~/.claude/settings.local.json` -- extract keys from `mcpServers` object
2. Parse `.mcp.json` in current directory -- extract keys from `mcpServers` object
3. Fallback: parse `claude mcp list` output -- extract server names (first field before the colon)

All three sources are merged (deduplicated). No persistent caching -- results are computed per completion invocation. No network calls.

#### `__fish_claude_sessions`

Returns session IDs with descriptions for `--resume <tab>`.

1. Derives the project slug from `$PWD` using Claude's encoding: path with `/` replaced by `-`, leading `-` stripped
2. Lists `*.jsonl` files in `~/.claude/projects/{slug}/`
3. For each file, extracts the UUID from the filename
4. Reads the corresponding session metadata from `~/.claude/sessions/*.json` to get timestamps
5. Returns formatted as: `uuid\tdescription (time ago)`

Scoped to the current project directory only -- does not show sessions from other projects.

## Completion Coverage

### Top-Level Flags (when no subcommand)

All ~40 flags from `claude --help`:

| Category | Flags |
|----------|-------|
| Simple toggles | `--debug`, `--verbose`, `--print`, `--version`, `--help`, `--ide`, `--chrome`, `--no-chrome`, `--brief`, `--fork-session`, `--mcp-debug`, `--dangerously-skip-permissions`, `--allow-dangerously-skip-permissions`, `--disable-slash-commands`, `--no-session-persistence`, `--include-partial-messages`, `--replay-user-messages` |
| Enumerated values | `--output-format` (text/json/stream-json), `--input-format` (text/stream-json), `--effort` (low/medium/high/max), `--permission-mode` (acceptEdits/bypassPermissions/default/dontAsk/plan/auto), `--model` (sonnet/opus/haiku) |
| Dynamic values | `--resume` (sessions), `--mcp-config` (files), `--add-dir` (directories), `--debug-file` (files), `--plugin-dir` (directories), `--settings` (files) |
| Freeform values | `--system-prompt`, `--append-system-prompt`, `--allowedTools`, `--disallowedTools`, `--json-schema`, `--max-budget-usd`, `--session-id`, `--name`, `--agents`, `--betas`, `--tools`, `--setting-sources`, `--file`, `--agent`, `--worktree`, `--from-pr`, `--tmux` |

### Subcommands

Suggested when no subcommand is present: `config`, `mcp`, `auth`, `plugin`, `agents`, `doctor`, `update`, `install`, `setup-token`, `migrate-installer`.

### `config` Subcommand Tree

```
config
  set [--global/-g] <key> <value>
  get [--global/-g] <key>
  list
  reset
```

Config key names are hardcoded in the completions file but generated at CI/CD build time by `scripts/generate-config-keys.py`, which fetches the schema from `https://json.schemastore.org/claude-code-settings.json` and extracts all top-level property names.

### `mcp` Subcommand Tree

```
mcp
  list
  add [--transport stdio|sse|http] [--scope local|user|project] [-e KEY=val] [-H header] [--callback-port] [--client-id] [--client-secret] <name> <command> [args...]
  add-json <name> <json>
  add-from-claude-desktop
  remove <name>          # dynamic: __fish_claude_mcp_servers
  get <name>             # dynamic: __fish_claude_mcp_servers
  enable <name>          # dynamic: __fish_claude_mcp_servers
  disable <name>         # dynamic: __fish_claude_mcp_servers
  serve [--debug] [--verbose]
  reset-project-choices
```

### `auth` Subcommand Tree

```
auth
  login
  logout
  status
```

### `plugin` Subcommand Tree

```
plugin
  install <plugin>
  uninstall <plugin>
  list
  enable <plugin>
  disable <plugin>
  update <plugin>
  validate <path>
  marketplace
    add <source>
    remove <name>
    list
    update [name]
```

### `install` Subcommand

```
install [--force] [stable|latest|<version>]
```

### Simple Subcommands

`doctor`, `update`/`upgrade`, `agents`, `setup-token`, `migrate-installer` -- only `--help` completion.

## CI/CD: Config Key Generation

### `scripts/generate-config-keys.py`

Python script (run with `uv`) that:
1. Fetches `https://json.schemastore.org/claude-code-settings.json`
2. Extracts all top-level property names (excluding `$schema`)
3. For properties with enum values, also extracts the allowed values
4. Patches `completions/claude.fish` by replacing the content between marker comments:
   ```fish
   # BEGIN GENERATED CONFIG KEYS
   ...
   # END GENERATED CONFIG KEYS
   ```

### `.github/workflows/update-config-keys.yml`

Scheduled workflow (weekly or on-demand) that:
1. Runs `scripts/generate-config-keys.py`
2. If the completions file changed, commits and opens a PR

## Design Decisions

1. **Single-file completions** -- standard Fisher pattern, simple to install and maintain.
2. **No runtime network calls** -- config keys are baked in at build time; MCP/session data comes from local files only.
3. **Project-scoped sessions** -- `--resume` only shows sessions for the current working directory, matching Claude's behavior.
4. **MCP fallback chain** -- fast JSON parse first, `claude mcp list` only as last resort (has health-check latency).
5. **Build-time codegen** -- keeps the shipped completion file self-contained while staying current with schema changes.

## Testing

Manual testing approach:
- `claude <tab>` -- shows subcommands and flags
- `claude --effort <tab>` -- shows low/medium/high/max
- `claude mcp remove <tab>` -- shows configured MCP servers
- `claude --resume <tab>` -- shows project-scoped session IDs
- `claude config set <tab>` -- shows config key names
- `claude plugin marketplace <tab>` -- shows add/remove/list/update
