import { useContext, createContext } from "react";
import {
  BaseConfig,
  ProxyProvider,
  Rule,
  RuleProvider,
} from "tauri-plugin-mihomo-api";

export interface AppDataContextType {
  proxies: any;
  clashConfig: BaseConfig | null;
  rules: Rule[];
  sysproxy: any;
  runningMode?: string;
  uptime: number;
  proxyProviders: Record<string, ProxyProvider>;
  ruleProviders: Record<string, RuleProvider>;
  systemProxyAddress: string;

  refreshProxy: () => Promise<any>;
  refreshClashConfig: () => Promise<any>;
  refreshRules: () => Promise<any>;
  refreshSysproxy: () => Promise<any>;
  refreshProxyProviders: () => Promise<any>;
  refreshRuleProviders: () => Promise<any>;
  refreshAll: () => Promise<any>;
}

export const AppDataContext = createContext<AppDataContextType | null>(null);

export const useAppData = () => {
  const context = useContext(AppDataContext);
  if (!context) {
    throw new Error("useAppData must be used within AppDataProvider");
  }
  return context;
};

