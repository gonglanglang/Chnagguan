<template>
  <!-- #ifdef H5 -->
  <view
    class="math-text"
    :class="{ 'math-text--inline': inline }"
    v-html="renderedHtml"
  />
  <!-- #endif -->
  <!-- #ifndef H5 -->
  <view class="math-flow" :class="{ 'math-flow--inline': inline }">
    <template v-for="(tok, idx) in tokens" :key="idx">
      <text v-if="tok.type === 'text'" selectable class="math-seg">{{ tok.value }}</text>
      <text v-else-if="tok.type === 'sup'" selectable class="math-sup">{{ tok.value }}</text>
      <text v-else-if="tok.type === 'sub'" selectable class="math-sub">{{ tok.value }}</text>
      <view v-else-if="tok.type === 'frac'" class="math-frac">
        <text selectable class="math-frac__num">{{ tok.num }}</text>
        <view class="math-frac__bar" />
        <text selectable class="math-frac__den">{{ tok.den }}</text>
      </view>
      <view v-else-if="tok.type === 'br'" class="math-br" />
    </template>
  </view>
  <!-- #endif -->
</template>

<script setup lang="ts">
import { computed } from "vue";
import { parseMathTokens, renderMathHtml } from "@/utils/math";

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
const tokens = computed(() => parseMathTokens(props.text));
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

.math-flow {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  align-content: flex-start;
  row-gap: 6rpx;
  width: 100%;
  color: inherit;
  word-break: break-word;
}

.math-flow--inline {
  display: inline-flex;
  width: auto;
  vertical-align: middle;
}

.math-seg {
  display: inline;
  line-height: 1.5;
  color: inherit;
}

.math-sup {
  align-self: flex-start;
  margin-top: 2rpx;
  margin-left: 2rpx;
  font-size: 0.72em;
  line-height: 1;
  color: inherit;
}

.math-sub {
  align-self: flex-end;
  margin-bottom: 2rpx;
  margin-left: 2rpx;
  font-size: 0.72em;
  line-height: 1;
  color: inherit;
}

.math-frac {
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 0 4rpx;
  margin: 0 6rpx;
  vertical-align: middle;
}

.math-frac__num,
.math-frac__den {
  padding: 0 6rpx;
  font-size: 0.76em;
  line-height: 1.15;
  color: inherit;
  text-align: center;
}

.math-frac__bar {
  width: 100%;
  min-width: 28rpx;
  height: 2rpx;
  margin: 3rpx 0;
  background-color: currentColor;
}

.math-br {
  width: 100%;
  height: 6rpx;
}
</style>
