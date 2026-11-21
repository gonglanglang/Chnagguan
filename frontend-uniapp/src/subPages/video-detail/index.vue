<template>
  <app-page-shell ref="shellRef" :title="detail?.series.title || '修炼课堂'">
    <template #header>
      <app-navbar
        :title="detail?.series.title || '修炼课堂'"
        :show-back="true"
        :show-home="false"
        :fixed="false"
        :placeholder="false"
      />
      <view v-if="activeLesson?.videoUrl" class="player-wrap">
        <video
          v-if="userStore.isAuthenticated"
          id="courseVideoPlayer"
          :key="activeLesson.id"
          :src="activeLesson.videoUrl"
          :poster="activeLesson.coverImageUrl || detail?.series.coverImageUrl || undefined"
          :autoplay="shouldAutoPlay"
          controls
          show-center-play-btn
          class="player-video"
          @play="onVideoPlay"
          @fullscreenchange="onVideoFullscreenChange"
        />
        <view v-else class="player-gate" @click="requireLoginToWatch">
          <image
            v-if="activeLesson.coverImageUrl || detail?.series.coverImageUrl"
            :src="activeLesson.coverImageUrl || detail?.series.coverImageUrl"
            mode="aspectFill"
            class="player-gate__poster"
          />
          <view class="player-gate__mask">
            <view class="player-gate__btn">
              <app-icon name="play-circle" size="40" color="#ffffff" />
            </view>
            <text class="player-gate__title">点击播放课程视频</text>
            <text class="player-gate__sub">请先登录后观看</text>
          </view>
        </view>
      </view>
    </template>

    <view v-if="loading" class="state-box">
      <wd-loading />
    </view>

    <view v-else-if="detail" class="detail-body">
      <view class="series-card">
        <view class="series-card__head">
          <text class="series-card__title">{{ detail.series.title }}</text>
          <wd-tag size="small" type="success" variant="light">
            {{ detail.series.realmName || "全境界" }}
          </wd-tag>
        </view>
        <text v-if="detail.series.intro" class="series-card__intro">
          {{ detail.series.intro }}
        </text>
      </view>

      <!-- 当前课时课堂笔记（显示在课程目录上方；备注与附件皆为空时不展示） -->
      <view v-if="activeLesson && hasActiveLessonNotes" class="section-card">
        <view class="section-card__head">
          <view class="section-card__title-wrap">
            <app-icon name="notes" size="17" color="primary" />
            <text class="section-card__title">课堂笔记 · {{ activeLesson.title }}</text>
          </view>
        </view>

        <view v-if="activeLesson.classNotes && activeLesson.classNotes.trim()" class="notes-body">
          <math-text :key="activeLesson.id" :text="activeLesson.classNotes" />
        </view>

        <view
          v-if="activeLesson.notesAttachments && activeLesson.notesAttachments.length > 0"
          class="att-section"
          :class="{ 'att-section--divided': Boolean(activeLesson.classNotes && activeLesson.classNotes.trim()) }"
        >
          <text class="att-section__title">笔记附件（{{ activeLesson.notesAttachments.length }} 个）</text>
          <view class="att-list">
            <view
              v-for="(att, idx) in activeLesson.notesAttachments"
              :key="`${activeLesson.id}-att-${idx}`"
              class="att-row"
              @click="openAttachment(att)"
            >
              <view class="att-row__left">
                <view class="att-row__icon">
                  <app-icon
                    :name="isImageAttachment(att) ? 'camera' : 'notes'"
                    size="16"
                    color="primary"
                  />
                </view>
                <view class="att-row__meta">
                  <text class="att-row__name">{{ att.name }}</text>
                  <text class="att-row__size">{{ formatFileSize(att.size) }}</text>
                </view>
              </view>
              <text class="att-row__action">{{ isImageAttachment(att) ? "预览" : "打开" }}</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 选集课程列表（不展示卡片顶部标题） -->
      <view class="section-card">
        <view v-if="detail.lessons.length === 0" class="empty-tip">
          该系列暂未上传视频课时
        </view>

        <view v-else class="lesson-list">
          <view
            v-for="(lesson, idx) in detail.lessons"
            :key="lesson.id"
            class="lesson-row"
            :class="{ 'lesson-row--active': activeLesson?.id === lesson.id }"
            @click="selectLesson(lesson)"
          >
            <view class="lesson-row__left">
              <image
                v-if="lesson.coverImageUrl || detail.series.coverImageUrl"
                :src="lesson.coverImageUrl || detail.series.coverImageUrl"
                mode="aspectFill"
                class="lesson-row__thumb"
              />
              <view
                v-else
                class="lesson-row__no"
                :class="{ 'lesson-row__no--active': activeLesson?.id === lesson.id }"
              >
                {{ idx + 1 }}
              </view>
              <text class="lesson-row__title">{{ idx + 1 }}. {{ lesson.title }}</text>
            </view>
            <view class="lesson-row__right">
              <text v-if="lesson.durationSec > 0" class="lesson-row__dur">
                {{ formatDuration(lesson.durationSec) }}
              </text>
              <app-icon
                name="play-circle"
                size="16"
                :color="activeLesson?.id === lesson.id ? 'primary' : 'muted'"
              />
            </view>
          </view>
        </view>
      </view>
    </view>
  </app-page-shell>
