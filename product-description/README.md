# dim CLI product description

A written description of the user experience of the `dim` command: what the user types, what the terminal shows, and exactly what happens when an invocation succeeds, fails, reads input, or is interrupted.

## Purpose

`dim` is, from the user's point of view, a state chart driven by shell invocations and expression lines. The user supplies an expression, a file, or standard input; the command scans, parses, evaluates, formats, and prints a result. In REPL mode the same lifecycle repeats for each line while runtime constants remain available.

This project describes the default native CLI at `/Users/jerell/Repos/dim/zig-out/bin/dim`, with no rc file, environment customization, or embedding. It is written from the outside in for users, testers, designers, and engineers.

### What this is not

- Not API documentation for the Zig library or WASM ABI.
- Not documentation of the React registry or `QuantityInput` component.
- Not organized by source package. The parser, evaluator, and formatter are described where the user encounters their behavior.

## Conventions

- Describe what the user sees and does, not implementation details.
- Technical mechanisms appear only in `> Technical note:` blocks when they change expectations.
- Use sentence case and the vocabulary in [glossary.md](glossary.md).
- Every feature document ends with open questions and the source commit.

## The work to be done

Each document follows the eight-section feature skeleton: summary, simple case, invocation event by event, variants, cancel and interrupt, interactions with other systems, edge cases, and open questions.

### Document template

1. **Summary.** What the command or user-visible capability does and how it is reached.
2. **The simple case.** The common path without variants or failures.
3. **The interaction, event by event.** The five invocation phases: **invoke**, **exit immediately**, **begin running**, **while running**, and **finish**. A command with no observable long-running phase still fills every slot.
4. **Modifiers.** The fixed CLI variant axis: flags and options, environment variables, config-file keys, stdout TTY versus pipe, stdin TTY versus pipe, machine-readable or quiet modes, dry-run, and verbosity.
5. **Cancel and interrupt.** The fixed rows are: Ctrl+C (SIGINT) once and twice; SIGTERM; terminal closed (SIGHUP); stdin closed or stdout pipe closed (SIGPIPE); network lost; disk full or file locked; a required file changed; two instances at once; and the process killed outright.
6. **Interactions with other systems.** Configuration precedence; output modes; colors and Unicode; exit codes; logging and verbosity; locking and concurrency; caching; network and proxies; permissions and sudo; shell completion; update or version checks.
7. **Edge cases.** Observable limits, malformed input, empty input, repeated commands, and order-dependent state.
8. **Open questions and verification.** What remains unconfirmed, suspected defects, and the source commit.

### Method

Draft from `src/main.zig`, the parser and expression evaluator, formatting and registry code, and the CLI tests in `src/main.zig`. Verify with the built binary in `zig-out/bin/dim`; use scripts for output and exit codes and a real TTY for prompts and REPL behavior.

### Scope decisions

- **Surface.** The native `dim` CLI, version built from this repository, default configuration, POSIX-like shell semantics, and a TTY unless a document says otherwise.
- **Source of truth.** `/Users/jerell/Repos/dim`, revision commit `5d9cf0d`; the CLI surface is unchanged by the API revisions covered here.
- **Run command.** `zig-out/bin/dim`; build with `zig build` if the binary is absent. REPL verification uses an interactive terminal; batch verification uses pipes and `--file`.
- **Out of scope.** Zig library APIs, C/Rust integration, WASM/browser APIs, React components, registry installation, custom unit registries, and non-default application embedding.
- **Interaction shape.** The unit is an invocation with phases invoke, exit immediately, begin running, while running, and finish. The variant axis, interrupt list, and cross-cutting order above are fixed.
- **Repository location.** This description is in `product-description/` inside the source checkout, as requested.

## Structure

```
README.md                         this file
goal.md                           standing drafting instructions
AGENTS.md, CLAUDE.md              agent entry points
glossary.md                       shared vocabulary
bug-triage.md                     suspected defects

verification/
  README.md                       verification protocol
  cli.md                          checklists for all CLI documents

foundations/
  invocation.md                   argument forms and lifecycle
  configuration.md                defaults and precedence
  output.md                       streams, formatting modes, and exit results
  session-state.md                REPL and runtime constant state

cli/
  expressions.md                  arithmetic, quantities, and unit expressions
  conversions.md                  `as` conversions and affine units
  constants.md                    defining, listing, showing, and clearing constants
  input-sources.md                direct arguments, REPL, stdin, and files

cross-cutting/
  errors.md                       parse and runtime failures
```

## Coverage

| Document | Status |
| --- | --- |
| glossary.md | drafted |
| foundations/invocation.md | drafted |
| foundations/configuration.md | drafted |
| foundations/output.md | drafted |
| foundations/session-state.md | drafted |
| cli/constants.md | drafted |
| cli/expressions.md | drafted |
| cli/conversions.md | drafted |
| cli/input-sources.md | drafted |
| cross-cutting/errors.md | drafted |
| verification/ (1 checklist) | drafted |
| bug-triage.md | drafted |

## Reference

The source of truth for this revision is `/Users/jerell/Repos/dim` at commit `5d9cf0d`.

- `src/main.zig`: CLI argument dispatch, REPL, stdin/file reading, command handling, output, and CLI tests.
- `src/parser/parser.zig`: token-to-expression grammar and parse errors.
- `src/parser/scanner.zig`: lexical input and token errors.
- `src/parser/expressions.zig`: evaluation of arithmetic, quantities, conversions, formatting modes, and constants.
- `src/format.zig`: displayed unit normalization and formatting.
- `src/Unit.zig`, `src/quantity.zig`, and `src/root.zig`: units, dimensions, quantities, and affine/delta behavior.
- `src/registry/*.zig`: default unit registries.
- `build.zig`: native CLI build and `zig build run` entry point.
- `README.md`, `test.dim`, and `test2.dim`: documented invocation examples and batch inputs.
