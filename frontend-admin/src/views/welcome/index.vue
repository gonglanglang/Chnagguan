<script setup lang="ts">
import { ref, onMounted, nextTick, onBeforeUnmount } from "vue";
import { useRouter } from "vue-router";
import * as echarts from "echarts";
import { getDashboardOverview, type DashboardOverview } from "@/api/guoguanla";

defineOptions({
  name: "Welcome"
});

const router = useRouter();
const loading = ref(false);
const overview = ref<DashboardOverview | null>(null);
const chartRef = ref<HTMLElement | null>(null);
let chartInstance: echarts.ECharts | null = null;

async function fetchOverview() {
  loading.value = true;
  try {
    const res = await getDashboardOverview();
    overview.value = res.data;
    await nextTick();
    renderRealmChart();
  } finally {
    loading.value = false;
  }
}

function renderRealmChart() {
  if (!chartRef.value || !overview.value) return;
  if (!chartInstance) {
    chartInstance = echarts.init(chartRef.value);
  }
  const stats = overview.value.realmStats || [];
  chartInstance.setOption({
    tooltip: { trigger: "axis" },
    legend: { data: ["章节数", "题目数", "学生人数"], top: 2, left: "center" },
    grid: { left: 48, right: 48, top: 56, bottom: 28 },
    xAxis: {
      type: "category",
      data: stats.map(s => s.realmName)
    },
    yAxis: [
      { type: "value", name: "章节/题目" },
      { type: "value", name: "学生人数", minInterval: 1 }
    ],
    series: [
      {
        name: "章节数",
        type: "bar",
        itemStyle: { color: "#86efac", borderRadius: [4, 4, 0, 0] },
        data: stats.map(s => s.chapterCount)
      },
      {
        name: "题目数",
        type: "bar",
        itemStyle: { color: "#16a34a", borderRadius: [4, 4, 0, 0] },
        data: stats.map(s => s.questionCount)
      },
      {
        name: "学生人数",
        type: "line",
        yAxisIndex: 1,
        smooth: true,
        itemStyle: { color: "#f59e0b" },
        data: stats.map(s => s.studentCount)
      }
    ]
  });
}

function handleResize() {
  chartInstance?.resize();
}

onMounted(() => {
  fetchOverview();
  window.addEventListener("resize", handleResize);
});

onBeforeUnmount(() => {
  window.removeEventListener("resize", handleResize);
  chartInstance?.dispose();
  chartInstance = null;
});
</script>

<template>
  <div v-loading="loading" class="space-y-4">
    <el-card shadow="never">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 class="text-lg font-bold text-gray-800">过关啦 · 修仙闯关管理后台</h2>
          <p class="mt-1 text-sm text-gray-500">
            管理 练气 → 筑基 → 结丹 → 假婴 → 元婴 → 化神 六大境界难度、进阶考规则与学生境界。
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <el-button type="primary" @click="router.push('/system/realm/index')">
            境界与进阶设置
          </el-button>
          <el-button @click="router.push('/user/index')">学生列表与改境界</el-button>
          <el-button @click="router.push('/bank/question/index')">管理题库</el-button>
        </div>
      </div>
    </el-card>

    <div v-if="overview" class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <el-card shadow="never">
        <div class="text-sm text-gray-500">学生总人数</div>
        <div class="mt-2 flex flex-wrap items-baseline justify-between gap-x-2 gap-y-1">
          <span class="text-3xl font-bold text-green-700">{{ overview.userCount }}</span>
          <el-tag type="success" size="small" class="whitespace-nowrap">
            今日活跃 {{ overview.activeUserCount }}
          </el-tag>
        </div>
      </el-card>

      <el-card shadow="never">
        <div class="text-sm text-gray-500">章节与关卡</div>
        <div class="mt-2 flex flex-wrap items-baseline justify-between gap-x-2 gap-y-1">
          <span class="text-3xl font-bold text-gray-800">{{ overview.chapterCount }}</span>
          <span class="whitespace-nowrap text-xs text-gray-500">共 {{ overview.gateCount }} 道关卡</span>
        </div>
      </el-card>

      <el-card shadow="never">
        <div class="text-sm text-gray-500">题库总题数</div>
        <div class="mt-2 flex flex-wrap items-baseline justify-between gap-x-2 gap-y-1">
          <span class="text-3xl font-bold text-gray-800">{{ overview.questionCount }}</span>
          <span class="whitespace-nowrap text-xs text-gray-500">供六大境界及进阶抽取</span>
        </div>
      </el-card>

      <el-card shadow="never">
        <div class="text-sm text-gray-500">待巩固错题</div>
        <div class="mt-2 flex flex-wrap items-baseline justify-between gap-x-2 gap-y-1">
          <span class="text-3xl font-bold text-amber-600">{{ overview.totalWrongCount }}</span>
          <span class="whitespace-nowrap text-xs text-gray-500">累计作答 {{ overview.totalQuizCount }} 次</span>
        </div>
      </el-card>
    </div>

    <div class="grid grid-cols-1 gap-4 lg:grid-cols-3">
      <el-card shadow="never" class="lg:col-span-2">
        <template #header>
          <div class="font-bold text-gray-800">各境界题库与学生分布</div>
        </template>
        <div ref="chartRef" class="h-80 w-full" />
      </el-card>

      <el-card shadow="never">
        <template #header>
          <div class="font-bold text-gray-800">错题较多章节</div>
        </template>
        <div v-if="overview?.topWrongChapters?.length" class="space-y-3">
          <div
            v-for="(item, idx) in overview.topWrongChapters"
            :key="item.chapterName + idx"
            class="flex items-center justify-between gap-2 rounded border border-gray-100 p-2.5"
          >
            <div class="min-w-0 flex-1 truncate">
              <span class="mr-2 font-bold text-amber-600">{{ idx + 1 }}</span>
              <span class="text-sm text-gray-800">{{ item.chapterName }}</span>
            </div>
            <el-tag type="danger" size="small" class="shrink-0 whitespace-nowrap">
              错 {{ item.wrongCount }} 次
            </el-tag>
          </div>
        </div>
        <el-empty v-else description="暂无错题记录" :image-size="72" />
      </el-card>
    </div>
  </div>
</template>
