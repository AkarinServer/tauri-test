import { Stack, Typography, Divider } from "@mui/material";
import { useTranslation } from "react-i18next";

import { useAppData } from "@/providers/app-data-context";
import { useVerge } from "@/hooks/use-verge";

export const SystemInfoCard = () => {
  const { t } = useTranslation();
  const { runningMode, uptime, systemProxyAddress } = useAppData();
  const { verge } = useVerge();

  const formatUptime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  };

  return (
    <Stack spacing={1.5}>
      {runningMode && (
        <>
          <Stack direction="row" justifyContent="space-between">
            <Typography variant="body2" color="text.secondary">
              {t("home.components.systemInfo.fields.runningMode")}
            </Typography>
            <Typography variant="body2" fontWeight="medium">
              {runningMode}
            </Typography>
          </Stack>
          <Divider />
        </>
      )}
      {uptime > 0 && (
        <>
          <Stack direction="row" justifyContent="space-between">
            <Typography variant="body2" color="text.secondary">
              {t("home.components.clashInfo.fields.uptime")}
            </Typography>
            <Typography variant="body2" fontWeight="medium">
              {formatUptime(uptime)}
            </Typography>
          </Stack>
          <Divider />
        </>
      )}
      {systemProxyAddress && systemProxyAddress !== "-" && (
        <>
          <Stack direction="row" justifyContent="space-between">
            <Typography variant="body2" color="text.secondary">
              {t("home.components.clashInfo.fields.systemProxyAddress")}
            </Typography>
            <Typography variant="body2" fontWeight="medium">
              {systemProxyAddress}
            </Typography>
          </Stack>
          <Divider />
        </>
      )}
      {verge?.verge_mixed_port && (
        <Stack direction="row" justifyContent="space-between">
          <Typography variant="body2" color="text.secondary">
            {t("home.components.clashInfo.fields.mixedPort")}
          </Typography>
          <Typography variant="body2" fontWeight="medium">
            {verge.verge_mixed_port}
          </Typography>
        </Stack>
      )}
    </Stack>
  );
};

