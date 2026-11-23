<template>
  <view class="home-page">
    <app-navbar title="过关啦" :show-back="false" :fixed="false" />

    <scroll-view
      scroll-y
      :scroll-top="innerScrollTop"
      :show-scrollbar="false"
      class="home-scroll"
      @scroll="onBodyScroll"
    >
      <view class="home-body">
        <template v-if="showSummarySkeleton">
          <view class="greeting-row">
            <view class="greeting-main">
              <wd-skeleton
                animation="gradient"
                :row-col="[[{ width: '58%', height: '24px' }], [{ width: '74%', height: '14px' }]]"
              />
            </view>
            <wd-skeleton animation="gradient" :row-col="[[{ width: '76px', height: '32px', borderRadius: '6px' }]]" />
          </view>

          <view class="hero-card">
            <wd-skeleton
              animation="gradient"
              :row-col="[
                [{ width: '32%', height: '16px' }, { width: '18%', height: '18px' }],
                [{ width: '62%', height: '22px' }],
                [{ width: '48%', height: '14px' }],
                [{ width: '100%', height: '6px' }],
                [{ width: '24%', height: '32px', borderRadius: '6px' }, { width: '24%', height: '32px', borderRadius: '6px' }],
              ]"
            />
          </view>

          <view class="notice-skeleton">
            <wd-skeleton animation="gradient" :row-col="[[{ width: '100%', height: '34px' }]]" />
          </view>

          <text class="ggl-section-label">章节闯关</text>
          <view class="catalog-card">
            <view v-for="n in 4" :key="n" class="chapter-skeleton-row">
              <wd-skeleton
                animation="gradient"
                :row-col="[[{ width: '36px', height: '36px' }, { width: '52%', height: '16px' }, { width: '16%', height: '18px' }]]"
              />
            </view>
          </view>
        </template>

        <template v-else>
          <!-- 顶部问候 + 学习体系弹窗入口 -->
          <view class="greeting-row">
            <view class="greeting-main">
              <text class="greeting-title">{{ greetingText }}</text>
              <view class="greeting-sub">
                <text class="greeting-sub__muted">当前境界</text>
                <text class="greeting-sub__realm">{{ currentRealm.realmName }}</text>
                <text class="greeting-sub__muted">
                  · 已过 {{ totalPassedGates }}/{{ totalRealmGates }} 关
                </text>
              </view>
            </view>
            <wd-button type="info" variant="plain" size="small" @click="openSystemPopup">
              学习体系
            </wd-button>
          </view>

          <!-- 继续修炼 Hero 主卡片 -->
          <view v-if="heroChapter" class="hero-card">
            <view class="hero-card__head">
              <text class="hero-card__eyebrow">继续修炼</text>
              <text class="ggl-tag ggl-tag--primary">第 {{ heroChapterSeq }} 章</text>
            </view>

            <text class="hero-card__title">{{ heroChapter.name }}</text>
            <text class="hero-card__sub">{{ heroSubtitle }}</text>

            <view class="hero-progress">
              <view class="hero-progress__track">
                <view class="hero-progress__fill" :style="{ width: heroProgressPercent + '%' }" />
              </view>
              <text class="hero-progress__pct">{{ heroProgressPercent }}%</text>
            </view>

            <view class="hero-card__footer">
              <wd-button
                type="info"
                variant="plain"
                size="small"
                @click="openChapterMap(heroChapter, heroChapterSeq)"
              >
                查看地图
              </wd-button>
              <wd-button type="primary" size="small" @click="handleContinuePractice">
                继续闯关
              </wd-button>
            </view>
          </view>

          <!-- 公告条 -->
          <view v-if="noticeText" class="notice-banner" @click="handleNoticeTap">
            <app-icon name="notice" :size="15" color="warning" />
            <text class="notice-banner__text">{{ noticeText }}</text>
          </view>

          <!-- 章节闯关标题 -->
          <text class="ggl-section-label">章节闯关</text>

          <!-- 粘性境界 Tabs + 章节列表一体白卡 -->
          <view class="catalog-card">
            <scroll-view scroll-x :show-scrollbar="false" class="realm-tabs-scroll">
              <view class="realm-tabs">
                <view
                  v-for="realm in userStore.realms"
                  :key="realm.realmCode"
                  class="realm-tab"
                  :class="{ 'realm-tab--active': viewingRealmCode === realm.realmCode }"
                  @click="selectRealmTab(realm)"
                >
                  <text class="realm-tab__name">{{ realm.realmName }}</text>
                  <view v-if="viewingRealmCode === realm.realmCode" class="realm-tab__bar" />
                </view>
              </view>
            </scroll-view>

            <view v-if="isSuppressedViewing || currentRealm.examEligible" class="realm-hint-strip">
              <text class="realm-hint-strip__text">
                {{
                  isSuppressedViewing
                    ? `高境压制 · 正在重温${viewingRealm.realmName}内容，全章节自由开放`
                    : `${currentRealm.realmName}已达标，可点击下方按钮参加境界进阶考核`
                }}
              </text>
              <text
                v-if="currentRealm.examEligible && !isSuppressedViewing"
                class="realm-hint-strip__action"
                @click="startAdvanceExam"
              >
                去考核
              </text>
            </view>

            <view v-if="showChapterSkeleton" class="chapter-skeleton-list">
              <view v-for="n in 4" :key="n" class="chapter-skeleton-row">
                <wd-skeleton
                  animation="gradient"
                  :row-col="[[{ width: '36px', height: '36px' }, { width: '54%', height: '16px' }, { width: '16%', height: '18px' }]]"
                />
              </view>
            </view>

            <view v-else-if="chapters.length === 0" class="catalog-empty">
              <app-icon name="empty" :size="28" color="muted" />
              <text class="catalog-empty__text">该境界暂未配置章节</text>
            </view>

            <view v-else class="chapter-list">
              <view
                v-for="(chapter, idx) in chapters"
                :key="chapter.id"
                class="chapter-row"
                @click="openChapterMap(chapter, idx + 1)"
              >
                <view class="chapter-row__inner">
                  <view class="chapter-badge" :class="chapterBadgeClass(chapter)">
                    <text class="chapter-badge__num">{{ formatIndex(idx + 1) }}</text>
                  </view>

                  <view class="chapter-main">
                    <text class="chapter-main__title">{{ chapter.name }}</text>
                    <text class="chapter-main__desc">
                      {{ chapter.description || "四关精讲精练，循序夯实基础" }}
                    </text>
                  </view>

                  <view class="chapter-right">
                    <text class="ggl-tag" :class="chapterTagClass(chapter)">
                      {{ chapterStatusText(chapter) }}
                    </text>
                    <text class="chapter-right__count">
                      {{ chapter.passedCount }}/{{ chapter.totalGates }}
                    </text>
                    <app-icon name="right" :size="14" color="#BFBFBF" />
                  </view>
                </view>
                <view v-if="idx < chapters.length - 1" class="chapter-row__divider" />
              </view>
            </view>
          </view>

          <view class="bottom-exam-tip" @click="openSystemPopup">
            <text class="bottom-exam-tip__text">
              {{
                currentRealm.examEligible
                  ? `${currentRealm.realmName}已满足进阶条件，点击查看学习体系并考核晋升`
                  : `全境界题库已自由开放 · 本境再过 ${Math.max(0, currentRealm.examRemainingGates)} 关可解锁进阶考核`
              }}
            </text>
          </view>
        </template>
      </view>
    </scroll-view>

    <!-- 学习体系底部抽屉弹窗 -->
    <wd-popup
      v-model="showSystemPopup"
      position="bottom"
      :z-index="900"
      safe-area-inset-bottom
      custom-style="border-top-left-radius: 32rpx; border-top-right-radius: 32rpx; overflow: hidden;"
    >
      <view class="system-sheet">
        <view class="system-sheet__header">
          <view class="system-sheet__close-placeholder" />
          <text class="system-sheet__title">学习体系</text>
          <view class="system-sheet__close" @click="showSystemPopup = false">
            <app-icon name="close" :size="18" color="muted" />
          </view>
        </view>

        <text class="system-sheet__desc">
          共 {{ userStore.realms.length }} 大境界，全阶段课程与章节题库自由开放学习；完成本境指定关卡后可发起进阶考核晋升。
        </text>

        <scroll-view scroll-y :show-scrollbar="false" class="system-sheet__scroll">
          <view class="system-list-card">
            <view
              v-for="(realm, rIdx) in userStore.realms"
              :key="realm.realmCode"
              class="system-row"
              @click="handleChooseRealmFromPopup(realm)"
            >
              <view class="system-row__content">
                <view class="system-row__main">
                  <text class="system-row__title">
                    {{ realm.realmName }} · {{ shortDiff(realm.difficultyLabel) }}
                  </text>
                  <text class="system-row__sub">
                    {{ realm.description || `共 ${realm.chapterCount} 章 ${realm.gateCount} 关` }}
                  </text>
                </view>
                <text class="ggl-tag" :class="realmPopupTagClass(realm)">
                  {{ realmPopupTagText(realm) }}
                </text>
              </view>
              <view v-if="rIdx < userStore.realms.length - 1" class="system-row__divider" />
            </view>
          </view>
        </scroll-view>

        <view class="system-sheet__footer">
          <wd-button
            v-if="currentRealm.examEligible"
            type="primary"
            size="large"
            block
            @click="handleExamFromPopup"
          >
            参加{{ currentRealm.realmName }}进阶考核
          </wd-button>
          <wd-button
            v-else
            type="info"
            variant="plain"
            size="large"
            block
            @click="goRealmsOverview"
          >
            查看境界详情与进阶规则
          </wd-button>
        </view>
      </view>
    </wd-popup>
  </view>
