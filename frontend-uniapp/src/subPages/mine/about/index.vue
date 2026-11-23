<template>
  <app-page-shell title="关于过关啦" :has-footer="true">
    <template v-if="loading">
      <view class="about-card">
        <wd-skeleton
          animation="gradient"
          :row-col="[
            [
              { type: 'rect', width: '48px', height: '48px', borderRadius: '10px', marginRight: '12px' },
              { width: '58%', height: '20px' },
            ],
            { width: '100%', height: '14px' },
            { width: '92%', height: '14px' },
            { width: '64%', height: '14px' },
          ]"
        />
      </view>

      <view class="about-sk-group">
        <wd-skeleton
          animation="gradient"
          :row-col="[
            { width: '28%', height: '14px' },
            [{ width: '32%', height: '16px' }, { width: '52%', height: '16px' }],
            [{ width: '32%', height: '16px' }, { width: '48%', height: '16px' }],
            [{ width: '32%', height: '16px' }, { width: '54%', height: '16px' }],
            [{ width: '32%', height: '16px' }, { width: '52%', height: '16px' }],
          ]"
        />
      </view>
    </template>

    <template v-else>
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
          全境界内容均已开放自由学习；完成当前境界学习要求后可参加随机抽题进阶考核，高境界亦可压制境界重温低境界题目。
        </text>
      </view>

      <wd-cell-group title="修炼规则" border custom-class="mt-24rpx">
        <wd-cell title="境界权限" value="全境界开放，支持跨级自由学习" />
        <wd-cell title="压制境界" value="高境界可压制至低境界刷题" />
        <wd-cell title="进阶考核" value="本境学成后随机抽题达标即晋升" />
        <wd-cell title="错题巩固" value="答错自动收录，重做答对即掌握" />
      </wd-cell-group>
    </template>

    <template #footer>
      <wd-skeleton
        v-if="loading"
        animation="gradient"
        :row-col="[{ width: '100%', height: '42px', borderRadius: '10px' }]"
      />
      <wd-button v-else type="primary" block :loading="checking" @click="handleCheckUpdate">
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
const loading = ref(true);
const checking = ref(false);

onMounted(async () => {
  try {
    const local = await getLocalAppVersion();
    version.value = local.version;
  } finally {
    loading.value = false;
  }
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
  border-radius: 16rpx;
}

.about-sk-group {
  padding: 26rpx 24rpx;
  margin-top: 24rpx;
  background: var(--color-bg-card);
  border-radius: 16rpx;
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
