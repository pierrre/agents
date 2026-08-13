---
name: golang-review
description: "Golang code-review checklist — load FIRST whenever an agent reviews, checks, audits, or examines any Go code (a PR diff, a file, a function, or a pre-merge correctness pass). Use when the user asks to review, check, verify, look at, or audit Go code, when reading a Go diff to find bugs, or when debugging a Go panic. Verifies every access is provably safe: nil pointer dereferences, slice/array index bounds, map key existence, bare type assertions, integer division by zero, nil map writes, typed nil interface traps, and data races (unsynchronized concurrent access). This is the always-on correctness pass for panics and races — it triggers even when the review also covers style or design; defer to `samber/cc-skills-golang@golang-code-style` for style, `samber/cc-skills-golang@golang-safety` for design-time defensive-coding patterns, and `samber/cc-skills-golang@golang-concurrency` for deeper concurrency design."
user-invocable: true
license: MIT
compatibility: Designed for Claude Code or similar AI coding agents, and for projects using Golang.
metadata:
  author: pierrre
  version: "1.0.0"
  openclaw:
    emoji: "🔎"
    requires:
      bins:
        - go
    install: []
allowed-tools: Read Glob Grep Bash(go:*) Bash(golangci-lint:*) Bash(git:*)
---

**Persona:** You are a Go code reviewer who flags every unguarded access that can panic at runtime, and every unsynchronized concurrent access that races.

# Go Code Review: Panic-Prevention Checklist

When reviewing Go code (a diff, a file, or a function), verify each access below is **provably safe** — established by a preceding guard, a constructor/contract guarantee, or a caller-side invariant you can trace. Cite `file:line` and the rule number for each finding.

> Review the codebase, not just the diff. Trace callers and upstream validation before flagging — a function that looks unguarded in isolation may be safe in context. When context reduces but does not eliminate risk, report at lower priority and suggest an inline comment documenting the invariant.

> Not every nil access panics: `len(s)`, `cap(s)`, `range`, and `append` on nil slices, plus reads and `delete` on a nil map, are all safe — only **writes** to a nil map and index access past bounds panic. Don't flag the safe forms.

> **Scope: runtime data, not programmer misuse.** These checks target panics from unpredictable runtime data — a nil from a lookup, a missing key, an untrusted index, a runtime divisor. They do not cover caller contract violations — arguments that violate a documented precondition. There a panic is the correct signal: it points at the misuse, and soft-fail guards just hide the call site. Treat such guards as low-priority style noise, not correctness bugs.

> **Severity.** Report **blocking** for an unproven deref/index/divisor/race on a reachable path; **advisory** for silent-default map reads and provably-safe-but-fragile forms (uncommented contract assumptions, oversized shifts).

> **Prove every edge of a chain.** `cfg.tables[name].rows[i].owner.Name` is one deref but many hops; each hop needs its own proof — `cfg != nil`, `rows` non-nil, `i` in bounds, `owner` non-nil. Never dereference a `m[k]` or `s[i]` result without adding the §2/§3 proof first.

## 1. Nil pointer before dereference

Any dereference of a pointer `p` — `*p`, `p.Field`, or a method body touching `p` — requires proof that `p != nil`. Calling `p.Method()` on a nil `*T` receiver is itself legal in Go; the panic happens only when the method body dereferences `p` without a nil guard.

Acceptable proofs:
- A preceding `if p == nil { return ... }` (early return) or `if p != nil { ... }` guard.
- A short-circuit guard on the same expression: `if p != nil && p.F > 0` or `if p == nil || p.OK()`. (`&&`/`||` evaluate left-to-right, so the nil test runs first.)
- `p` comes from a constructor/function documented to never return nil.
- `p` is a pointer **parameter of an exported function** — non-nil by caller contract (callers must honor; unexported functions do NOT get this allowance).
- `p` is a method receiver whose caller contract guarantees non-nil.

