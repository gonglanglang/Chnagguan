<template>
  <app-page-shell title="修仙境界体系">
    <template v-if="initialLoading">
      <view class="summary-card">
        <wd-skeleton
          animation="gradient"
          :row-col="[
            [
              { type: 'rect', width: '40px', height: '40px', borderRadius: '10px', marginRight: '10px' },
              { width: '68%', height: '18px' },
            ],
            { width: '82%', height: '13px' },
          ]"
        />
      </view>

      <view class="realm-list">
        <view v-for="n in 6" :key="n" class="realm-card">
          <wd-skeleton
            animation="gradient"
            :row-col="[
              [
                { type: 'rect', width: '28px', height: '28px', borderRadius: '7px', marginRight: '10px' },
                { width: '42%', height: '16px' },
                { width: '24%', height: '20px', borderRadius: '6px' },
              ],
              { width: '88%', height: '13px' },
              [
                { width: '56%', height: '12px' },
                { width: '28%', height: '12px' },
              ],
            ]"
          />
        </view>
      </view>
    </template>

    <template v-else>
      <view class="summary-card">
        <view class="summary-card__badge">
          <app-icon name="realm-lotus" size="24" color="primary" />
        </view>
        <view class="summary-card__info">
          <text class="summary-card__title">当前境界：{{ userStore.currentRealm.realmName }}</text>
          <text class="summary-card__sub">
            全境界自由学习，完成本境要求后可参加进阶考核突破
          </text>
        </view>
      </view>

      <view class="realm-list">
        <view v-for="item in userStore.realms" :key="item.realmCode" class="realm-card">
          <view class="realm-card__head">
            <view class="realm-card__title-wrap">
              <view class="realm-card__order realm-card__order--open">
                <app-icon v-if="item.isCurrent" name="check" size="15" color="#ffffff" />
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
            <wd-tag v-else type="info" variant="light" size="small">可跨级学习</wd-tag>
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
    </template>
  </app-page-shell>
</template>

<script setup lang="ts">
import { onShow } from "@dcloudio/uni-app";
import { useUserStore } from "@/store";

definePage({
  name: "levels",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "修仙境界体系",
  },
});

const userStore = useUserStore();
const initialLoading = ref(!userStore.homeSummary);

onShow(async () => {
  if (!userStore.homeSummary) {
    initialLoading.value = true;
  }
  try {
    await userStore.loadHomeSummary(true);
  } catch {
    // Keep fallback realms
  } finally {
    initialLoading.value = false;
  }
});
</script>

<style lang="scss" scoped>
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
