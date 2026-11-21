<template>
  <app-page-shell :has-footer="hasFooterBar">
    <template #header>
      <app-navbar
        :title="navbarTitle"
        :show-back="false"
        :show-home="false"
        :fixed="false"
        :placeholder="false"
      >
        <template #left>
          <view class="nav-exit-btn" @click="handleExit">
            <wd-icon name="arrow-left" size="18" color="var(--color-text)" />
            <text class="nav-exit-text">{{ submitResult ? "返回" : "退出" }}</text>
          </view>
        </template>
      </app-navbar>
    </template>

    <view v-if="loading" class="state-box">
      <wd-loading />
      <text class="state-box__text">正在抽取题目...</text>
    </view>

    <view v-else-if="loadError" class="state-box">
      <wd-empty icon="no-content" :tip="loadError" />
      <view class="state-box__actions">
        <wd-button size="small" variant="plain" @click="goBack">返回</wd-button>
        <wd-button size="small" type="primary" @click="initQuiz">重试</wd-button>
      </view>
    </view>

    <!-- 答题视图 -->
    <template v-else-if="startData && !submitResult && currentItem">
      <view class="progress-card">
        <view class="progress-card__top">
          <text class="progress-card__step">
            第 {{ currentIdx + 1 }} / {{ startData.items.length }} 题
          </text>
          <view class="progress-card__tags">
            <wd-tag
              v-if="currentItem.questionFormat === 'ESSAY'"
              type="success"
              variant="light"
              size="small"
            >
              解答题
            </wd-tag>
            <wd-tag v-if="startData.suppressedMode" type="warning" variant="light" size="small">
              压制境界
            </wd-tag>
            <wd-tag type="primary" variant="light" size="small">
              <template v-if="startData.mode === 'ADVANCE_EXAM'">
                {{ startData.passScore ?? 60 }} 分进阶
              </template>
              <template v-else-if="startData.mode === 'WRONG_REDO'">
                答对即掌握
              </template>
              <template v-else>
                答对 {{ startData.passCount }} 题过关
              </template>
            </wd-tag>
          </view>
        </view>
        <wd-progress :percentage="progressPercent" hide-text />
      </view>

      <view class="question-card">
        <view class="question-card__meta">
          <wd-tag variant="light" size="small">
            {{ startData.realmName || "修炼答题" }}
          </wd-tag>
          <text v-if="startData.chapterName" class="question-card__chapter">
            {{ startData.chapterName }}
          </text>
        </view>
        <view class="question-card__stem">
          <math-text :key="`${startData.sessionNo}-${currentItem.itemIndex}-stem`" :text="currentItem.stem" />
        </view>
      </view>

      <!-- 解答题作答展示区（交由管理员在后台批改，取消学生自评） -->
      <template v-if="isCurrentEssay">
        <view v-if="currentFeedback" class="essay-saved-card">
          <view class="essay-saved-card__head">
            <text class="essay-saved-card__title">我的已保存作答</text>
            <wd-tag type="warning" variant="light" size="small">待老师批改</wd-tag>
          </view>
          <view v-if="currentFeedback.answerText" class="essay-saved-card__text">
            文字作答：{{ currentFeedback.answerText }}
          </view>
          <view v-if="currentFeedback.answerImageUrl" class="essay-saved-card__img-wrap">
            <image
              :src="currentFeedback.answerImageUrl"
              mode="aspectFit"
              class="essay-saved-card__img"
              @click="previewImage(currentFeedback.answerImageUrl)"
            />
          </view>
          <view class="essay-pending-banner">
            <wd-icon name="time" size="16" color="#d97706" />
            <text class="essay-pending-banner__text">作答已提交至云端，等待老师批改点评</text>
          </view>
        </view>
      </template>

      <!-- 选择题作答区 -->
      <template v-else>
          <view class="options-list">
            <view
              v-for="(opt, idx) in currentItem.options"
              :key="idx"
              class="option-row"
              :class="getOptionClass(idx)"
              @click="handleSelectOption(idx)"
            >
              <view class="option-row__badge">{{ LETTERS[idx] || idx + 1 }}</view>
              <view class="option-row__text">
                <math-text
                  :key="`${startData.sessionNo}-${currentItem.itemIndex}-op-${idx}`"
                  :text="opt"
                  inline
                />
              </view>
              <view class="option-row__status">
                <wd-icon
                  v-if="currentFeedback && idx === currentFeedback.correctIndex"
                  name="check-circle-fill"
                  size="18"
                  color="#16a34a"
                />
                <wd-icon
                  v-else-if="
                    currentFeedback &&
                    idx === currentSelected &&
                    !currentFeedback.correct
                  "
                  name="close-circle-fill"
                  size="18"
                  color="#ef4444"
                />
              </view>
            </view>
          </view>

          <view
            v-if="currentFeedback"
            class="feedback-card"
            :class="currentFeedback.correct ? 'feedback-card--pass' : 'feedback-card--fail'"
          >
            <view class="feedback-card__head">
              <wd-icon
                :name="currentFeedback.correct ? 'check-circle-fill' : 'close-circle-fill'"
                size="18"
                :color="currentFeedback.correct ? '#16a34a' : '#ef4444'"
              />
              <text class="feedback-card__title">
                {{ currentFeedback.correct ? "回答正确" : "回答有误" }}
              </text>
            </view>
            <view class="feedback-card__ans">
              正确答案：{{ LETTERS[currentFeedback.correctIndex] || currentFeedback.correctIndex + 1 }}.
              <math-text :text="currentItem.options[currentFeedback.correctIndex] || ''" inline />
            </view>
            <view v-if="currentFeedback.analysis" class="feedback-card__analysis">
              <math-text :text="currentFeedback.analysis" />
            </view>
          </view>
      </template>
    </template>

    <!-- 结算结果视图 -->
    <template v-else-if="submitResult">
      <view class="result-card">
        <view
          class="result-card__icon"
          :class="submitResult.passed ? 'result-card__icon--pass' : 'result-card__icon--retry'"
        >
          <wd-icon
            :name="submitResult.passed ? 'check-circle-fill' : 'info-circle'"
            size="40"
            :color="submitResult.passed ? '#16a34a' : '#f59e0b'"
          />
        </view>

        <text class="result-card__title">
          <template v-if="!submitResult.passed && (submitResult.pendingReviewCount || 0) > 0">
            答卷已提交 · 待老师批改
          </template>
          <template v-else-if="submitResult.mode === 'ADVANCE_EXAM'">
            {{ submitResult.passed ? "进阶成功" : "进阶未通过" }}
          </template>
          <template v-else-if="submitResult.mode === 'WRONG_REDO'">错题重做完成</template>
          <template v-else>{{ submitResult.passed ? "本关通过" : "暂未过关" }}</template>
        </text>

        <text class="result-card__score">
          <template v-if="submitResult.mode === 'ADVANCE_EXAM'">
            得分 {{ submitResult.score ?? 0 }} 分（及格线 {{ submitResult.passScore ?? 60 }} 分 · 答对 {{ submitResult.correctCount }}/{{ submitResult.totalCount }} 题）
          </template>
          <template v-else>
            答对 {{ submitResult.correctCount }} / {{ submitResult.totalCount }} 题
          </template>
        </text>

        <text
          v-if="(submitResult.pendingReviewCount || 0) > 0"
          class="result-card__desc"
        >
          其中 {{ submitResult.pendingReviewCount }} 道解答题已提交云端，待老师在后台批改后自动同步成绩与过关状态
        </text>
        <text v-else-if="submitResult.mode === 'WRONG_REDO'" class="result-card__desc">
          本次新掌握 {{ submitResult.masteredCount }} 道错题
        </text>
        <text v-else-if="submitResult.mode === 'ADVANCE_EXAM'" class="result-card__desc">
          {{
            submitResult.passed
              ? "实力达标，已正式突破当前境界"
              : "尚差少许火候，巩固错题后可再次发起考核"
          }}
        </text>
        <text v-else class="result-card__desc">
          {{
            submitResult.newlyPassed
              ? "首次通关成功，已解锁下一关卡"
              : submitResult.passed
                ? "巩固练习完成"
                : `本关需答对 ${submitResult.passCount} 题，整理思路再试`
          }}
        </text>

        <view v-if="submitResult.promotedRealm" class="promote-banner">
          <wd-icon name="trophy" size="18" color="var(--color-primary)" />
          <text class="promote-banner__text">
            恭喜突破至「{{ submitResult.promotedRealm.realmName }}」境界
          </text>
        </view>
      </view>

      <view v-if="submitResult.wrongItems && submitResult.wrongItems.length > 0" class="review-box">
        <text class="review-box__title">错题复盘（{{ submitResult.wrongItems.length }}）</text>
        <view
          v-for="(item, idx) in submitResult.wrongItems"
          :key="idx"
          class="review-card"
        >
          <view class="review-card__stem">
            <math-text :text="item.stem" />
          </view>
          <view class="review-card__ans">
            参考答案：<math-text :text="item.correctAnswer || '见解析'" inline />
          </view>
          <view v-if="item.analysis" class="review-card__analysis">
            <math-text :text="item.analysis" />
          </view>
        </view>
      </view>
    </template>

    <template #footer>
      <template v-if="startData && !submitResult && currentItem">
        <wd-button
          v-if="isCurrentEssay && !currentFeedback"
          type="primary"
          block
          @click="openLandscapeDraw"
        >
          开始作答
        </wd-button>
        <wd-button
          v-else-if="currentIdx < startData.items.length - 1"
          type="primary"
          block
          :disabled="!canGoNext || checking"
          @click="nextQuestion"
        >
          下一题
        </wd-button>
        <wd-button
          v-else
          type="primary"
          block
          :loading="submitting"
          :disabled="!canGoNext || checking"
          @click="handleSubmit"
        >
          提交交卷
        </wd-button>
      </template>

      <view v-else-if="submitResult" class="result-actions">
        <wd-button variant="plain" block @click="goBack">返回</wd-button>
        <wd-button
          v-if="submitResult.mode === 'GATE' || (submitResult.mode === 'ADVANCE_EXAM' && !submitResult.passed)"
          type="primary"
          block
          @click="initQuiz"
        >
          {{ submitResult.passed ? "再练一次" : "重新挑战" }}
        </wd-button>
      </view>
    </template>
  </app-page-shell>
