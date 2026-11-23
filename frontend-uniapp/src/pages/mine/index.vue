<template>
  <view class="mine-page">
    <app-navbar title="我的" :show-back="false" :fixed="false" />

    <scroll-view scroll-y :show-scrollbar="false" class="mine-scroll">
      <view class="mine-body">
        <!-- 骨架屏 -->
        <template v-if="initialLoading">
          <view class="profile-skeleton-card">
            <wd-skeleton
              animation="gradient"
              :row-col="[
                [{ width: '56px', height: '56px', type: 'circle' }, { width: '58%', height: '48px' }],
                [{ width: '26%', height: '38px' }, { width: '26%', height: '38px' }, { width: '26%', height: '38px' }],
              ]"
            />
          </view>

          <view class="grid-skeleton-card">
            <wd-skeleton
              animation="gradient"
              :row-col="[[
                { width: '20%', height: '46px' },
                { width: '20%', height: '46px' },
                { width: '20%', height: '46px' },
                { width: '20%', height: '46px' },
              ]]"
            />
          </view>

          <text class="ggl-section-label mine-section-label">设置</text>
          <view class="menu-skeleton-card">
            <view v-for="n in 4" :key="n" class="menu-skeleton-row">
              <wd-skeleton
                animation="gradient"
                :row-col="[[{ width: '18px', height: '18px' }, { width: '48%', height: '18px' }, { width: '16%', height: '14px' }]]"
              />
            </view>
          </view>
        </template>

        <!-- 正式内容 -->
        <template v-else>
          <profile-card
            :is-authenticated="userStore.isAuthenticated"
            :avatar-url="userStore.userInfo?.avatarUrl"
            :nickname="userStore.userInfo?.nickname || userStore.userInfo?.username"
            :grade-name="userStore.userInfo?.gradeName"
            :realm-name="userStore.currentRealm.realmName"
            :passed-gate-count="userStore.passedGateCount"
            :passed-chapter-count="passedChapters.length"
            :realm-progress-percent="realmProgressPercent"
            @edit="goProfile"
            @login="goLogin"
          />

          <!-- 四宫格学习入口 -->
          <view class="quick-grid">
            <view class="quick-item" @click="goRealmsOverview">
              <view class="quick-item__icon">
                <app-icon name="layers" :size="22" color="primary" />
              </view>
              <text class="quick-item__label">境界体系</text>
            </view>

            <view class="quick-item" @click="goEssayRecords">
              <view class="quick-item__icon">
                <app-icon name="pen-line" :size="22" color="primary" />
              </view>
              <text class="quick-item__label">解答记录</text>
            </view>

            <view class="quick-item" @click="handleStartExam">
              <view class="quick-item__icon">
                <app-icon name="graduation-cap" :size="22" color="primary" />
              </view>
              <text class="quick-item__label">进阶考</text>
            </view>

            <view class="quick-item" @click="openRecordsPopup">
              <view class="quick-item__icon">
                <app-icon name="chart-column" :size="22" color="primary" />
              </view>
              <text class="quick-item__label">章节档案</text>
            </view>
          </view>

          <!-- 设置分组 -->
          <menu-section :groups="menuGroups" @select="handleMenuSelect" />

          <!-- 退出 / 登录按钮 -->
          <view v-if="userStore.isAuthenticated" class="auth-action">
            <wd-button
              type="danger"
              variant="plain"
              size="large"
              block
              :loading="isLoggingOut"
              @click="requestLogout"
            >
              {{ isLoggingOut ? "正在退出..." : "退出登录" }}
            </wd-button>
          </view>
          <view v-else class="auth-action">
            <wd-button type="primary" size="large" block @click="goLogin">
              登录 / 注册
            </wd-button>
          </view>
        </template>
      </view>
    </scroll-view>

    <!-- 章节档案弹窗 -->
    <wd-popup
      v-model="showChapterRecordsPopup"
      position="bottom"
      :z-index="900"
      safe-area-inset-bottom
      custom-style="border-top-left-radius: 32rpx; border-top-right-radius: 32rpx; overflow: hidden;"
    >
      <view class="records-sheet">
        <view class="records-sheet__header">
          <view class="records-sheet__placeholder" />
          <text class="records-sheet__title">章节学习档案</text>
          <view class="records-sheet__close" @click="showChapterRecordsPopup = false">
            <app-icon name="close" :size="18" color="muted" />
          </view>
        </view>

        <text class="records-sheet__sub">
          已留下闯关记录的章节共 {{ passedChapters.length }} 个，点击可直接进入该章闯关地图。
        </text>

        <view v-if="passedChapters.length === 0" class="records-empty">
          <app-icon name="empty" :size="28" color="muted" />
          <text class="records-empty__text">
            {{ userStore.isAuthenticated ? "还没有通过关卡，回首页开始第一关吧" : "登录后可同步全部章节学习记录" }}
          </text>
        </view>

        <scroll-view v-else scroll-y :show-scrollbar="false" class="records-scroll">
          <view class="records-list-card">
            <view
              v-for="(ch, idx) in passedChapters"
              :key="ch.id"
              class="record-row"
              @click="openChapterFromPopup(ch, idx + 1)"
            >
              <view class="record-row__inner">
                <view class="record-row__main">
                  <text class="record-row__title">{{ ch.name }}</text>
                  <text class="record-row__sub">{{ ch.realmName }}</text>
                </view>
                <text
                  class="ggl-tag"
                  :class="ch.passedCount >= ch.totalGates ? 'ggl-tag--success' : 'ggl-tag--primary'"
                >
                  {{ ch.passedCount }}/{{ ch.totalGates }} 关
                </text>
              </view>
              <view v-if="idx < passedChapters.length - 1" class="record-row__divider" />
            </view>
          </view>
        </scroll-view>
      </view>
    </wd-popup>
  </view>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { onShow } from "@dcloudio/uni-app";
