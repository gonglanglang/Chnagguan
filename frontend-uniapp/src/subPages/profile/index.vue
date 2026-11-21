<template>
  <app-page-shell title="个人资料" :has-footer="true">
    <view class="avatar-card" @click="chooseAvatar">
      <view class="avatar-card__left">
        <view class="avatar-box">
          <image
            v-if="avatarPreview"
            :src="avatarPreview"
            mode="aspectFill"
            class="avatar-box__img"
          />
          <text v-else class="avatar-box__text">{{ avatarLetter }}</text>
        </view>
        <view class="avatar-card__info">
          <text class="avatar-card__title">个人头像</text>
          <text class="avatar-card__sub">点击可从相册选择或拍照更换头像</text>
        </view>
      </view>
      <view class="avatar-card__right">
        <text class="avatar-card__action">{{ uploadingAvatar ? "上传中..." : "更换" }}</text>
        <wd-icon name="right" size="14" color="var(--color-text-muted)" />
      </view>
    </view>

    <view class="profile-card">
      <wd-cell-group border>
        <wd-cell title="用户名" :value="userStore.userInfo?.username || '--'" />
        <wd-cell
          title="当前修仙境界"
          :value="userStore.userInfo?.realmName || '练气'"
          label="境界由进阶考核或管理员调整，不可自行更改"
        />
        <wd-input
          v-model="nickname"
          label="昵称"
          label-width="140rpx"
          clearable
          placeholder="请输入学生昵称"
        />
      </wd-cell-group>
    </view>

    <template #footer>
      <wd-button
        type="primary"
        block
        :loading="saving"
        :disabled="uploadingAvatar"
        @click="handleSave"
      >
        保存资料
      </wd-button>
    </template>
  </app-page-shell>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { onLoad } from "@dcloudio/uni-app";
import { useUserStore } from "@/store";
import { ensureAuthenticated } from "@/utils/auth";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "profile",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "个人资料",
  },
});

const userStore = useUserStore();
const toast = useToast();
const saving = ref(false);
const uploadingAvatar = ref(false);
const nickname = ref("");

const avatarPreview = computed(() => userStore.userInfo?.avatarUrl || "");
const avatarLetter = computed(() => {
  const s = nickname.value || userStore.userInfo?.nickname || userStore.userInfo?.username || "修";
  return s.slice(0, 1).toUpperCase();
});

function chooseAvatar(): void {
  if (uploadingAvatar.value) return;
  uni.chooseImage({
    count: 1,
    sizeType: ["compressed"],
    sourceType: ["album", "camera"],
    success: async (res) => {
      const filePath = res.tempFilePaths?.[0];
      if (!filePath) return;
      uploadingAvatar.value = true;
      try {
        await userStore.uploadAvatar(filePath);
        toast.success("头像已更新");
      } catch (err) {
        toast.error(getErrorMessage(err, "头像上传失败"));
      } finally {
        uploadingAvatar.value = false;
      }
    },
  });
}

async function handleSave(): Promise<void> {
  if (!nickname.value.trim()) {
    toast.warning("昵称不能为空");
    return;
  }
  saving.value = true;
  try {
    await userStore.updateProfile({ nickname: nickname.value.trim() });
    toast.success("资料已保存");
    setTimeout(() => {
      uni.navigateBack();
    }, 350);
  } catch (err) {
    toast.error(getErrorMessage(err, "保存失败"));
  } finally {
    saving.value = false;
  }
}

onLoad(async () => {
  if (!ensureAuthenticated()) return;
  try {
    const profile = await userStore.loadUserInfo(true);
    nickname.value = profile.nickname || "";
  } catch {
    nickname.value = userStore.userInfo?.nickname || "";
  }
});
</script>

<style lang="scss" scoped>
.avatar-card {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
  padding: 24rpx 28rpx;
  margin-bottom: 20rpx;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.avatar-card__left {
  display: flex;
  flex: 1;
  gap: 20rpx;
  align-items: center;
  min-width: 0;
}

.avatar-box {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 108rpx;
  height: 108rpx;
  overflow: hidden;
  background: var(--color-primary-soft);
  border-radius: 50%;
}

.avatar-box__img {
  width: 100%;
  height: 100%;
}

.avatar-box__text {
  font-size: 40rpx;
  font-weight: 600;
  color: var(--color-primary);
}

.avatar-card__info {
  display: flex;
  flex-direction: column;
  gap: 6rpx;
}

.avatar-card__title {
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text);
}

.avatar-card__sub {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.avatar-card__right {
  display: flex;
  flex-shrink: 0;
  gap: 6rpx;
  align-items: center;
}

.avatar-card__action {
  font-size: 26rpx;
  color: var(--color-primary);
}

.profile-card {
  overflow: hidden;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}
</style>
