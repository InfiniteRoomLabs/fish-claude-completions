# fish-claude-completions

Tab completions for the [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI in [Fish shell](https://fishshell.com/).

## Features

- Complete all flags, subcommands, and sub-subcommands
- Dynamic MCP server name completions (from local config files)
- Dynamic session ID completions for `--resume` (scoped to current project)
- Full subcommand trees for `mcp`, `auth`, `plugin`, and `install`

## Installation

Using [Fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install InfiniteRoomLabs/fish-claude-completions
```

## How It Works

### Static completions

All CLI flags and subcommand trees are defined statically.

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
