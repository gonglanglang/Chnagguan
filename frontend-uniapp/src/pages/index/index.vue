<template>
  <view class="home-page">
    <app-navbar
      :title="navTitle"
      :show-back="false"
      :show-home="false"
      fixed
      placeholder
    >
      <template v-if="selectedChapter" #left>
        <view class="nav-back-btn" @click="exitChapter">
          <wd-icon name="arrow-left" size="18" color="var(--color-text)" />
          <text class="nav-back-text">返回</text>
        </view>
      </template>
    </app-navbar>

    <view class="page-body">
      <template v-if="!selectedChapter">
        <!-- 顶部境界主卡（雅致翡翠渐变收口） -->
        <view class="realm-hero">
          <view class="realm-hero__top" @click="goRealmsOverview">
            <view class="realm-hero__left">
              <view class="realm-hero__icon">
                <wd-icon name="trophy" size="22" color="#ffffff" />
              </view>
              <view>
                <view class="realm-hero__title-row">
                  <text class="realm-hero__name">{{ currentRealm.realmName }}</text>
                  <text class="realm-hero__badge">{{ currentRealm.difficultyLabel }}</text>
                </view>
                <text class="realm-hero__sub">
                  本境通关 {{ currentRealm.passedGateCount }} / {{ currentRealm.gateCount || 0 }} 关 · 累计 {{ userStore.passedGateCount }} 关
                </text>
              </view>
            </view>
            <view class="realm-hero__link">
              <text>境界体系</text>
              <wd-icon name="right" size="13" color="rgba(255,255,255,0.85)" />
            </view>
          </view>

          <view class="realm-hero__bar-wrap">
            <view class="realm-hero__bar-track">
              <view
                class="realm-hero__bar-fill"
                :style="{ width: calcPercent(currentRealm.passedGateCount, currentRealm.gateCount) + '%' }"
              />
            </view>
            <text class="realm-hero__pct">
              {{ calcPercent(currentRealm.passedGateCount, currentRealm.gateCount) }}%
            </text>
          </view>

          <view class="realm-hero__footer">
            <template v-if="!userStore.isAuthenticated">
              <text class="realm-hero__tip">当前游客试玩练气境，登录后可同步进度并进阶</text>
              <view class="realm-hero__btn" @click="goLogin">去登录</view>
            </template>
            <template v-else-if="!userStore.userInfo?.nextRealmName">
              <text class="realm-hero__tip">已臻化神巅峰，点击下方可压制境界温习各阶题库</text>
            </template>
            <template v-else-if="currentRealm.examEligible">
              <text class="realm-hero__tip">
                已满考核条件，抽 {{ currentRealm.examQuestionCount }} 题过 {{ currentRealm.examPassScore }} 分即升「{{ userStore.userInfo.nextRealmName }}」
              </text>
              <view class="realm-hero__btn" @click="startAdvanceExam">进阶考核</view>
            </template>
            <template v-else>
              <text class="realm-hero__tip">
                再通 {{ currentRealm.examRemainingGates }} 关开启进阶考（{{ currentRealm.examQuestionCount }}题 · {{ currentRealm.examPassScore }}分及格）
              </text>
            </template>
          </view>
        </view>

        <!-- 六大境界 3x2 网格切换（高境可压制至低境，低境锁定） -->
        <view class="realm-box">
          <view class="realm-box__head">
            <text class="realm-box__title">修炼境界</text>
            <text class="realm-box__hint">高境可压制做低境题</text>
          </view>

          <view class="realm-grid">
            <view
              v-for="r in userStore.realms"
              :key="r.realmCode"
              class="realm-cell"
              :class="{
                'realm-cell--active': viewingRealmCode === r.realmCode,
                'realm-cell--locked': r.isHigher,
              }"
              @click="selectRealmTab(r)"
            >
              <view class="realm-cell__row">
                <text class="realm-cell__name">{{ r.realmName }}</text>
                <wd-icon
                  v-if="r.isHigher"
                  name="lock"
                  size="12"
                  color="var(--color-text-muted)"
                />
                <text v-else-if="r.isCurrent" class="realm-cell__mark">本境</text>
                <text v-else class="realm-cell__mark">可压</text>
              </view>
              <text class="realm-cell__sub">{{ shortDiff(r.difficultyLabel) }}</text>
            </view>
          </view>

          <view v-if="isSuppressedViewing" class="suppress-banner">
            <text class="suppress-banner__text">
              压制境界中：当前以「{{ currentRealm.realmName }}」修为练习「{{ viewingRealm?.realmName }}」题目
            </text>
            <text class="suppress-banner__back" @click="resetToCurrentRealm">回到本境</text>
          </view>
        </view>

        <view v-if="userStore.appNotice" class="notice-strip">
          <wd-icon name="notification" size="14" color="var(--color-primary)" />
          <text class="notice-strip__text">{{ userStore.appNotice }}</text>
        </view>

        <!-- 章节列表 -->
        <view class="section-header">
          <text class="section-title">{{ viewingRealm?.realmName }} · 章节修炼</text>
          <text class="section-sub">共 {{ chapters.length }} 章</text>
        </view>

        <view v-if="loadingChapters" class="loading-box">
          <wd-loading />
        </view>

        <wd-empty
          v-else-if="chapters.length === 0"
          icon="no-content"
          tip="该境界暂未配置章节"
        />

        <view v-else class="chapter-list">
          <view
            v-for="(chap, idx) in chapters"
            :key="chap.id"
            class="chapter-card"
            @click="enterChapter(chap)"
          >
            <view class="chapter-card__top">
              <view class="chapter-card__left">
                <view class="chapter-card__no">{{ String(idx + 1).padStart(2, "0") }}</view>
                <view class="chapter-card__info">
                  <text class="chapter-card__name">{{ chap.name }}</text>
                  <text v-if="chap.description" class="chapter-card__desc">{{ chap.description }}</text>
                </view>
              </view>
              <view class="chapter-card__right">
                <text
                  class="chapter-card__stat"
                  :class="{ 'chapter-card__stat--done': chap.passedCount >= chap.totalGates && chap.totalGates > 0 }"
                >
                  {{ chap.passedCount }}/{{ chap.totalGates }} 关
                </text>
                <wd-icon name="right" size="14" color="var(--color-text-muted)" />
              </view>
            </view>

            <view class="chapter-card__bar">
              <wd-progress
                :percentage="calcPercent(chap.passedCount, chap.totalGates)"
                hide-text
              />
            </view>
          </view>
        </view>
      </template>

      <!-- 章节关卡钻取视图 -->
      <template v-else>
        <view class="chapter-summary">
          <view class="chapter-summary__top">
            <text class="chapter-summary__title">{{ selectedChapter.name }}</text>
            <wd-tag v-if="isSuppressedViewing" type="warning" variant="light" size="small">
              压制境界
            </wd-tag>
            <text v-else class="chapter-summary__count">
              {{ passedGatesInChapter }} / {{ gates.length }} 关已通
            </text>
          </view>
          <text v-if="selectedChapter.description" class="chapter-summary__desc">
            {{ selectedChapter.description }}
          </text>
        </view>

        <view v-if="loadingGates" class="loading-box">
          <wd-loading />
        </view>

        <wd-empty
          v-else-if="gates.length === 0"
          icon="no-content"
          tip="该章节暂未设置关卡"
        />

        <view v-else class="gate-list">
          <view
            v-for="gate in gates"
            :key="gate.id"
            class="gate-card"
            :class="{ 'gate-card--locked': gate.locked || gate.empty }"
            @click="startGateQuiz(gate)"
          >
            <view class="gate-card__left">
              <view
                class="gate-card__index"
                :class="{
                  'gate-card__index--done': gate.passed,
                  'gate-card__index--locked': gate.locked || gate.empty,
                }"
              >
                <wd-icon v-if="gate.passed" name="check" size="18" color="#ffffff" />
                <text v-else>{{ String(gate.gateIndex + 1).padStart(2, "0") }}</text>
              </view>

              <view class="gate-card__info">
                <view class="gate-card__title-row">
                  <text class="gate-card__name">{{ gate.gateName }}</text>
                  <view class="gate-card__stars">
                    <wd-icon
                      v-for="n in gate.star || 1"
                      :key="n"
                      name="star-fill"
                      size="12"
                      color="#f59e0b"
                    />
                  </view>
                </view>
                <text class="gate-card__meta">
                  共 {{ gate.questionCount }} 题 · 答对 {{ gate.passCount }} 题过关
                </text>
              </view>
            </view>

            <view class="gate-card__right">
              <template v-if="gate.empty">
                <wd-tag variant="light" size="small">敬请期待</wd-tag>
              </template>
              <template v-else-if="gate.locked">
                <view class="gate-card__lock">
                  <wd-icon name="lock" size="15" color="var(--color-text-muted)" />
                  <text>未解锁</text>
                </view>
              </template>
              <template v-else-if="gate.passed">
                <wd-button size="small" variant="plain">再闯</wd-button>
              </template>
              <template v-else>
                <wd-button size="small" type="primary">开始</wd-button>
              </template>
            </view>
          </view>
        </view>
      </template>
    </view>
  </view>
