function _claude_agent_fzf_preview --description "Preview agent details for claude --agent fzf completion"
    set -l agent_name (string split \t -- $argv[1])[1]
    if test -z "$agent_name"
        return
    end

    # User agents: ~/.claude/agents/<name>.md
    set -l user_file "$HOME/.claude/agents/$agent_name.md"
    if test -f "$user_file"
        head -50 "$user_file"
        return
    end

    # Plugin agents: name is plugin:path:to:agent
    set -l plugins_file "$HOME/.claude/plugins/installed_plugins.json"
    if test -f "$plugins_file"
        python3 -c "
import json, os, sys
name = sys.argv[1]
data = json.load(open(sys.argv[2]))
for key, entries in data.get('plugins', {}).items():
    plugin_name = key.split('@')[0]
    if not name.startswith(plugin_name + ':'):
        continue
    rel = name[len(plugin_name)+1:].replace(':', os.sep) + '.md'
    for entry in entries:
        fpath = os.path.join(entry.get('installPath', ''), 'agents', rel)
        if os.path.exists(fpath):
            print(open(fpath).read(3000))
            sys.exit(0)
" "$agent_name" "$plugins_file" 2>/dev/null
    end
end
