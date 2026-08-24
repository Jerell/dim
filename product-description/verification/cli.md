# Verification: CLI

Run `zig build` first. Use `zig-out/bin/dim`; use a temporary directory for files and a real TTY for REPL claims. Result is `—` until a hand pass is run.

## foundations/invocation.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INVOC-01 | P1 | piped | A direct expression prints one result without a prompt ([simple case](../foundations/invocation.md#the-simple-case)). | Built binary. | 1. Run `zig-out/bin/dim '1 m + 2 m'`. | stdout is one result line and no `> ` prompt. | — |
| INVOC-02 | P1 | TTY | Bare TTY input starts the REPL ([invoke](../foundations/invocation.md#invoke)). | Interactive terminal. | 1. Run `zig-out/bin/dim`. | `> ` appears before input. | — |

## foundations/configuration.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CONFIG-01 | P1 | piped | Built-in units work without a config file ([simple case](../foundations/configuration.md#the-simple-case)). | Clean shell. | 1. Run `zig-out/bin/dim '1 bar as kPa'`. | A converted result is printed without setup. | — |

## foundations/output.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| OUTPUT-01 | P1 | piped | Success goes to stdout and a malformed expression goes to stderr ([simple case](../foundations/output.md#the-simple-case)). | Built binary. | 1. Capture streams for `1 m + 2 m`.<br>2. Capture streams for `1e`. | First has result on stdout; second has a scanner or parser diagnostic on stderr and no result. | pass (scripted; scanner diagnostic) |

## foundations/session-state.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| STATE-01 | P1 | TTY | A constant remains available across REPL lines ([simple case](../foundations/session-state.md#the-simple-case)). | Interactive terminal. | 1. Start `dim`.<br>2. Enter `d = (24 h)`.<br>3. Enter `1000000 s as d`. | The third line uses `d` and prints a day-valued result. | — |

## cli/constants.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CONST-01 | P1 | TTY | Defining a constant stores it for later lines ([finishing](../cli/constants.md#finish)). | Empty REPL. | 1. Define `d = (24 h)`.<br>2. Enter `show d`. | Assignment prints its quantity; `show d` prints its definition. | — |
| CONST-02 | P2 | TTY | Clearing a constant prints `ok` and removes it ([finishing](../cli/constants.md#finish)). | `d` defined. | 1. Enter `clear d`.<br>2. Use `d` in an expression. | First prints `ok`; second no longer resolves `d`. | — |

## cli/expressions.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EXPR-01 | P1 | piped | Compatible quantities can be added ([simple case](../cli/expressions.md#the-simple-case)). | Built binary. | 1. Run `zig-out/bin/dim '1 m + 2 m'`. | stdout contains `3 m`. | pass (scripted) |
| EXPR-02 | P2 | piped | Division by zero is a runtime error ([ending at once](../cli/expressions.md#exit-immediately)). | Built binary. | 1. Run `zig-out/bin/dim '1 m / 0 m'`. | stderr contains a runtime error and stdout has no result. | pass (scripted) |

## cli/conversions.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CONVERT-01 | P1 | piped | `as` converts a quantity to the requested unit ([simple case](../cli/conversions.md#the-simple-case)). | Built binary. | 1. Run `zig-out/bin/dim '1 bar as kPa'`. | stdout contains `100 kPa`. | pass (scripted) |
| CONVERT-02 | P2 | piped | Affine temperature conversion applies the offset ([simple case](../cli/conversions.md#the-simple-case)). | Built binary. | 1. Run `zig-out/bin/dim '100 C as F'`. | stdout represents 212 Fahrenheit. | pass (scripted; `211.99999999999994 F`) |

## cli/input-sources.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INPUT-01 | P1 | piped | Piped stdin is processed as batch input without prompts ([simple case](../cli/input-sources.md#the-simple-case)). | Built binary. | 1. Pipe two expressions to `zig-out/bin/dim`. | One result line per non-empty input line and no prompt. | pass (scripted) |
| INPUT-02 | P2 | file | `--file` processes non-empty lines in order ([begin running](../cli/input-sources.md#begin-running)). | Temporary file with two valid lines and a blank line. | 1. Run `zig-out/bin/dim --file path`. | Two result lines, in file order. | — |

## cross-cutting/errors.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ERROR-01 | P1 | piped | Parse errors do not print a result ([exit immediately](../cross-cutting/errors.md#exit-immediately)). | Built binary. | 1. Run `zig-out/bin/dim '1e'`, capturing both streams. | stderr has a scanner or parser diagnostic; stdout has no quantity result. | pass (scripted; status 0) |

Not checkable by hand:

- Whether the absence of configuration is a desirable product decision.
- Whether unrecognized format names should fall back to `none` or be rejected; this needs a product call.