</template>

<script setup lang="ts">
import { onShow } from "@dcloudio/uni-app";
import { AppBankAPI } from "@/api/guoguanla";
import { useUserStore } from "@/store";
import type { ChapterCard, GateCard, RealmItem } from "@/types/guoguanla";
import { ensureAuthenticated, getGuestPassedIds } from "@/utils/auth";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "home",
  layout: "tabbar",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "过关啦",
  },
});

const userStore = useUserStore();
const toast = useToast();

const viewingRealmCode = ref<string>("lianqi");
const manualSuppress = ref(false);
const selectedChapter = ref<ChapterCard | null>(null);
const chapters = ref<ChapterCard[]>([]);
const gates = ref<GateCard[]>([]);
const loadingChapters = ref(false);
const loadingGates = ref(false);

const currentRealm = computed(() => userStore.currentRealm);

const viewingRealm = computed(() => {
  return userStore.realms.find((r) => r.realmCode === viewingRealmCode.value) || currentRealm.value;
});

const isSuppressedViewing = computed(() => {
  return (viewingRealm.value?.realmOrder ?? 1) < (currentRealm.value?.realmOrder ?? 1);
});

const navTitle = computed(() => {
  if (selectedChapter.value) return selectedChapter.value.name;
  return "过关啦";
});

