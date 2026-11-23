<template>
  <view class="cultivate-page">
    <app-navbar title="修炼课堂" :show-back="false" :fixed="false" />

    <scroll-view
      scroll-y
      :show-scrollbar="false"
      class="cultivate-scroll"
      @scrolltolower="loadMore"
    >
      <view class="cultivate-body">
        <template v-if="loading && list.length === 0 && featuredList.length === 0">
          <text class="ggl-section-label cultivate-label">本周精选</text>
          <view class="featured-skeleton">
            <wd-skeleton
              animation="gradient"
              :row-col="[
                [{ width: '100%', height: '155px' }],
                [{ width: '62%', height: '18px' }],
                [{ width: '44%', height: '14px' }],
              ]"
            />
          </view>

          <text class="ggl-section-label cultivate-label">全部课程</text>
          <view class="courses-card">
            <view v-for="n in 3" :key="n" class="course-skeleton-row">
              <wd-skeleton
                animation="gradient"
                :row-col="[[{ width: '112px', height: '70px' }, { width: '56%', height: '64px' }]]"
              />
            </view>
          </view>
        </template>

        <template v-else>
          <!-- 本周精选横向轮播 -->
          <template v-if="featuredList.length > 0">
            <text class="ggl-section-label cultivate-label">本周精选</text>

            <swiper
              class="featured-swiper"
              :current="featuredIndex"
              previous-margin="24rpx"
              next-margin="88rpx"
              @change="onFeaturedChange"
            >
              <swiper-item v-for="item in featuredList" :key="item.id">
                <view class="featured-card" @click="openCourseDrawer(item)">
                  <view class="featured-cover">
                    <image
                      v-if="item.coverImageUrl"
                      :src="item.coverImageUrl"
                      mode="aspectFill"
                      class="featured-cover__img"
                    />
                    <view v-else class="featured-cover__placeholder">
                      <app-icon name="circle-play" :size="36" color="primary" />
                    </view>
                    <view class="featured-cover__badge">
                      <text class="featured-cover__badge-text">{{ item.lessonCount }} 课时</text>
                    </view>
                  </view>

                  <view class="featured-info">
                    <text class="featured-info__title">{{ item.title }}</text>
                    <text class="featured-info__sub">
                      {{ item.realmName || "专题课程" }} · {{ item.intro || "名师精讲 · 配套讲义" }}
                    </text>
                  </view>
                </view>
              </swiper-item>
            </swiper>

            <view v-if="featuredList.length > 1" class="swiper-dots">
              <view
                v-for="(item, idx) in featuredList"
                :key="item.id"
                class="swiper-dot"
                :class="{ 'swiper-dot--active': idx === featuredIndex }"
              />
            </view>
          </template>

          <!-- 全部课程（境界筛选 + 白卡分隔列表） -->
          <text class="ggl-section-label cultivate-label">全部课程</text>

          <view class="courses-card">
            <scroll-view scroll-x :show-scrollbar="false" class="filter-tabs-scroll">
              <view class="filter-tabs">
                <view
                  class="filter-tab"
                  :class="{ 'filter-tab--active': selectedRealm === '' }"
                  @click="selectRealm('')"
                >
                  <text class="filter-tab__text">全部</text>
                  <view v-if="selectedRealm === ''" class="filter-tab__bar" />
                </view>
                <view
                  v-for="realm in userStore.realms"
                  :key="realm.realmCode"
                  class="filter-tab"
                  :class="{ 'filter-tab--active': selectedRealm === realm.realmCode }"
                  @click="selectRealm(realm.realmCode)"
                >
                  <text class="filter-tab__text">{{ realm.realmName }}</text>
                  <view v-if="selectedRealm === realm.realmCode" class="filter-tab__bar" />
                </view>
              </view>
            </scroll-view>

            <view v-if="loading && list.length === 0" class="course-skeleton-list">
              <view v-for="n in 3" :key="n" class="course-skeleton-row">
                <wd-skeleton
                  animation="gradient"
                  :row-col="[[{ width: '112px', height: '70px' }, { width: '56%', height: '64px' }]]"
                />
              </view>
            </view>

            <view v-else-if="list.length === 0" class="courses-empty">
              <app-icon name="circle-play" :size="30" color="muted" />
              <text class="courses-empty__title">暂无教学课程</text>
              <text class="courses-empty__desc">切换其他境界查看，或等待教研老师上传新课</text>
            </view>

            <view v-else class="course-list">
              <view
                v-for="(item, idx) in list"
                :key="item.id"
                class="course-row"
                @click="openCourseDrawer(item)"
              >
                <view class="course-row__inner">
                  <view class="course-thumb">
                    <image
                      v-if="item.coverImageUrl"
                      :src="item.coverImageUrl"
                      mode="aspectFill"
                      class="course-thumb__img"
                    />
                    <view v-else class="course-thumb__placeholder">
                      <app-icon name="circle-play" :size="24" color="primary" />
                    </view>
                  </view>

                  <view class="course-meta">
                    <text class="course-meta__title">{{ item.title }}</text>
                    <view class="course-meta__tags">
                      <text class="course-meta__realm">{{ item.realmName || "全境界" }}</text>
                      <text class="ggl-tag ggl-tag--success">讲师笔记</text>
                    </view>
                    <text class="course-meta__foot">
                      {{ item.lessonCount }} 节 · {{ item.intro || "名师讲解 · 点击选集" }}
                    </text>
                  </view>
                </view>
                <view v-if="idx < list.length - 1" class="course-row__divider" />
              </view>

              <view v-if="loading" class="list-foot-status">
                <text class="list-foot-status__text">正在加载更多课程...</text>
              </view>
              <view v-else-if="list.length >= total && total > 0" class="list-foot-status">
                <text class="list-foot-status__text">已显示全部 {{ total }} 门课程</text>
              </view>
            </view>
          </view>
        </template>
      </view>
    </scroll-view>

    <!-- 课程目录底部抽屉 -->
    <wd-popup
      v-model="showCourseDrawer"
      position="bottom"
      :z-index="900"
      safe-area-inset-bottom
      custom-style="border-top-left-radius: 32rpx; border-top-right-radius: 32rpx; overflow: hidden;"
    >
      <view v-if="activeSeries" class="drawer-sheet">
        <view class="drawer-sheet__header">
          <view class="drawer-sheet__close-placeholder" />
          <text class="drawer-sheet__title">{{ activeSeries.title }}</text>
          <view class="drawer-sheet__close" @click="showCourseDrawer = false">
            <app-icon name="close" :size="18" color="muted" />
          </view>
        </view>

        <text class="drawer-sheet__sub">
          {{ activeSeries.realmName || "综合课程" }} · 共 {{ drawerLessons.length || activeSeries.lessonCount }} 节
        </text>

        <view v-if="drawerLoading" class="drawer-loading">
          <view v-for="n in 3" :key="n" class="drawer-skeleton-row">
            <wd-skeleton
              animation="gradient"
              :row-col="[[{ width: '18px', height: '18px', type: 'circle' }, { width: '58%', height: '16px' }, { width: '16%', height: '14px' }]]"
            />
          </view>
        </view>

        <view v-else-if="drawerLessons.length === 0" class="drawer-empty">
          <text class="drawer-empty__text">该课程暂未添加课时，点击下方按钮可查看课程简介</text>
        </view>

        <scroll-view v-else scroll-y :show-scrollbar="false" class="drawer-list-scroll">
          <view class="drawer-lesson-card">
            <view
              v-for="(lesson, lIdx) in drawerLessons"
              :key="lesson.id"
              class="drawer-lesson-row"
              @click="selectedLessonId = lesson.id"
            >
              <view class="drawer-lesson-row__inner">
                <view class="drawer-lesson-row__left">
                  <app-icon
                    name="circle-play"
                    :size="16"
                    :color="selectedLessonId === lesson.id ? 'primary' : 'muted'"
                  />
                  <text
                    class="drawer-lesson-row__title"
                    :class="{ 'drawer-lesson-row__title--active': selectedLessonId === lesson.id }"
                  >
                    第 {{ lIdx + 1 }} 节 · {{ lesson.title }}
                  </text>
                </view>
                <text class="drawer-lesson-row__dur">{{ formatDuration(lesson.durationSec) }}</text>
              </view>
              <view v-if="lIdx < drawerLessons.length - 1" class="drawer-lesson-row__divider" />
            </view>
          </view>
        </scroll-view>

        <view class="drawer-sheet__footer">
          <view class="drawer-start-btn" @click="startLearningSelected">
            <text class="drawer-start-btn__text">开始学习</text>
          </view>
        </view>
      </view>
    </wd-popup>
  </view>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { onShow } from "@dcloudio/uni-app";
