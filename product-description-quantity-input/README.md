# QuantityInput product description

A written description of the user experience of the `QuantityInput` React component in the Storybook surface: what the user sees, what they can type, and exactly what happens as a quantity becomes valid, invalid, converted, or controlled by its parent.

## Purpose

`QuantityInput` is, from the user's point of view, a small state chart driven by field editing, focus, blur, and the converted-values button. The field accepts a number or a full dimensional expression, evaluates it through the dim runtime, marks incompatible input invalid, and can show converted values in a popover. The component's visible behavior is spread across the component, its provider, UI primitives, stories, and tests.

This project describes the `dim/QuantityInput` Storybook surface with all three stories—Default, Invalid, and Spreadsheet—under their default story configuration. It describes the component from the user's point of view, not the implementation.

### What this is not

- Not API documentation for every prop, the WASM ABI, or the Zig library. Those remain in the source repository's README and TypeScript types.
- Not a description of `DimProvider` as a standalone product. Provider loading is included only where it changes what the `QuantityInput` user sees.
- Not a registry-installation guide. The shadcn registry payload and copied-component workflow are out of scope.

## Conventions

- Describe the experience, not the code. Say "the field shows an invalid state" rather than "the effect sets `status`".
- Technical detail goes only in `> Technical note:` blocks when the mechanism changes what the user expects.
- Use sentence case for headings and the vocabulary in [glossary.md](glossary.md).
- Every feature document ends with open questions and the source commit.
- The Storybook canvas is the page being described. The browser, not an application account, supplies the verification environment.

## The work to be done

Each document describes one user-facing behavior of the component or one foundation it owns. Documents use the same eight-section skeleton so that editing, validation, conversion, popover, and spreadsheet behavior can be compared without changing vocabulary.

### Document template

1. **Summary.** What the behavior lets the user do and where it appears in the Storybook surface.
2. **The simple case.** The common path with a valid pressure value.
3. **The interaction, event by event.** The five phases of a **field lifecycle**: **arrive**, **leave untouched**, **begin editing**, **while editing**, and **finish editing**. These phases cover initial render, a field that is never changed, the first edit, live evaluation and popover use, and the final value/callback state.
4. **Modifiers.** The fixed variant axis: controlled or uncontrolled value, default value, declared unit, conversion list, locale, and runtime readiness. The table always uses the same rows.
5. **Cancel and interrupt.** The fixed rows are: Escape; clicking or interacting elsewhere; closing the conversion popover; the runtime or browser failing; reloading or closing the tab; the parent changing the value or props; and the input channel changing through paste, autofill, or another device.
6. **Interactions with other systems.** Validation and error display; controlled and uncontrolled state; conversion formatting and locale; callbacks; focus and keyboard access; the dim runtime and provider; popover and portal behavior; layout and table integration; browser accessibility semantics.
7. **Edge cases.** Empty input, whitespace, bare numbers, full expressions, incompatible dimensions, zero conversions, duplicate conversion keys, and updates from a parent.
8. **Open questions and verification.** Unconfirmed visual or timing behavior, suspected defects, and the source commit.

### Method

Read `registry/components/quantity-input.tsx` first, then the `InputGroup` and `Popover` primitives, `wasm/dim.ts`, Storybook stories, and React tests. Run `npm run storybook` on port 6006 to observe the Default, Invalid, and Spreadsheet stories. Run `npm run typecheck` and `npm run test:components` for supporting evidence.

### Verification

The `verification/` directory contains one checklist for the foundations and component stories. A tester uses a desktop browser at Storybook port 6006, records `pass`, `fail`, or `blocked`, and files failures in `bug-triage.md`. A document is `verified` only when every P1 and P2 item has passed or been filed; automated tests alone do not establish visual verification.

## Order of work