</template>

<script setup lang="ts">
import { onLoad, onShow } from "@dcloudio/uni-app";
import { computed, ref } from "vue";
import { AppVideoAPI } from "@/api/guoguanla";
import { useUserStore } from "@/store";
import type { NoteAttachmentItem, VideoLessonItem, VideoSeriesDetail } from "@/types/guoguanla";
import { getErrorMessage } from "@/utils/error";
import { enforceOrientationRepeatedly } from "@/utils/orientation";

definePage({
  name: "video-detail",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "修炼课堂",
  },
});

const userStore = useUserStore();
const toast = useToast();
const shellRef = ref<{ scrollToTop: () => void } | null>(null);
const loading = ref(true);
const detail = ref<VideoSeriesDetail | null>(null);
const activeLesson = ref<VideoLessonItem | null>(null);
const seriesId = ref(0);
const initialLessonId = ref(0);
const shouldAutoPlay = ref(false);

const hasActiveLessonNotes = computed(() => {
  const lesson = activeLesson.value;
  if (!lesson) return false;
  const hasNotes = Boolean(lesson.classNotes && lesson.classNotes.trim());
  const hasAttachments = Array.isArray(lesson.notesAttachments) && lesson.notesAttachments.length > 0;
  return hasNotes || hasAttachments;
});