import { useToast } from "@wot-ui/ui";
import { AppVideoAPI } from "@/api/guoguanla";
import { useUserStore } from "@/store";
import type { VideoLessonItem, VideoSeriesItem } from "@/types/guoguanla";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "cultivate",
  layout: "tabbar",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "课堂",
  },
});

const userStore = useUserStore();
const toast = useToast();

const selectedRealm = ref("");
const loading = ref(true);
const pageNum = ref(1);
const pageSize = 12;
const total = ref(0);
const list = ref<VideoSeriesItem[]>([]);
const featuredList = ref<VideoSeriesItem[]>([]);
const featuredIndex = ref(0);

const showCourseDrawer = ref(false);
const activeSeries = ref<VideoSeriesItem | null>(null);
const drawerLoading = ref(false);
const drawerLessons = ref<VideoLessonItem[]>([]);
const selectedLessonId = ref<number>(0);

function onFeaturedChange(e: { detail?: { current?: number } }): void {
  featuredIndex.value = e?.detail?.current ?? 0;
}

function formatDuration(sec?: number): string {
  const s = Math.max(0, Number(sec) || 0);
  const mm = String(Math.floor(s / 60)).padStart(2, "0");
  const ss = String(Math.floor(s % 60)).padStart(2, "0");
  return `${mm}:${ss}`;
}

