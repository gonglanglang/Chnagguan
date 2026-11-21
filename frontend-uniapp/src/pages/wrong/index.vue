<template>
  <view class="wrong-page">
    <app-navbar title="错题本" :show-back="false" :show-home="false" fixed placeholder />

    <view v-if="!userStore.isAuthenticated" class="empty-auth">
      <wd-empty icon="lock" tip="登录后自动收录答错题目，支持按境界集中重做" />
      <view class="empty-auth__action">
        <wd-button type="primary" block @click="goLogin">登录 / 注册</wd-button>
      </view>
    </view>

    <template v-else>
      <!-- 按修仙境界筛选 -->
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

      <view class="page-body">
        <view class="summary-bar">
          <view class="summary-bar__left">
            <text class="summary-bar__count">待巩固 {{ total }} 题</text>
            <text class="summary-bar__hint">重做答对将自动移出错题本</text>
          </view>
          <view class="summary-bar__actions">
            <wd-button
              size="small"
              variant="text"
              type="danger"
              :disabled="total === 0"
              @click="handleClearAll"
            >
              清空
            </wd-button>
            <wd-button
              size="small"
              type="primary"
              :disabled="total === 0"
              @click="handleStartRedo"
            >
              错题重做
            </wd-button>
          </view>
        </view>

        <view v-if="loading && list.length === 0" class="loading-box">
          <wd-loading />
        </view>

        <wd-empty
          v-else-if="list.length === 0"
          icon="no-content"
          tip="当前暂无待巩固错题"
        />

        <view v-else class="wrong-list">
          <view v-for="item in list" :key="item.id" class="wrong-card">
            <view class="wrong-card__header">
              <text class="wrong-card__source">
                <template v-if="item.realmName">{{ item.realmName }} · </template>
                {{ item.chapterName || "章节练习" }}
                <template v-if="item.gateName"> · {{ item.gateName }}</template>
              </text>
              <wd-tag type="warning" variant="light" size="small">
                错 {{ item.wrongCount }} 次
              </wd-tag>
            </view>

            <view class="wrong-card__stem">
              <math-text :text="item.stem" />
            </view>

            <view class="wrong-card__answer">
              <text class="wrong-card__answer-label">参考答案：</text>
              <view class="wrong-card__answer-val">
                <math-text :text="formatCorrectAnswer(item)" inline />
              </view>
            </view>

            <view v-if="item.lastAnswerImageUrl" class="wrong-card__img-row">
              <text class="wrong-card__img-label" @click="previewWrongImg(item.lastAnswerImageUrl)">
                查看上次手写画板作答图 ›
              </text>
            </view>

            <view v-if="item.analysis" class="wrong-card__analysis">
              解析：<math-text :text="item.analysis" inline />
            </view>

            <view class="wrong-card__footer">
              <text class="wrong-card__time">{{ formatTime(item.lastWrongAt) }}</text>
              <wd-button size="small" variant="plain" @click="handleMarkMastered(item.id)">
                标为已掌握
              </wd-button>
            </view>
          </view>

          <view v-if="list.length < total" class="load-more">
            <wd-button size="small" variant="plain" :loading="loading" @click="loadMore">
              加载更多 ({{ list.length }} / {{ total }})
            </wd-button>
          </view>
        </view>
      </view>
    </template>
  </view>
</template>

<script setup lang="ts">
import { onShow } from "@dcloudio/uni-app";
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

const selectedRealm = ref<string>("");
const pageNum = ref(1);
const pageSize = 15;
const total = ref(0);
const list = ref<WrongQuestionItem[]>([]);
const loading = ref(false);

const LETTERS = ["A", "B", "C", "D", "E", "F"];