function formatDuration(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

function formatFileSize(bytes?: number): string {
  const n = Math.max(0, Number(bytes || 0));
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

function isImageAttachment(att: NoteAttachmentItem): boolean {
  const ct = (att.contentType || "").toLowerCase();
  const name = (att.name || "").toLowerCase();
  return ct.startsWith("image/") || /\.(png|jpe?g|webp|gif)$/.test(name);
}

function copyAttachmentUrl(att: NoteAttachmentItem): void {
  if (!att.url) {
    toast.error("附件链接不可用");
    return;
  }
  uni.setClipboardData({
    data: att.url,
    success: () => {
      uni.showModal({
        title: "已复制下载链接",
        content: `已复制附件「${att.name}」的下载地址，可在系统浏览器粘贴打开或下载。`,
        showCancel: false,
      });
    },
  });
}

function openAttachment(att: NoteAttachmentItem): void {
  if (!att.url) {
    toast.error("附件链接已失效，请刷新页面重试");
    return;
  }
  if (isImageAttachment(att)) {
    const imgUrls = (activeLesson.value?.notesAttachments || [])
      .filter((item) => isImageAttachment(item) && Boolean(item.url))
      .map((item) => item.url);
    uni.previewImage({
      urls: imgUrls.length > 0 ? imgUrls : [att.url],
      current: att.url,
    });
    return;
  }

  // #ifdef APP-PLUS || MP
  uni.showLoading({ title: "正在打开附件..." });
  uni.downloadFile({
    url: att.url,
    success: (dlRes) => {
      if (dlRes.statusCode >= 200 && dlRes.statusCode < 300 && dlRes.tempFilePath) {
        uni.openDocument({
          filePath: dlRes.tempFilePath,
          showMenu: true,
          complete: () => uni.hideLoading(),
          fail: () => copyAttachmentUrl(att),
        });
      } else {
        uni.hideLoading();
        copyAttachmentUrl(att);
      }
    },
    fail: () => {
      uni.hideLoading();
      copyAttachmentUrl(att);
    },
  });
  // #endif

  // #ifdef H5
  copyAttachmentUrl(att);
  // #endif
}

function buildCurrentVideoUrl(autoPlay = true): string {
  const params: string[] = [`id=${seriesId.value}`];
  if (activeLesson.value?.id) {
    params.push(`lessonId=${activeLesson.value.id}`);
  }
  if (autoPlay) {
    params.push("autoPlay=1");
  }
  return `/subPages/video-detail/index?${params.join("&")}`;
}

function requireLoginToWatch(): void {
  const redirect = encodeURIComponent(buildCurrentVideoUrl(true));
  toast.warning("请先登录后再观看课程视频");
  uni.redirectTo({
    url: `/subPages/login/index?redirect=${redirect}`,
    fail: () => {
      uni.navigateTo({
        url: `/subPages/login/index?redirect=${redirect}`,
      });
    },
  });
}

function onVideoPlay(): void {
  if (!userStore.isAuthenticated) {
    try {
      uni.createVideoContext("courseVideoPlayer").pause();
    } catch {
      // ignore pause fallback error
    }
    requireLoginToWatch();
  }
}

function onVideoFullscreenChange(e: { detail?: { fullScreen?: boolean } }): void {
  if (!e?.detail?.fullScreen) {
    enforceOrientationRepeatedly();
  }
}

function selectLesson(lesson: VideoLessonItem): void {
  shouldAutoPlay.value = false;
  activeLesson.value = lesson;
  shellRef.value?.scrollToTop();
}

async function fetchDetail(id: number): Promise<void> {
  loading.value = true;
  try {
    const res = await AppVideoAPI.getSeriesDetail(id);
    detail.value = res;
    const matched = initialLessonId.value > 0
      ? res.lessons.find((item) => item.id === initialLessonId.value)
      : undefined;
    activeLesson.value = matched || res.lessons[0] || null;
  } catch (err) {
    toast.error(getErrorMessage(err, "加载教学视频失败"));
  } finally {
    loading.value = false;
  }
}

onLoad((query) => {
  const id = Number(query?.id || 0);
  seriesId.value = id;
  initialLessonId.value = Number(query?.lessonId || 0);
  shouldAutoPlay.value = query?.autoPlay === "1";
  if (id > 0) {
    void fetchDetail(id);
  } else {
    loading.value = false;
  }
});

onShow(() => {
  enforceOrientationRepeatedly();
});
</script>

<style lang="scss" scoped>
.player-wrap {
  width: 100%;
  background: #0f172a;
}

.player-video {
  display: block;
  width: 100%;
  height: 420rpx;
}

.player-gate {
  position: relative;
  width: 100%;
  height: 420rpx;
  overflow: hidden;
  background: #0f172a;
}

.player-gate__poster {
  width: 100%;
  height: 100%;
}

.player-gate__mask {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  flex-direction: column;
  gap: 10rpx;
  align-items: center;
  justify-content: center;
  background: rgba(15, 23, 42, 0.56);
}

.player-gate__btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 108rpx;
  height: 108rpx;
  background: rgba(22, 163, 74, 0.88);
  border-radius: 50%;
  box-shadow: 0 8rpx 24rpx rgba(0, 0, 0, 0.28);
}

.player-gate__title {
  margin-top: 6rpx;
  font-size: 28rpx;
  font-weight: 600;
  color: #ffffff;
}

.player-gate__sub {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.82);
}

