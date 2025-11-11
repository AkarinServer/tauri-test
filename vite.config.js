import { defineConfig } from "vite";

// https://vitejs.dev/config/
export default defineConfig({
  // prevent vite from obscuring rust errors
  clearScreen: false,
  // Tauri expects a fixed port, fail if that port is not available
  server: {
    port: 5173,
    strictPort: true,
    watch: {
      // Tell Vite to ignore watching `src-tauri`
      ignored: ["**/src-tauri/**"],
    },
  },
  build: {
    // 优化构建配置
    target: 'esnext',
    minify: 'esbuild',
    // 代码分割优化
    rollupOptions: {
      output: {
        manualChunks: {
          // 将 Tauri API 单独打包
          'tauri-api': ['@tauri-apps/api/core'],
        },
      },
    },
    // 减少 chunk 大小警告阈值
    chunkSizeWarningLimit: 1000,
  },
  // 优化依赖预构建
  optimizeDeps: {
    include: ['@tauri-apps/api/core'],
  },
});

