# Bug triage

A consolidated list of suspected defects raised while describing the `QuantityInput` Storybook surface. These entries come from source and tests; no browser hand-verification pass has run. The list separates behavior that needs a product decision from behavior that appears wrong for the covered stories.

## Summary

One likely accessibility defect was found: the covered stories render text inputs without an explicit accessible name. Two related documents raise it because Default and Spreadsheet expose the same gap. Loading timing and popover focus behavior remain open observations rather than confirmed bugs.

| ID | Title | Severity | Area | Decision needed | Issue |
| --- | --- | --- | --- | --- | --- |
| B-01 | QuantityInput story inputs have no accessible name | medium | accessibility | fix | — |

## Medium

### B-01: QuantityInput story inputs have no accessible name

- **Where the user meets it:** A keyboard or screen-reader user reaches the text input in the Default, Invalid, or Spreadsheet Storybook story.
- **What happens / what was expected:** The component renders a text input and the stories provide no `aria-label`, visible label, or `name`/label association. The info button is named, but the quantity field itself may be announced without a useful name. The expected behavior is a meaningful field name such as `Pressure`.
- **Reproduce:** 1. Open `dim/QuantityInput/Default` in Storybook. 2. Inspect the accessibility tree or tab to the text input. 3. Repeat for each Spreadsheet row. 4. Record the computed accessible name.
- **Why (from the code):** `stories/quantity-input.stories.tsx` supplies `unit`, `defaultValue`, and `conversions` but no `aria-label` or label element. `registry/components/quantity-input.tsx` forwards input props but does not create a label from `unit`.
- **Severity:** `medium`. The visual control works, but users who depend on accessible names may not know what the field represents.
- **Decision needed:** `fix`. Add a visible or programmatic label in the stories/consumer surface, or require/document an accessible label prop for every use.
- **Raised by:** [basic editing](quantity-input/basic-editing.md#open-questions-and-verification), [spreadsheet integration](quantity-input/spreadsheet-integration.md#open-questions-and-verification), [accessibility and layout](cross-cutting/accessibility-and-layout.md#open-questions-and-verification)

## Open observations

- The Default Storybook canvas may briefly show `Loading dim…`; this is timing-dependent and was not observed by hand.
- The popover primitive's focus return and screen-reader announcement need browser verification.
- A consumer can supply `aria-label`, as the React tests do; whether the component itself should require or synthesize one is a product decision if the Storybook stories are not considered production usage.
