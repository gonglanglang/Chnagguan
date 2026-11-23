<template>
  <app-page-shell
    :title="navbarTitle"
    :show-back="false"
    :has-footer="hasFooterBar"
    :flush="true"
  >
    <template #nav-left>
      <view class="nav-exit-btn" @click="handleExit">
        <app-icon name="close" :size="20" color="text" />
      </view>
    </template>

    <template #header>
      <view class="quiz-header-wrap">
        <app-navbar
          :title="navbarTitle"
          :show-back="false"
          :fixed="false"
        >
          <template #left>
            <view class="nav-exit-btn" @click="handleExit">
              <app-icon name="close" :size="20" color="text" />
            </view>
          </template>
        </app-navbar>

        <!-- 顶部答题进度条与用时（作答态与加载态） -->
        <view v-if="startData && !submitResult" class="progress-strip">
          <view class="progress-strip__top">
            <view class="progress-strip__index">
              <text class="progress-strip__muted">第 </text>
              <text class="progress-strip__curr">{{ currentIdx + 1 }}</text>
              <text class="progress-strip__muted"> / {{ startData.totalCount }} 题</text>
            </view>
            <view class="progress-strip__timer">
              <app-icon name="time" :size="14" color="muted" />
              <text class="progress-strip__time">{{ formattedElapsed }}</text>
            </view>
          </view>
          <view class="progress-track">
            <view class="progress-track__fill" :style="{ width: progressPercent + '%' }" />
          </view>
        </view>
      </view>
    </template>

    <!-- 骨架屏 -->
    <view v-if="loading" class="quiz-body">
      <view class="question-card">
        <wd-skeleton
          animation="gradient"
          :row-col="[
            [{ width: '16%', height: '18px' }, { width: '24%', height: '18px' }],
            [{ width: '92%', height: '20px' }],
            [{ width: '74%', height: '20px' }],
          ]"
        />
      </view>
      <view v-for="n in 4" :key="n" class="option-skeleton-row">
        <wd-skeleton
          animation="gradient"
          :row-col="[[{ width: '28px', height: '28px', type: 'circle' }, { width: '68%', height: '18px' }]]"
        />
      </view>
    </view>

    <!-- 加载失败 -->
    <view v-else-if="loadError" class="state-card">
      <app-icon name="alert-circle" :size="36" color="danger" />
      <text class="state-card__title">{{ loadError }}</text>
      <view class="state-card__btn" @click="goBack">
        <text class="state-card__btn-text">返回上一页</text>
      </view>
    </view>

    <!-- 答题主体 -->
    <view v-else-if="startData && !submitResult && currentItem" class="quiz-body">
      <!-- 题干卡片 -->
      <view class="question-card">
        <view class="question-card__tags">
          <text class="ggl-tag ggl-tag--primary">
            {{ isCurrentEssay ? "解答题" : "单选题" }}
          </text>
          <text class="ggl-tag ggl-tag--neutral">
            {{ startData.chapterName || startData.realmName || "综合训练" }}
          </text>
        </view>
        <view class="question-card__stem">
          <math-text :text="currentItem.stem" />
        </view>
      </view>

      <!-- 单选题选项 -->
      <view v-if="!isCurrentEssay" class="options-list">
        <view
          v-for="(opt, idx) in currentItem.options"
          :key="idx"
          class="option-row"
          :class="getOptionClass(idx)"
          @click="handleSelectOption(idx)"
        >
          <view class="option-row__left">
            <view class="option-letter">
              <text class="option-letter__text">{{ LETTERS[idx] || idx + 1 }}</text>
            </view>
            <view class="option-content">
              <math-text :text="opt" />
            </view>
          </view>

          <view v-if="currentFeedback" class="option-row__status">
            <app-icon
              v-if="idx === currentFeedback.correctIndex"
              name="check-circle"
              :size="20"
              color="success"
            />
            <app-icon
              v-else-if="idx === currentSelected && !currentFeedback.correct"
              name="close-circle"
              :size="20"
              color="danger"
            />
          </view>
        </view>
      </view>

      <!-- 解答题作答区 -->
      <view v-else class="essay-card">
        <view class="essay-card__head">
          <text class="essay-card__title">手写画板作答</text>
          <text class="essay-card__hint">支持横屏手写演算并上传老师批改</text>
        </view>

        <view
          v-if="currentFeedback?.answerImageUrl"
          class="essay-preview"
          @click="previewImage(currentFeedback.answerImageUrl)"
        >
          <image
            :src="currentFeedback.answerImageUrl"
            mode="aspectFit"
            class="essay-preview__img"
          />
          <text class="essay-preview__tip">点击查看大图</text>
        </view>

        <view class="essay-draw-btn" @click="openLandscapeDraw">
          <app-icon name="brush" :size="18" color="primary" />
          <text class="essay-draw-btn__text">
            {{ currentFeedback?.answerImageUrl ? "重新前往手写画板" : "前往手写画板作答" }}
          </text>
        </view>

        <view v-if="!currentFeedback" class="essay-text-box">
          <textarea
            v-model="essayTextMap[currentItem.itemIndex]"
            class="essay-textarea"
            placeholder="也可以在此补充文字解题步骤..."
            placeholder-class="essay-placeholder"
            :maxlength="500"
          />
          <view class="essay-self-btn" @click="handleCheckEssayText">
            <text class="essay-self-btn__text">提交解答并查看解析</text>
          </view>
        </view>
      </view>

      <!-- 判题反馈与解析卡片 -->
      <view v-if="currentFeedback" class="feedback-card">
        <view class="feedback-card__head">
          <view class="feedback-card__status">
            <app-icon
              :name="currentFeedback.pendingReview ? 'info' : currentFeedback.correct ? 'check-circle' : 'alert-circle'"
              :size="18"
              :color="currentFeedback.pendingReview ? 'primary' : currentFeedback.correct ? 'success' : 'danger'"
            />
            <text
              class="feedback-card__title"
              :class="feedbackTitleClass(currentFeedback)"
            >
              {{ feedbackTitleText(currentFeedback) }}
            </text>
          </view>

          <text
            v-if="!isCurrentEssay"
            class="ggl-tag"
            :class="currentFeedback.correct ? 'ggl-tag--success' : 'ggl-tag--danger'"
          >
            正确答案 {{ LETTERS[currentFeedback.correctIndex] || currentFeedback.correctIndex + 1 }}
          </text>
        </view>

        <view v-if="currentFeedback.referenceAnswer" class="feedback-ref">
          <text class="feedback-ref__label">参考答案：</text>
          <math-text :text="currentFeedback.referenceAnswer" />
        </view>

        <view v-if="currentFeedback.analysis" class="feedback-card__analysis">
          <math-text :text="currentFeedback.analysis" />
        </view>

        <text class="feedback-card__foot">
          {{ feedbackFootHint(currentFeedback) }}
        </text>
      </view>
    </view>

    <!-- 交卷结果页 -->
    <view v-else-if="submitResult" class="quiz-body">
      <view class="result-card">
        <view
          class="result-badge"
          :class="submitResult.passed ? 'result-badge--pass' : 'result-badge--fail'"
        >
          <app-icon
            :name="submitResult.passed ? 'check-circle' : 'alert-circle'"
            :size="36"
            :color="submitResult.passed ? 'success' : 'danger'"
          />
        </view>
        <text class="result-title">
          {{ resultHeadline(submitResult) }}
        </text>
        <text class="result-sub">
          本关共 {{ submitResult.totalCount }} 题，答对 {{ submitResult.correctCount }} 题
          {{ submitResult.score !== null ? ` · 得分 ${submitResult.score}` : "" }}
        </text>

        <view class="result-metrics">
          <view class="result-metric">
            <text class="result-metric__val">{{ submitResult.correctCount }}</text>
            <text class="result-metric__label">答对题数</text>
          </view>
          <view class="result-metric">
            <text class="result-metric__val">{{ formattedElapsed }}</text>
            <text class="result-metric__label">本次用时</text>
          </view>
          <view class="result-metric">
            <text class="result-metric__val">{{ submitResult.totalPassedGates }}</text>
            <text class="result-metric__label">累计过关</text>
          </view>
        </view>
      </view>

      <view v-if="submitResult.promotedRealm" class="promo-card">
        <text class="ggl-tag ggl-tag--primary">境界晋升</text>
        <text class="promo-card__title">恭喜晋升至 {{ submitResult.promotedRealm.realmName }}！</text>
        <text class="promo-card__desc">{{ submitResult.promotedRealm.description }}</text>
      </view>

      <view v-if="submitResult.wrongItems && submitResult.wrongItems.length > 0" class="review-card">
        <text class="review-card__title">错题速览（已自动收录错题本）</text>
        <view
          v-for="(item, idx) in submitResult.wrongItems"
          :key="idx"
          class="review-row"
        >
          <view class="review-row__stem">
            <math-text :text="item.stem" />
          </view>
          <view class="review-row__ans">
            <text>正确答案：</text>
            <math-text :text="item.correctAnswer" inline />
          </view>
          <view v-if="idx < submitResult.wrongItems.length - 1" class="review-row__divider" />
        </view>
      </view>
    </view>

    <!-- 吸底操作按钮 -->
    <template #footer>
      <view v-if="loading" class="footer-skeleton">
        <wd-skeleton animation="gradient" :row-col="[[{ width: '100%', height: '44px', type: 'circle' }]]" />
      </view>

      <view v-else-if="submitResult" class="result-footer">
        <view class="footer-btn footer-btn--outline" @click="initQuiz">
          <text class="footer-btn__text">再做一次</text>
        </view>
        <view class="footer-btn footer-btn--primary" @click="goBack">
          <text class="footer-btn__text">返回地图</text>
        </view>
      </view>

      <view v-else-if="startData && currentItem">
        <!-- 未判题：提交答案 -->
        <view
          v-if="!currentFeedback && !isCurrentEssay"
          class="footer-btn footer-btn--primary"
          :class="{ 'footer-btn--disabled': currentSelected === undefined || checking }"
          @click="currentSelected !== undefined && !checking && handleConfirmChoice()"
        >
          <text class="footer-btn__text">{{ checking ? "正在判题..." : "提交答案" }}</text>
        </view>

        <!-- 解答题未作答前引导画板 -->
        <view
          v-else-if="!currentFeedback && isCurrentEssay"
          class="footer-btn footer-btn--primary"
          @click="openLandscapeDraw"
        >
          <text class="footer-btn__text">打开画板作答</text>
        </view>

        <!-- 已判题：下一题 / 完成交卷 -->
        <view
          v-else-if="currentIdx < startData.items.length - 1"
          class="footer-btn footer-btn--primary"
          @click="nextQuestion"
        >
          <text class="footer-btn__text">下一题</text>
        </view>

        <view
          v-else
          class="footer-btn footer-btn--primary"
          :class="{ 'footer-btn--disabled': submitting }"
          @click="!submitting && handleSubmit()"
        >
          <text class="footer-btn__text">{{ submitting ? "正在交卷..." : "完成交卷" }}</text>
        </view>
      </view>
    </template>
  </app-page-shell>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { onLoad, onShow, onUnload } from "@dcloudio/uni-app";
