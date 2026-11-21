<template>
  <view class="profile-page">
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

    <view class="submit-wrap">
      <wd-button type="primary" block :loading="saving" @click="handleSave">
        保存昵称
      </wd-button>
    </view>
  </view>
</template>

<script setup lang="ts">
import { onLoad } from "@dcloudio/uni-app";
import { useUserStore } from "@/store";
import { ensureAuthenticated } from "@/utils/auth";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "profile",
  style: {
    navigationBarTitleText: "个人资料",
  },
});

const userStore = useUserStore();
const toast = useToast();
const saving = ref(false);
const nickname = ref("");

async function handleSave(): Promise<void> {
  if (!nickname.value.trim()) {
    toast.warning("昵称不能为空");
    return;
  }
  saving.value = true;
  try {
    await userStore.updateProfile({ nickname: nickname.value.trim() });
    toast.success("已保存");
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
.profile-page {
  min-height: 100vh;
  padding: 24rpx;
  background: var(--color-bg-page);
}

.profile-card {
  overflow: hidden;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.submit-wrap {
  margin-top: 32rpx;
}
</style>
