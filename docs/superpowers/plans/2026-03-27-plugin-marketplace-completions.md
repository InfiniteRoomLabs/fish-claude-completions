# Plugin & Marketplace Dynamic Completions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dynamic tab completions for installed plugin names and registered marketplace names to the `claude plugin` subcommand tree.

**Architecture:** Two new helper functions (`__fish_claude_installed_plugins` and `__fish_claude_known_marketplaces`) in `completions/claude.fish` that parse JSON config files with `jq`. Six existing completion rules get wired to these helpers for positional argument completions.

**Tech Stack:** Fish shell, jq

---

### Task 1: Add `__fish_claude_installed_plugins` helper function

**Files:**
- Modify: `completions/claude.fish:12-27` (Helper Functions section, after `__fish_claude_no_subcommand`, before `__fish_claude_mcp_servers`)

- [ ] **Step 1: Write the function**

Add the following function after `__fish_claude_no_subcommand` (after line 27) and before `__fish_claude_mcp_servers` (currently line 29):

```fish
function __fish_claude_installed_plugins
    set -l plugins_file "$HOME/.claude/plugins/installed_plugins.json"
    if not test -f "$plugins_file"
        return
    end
    command jq -r '
        .plugins | to_entries[] |
        .key as $name |
        .value[] |
        $name + "\t" + .scope + ", " + (if .version == "unknown" then "unknown" else "v" + .version end)
    ' "$plugins_file" 2>/dev/null
end
```

- [ ] **Step 2: Verify output manually**

Run in a fish shell:

```bash
source completions/claude.fish && __fish_claude_installed_plugins
```

Expected: tab-separated lines like:

```
superpowers@claude-plugins-official	project, v5.0.6
agency@infinite-room-labs	user, unknown
frontend-design@claude-plugins-official	user, unknown
```

- [ ] **Step 3: Verify graceful fallback**

```bash
source completions/claude.fish && __fish_claude_installed_plugins /dev/null
```

Wait -- that won't work since the function reads a hardcoded path. Instead, temporarily rename the file and verify no output and no error:

```bash
mv ~/.claude/plugins/installed_plugins.json ~/.claude/plugins/installed_plugins.json.bak && source completions/claude.fish && __fish_claude_installed_plugins; mv ~/.claude/plugins/installed_plugins.json.bak ~/.claude/plugins/installed_plugins.json
```

Expected: no output, no errors (exit code 0 from the function, since `return` is reached).

- [ ] **Step 4: Commit**

```bash
git add completions/claude.fish
git commit -m "Add __fish_claude_installed_plugins helper function

Parses ~/.claude/plugins/installed_plugins.json with jq to provide
dynamic completions for installed plugin names with scope and version
metadata."
```

### Task 2: Add `__fish_claude_known_marketplaces` helper function

**Files:**
- Modify: `completions/claude.fish` (Helper Functions section, immediately after `__fish_claude_installed_plugins`)

- [ ] **Step 1: Write the function**

Add the following function immediately after `__fish_claude_installed_plugins` (from Task 1):

```fish
function __fish_claude_known_marketplaces
    set -l marketplaces_file "$HOME/.claude/plugins/known_marketplaces.json"
    if not test -f "$marketplaces_file"
        return
    end
    command jq -r '
        to_entries[] |
        .key + "\t" + .value.source.repo
    ' "$marketplaces_file" 2>/dev/null
end
```

- [ ] **Step 2: Verify output manually**

```bash
source completions/claude.fish && __fish_claude_known_marketplaces
```

Expected:

```
claude-plugins-official	anthropics/claude-plugins-official
cloudflare	cloudflare/skills
superpowers-marketplace	obra/superpowers-marketplace
infinite-room-labs	InfiniteRoomLabs/agent-ops
impeccable	pbakaus/impeccable
```

- [ ] **Step 3: Verify graceful fallback**

```bash
mv ~/.claude/plugins/known_marketplaces.json ~/.claude/plugins/known_marketplaces.json.bak && source completions/claude.fish && __fish_claude_known_marketplaces; mv ~/.claude/plugins/known_marketplaces.json.bak ~/.claude/plugins/known_marketplaces.json
```

Expected: no output, no errors.

