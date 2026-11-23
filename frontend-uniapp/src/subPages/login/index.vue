<template>
  <app-page-shell title="" :show-back="false" :show-home="false" :flush="true">
    <template #header>
      <view class="auth-topbar" :style="{ paddingTop: statusBarHeight + 'px' }">
        <view v-if="canGoBack" class="auth-back-btn" @click="goBack">
          <app-icon name="back" :size="20" color="text" />
        </view>
      </view>
    </template>

    <view class="auth-page">
      <!-- 骨架屏 -->
      <view v-if="initialLoading" class="auth-skeleton">
        <wd-skeleton
          animation="gradient"
          :row-col="[
            [{ width: '64px', height: '64px' }],
            [{ width: '56%', height: '24px' }],
            [{ width: '68%', height: '14px' }],
            [{ width: '100%', height: '42px' }],
            [{ width: '100%', height: '108px' }],
            [{ width: '100%', height: '44px', borderRadius: '6px' }],
          ]"
        />
      </view>

      <template v-else>
        <!-- 顶部品牌区 -->
        <view class="brand-header">
          <view class="brand-logo">
            <app-icon name="flag" :size="30" color="#ffffff" />
          </view>
          <text class="brand-title">欢迎来到过关啦</text>
          <text class="brand-sub">趣味闯关 + 视频课堂，每天进步一点</text>
        </view>

        <!-- 分段切换器（登录 / 注册） -->
        <view class="segmented-bar">
          <view
            class="segmented-item"
            :class="{ 'segmented-item--active': authMode === 'login' }"
            @click="authMode = 'login'"
          >
            <text class="segmented-item__text">登录</text>
          </view>
          <view
            class="segmented-item"
            :class="{ 'segmented-item--active': authMode === 'register' }"
            @click="authMode = 'register'"
          >
            <text class="segmented-item__text">注册</text>
          </view>
        </view>

        <!-- 登录表单 -->
        <template v-if="authMode === 'login'">
          <view class="cell-card">
            <view class="cell-row">
              <text class="cell-label">用户名</text>
              <input
                v-model="loginForm.account"
                class="cell-input"
                placeholder="请输入用户名"
                placeholder-class="cell-placeholder"
                :maxlength="32"
              />
            </view>
            <view class="cell-divider" />
            <view class="cell-row">
              <text class="cell-label">密码</text>
              <input
                v-model="loginForm.password"
                :password="!showLoginPwd"
                class="cell-input"
                placeholder="请输入密码"
                placeholder-class="cell-placeholder"
                :maxlength="32"
                @confirm="handleLogin"
              />
              <view class="eye-toggle" @click="showLoginPwd = !showLoginPwd">
                <app-icon :name="showLoginPwd ? 'eye' : 'eye-off'" :size="18" color="muted" />
              </view>
            </view>
          </view>

          <view class="login-helper-row">
            <view class="remember-wrap" @click="rememberAccount = !rememberAccount">
              <view class="checkbox-box" :class="{ 'checkbox-box--checked': rememberAccount }">
                <app-icon v-if="rememberAccount" name="check" :size="12" color="#ffffff" />
              </view>
              <text class="remember-text">记住用户名</text>
            </view>
            <text class="forgot-link" @click="handleForgotPassword">忘记密码？</text>
          </view>

          <view class="submit-action">
            <wd-button
              type="primary"
              size="large"
              block
              :loading="submitting"
              @click="handleLogin"
            >
              {{ submitting ? "正在登录..." : "登录" }}
            </wd-button>
          </view>
        </template>

        <!-- 注册表单（必填年级，无任何预设体验账号） -->
        <template v-else>
          <view class="cell-card">
            <view class="cell-row">
              <view class="cell-label-req">
                <text class="cell-label-req__text">用户名</text>
                <text class="cell-label-req__star">*</text>
              </view>
              <input
                v-model="registerForm.username"
                class="cell-input"
                placeholder="3~16 位字母或数字"
                placeholder-class="cell-placeholder"
                :maxlength="16"
              />
            </view>
            <view class="cell-divider" />
            <view class="cell-row">
              <view class="cell-label-req">
                <text class="cell-label-req__text">昵称</text>
                <text class="cell-label-req__star">*</text>
              </view>
              <input
                v-model="registerForm.nickname"
                class="cell-input"
                placeholder="闯关时显示的名字"
                placeholder-class="cell-placeholder"
                :maxlength="24"
              />
            </view>
            <view class="cell-divider" />
            <view class="cell-row">
              <view class="cell-label-req">
                <text class="cell-label-req__text">密码</text>
                <text class="cell-label-req__star">*</text>
              </view>
              <input
                v-model="registerForm.password"
                :password="!showRegisterPwd"
                class="cell-input"
                placeholder="至少 6 位"
                placeholder-class="cell-placeholder"
                :maxlength="32"
              />
              <view class="eye-toggle" @click="showRegisterPwd = !showRegisterPwd">
                <app-icon :name="showRegisterPwd ? 'eye' : 'eye-off'" :size="18" color="muted" />
              </view>
            </view>
          </view>

          <view class="grade-card">
            <view class="grade-card__head">
              <text class="grade-card__label">所在年级</text>
              <text class="grade-card__star">*</text>
            </view>
            <view class="grade-grid">
              <view
                v-for="item in gradeOptions"
                :key="item.gradeCode"
                class="grade-pill"
                :class="{ 'grade-pill--active': registerForm.gradeCode === item.gradeCode }"
                @click="registerForm.gradeCode = item.gradeCode"
              >
                <text class="grade-pill__text">{{ item.gradeName }}</text>
              </view>
            </view>
          </view>

          <view class="submit-action">
            <wd-button
              type="primary"
              size="large"
              block
              :loading="submitting"
              @click="handleRegister"
            >
              {{ submitting ? "正在注册..." : "注册" }}
            </wd-button>
          </view>
        </template>

        <!-- 底部游客试玩入口 -->
        <view class="guest-footer">
          <text class="guest-footer__link" @click="goHome">先逛逛，游客试玩</text>
          <text class="guest-footer__legal">登录即表示同意《用户协议》与《隐私政策》</text>
        </view>
      </template>
    </view>
  </app-page-shell>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from "vue";
