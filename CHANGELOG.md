# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Design spec for fish-claude-completions Fisher plugin
- Implementation plan with 9 tasks across 4 chunks

### Changed

- Fix spec: remove non-existent `mcp enable`/`disable` and `migrate-installer` subcommands
- Fix spec: add missing flags (`-c`, `--fallback-model`, `--strict-mcp-config`) and short forms (`-r`, `-w`, `-n`)
- Fix spec: correct session metadata lookup strategy to use `.jsonl` mtime
- Fix spec: add all subcommand-level flags for mcp/auth/plugin trees
