<script setup lang="ts">
import { computed } from "vue";

defineOptions({
  name: "GglIcon"
});

const props = withDefaults(
  defineProps<{
    name: string;
    size?: number | string;
    color?: string;
  }>(),
  {
    size: 18,
    color: "currentColor"
  }
);

const PATHS: Record<string, string> = {
  "gate-home": `
    <path d="M3 10.5L12 3.5L21 10.5" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M5.5 9.2V20H18.5V9.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M9.5 20V14.2C9.5 12.82 10.62 11.7 12 11.7C13.38 11.7 14.5 12.82 14.5 14.2V20" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M8 7.5H16" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
  `,
  "cultivate-scroll": `
    <rect x="4" y="4.5" width="16" height="15" rx="3" stroke="currentColor" stroke-width="1.9"/>
    <path d="M10.2 9.2L15.2 12L10.2 14.8V9.2Z" fill="currentColor" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M7.5 2.8V5.2M16.5 2.8V5.2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  `,
  "wrong-sword": `
    <path d="M5.5 4.2C5.5 3.54 6.04 3 6.7 3H16.5C17.6 3 18.5 3.9 18.5 5V19.2C18.5 20.19 17.7 21 16.7 21H6.7C6.04 21 5.5 20.46 5.5 19.8V4.2Z" stroke="currentColor" stroke-width="1.9"/>
    <path d="M9 3V21" stroke="currentColor" stroke-width="1.7"/>
    <path d="M12.2 9.5L15.4 12.7M15.4 9.5L12.2 12.7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
    <path d="M12 16H15.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  `,
  "dao-user": `
    <circle cx="12" cy="8.4" r="3.6" stroke="currentColor" stroke-width="1.9"/>
    <path d="M9.6 4.8L12 2.8L14.4 4.8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M5 19.8C5.6 16.4 8.5 14.4 12 14.4C15.5 14.4 18.4 16.4 19 19.8" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
  `,
  "realm-lotus": `
    <path d="M12 4C9.8 7.1 9.5 10.6 12 14C14.5 10.6 14.2 7.1 12 4Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
    <path d="M6.2 7.4C6.6 11.2 8.7 13.8 12 14.6C8.8 14.9 5.5 13.8 4 11C4.5 9.4 5.2 8.2 6.2 7.4Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
    <path d="M17.8 7.4C17.4 11.2 15.3 13.8 12 14.6C15.2 14.9 18.5 13.8 20 11C19.5 9.4 18.8 8.2 17.8 7.4Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
    <path d="M5 18.5H19" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
  `,
  brush: `
    <path d="M16.8 4.2L19.8 7.2L9.2 17.8L5.2 18.8L6.2 14.8L16.8 4.2Z" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="M14.4 6.6L17.4 9.6" stroke="currentColor" stroke-width="1.8"/>
  `,
  eraser: `
    <path d="M14.5 4.5L19.8 9.8L11.2 18.4H5.8L4.2 16.8L14.5 4.5Z" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="M9.4 10.6L14.4 15.6" stroke="currentColor" stroke-width="1.8"/>
    <path d="M11.2 18.4H20" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  `,
  undo: `
    <path d="M8.5 7.5H4.5V3.5" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M4.8 7.5C6.8 5.2 9.8 4.2 12.8 4.8C16.7 5.6 19.4 9.1 19 13.1C18.6 16.9 15.4 19.6 11.6 19.6C8.8 19.6 6.4 18.1 5.2 15.8" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
  `,
  clear: `
    <path d="M4.5 7H19.5M9.5 4H14.5" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M6.8 7L7.6 19.2C7.66 19.95 8.28 20.5 9.03 20.5H14.97C15.72 20.5 16.34 19.95 16.4 19.2L17.2 7" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M10.2 10.8V16.5M13.8 10.8V16.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  `,
  notes: `
    <rect x="5" y="3.5" width="14" height="17" rx="2.4" stroke="currentColor" stroke-width="1.9"/>
    <path d="M8.5 8.5H15.5M8.5 12.2H15.5M8.5 15.9H13" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  `,
  "video-play": `
    <rect x="3" y="5" width="18" height="14" rx="2.8" stroke="currentColor" stroke-width="1.9"/>
    <path d="M10.2 9.2L15.4 12L10.2 14.8V9.2Z" fill="currentColor"/>
  `,
  spark: `
    <path d="M12 3L14.2 9.4L20.5 11.6L14.2 13.8L12 20.2L9.8 13.8L3.5 11.6L9.8 9.4L12 3Z" stroke="currentColor" stroke-width="1.85" stroke-linejoin="round"/>
  `,
  back: `
    <path d="M14.8 5.5L8.2 12L14.8 18.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  `,
  "check-circle": `
    <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.9"/>
    <path d="M8.2 12.2L10.8 14.8L16 9.4" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
  `,
  "close-circle": `
    <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.9"/>
    <path d="M9 9L15 15M15 9L9 15" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
  `
};

const sizeStyle = computed(() => {
  const s = typeof props.size === "number" ? `${props.size}px` : props.size;
  return { width: s, height: s, color: props.color };
});

const bodyMarkup = computed(() => PATHS[props.name] || PATHS.spark);
</script>

<template>
  <svg
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    class="inline-block shrink-0 align-middle"
    :style="sizeStyle"
    v-html="bodyMarkup"
  />
</template>