</template>

<script setup lang="ts">
import { onLoad, onShow, onUnload } from "@dcloudio/uni-app";
import { AppQuizAPI, AppRealmExamAPI, AppWrongAPI, type AnswerSubmitPayload } from "@/api/guoguanla";
import { useUserStore } from "@/store";
import type { CheckItemResult, QuizStartResult, SubmitResult } from "@/types/guoguanla";
import { getGuestPassedIds } from "@/utils/auth";
import { getErrorMessage } from "@/utils/error";
import { lockPortraitOrientation } from "@/utils/orientation";

definePage({
  name: "quiz",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "修炼答题",
  },
});

const LETTERS = ["A", "B", "C", "D", "E", "F"];
const userStore = useUserStore();
const toast = useToast();

const mode = ref<"GATE" | "WRONG_REDO" | "ADVANCE_EXAM">("GATE");
const gateId = ref<number | undefined>();
const realmCode = ref<string | undefined>();
const chapterId = ref<number | undefined>();

const loading = ref(true);
const loadError = ref("");
const checking = ref(false);
const submitting = ref(false);

const startData = ref<QuizStartResult | null>(null);
const currentIdx = ref(0);
const selectedMap = ref<Record<number, number>>({});
const essayTextMap = ref<Record<number, string>>({});
const essayImageKeyMap = ref<Record<number, string>>({});
const feedbackMap = ref<Record<number, CheckItemResult>>({});
const submitResult = ref<SubmitResult | null>(null);

