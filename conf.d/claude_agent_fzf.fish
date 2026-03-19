# Registers a fifc rule for `claude --agent` that enables fuzzy agent search.
# Requires: fifc (https://github.com/gazorby/fifc)
# Falls back gracefully to standard fish completions when fifc is absent.

if not status is-interactive
    exit
end

if not functions -q fifc
    exit
end

fifc \
    -r 'claude\h.*--agent\h' \
    -s '__fish_claude_agents' \
    -e '([^\t]+)' \
    -p '_claude_agent_fzf_preview $fifc_candidate' \
    -f '--no-exact --delimiter=\t --with-nth=1,2 --preview-window=right:50%:wrap'