const passedGatesInChapter = computed(() => gates.value.filter((g) => g.passed).length);

function shortDiff(label: string): string {
  if (!label) return "";
  const idx = label.indexOf("·");
  return idx >= 0 ? label.slice(idx + 1).trim() : label;
}

function calcPercent(passed: number, total: number): number {
  if (!total || total <= 0) return 0;
  return Math.min(100, Math.round((passed / total) * 100));
}

function activeGuestIds(): number[] | undefined {
  return userStore.isAuthenticated ? undefined : getGuestPassedIds();
}

async function fetchChapters(realmCode: string): Promise<void> {
  loadingChapters.value = true;
  try {
    chapters.value = await AppBankAPI.getChaptersByRealm(realmCode, activeGuestIds());
  } catch (err) {
    toast.error(getErrorMessage(err, "加载章节失败"));
  } finally {
    loadingChapters.value = false;
  }
}

async function fetchGates(chapterId: number): Promise<void> {
  loadingGates.value = true;
  try {
    gates.value = await AppBankAPI.getGatesByChapter(chapterId, activeGuestIds());
  } catch (err) {
    toast.error(getErrorMessage(err, "加载关卡失败"));
  } finally {
    loadingGates.value = false;
  }
}

async function refreshPage(): Promise<void> {
  try {
    await userStore.loadHomeSummary(true);
  } catch {
    // Keep cached summary
  }
  const active = currentRealm.value.realmCode;
  const viewingOrder = viewingRealm.value?.realmOrder ?? 1;
  if (!manualSuppress.value || viewingOrder > currentRealm.value.realmOrder) {
    viewingRealmCode.value = active;
    manualSuppress.value = false;
  }
  if (selectedChapter.value) {
    await fetchGates(selectedChapter.value.id);
  } else {
    await fetchChapters(viewingRealmCode.value);
  }
}

function selectRealmTab(realm: RealmItem): void {
  if (realm.isHigher) {
    toast.info(`境界不足，需先进阶至「${realm.realmName}」后方可挑战`);
    return;
  }
  viewingRealmCode.value = realm.realmCode;
  manualSuppress.value = realm.realmOrder < currentRealm.value.realmOrder;
  void fetchChapters(realm.realmCode);
}

function resetToCurrentRealm(): void {
  manualSuppress.value = false;
  viewingRealmCode.value = currentRealm.value.realmCode;
  void fetchChapters(viewingRealmCode.value);
}

async function enterChapter(chapter: ChapterCard): Promise<void> {
  if (chapter.lockedByRealm) {
    toast.info("当前境界不足，请先完成当前境界进阶考核");
    return;
  }
  selectedChapter.value = chapter;
  await fetchGates(chapter.id);
}

function exitChapter(): void {
  selectedChapter.value = null;
  void fetchChapters(viewingRealmCode.value);
}

function startGateQuiz(gate: GateCard): void {
  if (gate.lockedByRealm) {
    toast.info("境界不足，请先通过当前境界进阶考核");
    return;
  }
  if (gate.empty) {
    toast.info("该关卡题目整理中，敬请期待");
    return;
  }
  if (gate.locked) {
    toast.info("请先通过上一关解锁当前关卡");
    return;
  }
  if (!userStore.isAuthenticated && !userStore.guestModeEnabled) {
    ensureAuthenticated();
    return;
  }
  uni.navigateTo({
    url: `/subPages/quiz/index?mode=GATE&gateId=${gate.id}`,
  });
}