```go
// ✗ unexported fn, unguarded — panics if u is nil
func fullName(u *User) string { return u.First + " " + u.Last }

// ✓ early return guard
func fullName(u *User) string {
    if u == nil { return "" }
    return u.First + " " + u.Last
}

// ✓ exported: pointer param non-nil by contract
func (s *Server) Handle(u *User) error { return s.process(u.First) }
```

### 1a. Typed nil in an interface

An interface holds (type, value). Returning a typed nil pointer into an interface makes the interface non-nil — the caller's `== nil` check is bypassed and the value panics on use. When a function returns an interface, verify the nil path returns the untyped `nil`, not a typed nil pointer.

```go
// ✗ interface{type: *MyHandler, value: nil} != nil — caller's == nil check is bypassed
func getHandler(enabled bool) http.Handler {
    if !enabled { var h *MyHandler; return h }
    return &MyHandler{}
}

// ✓ return untyped nil so the interface itself is nil
func getHandler(enabled bool) http.Handler {
    if !enabled { return nil }
    return &MyHandler{}
}
```

Same trap with `error`: returning a typed nil `*MyError` makes `err != nil` true, so the caller's error branch runs and panics dereferencing `err`. Return untyped `nil` (or the error value) on the error path.

```go
// ✗ err != nil is true, but err is a typed nil *MyError — dereferencing it panics
func load() (*Config, error) {
    if !ready {
        return nil, (*MyError)(nil)
    }
    return &Config{}, nil
}
```

### 1b. Nil function values & `defer`

Calling a nil function panics: `var f func(); f()`. Apply the §1 proofs to func values reached through lookups or optional fields invoked later — `handlers[evt]()`, `opt.OnDone(cb)`.

For `defer f()` and `defer p.M()`, args and receiver are evaluated at the defer site but the call runs at return — a nil func or nil receiver there panics after the surrounding guards are gone, in a scope the guards may not cover. Check deferred invocations too.

## 2. Slice/array index bounds

- Index access `s[i]` requires `0 <= i < len(s)`.
- Slice expression `s[i:j]` requires `0 <= i <= j <= len(s)`.
- Three-index `s[i:j:k]` additionally requires `j <= k <= cap(s)`.

Acceptable proofs: `i` comes from `for i := range s`; a preceding `if i < len(s)` (plus `i >= 0` when `i` is signed and untrusted) or a short-circuit `i < len(s) && ...`; or `i` is a constant known in-bounds. String indexing `s[i]` and slicing `s[i:j]` follow the same rules (byte positions).

```go
// ✗ untrusted index, no guard
func nth(items []string, i int) string { return items[i] }

// ✓ bounds-checked
func nth(items []string, i int) (string, bool) {
    if i < 0 || i >= len(items) { return "", false }
    return items[i], true
}
```

## 3. Map key existence

For `v := m[k]`, decide explicitly whether a missing key is an error or an acceptable default:

- Missing is an error → comma-ok: `v, ok := m[k]; if !ok { ... }`.
- Zero value is fine → add a comment `// ok: zero value is the default`.

```go
// ✗ silent default hides missing keys
func price(m map[string]int, sku string) int { return m[sku] }

// ✓ missing is an error
func price(m map[string]int, sku string) (int, error) {
    p, ok := m[sku]
    if !ok { return 0, fmt.Errorf("unknown sku %q", sku) }
    return p, nil
}
```

## 4. Type assertions

Bare `x.(T)` panics on mismatch. Require comma-ok, or a type switch that has a `default` (or exhausts every case):

```go
// ✗ panics if w is not *http.Request
r := w.(*http.Request)

// ✓
r, ok := w.(*http.Request)
if !ok { return errors.New("not a *http.Request") }
```

## 5. Integer division by zero & negative shift counts

`a / b` and `a % b` on integers panic when `b == 0`; float division yields `±Inf`/`NaN` (logic bug). Guard the divisor. (`MinInt / -1` wraps without panicking — do not flag.)

