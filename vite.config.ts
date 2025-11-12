import { fileURLToPath } from "node:url";
import path from "node:path";
import os from "node:os";
import { createRequire } from "node:module";
import legacy from "@vitejs/plugin-legacy";
import react from "@vitejs/plugin-react";
import svgr from "vite-plugin-svgr";
import { defineConfig } from "vite";
import type { Plugin } from "vite";

// Get __dirname equivalent in ESM
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Create require function for CommonJS modules
const require = createRequire(import.meta.url);

// Detect architecture - use Babel-based React plugin for RISC-V, SWC for others
// SWC doesn't have native bindings for RISC-V, so we must use Babel-based plugin
const isRiscV = 
  process.env.TARGET_ARCH === "riscv64" ||
  process.env.RUNNER_ARCH === "riscv64" ||
  process.arch === "riscv64" ||
  os.arch() === "riscv64";

// Get React plugin based on architecture
// We can't import @vitejs/plugin-react-swc on RISC-V because it will try to load @swc/core
// which doesn't have native bindings for RISC-V. So we use a function to load it conditionally.
function getReactPlugin(): Plugin {
  if (isRiscV) {
    console.log("[vite.config.ts] Detected RISC-V architecture, using Babel-based React plugin (@vitejs/plugin-react)");
    console.log(`[vite.config.ts] TARGET_ARCH: ${process.env.TARGET_ARCH}, RUNNER_ARCH: ${process.env.RUNNER_ARCH}, process.arch: ${process.arch}, os.arch(): ${os.arch()}`);
    return react();
  } else {
    // Only try to load SWC plugin when not on RISC-V
    try {
      // Use createRequire to load CommonJS module
      const reactSwc = require("@vitejs/plugin-react-swc");
      console.log(`[vite.config.ts] Using SWC-based React plugin (@vitejs/plugin-react-swc) - arch: ${process.arch || os.arch()}`);
      return reactSwc.default ? reactSwc.default() : reactSwc();
    } catch (error) {
      // Fallback to Babel if SWC fails to load
      console.warn("[vite.config.ts] Failed to load SWC plugin, falling back to Babel:", error);
      return react();
    }
  }
}

const reactPlugin = getReactPlugin();

export default defineConfig({
  root: "src",
  base: "./", // Use relative paths for Tauri asset protocol
  server: {
    port: 5173,
    strictPort: true,
    watch: {
      ignored: ["**/src-tauri/**", "**/clash-verge-rev/**"],
    },
  },
  plugins: [
    svgr(),
    reactPlugin,
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
    assetsDir: "assets",
    rollupOptions: {
      treeshake: {
        preset: "recommended",
        moduleSideEffects: (id) => !id.endsWith(".css"),
        tryCatchDeoptimization: false,
      },
      output: {
        compact: true,
        // Disable code splitting to avoid circular dependency issues
        // In development mode, Vite doesn't split code, which is why it works there
        // For production, we'll use a single chunk to avoid React loading issues
        manualChunks: undefined,
        // Use relative paths for Tauri asset protocol
        assetFileNames: "assets/[name].[hash].[ext]",
        chunkFileNames: "assets/[name].[hash].js",
        entryFileNames: "assets/[name].[hash].js",
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

