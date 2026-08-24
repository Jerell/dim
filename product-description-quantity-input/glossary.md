# Glossary

The vocabulary used across these documents. When a document uses one of these words, it means exactly this.

## The Storybook surface

**Storybook canvas.** The centered preview area in which the `QuantityInput` stories render. The Default and Invalid stories render one field; the Spreadsheet story renders three fields in a table.

**Story.** One named Storybook scenario with its own props and render function. This description covers Default, Invalid, and Spreadsheet.

**QuantityInput.** The square-edged text field that accepts a quantity expression and exposes an info button for converted values. It displays one field value while the runtime evaluates that value in the background.

**Conversion.** A requested output unit and optional label and decimal-place rule. For example, `kPa` with one decimal place turns a valid pressure into text such as `100.0` and `kPa`.

**Conversion popover.** The panel opened by the info button. It shows an idle, loading, invalid, compatible, or converted-values message without replacing the field.

## Values and state

**Declared unit.** The unit against which a field's expression is checked, `bar` in the covered stories. A bare number is interpreted using this unit.

**Expression.** The text evaluated by the dim runtime. A non-empty bare number is expanded to a number followed by the declared unit; text containing other characters is evaluated as entered.

**Raw value.** The exact string in the input, including a bare number or full expression. `onValueChange` receives this string rather than a parsed quantity.

**Quantity result.** The structured runtime result for a valid expression, including numeric value, display unit, dimensions, delta status, and format mode.

**Idle.** The field state when its trimmed value is empty. The conversion panel says `Enter a quantity expression.` and no result or conversions are shown.

**Loading.** The field state when it has an expression but the dim runtime is not ready. The conversion panel says `Loading unit conversions…`; no conversions are shown yet.

**Valid.** The field state when the expression evaluates and is compatible with the declared unit. The component keeps a result and computes every requested conversion.

**Invalid.** The field state when evaluation, compatibility checking, or conversion fails. The input has `aria-invalid="true"`, the group uses destructive styling, and the panel explains that the quantity is invalid.

**Compatible.** An expression has the same dimension as the declared unit. Compatibility does not require the expression to use the same spelling or scale.

## Ownership and interaction

**Controlled value.** A `value` supplied by the parent. Typing calls `onValueChange`, but the displayed field remains at the parent's supplied value until the parent changes it.

**Uncontrolled value.** The component's local copy of `defaultValue`. Typing updates what the field displays immediately.

**Field lifecycle.** The unit of interaction used here: arrive, leave untouched, begin editing, while editing, and finish editing. It describes one rendered field from initial display through edits and the resulting callbacks.

**Begin editing.** The first input change from the starting value. It may change raw value, validity, conversions, and callbacks.

**Finish editing.** The field has processed the latest input and the parent has received any callback; it does not mean the component submits or persists a record.

**Runtime readiness.** Whether the shared dim WASM runtime is ready for evaluation. The provider exposes loading, ready, or error status, while `QuantityInput` reads only the ready boolean.

**Provider.** `DimProvider`, the context wrapper that initializes the runtime and optionally replaces its children with loading or error fallback content.

## Events that end or interrupt a field lifecycle

**Cancel.** Escape or another user action abandons a transient UI action, such as closing the popover. It does not undo a text change because the component has no edit buffer separate from the input value.

**Complete.** The field completes a lifecycle step when a change has been accepted into local or parent-owned value state and the corresponding callbacks have run. It does not create a saved record.

**Interrupt.** A browser, parent, runtime, or input-channel event changes or ends the current lifecycle before the user has finished with the field.

**Leave untouched.** The field is rendered and inspected without an input change. Opening the popover in this phase reads the current idle or valid state but does not change the value.

**Input channel.** The way text reaches the field: keyboard typing, paste, autofill, a controlled parent update, or another browser input mechanism.

## Interface and surrounding systems

**Info button.** The icon-only button with the accessible label `Show converted values`. It opens and closes the conversion popover.

**Callback.** A function supplied by the parent that observes a raw value (`onValueChange`) or the structured field state (`onResultChange`). A callback is an observable integration side effect, not durable persistence.

**Locale.** The `Intl.NumberFormat` locale used to render conversion text. The covered stories use the default `en-GB` locale.

**Conversion list.** The ordered set of requested conversions. Each item contributes one result row when the field is valid; an empty list produces a compatibility message instead.

**Focus.** The browser's current text-input target. The input receives normal text focus, and clicking the non-button addon focuses the input.

**Portal.** The rendering path that places the popover content outside the input group's DOM subtree while leaving it visually attached to the trigger.

**Table integration.** The Spreadsheet story's use of three controlled `QuantityInput` instances inside table cells, with a shared array of raw values.
