import { fileURLToPath } from "node:url";
import path from "node:path";
import legacy from "@vitejs/plugin-legacy";
import react from "@vitejs/plugin-react-swc";
import svgr from "vite-plugin-svgr";
import { defineConfig } from "vite";

// Get __dirname equivalent in ESM
const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  root: "src",
  server: {
    port: 5173,
    strictPort: true,
    watch: {
      ignored: ["**/src-tauri/**", "**/clash-verge-rev/**"],
    },
  },
  plugins: [
    svgr(),
    react(),
    legacy({
      targets: ["edge>=109", "safari>=13"],
      renderLegacyChunks: false,
      modernPolyfills: true,
      additionalModernPolyfills: [
        path.resolve(__dirname, "src/polyfills/matchMedia.js"),
        path.resolve(__dirname, "src/polyfills/WeakRef.js"),
        path.resolve(__dirname, "src/polyfills/RegExp.js"),
      ],
    }),
  ],
  build: {
    outDir: "../dist",
    emptyOutDir: true,
    minify: "esbuild",
    chunkSizeWarningLimit: 2000,
    reportCompressedSize: false,
    sourcemap: false,
    cssCodeSplit: true,
    cssMinify: true,
    rollupOptions: {
      treeshake: {
        preset: "recommended",
        moduleSideEffects: (id) => !id.endsWith(".css"),
        tryCatchDeoptimization: false,
      },
      output: {
        compact: true,
        experimentalMinChunkSize: 50000,
        dynamicImportInCjs: true,
        manualChunks(id) {
          if (id.includes("node_modules")) {
            // React core libraries
            if (
              id.includes("react") ||
              id.includes("react-dom") ||
              id.includes("react-router")
            ) {
              return "react-core";
            }

            // Material UI libraries (grouped together)
            if (
              id.includes("@mui/material") ||
              id.includes("@mui/icons-material")
            ) {
              return "mui";
            }

            // Tauri-related plugins
            if (
              id.includes("@tauri-apps/api") ||
              id.includes("@tauri-apps/plugin")
            ) {
              return "tauri-plugins";
            }

            // Utilities chunk
            if (
              id.includes("axios") ||
              id.includes("lodash-es") ||
              id.includes("dayjs") ||
              id.includes("js-yaml") ||
              id.includes("nanoid")
            ) {
              return "utils";
            }

            // Group all other packages together
            return "vendor";
          }
        },
      },
    },
  },
  resolve: {
    alias: {
      // When root is "src", Vite's working directory is "src"
      // So "@" should point to the src directory (current working directory in Vite)
      "@": path.resolve(__dirname, "src"),
      "@root": path.resolve(__dirname),
    },
  },
  define: {
    OS_PLATFORM: `"${process.platform}"`,
  },
});

