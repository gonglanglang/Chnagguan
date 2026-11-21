<template>
  <view class="menu-section">
    <view v-for="group in groups" :key="group.title" class="menu-card">
      <wd-cell-group :title="group.title" border>
        <wd-cell
          v-for="item in group.items"
          :key="item.key"
          :title="item.title"
          :value="item.value"
          is-link
          clickable
          @click="emit('select', item.key)"
        >
          <template #icon>
            <app-icon
              :name="item.icon"
              size="18"
              color="primary"
              custom-class="menu-card__icon"
            />
          </template>
        </wd-cell>
      </wd-cell-group>
    </view>
  </view>
</template>

<script setup lang="ts">
export interface MenuEntry {
  key: string;
  title: string;
  icon: string;
  value?: string;
}

export interface MenuGroup {
  title: string;
  items: MenuEntry[];
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
  gap: 20rpx;
  margin-top: 24rpx;
}

.menu-card {
  overflow: hidden;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.menu-card__icon {
  margin-right: 16rpx;
}
</style>
