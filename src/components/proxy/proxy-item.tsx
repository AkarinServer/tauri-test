import {
  Box,
  IconButton,
  ListItem,
  ListItemButton,
  ListItemText,
  Typography,
  Chip,
  Tooltip,
} from "@mui/material";
import { CheckCircle, Speed } from "@mui/icons-material";
import { useLockFn } from "ahooks";
import { useEffect, useReducer } from "react";
import { useTranslation } from "react-i18next";

import { useVerge } from "@/hooks/use-verge";
import delayManager, { type DelayUpdate } from "@/services/delay";
import type { IProxyGroupItem, IProxyItem } from "@/types";

interface Props {
  group: IProxyGroupItem;
  proxy: IProxyItem;
  selected: boolean;
  onClick?: (groupName: string, proxyName: string) => void;
}

const presetList = ["DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE"];

export const ProxyItem = (props: Props) => {
  const { group, proxy, selected, onClick } = props;
  const { t } = useTranslation();
  const { verge } = useVerge();
  const timeout = verge?.default_latency_timeout || 10000;
  const isPreset = presetList.includes(proxy.name);

  // 延迟状态管理
  const [delayState, setDelayState] = useReducer(
    (_: DelayUpdate, next: DelayUpdate) => next,
    { delay: -1, updatedAt: 0 },
  );

  // 注册延迟监听器
  useEffect(() => {
    if (isPreset) return;
    delayManager.setListener(proxy.name, group.name, setDelayState);

    return () => {
      delayManager.removeListener(proxy.name, group.name);
    };
  }, [proxy.name, group.name, isPreset]);

  // 初始化延迟值 - 不显示任何延迟，只有测试后才显示
  useEffect(() => {
    if (isPreset) return;
    // 初始状态：未测试
    setDelayState({ delay: -1, updatedAt: 0 });
  }, [proxy.name, group.name, isPreset]);

  const handleClick = () => {
    if (onClick && !selected) {
      onClick(group.name, proxy.name);
    }
  };

  const onDelay = useLockFn(async () => {
    if (isPreset) return;
    setDelayState({ delay: -2, updatedAt: Date.now() });
    const result = await delayManager.checkDelay(proxy.name, group.name, timeout);
    setDelayState(result);
  });

  const delayValue = delayState.delay;

  const formatDelay = (delayValue: number): string => {
    if (delayValue === -1) return "-";
    if (delayValue === -2) return t("proxies.item.testing");
    if (delayValue === 0 || delayValue >= timeout) return t("proxies.item.timeout");
    if (delayValue > 1e5) return t("proxies.item.error");
    return `${delayValue} ms`;
  };

  const getDelayColor = (delayValue: number): string => {
    if (delayValue < 0) return "text.secondary";
    if (delayValue === 0 || delayValue >= timeout) return "error.main";
    if (delayValue >= 10000) return "error.main";
    if (delayValue >= 400) return "warning.main";
    if (delayValue >= 250) return "primary.main";
    return "success.main";
  };

  return (
    <ListItem disablePadding>
      <ListItemButton
        onClick={handleClick}
        selected={selected}
        sx={{
          borderRadius: 1,
          "&.Mui-selected": {
            bgcolor: "action.selected",
            "&:hover": {
              bgcolor: "action.selected",
            },
          },
        }}
      >
        <Box sx={{ display: "flex", alignItems: "center", width: "100%", gap: 1 }}>
          {selected && (
            <CheckCircle color="primary" sx={{ fontSize: 20 }} />
          )}
          <ListItemText
            primary={proxy.name}
            secondary={
              <Box sx={{ display: "flex", gap: 1, mt: 0.5, alignItems: "center" }}>
                <Chip
                  label={proxy.type}
                  size="small"
                  variant="outlined"
                  sx={{ height: 20, fontSize: "0.7rem" }}
                />
                {!isPreset && delayValue !== -1 && (
                  <Typography 
                    variant="caption" 
                    color={getDelayColor(delayValue)}
                    sx={{ minWidth: 60 }}
                  >
                    {formatDelay(delayValue)}
                  </Typography>
                )}
              </Box>
            }
          />
          {!isPreset && (
            <Tooltip title={t("proxies.item.delay")}>
              <IconButton
                size="small"
                onClick={(e) => {
                  e.stopPropagation();
                  onDelay();
                }}
                disabled={delayValue === -2}
                sx={{ ml: "auto" }}
              >
                <Speed fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
        </Box>
      </ListItemButton>
    </ListItem>
  );
};

