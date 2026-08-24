import { readFileSync } from "node:fs";

import { render, screen, waitFor } from "@testing-library/react";
import { describe, expect, test } from "vitest";

import { DimProvider, useDim } from "@/components/dim-provider";
import { evalStructured } from "@/lib/dim/dim";

const wasmBytes = readFileSync("zig-out/bin/dim_wasm.wasm");

function Status() {
  const { status } = useDim();
  return <p>{status}</p>;
}

describe("DimProvider", () => {
  test("initializes the runtime and defines constants", async () => {
    render(
      <DimProvider
        initOptions={{ wasmBytes }}
        constants={[{ name: "workday", expr: "8 h" }]}
      >
        <Status />
      </DimProvider>,
    );

    expect(await screen.findByText("ready")).toBeVisible();
    await waitFor(() => {
      const result = evalStructured("2 workday as h");
      expect(result.kind).toBe("quantity");
      if (result.kind === "quantity") {
        expect(result.value).toBe(16);
        expect(result.unit).toBe("h");
      }
    });
  });
});
