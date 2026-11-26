<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { useRouter } from "vue-router";
import { ElMessage, ElMessageBox } from "element-plus";
import {
  getUserPage,
  createUser,
  updateUser,
  updateUserPassword,
  updateUserRealm,
  updateUserStatus,
  deleteUser,
  getRealms,
  type StudentUser,
  type RealmConfig
} from "@/api/guoguanla";

defineOptions({
  name: "StudentUserManage"
});

const router = useRouter();
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

// 快捷修改学习阶段弹窗
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

function openDetail(row: StudentUser) {
  router.push(`/user/detail/${row.id}`);
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
    ElMessage.success("已调整学生学习阶段");
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
        <el-form-item label="当前阶段">
          <el-select v-model="query.realmCode" placeholder="全部阶段" clearable style="width: 190px">
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
        <el-table-column label="学生信息" min-width="190">
          <template #default="{ row }">
            <div class="flex items-center gap-1.5">
              <el-button
                link
                type="primary"
                class="!h-auto !p-0 text-left font-semibold"
                @click="openDetail(row)"
              >
                {{ row.nickname }}
              </el-button>
              <el-tag
                v-if="(row.pendingEssayCount || 0) > 0"
                type="warning"
                size="small"
                class="shrink-0 whitespace-nowrap"
              >
                待批 {{ row.pendingEssayCount }}
              </el-tag>
            </div>
            <div class="truncate text-xs text-gray-500">账号：{{ row.username || "-" }}</div>
          </template>
        </el-table-column>
        <el-table-column label="当前学习阶段" min-width="176">
          <template #default="{ row }">
            <div class="flex flex-nowrap items-center gap-2 whitespace-nowrap">
              <el-tag type="success" class="shrink-0">{{ row.realmName || "初一" }}</el-tag>
              <el-button link type="primary" size="small" class="shrink-0" @click="openRealmAdjust(row)">
                修改阶段
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
        <el-table-column label="操作" width="280" align="center">
          <template #default="{ row }">
            <div class="inline-flex items-center justify-center whitespace-nowrap">
              <el-button link type="primary" @click="openDetail(row)">详情批改</el-button>
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

    <!-- 快捷调整学生阶段弹窗 -->
    <el-dialog v-model="realmDialogVisible" title="修改学生学习阶段" width="440px">
      <div v-if="realmTargetUser" class="space-y-4">
        <div class="text-sm text-gray-600">
          正在为学生 <span class="font-bold text-gray-900">{{ realmTargetUser.nickname }}</span>
          设定学习阶段（修改后立即生效，各年级题库均可自由刷题巩固）：
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
        <el-form-item label="当前阶段" required>
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
