<template>
  <image
    :src="dataUri"
    mode="aspectFit"
    class="app-icon"
    :class="customClass"
    :style="{ width: resolvedSize, height: resolvedSize }"
  />
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useTheme } from "@/composables/useTheme";
import { buildGglIconDataUri } from "@/utils/icon-registry";

const props = withDefaults(
  defineProps<{
    name: string;
    size?: number | string;
    color?: string;
    customClass?: string;
  }>(),
  {
    size: 18,
    color: "var(--color-text)",
    customClass: "",
  },
);

const { isDark, selectedThemeColor } = useTheme();

const resolvedColor = computed(() => {
  const raw = (props.color || "").trim();
  if (!raw || raw === "var(--color-text)" || raw === "text") {
    return isDark.value ? "#f8fafc" : "#1e293b";
  }
  if (raw === "var(--color-primary)" || raw === "primary") {
    return selectedThemeColor.value?.primary || "#16a34a";
  }
  if (raw === "var(--color-text-secondary)" || raw === "secondary") {
    return "#64748b";
  }
  if (raw === "var(--color-text-muted)" || raw === "muted") {
    return isDark.value ? "#64748b" : "#94a3b8";
  }
  if (raw === "var(--color-warning)" || raw === "warning") {
    return isDark.value ? "#f59e0b" : "#d97706";
  }
  if (raw === "var(--color-danger)" || raw === "danger") {
    return isDark.value ? "#f87171" : "#ef4444";
  }
  return raw;
});

const resolvedSize = computed(() => {
  if (typeof props.size === "number") {
    return `${props.size}px`;
  }
  const s = String(props.size).trim();
  return /^\d+$/.test(s) ? `${s}px` : s;
});

const dataUri = computed(() => buildGglIconDataUri(props.name, resolvedColor.value));
</script>

<style lang="scss" scoped>
.app-icon {
  display: inline-block;
  flex-shrink: 0;
  vertical-align: middle;
}
</style>
