"use client";

import {
  Fragment,
  forwardRef,
  useEffect,
  useMemo,
  useState,
  type ComponentProps,
} from "react";
import { InfoIcon } from "lucide-react";

import { useDim } from "@/components/dim-provider";
import {
  InputGroup,
  InputGroupAddon,
  InputGroupButton,
  InputGroupInput,
} from "@/components/ui/input-group";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import {
  batchConvertExprs,
  evalStructured,
  isCompatible,
  type DimEvalResult,
} from "@/lib/dim/dim";
import { cn } from "@/lib/utils";

export type QuantityConversion = {
  unit: string;
  label?: string;
  decimalPlaces?: number;
};

export type QuantityConversionResult = QuantityConversion & {
  value: number;
  text: string;
};

export type QuantityInputState = {
  status: "idle" | "loading" | "valid" | "invalid";
  expression?: string;
  result?: DimEvalResult;
  conversions: QuantityConversionResult[];
  error?: Error;
};

export type QuantityInputProps = Omit<
  ComponentProps<typeof InputGroupInput>,
  "defaultValue" | "value"
> & {
  unit: string;
  value?: string;
  defaultValue?: string;
  conversions?: QuantityConversion[];
  locale?: string;
  groupClassName?: string;
  infoLabel?: string;
  onValueChange?: (value: string) => void;
  onResultChange?: (state: QuantityInputState) => void;
};

function toExpression(value: string, unit: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  return Number.isFinite(Number(trimmed)) ? `${trimmed} ${unit}` : trimmed;
}

function formatConversionValue(
  value: number,
  conversion: QuantityConversion,
  locale: string,
): string {
  return new Intl.NumberFormat(locale, {
    maximumFractionDigits: conversion.decimalPlaces ?? 6,
    minimumFractionDigits: conversion.decimalPlaces,
    useGrouping: false,
  }).format(value);
}

const EMPTY_STATE: QuantityInputState = {
  status: "idle",
  conversions: [],
};
const EMPTY_CONVERSIONS: QuantityConversion[] = [];

export const QuantityInput = forwardRef<
  HTMLInputElement,
  QuantityInputProps
>(function QuantityInput(
  {
    unit,
    value: controlledValue,
    defaultValue = "",
    conversions = EMPTY_CONVERSIONS,
    locale = "en-GB",
    className,
    groupClassName,
    infoLabel = "Show converted values",
    onChange,
    onValueChange,
    onResultChange,
    ...inputProps
  },
  ref,
) {
  const { ready } = useDim();
  const [uncontrolledValue, setUncontrolledValue] = useState(defaultValue);
  const [state, setState] = useState<QuantityInputState>(EMPTY_STATE);
  const value = controlledValue ?? uncontrolledValue;
  const expression = useMemo(() => toExpression(value, unit), [unit, value]);

  useEffect(() => {
    if (!expression) {
      setState(EMPTY_STATE);
      return;
    }
    if (!ready) {
      setState({ status: "loading", expression, conversions: [] });
      return;
    }

    try {
      const result = evalStructured(expression);
      if (!isCompatible(expression, unit)) {
        throw new Error(`Not compatible with ${unit}`);
      }

      const values = batchConvertExprs(
        conversions.map((conversion) => ({
          expr: expression,
          unit: conversion.unit,
        })),
      );
      setState({
        status: "valid",
        expression,
        result,
        conversions: conversions.map((conversion, index) => ({
          ...conversion,
          value: values[index],
          text: formatConversionValue(values[index], conversion, locale),
        })),
      });
    } catch (cause) {
      const error =
        cause instanceof Error ? cause : new Error(`Not compatible with ${unit}`);
      setState({ status: "invalid", expression, conversions: [], error });
    }
  }, [conversions, expression, locale, ready, unit]);

  useEffect(() => {
    onResultChange?.(state);
  }, [onResultChange, state]);

  return (
    <InputGroup
      data-status={state.status}
      className={cn(
        "h-9 rounded-none shadow-none",
        state.status === "invalid" &&
          "border-destructive focus-within:ring-destructive/20",
        groupClassName,
      )}
    >
      <InputGroupInput
        {...inputProps}
        ref={ref}
        type="text"
        value={value}
        autoComplete="off"
        aria-invalid={state.status === "invalid" || undefined}
        className={cn(
          "rounded-none text-right font-mono tabular-nums",
          className,
        )}
        onChange={(event) => {
          if (controlledValue === undefined) {
            setUncontrolledValue(event.currentTarget.value);
          }
          onChange?.(event);
          onValueChange?.(event.currentTarget.value);
        }}
      />
      <InputGroupAddon align="inline-start" className="pl-1">
        <Popover>
          <PopoverTrigger
            render={
              <InputGroupButton
                type="button"
                variant="ghost"
                size="icon-xs"
                className="rounded-none"
                aria-label={infoLabel}
              />
            }
          >
            <InfoIcon aria-hidden="true" />
          </PopoverTrigger>
          <PopoverContent
            align="start"
            className="w-fit min-w-36 rounded-lg p-3 text-sm"
          >
            <ConversionPanel state={state} unit={unit} />
          </PopoverContent>
        </Popover>
      </InputGroupAddon>
    </InputGroup>
  );
});

function ConversionPanel({ state, unit }: { state: QuantityInputState; unit: string }) {
  if (state.status === "idle") {
    return <p className="text-muted-foreground">Enter a quantity expression.</p>;
  }
  if (state.status === "loading") {
    return <p className="text-muted-foreground">Loading unit conversions…</p>;
  }
  if (state.status === "invalid") {
    return (
      <div className="space-y-1">
        <p className="font-medium text-destructive">Invalid quantity</p>
        <p className="text-muted-foreground">{state.error?.message ?? `Not compatible with ${unit}`}</p>
      </div>
    );
  }
  if (state.conversions.length === 0) {
    return <p className="text-muted-foreground">Compatible with {unit}.</p>;
  }

  return (
    <div className="space-y-2">
      <p className="font-medium">Converted values</p>
      <dl className="grid grid-cols-[1fr_auto] gap-x-3 gap-y-1">
        {state.conversions.map((conversion) => (
          <Fragment key={`${conversion.unit}-${conversion.label ?? ""}`}>
            <dd className="text-right font-mono tabular-nums">{conversion.text}</dd>
            <dt className="whitespace-nowrap text-muted-foreground">
              {conversion.label ?? conversion.unit}
            </dt>
          </Fragment>
        ))}
      </dl>
    </div>
  );
}

QuantityInput.displayName = "QuantityInput";
