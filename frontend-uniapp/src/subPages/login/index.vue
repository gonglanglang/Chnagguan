<template>
  <app-page-shell title="账号登录" :show-home="false">
    <view class="login-header">
      <view class="login-logo">
        <wd-icon name="book" size="28" color="#ffffff" />
      </view>
      <text class="login-title">过关啦</text>
      <text class="login-subtitle">登录后保存修仙境界、通关记录与错题本</text>
    </view>

    <view class="login-card">
      <wd-tabs v-model="authMode">
        <wd-tab name="login" title="账号登录" />
        <wd-tab name="register" title="拜师入门（注册）" />
      </wd-tabs>

      <view v-if="authMode === 'login'" class="form-body">
        <wd-cell-group border>
          <wd-input
            v-model="loginForm.account"
            label="账号"
            label-width="120rpx"
            clearable
            placeholder="请输入学生用户名"
          />
          <wd-input
            v-model="loginForm.password"
            label="密码"
            label-width="120rpx"
            show-password
            clearable
            placeholder="请输入密码"
            @confirm="handleLogin"
          />
        </wd-cell-group>

        <view class="demo-accounts">
          <text class="demo-accounts__label">快捷体验账号（点击填入）：</text>
          <view class="demo-accounts__row">
            <text class="demo-chip" @click="fillDemo('stu_linxiaoyu')">练气 · 林小雨</text>
            <text class="demo-chip" @click="fillDemo('stu_chenziyu')">筑基 · 陈子轩</text>
          </view>
        </view>

        <view class="form-submit">
          <wd-button type="primary" block :loading="submitting" @click="handleLogin">
            登录
          </wd-button>
        </view>
      </view>

      <view v-else class="form-body">
        <wd-cell-group border>
          <wd-input
            v-model="registerForm.username"
            label="用户名"
            label-width="120rpx"
            clearable
            placeholder="3-32位字母或数字"
          />
          <wd-input
            v-model="registerForm.nickname"
            label="昵称"
            label-width="120rpx"
            clearable
            placeholder="请输入昵称"
          />
          <wd-input
            v-model="registerForm.password"
            label="密码"
            label-width="120rpx"
            show-password
            clearable
            placeholder="至少6位密码"
          />
        </wd-cell-group>

        <text class="register-note">新注册账号统一从「练气」境界开启修炼</text>

        <view class="form-submit">
          <wd-button type="primary" block :loading="submitting" @click="handleRegister">
            注册并进入练气
          </wd-button>
        </view>
      </view>
    </view>

    <view class="guest-link">
      <wd-button variant="text" @click="goHome">暂不登录，先试玩练气关卡</wd-button>
    </view>
  </app-page-shell>
</template>

<script setup lang="ts">
import { onLoad } from "@dcloudio/uni-app";
import { useUserStore } from "@/store";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "login",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "账号登录",
  },
});

const TAB_PAGES = ["/pages/index/index", "/pages/wrong/index", "/pages/mine/index"];

const userStore = useUserStore();
const toast = useToast();

const authMode = ref<"login" | "register">("login");
const redirectUrl = ref("");
const submitting = ref(false);

const loginForm = reactive({
  account: "",
  password: "",
});

const registerForm = reactive({
  username: "",
  nickname: "",
  password: "",
});

function fillDemo(account: string): void {
  loginForm.account = account;
  loginForm.password = "123456";
}

function navigateAfterAuth(): void {
  const target = redirectUrl.value;
  if (target && TAB_PAGES.some((tab) => target.startsWith(tab))) {
    uni.switchTab({ url: target.split("?")[0] });
    return;
  }
  if (target) {
    uni.redirectTo({
      url: target,
      fail: () => uni.switchTab({ url: "/pages/index/index" }),
    });
    return;
  }
  const pages = getCurrentPages();
  if (pages.length > 1) {
    uni.navigateBack();
  } else {
    uni.switchTab({ url: "/pages/index/index" });
  }
}

async function handleLogin(): Promise<void> {
  if (!loginForm.account.trim() || !loginForm.password) {
    toast.warning("请输入账号和密码");
    return;
  }
  submitting.value = true;
  try {
    await userStore.login({
      account: loginForm.account.trim(),
      password: loginForm.password,
    });
    toast.success("登录成功");
    navigateAfterAuth();
  } catch (err) {
    toast.error(getErrorMessage(err, "登录失败"));
  } finally {
    submitting.value = false;
  }
}

async function handleRegister(): Promise<void> {
  if (registerForm.username.trim().length < 3) {
    toast.warning("用户名长度至少为 3 位");
    return;
  }
  if (!registerForm.nickname.trim()) {
    toast.warning("请输入昵称");
    return;
  }
  if (registerForm.password.length < 6) {
    toast.warning("密码长度至少为 6 位");
    return;
  }
  submitting.value = true;
  try {
    await userStore.register({
      username: registerForm.username.trim(),
      nickname: registerForm.nickname.trim(),
      password: registerForm.password,
    });
    toast.success("注册成功");
    navigateAfterAuth();
  } catch (err) {
    toast.error(getErrorMessage(err, "注册失败"));
  } finally {
    submitting.value = false;
  }
}

function goHome(): void {
  uni.switchTab({ url: "/pages/index/index" });
}

onLoad((query) => {
  if (query?.redirect) {
    redirectUrl.value = decodeURIComponent(query.redirect);
  }
});
</script>

<style lang="scss" scoped>
.login-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-top: 20rpx;
  margin-bottom: 36rpx;
}

.login-logo {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 96rpx;
  height: 96rpx;
  background: var(--color-primary);
  border-radius: 24rpx;
}

.login-title {
  margin-top: 20rpx;
  font-size: 40rpx;
  font-weight: 600;
  color: var(--color-text);
}

.login-subtitle {
  margin-top: 8rpx;
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.login-card {
  overflow: hidden;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.form-body {
  padding: 20rpx 24rpx 32rpx;
}

.demo-accounts {
  padding: 20rpx 8rpx 4rpx;
}

.demo-accounts__label {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.demo-accounts__row {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  margin-top: 10rpx;
}

.demo-chip {
  padding: 8rpx 18rpx;
  font-size: 23rpx;
  color: var(--color-primary);
  background: var(--color-primary-soft);
  border-radius: 999rpx;
}

.register-note {
  display: block;
  padding: 18rpx 8rpx 0;
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.form-submit {
  margin-top: 28rpx;
}

.guest-link {
  display: flex;
  justify-content: center;
  margin-top: 28rpx;
}
</style>
