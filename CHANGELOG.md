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
- Config key completions for `config set/get` from official JSON schema
- Full subcommand trees for `mcp`, `auth`, `plugin`, `config`, and `install`

### Changed

- Fix spec: remove non-existent `mcp enable`/`disable` and `migrate-installer` subcommands
- Fix spec: add missing flags (`-c`, `--fallback-model`, `--strict-mcp-config`) and short forms (`-r`, `-w`, `-n`)
- Fix spec: correct session metadata lookup strategy to use `.jsonl` mtime
- Fix spec: add all subcommand-level flags for mcp/auth/plugin trees
