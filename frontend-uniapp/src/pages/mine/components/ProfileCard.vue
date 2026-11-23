<template>
  <view class="profile-card">
    <view class="profile-head" @click="isAuthenticated ? emit('edit') : emit('login')">
      <view class="avatar-wrap">
        <image
          v-if="avatarUrl"
          :src="avatarUrl"
          mode="aspectFill"
          class="avatar-img"
        />
        <app-icon v-else name="user" :size="26" color="primary" />
      </view>

      <view class="profile-info">
        <text class="profile-name">
          {{ isAuthenticated ? nickname || "已登录道友" : "游客试玩" }}
        </text>
        <view class="profile-tags">
          <text class="ggl-tag ggl-tag--neutral">
            {{ isAuthenticated ? gradeName || "未设年级" : "本地体验" }}
          </text>
          <text class="ggl-tag ggl-tag--primary">
            {{ realmName }}
          </text>
        </view>
      </view>

      <view class="profile-edit">
        <text class="profile-edit__text">{{ isAuthenticated ? "编辑资料" : "点击登录" }}</text>
        <app-icon name="right" :size="14" color="#8C8C8C" />
      </view>
    </view>

    <view class="profile-stats">
      <view class="stat-col">
        <text class="stat-col__val">{{ passedGateCount }}</text>
        <text class="stat-col__label">累计闯关</text>
      </view>
      <view class="stat-col">
        <text class="stat-col__val">{{ passedChapterCount }}</text>
        <text class="stat-col__label">已学章节</text>
      </view>
      <view class="stat-col">
        <view class="stat-col__val-row">
          <text class="stat-col__val">{{ realmProgressPercent }}</text>
          <text class="stat-col__unit">%</text>
        </view>
        <text class="stat-col__label">本境进度</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
defineProps<{
  isAuthenticated: boolean;
  avatarUrl?: string;
  nickname?: string;
  gradeName?: string;
  realmName: string;
  passedGateCount: number;
  passedChapterCount: number;
  realmProgressPercent: number;
}>();

const emit = defineEmits<{
  edit: [];
  login: [];
}>();
</script>

<style lang="scss" scoped>
.profile-card {
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.profile-head {
  display: flex;
  gap: 24rpx;
  align-items: center;
}

.avatar-wrap {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 112rpx;
  height: 112rpx;
  overflow: hidden;
  background-color: var(--color-primary-soft);
  border-radius: 9999px;
}

.avatar-img {
  width: 100%;
  height: 100%;
}

.profile-info {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 10rpx;
  min-width: 0;
}

.profile-name {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 36rpx;
  font-weight: 700;
  color: var(--color-text);
  white-space: nowrap;
}

.profile-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  align-items: center;
}

.profile-edit {
  display: flex;
  flex-shrink: 0;
  gap: 4rpx;
  align-items: center;
}

.profile-edit__text {
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.profile-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  padding-top: 28rpx;
  margin-top: 28rpx;
  border-top: 1px solid var(--color-border);
}

.stat-col {
  display: flex;
  flex-direction: column;
  gap: 6rpx;
  align-items: center;
}

.stat-col__val-row {
  display: flex;
  align-items: baseline;
}

.stat-col__val {
  font-size: 40rpx;
  font-weight: 700;
  color: var(--color-text);
}

.stat-col__unit {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.stat-col__label {
  font-size: 24rpx;
  color: var(--color-text-muted);
}
</style>
