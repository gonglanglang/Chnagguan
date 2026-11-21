import { createSSRApp } from "vue";
import App from "./App.vue";

import "uno.css";
// #ifdef H5
import "katex/dist/katex.min.css";
// #endif
import "@/styles/index.scss";

import { setupPinia, useUserStore } from "@/store";
import { setupOrientationGuard } from "@/utils/orientation";
import { setUnauthorizedHandler } from "@/utils/request";

/**
 * 创建应用并注册会话处理回调
 */
export function createApp() {
  const app = createSSRApp(App);

  setupPinia(app);
  setupOrientationGuard();
  setUnauthorizedHandler(() => useUserStore().resetSession());

  return {
    app,
  };
}