import { useToast } from "@wot-ui/ui";
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
const ACTIVE_ESSAY_PROMPT_KEY = "ggl_active_essay_prompt";

const userStore = useUserStore();
const toast = useToast();

const mode = ref<"GATE" | "WRONG_REDO" | "ADVANCE_EXAM">("GATE");
const gateId = ref<number | undefined>();
const gateSeq = ref<number | undefined>();
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

const elapsedSec = ref(0);
let timerHandle: ReturnType<typeof setInterval> | null = null;

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

const progressPercent = computed(() => {
  const total = startData.value?.totalCount || 1;
  return Math.min(100, Math.round(((currentIdx.value + 1) / total) * 100));
});

const formattedElapsed = computed(() => {
  const mm = String(Math.floor(elapsedSec.value / 60)).padStart(2, "0");
  const ss = String(elapsedSec.value % 60).padStart(2, "0");
  return `${mm}:${ss}`;
});

const hasFooterBar = computed(() =>
  Boolean(
    loading.value ||
      (!loadError.value &&
        ((startData.value && !submitResult.value && currentItem.value) || submitResult.value)),
  ),
);

const navbarTitle = computed(() => {
  if (mode.value === "ADVANCE_EXAM") return "境界进阶考核";
  if (mode.value === "WRONG_REDO") return "错题重做";
  const name = startData.value?.gateName || "关卡挑战";
  return gateSeq.value ? `第 ${gateSeq.value} 关 · ${name}` : name;
});