import { useToast } from "@wot-ui/ui";
import { AppUserAPI } from "@/api/guoguanla";
import { useCacheCleaner } from "@/composables/useCacheCleaner";
import { useLogout } from "@/composables/useLogout";
import { useTheme } from "@/composables/useTheme";
import { useUserStore } from "@/store";
import type { ChapterCard } from "@/types/guoguanla";
import { checkAppUpdate, getLocalAppVersion } from "@/utils/app-update";
import { ensureAuthenticated } from "@/utils/auth";
import MenuSection, { type MenuGroup } from "./components/MenuSection.vue";
import ProfileCard from "./components/ProfileCard.vue";

definePage({
  name: "mine",
  layout: "tabbar",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "我的",
  },
});

const userStore = useUserStore();
const toast = useToast();
const { selectedThemeColor } = useTheme();
const { isLoggingOut, requestLogout } = useLogout();
const { usageText, loadUsage, clearCache } = useCacheCleaner();

const chapterRecords = ref<ChapterCard[]>([]);
const initialLoading = ref(true);
const hasLoadedOnce = ref(false);
const lastAuthState = ref(userStore.isAuthenticated);
const currentAppVersion = ref(import.meta.env.VITE_APP_VERSION || "1.0.0");
const showChapterRecordsPopup = ref(false);

const passedChapters = computed(() => chapterRecords.value.filter((c) => c.passedCount > 0));

const realmProgressPercent = computed(() => {
  const realm = userStore.currentRealm;
  if (!realm || !realm.gateCount) return 0;
  return Math.min(100, Math.round((realm.passedGateCount / realm.gateCount) * 100));
});

const menuGroups = computed<MenuGroup[]>(() => [
  {
    title: "设置",
    items: [
      {
        key: "theme",
        title: "主题设置",
        icon: "theme",
        value: selectedThemeColor.value?.name || "默认",
      },
      {
        key: "cache",
        title: "清理缓存",
        icon: "clear",
        value: usageText.value,
      },
      {
        key: "network",
        title: "网络检测",
        icon: "wifi",
      },
      {
        key: "update",
        title: "检查新版本",
        icon: "refresh",
        value: `v${currentAppVersion.value}`,
      },
      {
        key: "about",
        title: "关于我们",
        icon: "info",
        value: `v${currentAppVersion.value}`,
      },
    ],
  },
]);

function goLogin(): void {
  uni.navigateTo({
    url: `/subPages/login/index?redirect=${encodeURIComponent("/pages/mine/index")}`,
  });
}

function goProfile(): void {
  if (!ensureAuthenticated()) return;
  uni.navigateTo({ url: "/subPages/profile/index" });
}

function goRealmsOverview(): void {
  uni.navigateTo({ url: "/subPages/levels/index" });
}

function goEssayRecords(): void {
  if (!ensureAuthenticated()) return;
  uni.navigateTo({ url: "/subPages/essay-records/index" });
}

function handleStartExam(): void {
  if (!ensureAuthenticated()) return;
  if (!userStore.currentRealm.examEligible) {
    toast.info(`还差 ${Math.max(1, userStore.currentRealm.examRemainingGates)} 关解锁进阶考`);
    return;
  }
  uni.navigateTo({ url: "/subPages/quiz/index?mode=ADVANCE_EXAM" });
}