```go
// ✗ panics when n == 0
func avg(total, n int) int { return total / n }

// ✓
func avg(total, n int) (int, error) {
    if n == 0 { return 0, errors.New("avg of zero items") }
    return total / n, nil
}
```

`a << n` / `a >> n` with a **negative** runtime `n` panics; guard `n >= 0` when `n` comes from untrusted data. Counts ≥ width don't panic but silently produce `0` / sign-fill — advisory logic bug, not a panic:

```go
// ✗ panics when n < 0
func shift(x, n int) int { return x << n }

// ✓
func shift(x, n int) (int, error) {
    if n < 0 { return 0, errors.New("negative shift") }
    return x << n, nil
}
```

## 6. Nil map writes

`m[k] = v` on a nil map panics. Initialize with `make` or a composite literal first (lazy init is fine):

```go
// ✗ panic
var m map[string]int
m["a"] = 1

// ✓
m := make(map[string]int)
m["a"] = 1
```

## 7. Data races (concurrent access)

A data race occurs when two goroutines access the same variable and at least one access is a write, with no **happens-before** ordering between them (per the Go memory model). Races are always bugs: even "innocent" races on primitives (`bool`, `int`) give non-deterministic reads because compiler and CPU reordering is unconstrained. Concurrent map writes panic at runtime; most other races silently corrupt.

Unlike §1–6 (which panic on a bad access), a race requires reasoning about **concurrency** — flag any shared variable read or written by more than one goroutine unless one of these establishes happens-before:

- **`sync.Mutex` / `sync.RWMutex`** — shared maps, structs, multi-field state.
- **`sync/atomic`** — a single primitive (counter, flag, timestamp). Structs, interfaces, slices, and maps are *not* single-word; use a mutex — or, for immutable snapshots, `atomic.Value` / `atomic.Pointer[T]` (store fully-formed values, never mutate in place).
- **Channels** — a send is synchronized before the matching receive completes (unbuffered: the receive happens before the send completes).
- **`sync.Once`** — one-time initialization.
- **Goroutine creation** — the `go` statement happens before the goroutine starts, so values set before `go f()` are readable inside `f`. **Goroutine exit is NOT synchronized** — never rely on a goroutine finishing for ordering; observe its effects via a channel or `sync.WaitGroup`.

```go
// ✗ go.mod declaring `go 1.21` or lower: every goroutine captures the one shared i the loop mutates
for i := 0; i < n; i++ { go func() { fmt.Println(i) }() }
// ✓ pass i as a parameter (or shadow: i := i) — required whenever go.mod is ≤ 1.21
for i := 0; i < n; i++ { go func(i int) { fmt.Println(i) }(i) }
```

> With go.mod declaring `go 1.22+` the loop variable is per-iteration and the capture above is safe — check the go directive before flagging.

```go
// ✗ outer err shared between the main goroutine and a spawned goroutine
go func() { _, err = f1.Write(data); res <- err }()
f2, err = os.Create(...)            // races with the goroutine's write to err
// ✓ declare err inside each goroutine with :=
go func() { _, err := f1.Write(data); res <- err }()
```

```go
// ✗ concurrent map access panics at runtime
go func() { m["a"] = 1 }(); m["b"] = 2
// ✓ guard with a mutex (or sync.Map for read-heavy workloads)
var mu sync.Mutex
func set(k string, v int) { mu.Lock(); defer mu.Unlock(); m[k] = v }
```

```go
// ✗ unsynchronized send and close — close may run before the send
go func() { c <- struct{}{} }(); close(c)
// ✓ receive before close so the send is guaranteed done
go func() { c <- struct{}{} }(); <-c; close(c)
```

One goroutine owns one channel's `close`. Double close and send on a closed channel both panic — trace the closer's reachable callers.

Reject these incorrect synchronizations on sight (they compile but race):