.state-box {
  display: flex;
  justify-content: center;
  padding: 120rpx 0;
}

.detail-body {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.series-card,
.section-card {
  padding: 24rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 18rpx;
  box-shadow: var(--shadow-sm);
}

.series-card__head {
  display: flex;
  gap: 12rpx;
  align-items: flex-start;
  justify-content: space-between;
}

.series-card__title {
  flex: 1;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text);
}

.series-card__intro {
  display: block;
  margin-top: 12rpx;
  font-size: 25rpx;
  line-height: 1.55;
  color: var(--color-text-secondary);
}

.section-card__head {
  margin-bottom: 16rpx;
}

.section-card__title-wrap {
  display: flex;
  gap: 10rpx;
  align-items: center;
}

.section-card__title {
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text);
}

.lesson-list {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.lesson-row {
  display: flex;
  gap: 14rpx;
  align-items: center;
  justify-content: space-between;
  padding: 18rpx 16rpx;
  background: var(--color-bg-page);
  border: 1px solid transparent;
  border-radius: 14rpx;

  &--active {
    background: var(--color-primary-soft);
    border-color: var(--color-primary);
  }
}

.lesson-row__left {
  display: flex;
  flex: 1;
  gap: 14rpx;
  align-items: center;
  min-width: 0;
}

.lesson-row__no {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 44rpx;
  height: 44rpx;
  font-size: 22rpx;
  font-weight: 600;
  color: var(--color-text-secondary);
  background: var(--color-bg-card);
  border-radius: 10rpx;

  &--active {
    color: #ffffff;
    background: var(--color-primary);
  }
}

.lesson-row__thumb {
  flex-shrink: 0;
  width: 96rpx;
  height: 58rpx;
  background: #e2e8f0;
  border-radius: 10rpx;
}

.lesson-row__title {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 26rpx;
  font-weight: 500;
  color: var(--color-text);
  white-space: nowrap;
}

.lesson-row__right {
  display: flex;
  flex-shrink: 0;
  gap: 8rpx;
  align-items: center;
}

.lesson-row__dur {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.notes-body {
  font-size: 27rpx;
  line-height: 1.7;
  color: var(--color-text);
  white-space: pre-wrap;
}

.att-section {
  margin-top: 8rpx;

  &--divided {
    padding-top: 20rpx;
    margin-top: 20rpx;
    border-top: 1px solid var(--color-border);
  }
}

.att-section__title {
  display: block;
  margin-bottom: 12rpx;
  font-size: 24rpx;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.att-list {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.att-row {
  display: flex;
  gap: 12rpx;
  align-items: center;
  justify-content: space-between;
  padding: 16rpx 18rpx;
  background: var(--color-bg-page);
  border: 1px solid var(--color-border);
  border-radius: 14rpx;

  &:active {
    opacity: 0.78;
  }
}

.att-row__left {
  display: flex;
  flex: 1;
  gap: 14rpx;
  align-items: center;
  min-width: 0;
}

.att-row__icon {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 56rpx;
  height: 56rpx;
  background: var(--color-primary-soft);
  border-radius: 12rpx;
}

.att-row__meta {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 4rpx;
  min-width: 0;
}

.att-row__name {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 26rpx;
  font-weight: 500;
  color: var(--color-text);
  white-space: nowrap;
}

.att-row__size {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.att-row__action {
  flex-shrink: 0;
  padding: 6rpx 16rpx;
  font-size: 22rpx;
  font-weight: 600;
  color: var(--color-primary);
  background: var(--color-primary-soft);
  border-radius: 999rpx;
}

.empty-tip {
  padding: 20rpx 0;
  font-size: 24rpx;
  color: var(--color-text-muted);
  text-align: center;
}
</style>
