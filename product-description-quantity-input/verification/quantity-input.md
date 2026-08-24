# Verification: QuantityInput

Run `npm run storybook` from `/Users/jerell/Repos/dim` and open `http://localhost:6006`. Use a fresh page between stories. `mouse` means a real pointer; `keyboard` means real Tab/Enter/Space/Escape and text editing; `browser` means the browser DOM and visible canvas.

## foundations/field-state.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| STATE-01 | P1 | browser | Empty trimmed input is idle and the panel asks for an expression ([leave untouched](../foundations/field-state.md#leave-untouched)). | Render a QuantityInput with an empty value and ready runtime. | 1. Open the info button. | The panel says `Enter a quantity expression.` and no conversion rows appear. | — |
| STATE-02 | P1 | browser | Incompatible input is invalid ([while editing](../foundations/field-state.md#while-editing)). | Open Invalid or type into Default. | 1. Set the field to `12 kg`.<br>2. Wait for state update.<br>3. Inspect field and panel. | The field has `aria-invalid="true"`, destructive styling, and the panel says `Invalid quantity` and `Not compatible with bar`. | — |

## foundations/value-ownership.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| VALUE-01 | P1 | browser | An uncontrolled field displays its typed raw value ([begin editing](../foundations/value-ownership.md#begin-editing)). | Default story. | 1. Focus the field.<br>2. Replace `1 bar` with `2`. | The field displays the exact raw text `2`; it does not rewrite it to `2 bar`. | — |
| VALUE-02 | P1 | browser | Spreadsheet parent updates only the edited row ([while editing](../foundations/value-ownership.md#while-editing)). | Spreadsheet story. | 1. Edit the P-2 field.<br>2. Replace it with `3 bar`.<br>3. Inspect P-1 and P-3. | P-2 changes; P-1 and P-3 retain their original values. | — |

## foundations/runtime-readiness.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| READY-01 | P2 | browser | Storybook can show the provider loading fallback before the runtime is ready ([arrive](../foundations/runtime-readiness.md#arrive)). | Fresh Storybook load with cache disabled if possible. | 1. Open Default from a hard reload.<br>2. Observe immediately and after readiness. | The canvas may briefly show `Loading dim…`, then the story field appears. | — |
| READY-02 | P1 | browser | A ready runtime allows the initial valid value to produce conversions ([while editing](../foundations/runtime-readiness.md#while-editing)). | Default story after field appears. | 1. Open the info button. | Converted values are shown rather than a loading message. | — |

## quantity-input/basic-editing.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BASIC-01 | P1 | mouse | Default starts with `1 bar` and exposes the conversion button ([arrive](../quantity-input/basic-editing.md#arrive)). | Default story. | 1. Open the story. | A square-edged text field contains `1 bar`; an icon button named `Show converted values` is present. | — |
| BASIC-02 | P1 | mouse | Opening the info button shows configured conversions ([leave untouched](../quantity-input/basic-editing.md#leave-untouched)). | Default story after ready. | 1. Click `Show converted values`. | The panel shows `Converted values`, `1.000`/`bara`, `100.0`/`kPa`, and `14.50`/`psi`; input text is unchanged. | — |
| BASIC-03 | P1 | keyboard | An invalid edit keeps raw text and exposes invalid state ([while editing](../quantity-input/basic-editing.md#while-editing)). | Default story. | 1. Focus input.<br>2. Replace text with `12 kg`.<br>3. Wait for evaluation. | The field still shows `12 kg`, becomes invalid, and the panel explains incompatibility. | — |

## quantity-input/validation-and-conversions.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| VALID-01 | P1 | browser | Valid pressure values produce ordered conversion rows ([while editing](../quantity-input/validation-and-conversions.md#while-editing)). | Default story after ready. | 1. Open the conversion panel. | Rows appear in configured order: bara, kPa, psi, with 3, 1, and 2 decimal places. | — |
| VALID-02 | P2 | browser | Changing the declared value recomputes conversions without rewriting raw text ([begin editing](../quantity-input/validation-and-conversions.md#begin-editing)). | Default story. | 1. Replace the input with `2`.<br>2. Open the panel. | The input remains `2`; conversion values reflect `2 bar`. | — |

## quantity-input/conversion-popover.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| POPOVER-01 | P1 | mouse | The info button opens a panel without replacing the field ([begin editing](../quantity-input/conversion-popover.md#begin-editing)). | Default story. | 1. Record the field text.<br>2. Click the info button. | A positioned panel opens and the field text is unchanged. | — |
| POPOVER-02 | P2 | keyboard | Escape dismisses the open panel ([cancel and interrupt](../quantity-input/conversion-popover.md#cancel-and-interrupt)). | Default story with panel open. | 1. Press Escape. | The panel closes; the field remains mounted with its previous value and state. | — |

## quantity-input/spreadsheet-integration.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SHEET-01 | P1 | mouse | Spreadsheet renders three pressure rows ([the simple case](../quantity-input/spreadsheet-integration.md#the-simple-case)). | Spreadsheet story. | 1. Open the story. | Rows P-1, P-2, and P-3 show their initial raw values in separate fields. | — |
| SHEET-02 | P1 | mouse | An invalid table edit affects only its row ([while editing](../quantity-input/spreadsheet-integration.md#while-editing)). | Spreadsheet story. | 1. Replace P-2 with `12 kg`.<br>2. Wait for validation.<br>3. Inspect P-1 and P-3. | P-2 is invalid; P-1 and P-3 retain their values and normal state. | — |

## cross-cutting/accessibility-and-layout.md

| ID | P | Device | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A11Y-01 | P1 | keyboard | The info control is keyboard reachable and named ([arrive](../cross-cutting/accessibility-and-layout.md#arrive)). | Default story. | 1. Press Tab until the info control is focused.<br>2. Inspect its accessible name. | The control can receive focus and is named `Show converted values`. | — |
| A11Y-02 | P1 | browser | Invalid state is exposed through `aria-invalid` ([while editing](../cross-cutting/accessibility-and-layout.md#while-editing)). | Default story. | 1. Enter `12 kg`.<br>2. Inspect the input after validation. | The input has `aria-invalid="true"`; correcting the value removes it. | — |
| A11Y-03 | P1 | keyboard | The covered stories provide an accessible name for each text input (suspected bug). | Default and Spreadsheet stories. | 1. Inspect the accessible tree for each input.<br>2. Record the computed name. | Record whether each field has a meaningful accessible name; the source stories do not supply explicit input labels. | — |

Not checkable by hand:

- Whether the component's missing input labels are acceptable for every consumer; this requires a product/accessibility decision ([accessibility](../cross-cutting/accessibility-and-layout.md#open-questions-and-verification)).
- Whether the provider's shared runtime should show a loading fallback on every fresh story navigation ([runtime readiness](../foundations/runtime-readiness.md#edge-cases)).
