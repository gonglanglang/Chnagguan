<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import MathFormulaText from "@/components/MathFormulaText.vue";
import {
  getUserPage,
  getUserDetail,
  createUser,
  updateUser,
  updateUserPassword,
  updateUserRealm,
  updateUserStatus,
  deleteUser,
  getUserQuizRecordDetail,
  getUserEssayAnswers,
  reviewEssayAnswer,
  getRealms,
  type StudentUser,
  type StudentDetail,
  type QuizSessionItem,
  type EssayAnswerItem,
  type RealmConfig
} from "@/api/guoguanla";

defineOptions({
  name: "StudentUserManage"
});

const loading = ref(false);
const tableData = ref<StudentUser[]>([]);
const total = ref(0);
const realms = ref<RealmConfig[]>([]);

const query = reactive({
  keyword: "",
  realmCode: "",
  status: undefined as number | undefined,
  pageNum: 1,
  pageSize: 10
});

// 详情抽屉
const detailVisible = ref(false);
const detailLoading = ref(false);
const detailUserId = ref<number | null>(null);
const detailData = ref<StudentDetail | null>(null);
const essayList = ref<EssayAnswerItem[]>([]);
const essayLoading = ref(false);

// 单次作答逐题明细弹窗
const sessionDialogVisible = ref(false);
const sessionDetailLoading = ref(false);
const sessionDetailTitle = ref("");
const sessionItems = ref<QuizSessionItem[]>([]);

// 老师批改解答题弹窗
const reviewDialogVisible = ref(false);
const reviewTarget = ref<EssayAnswerItem | null>(null);
const reviewSaving = ref(false);
const reviewForm = reactive({
  teacherStatus: 1,
  teacherComment: ""
});

// 新增 / 编辑弹窗
const dialogVisible = ref(false);
const isEdit = ref(false);
const editId = ref<number | null>(null);
const saving = ref(false);
const form = reactive({
  username: "",
  password: "",
  nickname: "",
  realmCode: "lianqi",
  remark: ""
});

// 快捷修改密码弹窗
const pwdDialogVisible = ref(false);
const pwdTargetUser = ref<StudentUser | null>(null);
const savingPwd = ref(false);
const pwdForm = reactive({
  password: "",
  confirmPassword: ""
});

// 快捷修改境界弹窗
const realmDialogVisible = ref(false);
const realmTargetUser = ref<StudentUser | null>(null);
const selectedRealmCode = ref("lianqi");
const savingRealm = ref(false);

async function loadRealms() {
  const res = await getRealms();
  realms.value = res.data;
}

async function fetchUsers() {
  loading.value = true;
  try {
    const res = await getUserPage(query);
    tableData.value = res.data.records;
    total.value = res.data.total;
  } finally {
    loading.value = false;
  }
}

function handleSearch() {
  query.pageNum = 1;
  fetchUsers();
}

function handleReset() {
  query.keyword = "";
  query.realmCode = "";
  query.status = undefined;
  query.pageNum = 1;
  fetchUsers();
}

async function loadUserEssays(userId: number) {
  essayLoading.value = true;
  try {
    const res = await getUserEssayAnswers(userId, { pageNum: 1, pageSize: 20 });
    essayList.value = res.data.records;
  } finally {
    essayLoading.value = false;
  }
}

async function openDetail(row: StudentUser) {
  detailUserId.value = row.id;
  detailVisible.value = true;
  detailLoading.value = true;
  try {
    const res = await getUserDetail(row.id);
    detailData.value = res.data;
  } finally {
    detailLoading.value = false;
  }
  void loadUserEssays(row.id);
}

async function openSessionDetail(row: StudentDetail["recentRecords"][number]) {
  if (!detailUserId.value) return;
  sessionDetailTitle.value = `${row.chapterName} · ${row.gateName}（${row.sessionNo}）`;
  sessionDialogVisible.value = true;
  sessionDetailLoading.value = true;
  try {
    const res = await getUserQuizRecordDetail(detailUserId.value, row.sessionNo);
    sessionItems.value = res.data;
  } finally {
    sessionDetailLoading.value = false;
  }
}