function openRecordsPopup(): void {
  showChapterRecordsPopup.value = true;
}

function openChapterFromPopup(ch: ChapterCard, seq: number): void {
  showChapterRecordsPopup.value = false;
  uni.navigateTo({
    url: `/subPages/chapter-map/index?chapterId=${ch.id}&chapterSeq=${seq}&name=${encodeURIComponent(ch.name || "")}&desc=${encodeURIComponent(ch.description || "")}&realmName=${encodeURIComponent(ch.realmName || "")}`,
  });
}

function handleMenuSelect(key: string): void {
  switch (key) {
    case "theme":
      uni.navigateTo({ url: "/subPages/mine/settings/theme/index" });
      break;
    case "cache":
      uni.showModal({
        title: "清理缓存",
        content: "将清理临时缓存，不影响登录状态与设置。",
        success: (res) => {
          if (res.confirm) void clearCache();
        },
      });
      break;
    case "network":
      uni.navigateTo({ url: "/subPages/mine/settings/network/index" });
      break;
    case "update":
      void checkAppUpdate({ silent: false });
      break;
    case "about":
      uni.navigateTo({ url: "/subPages/mine/about/index" });
      break;
  }
}

async function syncMineData(): Promise<void> {
  if (!hasLoadedOnce.value || lastAuthState.value !== userStore.isAuthenticated) {
    initialLoading.value = true;
  }
  lastAuthState.value = userStore.isAuthenticated;
  void loadUsage();
  void getLocalAppVersion().then((info) => {
    currentAppVersion.value = info.version;
  });
  if (!userStore.isAuthenticated) {
    chapterRecords.value = [];
    hasLoadedOnce.value = true;
    initialLoading.value = false;
    return;
  }
  try {
    await userStore.loadHomeSummary(true);
    await userStore.loadUserInfo(true);
    chapterRecords.value = await AppUserAPI.getChapterRecords();
  } catch {
    // Silent fallback
  } finally {
    hasLoadedOnce.value = true;
    initialLoading.value = false;
  }
}

onShow(() => {
  void syncMineData();
});
</script>

<style lang="scss" scoped>
.mine-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  background-color: var(--color-bg-page);
}

.mine-scroll {
  flex: 1;
  min-height: 0;
}

.mine-body {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
  padding: 24rpx 24rpx 56rpx;
}

.profile-skeleton-card,
.grid-skeleton-card {
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.mine-section-label {
  padding: 0 8rpx;
  margin: 4rpx 0 -10rpx;
}

.menu-skeleton-card {
  overflow: hidden;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.menu-skeleton-row {
  padding: 28rpx 32rpx;
  border-bottom: 1px solid var(--color-border);

  &:last-child {
    border-bottom: none;
  }
}

.quick-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  padding: 28rpx 16rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.quick-item {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
  align-items: center;
  justify-content: center;
  padding: 8rpx 0;

  &:active {
    opacity: 0.72;
  }
}

.quick-item__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48rpx;
  height: 48rpx;
}

.quick-item__label {
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.auth-action {
  margin-top: 12rpx;
}

.records-sheet {
  display: flex;
  flex-direction: column;
  max-height: 76vh;
  padding: 28rpx 32rpx 36rpx;
  overflow: hidden;
  background-color: var(--color-bg-card);
}

.records-sheet__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.records-sheet__placeholder {
  width: 48rpx;
  height: 48rpx;
}

.records-sheet__title {
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text);
}

.records-sheet__close {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48rpx;
  height: 48rpx;
}

.records-sheet__sub {
  margin-top: 14rpx;
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.records-empty {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
  align-items: center;
  padding: 64rpx 24rpx;
  margin-top: 24rpx;
  text-align: center;
  border: 1px solid var(--color-border);
  border-radius: 16rpx;
}

.records-empty__text {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.records-scroll {
  flex: 1;
  min-height: 0;
  max-height: 48vh;
  margin-top: 24rpx;
}

.records-list-card {
  overflow: hidden;
  border: 1px solid var(--color-border);
  border-radius: 16rpx;
}

.record-row {
  background-color: var(--color-bg-card);

  &:active {
    background-color: var(--color-fill-1);
  }
}

.record-row__inner {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
  padding: 24rpx 28rpx;
}

.record-row__main {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 4rpx;
  min-width: 0;
}

.record-row__title {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-text);
  white-space: nowrap;
}

.record-row__sub {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.record-row__divider {
  height: 1px;
  margin: 0 28rpx;
  background-color: var(--color-border);
}
</style>
