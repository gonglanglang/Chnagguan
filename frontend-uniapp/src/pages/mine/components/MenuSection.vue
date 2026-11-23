<template>
  <view class="menu-section">
    <view v-for="(group, gIdx) in groups" :key="gIdx" class="menu-block">
      <text v-if="group.title" class="ggl-section-label menu-label">{{ group.title }}</text>

      <view class="menu-card">
        <view
          v-for="(item, iIdx) in group.items"
          :key="item.key"
          class="menu-row"
          @click="emit('select', item.key)"
        >
          <view class="menu-row__inner">
            <view class="menu-row__left">
              <app-icon :name="item.icon" :size="18" color="secondary" />
              <text class="menu-row__title">{{ item.title }}</text>
            </view>

            <view class="menu-row__right">
              <text v-if="item.value" class="menu-row__val">{{ item.value }}</text>
              <app-icon name="right" :size="14" color="#BFBFBF" />
            </view>
          </view>
          <view v-if="iIdx < group.items.length - 1" class="menu-row__divider" />
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
export interface MenuItem {
  key: string;
  title: string;
  icon: string;
  value?: string;
}

export interface MenuGroup {
  title?: string;
  items: MenuItem[];
}

defineProps<{
  groups: MenuGroup[];
}>();

const emit = defineEmits<{
  select: [key: string];
}>();
</script>

<style lang="scss" scoped>
.menu-section {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.menu-block {
  display: flex;
  flex-direction: column;
}

.menu-label {
  padding: 0 8rpx;
  margin: 0 0 14rpx;
}

.menu-card {
  overflow: hidden;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.menu-row {
  background-color: var(--color-bg-card);

  &:active {
    background-color: var(--color-fill-1);
  }
}

.menu-row__inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 28rpx 32rpx;
}

.menu-row__left {
  display: flex;
  gap: 20rpx;
  align-items: center;
}

.menu-row__title {
  font-size: 30rpx;
  color: var(--color-text);
}

.menu-row__right {
  display: flex;
  gap: 10rpx;
  align-items: center;
}

.menu-row__val {
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.menu-row__divider {
  height: 1px;
  margin: 0 32rpx;
  background-color: var(--color-border);
}
</style>
