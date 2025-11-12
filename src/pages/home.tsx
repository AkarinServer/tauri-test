import { RouterOutlined, AccountTreeOutlined, InfoOutlined } from "@mui/icons-material";
import { Grid } from "@mui/material";
import { useTranslation } from "react-i18next";

import { BasePage } from "@/components/base";
import { ClashModeCard } from "@/components/home/clash-mode-card";
import { CurrentProxyCard } from "@/components/home/current-proxy-card";
import { EnhancedCard } from "@/components/home/enhanced-card";
import { SystemInfoCard } from "@/components/home/system-info-card";

const HomePage = () => {
  const { t, ready } = useTranslation();

  // Show loading state if i18n is not ready
  if (!ready) {
    return (
      <BasePage title="加载中..." contentStyle={{ padding: 2 }}>
        <div>正在加载...</div>
      </BasePage>
    );
  }

  return (
    <BasePage title={t("home.page.title")} contentStyle={{ padding: 2 }}>
      <Grid container spacing={1.5} columns={{ xs: 6, sm: 6, md: 12 }}>
        <Grid size={6}>
          <EnhancedCard
            title={t("home.page.cards.proxyMode")}
            icon={<RouterOutlined />}
            iconColor="info"
          >
            <ClashModeCard />
          </EnhancedCard>
        </Grid>

        <Grid size={6}>
          <EnhancedCard
            title={t("home.components.currentProxy.title")}
            icon={<AccountTreeOutlined />}
            iconColor="primary"
          >
            <CurrentProxyCard />
          </EnhancedCard>
        </Grid>

        <Grid size={6}>
          <EnhancedCard
            title={t("home.components.systemInfo.title")}
            icon={<InfoOutlined />}
            iconColor="secondary"
          >
            <SystemInfoCard />
          </EnhancedCard>
        </Grid>
      </Grid>
    </BasePage>
  );
};

export default HomePage;
