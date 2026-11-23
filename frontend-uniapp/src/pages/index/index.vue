<template>
  <view class="home-page">
    <app-navbar
      :title="navTitle"
      :show-back="false"
      :show-home="false"
      :fixed="false"
      :placeholder="false"
    >
      <template v-if="selectedChapter" #left>
        <view class="nav-back-btn" @click="exitChapter">
          <app-icon name="back" size="18" color="text" />
          <text class="nav-back-text">返回</text>
        </view>
      </template>
    </app-navbar>

    <scroll-view
      scroll-y
      :scroll-top="innerScrollTop"
      :show-scrollbar="false"
      class="home-scroll"
      @scroll="onBodyScroll"
    >
      <view class="page-body">
      <template v-if="!selectedChapter">
        <!-- 六大境界 3x2 网格切换（全境界开放自由学习，高境可压制低境，低境可跨级研习） -->
        <view v-if="showSummarySkeleton" class="realm-box">
          <view class="realm-box__head">
            <wd-skeleton animation="gradient" :row-col="[[{ width: '30%', height: '16px' }, { width: '22%', height: '14px' }]]" />
          </view>
          <view class="realm-grid">
            <view v-for="n in 6" :key="n" class="realm-cell">
              <wd-skeleton
                animation="gradient"
                :row-col="[
                  { width: '62%', height: '14px' },
                  { width: '78%', height: '11px' },
                ]"
              />
            </view>
          </view>
        </view>

        <view v-else class="realm-box">
          <view class="realm-box__head">
            <text class="realm-box__title">修炼境界</text>
            <view class="realm-box__actions">
              <text
                v-if="userStore.isAuthenticated && currentRealm.examEligible && userStore.userInfo?.nextRealmName"
                class="realm-box__exam"
                @click="startAdvanceExam"
              >
                可进阶考核 ›
              </text>
              <text v-else class="realm-box__hint" @click="goRealmsOverview">
                境界体系 ›
              </text>
            </view>
          </view>

          <view class="realm-grid">
            <view
              v-for="r in userStore.realms"
              :key="r.realmCode"
              class="realm-cell"
              :class="{
                'realm-cell--active': viewingRealmCode === r.realmCode,
              }"
              @click="selectRealmTab(r)"
            >
              <view class="realm-cell__row">
                <text class="realm-cell__name">{{ r.realmName }}</text>
                <text v-if="r.isCurrent" class="realm-cell__mark">本境</text>
                <text v-else-if="r.isLower" class="realm-cell__mark">可压</text>
                <text v-else class="realm-cell__mark">高境</text>
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

          <view v-else-if="isHigherViewing" class="cross-banner">
            <text class="cross-banner__text">
              跨级研习中：当前以「{{ currentRealm.realmName }}」修为挑战「{{ viewingRealm?.realmName }}」内容
            </text>
            <text class="cross-banner__back" @click="resetToCurrentRealm">回到本境</text>
          </view>
        </view>

        <view v-if="showSummarySkeleton" class="notice-strip">
          <wd-skeleton animation="gradient" :row-col="[{ width: '100%', height: '14px' }]" />
        </view>
        <view v-else-if="userStore.appNotice" class="notice-strip">
          <app-icon name="notice" size="15" color="primary" />
          <text class="notice-strip__text">{{ userStore.appNotice }}</text>
        </view>

        <!-- 章节列表 -->
        <view class="section-header">
          <text class="section-title">{{ viewingRealm?.realmName }} · 章节修炼</text>
          <text class="section-sub">共 {{ chapters.length }} 章</text>
        </view>

        <view v-if="showChapterSkeleton" class="chapter-list">
          <view v-for="n in 4" :key="n" class="chapter-card">
            <wd-skeleton
              animation="gradient"
              :row-col="[
                [
                  { type: 'rect', width: '28px', height: '28px', borderRadius: '7px', marginRight: '10px' },
                  { width: '58%', height: '16px' },
                  { width: '16%', height: '13px' },
                ],
                { width: '100%', height: '6px', borderRadius: '999px' },
              ]"
            />
          </view>
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
                <app-icon name="right" size="14" color="muted" />
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

        <view v-if="loadingGates && gates.length === 0" class="gate-list">
          <view v-for="n in 4" :key="n" class="gate-card">
            <wd-skeleton
              animation="gradient"
              :row-col="[
                [
                  { type: 'rect', width: '33px', height: '33px', borderRadius: '8px', marginRight: '10px' },
                  { width: '50%', height: '16px' },
                  { width: '56px', height: '28px', borderRadius: '8px' },
                ],
                { width: '48%', height: '12px' },
              ]"
            />
          </view>
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
                <app-icon v-if="gate.passed" name="check" size="18" color="#ffffff" />
                <text v-else>{{ String(gate.gateIndex + 1).padStart(2, "0") }}</text>
              </view>

              <view class="gate-card__info">
                <view class="gate-card__title-row">
                  <text class="gate-card__name">{{ gate.gateName }}</text>
                  <view class="gate-card__stars">
                    <app-icon
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
                  <app-icon name="lock" size="15" color="muted" />
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
    </scroll-view>
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
const manualRealmSelected = ref(false);
const lastKnownUserRealmCode = ref<string>("lianqi");
const lastLoadedChaptersRealm = ref<string>("");
const selectedChapter = ref<ChapterCard | null>(null);
const chapters = ref<ChapterCard[]>([]);
const gates = ref<GateCard[]>([]);
const loadingSummary = ref(!userStore.homeSummary);
const loadingChapters = ref(false);
const loadingGates = ref(false);
const currentScrollY = ref(0);
const innerScrollTop = ref(0);