function startAdvanceExam(): void {
  if (!ensureAuthenticated()) return;
  uni.navigateTo({
    url: "/subPages/quiz/index?mode=ADVANCE_EXAM",
  });
}

function goLogin(): void {
  uni.navigateTo({ url: "/subPages/login/index" });
}

function goRealmsOverview(): void {
  uni.navigateTo({ url: "/subPages/levels/index" });
}

onShow(() => {
  void refreshPage();
});
</script>

<style lang="scss" scoped>
.home-page {
  min-height: 100vh;
  background: var(--color-bg-page);
}

.page-body {
  padding: 20rpx 24rpx 48rpx;
}

.nav-back-btn {
  display: flex;
  gap: 6rpx;
  align-items: center;
  padding: 8rpx 4rpx;
}

.nav-back-text {
  font-size: 28rpx;
  color: var(--color-text);
}

.realm-hero {
  padding: 28rpx 26rpx 24rpx;
  color: #ffffff;
  background: linear-gradient(135deg, #16a34a 0%, #15803d 100%);
  border-radius: 22rpx;
  box-shadow: 0 10rpx 24rpx rgba(22, 163, 74, 0.22);
}

.realm-hero__top {
  display: flex;
  gap: 14rpx;
  align-items: flex-start;
  justify-content: space-between;
}

.realm-hero__left {
  display: flex;
  flex: 1;
  gap: 18rpx;
  align-items: center;
  min-width: 0;
}

.realm-hero__icon {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 76rpx;
  height: 76rpx;
  background: rgba(255, 255, 255, 0.18);
  border-radius: 20rpx;
}

.realm-hero__title-row {
  display: flex;
  gap: 12rpx;
  align-items: center;
}

.realm-hero__name {
  font-size: 38rpx;
  font-weight: 700;
  color: #ffffff;
}

.realm-hero__badge {
  padding: 4rpx 14rpx;
  font-size: 20rpx;
  font-weight: 500;
  color: #ffffff;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 999rpx;
}

.realm-hero__sub {
  display: block;
  margin-top: 6rpx;
  font-size: 23rpx;
  color: rgba(255, 255, 255, 0.88);
}

.realm-hero__link {
  display: flex;
  flex-shrink: 0;
  gap: 4rpx;
  align-items: center;
  margin-top: 6rpx;
  font-size: 23rpx;
  color: rgba(255, 255, 255, 0.9);
}

.realm-hero__bar-wrap {
  display: flex;
  gap: 16rpx;
  align-items: center;
  margin-top: 22rpx;
}

.realm-hero__bar-track {
  flex: 1;
  height: 12rpx;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.22);
  border-radius: 999rpx;
}

.realm-hero__bar-fill {
  height: 100%;
  background: #ffffff;
  border-radius: 999rpx;
  transition: width 0.25s ease;
}

.realm-hero__pct {
  font-size: 23rpx;
  font-weight: 600;
  color: #ffffff;
}

.realm-hero__footer {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
  padding-top: 18rpx;
  margin-top: 18rpx;
  border-top: 1px solid rgba(255, 255, 255, 0.18);
}

.realm-hero__tip {
  flex: 1;
  font-size: 22rpx;
  line-height: 1.45;
  color: rgba(255, 255, 255, 0.92);
}

.realm-hero__btn {
  flex-shrink: 0;
  padding: 10rpx 24rpx;
  font-size: 24rpx;
  font-weight: 600;
  color: #15803d;
  background: #ffffff;
  border-radius: 999rpx;
}

.realm-box {
  padding: 22rpx;
  margin-top: 20rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border-light);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.realm-box__head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 16rpx;
}

.realm-box__title {
  font-size: 27rpx;
  font-weight: 600;
  color: var(--color-text);
}

.realm-box__hint {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.realm-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12rpx;
}

.realm-cell {
  display: flex;
  flex-direction: column;
  gap: 4rpx;
  padding: 16rpx 14rpx;
  background: var(--color-bg-page);
  border: 2rpx solid transparent;
  border-radius: 16rpx;
  transition: all 0.15s ease;

  &--active {
    background: var(--color-primary-soft);
    border-color: var(--color-primary);

    .realm-cell__name,
    .realm-cell__mark,
    .realm-cell__sub {
      color: var(--color-primary);
    }
  }

  &--locked {
    opacity: 0.6;
  }
}

