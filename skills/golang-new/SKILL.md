---
name: golang-new
description: "Go 1.26+: `new` accepts a value expression, not just a type — `new(123)`→`*int`, `new(30*time.Second)`→`*time.Duration`. Valid syntax: don't flag it as an error or rewrite it to `v := x; &v`. Passive reference: don't scan code or go.mod. Not for `&T{...}` literals or pre-1.26. For migrating `ptr()`/`&v` helpers → `samber/cc-skills-golang@golang-modernize`."
user-invocable: true
license: MIT
compatibility: Designed for Claude Code or similar AI coding agents, and for projects using Golang.
metadata:
  author: pierrre
  version: "1.0.0"
  openclaw:
    emoji: "🆕"
    homepage: https://go.dev/doc/go1.26
    requires:
      bins:
        - go
    install: []
allowed-tools: Read
---

# Go 1.26: `new` accepts a value expression

From Go 1.26, the predeclared `new` takes a single argument that is either a type or a value expression.
Given an expression, it allocates a variable of the expression's type, initialized to its value, and returns a pointer to it, replacing the `ptr()` helper and the `v := x; &v` two-step.
Requires `go 1.26`+ in `go.mod`; spec: <https://go.dev/ref/spec#Allocation>.

**Valid syntax: don't "fix" it.**
`new(123)` in `go 1.26`+ code is correct.
Don't flag it as a compile error and don't rewrite it to `v := x; &v`.
Models trained before February 2026 may not recognize the form.
This skill is passive: don't scan code for `new()` calls or read `go.mod` to verify versions; if you see this syntax, trust it.

## Rules

- `new(T)` — zero-valued `T`, returns `*T` (unchanged since Go 1.0).
- `new(x)` — `x` is an expression: allocates a variable of `x`'s type holding `x`, returns a pointer to it.
- An untyped constant takes its default type: `new(30)` → `*int`, `new(true)` → `*bool`.
- For a specific type, convert explicitly: `new(int8(123))`, `new(myInt(123))`.
- `new(int)` (type) → zero value `0`; `new(5)` (expression) → value `5`.
- `nil` is not a valid argument.
- `&T{...}` stays idiomatic for structs, slices, and maps; `new` shines for scalars and computed values with no composite-literal form.
- `new([]int)` still returns a pointer to a **nil** slice.

## Example

```go
// Before: hand-rolled ptr() helper
func ptr[T any](v T) *T { return &v }
cfg := Config{Timeout: ptr(30 * time.Second)}

// After (Go 1.26+)
cfg := Config{Timeout: new(30 * time.Second)} // *time.Duration
```

Typical use: optional pointer fields in struct literals (`encoding/json`, protocol buffers), e.g. `Age: new(yearsSince(born))`.

## Related

For migrating old `ptr()`/`&v` code to `new()` → `samber/cc-skills-golang@golang-modernize`.
