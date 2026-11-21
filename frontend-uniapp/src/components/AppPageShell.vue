<template>
  <view class="app-shell">
    <view class="app-shell__header">
      <slot name="header">
        <app-navbar
          :title="title"
          :show-back="showBack"
          :show-home="showHome"
          :fixed="false"
          :placeholder="false"
          @back="emit('back')"
          @home="emit('home')"
        >
          <template #left>
            <slot name="nav-left" />
          </template>
          <template #right>
            <slot name="nav-right" />
          </template>
        </app-navbar>
      </slot>
    </view>

    <scroll-view
      scroll-y
      :scroll-top="innerScrollTop"
      :show-scrollbar="false"
      class="app-shell__scroll"
      @scroll="onScroll"
    >
      <view class="app-shell__body" :class="{ 'app-shell__body--flush': flush }">
        <slot />
      </view>
    </scroll-view>

    <view v-if="hasFooter" class="app-shell__footer">
      <slot name="footer" />
    </view>
    <view v-else class="app-shell__safe-bottom" />
  </view>
</template>

<script setup lang="ts">
import { nextTick, onMounted, ref } from "vue";
import { onShow } from "@dcloudio/uni-app";
import { syncOrientationForCurrentPage } from "@/utils/orientation";

withDefaults(
  defineProps<{
    title?: string;
    showBack?: boolean;
    showHome?: boolean;
    hasFooter?: boolean;
    flush?: boolean;
  }>(),
  {
    title: "",
    showBack: true,
    showHome: false,
    hasFooter: false,
    flush: false,
  },
);

const emit = defineEmits<{
  back: [];
  home: [];
}>();

const currentScrollY = ref(0);
const innerScrollTop = ref(0);

function onScroll(e: { detail?: { scrollTop?: number } }): void {
  currentScrollY.value = e?.detail?.scrollTop ?? 0;
}

function scrollToTop(): void {
  innerScrollTop.value = currentScrollY.value;
  void nextTick(() => {
    innerScrollTop.value = 0;
    currentScrollY.value = 0;
  });
}

onMounted(() => {
  syncOrientationForCurrentPage();
});

onShow(() => {
  syncOrientationForCurrentPage();
  // #ifdef H5
  uni.pageScrollTo({ scrollTop: 0, duration: 0 });
  // #endif
});

defineExpose({
  scrollToTop,
});
</script>

<style lang="scss" scoped>
.app-shell {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100vh;
  overflow: hidden;
  background: var(--color-bg-page);
}

.app-shell__header {
  flex-shrink: 0;
}

.app-shell__scroll {
  flex: 1;
  width: 100%;
  min-height: 0;
}

.app-shell__body {
  padding: 20rpx 24rpx 32rpx;
  box-sizing: border-box;

  &--flush {
    padding: 0;
  }
}

.app-shell__footer {
  flex-shrink: 0;
  padding: 16rpx 24rpx calc(16rpx + env(safe-area-inset-bottom));
  background: var(--color-bg-card);
  border-top: 1px solid var(--color-border);
}

.app-shell__safe-bottom {
  flex-shrink: 0;
  height: env(safe-area-inset-bottom);
}
</style>
