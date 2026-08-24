# Glossary

The vocabulary used across these documents. When a document uses one of these words, it means exactly this.

## The terminal

**CLI.** The native `dim` command invoked from a shell.

**TTY.** A terminal device. When standard input is a TTY and no argument is supplied, `dim` starts the REPL; piped input is processed as batch input instead.

**Invocation.** One process start of `dim`, including its argument selection and all input lines it processes.

**REPL.** The interactive mode started by `dim` with no arguments when stdin is a TTY. It prints `> `, evaluates one line, then prints the next prompt.

**Batch input.** Expressions read from stdin or a file, one non-empty line at a time.

## Values and units

**Expression.** Text that `dim` scans, parses, evaluates, and prints as a number, string, boolean, quantity, or nil result.

**Quantity.** A numeric value with a physical dimension and a unit display. Quantities are converted through canonical storage before a requested display unit is applied.

**Dimension.** The physical exponents of a quantity, such as length, time, or mass. Quantities can be added or compared only when their dimensions are compatible.

**Unit.** A named scale such as `m`, `Pa`, `C`, or `km/h`. A compound unit combines unit names with multiplication, division, or an exponent.

**Canonical value.** The internal base representation used to compare and convert a quantity. It is not necessarily the value or unit printed to the user.

**Display unit.** The unit name requested after `as`, or the unit chosen by default formatting when no target is requested.

**Affine unit.** A unit with an offset as well as a scale, such as Celsius or Fahrenheit. Addition and subtraction treat absolute values and deltas differently; affine units cannot be raised to a non-integer exponent.

**Delta.** A quantity representing a difference between two absolute quantities. For example, subtracting two temperatures produces a temperature delta rather than an absolute temperature.

**Constant.** A named runtime quantity defined with `name = (expression)`. A constant remains available in later REPL lines and has precedence over unit registries.

## Invocation state

**Scan.** The first interpretation step, where characters become tokens. Scan errors are printed to stderr and stop that line.

**Parse.** The step that checks token order and builds the expression meaning. Parse errors are printed to stderr and stop that line.

**Evaluate.** The step that calculates a parsed expression and performs conversions or state changes. Runtime errors are printed to stderr and stop that line.

**Format.** The final conversion of a result into terminal text, including the requested `scientific`, `engineering`, `auto`, or `none` mode.

**Complete.** An invocation or input line has finished processing and its visible result has been emitted. In the REPL, completion returns control to the next prompt.

**Interrupt.** An external event that stops or changes an invocation before its normal completion, such as Ctrl+C, a closed pipe, or process termination.

**Safe to interrupt.** The CLI has no documented durable file-writing step during normal evaluation. Interrupting it may lose the current in-memory evaluation, but it does not intentionally leave a partially written output file.

## Output and failure

**stdout.** The stream used for prompts, successful results, usage text, and `ok` responses.

**stderr.** The stream used for scanner, parser, runtime, argument, and unknown-constant errors.

**Exit status.** The process result reported to the shell. Normal return uses the shell's success status; invalid `--file` arguments explicitly use status 64. Other operational failures may be reported by the host runtime.

**Format mode.** The optional suffix after `as`: `scientific`, `engineering`, `auto`, or an unrecognized mode that falls back to `none`.
