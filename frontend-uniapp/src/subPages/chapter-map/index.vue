<template>
  <app-page-shell title="闯关地图" :has-footer="true">
    <view v-if="loading && gates.length === 0" class="map-page">
      <view class="overview-card">
        <wd-skeleton
          animation="gradient"
          :row-col="[
            [{ width: '20%', height: '18px' }, { width: '24%', height: '16px' }],
            [{ width: '64%', height: '24px' }],
            [{ width: '48%', height: '14px' }],
            [{ width: '28%', height: '38px' }, { width: '28%', height: '38px' }, { width: '28%', height: '38px' }],
          ]"
        />
      </view>
      <text class="ggl-section-label map-section-label">闯关路线</text>
      <view class="route-card">
        <view v-for="n in 4" :key="n" class="route-skeleton-row">
          <wd-skeleton
            animation="gradient"
            :row-col="[[{ width: '24px', height: '24px', type: 'circle' }, { width: '58%', height: '18px' }, { width: '16%', height: '18px' }]]"
          />
        </view>
      </view>
    </view>

    <view v-else class="map-page">
      <!-- 本章概览卡 -->
      <view class="overview-card">
        <view class="overview-tags">
          <text class="ggl-tag ggl-tag--primary">第 {{ chapterSeq }} 章</text>
          <text class="overview-realm">{{ chapterRealmName }}</text>
        </view>
        <text class="overview-title">{{ chapterName }}</text>
        <text v-if="chapterDesc" class="overview-desc">{{ chapterDesc }}</text>

        <view class="overview-stats">
          <view class="stat-item">
            <view class="stat-item__val-row">
              <text class="stat-item__val">{{ passedCount }}</text>
              <text class="stat-item__unit">/{{ totalGatesCount }}</text>
            </view>
            <text class="stat-item__label">已通关</text>
          </view>
          <view class="stat-item">
            <view class="stat-item__val-row">
              <text class="stat-item__val">{{ totalQuestionsCount }}</text>
              <text class="stat-item__unit"> 题</text>
            </view>
            <text class="stat-item__label">总题数</text>
          </view>
          <view class="stat-item">
            <view class="stat-item__val-row">
              <text class="stat-item__val">{{ passThresholdPercent }}%</text>
            </view>
            <text class="stat-item__label">过关线</text>
          </view>
        </view>
      </view>

      <!-- 闯关路线 -->
      <text class="ggl-section-label map-section-label">闯关路线</text>

      <view v-if="gates.length === 0" class="route-card route-empty">
        <app-icon name="empty" :size="28" color="muted" />
        <text class="route-empty__text">该章节暂未开放关卡</text>
      </view>

      <view v-else class="route-card">
        <view
          v-for="(gate, gIdx) in gates"
          :key="gate.id"
          class="step-item"
          @click="startGateQuiz(gate)"
        >
          <view class="step-axis">
            <view class="step-node" :class="stepNodeClass(gate)">
              <app-icon v-if="gate.passed" name="check" :size="13" color="#ffffff" />
              <text v-else class="step-node__num">{{ displayGateNum(gate) }}</text>
            </view>
            <view
              v-if="gIdx < gates.length - 1"
              class="step-line"
              :class="{ 'step-line--done': gate.passed }"
            />
          </view>

          <view class="step-content">
            <view class="step-main">
              <text
                class="step-title"
                :class="{ 'step-title--active': !gate.passed && !gate.locked, 'step-title--locked': gate.locked }"
              >
                第 {{ displayGateNum(gate) }} 关 · {{ gate.gateName }}
              </text>
              <text class="step-sub">{{ formatGateSub(gate) }}</text>
            </view>
            <text class="ggl-tag" :class="stepTagClass(gate)">
              {{ stepTagText(gate) }}
            </text>
          </view>
        </view>
      </view>

      <view class="reward-hint">
        <app-icon name="trophy" :size="15" color="#F59E0B" />
        <text class="reward-hint__text">{{ totalGatesCount }} 关全部通关，可达成完整章节掌握</text>
      </view>
    </view>

    <template #footer>
      <wd-button
        type="primary"
        size="large"
        block
        :disabled="!primaryActionGate"
        @click="handlePrimaryStart"
      >
        {{ primaryButtonText }}
      </wd-button>
    </template>
  </app-page-shell>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { onLoad, onShow } from "@dcloudio/uni-app";
