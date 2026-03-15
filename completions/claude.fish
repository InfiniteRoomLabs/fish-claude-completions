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

# Enumerated value flags
complete -c claude -n __fish_claude_no_subcommand -l output-format -d "Output format (--print only)" -rxa "text json stream-json"
complete -c claude -n __fish_claude_no_subcommand -l input-format -d "Input format (--print only)" -rxa "text stream-json"
complete -c claude -n __fish_claude_no_subcommand -l effort -d "Effort level for the session" -rxa "low medium high max"
complete -c claude -n __fish_claude_no_subcommand -l permission-mode -d "Permission mode for the session" -rxa "acceptEdits bypassPermissions default dontAsk plan auto"
complete -c claude -n __fish_claude_no_subcommand -l model -d "Model for the current session" -rxa "sonnet opus haiku"
complete -c claude -n __fish_claude_no_subcommand -l fallback-model -d "Fallback model when default is overloaded" -rxa "sonnet opus haiku"

# Dynamic value flags
complete -c claude -n __fish_claude_no_subcommand -s r -l resume -d "Resume a conversation by session ID" -rxa "(__fish_claude_sessions)"
complete -c claude -n __fish_claude_no_subcommand -l mcp-config -d "Load MCP servers from JSON file" -rF
complete -c claude -n __fish_claude_no_subcommand -l add-dir -d "Additional directories for tool access" -rxa "(__fish_complete_directories)"
complete -c claude -n __fish_claude_no_subcommand -l debug-file -d "Write debug logs to file" -rF
complete -c claude -n __fish_claude_no_subcommand -l plugin-dir -d "Load plugins from directory" -rxa "(__fish_complete_directories)"
complete -c claude -n __fish_claude_no_subcommand -l settings -d "Path to settings JSON file" -rF

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