function startTimer(): void {
  stopTimer();
  elapsedSec.value = 0;
  timerHandle = setInterval(() => {
    elapsedSec.value += 1;
  }, 1000);
}

function stopTimer(): void {
  if (timerHandle !== null) {
    clearInterval(timerHandle);
    timerHandle = null;
  }
}

function getOptionClass(idx: number): string {
  const fb = currentFeedback.value;
  if (!fb) {
    return currentSelected.value === idx ? "option-row--selected" : "";
  }
  if (idx === fb.correctIndex) return "option-row--correct";
  if (idx === currentSelected.value && !fb.correct) return "option-row--wrong";
  return "option-row--dim";
}

function feedbackTitleClass(fb: CheckItemResult): string {
  if (fb.pendingReview) return "feedback-card__title--primary";
  return fb.correct ? "feedback-card__title--success" : "feedback-card__title--danger";
}

function feedbackTitleText(fb: CheckItemResult): string {
  if (fb.pendingReview) return "已提交等待批改";
  return fb.correct ? "回答正确" : "回答错误";
}

function feedbackFootHint(fb: CheckItemResult): string {
  if (fb.pendingReview) return "解答过程已提交，老师批改后将同步结果";
  if (mode.value === "WRONG_REDO") {
    return fb.correct ? "重做答对，交卷后自动移出错题本" : "本题将继续保留在错题本中";
  }
  return fb.correct ? "回答正确，继续下一题" : "本题已加入错题本";
}

