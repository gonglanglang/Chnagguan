<script setup lang="ts">
import { ref, onMounted, nextTick, onBeforeUnmount } from "vue";
import { useRouter } from "vue-router";
import * as echarts from "echarts";
import {
  getDashboardOverview,
  getOnlineStudents,
  type DashboardOverview,
  type OnlineStudentSummary
} from "@/api/guoguanla";

defineOptions({
  name: "Welcome"
});

const router = useRouter();
const loading = ref(false);
const refreshingOnline = ref(false);
const overview = ref<DashboardOverview | null>(null);
const onlineSummary = ref<OnlineStudentSummary | null>(null);
const onlineDrawerVisible = ref(false);
const chartRef = ref<HTMLElement | null>(null);
let chartInstance: echarts.ECharts | null = null;
let onlineTimer: number | null = null;

async function fetchOverview() {
  loading.value = true;
  try {
    const res = await getDashboardOverview();
    overview.value = res.data;
    onlineSummary.value = {
      onlineStudentCount: res.data.onlineStudentCount ?? 0,
      onlineWindowMinutes: res.data.onlineWindowMinutes ?? 5,
      serverTime: new Date().toISOString(),
      gradeDistribution: res.data.onlineByGrade || [],
      students: res.data.onlineStudents || []
    };
    await nextTick();
    renderRealmChart();
  } finally {
    loading.value = false;
  }
}

async function refreshOnlineOnly(silent = false) {
  if (!silent) refreshingOnline.value = true;
  try {
    const res = await getOnlineStudents();
    onlineSummary.value = res.data;
    if (overview.value) {
      overview.value.onlineStudentCount = res.data.onlineStudentCount;
      overview.value.onlineWindowMinutes = res.data.onlineWindowMinutes;
      overview.value.onlineByGrade = res.data.gradeDistribution;
      overview.value.onlineStudents = res.data.students;
    }
  } catch {
    // 静默轮询出错不打扰用户
  } finally {
    if (!silent) refreshingOnline.value = false;
  }
}

function formatSecondsAgo(sec: number): string {
  if (!Number.isFinite(sec) || sec <= 5) return "刚刚";
  if (sec < 60) return `${sec} 秒前`;
  const mins = Math.floor(sec / 60);
  return `${mins} 分钟前`;
}

function formatPlatform(platform?: string): string {
  const p = (platform || "app").toLowerCase();
  if (p.includes("android")) return "Android App";
  if (p.includes("ios")) return "iOS App";
  if (p.includes("web") || p.includes("h5")) return "Web 端";
  return "学生端 App";
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
  onlineTimer = window.setInterval(() => {
    void refreshOnlineOnly(true);
  }, 15000);
});

onBeforeUnmount(() => {
  window.removeEventListener("resize", handleResize);
  if (onlineTimer !== null) {
    window.clearInterval(onlineTimer);
    onlineTimer = null;
  }
  chartInstance?.dispose();
  chartInstance = null;
});
</script>

