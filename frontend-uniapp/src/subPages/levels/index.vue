<template>
  <view class="realms-page">
    <view class="summary-card">
      <view class="summary-card__badge">
        <wd-icon name="trophy" size="24" color="var(--color-primary)" />
      </view>
      <view class="summary-card__info">
        <text class="summary-card__title">当前境界：{{ userStore.currentRealm.realmName }}</text>
        <text class="summary-card__sub">
          低境不可入高境，高境可压制境界重温低境题目
        </text>
      </view>
    </view>

    <view class="realm-list">
      <view
        v-for="item in userStore.realms"
        :key="item.realmCode"
        class="realm-card"
        :class="{ 'realm-card--locked': item.isHigher }"
      >
        <view class="realm-card__head">
          <view class="realm-card__title-wrap">
            <view class="realm-card__order" :class="item.unlocked ? 'realm-card__order--open' : ''">
              <wd-icon v-if="item.isCurrent" name="check" size="15" color="#ffffff" />
              <text v-else>{{ item.realmOrder }}</text>
            </view>
            <view>
              <text class="realm-card__name">{{ item.realmName }}</text>
              <text class="realm-card__diff">{{ item.difficultyLabel }}</text>
            </view>
          </view>

          <wd-tag v-if="item.isCurrent" type="primary" size="small">当前境界</wd-tag>
          <wd-tag v-else-if="item.isLower" type="success" variant="light" size="small">
            已突破 · 可压制
          </wd-tag>
          <wd-tag v-else variant="light" size="small">未解锁</wd-tag>
        </view>

        <text v-if="item.description" class="realm-card__desc">{{ item.description }}</text>

        <view v-if="item.realmOrder < 6" class="realm-card__rule">
          <text>
            进阶考核：随机抽取 {{ item.examQuestionCount }} 题 · {{ item.examPassScore }} 分及格
          </text>
          <text>
            {{ item.unlockGates > 0 ? `过本境 ${item.unlockGates} 关解锁` : "本境全通后解锁" }}
          </text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { onShow } from "@dcloudio/uni-app";
import { useUserStore } from "@/store";

definePage({
  name: "levels",
  style: {
    navigationBarTitleText: "修仙境界体系",
  },
});

const userStore = useUserStore();

onShow(() => {
  void userStore.loadHomeSummary(true);
});
</script>

<style lang="scss" scoped>
.realms-page {
  min-height: 100vh;
  padding: 24rpx 24rpx 48rpx;
  background: var(--color-bg-page);
}

.summary-card {
  display: flex;
  gap: 20rpx;
  align-items: center;
  padding: 26rpx 24rpx;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.summary-card__badge {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 80rpx;
  height: 80rpx;
  background: var(--color-primary-soft);
  border-radius: 18rpx;
}

.summary-card__info {
  display: flex;
  flex-direction: column;
  gap: 6rpx;
}

.summary-card__title {
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text);
}

.summary-card__sub {
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.realm-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
  margin-top: 20rpx;
}

.realm-card {
  padding: 24rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 18rpx;

  &--locked {
    opacity: 0.68;
  }
}

.realm-card__head {
  display: flex;
  gap: 12rpx;
  align-items: center;
  justify-content: space-between;
}

.realm-card__title-wrap {
  display: flex;
  gap: 16rpx;
  align-items: center;
}

.realm-card__order {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 56rpx;
  height: 56rpx;
  font-size: 24rpx;
  font-weight: 600;
  color: var(--color-text-muted);
  background: var(--color-bg-page);
  border-radius: 14rpx;

  &--open {
    color: var(--color-primary);
    background: var(--color-primary-soft);
  }
}

.realm-card__name {
  display: block;
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text);
}

.realm-card__diff {
  display: block;
  margin-top: 4rpx;
  font-size: 22rpx;
  color: var(--color-text-secondary);
}

.realm-card__desc {
  display: block;
  margin-top: 14rpx;
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.realm-card__rule {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  justify-content: space-between;
  padding-top: 14rpx;
  margin-top: 14rpx;
  font-size: 22rpx;
  color: var(--color-text-muted);
  border-top: 1px solid var(--color-border);
}
</style>
