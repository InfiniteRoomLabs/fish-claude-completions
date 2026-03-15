# Fish Claude Completions Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Fisher plugin providing comprehensive tab completions for the `claude` CLI, with dynamic MCP/session completions and build-time config key generation.

**Architecture:** Single-file Fisher plugin (`completions/claude.fish`) with inline helper functions. Config keys are hardcoded but generated at CI/CD time from SchemaStore. MCP server names and session IDs are resolved dynamically from local files at tab-completion time.

**Tech Stack:** Fish shell, Python (uv) for codegen, GitHub Actions for CI/CD

**Spec:** `docs/superpowers/specs/2026-03-14-fish-claude-completions-design.md`

---

> **Note on testing:** Fish shell completions have no unit test framework. Each task includes manual verification steps using `complete -C` (which prints completions without interactive tab) or by sourcing the file and testing in a live shell. The pattern is: write code, source it, verify with `complete -C`.

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `completions/claude.fish` | Create | All completions + inline helper functions |
| `scripts/generate-config-keys.py` | Create | Fetch SchemaStore JSON, patch config key completions |
| `.github/workflows/update-config-keys.yml` | Create | Weekly scheduled workflow to run codegen |
| `README.md` | Create | Installation instructions for Fisher |
| `LICENSE` | Create | MIT license |
| `CHANGELOG.md` | Modify | Add entries for new files |

---

## Chunk 1: Scaffolding and Helper Functions

### Task 1: Project scaffolding (LICENSE, README)

**Files:**
- Create: `LICENSE`
- Create: `README.md`

- [ ] **Step 1: Create MIT LICENSE**

```
MIT License

Copyright (c) 2026 Infinite Room Labs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Create README.md**

```markdown
# fish-claude-completions

