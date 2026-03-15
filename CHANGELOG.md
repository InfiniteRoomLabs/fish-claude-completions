# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Design spec for fish-claude-completions Fisher plugin
- Implementation plan with 9 tasks across 4 chunks
- MIT LICENSE
- README with installation and usage instructions
- Fish shell completions for all `claude` CLI flags and subcommands
- Dynamic MCP server name completions from local config files
- Dynamic session ID completions for `--resume` scoped to current project
- Full subcommand trees for `mcp`, `auth`, `plugin`, and `install`

### Fixed

- Session slug derivation now keeps leading dash to match Claude Code's encoding

### Removed

- `config` subcommand completions (not a real CLI subcommand)
- Config key codegen script and GitHub Actions workflow

### Changed

- Fix spec: remove non-existent `mcp enable`/`disable` and `migrate-installer` subcommands
- Fix spec: add missing flags (`-c`, `--fallback-model`, `--strict-mcp-config`) and short forms (`-r`, `-w`, `-n`)
- Fix spec: correct session metadata lookup strategy to use `.jsonl` mtime
- Fix spec: add all subcommand-level flags for mcp/auth/plugin trees
