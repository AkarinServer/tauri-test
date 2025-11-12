import useSWR from "swr";

import type { IVergeConfig } from "@/types";
import { getVergeConfig, patchVergeConfig } from "@/services/cmds";
import { SWR_DEFAULTS } from "@/services/config";

export const useVerge = () => {
  const { data: verge, mutate: mutateVerge } = useSWR(
    "getVergeConfig",
    async () => {
      const config = await getVergeConfig();
      return config;
    },
    SWR_DEFAULTS,
  );

  const patchVerge = async (value: Partial<IVergeConfig>) => {
    await patchVergeConfig(value);
    mutateVerge();
  };

  return {
    verge,
    mutateVerge,
    patchVerge,
  };
};

