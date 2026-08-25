# Goal: complete the QuantityInput product description

You are working in the `product-description-quantity-input` repo. Read `README.md`, `glossary.md`, the foundation documents, and the pilot first. The README's coverage table is the work list. Write every document in its structure, then run the consistency pass.

## Source of truth

The source repo is `/Users/jerell/Repos/dim`, revision commit `5d9cf0d`. Describe the Storybook `dim/QuantityInput` story set—Default, Invalid, and Spreadsheet—with the default story configuration. The standalone provider, registry installation, WASM ABI, and arbitrary consumer integrations are out of scope.

Read in this order:

1. `registry/components/quantity-input.tsx` for the user-visible field lifecycle, state, validation, conversion rows, popover, styling, and callbacks.
2. `registry/components/ui/input-group.tsx` and `registry/components/ui/popover.tsx` for focus, invalid styling, button, portal, and dismissal behavior.
3. `registry/components/dim-provider.tsx` and `wasm/dim.ts` for runtime readiness and evaluation/conversion behavior that changes the field.
4. `stories/quantity-input.stories.tsx` for the three covered scenarios and their props.
5. `tests/react/quantity-input.test.tsx` and `tests/react/dim-provider.test.tsx` for executable edge cases.
6. `.storybook/preview.ts`, `vite.config.ts`, and `package.json` for canvas, aliases, and run commands.

Describe what the user sees and does, not React implementation. Use `> Technical note:` only when the implementation changes an expectation.

## Writing rules

- Follow the eight-section template in README.md for every feature document.
- Every feature uses the same field-lifecycle phases, modifier rows, interrupt rows, and cross-cutting order.
- Use glossary terms. Add a definition before introducing a new term.
- State surprising behavior plainly. Put suspected defects in open questions and then bug-triage.md.
- Cross-reference foundations instead of repeating their rules.
- Include one Mermaid `stateDiagram-v2` per interaction.
- End with `## Open questions and verification` and `Verified against /Users/jerell/Repos/dim commit \`5d9cf0d\`.`
- Do not alter runtime source files while drafting.

## Things already established

- The surface is Storybook's `dim/QuantityInput` Default, Invalid, and Spreadsheet stories.
- The default declared unit is `bar`; the default value is `1 bar`.
- Default conversions are `bar` labeled `bara` with 3 decimal places, `kPa` with 1, and `psi` with 2.
- The field states are idle, loading, valid, and invalid; empty trimmed input is idle.
- A bare finite number is interpreted using the declared unit; other non-empty text is evaluated as an expression.
- Validity is recomputed when value, declared unit, conversions, locale, or runtime readiness changes.
- Uncontrolled typing updates the displayed value; controlled typing calls `onValueChange` but the displayed value remains parent-owned.
- The info button is labeled `Show converted values` by default and opens a popover with the current state.
- Conversion values use `Intl.NumberFormat` with default locale `en-GB`, no grouping, and each conversion's decimal-place settings.
- The component does not submit or persist a record; callbacks are the only outward effects described here.

## Order of work

1. Pilot: `quantity-input/basic-editing.md`.
2. Foundations: field state, value ownership, runtime readiness.
3. Hardest area: validation and conversions, followed by the conversion popover.
4. Spreadsheet integration and accessibility/layout, then verification and triage.

Update the README coverage table as documents land. Commit coherent groups with `docs: add {path}` or `docs: revise {path}`. Never mark a document verified until a hand pass has run.
