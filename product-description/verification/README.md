# Hand verification

These checklists compare the CLI documents with the built `dim` binary one observable claim at a time.

## What is here

| File | Covers |
| --- | --- |
| [cli.md](cli.md) | foundations, CLI features, and cross-cutting errors |

## How to run a pass

1. Build with `zig build` from `/Users/jerell/Repos/dim` and use `zig-out/bin/dim`.
2. Confirm `git -C /Users/jerell/Repos/dim rev-parse --short HEAD` matches the footer (`5d9cf0d`).
3. Run P1 items first, then P2 and P3. Use a real TTY for REPL items and pipes/files for batch items.
4. Record `pass`, `fail`, or `blocked` in the Result column. File every fail in `bug-triage.md`; a fail may mean the document is wrong rather than the product.
5. A document becomes `verified` only after every P1 and P2 item has passed or been filed.

## Devices and conditions

- **TTY:** run the binary in an interactive terminal to observe `> ` prompts, flushing, EOF, and Ctrl+C.
- **Piped stdin/stdout:** use `printf` and shell pipes; prompts should not be expected in batch mode.
- **File input:** use a temporary file with blank, valid, and invalid lines; do not modify repository fixtures.
- **Second process:** launch two binaries separately to confirm constants do not cross process boundaries.
- **Signals:** use a long-running or repeated input only where practical; document if timing makes the item blocked.

## Driving the product from a script

Most claims are scriptable: commands can capture stdout, stderr, and exit status. Scripts cannot establish TTY-only prompt visibility or reliably win a race against a fast expression for signal tests. Use the real terminal for those claims.

## Results so far

A scripted pass ran on 2026-08-24 against the current built binary after `zig build test` passed. It checked direct arithmetic, conversion, affine temperature conversion, piped input, scanner failure, and division-by-zero output and streams. Those rows are marked `pass` with notes in `cli.md`; the failure cases returned status 0, which raised B-01. No TTY prompts, signals, file-source behavior, or visual terminal rendering were checked, so no document is marked `verified`.
