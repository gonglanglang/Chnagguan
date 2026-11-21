<template>
  <view v-if="state.visible" class="update-mask" @click.self="dismissAppUpdateModal">
    <view class="update-card">
      <view class="update-card__head">
        <view class="update-card__badge">
          <wd-icon name="refresh" size="22" color="#ffffff" />
        </view>
        <view class="update-card__title-wrap">
          <text class="update-card__title">发现新版本 v{{ state.latestVersion }}</text>
          <text class="update-card__ver">
            当前 v{{ state.currentVersion }} → 最新 v{{ state.latestVersion }}
          </text>
        </view>
      </view>

      <view class="update-card__section-label">更新内容</view>
      <scroll-view scroll-y class="update-card__list">
        <view
          v-for="(item, idx) in state.noteList"
          :key="idx"
          class="update-note-item"
        >
          <view class="update-note-item__dot" />
          <text class="update-note-item__text">{{ item }}</text>
        </view>
      </scroll-view>

      <view v-if="state.downloading" class="update-card__progress">
        <wd-progress :percentage="state.progress" hide-text />
        <text class="update-card__progress-text">正在下载安装包 {{ state.progress }}%...</text>
      </view>

      <text v-if="state.errorMsg" class="update-card__error">{{ state.errorMsg }}</text>

      <view class="update-card__actions">
        <wd-button
          v-if="!state.forceUpdate && !state.downloading"
          variant="plain"
          block
          @click="dismissAppUpdateModal"
        >
          暂不更新
        </wd-button>
        <wd-button
          type="primary"
          block
          :loading="state.downloading"
          @click="startAppUpdateDownload"
        >
          {{ state.downloading ? `下载中 ${state.progress}%` : "立即更新" }}
        </wd-button>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import {
  dismissAppUpdateModal,
  startAppUpdateDownload,
  useAppUpdateState,
} from "@/utils/app-update";

const state = useAppUpdateState();
</script>

<style lang="scss" scoped>
.update-mask {
  position: fixed;
  inset: 0;
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40rpx;
  background: rgba(15, 23, 42, 0.52);
}

.update-card {
  width: 100%;
  max-width: 620rpx;
  padding: 34rpx 30rpx 28rpx;
  background: var(--color-bg-card);
  border-radius: 24rpx;
  box-shadow: 0 18rpx 48rpx rgba(15, 23, 42, 0.22);
}

.update-card__head {
  display: flex;
  gap: 18rpx;
  align-items: center;
}

.update-card__badge {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 72rpx;
  height: 72rpx;
  background: var(--color-primary);
  border-radius: 18rpx;
}

.update-card__title-wrap {
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.update-card__title {
  font-size: 32rpx;
  font-weight: 700;
  color: var(--color-text);
}

.update-card__ver {
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.update-card__section-label {
  margin-top: 24rpx;
  margin-bottom: 12rpx;
  font-size: 24rpx;
  font-weight: 600;
  color: var(--color-text-muted);
}

.update-card__list {
  max-height: 300rpx;
  padding: 18rpx 20rpx;
  background: var(--color-bg-page);
  border-radius: 16rpx;
  box-sizing: border-box;
}

.update-note-item {
  display: flex;
  gap: 14rpx;
  align-items: flex-start;

  & + .update-note-item {
    margin-top: 14rpx;
  }
}

.update-note-item__dot {
  flex-shrink: 0;
  width: 12rpx;
  height: 12rpx;
  margin-top: 13rpx;
  background: var(--color-primary);
  border-radius: 50%;
}

.update-note-item__text {
  flex: 1;
  font-size: 26rpx;
  line-height: 1.55;
  color: var(--color-text);
}

.update-card__progress {
  margin-top: 22rpx;
}

.update-card__progress-text {
  display: block;
  margin-top: 8rpx;
  font-size: 23rpx;
  color: var(--color-primary);
  text-align: center;
}

.update-card__error {
  display: block;
  margin-top: 14rpx;
  font-size: 23rpx;
  color: var(--color-danger);
}

.update-card__actions {
  display: flex;
  gap: 18rpx;
  margin-top: 26rpx;
}
</style>
