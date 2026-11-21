<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { ElMessage } from "element-plus";
import {
  getRealms,
  updateRealm,
  getConfigs,
  updateConfig,
  type RealmConfig
} from "@/api/guoguanla";

defineOptions({
  name: "RealmConfigManage"
});

const loading = ref(false);
const savingBasic = ref(false);
const realms = ref<RealmConfig[]>([]);

const basicForm = reactive({
  guestMode: true,
  appNotice: ""
});

async function fetchAll() {
  loading.value = true;
  try {
    const [realmRes, cfgRes] = await Promise.all([getRealms(), getConfigs()]);
    realms.value = realmRes.data;
    const cfgList = cfgRes.data || [];
    const guestCfg = cfgList.find(c => c.configKey === "guest_mode_enabled");
    const noticeCfg = cfgList.find(c => c.configKey === "app_notice");
    basicForm.guestMode = guestCfg ? guestCfg.configValue === "true" : true;
    basicForm.appNotice = noticeCfg?.configValue || "";
  } finally {
    loading.value = false;
  }
}

async function saveRealmRow(row: RealmConfig) {
  if (!row.realmName.trim()) {
    ElMessage.warning("请填写境界名称");
    return;
  }
  await updateRealm(row.id, {
    realmName: row.realmName,
    difficultyLabel: row.difficultyLabel,
    description: row.description,
    unlockGates: row.unlockGates,
    examQuestionCount: row.examQuestionCount,
    examPassScore: row.examPassScore
  });
  ElMessage.success(`已保存「${row.realmName}」境界配置`);
}

async function saveBasicSettings() {
  savingBasic.value = true;
  try {
    await Promise.all([
      updateConfig("guest_mode_enabled", basicForm.guestMode ? "true" : "false"),
      updateConfig("app_notice", basicForm.appNotice.trim())
    ]);
    ElMessage.success("基础设置已保存");
  } finally {
    savingBasic.value = false;
  }
}

onMounted(fetchAll);
</script>

<template>
  <div v-loading="loading" class="space-y-4">
    <el-card shadow="never">
      <template #header>
        <div class="flex flex-wrap items-center justify-between gap-2">
          <span class="font-bold text-gray-800">修仙境界与进阶考核设置</span>
          <span class="text-xs text-gray-500">
            修改完成后点击每行右侧「保存」立即生效
          </span>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        class="mb-4"
        title="配置说明：学生按「练气 → 筑基 → 结丹 → 假婴 → 元婴 → 化神」逐级修炼。解锁门槛填 0 表示需学完当前境界全部关卡，填正数（如 4）表示通过 4 关即可开启进阶考核；考核按百分制计算分数线。"
      />

      <el-table :data="realms" border stripe class="w-full">
        <el-table-column label="顺序" width="84" align="center">
          <template #default="{ row }">
            <span class="whitespace-nowrap">第{{ row.realmOrder }}境</span>
          </template>
        </el-table-column>

        <el-table-column label="境界名称" min-width="115">
          <template #default="{ row }">
            <el-input v-model="row.realmName" size="small" />
          </template>
        </el-table-column>

        <el-table-column label="难度说明" min-width="155">
          <template #default="{ row }">
            <el-input v-model="row.difficultyLabel" size="small" />
          </template>
        </el-table-column>

        <el-table-column label="关/题数" width="108" align="center">
          <template #default="{ row }">
            <span class="whitespace-nowrap text-xs text-gray-600">{{ row.gateCount }}/{{ row.questionCount }}</span>
          </template>
        </el-table-column>

        <el-table-column label="解锁门槛(0=全通)" width="160" align="center">
          <template #default="{ row }">
            <el-input-number
              v-if="row.realmOrder < 6"
              v-model="row.unlockGates"
              controls-position="right"
              :min="0"
              :max="row.gateCount || 99"
              size="small"
              style="width: 100px"
            />
            <span v-else class="whitespace-nowrap text-xs text-gray-400">最高境界</span>
          </template>
        </el-table-column>

        <el-table-column label="抽题数" width="138" align="center">
          <template #default="{ row }">
            <div v-if="row.realmOrder < 6" class="flex items-center justify-center gap-1 whitespace-nowrap">
              <el-input-number
                v-model="row.examQuestionCount"
                controls-position="right"
                :min="1"
                :max="50"
                size="small"
                style="width: 82px"
              />
              <span class="text-xs text-gray-500">题</span>
            </div>
            <span v-else class="text-xs text-gray-400">-</span>
          </template>
        </el-table-column>

        <el-table-column label="及格线" width="138" align="center">
          <template #default="{ row }">
            <div v-if="row.realmOrder < 6" class="flex items-center justify-center gap-1 whitespace-nowrap">
              <el-input-number
                v-model="row.examPassScore"
                controls-position="right"
                :min="1"
                :max="100"
                :step="5"
                size="small"
                style="width: 82px"
              />
              <span class="text-xs text-gray-500">分</span>
            </div>
            <span v-else class="text-xs text-gray-400">-</span>
          </template>
        </el-table-column>

        <el-table-column label="人数" width="92" align="center">
          <template #default="{ row }">
            <el-tag type="success" size="small" class="whitespace-nowrap">{{ row.studentCount }}人</el-tag>
          </template>
        </el-table-column>

        <el-table-column label="操作" width="96" align="center">
          <template #default="{ row }">
            <el-button type="primary" size="small" @click="saveRealmRow(row)">保存</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>
        <span class="font-bold text-gray-800">前台基础设置</span>
      </template>
      <el-form label-width="140px" class="max-w-2xl">
        <el-form-item label="允许游客试玩">
          <div class="flex flex-wrap items-center gap-3">
            <el-switch v-model="basicForm.guestMode" class="shrink-0" />
            <span class="text-xs text-gray-500">
              开启后，未登录学生可先体验「练气」关卡（进阶考核需登录后参加）
            </span>
          </div>
        </el-form-item>

        <el-form-item label="学生端首页公告">
          <el-input
            v-model="basicForm.appNotice"
            placeholder="展示在学生端首页顶部的简短通知"
            maxlength="120"
            show-word-limit
          />
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="savingBasic" @click="saveBasicSettings">
            保存基础设置
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>
