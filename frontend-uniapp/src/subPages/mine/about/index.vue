<template>
  <app-page-shell title="关于过关啦" :has-footer="true">
    <view class="about-card">
      <view class="about__header">
        <view class="about__badge">
          <app-icon name="book" size="28" color="#ffffff" />
        </view>
        <view class="about__info">
          <text class="about__title">过关啦</text>
          <text class="about__subtitle">修仙体系数学闯关 · v{{ version }}</text>
        </view>
      </view>
      <text class="about__desc">
        按「练气 → 筑基 → 结丹 → 假婴 → 元婴 → 化神」六大境界由浅入深划分题目难度。
        完成当前境界学习要求后可参加随机抽题进阶考核，高境界可随时压制境界重温低境界题目。
      </text>
    </view>

    <wd-cell-group title="修炼规则" border custom-class="mt-24rpx">
      <wd-cell title="境界权限" value="低境界不可挑战高境界题目" />
      <wd-cell title="压制境界" value="高境界可压制至低境界刷题" />
      <wd-cell title="进阶考核" value="本境学成后随机抽题达标即晋升" />
      <wd-cell title="错题巩固" value="答错自动收录，重做答对即掌握" />
    </wd-cell-group>

    <template #footer>
      <wd-button type="primary" block :loading="checking" @click="handleCheckUpdate">
        检查新版本
      </wd-button>
    </template>
  </app-page-shell>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { checkAppUpdate, getLocalAppVersion } from "@/utils/app-update";

definePage({
  name: "about",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "关于过关啦",
  },
});

const version = ref(import.meta.env.VITE_APP_VERSION || "1.0.0");
const checking = ref(false);

onMounted(async () => {
  const local = await getLocalAppVersion();
  version.value = local.version;
});

async function handleCheckUpdate(): Promise<void> {
  checking.value = true;
  try {
    await checkAppUpdate({ silent: false });
  } finally {
    checking.value = false;
  }
}
</script>

<style lang="scss" scoped>
.about-card {
  padding: 32rpx 28rpx;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.about__header {
  display: flex;
  gap: 24rpx;
  align-items: center;
}

.about__badge {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 96rpx;
  height: 96rpx;
  background: var(--color-primary);
  border-radius: 20rpx;
}

.about__info {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.about__title {
  font-size: 36rpx;
  font-weight: 600;
  color: var(--color-text);
}

.about__subtitle {
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.about__desc {
  display: block;
  margin-top: 24rpx;
  font-size: 26rpx;
  line-height: 1.65;
  color: var(--color-text-secondary);
}
</style>
