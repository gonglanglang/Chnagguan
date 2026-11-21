<template>
  <view class="profile-card">
    <view class="profile-card__main">
      <view class="profile-card__left" @click="isLoggedIn ? emit('profile') : emit('login')">
        <view class="profile-card__avatar">
          <text v-if="isLoggedIn" class="profile-card__avatar-text">{{ avatarText }}</text>
          <wd-icon v-else name="user" size="26" color="var(--color-primary)" />
        </view>
        <view class="profile-card__info">
          <text class="profile-card__name">
            {{ isLoggedIn ? userInfo?.nickname || userInfo?.username : "未登录（游客模式）" }}
          </text>
          <text class="profile-card__sub">
            {{
              isLoggedIn
                ? `${userInfo?.realmName || "练气"} · ${userInfo?.difficultyLabel || ""} · @${userInfo?.username}`
                : "点击登录或注册，同步修仙境界与过关记录"
            }}
          </text>
        </view>
      </view>

      <view v-if="isLoggedIn" class="profile-card__action" @click="emit('profile')">
        <text class="profile-card__action-text">改昵称</text>
        <wd-icon name="right" size="14" color="var(--color-text-muted)" />
      </view>
      <view v-else class="profile-card__action">
        <wd-button size="small" type="primary" @click="emit('login')">去登录</wd-button>
      </view>
    </view>

    <view class="profile-card__stats">
      <view class="stat-item" @click="emit('realms')">
        <text class="stat-item__value">{{ userInfo?.realmName || "练气" }}</text>
        <text class="stat-item__label">当前境界</text>
      </view>
      <view class="stat-divider" />
      <view class="stat-item">
        <text class="stat-item__value">{{ passedCount }}</text>
        <text class="stat-item__label">累计过关</text>
      </view>
      <view class="stat-divider" />
      <view class="stat-item" @click="emit('realms')">
        <text class="stat-item__value">{{ nextStatusText }}</text>
        <text class="stat-item__label">进阶状态</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import type { AppUserProfile } from "@/types/guoguanla";

const props = defineProps<{
  isLoggedIn: boolean;
  userInfo?: AppUserProfile;
  passedCount: number;
}>();

const emit = defineEmits<{
  login: [];
  profile: [];
  realms: [];
}>();

const avatarText = computed(() => {
  const source = props.userInfo?.nickname || props.userInfo?.username || "修";
  return source.slice(0, 1).toUpperCase();
});

const nextStatusText = computed(() => {
  if (!props.isLoggedIn || !props.userInfo) return "练气试玩";
  if (!props.userInfo.nextRealmName) return "已满境";
  if (props.userInfo.examEligible) return "可进阶";
  return `差 ${props.userInfo.examRemainingGates ?? 0} 关`;
});
</script>

<style lang="scss" scoped>
.profile-card {
  position: relative;
  z-index: var(--z-sticky);
  padding: 28rpx;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.profile-card__main {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
}

.profile-card__left {
  display: flex;
  flex: 1;
  gap: 20rpx;
  align-items: center;
  min-width: 0;
}

.profile-card__avatar {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 100rpx;
  height: 100rpx;
  background: var(--color-primary-soft);
  border-radius: 50%;
}

.profile-card__avatar-text {
  font-size: 38rpx;
  font-weight: 600;
  color: var(--color-primary);
}

.profile-card__info {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 8rpx;
  min-width: 0;
}

.profile-card__name {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text);
  white-space: nowrap;
}

.profile-card__sub {
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 24rpx;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.profile-card__action {
  display: flex;
  flex-shrink: 0;
  gap: 4rpx;
  align-items: center;
}

.profile-card__action-text {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.profile-card__stats {
  display: flex;
  align-items: center;
  padding-top: 24rpx;
  margin-top: 24rpx;
  border-top: 1px solid var(--color-border);
}

.stat-item {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 6rpx;
  align-items: center;
  min-width: 0;
}

.stat-item__value {
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text);
  white-space: nowrap;
}

.stat-item__label {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.stat-divider {
  width: 1px;
  height: 44rpx;
  background: var(--color-border);
}
</style>