import { onLoad } from "@dcloudio/uni-app";
import { useToast } from "@wot-ui/ui";
import { useNavbarMetrics } from "@/composables/useNavbarMetrics";
import { useUserStore } from "@/store";
import type { GradeItem } from "@/types/guoguanla";
import { getErrorMessage } from "@/utils/error";
import { Storage } from "@/utils/storage";

definePage({
  name: "login",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "账号登录",
  },
});

const REMEMBERED_ACCOUNT_KEY = "ggl_remembered_account";

const TAB_PAGES = [
  "/pages/index/index",
  "/pages/cultivate/index",
  "/pages/wrong/index",
  "/pages/mine/index",
];

const FALLBACK_GRADES: GradeItem[] = [
  { gradeCode: "g7", gradeName: "初一", icon: "🌱", chapterCount: 10 },
  { gradeCode: "g8", gradeName: "初二", icon: "🌿", chapterCount: 10 },
  { gradeCode: "g9", gradeName: "初三", icon: "🌳", chapterCount: 9 },
  { gradeCode: "h1", gradeName: "高一", icon: "🍃", chapterCount: 10 },
  { gradeCode: "h2", gradeName: "高二", icon: "🌲", chapterCount: 8 },
  { gradeCode: "h3", gradeName: "高三", icon: "🎯", chapterCount: 4 },
];

const userStore = useUserStore();
const toast = useToast();
const { statusBarHeight } = useNavbarMetrics();

const initialLoading = ref(false);
const authMode = ref<"login" | "register">("login");
const redirectUrl = ref("");
const submitting = ref(false);
const showLoginPwd = ref(false);
const showRegisterPwd = ref(false);
const rememberAccount = ref(true);

const savedAccount = Storage.get<string>(REMEMBERED_ACCOUNT_KEY, "");
const loginForm = reactive({
  account: savedAccount || "",
  password: "",
});

const registerForm = reactive({
  username: "",
  nickname: "",
  password: "",
  gradeCode: "",
});

const canGoBack = computed(() => getCurrentPages().length > 1);

const gradeOptions = computed<GradeItem[]>(() => {
  const list = userStore.homeSummary?.grades;
  return list && list.length > 0 ? list : FALLBACK_GRADES;
});

function goBack(): void {
  if (getCurrentPages().length > 1) {
    uni.navigateBack();
  } else {
    goHome();
  }
}

function goHome(): void {
  uni.switchTab({ url: "/pages/index/index" });
}

