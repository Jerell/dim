# Goal: complete the dim CLI product description

You are working in the `product-description` repo. Read `README.md`, `glossary.md`, the foundation documents, and the pilot first. The README's coverage table is the work list. Write every document in its structure, then run the consistency pass.

## Source of truth

The source repo is checked out at `/Users/jerell/Repos/dim`. Describe the native CLI at `zig-out/bin/dim` in its default configuration. Library, WASM, React, registry, and custom embedding behavior is out of scope.

Read in this order:

1. `src/main.zig` for dispatch, REPL, batch input, commands, output, and CLI tests.
2. `src/parser/scanner.zig`, `src/parser/parser.zig`, and `src/parser/expressions.zig` for expression behavior.
3. `src/format.zig`, `src/Unit.zig`, `src/quantity.zig`, `src/root.zig`, and `src/registry/*.zig` for units and formatting.
4. `README.md`, `test.dim`, and `test2.dim` for user-facing examples.
5. `build.zig` for how to run the binary.

Describe the experience, not the code. Technical detail belongs only in `> Technical note:` blocks when it changes what the user expects.

## Writing rules

- Use the eight-section template in README.md.
- Every document uses the same invocation phases, modifier rows, interrupt rows, and cross-cutting order.
- Use glossary terms. Add a definition before introducing a new term.
- State surprising behavior plainly. Put suspected defects in open questions and in bug-triage.md after the full draft.
- Cross-reference foundation documents instead of repeating their rules.
- Include one Mermaid `stateDiagram-v2` per interaction.
- End with `## Open questions and verification` and `Verified against /Users/jerell/Repos/dim commit \`5d9cf0d\`.`
- Do not alter runtime source files.

## Things already established

- The surface is the native CLI with default configuration and no custom registry or rc file.
- The unit of interaction is an invocation with phases invoke, exit immediately, begin running, while running, and finish.
- No normal CLI path intentionally writes durable files; `--file` reads a file and outputs results.
- No argument starts the REPL only when stdin is a TTY; otherwise no argument reads stdin as batch input.
- Results go to stdout; scan, parse, runtime, and unknown-constant errors go to stderr.
- `--file` without exactly one path prints an error and usage, then exits with status 64.
- Runtime constants are process-local and persist across REPL lines; `list`, `show`, `clear`, and `clear all` operate on that state.

## Order of work

1. Foundations: invocation, configuration, output, session-state.
2. Pilot: constants, because definition changes later REPL state.
3. Hardest area: expressions, conversions, and input sources.
4. Cross-cutting errors, verification checklist, triage, then consistency review.

Update the README coverage table as documents land. Commit coherent groups with `docs: add {path}` or `docs: revise {path}`. Never claim a document is verified until a hand pass has run.
