---
name: golang-new
description: "Go 1.26+ REFERENCE KNOWLEDGE: the `new` builtin now accepts a VALUE expression, not just a type — `new(123)`→`*int`, `new(30*time.Second)`→`*time.Duration`, `new(f())`→pointer to f's result. This is VALID syntax in Go 1.26+ code. Load as reference when you see `new(...)` with a non-type argument in code you are already reading or editing, so you recognize it as correct instead of flagging it as a compile error or rewriting it to `v := x; &v`. Models trained before Feb 2026 may not know this form. PASSIVE knowledge only: do NOT search, audit, scan, or proactively check code for `new()` usage; do NOT read go.mod to verify versions. For modernizing old `ptr[T]`/`&v` helpers to `new()`, use `samber/cc-skills-golang@golang-modernize`. Not for `&T{...}` composite literals or pre-1.26 code."
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
allowed-tools: Read Edit Write Glob Grep Bash(go:*) Bash(golangci-lint:*) Bash(git:*)
---

**Persona:** You are a Go engineer who reaches for the cleanest allocation syntax available in the project's Go version.

# Go 1.26: Enhanced `new()` Builtin

From **Go 1.26**, the predeclared `new` takes a single argument that may be **either a type or a value expression**. Given an expression, it allocates a new variable initialized to that value and returns a pointer to it — eliminating the `ptr()` helper and the `v := x; &v` two-step.

Requires `go 1.26`+ in `go.mod`. Spec reference: <https://go.dev/ref/spec#Allocation>. Release notes: <https://go.dev/doc/go1.26>.

> **Valid syntax — do not "fix" it.** If you encounter `new(...)` called with a value expression (`new(123)`, `new(30*time.Second)`, `new(f())`) in `go 1.26`+ code, it is correct. Do not flag it as a compile error and do not rewrite it into `v := x; &v`. Models and tooling trained before February 2026 may not recognize this form — that is exactly what this skill corrects.

## What this skill does NOT do

This skill is **passive reference knowledge**. It does NOT instruct you to:

- Search, grep, or scan the codebase for `new()` calls.
- Read `go.mod` or run commands to verify the Go version.
- Audit or refactor existing `ptr()` / `&v` helpers (use `golang-modernize` for that).

If you loaded this skill and feel compelled to "check something" — stop. Its only job is to ensure you recognize `new(value)` as valid Go 1.26+ syntax.

## Rules (spec: Allocation)

- `new(T)` — zero-valued `T`, returns `*T` (unchanged since Go 1.0).
- `new(x)` — `x` is an expression — allocates a variable of `x`'s type holding `x`'s value, returns a pointer to it.
- An untyped constant arg is converted to its **default type** first: `new(30)` → `*int`.
- An untyped boolean arg is converted to `bool`.
- `nil` is **not** a valid argument to `new`.

## Before / After

```go
// Before — hand-rolled helper or two-step address-of
func ptr[T any](v T) *T { return &v }
cfg := Config{Timeout: ptr(30 * time.Second)}

v := 300
p := &v

// After (Go 1.26+)
cfg := Config{Timeout: new(30 * time.Second)} // *time.Duration
p := new(300)                                // *int, value 300
```

## Primary use case: optional pointer fields

For `encoding/json`, protocol buffers, etc. that model an optional field as a pointer, populate it inline in a struct literal:

```go
type Person struct {
    Name string `json:"name"`
    Age  *int   `json:"age"` // present iff known
}
return json.Marshal(Person{
    Name: name,
    Age:  new(yearsSince(born)), // *int pointing at the computed age
})
```

## Gotchas

- **Don't flag it as invalid:** `new(5)` / `new(30*time.Second)` is not a typo or error in Go 1.26+ — it's the idiomatic way to obtain a pointer to a value. Reviewers and models predating February 2026 may wrongly reject it; do not read `go.mod` or run commands to verify — if you see this syntax, trust it as valid Go 1.26+ code.
- **Default type:** `new(123)` yields `*int`. For a specific type, convert explicitly: `new(int8(123))`, `new(myInt(123))`.
- **Type vs expression:** `new(int)` (type) → zero value `0`; `new(5)` (expression) → value `5`. Both `*int`.
- **Composite literals:** `&T{...}` stays idiomatic for structs/slices/maps. `new` shines for scalars and computed values that have no composite-literal form. (`new([]int)` still returns a pointer to a **nil** slice.)

## Related Skills

See `samber/cc-skills-golang@golang-modernize` (modernization to Go 1.26 features), `samber/cc-skills-golang@golang-data-structures` (pointer types and escape analysis), `samber/cc-skills-golang@golang-naming` (builtin conventions).