1. **Pilot: [basic editing](quantity-input/basic-editing.md).** The smallest complete interaction: arrive with `1 bar`, edit the field, and inspect the conversion popover.
2. **Foundations: [field state](foundations/field-state.md), [value ownership](foundations/value-ownership.md), and [runtime readiness](foundations/runtime-readiness.md).** These own status, values, callbacks, and loading/error behavior.
3. **Hardest area: [validation and conversions](quantity-input/validation-and-conversions.md).** This owns the handoff from typing to evaluation, compatibility, and converted output.
4. **Everything else: [conversion popover](quantity-input/conversion-popover.md), [spreadsheet integration](quantity-input/spreadsheet-integration.md), and [accessibility and layout](cross-cutting/accessibility-and-layout.md).**

Progress is tracked in the [coverage table](#coverage).

### Scope decisions

- **Surface.** Storybook's `dim/QuantityInput` story set: Default, Invalid, and Spreadsheet, with the story decorator and default pressure conversions.
- **Configuration.** Default story args: `unit="bar"`, `defaultValue="1 bar"`, conversions for `bar` labeled `bara` at three decimals, `kPa` at one decimal, and `psi` at two decimals. No custom props beyond each story's own args.
- **Interaction shape.** The unit is a field lifecycle with phases arrive, leave untouched, begin editing, while editing, and finish editing. The interrupt list and cross-cutting order above are fixed for every feature document.
- **Out of scope.** Standalone `DimProvider` configuration, custom WASM deployment, registry installation, application form submission, server persistence, mobile-specific behavior, and arbitrary consumer-defined props. Provider readiness is described only as it affects the component.
- **Source.** `/Users/jerell/Repos/dim` at commit `c26ec6a` when this description was scaffolded.
- **Repository location.** This is a new description directory inside the source checkout, separate from the existing CLI description in `product-description/`.

## Structure

```
README.md                              this file
goal.md                                standing drafting instructions
glossary.md                            shared vocabulary
AGENTS.md, CLAUDE.md                    agent entry points
bug-triage.md                          suspected defects

verification/
  README.md                            hand-verification protocol
  quantity-input.md                    checklists for foundations and stories

foundations/
  field-state.md                       idle, loading, valid, and invalid states
  value-ownership.md                   controlled, uncontrolled, and callback behavior
  runtime-readiness.md                 provider readiness as seen by the field

quantity-input/
  basic-editing.md                     pilot: editing a valid quantity
  validation-and-conversions.md        live compatibility and converted results
  conversion-popover.md                the info button and result panel
  spreadsheet-integration.md           repeated controlled inputs in the table story

cross-cutting/
  accessibility-and-layout.md          keyboard, labels, focus, styling, and table layout
```

## Coverage

Status is one of `not started`, `drafted`, or `verified`.

| Document | Status |
| --- | --- |
| glossary.md | drafted |
| foundations/field-state.md | drafted |
| foundations/value-ownership.md | drafted |
| foundations/runtime-readiness.md | drafted |
| quantity-input/basic-editing.md | drafted |
| quantity-input/validation-and-conversions.md | drafted |
| quantity-input/conversion-popover.md | drafted |
| quantity-input/spreadsheet-integration.md | drafted |
| cross-cutting/accessibility-and-layout.md | drafted |
| verification/ (1 checklist) | not started |
| bug-triage.md | not started |

## Reference

The source of truth is `/Users/jerell/Repos/dim` at commit `c26ec6a`.

- `registry/components/quantity-input.tsx`: field value handling, state transitions, validation, conversions, popover content, styling, and callbacks.
- `registry/components/dim-provider.tsx`: runtime loading and readiness visible to the component.
- `registry/components/ui/input-group.tsx`: group, addon, input, focus, invalid, and disabled styling behavior.
- `registry/components/ui/popover.tsx`: portal, trigger, popup placement, and open/close behavior.
- `stories/quantity-input.stories.tsx`: Default, Invalid, and Spreadsheet surfaces and their default props.
- `tests/react/quantity-input.test.tsx`: executable behavior for valid conversion, invalid input, and controlled values.
- `tests/react/dim-provider.test.tsx`: runtime initialization and constant setup coverage.
- `wasm/dim.ts`: evaluation, compatibility, conversion, initialization, and runtime error behavior.
- `.storybook/preview.ts`: centered Storybook canvas and global styles.
- `vite.config.ts` and `package.json`: aliases, test setup, and Storybook/test commands.
