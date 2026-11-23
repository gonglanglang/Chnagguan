<template>
  <view class="wrong-page">
    <app-navbar title="错题本" :show-back="false" :fixed="false" />

    <!-- 顶部粘性全宽筛选 Tab -->
    <view v-if="userStore.isAuthenticated" class="filter-bar">
      <scroll-view scroll-x :show-scrollbar="false" class="filter-scroll">
        <view class="filter-tabs">
          <view
            class="filter-tab"
            :class="{ 'filter-tab--active': selectedFilter === 'all' }"
            @click="selectFilter('all')"
          >
            <text class="filter-tab__text">全部</text>
            <view v-if="selectedFilter === 'all'" class="filter-tab__bar" />
          </view>
          <view
            class="filter-tab"
            :class="{ 'filter-tab--active': selectedFilter === 'high' }"
            @click="selectFilter('high')"
          >
            <text class="filter-tab__text">高频</text>
            <view v-if="selectedFilter === 'high'" class="filter-tab__bar" />
          </view>
          <view
            v-for="realm in userStore.realms"
            :key="realm.realmCode"
            class="filter-tab"
            :class="{ 'filter-tab--active': selectedFilter === realm.realmCode }"
            @click="selectFilter(realm.realmCode)"
          >
            <text class="filter-tab__text">{{ realm.realmName }}</text>
            <view v-if="selectedFilter === realm.realmCode" class="filter-tab__bar" />
          </view>
        </view>
      </scroll-view>
    </view>

    <scroll-view scroll-y :show-scrollbar="false" class="wrong-scroll" @scrolltolower="loadMore">
      <view class="wrong-body">
        <!-- 未登录游客引导 -->
        <view v-if="pageReady && !userStore.isAuthenticated" class="guest-card">
          <view class="guest-card__icon">
            <app-icon name="notebook-pen" :size="30" color="primary" />
          </view>
          <text class="guest-card__title">登录后解锁专属错题本</text>
          <text class="guest-card__desc">
            每次闯关与解答的错题将自动收录，支持分境界筛选、错题重做与掌握消错。
          </text>
          <view class="guest-card__actions">
            <wd-button type="primary" size="medium" @click="goLogin">登录 / 注册</wd-button>
          </view>
        </view>

        <!-- 骨架屏 -->
        <template v-else-if="loading && list.length === 0">
          <view class="summary-card">
            <wd-skeleton
              animation="gradient"
              :row-col="[
                [{ width: '38%', height: '38px' }, { width: '48%', height: '32px', borderRadius: '6px' }],
                [{ width: '76%', height: '20px' }],
                [{ width: '45%', height: '14px' }],
              ]"
            />
          </view>
          <view v-for="n in 2" :key="n" class="wrong-card">
            <wd-skeleton
              animation="gradient"
              :row-col="[
                [{ width: '46%', height: '14px' }, { width: '16%', height: '18px' }],
                [{ width: '92%', height: '18px' }],
                [{ width: '74%', height: '18px' }],
                [{ width: '100%', height: '64px' }],
                [{ width: '28%', height: '14px' }, { width: '24%', height: '28px', borderRadius: '6px' }],
              ]"
            />
          </view>
        </template>

        <!-- 正式内容 -->
        <template v-else>
          <!-- 待巩固汇总卡 -->
          <view class="summary-card">
            <view class="summary-top">
              <view class="summary-count">
                <text class="summary-count__label">待巩固</text>
                <view class="summary-count__val-row">
                  <text class="summary-count__val">{{ displayedTotal }}</text>
                  <text class="summary-count__unit">题</text>
                </view>
              </view>

              <view class="summary-actions">
                <wd-button
                  type="info"
                  variant="plain"
                  size="small"
                  :disabled="total === 0"
                  @click="handleClearAll"
                >
                  清空
                </wd-button>
                <wd-button
                  type="primary"
                  size="small"
                  :disabled="displayedTotal === 0"
                  @click="handleStartRedo"
                >
                  错题重做
                </wd-button>
              </view>
            </view>

            <view v-if="realmSummaryTags.length > 0" class="summary-tags">
              <text
                v-for="tag in realmSummaryTags"
                :key="tag.realmCode"
                class="ggl-tag ggl-tag--neutral"
              >
                {{ tag.realmName }} {{ tag.count }} 题
              </text>
            </view>

            <text class="summary-hint">重做答对将自动移出错题本</text>
          </view>

          <!-- 空状态 -->
          <view v-if="displayedList.length === 0" class="empty-card">
            <app-icon name="check-circle" :size="32" color="success" />
            <text class="empty-card__title">
              {{ selectedFilter === "high" ? "暂无高频错题" : "当前暂无待巩固错题" }}
            </text>
            <text class="empty-card__desc">继续保持！闯关答错的题目会自动收录到这里</text>
          </view>

          <!-- 错题列表 -->
          <view v-else class="wrong-list">
            <view v-for="item in displayedList" :key="item.id" class="wrong-card">
              <view class="wrong-card__head">
                <text class="wrong-card__source">
                  {{ item.realmName }} · {{ item.chapterName }} · {{ item.gateName }}
                </text>
                <text
                  class="ggl-tag"
                  :class="item.wrongCount >= 2 ? 'ggl-tag--danger' : 'ggl-tag--warning'"
                >
                  错 {{ item.wrongCount }} 次
                </text>
              </view>

              <view class="wrong-card__stem">
                <math-text :text="item.stem" />
              </view>

              <view class="ref-box">
                <text class="ref-box__label">参考答案</text>
                <view class="ref-box__body">
                  <math-text :text="formatCorrectAnswer(item)" />
                </view>
                <view v-if="item.analysis" class="ref-box__analysis">
                  <math-text :text="item.analysis" />
                </view>
                <view v-if="item.lastAnswerImageUrl" class="ref-box__img-wrap">
                  <image
                    :src="item.lastAnswerImageUrl"
                    mode="aspectFit"
                    class="ref-box__img"
                    @click="previewWrongImg(item.lastAnswerImageUrl)"
                  />
                </view>
              </view>

              <view class="wrong-card__foot">
                <text class="wrong-card__time">{{ formatTime(item.lastWrongAt) }}</text>
                <wd-button
                  type="success"
                  variant="plain"
                  size="mini"
                  @click="handleMarkMastered(item.id)"
                >
                  标为已掌握
                </wd-button>
              </view>
            </view>

            <view v-if="loading" class="list-foot-status">
              <text class="list-foot-status__text">正在加载更多错题...</text>
            </view>
            <view v-else-if="list.length >= total && total > 0" class="list-foot-status">
              <text class="list-foot-status__text">已显示全部待巩固错题</text>
            </view>
          </view>
        </template>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { onShow } from "@dcloudio/uni-app";