</template>

<script setup lang="ts">
import { computed, nextTick, ref } from "vue";
import { onShow } from "@dcloudio/uni-app";
import { useToast } from "@wot-ui/ui";
import { AppBankAPI } from "@/api/guoguanla";
import { useUserStore } from "@/store";
import type { ChapterCard, RealmItem } from "@/types/guoguanla";
import { ensureAuthenticated, getGuestPassedIds } from "@/utils/auth";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "home",
  layout: "tabbar",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "闯关",
  },
});

const userStore = useUserStore();
const toast = useToast();

const viewingRealmCode = ref<string>("lianqi");
const manualRealmSelected = ref(false);
const lastKnownUserRealmCode = ref<string>("lianqi");
const lastLoadedChaptersRealm = ref<string>("");
const chapters = ref<ChapterCard[]>([]);
const heroChapters = ref<ChapterCard[]>([]);
const loadingSummary = ref(!userStore.homeSummary);
const loadingChapters = ref(false);
const showSystemPopup = ref(false);
const currentScrollY = ref(0);
const innerScrollTop = ref(0);

function onBodyScroll(e: { detail?: { scrollTop?: number } }): void {
  currentScrollY.value = e?.detail?.scrollTop ?? 0;
}

const currentRealm = computed(() => userStore.currentRealm);