function openReviewDialog(item: EssayAnswerItem) {
  reviewTarget.value = item;
  reviewForm.teacherStatus = item.teacherStatus === 2 ? 2 : 1;
  reviewForm.teacherComment = item.teacherComment || "";
  reviewDialogVisible.value = true;
}

async function submitReview() {
  if (!reviewTarget.value) return;
  reviewSaving.value = true;
  try {
    await reviewEssayAnswer(reviewTarget.value.id, {
      teacherStatus: reviewForm.teacherStatus,
      teacherComment: reviewForm.teacherComment.trim()
    });
    ElMessage.success("批改结果已保存");
    reviewDialogVisible.value = false;
    if (detailUserId.value) {
      await loadUserEssays(detailUserId.value);
    }
  } finally {
    reviewSaving.value = false;
  }
}

function openCreate() {
  isEdit.value = false;
  editId.value = null;
  form.username = "";
  form.password = "";
  form.nickname = "";
  form.realmCode = "lianqi";
  form.remark = "";
  dialogVisible.value = true;
}

function openEdit(row: StudentUser) {
  isEdit.value = true;
  editId.value = row.id;
  form.username = row.username;
  form.password = "";
  form.nickname = row.nickname;
  form.realmCode = row.realmCode || "lianqi";
  form.remark = row.remark || "";
  dialogVisible.value = true;
}

function openPasswordDialog(row: StudentUser) {
  pwdTargetUser.value = row;
  pwdForm.password = "";
  pwdForm.confirmPassword = "";
  pwdDialogVisible.value = true;
}

async function confirmPasswordReset() {
  if (!pwdTargetUser.value) return;
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
    await updateUserPassword(pwdTargetUser.value.id, pwd);
    ElMessage.success(`已修改「${pwdTargetUser.value.nickname}」的登录密码`);
    pwdDialogVisible.value = false;
  } finally {
    savingPwd.value = false;
  }
}

function openRealmAdjust(row: StudentUser) {
  realmTargetUser.value = row;
  selectedRealmCode.value = row.realmCode || "lianqi";
  realmDialogVisible.value = true;
}

async function confirmRealmAdjust() {
  if (!realmTargetUser.value) return;
  savingRealm.value = true;
  try {
    await updateUserRealm(realmTargetUser.value.id, selectedRealmCode.value);
    ElMessage.success("已调整学生修仙境界");
    realmDialogVisible.value = false;
    fetchUsers();
  } finally {
    savingRealm.value = false;
  }
}

async function handleSave() {
  if (!form.nickname.trim()) {
    ElMessage.warning("请输入学生昵称");
    return;
  }
  if (isEdit.value && form.password.trim() && form.password.trim().length < 6) {
    ElMessage.warning("重置密码长度不能少于 6 位");
    return;
  }
  saving.value = true;
  try {
    if (isEdit.value && editId.value) {
      const payload: Record<string, any> = {
        nickname: form.nickname.trim(),
        realmCode: form.realmCode,
        remark: form.remark
      };
      if (form.password.trim()) {
        payload.password = form.password.trim();
      }
      await updateUser(editId.value, payload);
      ElMessage.success(form.password.trim() ? "学生信息及密码已更新" : "学生信息已更新");
    } else {
      if (!form.username.trim() || form.password.trim().length < 6) {
        ElMessage.warning("请填写登录账号及不少于 6 位的密码");
        return;
      }
      await createUser({
        username: form.username.trim(),
        password: form.password.trim(),
        nickname: form.nickname.trim(),
        realmCode: form.realmCode,
        remark: form.remark
      });
      ElMessage.success("新增学生成功");
    }
    dialogVisible.value = false;
    fetchUsers();
  } finally {
    saving.value = false;
  }
}

async function handleToggleStatus(row: StudentUser) {
  const nextStatus = row.status === 1 ? 0 : 1;
  const label = nextStatus === 1 ? "启用" : "禁用";
  await ElMessageBox.confirm(`确认${label}学生「${row.nickname}」的账号吗？`, "提示", {
    type: "warning"
  });
  await updateUserStatus(row.id, nextStatus);
  ElMessage.success(`已${label}`);
  fetchUsers();
}

