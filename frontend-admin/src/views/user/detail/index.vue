<script setup lang="ts">
import { ref, reactive, computed, onMounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import MathFormulaText from "@/components/MathFormulaText.vue";
import GglIcon from "@/components/GglIcon/index.vue";
import {
  getUserDetail,
  getUserEssayAnswers,
  getRealms,
  updateUserRealm,
  updateUserPassword,
  type StudentDetail,
  type EssayAnswerItem,
  type RealmConfig
} from "@/api/guoguanla";

defineOptions({
  name: "StudentUserDetail"
});

const route = useRoute();
const router = useRouter();

const userId = computed(() => Number(route.params.id || 0));

const loading = ref(false);
const essayLoading = ref(false);
const detailData = ref<StudentDetail | null>(null);
const essayList = ref<EssayAnswerItem[]>([]);
const essayTotal = ref(0);
const essayPage = ref(1);
const statusFilter = ref<"ALL" | "1" | "2">("ALL");
const activeTab = ref("homework");

const realms = ref<RealmConfig[]>([]);
const realmDialogVisible = ref(false);
const selectedRealmCode = ref("lianqi");
const savingRealm = ref(false);

const pwdDialogVisible = ref(false);
const savingPwd = ref(false);
const pwdForm = reactive({
  password: "",
  confirmPassword: ""
});

const filteredEssays = computed(() => {
  if (statusFilter.value === "ALL") return essayList.value;
  return essayList.value.filter(e => String(e.aiStatus) === statusFilter.value);
});

async function loadData() {
  if (!userId.value) return;
  loading.value = true;
  try {
    const [detailRes, realmRes] = await Promise.all([getUserDetail(userId.value), getRealms()]);
    detailData.value = detailRes.data;
    realms.value = realmRes.data;
    selectedRealmCode.value = detailRes.data.profile.realmCode || "lianqi";
  } finally {
    loading.value = false;
  }
}

async function loadEssays() {
  if (!userId.value) return;
  essayLoading.value = true;
  try {
    const res = await getUserEssayAnswers(userId.value, { pageNum: essayPage.value, pageSize: 20 });
    essayList.value = res.data.records;
    essayTotal.value = res.data.total;
  } finally {
    essayLoading.value = false;
  }
}

function goBack() {
  router.push("/user/index");
}

async function confirmRealmAdjust() {
  if (!detailData.value) return;
  savingRealm.value = true;
  try {
    await updateUserRealm(detailData.value.profile.id, selectedRealmCode.value);
    ElMessage.success("已调整学生学习阶段");
    realmDialogVisible.value = false;
    await loadData();
  } finally {
    savingRealm.value = false;
  }
}

function openPasswordDialog() {
  pwdForm.password = "";
  pwdForm.confirmPassword = "";
  pwdDialogVisible.value = true;
}

async function confirmPasswordReset() {
  if (!detailData.value) return;
  const pwd = pwdForm.password.trim();
  if (pwd.length < 6) {
    ElMessage.warning("新密码长度不能少于 6 位");
    return;
  }
  if (pwd !== pwdForm.confirmPassword.trim()) {
    ElMessage.warning("两次输入的密码不一致");
    return;
  }
  savingPwd.value = true;
  try {
    await updateUserPassword(detailData.value.profile.id, pwd);
    ElMessage.success("学生登录密码已更新");
    pwdDialogVisible.value = false;
  } finally {
    savingPwd.value = false;
  }
}

onMounted(async () => {
  await Promise.all([loadData(), loadEssays()]);
});
</script>

<template>
  <div v-loading="loading" class="space-y-4">
    <!-- 顶部学生基本信息卡 -->
    <el-card v-if="detailData" shadow="never">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex items-center gap-4">
          <el-button plain @click="goBack">
            <GglIcon name="back" :size="15" class="mr-1" />
            返回列表
          </el-button>

          <el-avatar
            :size="56"
            :src="detailData.profile.avatarUrl || undefined"
            class="shrink-0 bg-green-100 text-lg font-bold text-green-700"
          >
            {{ (detailData.profile.nickname || "学").slice(0, 1) }}
          </el-avatar>

          <div>
            <div class="flex items-center gap-2">
              <span class="text-lg font-bold text-slate-800">{{ detailData.profile.nickname }}</span>
              <el-tag type="success" size="small">{{ detailData.profile.realmName || "初一" }}</el-tag>
              <el-tag :type="detailData.profile.status === 1 ? 'success' : 'danger'" size="small">
                {{ detailData.profile.status === 1 ? "正常" : "禁用" }}
              </el-tag>
            </div>
            <div class="mt-1 flex flex-wrap items-center gap-x-5 gap-y-1 text-xs text-slate-500">
              <span>账号：{{ detailData.profile.username || "-" }}</span>
              <span>已过关卡：{{ detailData.profile.passedGateCount }} 关</span>
              <span>待巩固错题：{{ detailData.profile.wrongCount }} 题</span>
              <span>最近学习：{{ detailData.profile.lastActiveAt || "-" }}</span>
              <span v-if="detailData.profile.remark">备注：{{ detailData.profile.remark }}</span>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <el-button plain type="primary" @click="realmDialogVisible = true">调整阶段</el-button>
          <el-button plain type="warning" @click="openPasswordDialog">修改密码</el-button>
        </div>
      </div>
    </el-card>

    <!-- 底部 Tabs：只读展示 AI 解答批改记录（已全面升级为 AI 自动判题） -->
    <el-card shadow="never">
      <el-tabs v-model="activeTab">
        <el-tab-pane label="AI 解答记录" name="homework">
          <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div class="flex items-center gap-2">
              <el-radio-group v-model="statusFilter" size="small">
                <el-radio-button value="ALL">全部 ({{ essayList.length }})</el-radio-button>
                <el-radio-button value="1">AI 判对通过</el-radio-button>
                <el-radio-button value="2">AI 判错待订正</el-radio-button>
              </el-radio-group>
              <span class="text-xs text-slate-400">
                说明：解答题由 AI 大模型实时判题评分并同步错题本，无需后台人工批改
              </span>
            </div>
            <el-button size="small" @click="loadEssays">刷新列表</el-button>
          </div>

          <div v-loading="essayLoading" class="space-y-3">
            <template v-if="filteredEssays.length > 0">
              <div
                v-for="item in filteredEssays"
                :key="item.id"
                class="rounded-xl border border-slate-200 bg-slate-50/60 p-4"
              >
                <div class="flex flex-wrap items-center justify-between gap-2 border-b border-slate-200 pb-2.5">
                  <div class="flex items-center gap-2 text-xs text-slate-600">
                    <el-tag size="small" type="info">{{ item.realmName || "数学题库" }}</el-tag>
                    <span class="font-semibold text-slate-700">{{ item.chapterName || "章节练习" }}</span>
                    <span>·</span>
                    <span>{{ item.gateName || "-" }}</span>
                    <span class="text-slate-400">| 提交于 {{ item.createdAt }}</span>
                  </div>

                  <div class="flex items-center gap-2">
                    <el-tag
                      size="small"
                      :type="item.aiStatus === 1 ? 'success' : item.aiStatus === 2 ? 'danger' : 'info'"
                    >
                      {{
                        item.aiStatus === 1
                          ? `AI 判对通过${item.aiScore != null ? ` · ${item.aiScore}分` : ""}`
                          : item.aiStatus === 2
                            ? `AI 判错（已入错题）${item.aiScore != null ? ` · ${item.aiScore}分` : ""}`
                            : "未判题"
                      }}
                    </el-tag>
                    <el-tag v-if="item.aiModel" size="small" type="info" effect="plain">
                      {{ item.aiModel }}
                    </el-tag>
                  </div>
                </div>

                <div class="mt-3 grid grid-cols-1 gap-4 lg:grid-cols-12">
                  <div class="space-y-2 lg:col-span-7">
                    <div class="text-sm font-semibold text-slate-800">
                      <MathFormulaText :text="item.stem" />
                    </div>
                    <div v-if="item.referenceAnswer" class="rounded bg-green-50 px-3 py-2 text-xs text-green-800">
                      参考答案：<MathFormulaText :text="item.referenceAnswer" inline />
                    </div>
                    <div v-if="item.answerText" class="rounded bg-white px-3 py-2 text-xs text-slate-700">
                      学生文字作答：{{ item.answerText }}
                    </div>
                    <div v-if="item.aiComment" class="rounded bg-sky-50 px-3 py-2 text-xs text-sky-900">
                      AI 批改点评：{{ item.aiComment }}
                    </div>
                  </div>

                  <div v-if="item.answerImageUrl" class="flex flex-wrap gap-3 lg:col-span-5">
                    <div>
                      <div class="mb-1 text-xs text-slate-500">学生手写作答</div>
                      <el-image
                        :src="item.answerImageUrl"
                        :preview-src-list="[item.answerImageUrl]"
                        preview-teleported
                        fit="contain"
                        class="h-36 w-56 rounded border border-slate-200 bg-white"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </template>
            <el-empty v-else description="暂无学生解答题 AI 批改记录" />
          </div>

          <div v-if="essayTotal > 20" class="mt-4 flex justify-end">
            <el-pagination
              v-model:current-page="essayPage"
              :page-size="20"
              :total="essayTotal"
              layout="total, prev, pager, next"
              @current-change="loadEssays"
            />
          </div>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <!-- 调整学习阶段弹窗 -->
    <el-dialog v-model="realmDialogVisible" title="修改学生学习阶段" width="440px">
      <div class="grid grid-cols-2 gap-2.5">
        <div
          v-for="r in realms"
          :key="r.realmCode"
          class="cursor-pointer rounded-lg border p-3 transition"
          :class="
            selectedRealmCode === r.realmCode
              ? 'border-green-600 bg-green-50 text-green-800'
              : 'border-slate-200 hover:border-green-400'
          "
          @click="selectedRealmCode = r.realmCode"
        >
          <div class="font-bold">{{ r.realmName }}</div>
          <div class="mt-0.5 text-xs text-slate-500">{{ r.difficultyLabel }}</div>
        </div>
      </div>
      <template #footer>
        <el-button @click="realmDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingRealm" @click="confirmRealmAdjust">确认修改</el-button>
      </template>
    </el-dialog>

    <!-- 修改密码弹窗 -->
    <el-dialog v-model="pwdDialogVisible" title="修改学生登录密码" width="420px">
      <el-form label-width="90px">
        <el-form-item label="新密码" required>
          <el-input
            v-model="pwdForm.password"
            type="password"
            show-password
            placeholder="请输入不少于 6 位新密码"
          />
        </el-form-item>
        <el-form-item label="确认密码" required>
          <el-input
            v-model="pwdForm.confirmPassword"
            type="password"
            show-password
            placeholder="请再次输入新密码"
            @keyup.enter="confirmPasswordReset"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="pwdDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingPwd" @click="confirmPasswordReset">确认修改</el-button>
      </template>
    </el-dialog>
  </div>
</template>
