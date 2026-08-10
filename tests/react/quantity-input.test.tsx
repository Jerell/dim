import { readFileSync } from "node:fs";

import { render, screen, waitFor } from "@testing-library/react";
import type { ComponentProps } from "react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test, vi } from "vitest";

import { DimProvider } from "@/components/dim-provider";
import { QuantityInput } from "@/components/quantity-input";

const wasmBytes = readFileSync("zig-out/bin/dim_wasm.wasm");

function renderQuantityInput(
  props: Partial<ComponentProps<typeof QuantityInput>> = {},
) {
  return render(
    <DimProvider initOptions={{ wasmBytes }}>
      <QuantityInput
        aria-label="Pressure"
        unit="bar"
        conversions={[
          { unit: "kPa", decimalPlaces: 1 },
          { unit: "psi", decimalPlaces: 2 },
        ]}
        {...props}
      />
    </DimProvider>,
  );
}

describe("QuantityInput", () => {
  test("converts a valid expression in the info popover", async () => {
    const user = userEvent.setup();
    const onResultChange = vi.fn();
    renderQuantityInput({ defaultValue: "1 bar", onResultChange });

    const input = await screen.findByRole("textbox", { name: "Pressure" });
    await waitFor(() => expect(input).not.toHaveAttribute("aria-invalid"));
    await user.click(screen.getByRole("button", { name: /converted values/i }));

    expect(await screen.findByText("100.0")).toBeVisible();
    expect(screen.getByText("kPa")).toBeVisible();
    expect(screen.getByText("14.50")).toBeVisible();
    expect(screen.getByText("psi")).toBeVisible();
    const conversionGrid = screen.getByText("100.0").closest("dl");
    expect(conversionGrid).toHaveClass("grid-cols-[1fr_auto]");
    expect(conversionGrid?.firstElementChild).toHaveTextContent("100.0");
    expect(conversionGrid?.firstElementChild?.nextElementSibling).toHaveTextContent(
      "kPa",
    );
    expect(onResultChange).toHaveBeenCalledWith(
      expect.objectContaining({ status: "valid", expression: "1 bar" }),
    );
  });

  test("marks incompatible input invalid and keeps square edges", async () => {
    const user = userEvent.setup();
    renderQuantityInput();

    const input = await screen.findByRole("textbox", { name: "Pressure" });
    await user.type(input, "12 kg");
    await waitFor(() => expect(input).toHaveAttribute("aria-invalid", "true"));
    expect(input).toHaveClass("text-right");
    expect(input.closest("[data-slot='input-group']")).toHaveClass("rounded-none");
    expect(input.closest("[data-slot='input-group']")).toHaveClass(
      "has-[[data-slot=input-group-control]:focus-visible]:z-10",
    );
    expect(
      input
        .closest("[data-slot='input-group']")
        ?.querySelector("[data-align='inline-end']"),
    ).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /converted values/i }));
    expect(await screen.findByText("Invalid quantity")).toBeVisible();
    expect(screen.getByText("Not compatible with bar")).toBeVisible();
  });

  test("emits raw controlled values", async () => {
    const user = userEvent.setup();
    const onValueChange = vi.fn();
    renderQuantityInput({ value: "1", onValueChange });

    const input = await screen.findByRole("textbox", { name: "Pressure" });
    await user.type(input, "2");
    expect(onValueChange).toHaveBeenLastCalledWith("12");
    expect(input).toHaveValue("1");
  });
});
