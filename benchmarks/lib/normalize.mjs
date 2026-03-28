export function normalizeDimSyntax(value) {
  return value
    .replaceAll("·", "*")
    .replaceAll("⋅", "*")
    .replaceAll("²", "^2")
    .replaceAll("³", "^3")
    .replace(
      /(^|[^\w.])([+-]?(?:\d+\.?\d*|\.\d+)[eE][+-]?\d+)(?=\s|$|[()*/+\-])/g,
      (_, prefix, numeric) => `${prefix}${expandScientificNotation(numeric)}`,
    );
}

function expandScientificNotation(value) {
  const lower = value.toLowerCase();
  if (!lower.includes("e")) {
    return value;
  }

  const sign = lower.startsWith("-") ? "-" : "";
  const unsigned =
    lower.startsWith("-") || lower.startsWith("+") ? lower.slice(1) : lower;
  const [coefficient, exponentString] = unsigned.split("e");
  const exponent = Number.parseInt(exponentString, 10);
  if (!Number.isFinite(exponent)) {
    return value;
  }

  const [integerPart, fractionPart = ""] = coefficient.split(".");
  const digits = `${integerPart}${fractionPart}`.replace(/^0+/, "") || "0";
  const decimalIndex = integerPart.length + exponent;

  if (digits === "0") {
    return "0";
  }

  if (decimalIndex <= 0) {
    return `${sign}0.${"0".repeat(Math.abs(decimalIndex))}${digits}`;
  }

  if (decimalIndex >= digits.length) {
    return `${sign}${digits}${"0".repeat(decimalIndex - digits.length)}`;
  }

  return `${sign}${digits.slice(0, decimalIndex)}.${digits.slice(decimalIndex)}`;
}
