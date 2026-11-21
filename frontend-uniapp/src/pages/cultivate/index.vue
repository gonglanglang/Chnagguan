<template>
  <view class="cultivate-page">
    <app-navbar title="修炼课堂" :show-back="false" :show-home="false" :fixed="false" :placeholder="false" />

    <view class="tabs-wrap">
      <wd-tabs v-model="selectedRealm" @change="onRealmChange">
        <wd-tab name="" title="全部" />
        <wd-tab
          v-for="r in userStore.realms"
          :key="r.realmCode"
          :name="r.realmCode"
          :title="r.realmName"
        />
      </wd-tabs>
    </view>

    <scroll-view scroll-y :show-scrollbar="false" class="cultivate-scroll">
      <view class="page-body">
        <view v-if="loading && list.length === 0" class="loading-box">
          <wd-loading />
        </view>

        <view v-else-if="list.length === 0" class="empty-box">
          <app-icon name="cultivate-scroll" size="42" color="muted" />
          <text class="empty-box__title">暂无教学视频系列</text>
          <text class="empty-box__desc">老师在后台上传系列视频与课堂笔记后，即可在此修炼学习</text>
        </view>

        <view v-else class="series-list">
          <view
            v-for="item in list"
            :key="item.id"
            class="series-card"
            @click="openSeries(item)"
          >
            <view class="series-card__cover-wrap">
              <image
                v-if="item.coverImageUrl"
                :src="item.coverImageUrl"
                mode="aspectFill"
                class="series-card__cover"
              />
              <view v-else class="series-card__cover-fallback">
                <app-icon name="video-play" size="34" color="#ffffff" />
                <text class="series-card__fallback-txt">{{ item.realmName || "修炼精讲" }}</text>
              </view>
              <view class="series-card__lesson-pill">
                <app-icon name="play-circle" size="13" color="#ffffff" />
                <text>{{ item.lessonCount }} 节</text>
              </view>
            </view>

            <view class="series-card__body">
              <view class="series-card__title-row">
                <text class="series-card__title">{{ item.title }}</text>
                <wd-tag size="small" type="success" variant="light">
                  {{ item.realmName || "全境界" }}
                </wd-tag>
              </view>
              <view class="series-card__summary-row">
                <text class="series-card__intro">
                  {{ item.intro || "同步精讲视频与配套课堂笔记" }}
                </text>
                <view class="series-card__go">
                  <text>开始学习</text>
                  <app-icon name="right" size="13" color="primary" />
                </view>
              </view>
            </view>
          </view>

          <view v-if="list.length < total" class="load-more">
            <wd-button size="small" variant="plain" :loading="loading" @click="loadMore">
              加载更多 ({{ list.length }} / {{ total }})
            </wd-button>
          </view>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { onShow } from "@dcloudio/uni-app";
import { ref } from "vue";
import { AppVideoAPI } from "@/api/guoguanla";
import { useUserStore } from "@/store";
import type { VideoSeriesItem } from "@/types/guoguanla";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "cultivate",
  layout: "tabbar",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "修炼",
  },
});

const userStore = useUserStore();
const toast = useToast();

const selectedRealm = ref("");
const loading = ref(false);
const pageNum = ref(1);
const pageSize = 12;
const total = ref(0);
const list = ref<VideoSeriesItem[]>([]);

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
  } catch (err) {
    toast.error(getErrorMessage(err, "加载教学视频失败"));
  } finally {
    loading.value = false;
  }
}

function onRealmChange(payload: { name: string | number }): void {
  selectedRealm.value = String(payload.name);
  void fetchSeries(true);
}

function loadMore(): void {
  if (loading.value || list.value.length >= total.value) return;
  pageNum.value += 1;
  void fetchSeries(false);
}

function openSeries(item: VideoSeriesItem): void {
  uni.navigateTo({
    url: `/subPages/video-detail/index?id=${item.id}`,
  });
}

onShow(() => {
  void userStore.loadHomeSummary(true);
  void fetchSeries(true);
});
</script>

<style lang="scss" scoped>
.cultivate-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  background: var(--color-bg-page);
}

.tabs-wrap {
  flex-shrink: 0;
  background: var(--color-bg-card);
  border-bottom: 1px solid var(--color-border);
}

.cultivate-scroll {
  flex: 1;
  min-height: 0;
}

.page-body {
  padding: 20rpx 24rpx 48rpx;
}

.loading-box {
  display: flex;
  justify-content: center;
  padding: 96rpx 0;
}

.empty-box {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
  align-items: center;
  padding: 120rpx 36rpx;
  text-align: center;
}

.empty-box__title {
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text);
}

.empty-box__desc {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.series-list {
  display: flex;
  flex-direction: column;
  gap: 22rpx;
}

.series-card {
  overflow: hidden;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.series-card__cover-wrap {
  position: relative;
  width: 100%;
  height: 330rpx;
  background: #0f172a;
}

.series-card__cover {
  width: 100%;
  height: 100%;
}

.series-card__cover-fallback {
  display: flex;
  flex-direction: column;
  gap: 10rpx;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, #16a34a 0%, #15803d 100%);
}

.series-card__fallback-txt {
  font-size: 26rpx;
  font-weight: 600;
  color: #ffffff;
}

.series-card__lesson-pill {
  position: absolute;
  right: 18rpx;
  bottom: 18rpx;
  display: flex;
  gap: 6rpx;
  align-items: center;
  padding: 6rpx 16rpx;
  font-size: 22rpx;
  font-weight: 500;
  color: #ffffff;
  background: rgba(15, 23, 42, 0.72);
  border-radius: 999rpx;
}

.series-card__body {
  padding: 22rpx 24rpx;
}

.series-card__title-row {
  display: flex;
  gap: 12rpx;
  align-items: flex-start;
  justify-content: space-between;
}

.series-card__title {
  flex: 1;
  font-size: 31rpx;
  font-weight: 600;
  line-height: 1.4;
  color: var(--color-text);
}

.series-card__summary-row {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
  margin-top: 12rpx;
}

.series-card__intro {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 25rpx;
  line-height: 1.4;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.series-card__go {
  display: inline-flex;
  flex-shrink: 0;
  gap: 4rpx;
  align-items: center;
  font-size: 25rpx;
  font-weight: 600;
  color: var(--color-primary);
  white-space: nowrap;
}

.load-more {
  display: flex;
  justify-content: center;
  padding: 12rpx 0;
}
</style>
