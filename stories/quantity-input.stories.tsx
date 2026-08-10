import { useState } from "react";
import type { Meta, StoryObj } from "@storybook/react-vite";
import { expect, userEvent, within } from "storybook/test";

import { DimProvider } from "@/components/dim-provider";
import { QuantityInput } from "@/components/quantity-input";

const pressureConversions = [
  { unit: "bar", label: "bara", decimalPlaces: 3 },
  { unit: "kPa", decimalPlaces: 1 },
  { unit: "psi", decimalPlaces: 2 },
];

const meta = {
  title: "dim/QuantityInput",
  component: QuantityInput,
  decorators: [
    (Story) => (
      <DimProvider loadingFallback={<p>Loading dim…</p>}>
        <div className="w-96">
          <Story />
        </div>
      </DimProvider>
    ),
  ],
  args: {
    unit: "bar",
    defaultValue: "1 bar",
    conversions: pressureConversions,
  },
} satisfies Meta<typeof QuantityInput>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(await canvas.findByRole("button", { name: /converted values/i }));
    await expect(await within(document.body).findByText("100.0")).toBeVisible();
    await expect(await within(document.body).findByText("kPa")).toBeVisible();
  },
};

export const Invalid: Story = {
  args: {
    defaultValue: "12 kg",
  },
};

export const Spreadsheet: Story = {
  render: () => {
    const [values, setValues] = useState(["1 bar", "250 kPa", "14.5 psi"]);
    return (
      <table className="w-2xl border-collapse">
        <thead>
          <tr>
            <th className="border p-2 text-left">Node</th>
            <th className="border p-2 text-left">Pressure</th>
          </tr>
        </thead>
        <tbody>
          {values.map((value, index) => (
            <tr key={index}>
              <td className="border px-2 font-mono">P-{index + 1}</td>
              <td className="border p-0">
                <QuantityInput
                  unit="bar"
                  value={value}
                  conversions={pressureConversions}
                  groupClassName="-m-px w-[calc(100%+2px)]"
                  onValueChange={(nextValue) =>
                    setValues((current) =>
                      current.map((item, itemIndex) =>
                        itemIndex === index ? nextValue : item,
                      ),
                    )
                  }
                />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    );
  },
};
