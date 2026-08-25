"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

import {
  defineConst,
  initDim,
  recoverDim,
  type DimInitOptions,
} from "@/lib/dim/dim";

export type DimConstant = {
  name: string;
  expr: string;
};

export type DimContextValue = {
  ready: boolean;
  status: "loading" | "ready" | "error";
  error: Error | null;
  retry: () => void;
};

const DimContext = createContext<DimContextValue | null>(null);

export type DimProviderProps = {
  children: ReactNode;
  constants?: DimConstant[];
  initOptions?: DimInitOptions;
  loadingFallback?: ReactNode;
  errorFallback?:
    | ReactNode
    | ((error: Error, retry: () => void) => ReactNode);
};

export function DimProvider({
  children,
  constants = [],
  initOptions,
  loadingFallback,
  errorFallback,
}: DimProviderProps) {
  const optionsRef = useRef(initOptions);
  const constantsRef = useRef(constants);
  const constantsKey = JSON.stringify(constants);
  const constantsKeyRef = useRef(constantsKey);
  const appliedConstantsKeyRef = useRef<string | null>(null);
  const [state, setState] = useState<{
    status: DimContextValue["status"];
    error: Error | null;
  }>({ status: "loading", error: null });
  const [retryKey, setRetryKey] = useState(0);

  optionsRef.current = initOptions;
  constantsRef.current = constants;
  constantsKeyRef.current = constantsKey;

  const applyConstants = () => {
    for (const constant of constantsRef.current) {
      defineConst(constant.name, constant.expr);
    }
    appliedConstantsKeyRef.current = constantsKeyRef.current;
  };

  useEffect(() => {
    let active = true;
    appliedConstantsKeyRef.current = null;
    setState({ status: "loading", error: null });

    const initialize = retryKey === 0 ? initDim : recoverDim;
    void initialize(optionsRef.current)
      .then(() => {
        if (!active) return;
        try {
          // Do not expose ready until provider constants are available.
          applyConstants();
          setState({ status: "ready", error: null });
        } catch (cause) {
          const error =
            cause instanceof Error ? cause : new Error("Failed to define dim constants");
          setState({ status: "error", error });
        }
      })
      .catch((cause: unknown) => {
        if (!active) return;
        const error =
          cause instanceof Error ? cause : new Error("Failed to initialize dim");
        setState({ status: "error", error });
      });

    return () => {
      active = false;
    };
  }, [retryKey]);

  useEffect(() => {
    if (
      state.status !== "ready" ||
      appliedConstantsKeyRef.current === constantsKey
    ) {
      return;
    }

    try {
      applyConstants();
    } catch (cause) {
      const error =
        cause instanceof Error ? cause : new Error("Failed to define dim constants");
      setState({ status: "error", error });
    }
  }, [constantsKey, state.status]);

  const retry = useCallback(() => {
    setRetryKey((key) => key + 1);
  }, []);

  const value = useMemo<DimContextValue>(
    () => ({
      ready: state.status === "ready",
      status: state.status,
      error: state.error,
      retry,
    }),
    [retry, state],
  );

  let content = children;
  if (state.status === "loading" && loadingFallback !== undefined) {
    content = loadingFallback;
  } else if (state.status === "error" && state.error && errorFallback !== undefined) {
    content =
      typeof errorFallback === "function"
        ? errorFallback(state.error, retry)
        : errorFallback;
  }

  return <DimContext.Provider value={value}>{content}</DimContext.Provider>;
}

export function useDim(): DimContextValue {
  const context = useContext(DimContext);
  if (!context) {
    throw new Error("useDim must be used within a DimProvider");
  }
  return context;
}