function resultHeadline(res: SubmitResult): string {
  if (mode.value === "ADVANCE_EXAM") {
    return res.passed ? "考核通过，成功晋升！" : "暂未达标，再接再厉";
  }
  if (mode.value === "WRONG_REDO") {
    return `本次重做掌握 ${res.masteredCount || res.correctCount} 题`;
  }
  return res.passed ? "闯关成功！" : "差一点点，继续加油";
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

function handleSelectOption(idx: number): void {
  if (!currentItem.value || currentFeedback.value || checking.value) return;
  selectedMap.value[currentItem.value.itemIndex] = idx;
}

async function handleConfirmChoice(): Promise<void> {
  if (!startData.value || !currentItem.value) return;
  if (currentFeedback.value || checking.value) return;
  const itemIndex = currentItem.value.itemIndex;
  const idx = selectedMap.value[itemIndex];
  if (idx === undefined) return;

  checking.value = true;
  try {
    const res = await AppQuizAPI.checkItem({
      sessionNo: startData.value.sessionNo,
      itemIndex,
      selectedIndex: idx,
    });
    feedbackMap.value[itemIndex] = res;
  } catch (err) {
    toast.error(getErrorMessage(err, "判题失败"));
  } finally {
    checking.value = false;
  }
}

async function handleCheckEssayText(): Promise<void> {
  if (!startData.value || !currentItem.value || checking.value) return;
  const itemIndex = currentItem.value.itemIndex;
  const text = (essayTextMap.value[itemIndex] || "").trim();
  if (!text) {
    toast.warning("请先输入解题思路或打开画板手写");
    return;
  }
  checking.value = true;
  try {
    const res = await AppQuizAPI.checkItem({
      sessionNo: startData.value.sessionNo,
      itemIndex,
      answerText: text,
      answerImageKey: essayImageKeyMap.value[itemIndex] || undefined,
    });
    feedbackMap.value[itemIndex] = res;
  } catch (err) {
    toast.error(getErrorMessage(err, "提交解答失败"));
  } finally {
    checking.value = false;
  }
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
    if (startData.value && !loadError.value) {
      startTimer();
    }
  } catch (err) {
    loadError.value = getErrorMessage(err, "出题失败，请稍后重试");
  } finally {
    loading.value = false;
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
    stopTimer();
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
      void userStore.refreshWrongCount();
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
    confirmColor: "#EF4444",
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
  gateSeq.value = query?.gateSeq ? Number(query.gateSeq) : undefined;
  realmCode.value = query?.realmCode ? decodeURIComponent(query.realmCode) : undefined;
  chapterId.value = query?.chapterId ? Number(query.chapterId) : undefined;
  void initQuiz();
});

onShow(() => {
  lockPortraitOrientation();
});

