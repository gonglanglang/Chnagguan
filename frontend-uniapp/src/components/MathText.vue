<template>
  <!-- #ifdef H5 -->
  <view
    class="math-text"
    :class="{ 'math-text--inline': inline }"
    v-html="renderedHtml"
  />
  <!-- #endif -->
  <!-- #ifndef H5 -->
  <rich-text
    class="math-text"
    :class="{ 'math-text--inline': inline }"
    :nodes="renderedHtml"
  />
  <!-- #endif -->
</template>

<script setup lang="ts">
import { computed } from "vue";
import { renderMathHtml } from "@/utils/math";

const props = withDefaults(
  defineProps<{
    text?: string | null;
    inline?: boolean;
  }>(),
  {
    text: "",
    inline: false,
  },
);

const renderedHtml = computed(() => renderMathHtml(props.text));
</script>

<style lang="scss" scoped>
.math-text {
  word-break: break-word;
  line-height: 1.65;
}

.math-text--inline {
  display: inline;
}

.math-text :deep(.math-inline .katex) {
  font-size: 1.02em;
}

.math-text :deep(.math-block) {
  display: block;
  margin: 10rpx 0;
  overflow-x: auto;
}
</style>