const ACTIVE_ESSAY_PROMPT_KEY = "ggl_active_essay_prompt";

interface EssayDrawSavedPayload {
  sessionNo: string;
  itemIndex: number;
  answerImageKey: string;
  answerText: string;
  feedback: CheckItemResult;
}

const currentItem = computed(() => startData.value?.items?.[currentIdx.value] ?? null);
const isCurrentEssay = computed(() => currentItem.value?.questionFormat === "ESSAY");

const currentSelected = computed(() => {
  if (!currentItem.value) return undefined;
  return selectedMap.value[currentItem.value.itemIndex];
});

const currentFeedback = computed(() => {
  if (!currentItem.value) return undefined;
  return feedbackMap.value[currentItem.value.itemIndex];
});

const canGoNext = computed(() => Boolean(currentFeedback.value));

const hasFooterBar = computed(() =>
  Boolean(
    !loading.value &&
      !loadError.value &&
      ((startData.value && !submitResult.value && currentItem.value) || submitResult.value),
  ),
);

const progressPercent = computed(() => {
  const total = startData.value?.items?.length || 0;
  if (total === 0) return 0;
  return Math.min(100, Math.round(((currentIdx.value + 1) / total) * 100));
});

const navbarTitle = computed(() => {
  if (mode.value === "ADVANCE_EXAM") return "境界进阶考核";
  if (mode.value === "WRONG_REDO") return "错题重做";
  return startData.value?.gateName || "关卡挑战";
});