<template>
  <div v-loading="loading" class="space-y-4">
    <el-card shadow="never">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 class="text-lg font-bold text-gray-800">过关啦 · 数学闯关管理后台</h2>
          <p class="mt-1 text-sm text-gray-500">
            管理 初一 → 初二 → 初三 → 高一 → 高二 → 高三 六大学习阶段难度、师资轮播、实时在线学情与数学题库。
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <el-button type="primary" @click="router.push('/system/realm/index')">
            阶段与系统设置
          </el-button>
          <el-button type="success" plain @click="router.push('/banner/index')">
            师资轮播管理
          </el-button>
          <el-button @click="router.push('/user/index')">学生列表与阶段</el-button>
          <el-button @click="router.push('/bank/question/index')">管理题库</el-button>
        </div>
      </div>
    </el-card>

    <!-- 核心统计指标（含实时学生在线人数模块） -->
    <div v-if="overview" class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-5">
      <!-- 实时在线人数模块 -->
      <el-card
        shadow="never"
        class="cursor-pointer border-emerald-200 bg-gradient-to-br from-emerald-50/80 to-white transition hover:border-emerald-400"
        @click="onlineDrawerVisible = true"
      >
        <div class="flex items-center justify-between gap-2">
          <div class="flex items-center gap-2 text-sm font-semibold text-emerald-800">
            <span class="relative flex h-2.5 w-2.5">
              <span
                class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75"
              />
              <span class="relative inline-flex h-2.5 w-2.5 rounded-full bg-emerald-500" />
            </span>
            <span>当前学生在线</span>
          </div>
          <el-button
            link
            type="success"
            size="small"
            :loading="refreshingOnline"
            @click.stop="refreshOnlineOnly(false)"
          >
            刷新
          </el-button>
        </div>
        <div class="mt-2 flex flex-wrap items-baseline justify-between gap-x-2 gap-y-1">
          <div class="flex items-baseline gap-1">
            <span class="text-3xl font-extrabold text-emerald-600">
              {{ onlineSummary?.onlineStudentCount ?? overview.onlineStudentCount ?? 0 }}
            </span>
            <span class="text-xs font-medium text-emerald-700">人在线</span>
          </div>
          <el-tag type="success" size="small" effect="light" class="whitespace-nowrap">
            近 {{ onlineSummary?.onlineWindowMinutes ?? 5 }} 分钟活跃
          </el-tag>
        </div>
        <div class="mt-2 flex items-center justify-between text-[11px] text-slate-500">
          <span class="truncate">
            {{
              onlineSummary?.gradeDistribution?.length
                ? onlineSummary.gradeDistribution.map(g => `${g.gradeName} ${g.count}`).join(" · ")
                : "每 15 秒自动实时刷新"
            }}
          </span>
          <span class="shrink-0 font-semibold text-emerald-700">详情 ›</span>
        </div>
      </el-card>

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
          <span class="whitespace-nowrap text-xs text-gray-500">供初一至高三各阶段抽取</span>
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

    <!-- 当前在线学生实时明细面板 -->
    <el-card shadow="never">
      <template #header>
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex items-center gap-2">
            <span class="font-bold text-gray-800">实时在线学生监控</span>
            <el-tag type="success" size="small" effect="plain">
              当前在线 {{ onlineSummary?.onlineStudentCount ?? 0 }} 人
            </el-tag>
            <span class="text-xs text-gray-400">
              统计近 {{ onlineSummary?.onlineWindowMinutes ?? 5 }} 分钟内在线心跳与学习行为，退出登录即时离线
            </span>
          </div>
          <div class="flex items-center gap-2">
            <el-tag
              v-for="g in onlineSummary?.gradeDistribution || []"
              :key="g.gradeCode"
              size="small"
              type="info"
            >
              {{ g.gradeName }}：{{ g.count }} 人
            </el-tag>
            <el-button size="small" plain :loading="refreshingOnline" @click="refreshOnlineOnly(false)">
              立即刷新
            </el-button>
          </div>
        </div>
      </template>

      <el-table
        v-if="onlineSummary?.students?.length"
        :data="onlineSummary.students"
        size="small"
        stripe
        class="w-full"
      >
        <el-table-column label="学生" min-width="150">
          <template #default="{ row }">
            <div class="flex items-center gap-2">
              <span class="inline-block h-2 w-2 rounded-full bg-emerald-500" />
              <span class="font-semibold text-gray-800">{{ row.nickname }}</span>
              <span class="text-xs text-gray-400">({{ row.username }})</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="当前年级" width="110" align="center">
          <template #default="{ row }">
            <el-tag size="small" type="primary">{{ row.gradeName || row.realmName }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="当前动态" min-width="140">
          <template #default="{ row }">
            <span class="text-xs text-gray-700">{{ row.lastAction || "在线学习" }}</span>
          </template>
        </el-table-column>
        <el-table-column label="终端" width="120" align="center">
          <template #default="{ row }">
            <el-tag size="small" type="info" effect="plain">{{ formatPlatform(row.platform) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="最近活跃" width="120" align="center">
          <template #default="{ row }">
            <span class="text-xs font-medium text-emerald-700">{{ formatSecondsAgo(row.secondsAgo) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" align="center">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="router.push(`/user/detail/${row.userId}`)">
              查看学情
            </el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-else class="flex items-center justify-center py-6 text-sm text-gray-400">
        当前暂无已登录学生在线（学生打开 App 登录后将实时出现在此列表中）
      </div>
    </el-card>

    <div class="grid grid-cols-1 gap-4 lg:grid-cols-3">
      <el-card shadow="never" class="lg:col-span-2">
        <template #header>
          <div class="font-bold text-gray-800">各年级阶段题库与学生分布</div>
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

    <!-- 点击顶部在线卡片弹出的详情抽屉 -->
    <el-drawer
      v-model="onlineDrawerVisible"
      title="当前在线学生实时列表"
      size="520px"
    >
      <div class="mb-4 flex items-center justify-between rounded-lg bg-emerald-50 p-3">
        <div>
          <div class="text-xs text-emerald-700">当前在线总人数</div>
          <div class="text-2xl font-bold text-emerald-700">
            {{ onlineSummary?.onlineStudentCount ?? 0 }} 人
          </div>
        </div>
        <el-button type="success" size="small" :loading="refreshingOnline" @click="refreshOnlineOnly(false)">
          立即刷新
        </el-button>
      </div>
      <div v-if="onlineSummary?.students?.length" class="space-y-2.5">
        <div
          v-for="stu in onlineSummary.students"
          :key="stu.userId"
          class="flex items-center justify-between rounded-lg border border-gray-100 p-3"
        >
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="inline-block h-2 w-2 rounded-full bg-emerald-500" />
              <span class="font-semibold text-gray-800">{{ stu.nickname }}</span>
              <el-tag size="small">{{ stu.gradeName }}</el-tag>
            </div>
            <div class="mt-1 text-xs text-gray-500">
              {{ stu.lastAction }} · {{ formatPlatform(stu.platform) }} · {{ formatSecondsAgo(stu.secondsAgo) }}
            </div>
          </div>
          <el-button link type="primary" size="small" @click="router.push(`/user/detail/${stu.userId}`)">
            详情
          </el-button>
        </div>
      </div>
      <el-empty v-else description="当前暂无学生在线" />
    </el-drawer>
  </div>
</template>
