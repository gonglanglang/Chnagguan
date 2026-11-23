<template>
  <app-page-shell title="我的解答作答记录">
    <template v-if="loading && list.length === 0">
      <view class="summary-bar">
        <wd-skeleton
          animation="gradient"
          :row-col="[
            [
              { width: '48%', height: '16px' },
              { width: '56px', height: '28px', borderRadius: '8px' },
            ],
            { width: '62%', height: '12px' },
          ]"
        />
      </view>

      <view class="essay-list">
        <view v-for="n in 3" :key="n" class="essay-card">
          <wd-skeleton
            animation="gradient"
            :row-col="[
              [
                { width: '54%', height: '13px' },
                { width: '24%', height: '18px', borderRadius: '6px' },
              ],
              { width: '94%', height: '16px' },
              { width: '68%', height: '16px' },
              { type: 'rect', width: '100%', height: '140px', borderRadius: '8px' },
              { width: '34%', height: '12px' },
            ]"
          />
        </view>
      </view>
    </template>

    <template v-else>
      <view class="summary-bar">
        <view class="summary-bar__left">
          <text class="summary-bar__count">共 {{ total }} 条作答记录</text>
          <text class="summary-bar__hint">清空后将从数据库永久删除且不可恢复</text>
        </view>
        <wd-button
          size="small"
          variant="text"
          type="danger"
          :disabled="total === 0 || clearing"
          :loading="clearing"
          @click="handleClearAll"
        >
          清空
        </wd-button>
      </view>

      <wd-empty
        v-if="list.length === 0"
        icon="no-content"
        tip="暂无解答题手写作答记录，快去挑战解答关卡吧"
      />

      <view v-else class="essay-list">
        <view v-for="item in list" :key="item.id" class="essay-card">
          <view class="essay-card__top">
            <text class="essay-card__source">
              <template v-if="item.realmName">{{ item.realmName }} · </template>
              {{ item.chapterName || "解答作答" }}
              <template v-if="item.gateName"> · {{ item.gateName }}</template>
            </text>
            <view class="essay-card__badges">
              <wd-tag
                size="small"
                :type="item.teacherStatus === 1 ? 'success' : item.teacherStatus === 2 ? 'danger' : 'primary'"
                variant="light"
              >
                {{
                  item.teacherStatus === 1
                    ? "老师已批通过"
                    : item.teacherStatus === 2
                      ? "老师批：待订正"
                      : "待老师批改"
                }}
              </wd-tag>
            </view>
          </view>

          <view class="essay-card__stem">
            <math-text :text="item.stem" />
          </view>

          <view v-if="item.answerText" class="essay-card__text">
            文字补充：{{ item.answerText }}
          </view>

          <view v-if="item.answerImageUrl" class="essay-card__img-wrap">
            <text class="essay-card__label">我的手写作答：</text>
            <image
              :src="item.answerImageUrl"
              mode="aspectFit"
              class="essay-card__img"
              @click="previewImg(item.answerImageUrl)"
            />
          </view>

          <view v-if="item.teacherImageUrl" class="essay-card__img-wrap">
            <text class="essay-card__label">老师画板批注：</text>
            <image
              :src="item.teacherImageUrl"
              mode="aspectFit"
              class="essay-card__img"
              @click="previewImg(item.teacherImageUrl)"
            />
          </view>

          <view v-if="item.referenceAnswer" class="essay-card__ref">
            <text class="essay-card__ref-label">参考答案：</text>
            <math-text :text="item.referenceAnswer" inline />
          </view>

          <view v-if="item.teacherComment" class="essay-card__comment">
            老师点评：{{ item.teacherComment }}
          </view>

          <view class="essay-card__time">{{ formatTime(item.createdAt) }}</view>
        </view>

        <view v-if="list.length < total" class="load-more">
          <wd-button size="small" variant="plain" :loading="loading" @click="loadMore">
            加载更多 ({{ list.length }} / {{ total }})
          </wd-button>
        </view>
      </view>
    </template>
  </app-page-shell>
</template>