async function fetchFeatured(): Promise<void> {
  try {
    const res = await AppVideoAPI.getSeriesPage({ pageNum: 1, pageSize: 5 });
    featuredList.value = res.records;
    if (featuredIndex.value >= featuredList.value.length) {
      featuredIndex.value = 0;
    }
  } catch {
    // Fallback handled by main list fetch
  }
}

async function fetchSeries(reset = true): Promise<void> {
  if (reset) pageNum.value = 1;
  loading.value = true;
  try {
    const res = await AppVideoAPI.getSeriesPage({
      realmCode: selectedRealm.value || undefined,
      pageNum: pageNum.value,
      pageSize,
    });
    total.value = res.total;
    list.value = reset ? res.records : [...list.value, ...res.records];
    if (!selectedRealm.value && reset) {
      featuredList.value = res.records.slice(0, 5);
    }
  } catch (err) {
    toast.error(getErrorMessage(err, "加载教学视频失败"));
  } finally {
    loading.value = false;
  }
}

function selectRealm(realmCode: string): void {
  selectedRealm.value = realmCode;
  list.value = [];
  void fetchSeries(true);
}

function loadMore(): void {
  if (loading.value || list.value.length >= total.value) return;
  pageNum.value += 1;
  void fetchSeries(false);
}

async function openCourseDrawer(series: VideoSeriesItem): Promise<void> {
  activeSeries.value = series;
  drawerLessons.value = [];
  selectedLessonId.value = 0;
  showCourseDrawer.value = true;
  drawerLoading.value = true;
  try {
    const detail = await AppVideoAPI.getSeriesDetail(series.id);
    drawerLessons.value = detail.lessons || [];
    selectedLessonId.value = drawerLessons.value[0]?.id || 0;
  } catch (err) {
    toast.error(getErrorMessage(err, "加载课程目录失败"));
  } finally {
    drawerLoading.value = false;
  }
}

function startLearningSelected(): void {
  if (!activeSeries.value) return;
  const seriesId = activeSeries.value.id;
  const lessonId = selectedLessonId.value;
  showCourseDrawer.value = false;
  const url = lessonId > 0
    ? `/subPages/video-detail/index?id=${seriesId}&lessonId=${lessonId}`
    : `/subPages/video-detail/index?id=${seriesId}`;
  uni.navigateTo({ url });
}

onShow(() => {
  void userStore.loadHomeSummary(true);
  if (selectedRealm.value) {
    void fetchFeatured();
  }
  void fetchSeries(true);
});
</script>

<style lang="scss" scoped>
.cultivate-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  background-color: var(--color-bg-page);
}

.cultivate-scroll {
  flex: 1;
  min-height: 0;
}

.cultivate-body {
  padding-bottom: 44rpx;
}

.cultivate-label {
  margin-top: 24rpx;
}

