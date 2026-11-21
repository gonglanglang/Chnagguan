<template>
  <app-page-shell title="我的解答作答记录">
    <view v-if="loading && list.length === 0" class="state-box">
      <wd-loading />
    </view>

    <wd-empty
      v-else-if="list.length === 0"
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
const loading = ref(false);
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

onShow(() => {
  void fetchRecords(true);
});
</script>

<style lang="scss" scoped>
.state-box {
  display: flex;
  justify-content: center;
  padding: 120rpx 0;
}

.essay-list {
  display: flex;
  flex-direction: column;
  gap: 18rpx;
}

.essay-card {
  padding: 24rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 18rpx;
  box-shadow: var(--shadow-sm);
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
  padding: 14rpx 18rpx;
  margin-top: 14rpx;
  font-size: 24rpx;
  color: #166534;
  background: #f0fdf4;
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
  margin-top: 12rpx;
  display: flex;
  justify-content: center;
}
</style>
