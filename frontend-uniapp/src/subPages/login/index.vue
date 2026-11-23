<template>
  <app-page-shell title="账号登录" :show-home="false">
    <template v-if="initialLoading">
      <view class="login-header">
        <wd-skeleton
          animation="gradient"
          :row-col="[{ type: 'rect', width: '48px', height: '48px', borderRadius: '12px' }]"
        />
        <view class="login-sk-title">
          <wd-skeleton
            animation="gradient"
            :row-col="[
              { width: '96px', height: '20px', margin: '0 auto' },
              { width: '210px', height: '13px', margin: '0 auto' },
            ]"
          />
        </view>
      </view>

      <view class="login-card login-sk-card">
        <wd-skeleton
          animation="gradient"
          :row-col="[
            [
              { width: '44%', height: '20px' },
              { width: '44%', height: '20px' },
            ],
            { width: '100%', height: '44px', borderRadius: '10px' },
            { width: '100%', height: '44px', borderRadius: '10px' },
            { width: '100%', height: '42px', borderRadius: '10px' },
          ]"
        />
      </view>

      <view class="guest-link">
        <wd-skeleton animation="gradient" :row-col="[{ width: '140px', height: '16px' }]" />
      </view>
    </template>

    <template v-else>
      <view class="login-header">
        <view class="login-logo">
          <app-icon name="book" size="28" color="#ffffff" />
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

          <view class="grade-field">
            <view class="grade-field__head">
              <text class="grade-field__label">所在年级</text>
              <text class="grade-field__req">* 必选</text>
            </view>
            <view class="grade-grid">
              <view
                v-for="g in gradeOptions"
                :key="g.gradeCode"
                class="grade-chip"
                :class="{ 'grade-chip--active': registerForm.gradeCode === g.gradeCode }"
                @click="registerForm.gradeCode = g.gradeCode"
              >
                <text class="grade-chip__name">{{ g.gradeName }}</text>
              </view>
            </view>
          </view>

          <text class="register-note">
            {{
              selectedGradeName
                ? `已选「${selectedGradeName}」，将自动匹配初始境界，全境界题目均开放自由学习`
                : "请先选择当前所在年级，全境界题目均开放自由研习"
            }}
          </text>

          <view class="form-submit">
            <wd-button type="primary" block :loading="submitting" @click="handleRegister">
              完成注册
            </wd-button>
          </view>
        </view>
      </view>

      <view class="guest-link">
        <wd-button variant="text" @click="goHome">暂不登录，游客试玩</wd-button>
      </view>
    </template>
  </app-page-shell>
</template>

<script setup lang="ts">
import { onLoad } from "@dcloudio/uni-app";
import { useUserStore } from "@/store";
import type { GradeItem } from "@/types/guoguanla";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "login",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "账号登录",
  },
});

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

const initialLoading = ref(false);
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
  gradeCode: "",
});

const gradeOptions = computed<GradeItem[]>(() => {
  const list = userStore.homeSummary?.grades;
  return list && list.length > 0 ? list : FALLBACK_GRADES;
});

const selectedGradeName = computed(() => {
  const found = gradeOptions.value.find((g) => g.gradeCode === registerForm.gradeCode);
  return found?.gradeName || "";
});

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

function goHome(): void {
  uni.switchTab({ url: "/pages/index/index" });
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
      // Fallback to static grade options
    } finally {
      initialLoading.value = false;
    }
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

.login-sk-title {
  margin-top: 20rpx;
}

.login-sk-card {
  padding: 28rpx 24rpx 32rpx;
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

.grade-field {
  padding: 22rpx 8rpx 4rpx;
}

.grade-field__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14rpx;
}

.grade-field__label {
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-text);
}

.grade-field__req {
  font-size: 22rpx;
  color: var(--color-danger);
}

.grade-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12rpx;
}

.grade-chip {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 68rpx;
  background: var(--color-bg-page);
  border: 2rpx solid var(--color-border);
  border-radius: 14rpx;
  transition: all 0.15s ease;

  &--active {
    background: var(--color-primary-soft);
    border-color: var(--color-primary);

    .grade-chip__name {
      font-weight: 600;
      color: var(--color-primary);
    }
  }
}

.grade-chip__name {
  font-size: 26rpx;
  color: var(--color-text);
}

.register-note {
  display: block;
  padding: 18rpx 8rpx 0;
  font-size: 23rpx;
  line-height: 1.45;
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