function formatCorrectAnswer(item: WrongQuestionItem): string {
  if (item.questionFormat === "ESSAY") {
    return item.referenceAnswer || "详见下方解析";
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
  try {
    const res = await AppWrongAPI.getPage({
      realmCode: selectedRealm.value || undefined,
      pageNum: pageNum.value,
      pageSize,
    });
    total.value = res.total;
    list.value = reset ? res.records : [...list.value, ...res.records];
  } catch (err) {
    toast.error(getErrorMessage(err, "获取错题失败"));
  } finally {
    loading.value = false;
  }
}

function onRealmChange(payload: { name: string | number }): void {
  selectedRealm.value = String(payload.name);
  void fetchList(true);
}

function loadMore(): void {
  if (loading.value || list.value.length >= total.value) return;
  pageNum.value += 1;
  void fetchList(false);
}

function handleStartRedo(): void {
  if (total.value === 0) return;
  const query = selectedRealm.value
    ? `mode=WRONG_REDO&realmCode=${encodeURIComponent(selectedRealm.value)}`
    : "mode=WRONG_REDO";
  uni.navigateTo({ url: `/subPages/quiz/index?${query}` });
}

function handleMarkMastered(id: number): void {
  uni.showModal({
    title: "确认已掌握",
    content: "标记后将从当前错题本移除。",
    success: async (res) => {
      if (!res.confirm) return;
      try {
        await AppWrongAPI.markMastered(id);
        toast.success("已标为掌握");
        await fetchList(true);
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
    confirmColor: "#ef4444",
    success: async (res) => {
      if (!res.confirm) return;
      try {
        await AppWrongAPI.clearAll();
        toast.success("已清空");
        await fetchList(true);
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
  if (userStore.isAuthenticated) {
    void userStore.loadHomeSummary(true);
    void fetchList(true);
  }
});
</script>

<style lang="scss" scoped>
.wrong-page {
  min-height: 100vh;
  background: var(--color-bg-page);
}

.empty-auth {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 120rpx 48rpx 40rpx;
}

.empty-auth__action {
  width: 100%;
  max-width: 420rpx;
  margin-top: 24rpx;
}

.tabs-wrap {
  background: var(--color-bg-card);
  border-bottom: 1px solid var(--color-border);
}

.page-body {
  padding: 20rpx 24rpx 40rpx;
}

.summary-bar {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
  padding: 22rpx 24rpx;
  margin-bottom: 20rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 18rpx;
  box-shadow: var(--shadow-sm);
}

.summary-bar__left {
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.summary-bar__count {
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text);
}

.summary-bar__hint {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.summary-bar__actions {
  display: flex;
  gap: 12rpx;
  align-items: center;
}

.loading-box {
  display: flex;
  justify-content: center;
  padding: 80rpx 0;
}

.wrong-list {
  display: flex;
  flex-direction: column;
  gap: 18rpx;
}

.wrong-card {
  padding: 26rpx 24rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 18rpx;
  box-shadow: var(--shadow-sm);
}

.wrong-card__header {
  display: flex;
  gap: 12rpx;
  align-items: center;
  justify-content: space-between;
}

.wrong-card__source {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 24rpx;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.wrong-card__stem {
  display: block;
  margin-top: 16rpx;
  font-size: 30rpx;
  font-weight: 500;
  line-height: 1.55;
  color: var(--color-text);
}

.wrong-card__answer {
  padding: 14rpx 18rpx;
  margin-top: 16rpx;
  font-size: 26rpx;
  background: var(--color-primary-soft);
  border-radius: 12rpx;
}

.wrong-card__answer-label {
  color: var(--color-text-secondary);
}

.wrong-card__answer-val {
  font-weight: 600;
  color: var(--color-primary);
}

.wrong-card__img-row {
  margin-top: 10rpx;
}

.wrong-card__img-label {
  font-size: 24rpx;
  color: var(--color-primary);
}

.wrong-card__analysis {
  display: block;
  margin-top: 12rpx;
  font-size: 24rpx;
  line-height: 1.55;
  color: var(--color-text-secondary);
}

.wrong-card__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 16rpx;
  margin-top: 18rpx;
  border-top: 1px solid var(--color-border);
}

.wrong-card__time {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.load-more {
  display: flex;
  justify-content: center;
  padding: 16rpx 0;
}
</style>