import { useToast } from "@wot-ui/ui";
import { AppBankAPI } from "@/api/guoguanla";
import { useUserStore } from "@/store";
import type { GateCard } from "@/types/guoguanla";
import { ensureAuthenticated, getGuestPassedIds } from "@/utils/auth";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "chapter-map",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "闯关地图",
  },
});

const userStore = useUserStore();
const toast = useToast();

const chapterId = ref(0);
const chapterSeq = ref(1);
const chapterName = ref("章节闯关");
const chapterDesc = ref("");
const chapterRealmName = ref("");
const gates = ref<GateCard[]>([]);
const loading = ref(true);

const passedCount = computed(() => gates.value.filter((g) => g.passed).length);
const totalGatesCount = computed(() => gates.value.length || 4);

const totalQuestionsCount = computed(() => {
  return gates.value.reduce((sum, g) => sum + (g.questionCount || 0), 0);
});

const passThresholdPercent = computed(() => {
  const refGate = gates.value.find((g) => !g.passed && g.questionCount > 0) || gates.value[0];
  if (!refGate || !refGate.questionCount) return 60;
  return Math.round((refGate.passCount / refGate.questionCount) * 100);
});

const nextPlayableGate = computed<GateCard | null>(() => {
  return gates.value.find((g) => !g.passed && !g.locked && !g.empty) || null;
});

const primaryActionGate = computed<GateCard | null>(() => {
  return nextPlayableGate.value || gates.value.find((g) => !g.locked && !g.empty) || null;
});

const baseGateOffset = computed(() => {
  return gates.value.some((g) => g.gateIndex === 0) ? 1 : 0;
});

function displayGateNum(gate: GateCard): number {
  return gate.gateIndex + baseGateOffset.value;
}

const primaryButtonText = computed(() => {
  if (nextPlayableGate.value) {
    return `开始第 ${displayGateNum(nextPlayableGate.value)} 关`;
  }
  if (primaryActionGate.value && passedCount.value === gates.value.length && gates.value.length > 0) {
    return "重温第 1 关";
  }
  return "暂无可挑战关卡";
});

function activeGuestIds(): number[] | undefined {
  return userStore.isAuthenticated ? undefined : getGuestPassedIds();
}

function stepNodeClass(gate: GateCard): string {
  if (gate.passed) return "step-node--done";
  if (!gate.locked) return "step-node--current";
  return "step-node--locked";
}

function stepTagClass(gate: GateCard): string {
  if (gate.passed) return "ggl-tag--success";
  if (!gate.locked && !gate.empty) return "ggl-tag--primary";
  return "ggl-tag--neutral";
}

function stepTagText(gate: GateCard): string {
  if (gate.passed) return "已完成";
  if (gate.empty) return "待整理";
  if (!gate.locked) return "可挑战";
  return "未解锁";
}

function formatGateSub(gate: GateCard): string {
  if (gate.empty) return "题目整理中 · 敬请期待";
  if (gate.passed) {
    return `${gate.questionCount} 题 · 已通过（答对 ${gate.passCount} 题及格）`;
  }
  if (gate.locked) {
    return `${gate.questionCount} 题 · 完成上一关后解锁`;
  }
  const pct = gate.questionCount > 0 ? Math.round((gate.passCount / gate.questionCount) * 100) : 60;
  return `${gate.questionCount} 题 · 答对 ${pct}% 即可通关`;
}

async function fetchGates(): Promise<void> {
  if (!chapterId.value) return;
  loading.value = true;
  try {
    gates.value = await AppBankAPI.getGatesByChapter(chapterId.value, activeGuestIds());
  } catch (err) {
    toast.error(getErrorMessage(err, "加载关卡失败"));
  } finally {
    loading.value = false;
  }
}

function startGateQuiz(gate: GateCard): void {
  if (gate.empty) {
    toast.info("该关卡题目整理中，敬请期待");
    return;
  }
  if (gate.locked) {
    toast.info("请先通过上一关解锁当前关卡");
    return;
  }
  if (!userStore.isAuthenticated && !userStore.guestModeEnabled) {
    ensureAuthenticated();
    return;
  }
  uni.navigateTo({
    url: `/subPages/quiz/index?mode=GATE&gateId=${gate.id}&gateSeq=${displayGateNum(gate)}`,
  });
}

