import { defineStore } from "pinia";
import { Storage } from "@/utils/storage";
import { THEME_MODE_KEY, THEME_COLOR_KEY } from "@/constants";
import type { ConfigProviderThemeVars } from "@wot-ui/ui";

export interface ThemeColorOption {
  name: string;
  value: string;
  primary: string;
}

export type ThemeMode = "light" | "dark";

export const themeColorOptions: ThemeColorOption[] = [
  { name: "天青蓝", value: "blue", primary: "#0284C7" },
  { name: "过关绿", value: "green", primary: "#16a34a" },
  { name: "活力橙", value: "orange", primary: "#FF7D00" },
  { name: "樱花粉", value: "pink", primary: "#FF69B4" },
  { name: "紫罗兰", value: "purple", primary: "#8A2BE2" },
  { name: "朱砂红", value: "red", primary: "#FF4757" },
];

const THEME_UI_V2_FLAG = "ggl_ui_v2_theme_migrated";

function mixHex(hex: string, targetHex: string, ratio: number): string {
  const valid = /^#[0-9a-fA-F]{6}$/;
  if (!valid.test(hex)) return hex;
  const r1 = Number.parseInt(hex.slice(1, 3), 16);
  const g1 = Number.parseInt(hex.slice(3, 5), 16);
  const b1 = Number.parseInt(hex.slice(5, 7), 16);
  const r2 = Number.parseInt(targetHex.slice(1, 3), 16);
  const g2 = Number.parseInt(targetHex.slice(3, 5), 16);
  const b2 = Number.parseInt(targetHex.slice(5, 7), 16);
  const blend = (a: number, b: number) =>
    Math.round(a * (1 - ratio) + b * ratio)
      .toString(16)
      .padStart(2, "0");
  return `#${blend(r1, r2)}${blend(g1, g2)}${blend(b1, b2)}`;
}

function resolveInitialThemeColor(): ThemeColorOption {
  const defaultBlue = themeColorOptions[0];
  const migrated = Storage.get<boolean>(THEME_UI_V2_FLAG, false);
  if (!migrated) {
    Storage.set(THEME_UI_V2_FLAG, true);
    Storage.set(THEME_COLOR_KEY, defaultBlue);
    return defaultBlue;
  }
  return Storage.get<ThemeColorOption>(THEME_COLOR_KEY, defaultBlue);
}

export const useThemeStore = defineStore("theme", () => {
  const themeMode = ref<ThemeMode>(Storage.get<ThemeMode>(THEME_MODE_KEY, "light"));

  const selectedThemeColor = ref<ThemeColorOption>(resolveInitialThemeColor());

  // @wot-ui/ui v2 所有主色组件均绑定 --wot-primary-1..7 CSS 变量
  const themeVars = computed<ConfigProviderThemeVars>(() => {
    const p = selectedThemeColor.value.primary;
    return {
      primary1: mixHex(p, "#ffffff", 0.91),
      primary2: mixHex(p, "#ffffff", 0.8),
      primary5: mixHex(p, "#ffffff", 0.2),
      primary6: p,
      primary7: mixHex(p, "#000000", 0.16),
    };
  });

  const isDark = computed(() => themeMode.value === "dark");

  const syncNavigationBarTheme = () => {
    try {
      const res: any = uni.setNavigationBarColor({
        frontColor: themeMode.value === "light" ? "#000000" : "#ffffff",
        backgroundColor: themeMode.value === "light" ? "#ffffff" : "#1f2937",
        fail: () => {},
      });
      if (res && typeof res.catch === "function") {
        res.catch(() => {});
      }
    } catch {
      // Custom navbar pages may reject setNavigationBarColor; ignore cleanly
    }
  };

  const setThemeMode = (mode: ThemeMode) => {
    themeMode.value = mode;
    Storage.set(THEME_MODE_KEY, mode);
    syncNavigationBarTheme();
  };

  const toggleThemeMode = () => {
    setThemeMode(themeMode.value === "light" ? "dark" : "light");
  };

  const setThemeColor = (color: ThemeColorOption) => {
    selectedThemeColor.value = color;
    Storage.set(THEME_COLOR_KEY, color);
  };

  const initTheme = () => {
    nextTick(() => {
      syncNavigationBarTheme();
    });
  };

  return {
    themeMode,
    selectedThemeColor,
    themeVars,
    isDark,
    setThemeMode,
    toggleThemeMode,
    setThemeColor,
    syncNavigationBarTheme,
    initTheme,
  };
});
