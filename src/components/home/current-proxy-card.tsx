import { Box, Chip, Typography } from "@mui/material";
import { useTranslation } from "react-i18next";

import { useAppData } from "@/providers/app-data-context";

export const CurrentProxyCard = () => {
  const { t } = useTranslation();
  const { proxies, clashConfig } = useAppData();

  const mode = clashConfig?.mode?.toLowerCase() || "rule";
  const globalProxy = proxies?.global;

  const getCurrentProxyName = () => {
    if (mode === "global") {
      return globalProxy?.now || t("home.components.currentProxy.labels.globalMode");
    }
    if (mode === "direct") {
      return t("home.components.currentProxy.labels.directMode");
    }
    // rule mode - show current proxy from global group
    return globalProxy?.now || t("home.components.currentProxy.labels.noActiveNode");
  };

  return (
    <Box sx={{ display: "flex", flexDirection: "column", gap: 2 }}>
      <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
        <Typography variant="body2" color="text.secondary">
          {t("home.components.currentProxy.labels.group")}
        </Typography>
        <Chip
          label={globalProxy?.name || "GLOBAL"}
          color="primary"
          variant="outlined"
          size="small"
        />
      </Box>
      <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
        <Typography variant="body2" color="text.secondary">
          {t("home.components.currentProxy.labels.proxy")}
        </Typography>
        <Typography variant="body1" fontWeight="medium">
          {getCurrentProxyName()}
        </Typography>
      </Box>
    </Box>
  );
};