const viewingRealm = computed(() => {
  return userStore.realms.find((r) => r.realmCode === viewingRealmCode.value) || currentRealm.value;
});

const isSuppressedViewing = computed(() => {
  return (viewingRealm.value?.realmOrder ?? 1) < (currentRealm.value?.realmOrder ?? 1);
});

const showSummarySkeleton = computed(() => loadingSummary.value && !userStore.homeSummary);

const showChapterSkeleton = computed(
  () =>
    loadingChapters.value &&
    (chapters.value.length === 0 || lastLoadedChaptersRealm.value !== viewingRealmCode.value),
);

const greetingText = computed(() => {
  const hour = new Date().getHours();
  const period = hour < 12 ? "早上好" : hour < 18 ? "下午好" : "晚上好";
  const name = userStore.userInfo?.nickname || (userStore.isAuthenticated ? "道友" : "同学");
  return `${period}，${name}`;
});

const totalPassedGates = computed(() => {
  if (userStore.isAuthenticated && userStore.userInfo) {
    return userStore.userInfo.passedGateCount ?? currentRealm.value?.passedGateCount ?? 0;
  }
  return userStore.realms.reduce((acc, r) => acc + (r.passedGateCount || 0), 0);
});

const totalRealmGates = computed(() => {
  const total = userStore.realms.reduce((acc, r) => acc + (r.gateCount || 0), 0);
  return total > 0 ? total : currentRealm.value?.gateCount || 204;
});

const activeHeroSource = computed(() => {
  if (heroChapters.value.length > 0) return heroChapters.value;
  return chapters.value;
});

const heroChapter = computed<ChapterCard | null>(() => {
  const list = activeHeroSource.value;
  if (list.length === 0) return null;
  const inProgress = list.find((c) => c.passedCount > 0 && c.passedCount < c.totalGates);
  if (inProgress) return inProgress;
  const unstarted = list.find((c) => c.passedCount < c.totalGates);
  return unstarted || list[0];
});

const heroChapterSeq = computed(() => {
  if (!heroChapter.value) return 1;
  const idx = activeHeroSource.value.findIndex((c) => c.id === heroChapter.value?.id);
  return idx >= 0 ? idx + 1 : 1;
});