.featured-skeleton {
  padding: 24rpx;
  margin: 0 24rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.featured-swiper {
  height: 444rpx;
}

.featured-card {
  height: 432rpx;
  margin-right: 20rpx;
  overflow: hidden;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.featured-cover {
  position: relative;
  width: 100%;
  height: 300rpx;
  background-color: var(--color-primary-soft);
}

.featured-cover__img {
  width: 100%;
  height: 100%;
}

.featured-cover__placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
}

.featured-cover__badge {
  position: absolute;
  right: 16rpx;
  bottom: 16rpx;
  padding: 6rpx 16rpx;
  background-color: rgba(0, 0, 0, 0.6);
  border-radius: 9999px;
}

.featured-cover__badge-text {
  font-size: 22rpx;
  color: #ffffff;
}

.featured-info {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
  padding: 22rpx 24rpx;
}

.featured-info__title {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 30rpx;
  font-weight: 700;
  color: var(--color-text);
  white-space: nowrap;
}

.featured-info__sub {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 24rpx;
  color: var(--color-text-muted);
  white-space: nowrap;
}

.swiper-dots {
  display: flex;
  gap: 10rpx;
  align-items: center;
  justify-content: center;
  margin-top: 16rpx;
}

.swiper-dot {
  width: 8rpx;
  height: 8rpx;
  background-color: var(--color-border-strong);
  border-radius: 9999px;
  transition: width 0.2s ease, background-color 0.2s ease;

  &--active {
    width: 24rpx;
    background-color: var(--color-primary);
  }
}

.courses-card {
  margin: 0 24rpx;
  overflow: hidden;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.filter-tabs-scroll {
  width: 100%;
  border-bottom: 1px solid var(--color-border);
}

.filter-tabs {
  display: flex;
  align-items: center;
  padding: 0 12rpx;
}

.filter-tab {
  position: relative;
  display: flex;
  flex: 1 0 auto;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-width: 104rpx;
  height: 84rpx;
  padding: 0 18rpx;
}

.filter-tab__text {
  font-size: 28rpx;
  color: var(--color-text-muted);
  white-space: nowrap;
}

.filter-tab--active .filter-tab__text {
  font-weight: 600;
  color: var(--color-text);
}

.filter-tab__bar {
  position: absolute;
  bottom: 0;
  width: 38rpx;
  height: 6rpx;
  background-color: var(--color-primary);
  border-radius: 9999px;
}

.course-skeleton-list {
  padding: 8rpx 0;
}

.course-skeleton-row {
  padding: 28rpx;
  border-bottom: 1px solid var(--color-border);

  &:last-child {
    border-bottom: none;
  }
}

.courses-empty {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
  align-items: center;
  padding: 80rpx 32rpx;
  text-align: center;
}

.courses-empty__title {
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text);
}

.courses-empty__desc {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.course-list {
  display: flex;
  flex-direction: column;
}

.course-row {
  background-color: var(--color-bg-card);

  &:active {
    background-color: var(--color-fill-1);
  }
}

.course-row__inner {
  display: flex;
  gap: 24rpx;
  align-items: center;
  padding: 28rpx;
}

.course-row__divider {
  height: 1px;
  margin: 0 28rpx;
  background-color: var(--color-border);
}

.course-thumb {
  flex-shrink: 0;
  width: 224rpx;
  height: 140rpx;
  overflow: hidden;
  background-color: var(--color-primary-soft);
  border-radius: 12rpx;
}

.course-thumb__img {
  width: 100%;
  height: 100%;
}

.course-thumb__placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
}

.course-meta {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 10rpx;
  min-width: 0;
}

.course-meta__title {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text);
  white-space: nowrap;
}

.course-meta__tags {
  display: flex;
  gap: 12rpx;
  align-items: center;
}

.course-meta__realm {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.course-meta__foot {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 22rpx;
  color: var(--color-text-placeholder);
  white-space: nowrap;
}

.list-foot-status {
  padding: 24rpx 0;
  text-align: center;
}

.list-foot-status__text {
  font-size: 24rpx;
  color: var(--color-text-placeholder);
}

.drawer-sheet {
  display: flex;
  flex-direction: column;
  max-height: 76vh;
  padding: 28rpx 32rpx 32rpx;
  overflow: hidden;
  background-color: var(--color-bg-card);
}

.drawer-sheet__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.drawer-sheet__close-placeholder {
  width: 48rpx;
  height: 48rpx;
}

.drawer-sheet__title {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text);
  text-align: center;
  white-space: nowrap;
}

.drawer-sheet__close {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48rpx;
  height: 48rpx;
}

.drawer-sheet__sub {
  margin-top: 12rpx;
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.drawer-loading {
  margin-top: 24rpx;
}

.drawer-skeleton-row {
  padding: 22rpx 0;
}

.drawer-empty {
  padding: 48rpx 16rpx;
  margin-top: 20rpx;
  text-align: center;
  border: 1px solid var(--color-border);
  border-radius: 16rpx;
}

.drawer-empty__text {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.drawer-list-scroll {
  flex: 1;
  min-height: 0;
  max-height: 48vh;
  margin-top: 24rpx;
}

.drawer-lesson-card {
  overflow: hidden;
  border: 1px solid var(--color-border);
  border-radius: 16rpx;
}

.drawer-lesson-row {
  background-color: var(--color-bg-card);

  &:active {
    background-color: var(--color-fill-1);
  }
}

.drawer-lesson-row__inner {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
  padding: 26rpx 24rpx;
}

.drawer-lesson-row__left {
  display: flex;
  flex: 1;
  gap: 16rpx;
  align-items: center;
  min-width: 0;
}

.drawer-lesson-row__title {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 28rpx;
  color: var(--color-text);
  white-space: nowrap;

  &--active {
    font-weight: 500;
    color: var(--color-primary);
  }
}

.drawer-lesson-row__dur {
  flex-shrink: 0;
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.drawer-lesson-row__divider {
  height: 1px;
  margin: 0 24rpx;
  background-color: var(--color-border);
}

.drawer-sheet__footer {
  margin-top: 28rpx;
}

.drawer-start-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 88rpx;
  background-color: var(--color-primary);
  border-radius: 9999px;
}

.drawer-start-btn__text {
  font-size: 30rpx;
  font-weight: 600;
  color: #ffffff;
}
</style>
