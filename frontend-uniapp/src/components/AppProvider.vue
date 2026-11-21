<template>
  <wd-config-provider
    :theme="themeMode"
    :theme-vars="themeVars"
    :custom-style="providerStyle"
    :button="{ type: 'primary' }"
    :tag="{ variant: 'plain' }"
  >
    <slot />
    <wd-notify />
    <wd-toast />
    <wd-dialog />
  </wd-config-provider>
</template>

<script lang="ts" setup>
import { storeToRefs } from "pinia";
import { useThemeStore } from "@/store";

/**
 * 应用容器：主题与反馈组件的挂载点
 *
 * 页面内容与全局弹层（notify/toast/dialog）从 wd-config-provider 继承主题，
 * default / tabbar / blank 三类 layout 共用同一份注入逻辑
 * uni-app 的每个页面各自挂载一个实例，不是跨页常驻的单例
 */
const themeStore = useThemeStore();
const { themeMode, themeVars } = storeToRefs(themeStore);

// 主色为 6 位十六进制时才能拆出 RGB 分量生成透明度变体
const HEX6_RE = /^#[0-9a-fA-F]{6}$/;

// 深色模式卡片填充色改由 wot 变量接管，避免深色下卡片发黑
const providerStyle = computed(() => {
  const p = themeStore.selectedThemeColor.primary;
  const styles = [
    `--color-primary: ${p}`,
    `--wot-color-theme: ${p}`,
    `--wot-primary-6: ${p}`,
    "--wot-filled-oppo: var(--color-bg-card)",
  ];
  if (HEX6_RE.test(p)) {
    const bigint = Number.parseInt(p.slice(1), 16);
    const r = (bigint >> 16) & 255;
    const g = (bigint >> 8) & 255;
    const b = bigint & 255;
    const rgb = `${r}, ${g}, ${b}`;
    const tint = (ratio: number) => {
      const rr = Math.round(r * (1 - ratio) + 255 * ratio).toString(16).padStart(2, "0");
      const gg = Math.round(g * (1 - ratio) + 255 * ratio).toString(16).padStart(2, "0");
      const bb = Math.round(b * (1 - ratio) + 255 * ratio).toString(16).padStart(2, "0");
      return `#${rr}${gg}${bb}`;
    };
    const shade = (ratio: number) => {
      const rr = Math.round(r * (1 - ratio)).toString(16).padStart(2, "0");
      const gg = Math.round(g * (1 - ratio)).toString(16).padStart(2, "0");
      const bb = Math.round(b * (1 - ratio)).toString(16).padStart(2, "0");
      return `#${rr}${gg}${bb}`;
    };
    styles.push(
      `--wot-primary-1: ${tint(0.91)}`,
      `--wot-primary-2: ${tint(0.8)}`,
      `--wot-primary-5: ${tint(0.2)}`,
      `--wot-primary-7: ${shade(0.16)}`,
      `--color-primary-soft: rgba(${rgb}, 0.1)`,
      `--color-primary-alpha-20: rgba(${rgb}, 0.2)`,
      `--color-primary-alpha-15: rgba(${rgb}, 0.15)`,
    );
  }
  return styles.join("; ");
});
</script>

<script lang="ts">
export default {
  name: "AppProvider",
  options: {
    virtualHost: true,
    styleIsolation: "shared",
  },
};
</script>