const heroProgressPercent = computed(() => {
  if (!heroChapter.value || heroChapter.value.totalGates <= 0) return 0;
  return Math.min(
    100,
    Math.round((heroChapter.value.passedCount / heroChapter.value.totalGates) * 100),
  );
});

const heroSubtitle = computed(() => {
  const ch = heroChapter.value;
  if (!ch) return "";
  if (ch.passedCount >= ch.totalGates && ch.totalGates > 0) {
    return `${ch.realmName} · 本章已全部通关`;
  }
  if (ch.passedCount > 0) {
    return `上次停在第 ${ch.passedCount + 1} 关 · ${ch.description || ch.realmName}`;
  }
  return ch.description || `${ch.realmName} · 共 ${ch.totalGates} 关等你挑战`;
});

const noticeText = computed(() => {
  const msg = userStore.appNotice?.trim();
  if (msg) return msg;
  if (currentRealm.value.examEligible) {
    return `恭喜！你在${currentRealm.value.realmName}已达晋升条件，点击立即参加进阶考核`;
  }
  return `全境界 51 章题库开放自由练习，完成本境指定关卡可参加进阶考核`;
});

function formatIndex(num: number): string {
  return String(num).padStart(2, "0");
}

function shortDiff(label: string): string {
  if (!label) return "";
  const idx = label.indexOf("·");
  return idx >= 0 ? label.slice(idx + 1).trim() : label;
}

function activeGuestIds(): number[] | undefined {
  return userStore.isAuthenticated ? undefined : getGuestPassedIds();
}

function chapterBadgeClass(chapter: ChapterCard): string {
  if (chapter.totalGates > 0 && chapter.passedCount >= chapter.totalGates) {
    return "chapter-badge--done";
  }
  if (chapter.passedCount > 0) {
    return "chapter-badge--active";
  }
  return "chapter-badge--idle";
}

function chapterTagClass(chapter: ChapterCard): string {
  if (chapter.totalGates > 0 && chapter.passedCount >= chapter.totalGates) {
    return "ggl-tag--success";
  }
  if (chapter.passedCount > 0) {
    return "ggl-tag--primary";
  }
  return "ggl-tag--neutral";
}

function chapterStatusText(chapter: ChapterCard): string {
  if (chapter.totalGates > 0 && chapter.passedCount >= chapter.totalGates) {
    return "已通关";
  }
  if (chapter.passedCount > 0) {
    return "进行中";
  }
  return "未开始";
}

function realmPopupTagText(realm: RealmItem): string {
  if (realm.isCurrent) return "修炼中";
  if (realm.isLower) return "已通过";
  return "自由开放";
}

function realmPopupTagClass(realm: RealmItem): string {
  if (realm.isCurrent) return "ggl-tag--primary";
  if (realm.isLower) return "ggl-tag--success";
  return "ggl-tag--neutral";
}