async function handleDelete(row: StudentUser) {
  await ElMessageBox.confirm(`确认删除学生「${row.nickname}」？删除后不可恢复。`, "确认删除", {
    type: "warning"
  });
  await deleteUser(row.id);
  ElMessage.success("已删除");
  fetchUsers();
}

onMounted(() => {
  loadRealms();
  fetchUsers();
});
</script>

<template>
  <div class="space-y-4">
    <el-card shadow="never">
      <el-form :inline="true" :model="query" class="flex flex-wrap items-center gap-y-2">
        <el-form-item label="学生">
          <el-input
            v-model="query.keyword"
            placeholder="姓名 / 账号"
            clearable
            style="width: 190px"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="当前境界">
          <el-select v-model="query.realmCode" placeholder="全部境界" clearable style="width: 190px">
            <el-option
              v-for="r in realms"
              :key="r.realmCode"
              :label="`${r.realmName}（${r.difficultyLabel}）`"
              :value="r.realmCode"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="query.status" placeholder="全部" clearable style="width: 120px">
            <el-option label="正常" :value="1" />
            <el-option label="禁用" :value="0" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <div class="flex items-center gap-2 whitespace-nowrap">
            <el-button type="primary" @click="handleSearch">查询</el-button>
            <el-button @click="handleReset">重置</el-button>
            <el-button type="success" @click="openCreate">+ 新增学生</el-button>
          </div>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never">
      <el-table v-loading="loading" :data="tableData" border stripe>
        <el-table-column prop="id" label="ID" width="64" align="center" />
        <el-table-column label="学生信息" min-width="160">
          <template #default="{ row }">
            <div class="truncate font-semibold text-gray-800">{{ row.nickname }}</div>
            <div class="truncate text-xs text-gray-500">账号：{{ row.username || "-" }}</div>
          </template>
        </el-table-column>
        <el-table-column label="当前修仙境界" min-width="176">
          <template #default="{ row }">
            <div class="flex flex-nowrap items-center gap-2 whitespace-nowrap">
              <el-tag type="success" class="shrink-0">{{ row.realmName || "练气" }}</el-tag>
              <el-button link type="primary" size="small" class="shrink-0" @click="openRealmAdjust(row)">
                修改境界
              </el-button>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="已过关卡" width="104" align="center">
          <template #default="{ row }">
            <span class="whitespace-nowrap">{{ row.passedGateCount }} 关</span>
          </template>
        </el-table-column>
        <el-table-column label="待巩固错题" width="118" align="center">
          <template #default="{ row }">
            <el-tag :type="row.wrongCount > 0 ? 'warning' : 'info'" size="small" class="whitespace-nowrap">
              {{ row.wrongCount }} 题
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="84" align="center">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'" size="small" class="whitespace-nowrap">
              {{ row.status === 1 ? "正常" : "禁用" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="最近学习时间" width="182" align="center">
          <template #default="{ row }">
            <span class="whitespace-nowrap">{{ row.lastActiveAt || "-" }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="268" align="center">
          <template #default="{ row }">
            <div class="inline-flex items-center justify-center whitespace-nowrap">
              <el-button link type="primary" @click="openDetail(row)">战绩</el-button>
              <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
              <el-button link type="warning" @click="openPasswordDialog(row)">改密</el-button>
              <el-button
                link
                :type="row.status === 1 ? 'warning' : 'success'"
                @click="handleToggleStatus(row)"
              >
                {{ row.status === 1 ? "禁用" : "启用" }}
              </el-button>
              <el-button link type="danger" @click="handleDelete(row)">删除</el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>

      <div class="mt-4 flex justify-end">
        <el-pagination
          v-model:current-page="query.pageNum"
          v-model:page-size="query.pageSize"
          :total="total"
          :page-sizes="[10, 20, 50]"
          layout="total, sizes, prev, pager, next"
          @current-change="fetchUsers"
          @size-change="fetchUsers"
        />
      </div>
    </el-card>

    <!-- 快捷修改学生密码弹窗 -->
    <el-dialog v-model="pwdDialogVisible" title="修改学生登录密码" width="420px">
      <div v-if="pwdTargetUser" class="space-y-4">
        <div class="text-sm text-gray-600">
          正在重置学生 <span class="font-bold text-gray-900">{{ pwdTargetUser.nickname }}</span>
          （账号：{{ pwdTargetUser.username }}）的登录密码：
        </div>
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
      </div>
      <template #footer>
        <el-button @click="pwdDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingPwd" @click="confirmPasswordReset">
          确认修改
        </el-button>
      </template>
    </el-dialog>

    <!-- 快捷调整学生境界弹窗 -->
    <el-dialog v-model="realmDialogVisible" title="修改学生修仙境界" width="440px">
      <div v-if="realmTargetUser" class="space-y-4">
        <div class="text-sm text-gray-600">
          正在为学生 <span class="font-bold text-gray-900">{{ realmTargetUser.nickname }}</span>
          设定境界（修改后立即生效，低境界题目可通过压制境界继续作答）：
        </div>
        <div class="grid grid-cols-2 gap-2.5">
          <div
            v-for="r in realms"
            :key="r.realmCode"
            class="cursor-pointer rounded-lg border p-3 transition"
            :class="
              selectedRealmCode === r.realmCode
                ? 'border-green-600 bg-green-50 text-green-800'
                : 'border-gray-200 hover:border-green-400'
            "
            @click="selectedRealmCode = r.realmCode"
          >
            <div class="font-bold">{{ r.realmName }}</div>
            <div class="mt-0.5 text-xs text-gray-500">{{ r.difficultyLabel }}</div>
          </div>
        </div>
      </div>
      <template #footer>
        <el-button @click="realmDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingRealm" @click="confirmRealmAdjust">
          确认修改
        </el-button>
      </template>
    </el-dialog>

    <!-- 学生战绩详情抽屉 -->
    <el-drawer v-model="detailVisible" title="学生详情、答题记录与批改" size="780px">
      <div v-loading="detailLoading" class="space-y-6">
        <template v-if="detailData">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="学生姓名">{{ detailData.profile.nickname }}</el-descriptions-item>
            <el-descriptions-item label="登录账号">{{ detailData.profile.username }}</el-descriptions-item>
            <el-descriptions-item label="当前境界">
              <el-tag type="success" size="small">{{ detailData.profile.realmName }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="累计过关">{{ detailData.profile.passedGateCount }} 关</el-descriptions-item>
            <el-descriptions-item label="备注" :span="2">{{ detailData.profile.remark || "-" }}</el-descriptions-item>
          </el-descriptions>

          <div>
            <h4 class="mb-2 font-bold text-gray-800">解答题手写作答与批改（阿里云 OSS 图）</h4>
            <div v-loading="essayLoading" class="space-y-3">
              <template v-if="essayList.length">
                <el-card v-for="item in essayList" :key="item.id" shadow="never">
                  <div class="flex flex-wrap items-center justify-between gap-2">
                    <div class="text-xs text-gray-500">
                      {{ item.chapterName || "解答练习" }} · {{ item.gateName || "-" }} · {{ item.createdAt }}
                    </div>
                    <div class="flex items-center gap-2 whitespace-nowrap">
                      <el-tag
                        v-if="item.selfCorrect !== null"
                        size="small"
                        :type="item.selfCorrect === 1 ? 'success' : 'warning'"
                      >
                        {{ item.selfCorrect === 1 ? "学生自评：正确" : "学生自评：待巩固" }}
                      </el-tag>
                      <el-tag
                        size="small"
                        :type="item.teacherStatus === 1 ? 'success' : item.teacherStatus === 2 ? 'danger' : 'info'"
                      >
                        {{ item.teacherStatus === 1 ? "老师批改：通过" : item.teacherStatus === 2 ? "老师批改：待订正" : "待批改" }}
                      </el-tag>
                      <el-button link type="primary" size="small" @click="openReviewDialog(item)">
                        批改点评
                      </el-button>
                    </div>
                  </div>
                  <div class="mt-2 font-medium text-gray-800">
                    <MathFormulaText :text="item.stem" />
                  </div>
                  <div v-if="item.answerText" class="mt-2 rounded bg-gray-50 px-3 py-2 text-xs text-gray-700">
                    学生文字作答：{{ item.answerText }}
                  </div>
                  <div v-if="item.answerImageUrl" class="mt-2">
                    <div class="mb-1 text-xs text-gray-500">手写画板作答图（点击可查看大图）：</div>
                    <el-image
                      :src="item.answerImageUrl"
                      :preview-src-list="[item.answerImageUrl]"
                      preview-teleported
                      fit="contain"
                      class="h-36 w-60 rounded border border-gray-200 bg-white"
                    />
                  </div>
                  <div v-if="item.teacherComment" class="mt-2 text-xs text-green-700">
                    老师点评：{{ item.teacherComment }}
                  </div>
                </el-card>
              </template>
              <el-empty v-else description="暂无解答题画板作答记录" :image-size="60" />
            </div>
          </div>

          <div>
            <h4 class="mb-2 font-bold text-gray-800">最近作答与进阶考核记录</h4>
            <el-table v-if="detailData.recentRecords.length" :data="detailData.recentRecords" size="small" border>
              <el-table-column prop="chapterName" label="内容" min-width="160" />
              <el-table-column prop="gateName" label="关卡/目标" min-width="120" />
              <el-table-column label="得分" width="128" align="center">
                <template #default="{ row }">
                  <span class="whitespace-nowrap">
                    {{ row.correctCount }} / {{ row.totalCount }}
                    <span v-if="row.mode === 'ADVANCE_EXAM' && row.score !== undefined">
                      ({{ row.score }}分)
                    </span>
                  </span>
                </template>
              </el-table-column>
              <el-table-column label="结果" width="84" align="center">
                <template #default="{ row }">
                  <el-tag size="small" class="whitespace-nowrap" :type="row.isPassed === 1 ? 'success' : 'info'">
                    {{ row.isPassed === 1 ? "通过" : "未过" }}
                  </el-tag>
                </template>
              </el-table-column>
              <el-table-column label="明细" width="90" align="center">
                <template #default="{ row }">
                  <el-button link type="primary" size="small" @click="openSessionDetail(row)">
                    查看答卷
                  </el-button>
                </template>
              </el-table-column>
            </el-table>
            <el-empty v-else description="暂无答题记录" :image-size="60" />
          </div>

          <div>
            <h4 class="mb-2 font-bold text-gray-800">章节通关情况</h4>
            <el-table v-if="detailData.chapterProgress.length" :data="detailData.chapterProgress" size="small" border>
              <el-table-column prop="chapterName" label="章节" min-width="180" />
              <el-table-column label="已通关卡" width="124" align="center">
                <template #default="{ row }">
                  <span class="whitespace-nowrap">{{ row.passedCount }} / {{ row.totalGates }} 关</span>
                </template>
              </el-table-column>
            </el-table>
            <el-empty v-else description="暂无章节过关记录" :image-size="60" />
          </div>
        </template>
      </div>
    </el-drawer>

    <!-- 答题会话逐题详情弹窗 -->
    <el-dialog v-model="sessionDialogVisible" :title="sessionDetailTitle" width="720px">
      <div v-loading="sessionDetailLoading" class="max-h-[70vh] space-y-3 overflow-y-auto pr-1">
        <el-card v-for="item in sessionItems" :key="item.itemIndex" shadow="never">
          <div class="flex items-center justify-between">
            <span class="text-xs font-bold text-gray-500">
              第 {{ item.itemIndex + 1 }} 题 · {{ item.questionFormat === "ESSAY" ? "解答题" : "选择题" }}
            </span>
            <el-tag size="small" :type="item.correct ? 'success' : 'danger'">
              {{ item.correct ? "正确" : "错误/未对" }}
            </el-tag>
          </div>
          <div class="mt-1.5 font-medium text-gray-800">
            <MathFormulaText :text="item.stem" />
          </div>
          <template v-if="item.questionFormat === 'ESSAY'">
            <div v-if="item.userAnswerText" class="mt-2 rounded bg-gray-50 p-2 text-xs text-gray-700">
              学生文字作答：{{ item.userAnswerText }}
            </div>
            <div v-if="item.userAnswerImageUrl" class="mt-2">
              <div class="mb-1 text-xs text-gray-500">手写作答图片：</div>
              <el-image
                :src="item.userAnswerImageUrl"
                :preview-src-list="[item.userAnswerImageUrl]"
                preview-teleported
                fit="contain"
                class="h-40 w-64 rounded border border-gray-200 bg-white"
              />
            </div>
            <div v-if="item.referenceAnswer" class="mt-2 text-xs text-green-700">
              参考答案：<MathFormulaText :text="item.referenceAnswer" inline />
            </div>
          </template>
          <template v-else-if="item.options?.length">
            <div class="mt-2 flex flex-wrap gap-1.5 text-xs">
              <span
                v-for="(op, idx) in item.options"
                :key="idx"
                class="rounded px-2 py-0.5"
                :class="
                  idx === item.answerIndex
                    ? 'bg-green-100 font-bold text-green-800'
                    : idx === item.userIndex
                      ? 'bg-red-100 text-red-700'
                      : 'bg-gray-100 text-gray-600'
                "
              >
                {{ "ABCD"[idx] }}. <MathFormulaText :text="op" inline />
                <template v-if="idx === item.userIndex">（学生所选）</template>
              </span>
            </div>
          </template>
        </el-card>
      </div>
    </el-dialog>

    <!-- 老师批改解答题弹窗 -->
    <el-dialog v-model="reviewDialogVisible" title="批改学生解答题" width="460px">
      <div v-if="reviewTarget" class="space-y-4">
        <div class="rounded bg-gray-50 p-3 text-sm text-gray-800">
          <MathFormulaText :text="reviewTarget.stem" />
        </div>
        <el-form label-width="88px">
          <el-form-item label="批改结论" required>
            <el-radio-group v-model="reviewForm.teacherStatus">
              <el-radio :value="1">通过（解答正确）</el-radio>
              <el-radio :value="2">待订正（步骤或结果有误）</el-radio>
            </el-radio-group>
          </el-form-item>
          <el-form-item label="老师评语">
            <el-input
              v-model="reviewForm.teacherComment"
              type="textarea"
              :rows="3"
              placeholder="可选填点评，学生可在个人端查看"
            />
          </el-form-item>
        </el-form>
      </div>
      <template #footer>
        <el-button @click="reviewDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="reviewSaving" @click="submitReview">保存批改</el-button>
      </template>
    </el-dialog>

    <!-- 新增 / 编辑学生弹窗 -->
    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑学生信息' : '新增学生'" width="460px">
      <el-form label-width="96px">
        <el-form-item v-if="!isEdit" label="登录账号" required>
          <el-input v-model="form.username" placeholder="如 stu_zhangsan" />
        </el-form-item>
        <el-form-item v-if="!isEdit" label="登录密码" required>
          <el-input v-model="form.password" type="password" show-password placeholder="至少 6 位" />
        </el-form-item>
        <el-form-item v-else label="重置密码">
          <el-input
            v-model="form.password"
            type="password"
            show-password
            placeholder="留空不修改；填写至少 6 位则重置密码"
          />
        </el-form-item>
        <el-form-item label="学生昵称" required>
          <el-input v-model="form.nickname" placeholder="学生姓名或昵称" />
        </el-form-item>
        <el-form-item label="当前境界" required>
          <el-select v-model="form.realmCode" class="w-full">
            <el-option
              v-for="r in realms"
              :key="r.realmCode"
              :label="`${r.realmName}（${r.difficultyLabel}）`"
              :value="r.realmCode"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="form.remark" type="textarea" :rows="2" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>
