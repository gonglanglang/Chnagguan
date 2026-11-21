<template>
  <app-provider>
    <view class="tabbar-shell">
      <view class="tabbar-shell__content">
        <slot />
      </view>
      <wd-tabbar
        v-model="activePath"
        bordered
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
            <app-icon
              :name="item.icon"
              :size="21"
              :color="active ? 'primary' : 'muted'"
            />
          </template>
        </wd-tabbar-item>
      </wd-tabbar>
    </view>
  </app-provider>
</template>

<script setup lang="ts">
import { ref, nextTick, onMounted } from "vue";
import { onShow } from "@dcloudio/uni-app";

const tabbarList = [
  { name: "/pages/index/index", title: "首页", icon: "gate-home" },
  { name: "/pages/cultivate/index", title: "修炼", icon: "cultivate-scroll" },
  { name: "/pages/wrong/index", title: "错题本", icon: "wrong-sword" },
  { name: "/pages/mine/index", title: "我的", icon: "dao-user" },
];

const activePath = ref(tabbarList[0].name);

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

  // #ifdef APP-PLUS
  uni.hideTabBar();
  // #endif
});

onShow(() => {
  syncActiveTab();
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