async function fetchChapters(realmCode: string): Promise<void> {
  loadingChapters.value = true;
  try {
    const res = await AppBankAPI.getChaptersByRealm(realmCode, activeGuestIds());
    chapters.value = res;
    lastLoadedChaptersRealm.value = realmCode;
    if (realmCode === currentRealm.value.realmCode) {
      heroChapters.value = res;
    }
  } catch (err) {
    toast.error(getErrorMessage(err, "加载章节失败"));
  } finally {
    loadingChapters.value = false;
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

  await fetchChapters(viewingRealmCode.value);
  if (viewingRealmCode.value !== active) {
    try {
      heroChapters.value = await AppBankAPI.getChaptersByRealm(active, activeGuestIds());
    } catch {
      // Ignore secondary hero fetch failure
    }
  }
}

function selectRealmTab(realm: RealmItem): void {
  viewingRealmCode.value = realm.realmCode;
  manualRealmSelected.value = realm.realmCode !== currentRealm.value.realmCode;
  void fetchChapters(realm.realmCode);
}

function openChapterMap(chapter: ChapterCard, seq: number): void {
  const name = encodeURIComponent(chapter.name || "");
  const desc = encodeURIComponent(chapter.description || "");
  const realmName = encodeURIComponent(chapter.realmName || "");
  uni.navigateTo({
    url: `/subPages/chapter-map/index?chapterId=${chapter.id}&chapterSeq=${seq}&name=${name}&desc=${desc}&realmName=${realmName}`,
  });
}

async function handleContinuePractice(): Promise<void> {
  const ch = heroChapter.value;
  if (!ch) return;
  try {
    const gateList = await AppBankAPI.getGatesByChapter(ch.id, activeGuestIds());
    const playable = gateList.find((g) => !g.passed && !g.locked && !g.empty)
      || gateList.find((g) => !g.locked && !g.empty);
    if (playable) {
      if (!userStore.isAuthenticated && !userStore.guestModeEnabled) {
        ensureAuthenticated();
        return;
      }
      const offset = gateList.some((g) => g.gateIndex === 0) ? 1 : 0;
      uni.navigateTo({
        url: `/subPages/quiz/index?mode=GATE&gateId=${playable.id}&gateSeq=${playable.gateIndex + offset}`,
      });
      return;
    }
  } catch {
    // Fallback to chapter map on error
  }
  openChapterMap(ch, heroChapterSeq.value);
}

function handleNoticeTap(): void {
  if (currentRealm.value.examEligible) {
    startAdvanceExam();
    return;
  }
  uni.showModal({
    title: "修炼公告",
    content: noticeText.value,
    showCancel: false,
    confirmText: "知道了",
    confirmColor: "#0284C7",
  });
}

function openSystemPopup(): void {
  showSystemPopup.value = true;
}

function handleChooseRealmFromPopup(realm: RealmItem): void {
  showSystemPopup.value = false;
  selectRealmTab(realm);
}

function startAdvanceExam(): void {
  if (!ensureAuthenticated()) return;
  uni.navigateTo({
    url: "/subPages/quiz/index?mode=ADVANCE_EXAM",
  });
}

function handleExamFromPopup(): void {
  showSystemPopup.value = false;
  startAdvanceExam();
}

function goRealmsOverview(): void {
  showSystemPopup.value = false;
  uni.navigateTo({ url: "/subPages/levels/index" });
}

onShow(() => {
  void nextTick(() => {
    innerScrollTop.value = currentScrollY.value;
  });
  void refreshPage();
});
</script>

<style lang="scss" scoped>
.home-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  background-color: var(--color-bg-page);
}

.home-scroll {
  flex: 1;
  min-height: 0;
}

.home-body {
  padding-bottom: 40rpx;
}

.greeting-row {
  display: flex;
  gap: 20rpx;
  align-items: center;
  justify-content: space-between;
  padding: 28rpx 32rpx 16rpx;
}

.greeting-main {
  flex: 1;
  min-width: 0;
}

.greeting-title {
  display: block;
  font-size: 40rpx;
  font-weight: 700;
  line-height: 1.25;
  color: var(--color-text);
}

.greeting-sub {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  margin-top: 8rpx;
  font-size: 26rpx;
  line-height: 1.4;
}

.greeting-sub__muted {
  color: var(--color-text-muted);
}

.greeting-sub__realm {
  margin: 0 8rpx;
  font-weight: 500;
  color: var(--color-primary);
}

.hero-card {
  padding: 32rpx;
  margin: 12rpx 24rpx 0;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.hero-card__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.hero-card__eyebrow {
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text);
}

.hero-card__title {
  display: block;
  margin-top: 20rpx;
  font-size: 36rpx;
  font-weight: 700;
  line-height: 1.35;
  color: var(--color-text);
}

