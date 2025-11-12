import { Box, Paper, ThemeProvider, createTheme } from "@mui/material";
import { Outlet } from "react-router";

import { BaseErrorBoundary } from "@/components/base";
import { useThemeMode } from "@/services/states";

const Layout = () => {
  let mode: "light" | "dark" = "light";
  try {
    mode = useThemeMode();
  } catch (error) {
    console.error("[Layout] useThemeMode failed:", error);
  }

  const theme = createTheme({
    palette: {
      mode: mode === "light" ? "light" : "dark",
    },
  });

  return (
    <ThemeProvider theme={theme}>
      <Paper
        square
        elevation={0}
        sx={{
          width: "100vw",
          height: "100vh",
          display: "flex",
          flexDirection: "column",
          backgroundColor: mode === "dark" ? "#121212" : "#ffffff",
        }}
      >
        <Box
          sx={{
            flex: 1,
            display: "flex",
            flexDirection: "column",
            overflow: "hidden",
          }}
        >
          <BaseErrorBoundary>
            <Outlet />
          </BaseErrorBoundary>
        </Box>
      </Paper>
    </ThemeProvider>
  );
};

export default Layout;

