---
name: golang-gopls-cli
description: "Golang identifier search via the gopls CLI — load FIRST whenever you need to find where a Go identifier (function, type, method, variable, constant, field, interface) is used, called, defined, declared, referenced, or implemented. ALWAYS use instead of grep/rg/find for Go identifiers: gopls is semantic and never returns false positives from comments, strings, or same-named symbols in other packages. Use when the user asks to find usages, call sites, references, definitions, or implementations of a Go identifier, or when you are about to run grep/rg/find on .go files to locate a symbol. Not for non-Go files, general text search, or file discovery by glob pattern. For the MCP server or native LSP tool → See `samber/cc-skills-golang@golang-gopls`."
user-invocable: false
license: MIT
compatibility: Designed for Claude Code or similar AI coding agents, and for projects using Golang. Requires the gopls binary.
metadata:
  author: pierrre
  version: "1.0.0"
  openclaw:
    emoji: "🔍"
    requires:
      bins:
        - go
        - gopls
    install:
      - kind: go
        package: golang.org/x/tools/gopls@latest
        bins: [gopls]
allowed-tools: Read Edit Write Glob Bash(go:*) Bash(golangci-lint:*) Bash(git:*) Bash(gopls:*)
---

## CRITICAL: Never use grep/rg/find for Go identifiers

**STOP.** If you are about to use `grep`, `rg`, `find`, or the `Grep` tool to locate a Go identifier in `.go` files, use `gopls` instead. gopls is semantic — it resolves the build graph, so it never returns false positives from comments, strings, or same-named symbols in other packages. grep does.

This rule has no exceptions. Even a "quick" grep for a Go symbol can return false positives or miss cross-package references. Always use `gopls` instead.

## `-remote=auto` is mandatory

Every command MUST run as `gopls -remote=auto <command>`. The flag spawns a background daemon that caches the workspace in memory and persists across invocations. First call loads the workspace (slow); subsequent calls are fast. Without it, each call re-parses the entire workspace from scratch.

## Primary workflow: name → position → query

You usually start with a name, not a position. Two steps:

1. `gopls -remote=auto workspace_symbol -matcher fuzzy Do` → returns the symbol's `file:line:col`
2. Feed that position to `references`, `definition`, `call_hierarchy`, etc.

## Command reference

| Task | Command | Example |
| --- | --- | --- |
| Where is X called? | `references` | `gopls -remote=auto references foo.go:10:5` |
| Where is X declared? | `definition` | `gopls -remote=auto definition -json foo.go:10:5` |
| Callers + callees of X | `call_hierarchy` | `gopls -remote=auto call_hierarchy foo.go:10:5` |
| Find symbol X in workspace | `workspace_symbol` | `gopls -remote=auto workspace_symbol -matcher fuzzy X` |
| Symbol outline of a file | `symbols` | `gopls -remote=auto symbols foo.go` |
| Interface ↔ concrete type | `implementation` | `gopls -remote=auto implementation foo.go:10:5` |
| Function signature at pos | `signature` | `gopls -remote=auto signature foo.go:10:5` |
| Occurrences in a file | `highlight` | `gopls -remote=auto highlight foo.go:10:5` |
| Diagnostics for a file | `check` | `gopls -remote=auto check foo.go` |
| Safe workspace rename | `rename` | `gopls -remote=auto rename -w foo.go:10:5 NewName` |

`-matcher` options: `fuzzy`, `fastfuzzy`, `casesensitive`, `caseinsensitive` (default).

## Position format

`file:line:col` (1-indexed) or `file:#offset` (0-indexed byte offset). Must land on an identifier, not whitespace or a comment.

## Gotchas

- `references` reflects only the queried file's build config (GOOS/build tags) — re-query under the right tags if cross-platform matches are missing.
- `call_hierarchy` is static only — calls through function values or interface methods are invisible; corroborate with `references`.

## `find`/glob stays for file discovery

`find`/glob remains correct for general file discovery ("list `*_test.go` under `pkg/`"). gopls only replaces it when the goal is locating a symbol — use `workspace_symbol` then.

**Install:** `go install golang.org/x/tools/gopls@latest`

For the MCP server or native LSP tool → See `samber/cc-skills-golang@golang-gopls`.
