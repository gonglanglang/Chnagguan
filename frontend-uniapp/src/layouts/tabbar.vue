<template>
  <app-provider>
    <view class="tabbar-shell">
      <view class="tabbar-shell__content">
        <slot />
      </view>
      <view class="tabbar-bar">
        <wd-tabbar
          v-model="activePath"
          :bordered="false"
          safe-area-inset-bottom
          :fixed="false"
          @change="handleTabbarChange"
        >
          <wd-tabbar-item
            v-for="item in tabbarList"
            :key="item.name"
            :name="item.name"
            :title="item.title"
          >
            <template #icon="{ active }">
              <view class="tab-icon-wrap">
                <app-icon
                  :name="item.icon"
                  :size="21"
                  :color="active ? 'primary' : 'muted'"
                />
                <view v-if="item.badge && wrongBadgeText" class="tab-badge">
                  {{ wrongBadgeText }}
                </view>
              </view>
            </template>
          </wd-tabbar-item>
        </wd-tabbar>
      </view>
    </view>
  </app-provider>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, ref } from "vue";
import { onShow } from "@dcloudio/uni-app";
import { useUserStore } from "@/store";
import { syncOrientationForCurrentPage } from "@/utils/orientation";

const userStore = useUserStore();

const tabbarList = [
  { name: "/pages/index/index", title: "闯关", icon: "flag", badge: false },
  { name: "/pages/cultivate/index", title: "课堂", icon: "circle-play", badge: false },
  { name: "/pages/wrong/index", title: "错题本", icon: "notebook-pen", badge: true },
  { name: "/pages/mine/index", title: "我的", icon: "user", badge: false },
];

const activePath = ref(tabbarList[0].name);

const wrongBadgeText = computed(() => {
  const count = userStore.wrongCount;
  if (!count || count <= 0) return "";
  return count > 99 ? "99+" : String(count);
});

function syncActiveTab() {
  const pages = getCurrentPages();
  const currentPage = pages[pages.length - 1];
  const route = (currentPage?.route as string) || "";
  const matched = tabbarList.find((item) => item.name === `/${route}`);
  if (matched) {
    activePath.value = matched.name;
  }
}

function handleTabbarChange({ value }: { value: string }) {
  activePath.value = value;
  nextTick(() => {
    uni.switchTab({ url: value });
  });
}

onMounted(() => {
  syncActiveTab();
  syncOrientationForCurrentPage();

  // #ifdef APP-PLUS
  uni.hideTabBar();
  // #endif
});

onShow(() => {
  syncActiveTab();
  syncOrientationForCurrentPage();
  void userStore.refreshWrongCount();
});
</script>

<script lang="ts">
export default {
  options: {
    addGlobalClass: true,
    virtualHost: true,
    styleIsolation: "shared",
  },
};
</script>

<style lang="scss" scoped>
.tabbar-bar {
  flex-shrink: 0;
  background-color: var(--color-bg-card);
  border-top: 1px solid var(--color-border);
}

.tab-icon-wrap {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48rpx;
  height: 44rpx;
}

.tab-badge {
  position: absolute;
  top: -4rpx;
  right: -14rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 30rpx;
  height: 30rpx;
  padding: 0 8rpx;
  font-size: 20rpx;
  font-weight: 600;
  line-height: 1;
  color: #ffffff;
  background-color: var(--color-danger);
  border-radius: 9999px;
}
</style>