import { useToast } from "@wot-ui/ui";
import { AppWrongAPI } from "@/api/guoguanla";
import { useUserStore } from "@/store";
import type { WrongQuestionItem } from "@/types/guoguanla";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "wrong",
  layout: "tabbar",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "错题本",
  },
});

const userStore = useUserStore();
const toast = useToast();

const selectedFilter = ref<string>("all");
const pageNum = ref(1);
const pageSize = 20;
const total = ref(0);
const list = ref<WrongQuestionItem[]>([]);
const loading = ref(false);
const pageReady = ref(false);

const LETTERS = ["A", "B", "C", "D", "E", "F"];

const displayedList = computed(() => {
  if (selectedFilter.value === "high") {
    return list.value.filter((item) => item.wrongCount >= 2);
  }
  return list.value;
});

const displayedTotal = computed(() => {
  if (selectedFilter.value === "high") {
    return displayedList.value.length;
  }
  return total.value;
});

const realmSummaryTags = computed(() => {
  const counts = new Map<string, { realmCode: string; realmName: string; count: number }>();
  for (const item of displayedList.value) {
    const code = item.realmCode || "other";
    const existing = counts.get(code);
    if (existing) {
      existing.count += 1;
    } else {
      counts.set(code, {
        realmCode: code,
        realmName: item.realmName || "综合",
        count: 1,
      });
    }
  }
  return Array.from(counts.values());
});