function handlePrimaryStart(): void {
  if (primaryActionGate.value) {
    startGateQuiz(primaryActionGate.value);
  }
}

onLoad((query) => {
  chapterId.value = Number(query?.chapterId || 0);
  chapterSeq.value = Number(query?.chapterSeq || 1);
  if (query?.name) chapterName.value = decodeURIComponent(query.name);
  if (query?.desc) chapterDesc.value = decodeURIComponent(query.desc);
  if (query?.realmName) chapterRealmName.value = decodeURIComponent(query.realmName);
});

onShow(() => {
  void fetchGates();
});
</script>

<style lang="scss" scoped>
.map-page {
  display: flex;
  flex-direction: column;
  padding-bottom: 16rpx;
}

.overview-card {
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.overview-tags {
  display: flex;
  gap: 16rpx;
  align-items: center;
}

.overview-realm {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.overview-title {
  display: block;
  margin-top: 18rpx;
  font-size: 40rpx;
  font-weight: 700;
  line-height: 1.3;
  color: var(--color-text);
}

.overview-desc {
  display: block;
  margin-top: 8rpx;
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.overview-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  padding-top: 28rpx;
  margin-top: 28rpx;
  border-top: 1px solid var(--color-border);
}

.stat-item {
  display: flex;
  flex-direction: column;
  gap: 6rpx;
  align-items: center;
}

.stat-item__val-row {
  display: flex;
  align-items: baseline;
}

.stat-item__val {
  font-size: 40rpx;
  font-weight: 700;
  color: var(--color-text);
}

.stat-item__unit {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.stat-item__label {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.map-section-label {
  padding: 0 8rpx;
  margin: 28rpx 0 16rpx;
}

.route-card {
  padding: 32rpx;
  background-color: var(--color-bg-card);
  border-radius: 16rpx;
}

.route-skeleton-row {
  padding: 20rpx 0;
}

.route-empty {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
  align-items: center;
  padding: 64rpx 32rpx;
}

.route-empty__text {
  font-size: 26rpx;
  color: var(--color-text-muted);
}

.step-item {
  display: flex;
  gap: 24rpx;
  align-items: stretch;
}

.step-axis {
  display: flex;
  flex-shrink: 0;
  flex-direction: column;
  align-items: center;
  width: 48rpx;
}

.step-node {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 48rpx;
  height: 48rpx;
  border-radius: 9999px;

  &--done {
    background-color: var(--color-primary);
  }

  &--current {
    color: var(--color-primary);
    background-color: var(--color-bg-card);
    border: 4rpx solid var(--color-primary);
  }

  &--locked {
    color: var(--color-text-placeholder);
    background-color: var(--color-bg-card);
    border: 2rpx solid var(--color-border-strong);
  }
}

.step-node__num {
  font-size: 24rpx;
  font-weight: 700;
  color: inherit;
}

.step-line {
  flex: 1;
  width: 2rpx;
  min-height: 44rpx;
  margin: 8rpx 0;
  background-color: var(--color-border-muted);

  &--done {
    background-color: var(--color-primary);
  }
}

.step-content {
  display: flex;
  flex: 1;
  gap: 16rpx;
  align-items: flex-start;
  justify-content: space-between;
  min-width: 0;
  padding-bottom: 40rpx;
}

.step-item:last-child .step-content {
  padding-bottom: 0;
}

.step-main {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 6rpx;
  min-width: 0;
}

.step-title {
  font-size: 30rpx;
  font-weight: 600;
  line-height: 1.4;
  color: var(--color-text);

  &--active {
    color: var(--color-primary);
  }

  &--locked {
    font-weight: 500;
    color: var(--color-text-muted);
  }
}

.step-sub {
  font-size: 24rpx;
  color: var(--color-text-muted);
}

.reward-hint {
  display: flex;
  gap: 10rpx;
  align-items: center;
  justify-content: center;
  margin-top: 28rpx;
}

.reward-hint__text {
  font-size: 24rpx;
  color: var(--color-text-muted);
}
</style>