function getOptionClass(idx: number): string {
  const fb = currentFeedback.value;
  if (!fb) {
    return currentSelected.value === idx ? "option-row--selected" : "";
  }
  if (idx === fb.correctIndex) return "option-row--correct";
  if (idx === currentSelected.value && !fb.correct) return "option-row--wrong";
  return "option-row--dim";
}

function previewImage(url?: string): void {
  if (!url) return;
  uni.previewImage({ urls: [url] });
}

function openLandscapeDraw(): void {
  if (!startData.value || !currentItem.value) return;
  const sessionNo = startData.value.sessionNo;
  const itemIndex = currentItem.value.itemIndex;
  const stem = currentItem.value.stem || "";
  const answerText = (essayTextMap.value[itemIndex] || "").trim();

  uni.setStorageSync(ACTIVE_ESSAY_PROMPT_KEY, {
    sessionNo,
    itemIndex,
    stem,
    answerText,
  });

  const query = [
    `sessionNo=${encodeURIComponent(sessionNo)}`,
    `itemIndex=${itemIndex}`,
    `stem=${encodeURIComponent(stem)}`,
    `answerText=${encodeURIComponent(answerText)}`,
  ].join("&");
  uni.navigateTo({
    url: `/subPages/draw-answer/index?${query}`,
  });
}

function handleEssayDrawSaved(payload?: EssayDrawSavedPayload): void {
  if (!payload || !startData.value) return;
  if (payload.sessionNo !== startData.value.sessionNo) return;
  if (payload.answerText) {
    essayTextMap.value[payload.itemIndex] = payload.answerText;
  }
  if (payload.answerImageKey) {
    essayImageKeyMap.value[payload.itemIndex] = payload.answerImageKey;
  }
  feedbackMap.value[payload.itemIndex] = payload.feedback;
  toast.success("作答已上传云端，等待老师批改");
}

async function initQuiz(): Promise<void> {
  loading.value = true;
  loadError.value = "";
  submitResult.value = null;
  currentIdx.value = 0;
  selectedMap.value = {};
  essayTextMap.value = {};
  essayImageKeyMap.value = {};
  feedbackMap.value = {};

  try {
    if (mode.value === "ADVANCE_EXAM") {
      startData.value = await AppRealmExamAPI.start();
    } else if (mode.value === "WRONG_REDO") {
      startData.value = await AppWrongAPI.startRedo({
        realmCode: realmCode.value,
        chapterId: chapterId.value,
        limit: 5,
      });
    } else if (gateId.value) {
      startData.value = await AppQuizAPI.start({
        gateId: gateId.value,
        guestPassedGateIds: userStore.isAuthenticated ? undefined : getGuestPassedIds(),
      });
    } else {
      loadError.value = "缺少关卡参数";
    }
  } catch (err) {
    loadError.value = getErrorMessage(err, "出题失败，请稍后重试");
  } finally {
    loading.value = false;
  }
}

async function handleSelectOption(idx: number): Promise<void> {
  if (!startData.value || !currentItem.value) return;
  if (currentFeedback.value || checking.value) return;

  const itemIndex = currentItem.value.itemIndex;
  selectedMap.value[itemIndex] = idx;
  checking.value = true;

  try {
    const res = await AppQuizAPI.checkItem({
      sessionNo: startData.value.sessionNo,
      itemIndex,
      selectedIndex: idx,
    });
    feedbackMap.value[itemIndex] = res;
  } catch (err) {
    delete selectedMap.value[itemIndex];
    toast.error(getErrorMessage(err, "判题失败"));
  } finally {
    checking.value = false;
  }
}

function nextQuestion(): void {
  if (!startData.value) return;
  if (currentIdx.value < startData.value.items.length - 1) {
    currentIdx.value += 1;
  }
}

