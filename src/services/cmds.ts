import { invoke } from "@tauri-apps/api/core";
import dayjs from "dayjs";
import { getProxies, getProxyProviders } from "tauri-plugin-mihomo-api";

import type {
  IProfileItem,
  IProfilesConfig,
  IConfigData,
  IProxyItem,
  IProxyGroupItem,
  ILogItem,
  IVergeConfig,
} from "@/types";

// Profile commands
export async function getProfiles(): Promise<IProfilesConfig> {
  return invoke<IProfilesConfig>("get_profiles");
}

export async function patchProfilesConfig(
  profiles: IProfilesConfig,
): Promise<void> {
  return invoke<void>("patch_profiles_config", { profiles });
}

export async function createProfile(
  item: Partial<IProfileItem>,
  fileData?: string | null,
): Promise<void> {
  return invoke<void>("create_profile", { item, fileData });
}

export async function deleteProfile(index: string): Promise<void> {
  return invoke<void>("delete_profile", { index });
}

// Clash config commands
export async function getRuntimeConfig(): Promise<IConfigData | null> {
  const config = await invoke<IConfigData>("get_runtime_config");
  return config || null;
}

export async function patchClashConfig(
  payload: Partial<IConfigData>,
): Promise<void> {
  return invoke<void>("patch_clash_config", { payload });
}

export async function patchClashMode(payload: string): Promise<void> {
  return invoke<void>("patch_clash_mode", { payload });
}

// Proxy commands
export async function calcuProxies(): Promise<{
  global: IProxyGroupItem;
  direct: IProxyItem;
  groups: IProxyGroupItem[];
  records: Record<string, IProxyItem>;
  proxies: IProxyItem[];
}> {
  const [proxyResponse, providerResponse] = await Promise.all([
    getProxies(),
    calcuProxyProviders(),
  ]);

  const proxyRecord = proxyResponse.proxies;
  const providerRecord = providerResponse;

  // provider name map
  const providerMap = Object.fromEntries(
    Object.entries(providerRecord).flatMap(([provider, item]) =>
      item!.proxies.map((p) => [p.name, { ...p, provider }]),
    ),
  );

  // compatible with proxy-providers
  const generateItem = (name: string) => {
    if (proxyRecord[name]) return proxyRecord[name];
    if (providerMap[name]) return providerMap[name];
    return {
      name,
      type: "unknown",
      udp: false,
      xudp: false,
      tfo: false,
      mptcp: false,
      smux: false,
      history: [],
    };
  };

  const { GLOBAL: global, DIRECT: direct, REJECT: reject } = proxyRecord;

  let groups: IProxyGroupItem[] = Object.values(proxyRecord).reduce<
    IProxyGroupItem[]
  >((acc, each) => {
    if (each?.name !== "GLOBAL" && each?.all) {
      acc.push({
        ...each,
        all: each.all!.map((item) => generateItem(item)),
      });
    }

    return acc;
  }, []);

  if (global?.all) {
    const globalGroups: IProxyGroupItem[] = global.all.reduce<
      IProxyGroupItem[]
    >((acc, name) => {
      if (proxyRecord[name]?.all) {
        acc.push({
          ...proxyRecord[name],
          all: proxyRecord[name].all!.map((item) => generateItem(item)),
        });
      }
      return acc;
    }, []);

    const globalNames = new Set(globalGroups.map((each) => each.name));
    groups = groups
      .filter((group) => {
        return !globalNames.has(group.name);
      })
      .concat(globalGroups);
  }

  const proxies = [direct, reject].concat(
    Object.values(proxyRecord).filter(
      (p) => !p?.all?.length && p?.name !== "DIRECT" && p?.name !== "REJECT",
    ),
  );

  const _global = {
    ...global,
    all: global?.all?.map((item) => generateItem(item)) || [],
  };

  return {
    global: _global as IProxyGroupItem,
    direct: direct as IProxyItem,
    groups,
    records: proxyRecord as Record<string, IProxyItem>,
    proxies: (proxies as IProxyItem[]) ?? [],
  };
}

export async function calcuProxyProviders() {
  const providers = await getProxyProviders();
  return Object.fromEntries(
    Object.entries(providers.providers)
      .sort()
      .filter(
        ([_, item]) =>
          item?.vehicleType === "HTTP" || item?.vehicleType === "File",
      ),
  );
}

// Clash logs
export async function getClashLogs(): Promise<ILogItem[]> {
  const regex = /time="(.+?)"\s+level=(.+?)\s+msg="(.+?)"/;
  const newRegex = /(.+?)\s+(.+?)\s+(.+)/;
  const logs = await invoke<string[]>("get_clash_logs");

  return logs.reduce<ILogItem[]>((acc, log) => {
    const result = log.match(regex);
    if (result) {
      const [_, _time, type, payload] = result;
      const time = dayjs(_time).format("MM-DD HH:mm:ss");
      acc.push({ time, type, payload });
      return acc;
    }

    const result2 = log.match(newRegex);
    if (result2) {
      const [_, time, type, payload] = result2;
      acc.push({ time, type, payload });
    }
    return acc;
  }, []);
}

export async function clearLogs(): Promise<void> {
  return invoke<void>("clear_logs");
}

// Verge config
export async function getVergeConfig(): Promise<IVergeConfig> {
  return invoke<IVergeConfig>("get_verge_config");
}

export async function patchVergeConfig(
  payload: Partial<IVergeConfig>,
): Promise<void> {
  return invoke<void>("patch_verge_config", { payload });
}

// System proxy
export async function getSystemProxy(): Promise<{
  enable: boolean;
  server: string;
  bypass: string;
}> {
  return invoke<{
    enable: boolean;
    server: string;
    bypass: string;
  }>("get_sys_proxy");
}

// Running mode and uptime
export const getRunningMode = async (): Promise<string> => {
  return invoke<string>("get_running_mode");
};

export const getAppUptime = async (): Promise<number> => {
  return invoke<number>("get_app_uptime");
};

// App commands
export async function restartApp(): Promise<void> {
  return invoke<void>("restart_app");
}

export async function exitApp(): Promise<void> {
  return invoke<void>("exit_app");
}

export async function getAppDir(): Promise<string> {
  return invoke<string>("get_app_dir");
}

export async function openAppDir(): Promise<void> {
  return invoke<void>("open_app_dir").catch((err) => console.error(err));
}