Tab completions for the [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI in [Fish shell](https://fishshell.com/).

## Features

- Complete all flags, subcommands, and sub-subcommands
- Dynamic MCP server name completions (from local config files)
- Dynamic session ID completions for `--resume` (scoped to current project)
- Config key completions for `config set/get` (generated from official JSON schema)
- Full subcommand trees for `mcp`, `auth`, `plugin`, `config`, and `install`

## Installation

Using [Fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install InfiniteRoomLabs/fish-claude-completions
```

## How It Works

### Static completions

All CLI flags and subcommand trees are defined statically. Config key names
are hardcoded but regenerated weekly from the
[official JSON schema](https://json.schemastore.org/claude-code-settings.json)
via CI/CD.

### Dynamic completions

- **MCP servers** (`claude mcp remove <tab>`): Reads server names from
  `~/.claude/settings.local.json` and `.mcp.json` in the current directory.
  Falls back to parsing `claude mcp list` output.
- **Sessions** (`claude --resume <tab>`): Lists session IDs from
  `~/.claude/projects/` scoped to the current working directory, sorted by
  most recently modified.

## Requirements

- [Fish shell](https://fishshell.com/) 3.0+
- [Fisher](https://github.com/jorgebucaran/fisher)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- Python 3 (for dynamic MCP server name completions from JSON config files)

## Credits

Based on the community completion script by
[r4ai](https://gist.github.com/r4ai/d3cb3360cd38b1ea0f28228b9473db0c),
extended with dynamic completions and full subcommand coverage.

## License

MIT
```

- [ ] **Step 3: Commit scaffolding**

```bash
git add LICENSE README.md
git commit -m "Add LICENSE and README"
```

---

### Task 2: Helper functions and completion file skeleton

**Files:**
- Create: `completions/claude.fish`

This task creates the file with all four helper functions and the `complete -c claude -f` base. No completions yet -- just the function definitions and markers.

- [ ] **Step 1: Create `completions/claude.fish` with helper functions**

```fish
# Fish shell completions for the Claude Code CLI (claude)
# https://github.com/InfiniteRoomLabs/fish-claude-completions
#
# Provides tab completions for all flags, subcommands, and dynamic values
# including MCP server names and session IDs.

# Disable file completions by default for claude
complete -c claude -f

# =============================================================================
# Helper Functions
# =============================================================================

function __fish_claude_no_subcommand
    set -l cmd (commandline -opc)
    for i in (seq 2 (count $cmd))
        switch $cmd[$i]
            case config mcp auth plugin plugins agents doctor update upgrade install setup-token
                return 1
            case '-*'
                continue
            case '*'
                return 1
        end
    end
    return 0
end

function __fish_claude_mcp_servers
    set -l servers

    # Source 1: Parse ~/.claude/settings.local.json
    set -l settings_file "$HOME/.claude/settings.local.json"
    if test -f "$settings_file"
        set -a servers (python3 -c "
import json
try:
    with open('$settings_file') as f:
        data = json.load(f)
    for key in data.get('mcpServers', {}):
        print(key)
except: pass
" 2>/dev/null)
    end

    # Source 2: Parse .mcp.json in current directory
    if test -f .mcp.json
        set -a servers (python3 -c "
import json
try:
    with open('.mcp.json') as f:
        data = json.load(f)
    for key in data.get('mcpServers', {}):
        print(key)
except: pass
" 2>/dev/null)
    end

    # Source 3: Fallback to claude mcp list (slower, does health checks)
    if test (count $servers) -eq 0
        set -a servers (command claude mcp list 2>/dev/null | string match -rg '^(\S+):' | sort -u)
    end

    # Deduplicate and output
    printf '%s\n' $servers | sort -u
end

function __fish_claude_sessions
    # Derive project slug from PWD (same encoding Claude uses)
    set -l slug (string replace -a '/' '-' $PWD | string replace -r '^-' '')
    set -l sessions_dir "$HOME/.claude/projects/$slug"

    if not test -d "$sessions_dir"
        return
    end

    # List .jsonl files sorted by modification time (newest first)
    for file in (ls -t "$sessions_dir"/*.jsonl 2>/dev/null)
        set -l uuid (basename $file .jsonl)
        # Skip non-UUID filenames (like cship, memory, etc.)
        if not string match -qr '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' $uuid
            continue
        end

        # Calculate relative time from file modification time
        # NOTE: stat -c is GNU/Linux. On macOS, use stat -f %m instead.
        set -l mtime (stat -c %Y "$file" 2>/dev/null; or stat -f %m "$file" 2>/dev/null)
        if test -z "$mtime"
            echo "$uuid"
            continue
        end
        set -l now (date +%s)
        set -l diff (math $now - $mtime)

        # Declare desc before the conditional to avoid Fish block-scoping
        set -l desc ""
        if test $diff -lt 60
            set desc "just now"
        else if test $diff -lt 3600
            set -l mins (math "floor($diff / 60)")
            set desc "$mins""m ago"
        else if test $diff -lt 86400
            set -l hrs (math "floor($diff / 3600)")
            set desc "$hrs""h ago"
        else
            set -l days (math "floor($diff / 86400)")
            set desc "$days""d ago"
        end
        echo -e "$uuid\t($desc)"
    end
end
```

- [ ] **Step 2: Verify helper functions load without errors**

Run from within the project directory:
```bash
fish -c "source completions/claude.fish; __fish_claude_no_subcommand; echo \$status"
```
Expected: `0` (no subcommand on empty commandline)

```bash
fish -c "source completions/claude.fish; __fish_claude_mcp_servers"
```
Expected: list of configured MCP server names (or empty if none configured)

```bash
fish -c "source completions/claude.fish; __fish_claude_sessions"
```
Expected: list of session UUIDs with relative timestamps (or empty if no sessions for this directory)

- [ ] **Step 3: Commit helper functions**

```bash
git add completions/claude.fish
git commit -m "Add completion file skeleton with helper functions"
```

---

## Chunk 2: Top-Level Completions

### Task 3: Top-level flags and subcommand suggestions

**Files:**
- Modify: `completions/claude.fish`

Append all top-level flag completions and subcommand suggestions after the helper functions.

- [ ] **Step 1: Add subcommand suggestions**

Append to `completions/claude.fish`:

```fish
# =============================================================================
# Subcommands (when no subcommand present)
# =============================================================================

complete -c claude -n __fish_claude_no_subcommand -xa config -d "Manage configuration settings"
complete -c claude -n __fish_claude_no_subcommand -xa mcp -d "Configure and manage MCP servers"
complete -c claude -n __fish_claude_no_subcommand -xa auth -d "Manage authentication"
complete -c claude -n __fish_claude_no_subcommand -xa plugin -d "Manage Claude Code plugins"
complete -c claude -n __fish_claude_no_subcommand -xa plugins -d "Manage Claude Code plugins"
complete -c claude -n __fish_claude_no_subcommand -xa agents -d "List configured agents"
complete -c claude -n __fish_claude_no_subcommand -xa doctor -d "Check auto-updater health"
complete -c claude -n __fish_claude_no_subcommand -xa update -d "Check for updates and install"
complete -c claude -n __fish_claude_no_subcommand -xa upgrade -d "Check for updates and install"
complete -c claude -n __fish_claude_no_subcommand -xa install -d "Install Claude Code native build"
complete -c claude -n __fish_claude_no_subcommand -xa setup-token -d "Set up a long-lived auth token"
```

- [ ] **Step 2: Add simple toggle flags**

```fish
# =============================================================================
# Top-level flags (when no subcommand)
# =============================================================================

# Simple toggles
complete -c claude -n __fish_claude_no_subcommand -s c -l continue -d "Continue the most recent conversation"
complete -c claude -n __fish_claude_no_subcommand -s d -l debug -d "Enable debug mode (optional filter: api,hooks)"
complete -c claude -n __fish_claude_no_subcommand -l verbose -d "Override verbose mode setting from config"
complete -c claude -n __fish_claude_no_subcommand -s p -l print -d "Print response and exit (useful for pipes)"
complete -c claude -n __fish_claude_no_subcommand -s v -l version -d "Output the version number"
complete -c claude -n __fish_claude_no_subcommand -s h -l help -d "Display help for command"
complete -c claude -n __fish_claude_no_subcommand -l ide -d "Auto-connect to IDE on startup"
complete -c claude -n __fish_claude_no_subcommand -l chrome -d "Enable Claude in Chrome integration"
complete -c claude -n __fish_claude_no_subcommand -l no-chrome -d "Disable Claude in Chrome integration"
complete -c claude -n __fish_claude_no_subcommand -l brief -d "Enable SendUserMessage tool for agent-to-user communication"
complete -c claude -n __fish_claude_no_subcommand -l fork-session -d "Create new session ID when resuming"
complete -c claude -n __fish_claude_no_subcommand -l mcp-debug -d "[DEPRECATED] Enable MCP debug mode"
complete -c claude -n __fish_claude_no_subcommand -l dangerously-skip-permissions -d "Bypass all permission checks"
complete -c claude -n __fish_claude_no_subcommand -l allow-dangerously-skip-permissions -d "Enable permission bypass as an option"
complete -c claude -n __fish_claude_no_subcommand -l disable-slash-commands -d "Disable all skills"
complete -c claude -n __fish_claude_no_subcommand -l no-session-persistence -d "Disable session saving (--print only)"
complete -c claude -n __fish_claude_no_subcommand -l include-partial-messages -d "Include partial messages (--print + stream-json)"
complete -c claude -n __fish_claude_no_subcommand -l replay-user-messages -d "Re-emit user messages on stdout"
complete -c claude -n __fish_claude_no_subcommand -l strict-mcp-config -d "Only use MCP servers from --mcp-config"
```

- [ ] **Step 3: Add enumerated value flags**

```fish
# Enumerated value flags
complete -c claude -n __fish_claude_no_subcommand -l output-format -d "Output format (--print only)" -rxa "text json stream-json"
complete -c claude -n __fish_claude_no_subcommand -l input-format -d "Input format (--print only)" -rxa "text stream-json"
complete -c claude -n __fish_claude_no_subcommand -l effort -d "Effort level for the session" -rxa "low medium high max"
complete -c claude -n __fish_claude_no_subcommand -l permission-mode -d "Permission mode for the session" -rxa "acceptEdits bypassPermissions default dontAsk plan auto"
complete -c claude -n __fish_claude_no_subcommand -l model -d "Model for the current session" -rxa "sonnet opus haiku"
complete -c claude -n __fish_claude_no_subcommand -l fallback-model -d "Fallback model when default is overloaded" -rxa "sonnet opus haiku"
```

- [ ] **Step 4: Add dynamic value flags**

```fish
# Dynamic value flags
complete -c claude -n __fish_claude_no_subcommand -s r -l resume -d "Resume a conversation by session ID" -rxa "(__fish_claude_sessions)"
complete -c claude -n __fish_claude_no_subcommand -l mcp-config -d "Load MCP servers from JSON file" -rF
complete -c claude -n __fish_claude_no_subcommand -l add-dir -d "Additional directories for tool access" -rxa "(__fish_complete_directories)"
complete -c claude -n __fish_claude_no_subcommand -l debug-file -d "Write debug logs to file" -rF
complete -c claude -n __fish_claude_no_subcommand -l plugin-dir -d "Load plugins from directory" -rxa "(__fish_complete_directories)"
complete -c claude -n __fish_claude_no_subcommand -l settings -d "Path to settings JSON file" -rF
```

- [ ] **Step 5: Add freeform value flags**

```fish
# Freeform value flags (require a value but no specific suggestions)
complete -c claude -n __fish_claude_no_subcommand -l system-prompt -d "System prompt for the session" -rx
complete -c claude -n __fish_claude_no_subcommand -l append-system-prompt -d "Append to default system prompt" -rx
complete -c claude -n __fish_claude_no_subcommand -l allowedTools -l allowed-tools -d "Tool names to allow" -rx
complete -c claude -n __fish_claude_no_subcommand -l disallowedTools -l disallowed-tools -d "Tool names to deny" -rx
complete -c claude -n __fish_claude_no_subcommand -l json-schema -d "JSON Schema for structured output" -rx
complete -c claude -n __fish_claude_no_subcommand -l max-budget-usd -d "Maximum dollar amount for API calls" -rx
complete -c claude -n __fish_claude_no_subcommand -l session-id -d "Use a specific session UUID" -rx
complete -c claude -n __fish_claude_no_subcommand -s n -l name -d "Display name for this session" -rx
complete -c claude -n __fish_claude_no_subcommand -l agents -d "JSON object defining custom agents" -rx
complete -c claude -n __fish_claude_no_subcommand -l betas -d "Beta headers for API requests" -rx
complete -c claude -n __fish_claude_no_subcommand -l tools -d "List of available tools" -rx
complete -c claude -n __fish_claude_no_subcommand -l setting-sources -d "Comma-separated setting sources" -rx
complete -c claude -n __fish_claude_no_subcommand -l file -d "File resources (file_id:relative_path)" -rx
complete -c claude -n __fish_claude_no_subcommand -l agent -d "Agent for the current session" -rx
complete -c claude -n __fish_claude_no_subcommand -s w -l worktree -d "Create a new git worktree for this session"
complete -c claude -n __fish_claude_no_subcommand -l from-pr -d "Resume session linked to a PR"
complete -c claude -n __fish_claude_no_subcommand -l tmux -d "Create a tmux session for the worktree"
```

- [ ] **Step 6: Verify top-level completions work**

```bash
fish -c "source completions/claude.fish; complete -C 'claude '" | head -20
```
Expected: shows subcommands (config, mcp, auth, plugin, etc.) and flags

```bash
fish -c "source completions/claude.fish; complete -C 'claude --effort '"
```
Expected: `low`, `medium`, `high`, `max`

```bash
fish -c "source completions/claude.fish; complete -C 'claude --permission-mode '"
```
Expected: `acceptEdits`, `bypassPermissions`, `default`, `dontAsk`, `plan`, `auto`

- [ ] **Step 7: Commit top-level completions**

```bash
git add completions/claude.fish
git commit -m "Add top-level flag and subcommand completions"
```

---

## Chunk 3: Subcommand Trees

### Task 4: `config` subcommand completions

**Files:**
- Modify: `completions/claude.fish`

- [ ] **Step 1: Add `config` subcommand tree**

Append to `completions/claude.fish`:

```fish
# =============================================================================
# config subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from set get list reset" -xa set -d "Set a config value"
complete -c claude -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from set get list reset" -xa get -d "Get a config value"
complete -c claude -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from set get list reset" -xa list -d "List all config values"
complete -c claude -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from set get list reset" -xa reset -d "Reset config to defaults"
complete -c claude -n "__fish_seen_subcommand_from config" -s h -l help -d "Display help for command"

# config set / config get flags
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -s g -l global -d "Set/get global configuration"

# Config key completions (generated by scripts/generate-config-keys.py)
# BEGIN GENERATED CONFIG KEYS
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa apiKeyHelper -d "Path to auth script"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa autoMemoryEnabled -d "Enable automatic memory saves"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa autoUpdatesChannel -d "Release channel (stable/latest)"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa awsCredentialExport -d "Path to AWS credential export script"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa awsAuthRefresh -d "Path to AWS auth refresh script"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa cleanupPeriodDays -d "Days to retain chat transcripts"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa env -d "Environment variables for sessions"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa attribution -d "Git commit/PR attribution settings"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa includeGitInstructions -d "Include git workflow instructions"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa includeCoAuthoredBy -d "[DEPRECATED] Use attribution instead"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa plansDirectory -d "Where plan files are stored"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa respectGitignore -d "File picker respects .gitignore"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa permissions -d "Tool usage permissions"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa language -d "Preferred response language"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa model -d "Default model"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa availableModels -d "Restrict selectable models"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa effortLevel -d "Adaptive reasoning effort"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa fastMode -d "Enable fast mode"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa fastModePerSessionOptIn -d "Require per-session fast mode opt-in"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa enableAllProjectMcpServers -d "Auto-approve project MCP servers"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa enabledMcpjsonServers -d "Approved .mcp.json servers"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa disabledMcpjsonServers -d "Rejected .mcp.json servers"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa allowedMcpServers -d "Enterprise MCP server allowlist"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa deniedMcpServers -d "Enterprise MCP server denylist"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa hooks -d "Custom commands for tool executions"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa disableAllHooks -d "Disable all hooks and statusLine"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa allowManagedHooksOnly -d "Only allow managed hooks"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa allowManagedPermissionRulesOnly -d "Only managed permission rules"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa statusLine -d "Custom status line display"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa fileSuggestion -d "Custom @ file autocomplete"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa enabledPlugins -d "Enabled plugins"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa extraKnownMarketplaces -d "Additional plugin marketplaces"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa strictKnownMarketplaces -d "Managed marketplace allowlist"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa skippedMarketplaces -d "Skipped marketplaces"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa skippedPlugins -d "Skipped plugin IDs"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa forceLoginMethod -d "Force login method"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa forceLoginOrgUUID -d "Organization UUID for OAuth"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa otelHeadersHelper -d "OpenTelemetry headers script"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa outputStyle -d "Response style"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa skipWebFetchPreflight -d "Skip WebFetch blocklist check"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa sandbox -d "Sandbox execution configuration"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa spinnerVerbs -d "Customize spinner verbs"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa spinnerTipsEnabled -d "Show tips in spinner"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa spinnerTipsOverride -d "Customize spinner tips"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa terminalProgressBarEnabled -d "Enable terminal progress bar"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa showTurnDuration -d "Show turn duration after responses"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa prefersReducedMotion -d "Reduce UI animations"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa alwaysThinkingEnabled -d "Enable extended thinking by default"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa companyAnnouncements -d "Startup announcements"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa teammateMode -d "Agent team display mode"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa pluginTrustMessage -d "Custom plugin trust warning"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa pluginConfigs -d "Per-plugin configuration"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa allowManagedMcpServersOnly -d "Only managed MCP servers"
complete -c claude -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get" -xa blockedMarketplaces -d "Blocked marketplace sources"
# END GENERATED CONFIG KEYS
```

- [ ] **Step 2: Verify config completions**

```bash
fish -c "source completions/claude.fish; complete -C 'claude config '"
```
Expected: `set`, `get`, `list`, `reset`

```bash
fish -c "source completions/claude.fish; complete -C 'claude config set '"
```
Expected: list of config key names (apiKeyHelper, autoMemoryEnabled, etc.)

- [ ] **Step 3: Commit config completions**

```bash
git add completions/claude.fish
git commit -m "Add config subcommand completions with generated keys"
```

---

### Task 5: `mcp` subcommand completions

**Files:**
- Modify: `completions/claude.fish`

- [ ] **Step 1: Add `mcp` subcommand tree**

Append to `completions/claude.fish`:

```fish
# =============================================================================
# mcp subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa list -d "List configured MCP servers"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa add -d "Add an MCP server"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa add-json -d "Add MCP server with JSON string"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa add-from-claude-desktop -d "Import MCP servers from Claude Desktop"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa remove -d "Remove an MCP server"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa get -d "Get details about an MCP server"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa serve -d "Start the Claude Code MCP server"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa reset-project-choices -d "Reset approved/rejected project MCP servers"
complete -c claude -n "__fish_seen_subcommand_from mcp" -s h -l help -d "Display help for command"

# mcp add flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s t -l transport -d "Transport type" -rxa "stdio sse http"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s e -l env -d "Set environment variables" -rx
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s H -l header -d "Set HTTP headers" -rx
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -l callback-port -d "Fixed port for OAuth callback" -rx
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -l client-id -d "OAuth client ID" -rx
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -l client-secret -d "Prompt for OAuth client secret"

# mcp add-json flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add-json" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add-json" -l client-secret -d "Prompt for OAuth client secret"

# mcp add-from-claude-desktop flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add-from-claude-desktop" -s s -l scope -d "Configuration scope" -rxa "local user project"

# mcp remove: dynamic server names + scope
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from remove" -xa "(__fish_claude_mcp_servers)"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from remove" -s s -l scope -d "Configuration scope" -rxa "local user project"

# mcp get: dynamic server names
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from get" -xa "(__fish_claude_mcp_servers)"

# mcp serve flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from serve" -s d -l debug -d "Enable debug mode"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from serve" -l verbose -d "Override verbose mode"
```

- [ ] **Step 2: Verify mcp completions**

```bash
fish -c "source completions/claude.fish; complete -C 'claude mcp '"
```
Expected: `list`, `add`, `add-json`, `add-from-claude-desktop`, `remove`, `get`, `serve`, `reset-project-choices`

```bash
fish -c "source completions/claude.fish; complete -C 'claude mcp add --transport '"
```
Expected: `stdio`, `sse`, `http`

```bash
fish -c "source completions/claude.fish; complete -C 'claude mcp remove '"
```
Expected: configured MCP server names

- [ ] **Step 3: Commit mcp completions**

```bash
git add completions/claude.fish
git commit -m "Add mcp subcommand completions with dynamic server names"
```

---

### Task 6: `auth`, `plugin`, `install`, and simple subcommand completions

**Files:**
- Modify: `completions/claude.fish`

- [ ] **Step 1: Add `auth` subcommand tree**

```fish
# =============================================================================
# auth subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout status" -xa login -d "Sign in to your Anthropic account"
complete -c claude -n "__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout status" -xa logout -d "Log out from your Anthropic account"
complete -c claude -n "__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout status" -xa status -d "Show authentication status"
complete -c claude -n "__fish_seen_subcommand_from auth" -s h -l help -d "Display help for command"

# auth login flags
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from login" -l email -d "Email address for login" -rx
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from login" -l sso -d "Use SSO authentication"

# auth status flags
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from status" -l json -d "Output as JSON"
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from status" -l text -d "Output as text"
```

- [ ] **Step 2: Add `plugin` subcommand tree**

```fish
# =============================================================================
# plugin subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install uninstall remove list enable disable update validate marketplace" -xa install -d "Install a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install uninstall remove list enable disable update validate marketplace" -xa uninstall -d "Uninstall a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install uninstall remove list enable disable update validate marketplace" -xa remove -d "Uninstall a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install uninstall remove list enable disable update validate marketplace" -xa list -d "List installed plugins"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install uninstall remove list enable disable update validate marketplace" -xa enable -d "Enable a disabled plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install uninstall remove list enable disable update validate marketplace" -xa disable -d "Disable an enabled plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install uninstall remove list enable disable update validate marketplace" -xa update -d "Update a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install uninstall remove list enable disable update validate marketplace" -xa validate -d "Validate a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install uninstall remove list enable disable update validate marketplace" -xa marketplace -d "Manage plugin marketplaces"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins" -s h -l help -d "Display help for command"

# plugin install/uninstall/enable/disable/update: scope flag
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from install" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from uninstall remove" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from enable" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from disable" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from disable" -s a -l all -d "Disable all plugins"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from update" -s s -l scope -d "Configuration scope" -rxa "local user project managed"

# plugin list flags
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from list" -l available -d "Show available plugins"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from list" -l json -d "Output as JSON"

# plugin validate: path completion
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from validate" -rF

# plugin marketplace sub-subcommands
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa add -d "Add a marketplace"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa remove -d "Remove a marketplace"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa rm -d "Remove a marketplace"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa list -d "List marketplaces"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa update -d "Update marketplace(s)"

# plugin marketplace add flags
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from add" -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from add" -l sparse -d "Use sparse checkout"

# plugin marketplace list flags
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from list" -l json -d "Output as JSON"
```

- [ ] **Step 3: Add `install` and simple subcommand completions**

```fish
# =============================================================================
# install subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from install" -xa "stable latest" -d "Install target version"
complete -c claude -n "__fish_seen_subcommand_from install" -l force -d "Force installation"
complete -c claude -n "__fish_seen_subcommand_from install" -s h -l help -d "Display help for command"

# =============================================================================
# Simple subcommands (help only)
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from doctor" -s h -l help -d "Display help for command"
complete -c claude -n "__fish_seen_subcommand_from update upgrade" -s h -l help -d "Display help for command"
complete -c claude -n "__fish_seen_subcommand_from setup-token" -s h -l help -d "Display help for command"

# agents subcommand
complete -c claude -n "__fish_seen_subcommand_from agents" -l setting-sources -d "Setting sources to load" -rx
complete -c claude -n "__fish_seen_subcommand_from agents" -s h -l help -d "Display help for command"
```

- [ ] **Step 4: Verify all subcommand completions**

```bash
fish -c "source completions/claude.fish; complete -C 'claude auth '"
```
Expected: `login`, `logout`, `status`

```bash
fish -c "source completions/claude.fish; complete -C 'claude plugin '"
```
Expected: `install`, `uninstall`, `remove`, `list`, `enable`, `disable`, `update`, `validate`, `marketplace`

```bash
fish -c "source completions/claude.fish; complete -C 'claude plugin marketplace '"
```
Expected: `add`, `remove`, `rm`, `list`, `update`

```bash
fish -c "source completions/claude.fish; complete -C 'claude install '"
```
Expected: `stable`, `latest`

- [ ] **Step 5: Commit remaining subcommand completions**

```bash
git add completions/claude.fish
git commit -m "Add auth, plugin, install, and simple subcommand completions"
```

---

## Chunk 4: CI/CD and Final Polish

### Task 7: Config key generation script

**Files:**
- Create: `scripts/generate-config-keys.py`

- [ ] **Step 1: Create `scripts/generate-config-keys.py`**

```python
#!/usr/bin/env python3
"""Fetch Claude Code settings schema from SchemaStore and update config key completions.

Usage:
    uv run scripts/generate-config-keys.py

Fetches the official JSON schema from json.schemastore.org, extracts all top-level
property names and descriptions, and patches completions/claude.fish between the
BEGIN/END GENERATED CONFIG KEYS markers.
"""

import json
import re
import sys
import urllib.request
from pathlib import Path

SCHEMA_URL = "https://json.schemastore.org/claude-code-settings.json"
COMPLETIONS_FILE = Path(__file__).parent.parent / "completions" / "claude.fish"
BEGIN_MARKER = "# BEGIN GENERATED CONFIG KEYS"
END_MARKER = "# END GENERATED CONFIG KEYS"

CONDITION = '__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get'


def fetch_schema() -> dict:
    """Fetch the JSON schema from SchemaStore, following redirects."""
    req = urllib.request.Request(SCHEMA_URL, headers={"User-Agent": "fish-claude-completions/1.0"})
    with urllib.request.urlopen(req) as resp:
        # Handle redirect (301 -> schemastore.org)
        return json.loads(resp.read().decode())


def extract_properties(schema: dict) -> list[tuple[str, str]]:
    """Extract (property_name, description) pairs from schema properties."""
    props = schema.get("properties", {})
    result = []
    for name, definition in sorted(props.items()):
        if name == "$schema":
            continue
        desc = definition.get("description", "")
        # Truncate long descriptions for fish completion display
        if len(desc) > 60:
            desc = desc[:57] + "..."
        # Escape any double quotes in descriptions
        desc = desc.replace('"', '\\"')
        result.append((name, desc))
    return result


def generate_completions(properties: list[tuple[str, str]]) -> str:
    """Generate fish completion lines for config keys."""
    lines = [BEGIN_MARKER]
    for name, desc in properties:
        line = f'complete -c claude -n "{CONDITION}" -xa {name}'
        if desc:
            line += f' -d "{desc}"'
        lines.append(line)
    lines.append(END_MARKER)
    return "\n".join(lines)


def patch_file(completions_text: str, generated_block: str) -> str:
    """Replace content between BEGIN/END markers with generated block."""
    pattern = re.compile(
        rf"^{re.escape(BEGIN_MARKER)}$.*?^{re.escape(END_MARKER)}$",
        re.MULTILINE | re.DOTALL,
    )
    if not pattern.search(completions_text):
        print(f"ERROR: Could not find {BEGIN_MARKER} / {END_MARKER} markers in completions file", file=sys.stderr)
        sys.exit(1)
    return pattern.sub(generated_block, completions_text)


def main() -> None:
    print(f"Fetching schema from {SCHEMA_URL}...")
    schema = fetch_schema()

    properties = extract_properties(schema)
    print(f"Found {len(properties)} config properties")

    generated = generate_completions(properties)

    completions_text = COMPLETIONS_FILE.read_text()
    patched = patch_file(completions_text, generated)

    if patched == completions_text:
        print("No changes needed -- completions are up to date")
        sys.exit(0)

    COMPLETIONS_FILE.write_text(patched)
    print(f"Updated {COMPLETIONS_FILE} with {len(properties)} config keys")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the script to verify it works**

```bash
uv run scripts/generate-config-keys.py
```
Expected: `Found N config properties` and `Updated completions/claude.fish with N config keys` (or "No changes needed" if already current)

- [ ] **Step 3: Verify the patched file still loads**

```bash
fish -c "source completions/claude.fish; complete -C 'claude config set '" | head -10
```
Expected: config key names

- [ ] **Step 4: Commit the generation script**

```bash
git add scripts/generate-config-keys.py
git commit -m "Add config key generation script from SchemaStore"
```

If the script updated `completions/claude.fish`, also stage and commit that:

```bash
git add completions/claude.fish
git commit -m "Update config keys from SchemaStore schema"
```

---

### Task 8: GitHub Actions workflow

**Files:**
- Create: `.github/workflows/update-config-keys.yml`

- [ ] **Step 1: Create the workflow file**

```yaml
name: Update Config Keys

on:
  schedule:
    # Weekly on Monday at 06:00 UTC
    - cron: '0 6 * * 1'
  workflow_dispatch: {}

permissions:
  contents: write
  pull-requests: write

jobs:
  update-config-keys:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v5

      - name: Run config key generator
        run: uv run scripts/generate-config-keys.py

      - name: Check for changes
        id: changes
        run: |
          if git diff --quiet completions/claude.fish; then
            echo "changed=false" >> "$GITHUB_OUTPUT"
          else
            echo "changed=true" >> "$GITHUB_OUTPUT"
          fi

      - name: Create Pull Request
        if: steps.changes.outputs.changed == 'true'
        uses: peter-evans/create-pull-request@v7
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "chore: update config keys from SchemaStore"
          title: "chore: update config key completions"
          body: |
            Automated update of `config set/get` key completions from the
            [official Claude Code settings schema](https://json.schemastore.org/claude-code-settings.json).

            Generated by `scripts/generate-config-keys.py`.
          branch: chore/update-config-keys
          delete-branch: true
```

- [ ] **Step 2: Commit the workflow**

```bash
git add .github/workflows/update-config-keys.yml
git commit -m "Add GitHub Actions workflow for weekly config key updates"
```

---

### Task 9: Final changelog update and verification

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update CHANGELOG.md**

Replace the `[Unreleased]` section content with (supersedes spec-only entries now that implementation is complete):

```markdown
## [Unreleased]

### Added

- Tab completions for all `claude` CLI flags and subcommands
- Dynamic MCP server name completions from local config files
- Dynamic session ID completions for `--resume` scoped to current project
- Config key completions for `config set/get` generated from official JSON schema
- Full subcommand trees for `mcp`, `auth`, `plugin`, `config`, and `install`
- `scripts/generate-config-keys.py` for CI/CD config key generation from SchemaStore
- GitHub Actions workflow for weekly automated config key updates
- README with installation instructions
- MIT LICENSE
```

- [ ] **Step 2: Full manual verification**

Run all verification commands from the spec's Testing section:

```bash
fish -c "source completions/claude.fish; complete -C 'claude '"
```
Expected: shows subcommands and flags

```bash
fish -c "source completions/claude.fish; complete -C 'claude --effort '"
```
Expected: `low medium high max`

```bash
fish -c "source completions/claude.fish; complete -C 'claude mcp remove '"
```
Expected: configured MCP server names

```bash
fish -c "source completions/claude.fish; complete -C 'claude --resume '"
```
Expected: project-scoped session IDs with relative timestamps

```bash
fish -c "source completions/claude.fish; complete -C 'claude config set '"
```
Expected: config key names

```bash
fish -c "source completions/claude.fish; complete -C 'claude plugin marketplace '"
```
Expected: `add remove rm list update`

- [ ] **Step 3: Commit final changelog**

```bash
git add CHANGELOG.md
git commit -m "Update changelog for initial release"
```
