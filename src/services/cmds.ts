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
  IProfileOption,
} from "@/types";

// Re-export types for convenience
export type { IProfileItem, IProfilesConfig };

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

export async function switchProfile(index: string): Promise<boolean> {
  return invoke<boolean>("patch_profiles_config_by_profile_index", { profileIndex: index });
}

export async function importProfile(
  url: string,
  option?: IProfileOption,
): Promise<void> {
  return invoke<void>("import_profile", {
    url,
    option: option || { with_proxy: true },
  });
}

export async function updateProfile(
  index: string,
  option?: IProfileOption,
): Promise<void> {
  return invoke<void>("update_profile", { index, option });
}

export async function patchProfile(
  index: string,
  profile: Partial<IProfileItem>,
): Promise<void> {
  return invoke<void>("patch_profile", { index, profile });
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

export async function syncTrayProxySelection(): Promise<void> {
  return invoke<void>("sync_tray_proxy_selection");
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
  // 后端返回的是毫秒，转换为秒
  const milliseconds = await invoke<number>("get_app_uptime");
  return Math.floor(milliseconds / 1000);
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

export async function clearAllData(): Promise<void> {
  return invoke<void>("clear_all_data");
}

// System commands
export async function getAppVersion(): Promise<string> {
  return invoke<string>("get_app_version");
}

// Core commands
export async function startCore(): Promise<void> {
  return invoke<void>("start_core");
}

export async function stopCore(): Promise<void> {
  return invoke<void>("stop_core");
}

export async function restartCore(): Promise<void> {
  return invoke<void>("restart_core");
}

