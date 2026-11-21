<template>
  <view class="mine-page">
    <view class="mine-hero" :style="{ paddingTop: statusBarHeight + 'px' }">
      <view class="mine-hero__bar" />
    </view>

    <view class="mine-content">
      <profile-card
        :is-logged-in="userStore.isAuthenticated"
        :user-info="userStore.userInfo"
        :passed-count="userStore.passedGateCount"
        @login="goLogin"
        @profile="goProfile"
        @realms="goRealmsOverview"
      />

      <view v-if="userStore.isAuthenticated && passedChapters.length > 0" class="records-card">
        <view class="records-card__header">
          <text class="records-card__title">章节过关战绩</text>
          <text class="records-card__sub">共 {{ passedChapters.length }} 章有进展</text>
        </view>
        <view class="records-list">
          <view v-for="chap in passedChapters.slice(0, 5)" :key="chap.id" class="record-row">
            <text class="record-row__name">
              <template v-if="chap.realmName">[{{ chap.realmName }}] </template>
              {{ chap.name }}
            </text>
            <text class="record-row__count">{{ chap.passedCount }}/{{ chap.totalGates }} 关</text>
          </view>
        </view>
      </view>

      <menu-section :groups="menuGroups" @select="handleMenuSelect" />

      <view v-if="userStore.isAuthenticated" class="logout-wrap">
        <wd-button
          variant="plain"
          type="danger"
          block
          :loading="isLoggingOut"
          @click="requestLogout"
        >
          退出登录
        </wd-button>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { onShow } from "@dcloudio/uni-app";
import { AppUserAPI } from "@/api/guoguanla";
import { useCacheCleaner } from "@/composables/useCacheCleaner";
import { useLogout } from "@/composables/useLogout";
import { useNavbarMetrics } from "@/composables/useNavbarMetrics";
import { useUserStore } from "@/store";
import type { ChapterCard } from "@/types/guoguanla";
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
const { statusBarHeight } = useNavbarMetrics();
const { isLoggingOut, requestLogout } = useLogout();
const { usageText, loadUsage, clearCache } = useCacheCleaner();

const chapterRecords = ref<ChapterCard[]>([]);
const passedChapters = computed(() => chapterRecords.value.filter((c) => c.passedCount > 0));

const menuGroups = computed<MenuGroup[]>(() => [
  {
    title: "修炼档案",
    items: [
      {
        key: "realms",
        title: "修仙境界体系",
        icon: "trophy",
        value: userStore.currentRealm.realmName,
      },
      {
        key: "profile",
        title: "个人昵称修改",
        icon: "user",
        value: userStore.userInfo?.nickname || "",
      },
    ],
  },
  {
    title: "系统设置",
    items: [
      {
        key: "theme",
        title: "主题与深色模式",
        icon: "skin",
      },
      {
        key: "cache",
        title: "清理本地缓存",
        icon: "delete",
        value: usageText.value,
      },
      {
        key: "network",
        title: "网络服务检测",
        icon: "wifi",
      },
      {
        key: "about",
        title: "关于过关啦",
        icon: "info-circle",
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

function handleMenuSelect(key: string): void {
  switch (key) {
    case "realms":
      goRealmsOverview();
      break;
    case "profile":
      goProfile();
      break;
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
    case "about":
      uni.navigateTo({ url: "/subPages/mine/about/index" });
      break;
  }
}

async function syncMineData(): Promise<void> {
  void loadUsage();
  if (!userStore.isAuthenticated) {
    chapterRecords.value = [];
    return;
  }
  try {
    await userStore.loadUserInfo(true);
    chapterRecords.value = await AppUserAPI.getChapterRecords();
  } catch {
    // Silent fallback
  }
}

onShow(() => {
  void syncMineData();
});
</script>

<style lang="scss" scoped>
.mine-page {
  min-height: 100vh;
  background: var(--color-bg-page);
}

.mine-hero {
  background: linear-gradient(135deg, #16a34a 0%, #15803d 100%);
}

.mine-hero__bar {
  height: 120rpx;
}

.mine-content {
  padding: 0 24rpx 48rpx;
  margin-top: -64rpx;
}

.records-card {
  padding: 24rpx 28rpx;
  margin-top: 24rpx;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.records-card__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16rpx;
}

.records-card__title {
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text);
}

.records-card__sub {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.records-list {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
}

.record-row {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
  padding-top: 14rpx;
  border-top: 1px solid var(--color-border);
}

.record-row:first-child {
  padding-top: 0;
  border-top: none;
}

.record-row__name {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 26rpx;
  color: var(--color-text);
  white-space: nowrap;
}

.record-row__count {
  font-size: 24rpx;
  font-weight: 500;
  color: var(--color-primary);
}

.logout-wrap {
  margin-top: 32rpx;
}
</style>