<script setup lang="ts">
import { onShow } from "@dcloudio/uni-app";
import { ref } from "vue";
import { AppUserAPI } from "@/api/guoguanla";
import type { EssayAnswerRecord } from "@/types/guoguanla";
import { getErrorMessage } from "@/utils/error";

definePage({
  name: "essay-records",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "我的解答作答记录",
  },
});

const toast = useToast();
const loading = ref(true);
const clearing = ref(false);
const pageNum = ref(1);
const total = ref(0);
const list = ref<EssayAnswerRecord[]>([]);

function formatTime(iso?: string | null): string {
  if (!iso) return "";
  return iso.replace("T", " ").slice(0, 16);
}

function previewImg(url: string): void {
  if (!url) return;
  uni.previewImage({ urls: [url] });
}

async function fetchRecords(reset = true): Promise<void> {
  if (reset) pageNum.value = 1;
  loading.value = true;
  try {
    const res = await AppUserAPI.getEssayAnswers({ pageNum: pageNum.value, pageSize: 10 });
    total.value = res.total;
    list.value = reset ? res.records : [...list.value, ...res.records];
  } catch (err) {
    toast.error(getErrorMessage(err, "获取解答记录失败"));
  } finally {
    loading.value = false;
  }
}

function loadMore(): void {
  if (loading.value || list.value.length >= total.value) return;
  pageNum.value += 1;
  void fetchRecords(false);
}

function handleClearAll(): void {
  if (total.value === 0 || clearing.value) return;
  uni.showModal({
    title: "清空解答作答记录",
    content: "确定永久清空所有解答作答记录吗？清空后数据库将彻底删除，不可恢复。",
    confirmColor: "#ef4444",
    success: async (res) => {
      if (!res.confirm) return;
      clearing.value = true;
      try {
        await AppUserAPI.clearEssayAnswers();
        list.value = [];
        total.value = 0;
        pageNum.value = 1;
        toast.success("已永久清空");
      } catch (err) {
        toast.error(getErrorMessage(err, "清空失败"));
      } finally {
        clearing.value = false;
      }
    },
  });
}

onShow(() => {
  void fetchRecords(true);
});
</script>

<style lang="scss" scoped>
.summary-bar {
  display: flex;
  gap: 16rpx;
  align-items: center;
  justify-content: space-between;
  padding: 20rpx 24rpx;
  margin-bottom: 20rpx;
  background: var(--color-bg-card);
  border-radius: 16rpx;
}

.summary-bar__left {
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.summary-bar__count {
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text);
}

.summary-bar__hint {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.essay-list {
  display: flex;
  flex-direction: column;
  gap: 18rpx;
}

.essay-card {
  padding: 24rpx;
  background: var(--color-bg-card);
  border-radius: 16rpx;
}

.essay-card__top {
  display: flex;
  flex-wrap: wrap;
  gap: 10rpx;
  align-items: center;
  justify-content: space-between;
}

.essay-card__source {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.essay-card__badges {
  display: flex;
  gap: 8rpx;
}

.essay-card__stem {
  margin-top: 14rpx;
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text);
}

.essay-card__text {
  padding: 14rpx 18rpx;
  margin-top: 14rpx;
  font-size: 24rpx;
  color: var(--color-text);
  background: var(--color-bg-page);
  border-radius: 12rpx;
}

.essay-card__img-wrap {
  margin-top: 14rpx;
}

.essay-card__label {
  display: block;
  margin-bottom: 8rpx;
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.essay-card__img {
  width: 100%;
  height: 320rpx;
  background: #ffffff;
  border: 1px solid var(--color-border);
  border-radius: 12rpx;
}

.essay-card__ref {
  padding: 16rpx 20rpx;
  margin-top: 14rpx;
  font-size: 24rpx;
  color: var(--color-success);
  background: var(--color-success-light);
  border-radius: 12rpx;
}

.essay-card__ref-label {
  font-weight: 600;
}

.essay-card__comment {
  margin-top: 12rpx;
  font-size: 24rpx;
  font-weight: 500;
  color: var(--color-primary);
}

.essay-card__time {
  margin-top: 12rpx;
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.load-more {
  display: flex;
  justify-content: center;
  margin-top: 12rpx;
}
</style>