.hero-card__sub {
  display: block;
  margin-top: 8rpx;
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.hero-progress {
  display: flex;
  gap: 24rpx;
  align-items: center;
  margin-top: 26rpx;
}

.hero-progress__track {
  flex: 1;
  height: 8rpx;
  overflow: hidden;
  background-color: var(--color-fill-2);
  border-radius: 9999px;
}

.hero-progress__fill {
  height: 100%;
  background-color: var(--color-primary);
  border-radius: 9999px;
  transition: width 0.25s ease;
}

.hero-progress__pct {
  font-size: 24rpx;
  color: var(--color-text-muted);
  white-space: nowrap;
}

.hero-card__footer {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: flex-end;
  padding-top: 24rpx;
  margin-top: 26rpx;
  border-top: 1px solid var(--color-border);
}

.notice-skeleton {
  margin: 24rpx 24rpx 0;
}

.notice-banner {
  display: flex;
  gap: 14rpx;
  align-items: center;
  padding: 18rpx 24rpx;
  margin: 24rpx 24rpx 0;
  background-color: var(--color-warning-light);
  border-radius: 12rpx;
}

.notice-banner__text {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 26rpx;
  color: var(--color-warning);
  white-space: nowrap;
}

.catalog-card {
  margin: 0 24rpx;
  overflow: hidden;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.realm-tabs-scroll {
  width: 100%;
  border-bottom: 1px solid var(--color-border);
}

.realm-tabs {
  display: flex;
  align-items: center;
  padding: 0 12rpx;
}

.realm-tab {
  position: relative;
  display: flex;
  flex: 1 0 auto;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-width: 112rpx;
  height: 84rpx;
  padding: 0 16rpx;
}

.realm-tab__name {
  font-size: 28rpx;
  font-weight: 400;
  color: var(--color-text-muted);
  white-space: nowrap;
}

.realm-tab--active .realm-tab__name {
  font-weight: 600;
  color: var(--color-text);
}

.realm-tab__bar {
  position: absolute;
  bottom: 0;
  width: 38rpx;
  height: 6rpx;
  background-color: var(--color-primary);
  border-radius: 9999px;
}

.realm-hint-strip {
  display: flex;
  gap: 12rpx;
  align-items: center;
  justify-content: space-between;
  padding: 16rpx 32rpx;
  background-color: var(--color-primary-soft);
}

.realm-hint-strip__text {
  flex: 1;
  font-size: 22rpx;
  color: var(--color-primary);
}

.realm-hint-strip__action {
  flex-shrink: 0;
  font-size: 22rpx;
  font-weight: 600;
  color: var(--color-primary);
}

.chapter-skeleton-list {
  padding: 8rpx 0;
}

.chapter-skeleton-row {
  padding: 26rpx 32rpx;
  border-bottom: 1px solid var(--color-border);

  &:last-child {
    border-bottom: none;
  }
}

.catalog-empty {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
  align-items: center;
  padding: 72rpx 32rpx;
}

.catalog-empty__text {
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.chapter-list {
  display: flex;
  flex-direction: column;
}

.chapter-row {
  background-color: var(--color-bg-card);

  &:active {
    background-color: var(--color-fill-1);
  }
}

.chapter-row__inner {
  display: flex;
  gap: 24rpx;
  align-items: center;
  padding: 28rpx 32rpx;
}

.chapter-row__divider {
  height: 1px;
  margin: 0 32rpx;
  background-color: var(--color-border);
}

.chapter-badge {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 72rpx;
  height: 72rpx;
  border-radius: 16rpx;

  &--done {
    color: var(--color-success);
    background-color: var(--color-success-light);
  }

  &--active {
    color: var(--color-primary);
    background-color: var(--color-primary-soft);
  }

  &--idle {
    color: var(--color-text-muted);
    background-color: var(--color-fill-1);
  }
}

.chapter-badge__num {
  font-size: 28rpx;
  font-weight: 700;
  color: inherit;
}

.chapter-main {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 6rpx;
  min-width: 0;
}

.chapter-main__title {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text);
  white-space: nowrap;
}

.chapter-main__desc {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 24rpx;
  color: var(--color-text-muted);
  white-space: nowrap;
}

.chapter-right {
  display: flex;
  flex-shrink: 0;
  gap: 12rpx;
  align-items: center;
}

.chapter-right__count {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.bottom-exam-tip {
  padding: 24rpx 32rpx 0;
  text-align: center;
}

.bottom-exam-tip__text {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.system-sheet {
  display: flex;
  flex-direction: column;
  max-height: 76vh;
  padding: 28rpx 32rpx 32rpx;
  overflow: hidden;
  background-color: var(--color-bg-card);
}

.system-sheet__header {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: space-between;
}

.system-sheet__close-placeholder {
  width: 48rpx;
  height: 48rpx;
}

.system-sheet__title {
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text);
}

.system-sheet__close {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48rpx;
  height: 48rpx;
}

.system-sheet__desc {
  margin-top: 16rpx;
  font-size: 24rpx;
  line-height: 1.5;
  color: var(--color-text-muted);
}

.system-sheet__scroll {
  flex: 1;
  min-height: 0;
  max-height: 48vh;
  margin-top: 24rpx;
}

.system-list-card {
  overflow: hidden;
  border: 1px solid var(--color-border);
  border-radius: 16rpx;
}

.system-row {
  background-color: var(--color-bg-card);

  &:active {
    background-color: var(--color-fill-1);
  }
}

.system-row__content {
  display: flex;
  gap: 20rpx;
  align-items: center;
  justify-content: space-between;
  padding: 26rpx 28rpx;
}

.system-row__main {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 6rpx;
  min-width: 0;
}

.system-row__title {
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-text);
}

.system-row__sub {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.system-row__divider {
  height: 1px;
  margin: 0 28rpx;
  background-color: var(--color-border);
}

.system-sheet__footer {
  margin-top: 28rpx;
}
</style>
