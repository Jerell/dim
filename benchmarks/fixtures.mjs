export const compatibilityFixtures = [
  { expr: "1 mm", unit: "mi", expected: true },
  { expr: "1 m", unit: "C", expected: false },
  { expr: "1.43567576391605e-5 Pa·s", unit: "Pa*s", expected: true },
];

export const sameDimensionFixtures = [
  { lhs: "1 km", rhs: "1 ft", expected: true },
  { lhs: "1 m", rhs: "1 m/s", expected: false },
  { lhs: "2", rhs: "4", expected: true },
];

export const convertValueFixtures = [
  { value: 1, fromUnit: "m", toUnit: "km", expected: 0.001 },
  { value: 1, fromUnit: "C", toUnit: "F", expected: 33.8 },
  { value: 1000, fromUnit: "Pa", toUnit: "bar", expected: 0.01 },
];

export const convertExprFixtures = [
  { expr: "18 kJ / 3 kg", unit: "kJ/kg", expectedValue: 6, expectedUnit: "kJ/kg" },
  { expr: "1 m", unit: "km", expectedValue: 0.001, expectedUnit: "km" },
  { expr: "1.43567576391605e-5 Pa·s", unit: "Pa*s", expectedValue: 1.43567576391605e-5, expectedUnit: "Pa*s" },
];

export const tooltipFanoutCase = {
  expression: "250000 Pa",
  units: ["Pa", "kPa", "MPa", "bar", "psi"],
};

export const tableBatchCase = [
  { expr: "20 C", unit: "degC" },
  { expr: "1 bar", unit: "Pa" },
  { expr: "1000 kg/m^3", unit: "kg/m^3" },
  { expr: "15 m/s", unit: "m/s" },
  { expr: "18 kJ / 3 kg", unit: "kJ/kg" },
  { expr: "1.43567576391605e-5 Pa·s", unit: "Pa*s" },
  { expr: "1 m", unit: "km" },
  { expr: "100 K", unit: "degC" },
];

export const plotBatchCase = Array.from({ length: 128 }, (_, index) => ({
  value: index + 1,
  fromUnit: "m/s",
  toUnit: "km/h",
}));
