// Basic types for RV Verge
// Types will be expanded as needed

export interface IProfileItem {
  uid: string;
  type?: string;
  name?: string;
  desc?: string;
  file?: string;
  url?: string;
  selected?: string[];
  updated?: number;
  extra?: Record<string, any>;
}

export interface IProfilesConfig {
  current?: string;
  items?: IProfileItem[];
}

export interface IVergeConfig {
  theme_mode?: "light" | "dark" | "system";
  theme_blur?: boolean;
  traffic_graph?: boolean;
  enable_clash_fields?: boolean;
  verge_mixed_port?: number;
  enable_auto_launch?: boolean;
  enable_service_mode?: boolean;
  enable_silent_start?: boolean;
  enable_system_proxy?: boolean;
  enable_proxy_guard?: boolean;
  system_proxy_bypass?: string;
  proxy_auto_config?: boolean;
  proxy_host?: string;
  proxy_port?: number;
  [key: string]: any;
}

export interface IClashInfo {
  version?: string;
  premium?: boolean;
  [key: string]: any;
}

export interface IConfigData {
  port?: number;
  "socks-port"?: number;
  "mixed-port"?: number;
  "allow-lan"?: boolean;
  mode?: "rule" | "global" | "direct";
  "log-level"?: string;
  [key: string]: any;
}

export interface IProxyItem {
  name: string;
  type: string;
  udp?: boolean;
  xudp?: boolean;
  tfo?: boolean;
  mptcp?: boolean;
  smux?: boolean;
  history?: Array<{ time: string; delay: number }>;
  all?: string[];
  now?: string;
  [key: string]: any;
}

export interface IProxyGroupItem extends IProxyItem {
  all: IProxyItem[];
}

export interface ILogItem {
  time: string;
  type: string;
  payload: string;
}

export interface IConnectionsItem {
  id: string;
  metadata: {
    network: string;
    type: string;
    sourceIP: string;
    destinationIP: string;
    sourcePort: string;
    destinationPort: string;
    host: string;
    dnsMode: string;
    uid?: number;
    process?: string;
    processPath?: string;
    specialProxy?: string;
  };
  upload: number;
  download: number;
  start: string;
  chains: string[];
  rule: string;
  rulePayload: string;
}

export interface INetworkInterface {
  name: string;
  address: string;
}

export interface IWebDavFile {
  href: string;
  filename?: string;
  modificationTime?: string;
  contentLength?: number;
}

export interface ILocalBackupFile {
  filename: string;
  time: number;
  size: number;
}

export interface IProfileOption {
  with_proxy?: boolean;
  [key: string]: any;
}

