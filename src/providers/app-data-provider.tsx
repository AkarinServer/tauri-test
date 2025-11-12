import { listen } from "@tauri-apps/api/event";
import React, { useCallback, useEffect, useMemo } from "react";
import useSWR from "swr";
import {
  getBaseConfig,
  getRuleProviders,
  getRules,
} from "tauri-plugin-mihomo-api";

import { useVerge } from "@/hooks/use-verge";
import {
  calcuProxies,
  calcuProxyProviders,
  getAppUptime,
  getRuntimeConfig,
  getRunningMode,
  getSystemProxy,
} from "@/services/cmds";
import { SWR_DEFAULTS, SWR_REALTIME, SWR_SLOW_POLL } from "@/services/config";

import { AppDataContext, AppDataContextType } from "./app-data-context";

export const AppDataProvider = ({
  children,
}: {
  children: React.ReactNode;
}) => {
  const { verge } = useVerge();

  const { data: proxiesData, mutate: refreshProxy } = useSWR(
    "getProxies",
    async () => {
      try {
        return await calcuProxies();
      } catch (error) {
        console.warn("[DataProvider] calcuProxies failed:", error);
        // Return default proxy structure
        return {
          global: {
            name: "GLOBAL",
            type: "select",
            all: [],
            now: "",
          },
          direct: {
            name: "DIRECT",
            type: "direct",
          },
          groups: [],
          records: {},
          proxies: [],
        };
      }
    },
    {
      ...SWR_REALTIME,
      onError: (err) => console.warn("[DataProvider] Proxy fetch failed:", err),
    },
  );

  const { data: clashConfig, mutate: refreshClashConfig } = useSWR(
    "getClashConfig",
    async () => {
      try {
        // Try to get config from mihomo API first
        return await getBaseConfig();
      } catch (error) {
        console.warn("[DataProvider] getBaseConfig failed, using runtime config:", error);
        // Fallback to runtime config from Rust backend
        try {
          return await getRuntimeConfig();
        } catch (err) {
          console.warn("[DataProvider] getRuntimeConfig failed:", err);
          // Return default config as last resort
          return {
            port: 7890,
            "socks-port": 7891,
            "mixed-port": 7897,
            "allow-lan": false,
            mode: "rule",
            "log-level": "info",
          } as any;
        }
      }
    },
    SWR_SLOW_POLL,
  );

  const { data: proxyProviders, mutate: refreshProxyProviders } = useSWR(
    "getProxyProviders",
    async () => {
      try {
        return await calcuProxyProviders();
      } catch (error) {
        console.warn("[DataProvider] calcuProxyProviders failed:", error);
        return {};
      }
    },
    SWR_DEFAULTS,
  );

  const { data: ruleProviders, mutate: refreshRuleProviders } = useSWR(
    "getRuleProviders",
    async () => {
      try {
        return await getRuleProviders();
      } catch (error) {
        console.warn("[DataProvider] getRuleProviders failed:", error);
        return { providers: {} } as any;
      }
    },
    SWR_DEFAULTS,
  );

  const { data: rulesData, mutate: refreshRules } = useSWR(
    "getRules",
    async () => {
      try {
        return await getRules();
      } catch (error) {
        console.warn("[DataProvider] getRules failed:", error);
        return { rules: [] } as any;
      }
    },
    SWR_DEFAULTS,
  );

  useEffect(() => {
    let isUnmounted = false;
    const cleanupFns: Array<() => void> = [];

    const registerCleanup = (fn: () => void) => {
      if (isUnmounted) {
        try {
          fn();
        } catch (error) {
          console.error("[DataProvider] Immediate cleanup failed:", error);
        }
      } else {
        cleanupFns.push(fn);
      }
    };

    const handleRefreshClash = () => {
      refreshProxy().catch((error) =>
        console.error("[DataProvider] Proxy refresh failed:", error),
      );
    };

    const handleRefreshProxy = () => {
      refreshProxy().catch((error) =>
        console.warn("[DataProvider] Proxy refresh failed:", error),
      );
    };

    const initializeListeners = async () => {
      try {
        const unlistenClash = await listen(
          "verge://refresh-clash-config",
          handleRefreshClash,
        );
        const unlistenProxy = await listen(
          "verge://refresh-proxy-config",
          handleRefreshProxy,
        );

        registerCleanup(() => {
          unlistenClash();
          unlistenProxy();
        });
      } catch (error) {
        console.warn("[AppDataProvider] 设置 Tauri 事件监听器失败:", error);
      }
    };

    void initializeListeners();

    return () => {
      isUnmounted = true;
      cleanupFns.splice(0).forEach((fn) => {
        try {
          fn();
        } catch (error) {
          console.error("[DataProvider] Cleanup error:", error);
        }
      });
    };
  }, [refreshProxy]);

  const { data: sysproxy, mutate: refreshSysproxy } = useSWR(
    "getSystemProxy",
    getSystemProxy,
    SWR_DEFAULTS,
  );

  const { data: runningMode } = useSWR(
    "getRunningMode",
    getRunningMode,
    SWR_DEFAULTS,
  );

  const { data: uptimeData } = useSWR("appUptime", getAppUptime, {
    ...SWR_DEFAULTS,
    refreshInterval: 3000,
    errorRetryCount: 1,
  });

  const refreshAll = useCallback(async () => {
    await Promise.all([
      refreshProxy(),
      refreshClashConfig(),
      refreshRules(),
      refreshSysproxy(),
      refreshProxyProviders(),
      refreshRuleProviders(),
    ]);
  }, [
    refreshProxy,
    refreshClashConfig,
    refreshRules,
    refreshSysproxy,
    refreshProxyProviders,
    refreshRuleProviders,
  ]);

  const value = useMemo(() => {
    const calculateSystemProxyAddress = () => {
      if (!verge || !clashConfig) return "-";

      const isPacMode = verge.proxy_auto_config ?? false;

      if (isPacMode) {
        const proxyHost = verge.proxy_host || "127.0.0.1";
        const proxyPort =
          verge.verge_mixed_port || clashConfig.mixedPort || 7897;
        return `${proxyHost}:${proxyPort}`;
      } else {
        const systemServer = sysproxy?.server;
        if (
          systemServer &&
          systemServer !== "-" &&
          !systemServer.startsWith(":")
        ) {
          return systemServer;
        } else {
          const proxyHost = verge.proxy_host || "127.0.0.1";
          const proxyPort =
            verge.verge_mixed_port || clashConfig.mixedPort || 7897;
          return `${proxyHost}:${proxyPort}`;
        }
      }
    };

    return {
      proxies: proxiesData,
      clashConfig: clashConfig || null,
      rules: rulesData?.rules || [],
      sysproxy,
      runningMode,
      uptime: uptimeData || 0,
      proxyProviders: proxyProviders || {},
      ruleProviders: ruleProviders?.providers || {},
      systemProxyAddress: calculateSystemProxyAddress(),
      refreshProxy,
      refreshClashConfig,
      refreshRules,
      refreshSysproxy,
      refreshProxyProviders,
      refreshRuleProviders,
      refreshAll,
    } as AppDataContextType;
  }, [
    proxiesData,
    clashConfig,
    rulesData,
    sysproxy,
    runningMode,
    uptimeData,
    proxyProviders,
    ruleProviders,
    verge,
    refreshProxy,
    refreshClashConfig,
    refreshRules,
    refreshSysproxy,
    refreshProxyProviders,
    refreshRuleProviders,
    refreshAll,
  ]);

  return (
    <AppDataContext.Provider value={value}>{children}</AppDataContext.Provider>
  );
};
