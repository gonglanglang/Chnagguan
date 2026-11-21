<script setup lang="ts">
import { computed } from "vue";
import { renderMathRichText } from "@/utils/math";

const props = withDefaults(
  defineProps<{
    text?: string | null;
    inline?: boolean;
  }>(),
  {
    text: "",
    inline: false
  }
);

const renderedHtml = computed(() => renderMathRichText(props.text));
</script>

<template>
  <span v-if="inline" class="math-rich-text math-rich-text--inline" v-html="renderedHtml" />
  <div v-else class="math-rich-text" v-html="renderedHtml" />
</template>

<style scoped>
.math-rich-text {
  line-height: 1.65;
  word-break: normal;
  overflow-wrap: break-word;
}

.math-rich-text--inline {
  display: inline;
}

.math-rich-text :deep(.math-inline .katex) {
  font-size: 1.02em;
}

.math-rich-text :deep(.math-block) {
  display: block;
  margin: 6px 0;
  overflow-x: auto;
}
</style>