async function handleSubmit(): Promise<void> {
  if (!startData.value || submitting.value) return;
  const answers: AnswerSubmitPayload[] = startData.value.items.map((item) => {
    if (item.questionFormat === "ESSAY") {
      const fb = feedbackMap.value[item.itemIndex];
      return {
        itemIndex: item.itemIndex,
        answerText: essayTextMap.value[item.itemIndex] || fb?.answerText || "",
        answerImageKey: essayImageKeyMap.value[item.itemIndex] || "",
        ...(typeof fb?.selfCorrect === "boolean" ? { selfCorrect: fb.selfCorrect } : {}),
      };
    }
    return {
      itemIndex: item.itemIndex,
      selectedIndex: selectedMap.value[item.itemIndex] ?? -1,
    };
  });

  submitting.value = true;
  try {
    const payload = { sessionNo: startData.value.sessionNo, answers };
    let res: SubmitResult;
    if (mode.value === "ADVANCE_EXAM") {
      res = await AppRealmExamAPI.submit(payload);
    } else if (mode.value === "WRONG_REDO") {
      res = await AppWrongAPI.submitRedo(payload);
    } else {
      res = await AppQuizAPI.submit(payload);
    }
    submitResult.value = res;

    if (
      res.passed &&
      res.newlyPassed &&
      mode.value === "GATE" &&
      !userStore.isAuthenticated &&
      startData.value.gateId
    ) {
      userStore.recordGuestPassedGate(startData.value.gateId);
    }
    if (userStore.isAuthenticated) {
      void userStore.loadHomeSummary(true);
    }
  } catch (err) {
    toast.error(getErrorMessage(err, "交卷失败"));
  } finally {
    submitting.value = false;
  }
}

function goBack(): void {
  const pages = getCurrentPages();
  if (pages.length > 1) {
    uni.navigateBack();
  } else {
    uni.switchTab({ url: "/pages/index/index" });
  }
}

function handleExit(): void {
  const hasProgress =
    Object.keys(selectedMap.value).length > 0 ||
    Object.keys(feedbackMap.value).length > 0 ||
    Object.values(essayTextMap.value).some((v) => v.trim().length > 0);
  if (submitResult.value || !hasProgress) {
    goBack();
    return;
  }
  uni.showModal({
    title: "退出答题",
    content: "当前尚未交卷，确定退出吗？",
    success: (res) => {
      if (res.confirm) goBack();
    },
  });
}

onLoad((query) => {
  uni.$on("essay-draw-saved", handleEssayDrawSaved);
  if (query?.mode === "ADVANCE_EXAM") {
    mode.value = "ADVANCE_EXAM";
  } else if (query?.mode === "WRONG_REDO") {
    mode.value = "WRONG_REDO";
  } else {
    mode.value = "GATE";
  }
  gateId.value = query?.gateId ? Number(query.gateId) : undefined;
  realmCode.value = query?.realmCode ? decodeURIComponent(query.realmCode) : undefined;
  chapterId.value = query?.chapterId ? Number(query.chapterId) : undefined;
  void initQuiz();
});

onShow(() => {
  lockPortraitOrientation();
});

onUnload(() => {
  uni.$off("essay-draw-saved", handleEssayDrawSaved);
});
</script>

<style lang="scss" scoped>
.nav-exit-btn {
  display: flex;
  gap: 6rpx;
  align-items: center;
  padding: 8rpx 4rpx;
}

.nav-exit-text {
  font-size: 28rpx;
  color: var(--color-text);
}

.state-box {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
  align-items: center;
  padding: 120rpx 32rpx;
}

.state-box__text {
  font-size: 26rpx;
  color: var(--color-text-secondary);
}

.state-box__actions {
  display: flex;
  gap: 16rpx;
}

.progress-card {
  padding: 22rpx 24rpx;
  background: var(--color-bg-card);
  border-radius: 18rpx;
  box-shadow: var(--shadow-sm);
}

.progress-card__top {
  display: flex;
  gap: 12rpx;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16rpx;
}

.progress-card__step {
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-text);
}

.progress-card__tags {
  display: flex;
  gap: 8rpx;
  align-items: center;
}

