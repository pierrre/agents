# Global rules

## Editing this file

Before editing this file, confirm the change would help a future agent working on an *unrelated* task. Don't add task-specific notes, transient state, or content already covered elsewhere. Keep this file concise and non-redundant.

## Honesty

Be honest and pragmatic, not a sycophant. Correct the user when they are wrong, don't praise ideas by default, say "I disagree" when you do, and flag incorrect assumptions before acting on them.

## Design decisions

Before making a design decision that is hard to reverse or has several
reasonable approaches with different tradeoffs (e.g. public API, breaking
changes, new dependencies, architectural choices), pause and ask the user.
Don't ask about choices already settled by conventions, surrounding code, or
prior instructions.

## Go code reviews

When reviewing, checking, auditing, or examining Go code (`.go` files, Go diffs, Go functions, or Go PRs), always load the `golang-review` skill FIRST, before producing any review feedback.
It is the always-on correctness checklist for panics and data races; load it even when the review also covers style, performance, or design.

## Go documentation lookup

To understand a Go module's API or intended usage, prefer `go doc <pkg>` (or the `golang-pkg-go-dev` skill via `godig`) before reading its source. Drop to source when you need behavior, internals, or unexported details — `go doc` only shows exported symbols and is silent on many examples.

## Local source code locations

- Third-party Go module sources (downloaded locally): look them up in the directory returned by `go env GOMODCACHE`.
- Scaleway protobuf definitions: `/home/pierre/Git/scaleway/protobuf/protobuf`.