- **Double-checked locking** — `if !done { once.Do(setup) }`: observing `done` does not imply observing the data. Use `sync.Once` unconditionally.
- **Busy-wait** — `for !done {}`: not guaranteed to observe the write or to terminate. Use a channel or `sync.WaitGroup`.
- **Pointer publication** — `for g == nil {}` then `g.msg`: observing `g != nil` does not imply `g.msg` is initialized. Publish through a channel or protect with a mutex.

### Runtime detection

The `-race` detector only catches races that actually execute, so review covers code paths tests miss. Suggest enabling:

```
go test -race ./...
```

→ See `samber/cc-skills-golang@golang-concurrency` for deeper patterns; `samber/cc-skills-golang@golang-testing` for race-enabled test setup.

## Common Mistakes

| Mistake | Fix |
| --- | --- |
| `p.Field` with no nil proof | Guard `if p == nil` or trace a non-nil contract to the caller |
| `p.Method()` whose body dereferences with no nil proof | Guard the receiver inside the method, or guarantee non-nil at the call site |
| Calling a nil func value (`handlers[e]()`, `opt.OnDone(cb)`) | Prove the func is non-nil before invoking |
| `defer p.M()` / `defer f()` where `p` or `f` can be nil | Guard before the defer site; the call runs at return, not at the defer |
| Returning a typed nil pointer into an interface | Return untyped `nil` so the interface is `== nil` |
| Returning a typed nil `*MyError` as `error` | `err != nil` passes and dereferencing panics — return untyped `nil` |
| `s[i]` with untrusted `i` | Bounds-check `0 <= i < len(s)` first |
| `s[i:j]` / `s[i:j:k]` with out-of-range indices | Check `0 <= i <= j <= len(s)` (and `k <= cap(s)`) |
| An unproven hop in a chain (`cfg.tables[name].rows[i].owner.Name`) | Prove each `cfg`/map/`rows[i]`/`owner` before its use |
| `v := m[k]` swallowing missing keys | Use comma-ok when absence matters; comment when zero value is OK |
| Bare `x.(T)` | Use `v, ok := x.(T)` or a type switch with `default` |
| `a / b` on integers | Guard `b != 0` |
| `x << n` / `x >> n` with negative `n` | Guard `n >= 0` when `n` is untrusted |
| `m[k] = v` on a nil map | `make(map[K]V)` before writing |
| Loop-counter capture (go.mod `go 1.21` or lower) | Pass `i` as a param or `i := i`; safe on go.mod `go 1.22+` |
| Shared variable (incl. outer `err`) read/written by >1 goroutine | Pass as param / shadow with `:=` / guard with mutex or `sync/atomic` |
| Concurrent map reads + writes | `sync.Mutex` (or `sync.Map` for read-heavy); concurrent map writes panic |
| Double close / send on a closed channel | One goroutine owns one `close`; coordinate via done-channel or `WaitGroup` |
| Unsynchronized `send` + `close` on one channel | Receive before `close` to establish happens-before |
| Double-checked locking / busy-wait `for !done` / pointer publication | `sync.Once`, channel, or `sync.WaitGroup` — observing one write never implies another |
| Relying on goroutine exit for ordering | Goroutine exit is not synchronized; observe effects via channel/`WaitGroup` |

## Enforce with Linters

`nilness`, `nilerr`, `errcheck`, `govet`, `staticcheck` (SA series), `gosec` catch many of these mechanically. `copyloopvar` (golangci-lint) flags `i := i` copies that Go 1.22 loop-var semantics render redundant; captures still race on modules declaring `go 1.21` or lower. → See `samber/cc-skills-golang@golang-lint`.

During a review of concrete changes, run the tools on the touched packages when feasible: `go vet`, `golangci-lint`, `go test -race`.

## Cross-References

- → See `samber/cc-skills-golang@golang-safety` skill for broader defensive coding (append aliasing, defer in loops, numeric overflow, float comparison)
- → See `samber/cc-skills-golang@golang-error-handling` skill for error wrapping and sentinel errors surfaced by these checks
- → See `samber/cc-skills-golang@golang-lint` skill for automated enforcement