function formatCorrectAnswer(item: WrongQuestionItem): string {
  if (item.questionFormat === "ESSAY") {
    return item.referenceAnswer || "详见解析";
  }
  const idx = item.answerIndex ?? 0;
  const letter = LETTERS[idx] || String(idx + 1);
  const text = item.options?.[idx] ?? "";
  return text ? `${letter}. ${text}` : letter;
}

function previewWrongImg(url?: string): void {
  if (!url) return;
  uni.previewImage({ urls: [url] });
}

function formatTime(iso: string): string {
  if (!iso) return "";
  return iso.replace("T", " ").slice(0, 16);
}

async function fetchList(reset = true): Promise<void> {
  if (!userStore.isAuthenticated) return;
  if (reset) {
    pageNum.value = 1;
  }
  loading.value = true;
  const activeRealmCode =
    selectedFilter.value === "all" || selectedFilter.value === "high"
      ? undefined
      : selectedFilter.value;
  try {
    const res = await AppWrongAPI.getPage({
      realmCode: activeRealmCode,
      pageNum: pageNum.value,
      pageSize,
    });
    total.value = res.total;
    list.value = reset ? res.records : [...list.value, ...res.records];
    if (!activeRealmCode) {
      userStore.setWrongCount(res.total);
    }
  } catch (err) {
    toast.error(getErrorMessage(err, "获取错题失败"));
  } finally {
    loading.value = false;
  }
}

function selectFilter(key: string): void {
  const prevUsesApi = selectedFilter.value !== "all" && selectedFilter.value !== "high";
  const nextUsesApi = key !== "all" && key !== "high";
  selectedFilter.value = key;
  if (prevUsesApi || nextUsesApi || list.value.length === 0) {
    list.value = [];
    void fetchList(true);
  }
}

function loadMore(): void {
  if (loading.value || list.value.length >= total.value) return;
  pageNum.value += 1;
  void fetchList(false);
}

function handleStartRedo(): void {
  if (displayedTotal.value === 0) return;
  const activeRealmCode =
    selectedFilter.value === "all" || selectedFilter.value === "high"
      ? ""
      : selectedFilter.value;
  const query = activeRealmCode
    ? `mode=WRONG_REDO&realmCode=${encodeURIComponent(activeRealmCode)}`
    : "mode=WRONG_REDO";
  uni.navigateTo({ url: `/subPages/quiz/index?${query}` });
}

function handleMarkMastered(id: number): void {
  uni.showModal({
    title: "确认已掌握",
    content: "标记后将从当前错题本移除。",
    confirmColor: "#10B981",
    success: async (res) => {
      if (!res.confirm) return;
      try {
        await AppWrongAPI.markMastered(id);
        toast.success("已标为掌握");
        await fetchList(true);
        void userStore.refreshWrongCount();
      } catch (err) {
        toast.error(getErrorMessage(err, "操作失败"));
      }
    },
  });
}

function handleClearAll(): void {
  uni.showModal({
    title: "清空错题本",
    content: "确定清空所有待巩固错题记录吗？",
    confirmColor: "#EF4444",
    success: async (res) => {
      if (!res.confirm) return;
      try {
        await AppWrongAPI.clearAll();
        toast.success("已清空");
        await fetchList(true);
        userStore.setWrongCount(0);
      } catch (err) {
        toast.error(getErrorMessage(err, "清空失败"));
      }
    },
  });
}

function goLogin(): void {
  uni.navigateTo({
    url: `/subPages/login/index?redirect=${encodeURIComponent("/pages/wrong/index")}`,
  });
}