.realm-cell__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.realm-cell__name {
  font-size: 27rpx;
  font-weight: 600;
  color: var(--color-text);
}

.realm-cell__mark {
  font-size: 20rpx;
  color: var(--color-text-secondary);
}

.realm-cell__sub {
  font-size: 20rpx;
  color: var(--color-text-muted);
}

.suppress-banner {
  display: flex;
  gap: 12rpx;
  align-items: center;
  justify-content: space-between;
  padding: 14rpx 18rpx;
  margin-top: 16rpx;
  background: var(--color-warning-light);
  border-radius: 12rpx;
}

.suppress-banner__text {
  flex: 1;
  font-size: 22rpx;
  color: var(--color-warning);
}

.suppress-banner__back {
  flex-shrink: 0;
  font-size: 22rpx;
  font-weight: 600;
  color: var(--color-primary);
}

.notice-strip {
  display: flex;
  gap: 12rpx;
  align-items: center;
  padding: 16rpx 20rpx;
  margin-top: 18rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border-light);
  border-radius: 16rpx;
}

.notice-strip__text {
  flex: 1;
  font-size: 23rpx;
  color: var(--color-text-secondary);
}

.section-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  padding: 0 4rpx;
  margin: 26rpx 0 16rpx;
}

.section-title {
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text);
}

.section-sub {
  font-size: 23rpx;
  color: var(--color-text-muted);
}

.loading-box {
  display: flex;
  justify-content: center;
  padding: 80rpx 0;
}

.chapter-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.chapter-card {
  padding: 24rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border-light);
  border-radius: 18rpx;
  box-shadow: var(--shadow-sm);
}

.chapter-card:active {
  background: var(--color-bg-active);
}

.chapter-card__top {
  display: flex;
  gap: 14rpx;
  align-items: center;
  justify-content: space-between;
}

.chapter-card__left {
  display: flex;
  flex: 1;
  gap: 16rpx;
  align-items: center;
  min-width: 0;
}

.chapter-card__no {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 56rpx;
  height: 56rpx;
  font-size: 24rpx;
  font-weight: 600;
  color: var(--color-primary);
  background: var(--color-primary-soft);
  border-radius: 14rpx;
}

.chapter-card__info {
  flex: 1;
  min-width: 0;
}

.chapter-card__name {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 29rpx;
  font-weight: 600;
  color: var(--color-text);
  white-space: nowrap;
}

.chapter-card__desc {
  display: block;
  margin-top: 4rpx;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 23rpx;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.chapter-card__right {
  display: flex;
  flex-shrink: 0;
  gap: 6rpx;
  align-items: center;
}

.chapter-card__stat {
  font-size: 23rpx;
  font-weight: 500;
  color: var(--color-text-secondary);

  &--done {
    font-weight: 600;
    color: var(--color-primary);
  }
}

.chapter-card__bar {
  margin-top: 16rpx;
}

.chapter-summary {
  padding: 24rpx;
  margin-bottom: 20rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border-light);
  border-radius: 18rpx;
}

.chapter-summary__top {
  display: flex;
  gap: 12rpx;
  align-items: center;
  justify-content: space-between;
}

.chapter-summary__title {
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text);
}

.chapter-summary__count {
  font-size: 24rpx;
  font-weight: 500;
  color: var(--color-primary);
}

.chapter-summary__desc {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.gate-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.gate-card {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
  padding: 24rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border-light);
  border-radius: 18rpx;
  box-shadow: var(--shadow-sm);

  &--locked {
    opacity: 0.7;
  }
}

.gate-card__left {
  display: flex;
  flex: 1;
  gap: 18rpx;
  align-items: center;
  min-width: 0;
}

.gate-card__index {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 66rpx;
  height: 66rpx;
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-primary);
  background: var(--color-primary-soft);
  border-radius: 16rpx;

  &--done {
    color: #ffffff;
    background: var(--color-primary);
  }

  &--locked {
    color: var(--color-text-muted);
    background: var(--color-bg-page);
  }
}

.gate-card__info {
  flex: 1;
  min-width: 0;
}

.gate-card__title-row {
  display: flex;
  gap: 10rpx;
  align-items: center;
}

.gate-card__name {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text);
  white-space: nowrap;
}

.gate-card__stars {
  display: flex;
  gap: 2rpx;
  align-items: center;
}

.gate-card__meta {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.gate-card__right {
  flex-shrink: 0;
}

.gate-card__lock {
  display: flex;
  gap: 6rpx;
  align-items: center;
  font-size: 24rpx;
  color: var(--color-text-muted);
}
</style>
