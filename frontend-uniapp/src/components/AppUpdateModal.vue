<template>
  <view v-if="state.visible" class="update-mask" @click.self="dismissAppUpdateModal">
    <view class="update-card">
      <view class="update-card__head">
        <view class="update-card__badge">
          <app-icon name="refresh" size="22" color="#ffffff" />
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
        <view v-for="(item, idx) in state.noteList" :key="idx" class="update-note-item">
          <view class="update-note-item__dot" />
          <text class="update-note-item__text">{{ item }}</text>
        </view>
      </scroll-view>

      <view v-if="showProgressPanel" class="update-progress-box">
        <view class="update-progress-box__head">
          <text class="update-progress-box__status">{{ progressStatusLabel }}</text>
          <text class="update-progress-box__pct">{{ state.progress }}%</text>
        </view>
        <wd-progress :percentage="state.progress" :duration="4" hide-text />
        <text class="update-progress-box__meta">{{ progressSizeText }}</text>
      </view>

      <view v-if="state.errorMsg" class="update-card__error-box">
        <text class="update-card__error">{{ state.errorMsg }}</text>
      </view>

      <view class="update-card__actions">
        <template v-if="state.downloading">
          <wd-button variant="plain" block @click="cancelAppUpdateDownload">取消下载</wd-button>
          <wd-button type="primary" block :loading="true">下载中 {{ state.progress }}%</wd-button>
        </template>

        <template v-else-if="isReadyToInstall">
          <wd-button v-if="!state.forceUpdate" variant="plain" block @click="dismissAppUpdateModal">
            稍后安装
          </wd-button>
          <wd-button v-else variant="plain" block @click="reDownloadAppUpdate">重新下载</wd-button>
          <wd-button type="primary" block @click="startAppUpdateDownload">立即安装</wd-button>
        </template>

        <template v-else>
          <wd-button v-if="!state.forceUpdate" variant="plain" block @click="dismissAppUpdateModal">
            暂不更新
          </wd-button>
          <wd-button type="primary" block @click="startAppUpdateDownload">
            {{ state.errorMsg ? "重新下载" : "立即更新" }}
          </wd-button>
        </template>
      </view>

      <view
        v-if="isReadyToInstall && state.errorMsg && !state.forceUpdate"
        class="update-card__retry-link"
        @click="reDownloadAppUpdate"
      >
        <text class="update-card__retry-text">安装包异常？点击重新下载</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from "vue";
import {
  cancelAppUpdateDownload,
  dismissAppUpdateModal,
  formatUpdateByteSize,
  reDownloadAppUpdate,
  startAppUpdateDownload,
  useAppUpdateState,
} from "@/utils/app-update";

const state = useAppUpdateState();

const isReadyToInstall = computed(() => !state.downloading && Boolean(state.downloadedFilePath));

const showProgressPanel = computed(() => state.downloading || isReadyToInstall.value);

const progressStatusLabel = computed(() => {
  if (isReadyToInstall.value) {
    return "安装包已就绪，请安装";
  }
  return state.downloadedBytes > 0 ? "正在应用内下载..." : "正在连接服务器...";
});

const progressSizeText = computed(() => {
  if (isReadyToInstall.value) {
    const sizeText =
      state.totalBytes > 0
        ? `（${formatUpdateByteSize(state.totalBytes)}）`
        : state.downloadedBytes > 0
          ? `（${formatUpdateByteSize(state.downloadedBytes)}）`
          : "";
    return `v${state.latestVersion} 下载完成${sizeText}，点击「立即安装」即可覆盖升级`;
  }
  if (state.totalBytes > 0) {
    return `已下载 ${formatUpdateByteSize(state.downloadedBytes)} / ${formatUpdateByteSize(state.totalBytes)}`;
  }
  if (state.downloadedBytes > 0) {
    return `已下载 ${formatUpdateByteSize(state.downloadedBytes)}`;
  }
  return "请保持应用在前台，下载完成后将自动拉起安装";
});
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
  background: var(--color-overlay);
}

.update-card {
  width: 100%;
  max-width: 620rpx;
  padding: 34rpx 30rpx 28rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 20rpx;
  box-shadow: var(--shadow-lg);
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
  border-radius: 14rpx;
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
  box-sizing: border-box;
  max-height: 280rpx;
  padding: 18rpx 20rpx;
  background: var(--color-bg-page);
  border-radius: 12rpx;
}

.update-note-item {
  display: flex;
  gap: 14rpx;
  align-items: flex-start;

  & + .update-note-item {
    margin-top: 12rpx;
  }
}

.update-note-item__dot {
  flex-shrink: 0;
  width: 10rpx;
  height: 10rpx;
  margin-top: 14rpx;
  background: var(--color-primary);
  border-radius: 50%;
}

.update-note-item__text {
  flex: 1;
  font-size: 26rpx;
  line-height: 1.55;
  color: var(--color-text);
}

.update-progress-box {
  padding: 18rpx 20rpx;
  margin-top: 20rpx;
  background: var(--color-bg-page);
  border: 1px solid var(--color-border);
  border-radius: 12rpx;
}

.update-progress-box__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12rpx;
}

.update-progress-box__status {
  font-size: 24rpx;
  font-weight: 600;
  color: var(--color-text);
}

.update-progress-box__pct {
  font-size: 26rpx;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: var(--color-primary);
}

.update-progress-box__meta {
  display: block;
  margin-top: 10rpx;
  font-size: 22rpx;
  line-height: 1.4;
  color: var(--color-text-muted);
}

.update-card__error-box {
  padding: 14rpx 18rpx;
  margin-top: 16rpx;
  background: var(--color-danger-light);
  border-radius: 10rpx;
}

.update-card__error {
  display: block;
  font-size: 23rpx;
  line-height: 1.45;
  color: var(--color-danger-text);
}

.update-card__actions {
  display: flex;
  gap: 18rpx;
  margin-top: 24rpx;
}

.update-card__retry-link {
  margin-top: 16rpx;
  text-align: center;
}

.update-card__retry-text {
  font-size: 23rpx;
  color: var(--color-text-muted);
  text-decoration: underline;
}
</style>