onUnload(() => {
  stopTimer();
  uni.$off("essay-draw-saved", handleEssayDrawSaved);
});
</script>

<style lang="scss" scoped>
.quiz-header-wrap {
  background-color: var(--color-bg-card);
}

.nav-exit-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 64rpx;
  height: 64rpx;
}

.progress-strip {
  padding: 6rpx 32rpx 20rpx;
  background-color: var(--color-bg-card);
  border-bottom: 1px solid var(--color-border);
}

.progress-strip__top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12rpx;
}

.progress-strip__index {
  display: flex;
  align-items: baseline;
  font-size: 24rpx;
}

.progress-strip__muted {
  color: var(--color-text-muted);
}

.progress-strip__curr {
  font-weight: 700;
  color: var(--color-text);
}

.progress-strip__timer {
  display: flex;
  gap: 8rpx;
  align-items: center;
}

.progress-strip__time {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.progress-track {
  width: 100%;
  height: 8rpx;
  overflow: hidden;
  background-color: var(--color-fill-2);
  border-radius: 9999px;
}

.progress-track__fill {
  height: 100%;
  background-color: var(--color-primary);
  border-radius: 9999px;
  transition: width 0.25s ease;
}

.quiz-body {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
  padding: 24rpx 24rpx 48rpx;
}

.state-card {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
  align-items: center;
  padding: 96rpx 32rpx;
  margin: 24rpx;
  text-align: center;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.state-card__title {
  font-size: 28rpx;
  color: var(--color-text-secondary);
}

.state-card__btn {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 76rpx;
  padding: 0 48rpx;
  background-color: var(--color-primary);
  border-radius: 9999px;
}

.state-card__btn-text {
  font-size: 28rpx;
  font-weight: 500;
  color: #ffffff;
}

.question-card {
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.question-card__tags {
  display: flex;
  gap: 12rpx;
  align-items: center;
}

.question-card__stem {
  margin-top: 24rpx;
  font-size: 34rpx;
  line-height: 1.65;
  color: var(--color-text);
}

.options-list {
  display: flex;
  flex-direction: column;
  gap: 22rpx;
}

.option-skeleton-row {
  padding: 28rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.option-row {
  display: flex;
  gap: 20rpx;
  align-items: center;
  justify-content: space-between;
  padding: 26rpx 28rpx;
  background-color: var(--color-bg-card);
  border: 1px solid transparent;
  border-radius: 16rpx;
  transition: background-color 0.15s ease, border-color 0.15s ease, opacity 0.15s ease;

  &--selected {
    background-color: var(--color-primary-soft);
    border-color: var(--color-primary);

    .option-letter {
      color: #ffffff;
      background-color: var(--color-primary);
    }
  }

  &--correct {
    background-color: var(--color-success-light);
    border-color: var(--color-success-outline);

    .option-letter {
      color: #ffffff;
      background-color: var(--color-success-outline);
    }
  }

  &--wrong {
    background-color: var(--color-danger-light);
    border-color: var(--color-danger);

    .option-letter {
      color: #ffffff;
      background-color: var(--color-danger);
    }
  }

  &--dim {
    opacity: 0.58;
  }
}

.option-row__left {
  display: flex;
  flex: 1;
  gap: 22rpx;
  align-items: center;
  min-width: 0;
}

.option-letter {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 56rpx;
  height: 56rpx;
  color: var(--color-text-secondary);
  background-color: var(--color-fill-1);
  border-radius: 9999px;
}

.option-letter__text {
  font-size: 26rpx;
  font-weight: 700;
  color: inherit;
}

.option-content {
  flex: 1;
  min-width: 0;
  font-size: 30rpx;
  line-height: 1.5;
  color: var(--color-text);
}

.option-row__status {
  flex-shrink: 0;
}

.essay-card {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.essay-card__head {
  display: flex;
  flex-direction: column;
  gap: 6rpx;
}

.essay-card__title {
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text);
}

.essay-card__hint {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.essay-preview {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
  align-items: center;
  padding: 16rpx;
  background-color: var(--color-bg-page);
  border-radius: 12rpx;
}

.essay-preview__img {
  width: 100%;
  height: 260rpx;
}

.essay-preview__tip {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.essay-draw-btn {
  display: flex;
  gap: 12rpx;
  align-items: center;
  justify-content: center;
  height: 84rpx;
  background-color: var(--color-primary-soft);
  border: 1px solid var(--color-primary-alpha-20);
  border-radius: 12rpx;
}

.essay-draw-btn__text {
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-primary);
}

.essay-text-box {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.essay-textarea {
  box-sizing: border-box;
  width: 100%;
  min-height: 160rpx;
  padding: 20rpx;
  font-size: 26rpx;
  color: var(--color-text);
  background-color: var(--color-bg-page);
  border-radius: 12rpx;
}

:deep(.essay-placeholder) {
  color: var(--color-text-placeholder);
}

.essay-self-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 76rpx;
  background-color: var(--color-bg-card);
  border: 1px solid var(--color-border-strong);
  border-radius: 9999px;
}

.essay-self-btn__text {
  font-size: 26rpx;
  font-weight: 500;
  color: var(--color-text-secondary);
}

.feedback-card {
  display: flex;
  flex-direction: column;
  gap: 18rpx;
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.feedback-card__head {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
}

.feedback-card__status {
  display: flex;
  gap: 12rpx;
  align-items: center;
}

.feedback-card__title {
  font-size: 30rpx;
  font-weight: 700;

  &--success {
    color: var(--color-success);
  }

  &--danger {
    color: var(--color-danger-text);
  }

  &--primary {
    color: var(--color-primary);
  }
}

.feedback-ref {
  padding: 20rpx;
  font-size: 26rpx;
  line-height: 1.55;
  color: var(--color-text-secondary);
  background-color: var(--color-bg-page);
  border-radius: 12rpx;
}

.feedback-ref__label {
  display: block;
  margin-bottom: 6rpx;
  font-size: 24rpx;
  font-weight: 600;
  color: var(--color-success);
}

.feedback-card__analysis {
  font-size: 26rpx;
  line-height: 1.6;
  color: var(--color-text-secondary);
}

.feedback-card__foot {
  font-size: 24rpx;
  color: var(--color-text-placeholder);
}

.result-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 48rpx 32rpx 36rpx;
  text-align: center;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.result-badge {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 112rpx;
  height: 112rpx;
  border-radius: 9999px;

  &--pass {
    background-color: var(--color-success-light);
  }

  &--fail {
    background-color: var(--color-danger-light);
  }
}

.result-title {
  margin-top: 24rpx;
  font-size: 38rpx;
  font-weight: 700;
  color: var(--color-text);
}

.result-sub {
  margin-top: 10rpx;
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.result-metrics {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  width: 100%;
  padding-top: 28rpx;
  margin-top: 32rpx;
  border-top: 1px solid var(--color-border);
}

.result-metric {
  display: flex;
  flex-direction: column;
  gap: 6rpx;
  align-items: center;
}

.result-metric__val {
  font-size: 36rpx;
  font-weight: 700;
  color: var(--color-text);
}

.result-metric__label {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.promo-card,
.review-card {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.promo-card__title,
.review-card__title {
  font-size: 30rpx;
  font-weight: 700;
  color: var(--color-text);
}

.promo-card__desc {
  font-size: 26rpx;
  color: var(--color-text-secondary);
}

.review-row {
  display: flex;
  flex-direction: column;
  gap: 10rpx;
  padding-top: 14rpx;
}

.review-row__stem {
  font-size: 26rpx;
  line-height: 1.5;
  color: var(--color-text);
}

.review-row__ans {
  display: flex;
  flex-wrap: wrap;
  gap: 4rpx;
  align-items: center;
  font-size: 24rpx;
  font-weight: 500;
  color: var(--color-success);
}

.review-row__divider {
  height: 1px;
  margin-top: 14rpx;
  background-color: var(--color-border);
}

.footer-skeleton {
  padding: 4rpx 0;
}

.result-footer {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20rpx;
}

.footer-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 88rpx;
  border-radius: 9999px;

  &--primary {
    color: #ffffff;
    background-color: var(--color-primary);
  }

  &--outline {
    color: var(--color-text-secondary);
    background-color: var(--color-bg-card);
    border: 1px solid var(--color-border-strong);
  }

  &--disabled {
    opacity: 0.4;
  }
}

.footer-btn__text {
  font-size: 32rpx;
  font-weight: 600;
  color: inherit;
}
</style>