function onBodyScroll(e: { detail?: { scrollTop?: number } }): void {
  currentScrollY.value = e?.detail?.scrollTop ?? 0;
}

function resetScroll(): void {
  innerScrollTop.value = currentScrollY.value;
  void nextTick(() => {
    innerScrollTop.value = 0;
    currentScrollY.value = 0;
  });
}

const currentRealm = computed(() => userStore.currentRealm);

const viewingRealm = computed(() => {
  return userStore.realms.find((r) => r.realmCode === viewingRealmCode.value) || currentRealm.value;
});

const isSuppressedViewing = computed(() => {
  return (viewingRealm.value?.realmOrder ?? 1) < (currentRealm.value?.realmOrder ?? 1);
});

const isHigherViewing = computed(() => {
  return (viewingRealm.value?.realmOrder ?? 1) > (currentRealm.value?.realmOrder ?? 1);
});

const showSummarySkeleton = computed(() => loadingSummary.value && !userStore.homeSummary);

const showChapterSkeleton = computed(
  () =>
    loadingChapters.value &&
    (chapters.value.length === 0 || lastLoadedChaptersRealm.value !== viewingRealmCode.value),
);

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
    const res = await AppBankAPI.getChaptersByRealm(realmCode, activeGuestIds());
    chapters.value = res;
    lastLoadedChaptersRealm.value = realmCode;
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
  if (!userStore.homeSummary) {
    loadingSummary.value = true;
  }
  try {
    await userStore.loadHomeSummary(true);
  } catch {
    // Keep cached summary
  } finally {
    loadingSummary.value = false;
  }
  const active = currentRealm.value.realmCode;
  if (!manualRealmSelected.value || lastKnownUserRealmCode.value !== active) {
    viewingRealmCode.value = active;
    manualRealmSelected.value = false;
  }
  lastKnownUserRealmCode.value = active;
  if (selectedChapter.value) {
    await fetchGates(selectedChapter.value.id);
  } else {
    await fetchChapters(viewingRealmCode.value);
  }
}

function selectRealmTab(realm: RealmItem): void {
  viewingRealmCode.value = realm.realmCode;
  manualRealmSelected.value = realm.realmCode !== currentRealm.value.realmCode;
  void fetchChapters(realm.realmCode);
}

function resetToCurrentRealm(): void {
  manualRealmSelected.value = false;
  viewingRealmCode.value = currentRealm.value.realmCode;
  void fetchChapters(viewingRealmCode.value);
}

async function enterChapter(chapter: ChapterCard): Promise<void> {
  selectedChapter.value = chapter;
  gates.value = [];
  resetScroll();
  await fetchGates(chapter.id);
}

function exitChapter(): void {
  selectedChapter.value = null;
  resetScroll();
  void fetchChapters(viewingRealmCode.value);
}

function startGateQuiz(gate: GateCard): void {
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

function goRealmsOverview(): void {
  uni.navigateTo({ url: "/subPages/levels/index" });
}

onShow(() => {
  void refreshPage();
});
</script>

<style lang="scss" scoped>
.home-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  background: var(--color-bg-page);
}

.home-scroll {
  flex: 1;
  min-height: 0;
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

.realm-box {
  padding: 22rpx;
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

.realm-box__actions {
  display: flex;
  align-items: center;
}

.realm-box__exam {
  font-size: 23rpx;
  font-weight: 600;
  color: var(--color-primary);
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

.cross-banner {
  display: flex;
  gap: 12rpx;
  align-items: center;
  justify-content: space-between;
  padding: 14rpx 18rpx;
  margin-top: 16rpx;
  background: var(--color-primary-soft);
  border-radius: 12rpx;
}

.cross-banner__text {
  flex: 1;
  font-size: 22rpx;
  color: var(--color-primary);
}

.cross-banner__back {
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