function handleForgotPassword(): void {
  uni.showModal({
    title: "找回密码提示",
    content: "请联系教研或系统管理员在后台重置学生登录密码。",
    showCancel: false,
    confirmText: "知道了",
    confirmColor: "#0284C7",
  });
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
  const account = loginForm.account.trim();
  if (!account || !loginForm.password) {
    toast.warning("请输入账号和密码");
    return;
  }
  if (rememberAccount.value) {
    Storage.set(REMEMBERED_ACCOUNT_KEY, account);
  } else {
    Storage.remove(REMEMBERED_ACCOUNT_KEY);
  }
  submitting.value = true;
  try {
    await userStore.login({
      account,
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
  if (!registerForm.gradeCode) {
    toast.warning("请选择所在年级");
    return;
  }
  submitting.value = true;
  try {
    await userStore.register({
      username: registerForm.username.trim(),
      nickname: registerForm.nickname.trim(),
      password: registerForm.password,
      gradeCode: registerForm.gradeCode,
    });
    toast.success("注册成功");
    navigateAfterAuth();
  } catch (err) {
    toast.error(getErrorMessage(err, "注册失败"));
  } finally {
    submitting.value = false;
  }
}

onLoad(async (query) => {
  if (query?.redirect) {
    redirectUrl.value = decodeURIComponent(query.redirect);
  }
  if (!userStore.homeSummary) {
    initialLoading.value = true;
    try {
      await userStore.loadHomeSummary(true);
    } catch {
      // Fallback grades remain usable offline
    } finally {
      initialLoading.value = false;
    }
  }
});
</script>

<style lang="scss" scoped>
.auth-topbar {
  display: flex;
  align-items: center;
  min-height: 72rpx;
  padding-right: 24rpx;
  padding-left: 24rpx;
  background-color: var(--color-bg-page);
}

.auth-back-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 64rpx;
  height: 64rpx;
}

.auth-page {
  padding: 20rpx 40rpx 64rpx;
}

.auth-skeleton {
  display: flex;
  flex-direction: column;
  gap: 28rpx;
  padding-top: 32rpx;
}

.brand-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 24rpx 0 48rpx;
  text-align: center;
}

.brand-logo {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 128rpx;
  height: 128rpx;
  background-color: var(--color-primary);
  border-radius: 32rpx;
}

.brand-title {
  margin-top: 32rpx;
  font-size: 44rpx;
  font-weight: 700;
  color: var(--color-text);
}

.brand-sub {
  margin-top: 12rpx;
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.segmented-bar {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  padding: 8rpx;
  background-color: var(--color-fill-2);
  border-radius: 16rpx;
}

.segmented-item {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 68rpx;
  border-radius: 12rpx;

  &--active {
    background-color: var(--color-bg-card);
    box-shadow: 0 2rpx 4rpx rgba(0, 0, 0, 0.08);
  }
}

.segmented-item__text {
  font-size: 28rpx;
  color: var(--color-text-muted);
}

.segmented-item--active .segmented-item__text {
  font-weight: 600;
  color: var(--color-text);
}

.cell-card {
  margin-top: 40rpx;
  overflow: hidden;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.cell-row {
  display: flex;
  gap: 20rpx;
  align-items: center;
  min-height: 96rpx;
  padding: 0 32rpx;
}

.cell-divider {
  height: 1px;
  margin: 0 32rpx;
  background-color: var(--color-border);
}

.cell-label {
  flex-shrink: 0;
  width: 128rpx;
  font-size: 28rpx;
  color: var(--color-text);
}

.cell-label-req {
  display: flex;
  flex-shrink: 0;
  gap: 4rpx;
  align-items: center;
  width: 128rpx;
}

.cell-label-req__text {
  font-size: 28rpx;
  color: var(--color-text);
}

.cell-label-req__star {
  font-size: 28rpx;
  color: var(--color-danger);
}

.cell-input {
  flex: 1;
  min-width: 0;
  height: 92rpx;
  font-size: 28rpx;
  color: var(--color-text);
}

:deep(.cell-placeholder) {
  font-size: 28rpx;
  color: var(--color-text-placeholder);
}

.eye-toggle {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 56rpx;
  height: 56rpx;
}

.login-helper-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 24rpx;
}

.remember-wrap {
  display: flex;
  gap: 14rpx;
  align-items: center;
}

.checkbox-box {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32rpx;
  height: 32rpx;
  background-color: var(--color-bg-card);
  border: 2rpx solid var(--color-border-strong);
  border-radius: 8rpx;

  &--checked {
    background-color: var(--color-primary);
    border-color: var(--color-primary);
  }
}

.remember-text {
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.forgot-link {
  font-size: 26rpx;
  color: var(--color-primary);
}

.grade-card {
  padding: 32rpx;
  margin-top: 24rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.grade-card__head {
  display: flex;
  gap: 6rpx;
  align-items: center;
  margin-bottom: 24rpx;
}

.grade-card__label {
  font-size: 28rpx;
  color: var(--color-text);
}

.grade-card__star {
  font-size: 28rpx;
  color: var(--color-danger);
}

.grade-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20rpx;
}

.grade-pill {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 72rpx;
  background-color: var(--color-bg-page);
  border: 1px solid transparent;
  border-radius: var(--radius-btn);

  &--active {
    background-color: var(--color-primary-soft);
    border-color: var(--color-primary-alpha-20);
  }
}

.grade-pill__text {
  font-size: 26rpx;
  color: var(--color-text-secondary);
}

.grade-pill--active .grade-pill__text {
  font-weight: 600;
  color: var(--color-primary);
}

.submit-action {
  margin-top: 48rpx;
}

.guest-footer {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
  align-items: center;
  margin-top: 48rpx;
  text-align: center;
}

.guest-footer__link {
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-primary);
}

.guest-footer__legal {
  font-size: 22rpx;
  color: var(--color-text-placeholder);
}
</style>