.question-card {
  padding: 32rpx 28rpx;
  margin-top: 20rpx;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.question-card__meta {
  display: flex;
  gap: 14rpx;
  align-items: center;
}

.question-card__chapter {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.question-card__stem {
  display: block;
  margin-top: 20rpx;
  font-size: 34rpx;
  font-weight: 500;
  line-height: 1.6;
  color: var(--color-text);
}

.essay-saved-card {
  padding: 22rpx 24rpx;
  margin-top: 20rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 18rpx;
}

.essay-saved-card__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.essay-saved-card__title {
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-text);
}

.essay-saved-card__text {
  padding: 12rpx 16rpx;
  margin-top: 12rpx;
  font-size: 26rpx;
  color: var(--color-text);
  background: var(--color-bg-page);
  border-radius: 10rpx;
}

.essay-saved-card__img-wrap {
  margin-top: 12rpx;
}

.essay-saved-card__img {
  width: 100%;
  height: 320rpx;
  background: #ffffff;
  border: 1px solid var(--color-border);
  border-radius: 12rpx;
}

.essay-pending-banner {
  display: flex;
  gap: 10rpx;
  align-items: center;
  padding: 16rpx 18rpx;
  margin-top: 14rpx;
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-radius: 12rpx;
}

.essay-pending-banner__text {
  font-size: 24rpx;
  font-weight: 500;
  color: #b45309;
}

.options-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
  margin-top: 24rpx;
}

.option-row {
  display: flex;
  gap: 18rpx;
  align-items: center;
  padding: 26rpx 24rpx;
  background: var(--color-bg-card);
  border: 2px solid var(--color-border);
  border-radius: 18rpx;
  transition: all 0.15s ease;

  &--selected {
    background: var(--color-primary-soft);
    border-color: var(--color-primary);
  }

  &--correct {
    background: #f0fdf4;
    border-color: #16a34a;

    .option-row__badge {
      color: #ffffff;
      background: #16a34a;
    }
  }

  &--wrong {
    background: #fef2f2;
    border-color: #ef4444;

    .option-row__badge {
      color: #ffffff;
      background: #ef4444;
    }
  }

  &--dim {
    opacity: 0.6;
  }
}

.option-row__badge {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 52rpx;
  height: 52rpx;
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-text-secondary);
  background: var(--color-bg-page);
  border-radius: 50%;
}

.option-row__text {
  flex: 1;
  font-size: 30rpx;
  line-height: 1.45;
  color: var(--color-text);
}

.option-row__status {
  flex-shrink: 0;
}

.feedback-card {
  padding: 24rpx;
  margin-top: 24rpx;
  border-radius: 18rpx;

  &--pass {
    background: #f0fdf4;
    border: 1px solid #bbf7d0;
  }

  &--fail {
    background: #fef2f2;
    border: 1px solid #fecaca;
  }
}

.feedback-card__head {
  display: flex;
  gap: 10rpx;
  align-items: center;
}

.feedback-card__title {
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text);
}

.feedback-card__ans {
  display: block;
  margin-top: 12rpx;
  font-size: 26rpx;
  font-weight: 500;
  color: var(--color-text);
}

.feedback-card__analysis {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  line-height: 1.55;
  color: var(--color-text-secondary);
}

.result-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 48rpx 32rpx;
  text-align: center;
  background: var(--color-bg-card);
  border-radius: 20rpx;
  box-shadow: var(--shadow-sm);
}

.result-card__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 112rpx;
  height: 112rpx;
  border-radius: 50%;

  &--pass {
    background: #f0fdf4;
  }

  &--retry {
    background: #fffbeb;
  }
}

.result-card__title {
  margin-top: 24rpx;
  font-size: 38rpx;
  font-weight: 600;
  color: var(--color-text);
}

.result-card__score {
  margin-top: 12rpx;
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-primary);
}

.result-card__desc {
  margin-top: 10rpx;
  font-size: 26rpx;
  color: var(--color-text-secondary);
}

.promote-banner {
  display: flex;
  gap: 10rpx;
  align-items: center;
  padding: 14rpx 24rpx;
  margin-top: 24rpx;
  background: var(--color-primary-soft);
  border-radius: 14rpx;
}

.promote-banner__text {
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-primary);
}

.review-box {
  margin-top: 24rpx;
}

.review-box__title {
  display: block;
  margin-bottom: 14rpx;
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text);
}

.review-card {
  padding: 22rpx 24rpx;
  margin-bottom: 14rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 16rpx;
}

.review-card__stem {
  display: block;
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-text);
}

.review-card__ans {
  display: block;
  margin-top: 10rpx;
  font-size: 24rpx;
  font-weight: 500;
  color: var(--color-primary);
}

.review-card__analysis {
  display: block;
  margin-top: 6rpx;
  font-size: 24rpx;
  line-height: 1.5;
  color: var(--color-text-secondary);
}

.result-actions {
  display: flex;
  gap: 20rpx;
  width: 100%;
}
</style>
