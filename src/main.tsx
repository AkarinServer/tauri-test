/// <reference types="vite/client" />
/// <reference types="vite-plugin-svgr/client" />

import { ResizeObserver } from "@juggle/resize-observer";
import { ComposeContextProvider } from "foxact/compose-context-provider";
import React from "react";
import { createRoot } from "react-dom/client";
import { RouterProvider } from "react-router";

import { BaseErrorBoundary } from "./components/base";
import { router } from "./pages/_routers";
import { AppDataProvider } from "./providers/app-data-provider";
import { WindowProvider } from "./providers/window";
import { initializeLanguage } from "./services/i18n";
import {
  LoadingCacheProvider,
  ThemeModeProvider,
  UpdateStateProvider,
} from "./services/states";

// Polyfills
import "./polyfills/matchMedia.js";
import "./polyfills/WeakRef.js";
import "./polyfills/RegExp.js";

// Styles
import "./styles/base.css";

// ResizeObserver polyfill
if (!window.ResizeObserver) {
  window.ResizeObserver = ResizeObserver;
}

const mainElementId = "root";
const container = document.getElementById(mainElementId);

if (!container) {
  throw new Error(
    `No container '${mainElementId}' found to render application`,
  );
}

// Disable WebView keyboard shortcuts
document.addEventListener("keydown", (event) => {
  const disabledShortcuts =
    ["F5", "F7"].includes(event.key) ||
    (event.altKey && ["ArrowLeft", "ArrowRight"].includes(event.key)) ||
    ((event.ctrlKey || event.metaKey) &&
      ["F", "G", "H", "J", "P", "Q", "R", "U"].includes(
        event.key.toUpperCase(),
      ));
  if (disabledShortcuts) {
    event.preventDefault();
  }
});

const initializeApp = () => {
  try {
    console.log("[main.tsx] Initializing app...");
    const contexts = [
      <ThemeModeProvider key="theme" />,
      <LoadingCacheProvider key="loading" />,
      <UpdateStateProvider key="update" />,
    ];

    const root = createRoot(container);
    root.render(
      <React.StrictMode>
        <ComposeContextProvider contexts={contexts}>
          <BaseErrorBoundary>
            <WindowProvider>
              <AppDataProvider>
                <RouterProvider router={router} />
              </AppDataProvider>
            </WindowProvider>
          </BaseErrorBoundary>
        </ComposeContextProvider>
      </React.StrictMode>,
    );
    console.log("[main.tsx] App initialized successfully");
  } catch (error) {
    console.error("[main.tsx] Failed to initialize app:", error);
    // Show error in UI
    container.innerHTML = `
      <div style="padding: 20px; font-family: monospace;">
        <h2>Application Initialization Error</h2>
        <pre>${error instanceof Error ? error.stack : String(error)}</pre>
      </div>
    `;
  }
};

// Initialize language (default to Chinese)
initializeLanguage("zh")
  .then(() => {
    console.log("[main.tsx] Language initialized successfully");
    initializeApp();
  })
  .catch((error) => {
    console.error("[main.tsx] Failed to initialize language:", error);
    // Still initialize app even if language fails
    initializeApp();
  });

// Error handling
window.addEventListener("error", (event) => {
  console.error("[main.tsx] Global error:", event.error);
});

window.addEventListener("unhandledrejection", (event) => {
  console.error("[main.tsx] Unhandled promise rejection:", event.reason);
});

// Cleanup on page unload (placeholder - will be implemented later)
// window.addEventListener("beforeunload", () => {
//   // Cleanup all WebSocket instances to prevent memory leaks
//   // MihomoWebSocket.cleanupAll();
// });

