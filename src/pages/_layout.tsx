import { Box, List, Paper, ThemeProvider, createTheme } from "@mui/material";
import { Outlet } from "react-router";
import { useTranslation } from "react-i18next";
import { SWRConfig } from "swr";
import { useEffect, useState } from "react";

import { BaseErrorBoundary } from "@/components/base";
import { LayoutItem } from "@/components/layout/layout-item";
import { LayoutTraffic } from "@/components/layout/layout-traffic";
import { useThemeMode } from "@/services/states";
import { getAppVersion } from "@/services/cmds";
import { navItems } from "./_routers";

const Layout = () => {
  const [appVersion, setAppVersion] = useState<string>("RV Verge");
  let mode: "light" | "dark" = "light";
  try {
    mode = useThemeMode();
  } catch (error) {
    console.error("[Layout] useThemeMode failed:", error);
  }

  const { t } = useTranslation();
  const theme = createTheme({
    palette: {
      mode: mode === "light" ? "light" : "dark",
    },
  });

  // 获取应用版本号
  useEffect(() => {
    getAppVersion()
      .then((version) => {
        setAppVersion(version);
      })
      .catch((error) => {
        console.error("[Layout] Failed to get app version:", error);
        // 保持默认值 "RV Verge"
      });
  }, []);

  return (
    <SWRConfig
      value={{
        errorRetryCount: 3,
        errorRetryInterval: 5000,
        onError: (error, key) => {
          console.error(`[SWR Error] Key: ${key}, Error:`, error);
        },
        dedupingInterval: 2000,
      }}
    >
      <ThemeProvider theme={theme}>
        <Paper
          square
          elevation={0}
          sx={{
            width: "100vw",
            height: "100vh",
            maxWidth: "100vw",
            maxHeight: "100vh",
            display: "flex",
            flexDirection: "column",
            backgroundColor: mode === "dark" ? "#121212" : "#ffffff",
            overflow: "hidden",
            margin: 0,
            padding: 0,
            boxSizing: "border-box",
            /* 禁用所有滚动条 */
            "&::-webkit-scrollbar": {
              display: "none",
            },
            scrollbarWidth: "none", /* Firefox */
            msOverflowStyle: "none", /* IE/Edge */
            /* 优化窗口调整性能 */
            willChange: "contents",
            /* 确保 body 和 html 也没有滚动条 */
            "& *": {
              "&::-webkit-scrollbar": {
                display: "none",
              },
            },
          }}
        >
          <Box
            sx={{
              display: "flex",
              flex: 1,
              overflow: "hidden",
              minWidth: 0,
              minHeight: 0,
              /* 优化窗口调整性能 */
              willChange: "contents",
            }}
          >
            {/* 左侧边栏 */}
            <Box
              sx={{
                flex: "0 0 200px",
                display: "flex",
                flexDirection: "column",
                borderRight: "1px solid",
                borderColor: "divider",
                overflow: "hidden",
                userSelect: "none",
              }}
            >
              {/* Logo 区域 */}
              <Box
                sx={{
                  flex: "0 0 58px",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  padding: "0 20px",
                  borderBottom: "1px solid",
                  borderColor: "divider",
                }}
              >
                <Box
                  sx={{
                    fontSize: "18px",
                    fontWeight: "bold",
                    color: "text.primary",
                  }}
                >
                  {appVersion}
                </Box>
              </Box>

              {/* 导航菜单 */}
              <List
                sx={{
                  flex: 1,
                  overflow: "hidden",
                  overflowY: "auto",
                  paddingTop: "4px",
                  /* 隐藏滚动条但保留滚动功能（仅用于菜单） */
                  "&::-webkit-scrollbar": {
                    width: "4px",
                  },
                  "&::-webkit-scrollbar-thumb": {
                    backgroundColor: "rgba(0, 0, 0, 0.2)",
                    borderRadius: "2px",
                  },
                  scrollbarWidth: "thin", /* Firefox */
                }}
              >
                {navItems.map((item) => (
                  <LayoutItem
                    key={item.path}
                    to={item.path}
                    icon={item.icon}
                  >
                    {t(item.label)}
                  </LayoutItem>
                ))}
              </List>

              {/* 流量显示 */}
              <Box
                sx={{
                  flex: "0 0 auto",
                  padding: "12px 20px",
                  borderTop: "1px solid",
                  borderColor: "divider",
                }}
              >
                <LayoutTraffic />
              </Box>
            </Box>

            {/* 右侧内容区域 */}
            <Box
              sx={{
                flex: 1,
                display: "flex",
                flexDirection: "column",
                overflow: "hidden",
                minWidth: 0,
                minHeight: 0,
                /* 优化窗口调整性能 */
                willChange: "contents",
              }}
            >
              <Box
                sx={{
                  flex: 1,
                  overflow: "hidden",
                  minWidth: 0,
                  minHeight: 0,
                  width: "100%",
                  height: "100%",
                  /* 使用 Flexbox 确保内容完全填充 */
                  display: "flex",
                  flexDirection: "column",
                }}
              >
                <BaseErrorBoundary>
                  <Box
                    sx={{
                      flex: 1,
                      overflowY: "auto",
                      overflowX: "hidden",
                      minWidth: 0,
                      minHeight: 0,
                      width: "100%",
                      height: "100%",
                      /* 美化滚动条 */
                      "&::-webkit-scrollbar": {
                        width: "8px",
                      },
                      "&::-webkit-scrollbar-track": {
                        backgroundColor: "transparent",
                      },
                      "&::-webkit-scrollbar-thumb": {
                        backgroundColor: "rgba(0, 0, 0, 0.2)",
                        borderRadius: "4px",
                        "&:hover": {
                          backgroundColor: "rgba(0, 0, 0, 0.3)",
                        },
                      },
                      scrollbarWidth: "thin", /* Firefox */
                      scrollbarColor: "rgba(0, 0, 0, 0.2) transparent", /* Firefox */
                    }}
                  >
                    <Outlet />
                  </Box>
                </BaseErrorBoundary>
              </Box>
            </Box>
          </Box>
        </Paper>
      </ThemeProvider>
    </SWRConfig>
  );
};

export default Layout;