onShow(() => {
  pageReady.value = true;
  if (userStore.isAuthenticated) {
    if (list.value.length === 0) {
      loading.value = true;
    }
    void userStore.loadHomeSummary(true);
    void fetchList(true);
  }
});
</script>

<style lang="scss" scoped>
.wrong-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  background-color: var(--color-bg-page);
}

.filter-bar {
  flex-shrink: 0;
  background-color: var(--color-bg-card);
  border-bottom: 1px solid var(--color-border);
}

.filter-scroll {
  width: 100%;
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
  min-width: 108rpx;
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

.wrong-scroll {
  flex: 1;
  min-height: 0;
}

.wrong-body {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
  padding: 24rpx 24rpx 48rpx;
}

.guest-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 80rpx 40rpx;
  text-align: center;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.guest-card__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 112rpx;
  height: 112rpx;
  background-color: var(--color-primary-soft);
  border-radius: 9999px;
}

.guest-card__title {
  margin-top: 24rpx;
  font-size: 34rpx;
  font-weight: 700;
  color: var(--color-text);
}

.guest-card__desc {
  margin-top: 12rpx;
  font-size: 26rpx;
  line-height: 1.6;
  color: var(--color-text-muted);
}

.guest-card__actions {
  margin-top: 32rpx;
}

.summary-card {
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.summary-top {
  display: flex;
  gap: 20rpx;
  align-items: center;
  justify-content: space-between;
}

.summary-count {
  display: flex;
  flex-direction: column;
}

.summary-count__label {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.summary-count__val-row {
  display: flex;
  gap: 8rpx;
  align-items: baseline;
  margin-top: 4rpx;
}

.summary-count__val {
  font-size: 64rpx;
  font-weight: 700;
  line-height: 1.05;
  color: var(--color-text);
}

.summary-count__unit {
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.summary-actions {
  display: flex;
  gap: 16rpx;
  align-items: center;
}

.summary-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  margin-top: 24rpx;
}

.summary-hint {
  display: block;
  margin-top: 20rpx;
  font-size: 24rpx;
  color: var(--color-text-placeholder);
}

.empty-card {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
  align-items: center;
  padding: 88rpx 32rpx;
  text-align: center;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.empty-card__title {
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text);
}

.empty-card__desc {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.wrong-list {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.wrong-card {
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.wrong-card__head {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
}

.wrong-card__source {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 24rpx;
  color: var(--color-text-muted);
  white-space: nowrap;
}

.wrong-card__stem {
  margin-top: 20rpx;
  font-size: 30rpx;
  line-height: 1.6;
  color: var(--color-text);
}

.ref-box {
  padding: 24rpx;
  margin-top: 24rpx;
  background-color: var(--color-bg-page);
  border-radius: 12rpx;
}

.ref-box__label {
  display: block;
  margin-bottom: 8rpx;
  font-size: 24rpx;
  font-weight: 600;
  color: var(--color-success);
}

.ref-box__body {
  font-size: 26rpx;
  line-height: 1.55;
  color: var(--color-text-secondary);
}

.ref-box__analysis {
  margin-top: 10rpx;
  font-size: 26rpx;
  line-height: 1.55;
  color: var(--color-text-muted);
}

.ref-box__img-wrap {
  margin-top: 16rpx;
}

.ref-box__img {
  width: 200rpx;
  height: 150rpx;
  background-color: var(--color-bg-card);
  border-radius: 8rpx;
}

.wrong-card__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 22rpx;
  margin-top: 24rpx;
  border-top: 1px solid var(--color-border);
}

.wrong-card__time {
  font-size: 24rpx;
  color: var(--color-text-placeholder);
}

.list-foot-status {
  padding: 12rpx 0 0;
  text-align: center;
}

.list-foot-status__text {
  font-size: 24rpx;
  color: var(--color-text-placeholder);
}
</style>