- [ ] **Step 4: Commit**

```bash
git add completions/claude.fish
git commit -m "Add __fish_claude_known_marketplaces helper function

Parses ~/.claude/plugins/known_marketplaces.json with jq to provide
dynamic completions for registered marketplace names with GitHub repo
metadata."
```

### Task 3: Wire plugin completions to `__fish_claude_installed_plugins`

**Files:**
- Modify: `completions/claude.fish:357-363` (plugin scope flag section)

- [ ] **Step 1: Add positional completions for uninstall/remove**

Add the following line after line 359 (the existing `uninstall remove` scope flag):

```fish
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from uninstall remove" -xa "(__fish_claude_installed_plugins)"
```

- [ ] **Step 2: Add positional completions for enable**

Add the following line after line 360 (the existing `enable` scope flag):

```fish
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from enable" -xa "(__fish_claude_installed_plugins)"
```

- [ ] **Step 3: Add positional completions for disable**

Add the following line after line 362 (the existing `disable --all` flag):

```fish
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from disable" -xa "(__fish_claude_installed_plugins)"
```

- [ ] **Step 4: Add positional completions for update**

Add the following line after line 363 (the existing `update` scope flag):

```fish
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from update" -xa "(__fish_claude_installed_plugins)"
```

- [ ] **Step 5: Verify completions work end-to-end**

Source the file and test each subcommand:

```bash
source completions/claude.fish
complete -C "claude plugin uninstall " | head -5
complete -C "claude plugin enable " | head -5
complete -C "claude plugin disable " | head -5
complete -C "claude plugin update " | head -5
```

Expected: each should list installed plugins with their scope/version descriptions, alongside the existing `--scope` flag completions.

- [ ] **Step 6: Commit**

```bash
git add completions/claude.fish
git commit -m "Wire plugin uninstall/enable/disable/update to dynamic completions

Tab-completing after these subcommands now shows installed plugin names
with scope and version metadata from installed_plugins.json."
```

### Task 4: Wire marketplace completions to `__fish_claude_known_marketplaces`

**Files:**
- Modify: `completions/claude.fish:379-384` (plugin marketplace section)

- [ ] **Step 1: Add positional completions for marketplace remove/rm**

Add the following line after the marketplace `add` flags (after line 381, the `--sparse` flag) and before the marketplace `list` flags:

```fish
# plugin marketplace remove/rm: dynamic marketplace names
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from remove rm" -xa "(__fish_claude_known_marketplaces)"
```

- [ ] **Step 2: Add positional completions for marketplace update**

Add the following line immediately after the one from Step 1:

```fish
# plugin marketplace update: dynamic marketplace names
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from update" -xa "(__fish_claude_known_marketplaces)"
```

- [ ] **Step 3: Verify completions work end-to-end**

```bash
source completions/claude.fish
complete -C "claude plugin marketplace remove " | head -5
complete -C "claude plugin marketplace rm " | head -5
complete -C "claude plugin marketplace update " | head -5
```

Expected: each should list known marketplace names (e.g., `claude-plugins-official`, `infinite-room-labs`) with their GitHub repo descriptions.

- [ ] **Step 4: Commit**

```bash
git add completions/claude.fish
git commit -m "Wire marketplace remove/rm/update to dynamic completions

Tab-completing after these subcommands now shows registered marketplace
names with GitHub repo metadata from known_marketplaces.json."
```

### Task 5: Update README and CHANGELOG

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update README features section**

In `README.md`, find the features list and add a bullet for plugin/marketplace completions. Read the file first to find the exact location.

- [ ] **Step 2: Update CHANGELOG**

Add a new `## [Unreleased]` or version entry at the top of `CHANGELOG.md` documenting the addition:

```markdown
## [1.2.0] - 2026-03-27

### Added
- Dynamic completions for installed plugin names (`plugin uninstall/enable/disable/update`)
- Dynamic completions for registered marketplace names (`plugin marketplace remove/rm/update`)
- New helper functions: `__fish_claude_installed_plugins`, `__fish_claude_known_marketplaces`
```

Read the file first to match the existing format.

- [ ] **Step 3: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "Update README and CHANGELOG for plugin/marketplace completions"
```
