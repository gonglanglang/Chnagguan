<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { ElMessage, type UploadRequestOptions } from "element-plus";
import {
  getRealms,
  updateRealm,
  getConfigs,
  updateConfig,
  getAdminAppVersion,
  initAppApkUpload,
  publishAppApk,
  uploadApkDirectToOss,
  uploadAppApk,
  OssDirectNetworkError,
  type RealmConfig,
  type AppVersionInfo
} from "@/api/guoguanla";

defineOptions({
  name: "RealmConfigManage"
});

const loading = ref(false);
const savingBasic = ref(false);
const savingVersion = ref(false);
const syncingGithub = ref(false);
const uploadingApk = ref(false);
const apkUploadProgress = ref(0);
const realms = ref<RealmConfig[]>([]);
const effectiveVersion = ref<AppVersionInfo | null>(null);

const basicForm = reactive({
  guestMode: true,
  appNotice: ""
});

const versionForm = reactive({
  githubRepo: "gonglanglang/Chnagguan",
  latestVersion: "1.0.0",
  latestVersionCode: 100,
  downloadUrl: "",
  forceUpdate: false,
  updateNotes: ""
});

async function fetchAll() {
  loading.value = true;
  try {
    const [realmRes, cfgRes, verRes] = await Promise.all([
      getRealms(),
      getConfigs(),
      getAdminAppVersion(false)
    ]);
    realms.value = realmRes.data;
    const cfgList = cfgRes.data || [];
    const map = new Map(cfgList.map(c => [c.configKey, c.configValue]));
    basicForm.guestMode = map.has("guest_mode_enabled")
      ? map.get("guest_mode_enabled") === "true"
      : true;
    basicForm.appNotice = map.get("app_notice") || "";

    versionForm.githubRepo = map.get("github_release_repo") || "gonglanglang/Chnagguan";
    versionForm.latestVersion = map.get("app_latest_version") || "1.0.0";
    versionForm.latestVersionCode = Number(map.get("app_latest_version_code") || 100);
    versionForm.downloadUrl = map.get("app_download_url") || "";
    versionForm.forceUpdate = map.get("app_force_update") === "true";
    versionForm.updateNotes = map.get("app_update_notes") || "";
    effectiveVersion.value = verRes.data;
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

async function saveVersionSettings() {
  if (!versionForm.latestVersion.trim()) {
    ElMessage.warning("请填写最新版本号");
    return;
  }
  savingVersion.value = true;
  try {
    await Promise.all([
      updateConfig("github_release_repo", versionForm.githubRepo.trim()),
      updateConfig("app_latest_version", versionForm.latestVersion.trim()),
      updateConfig("app_latest_version_code", String(versionForm.latestVersionCode || 100)),
      updateConfig("app_download_url", versionForm.downloadUrl.trim()),
      updateConfig("app_force_update", versionForm.forceUpdate ? "true" : "false"),
      updateConfig("app_update_notes", versionForm.updateNotes.trim())
    ]);
    const verRes = await getAdminAppVersion(true);
    effectiveVersion.value = verRes.data;
    ElMessage.success("App 版本配置已保存");
  } finally {
    savingVersion.value = false;
  }
}

async function refreshGithubRelease() {
  syncingGithub.value = true;
  try {
    await updateConfig("github_release_repo", versionForm.githubRepo.trim());
    const res = await getAdminAppVersion(true);
    effectiveVersion.value = res.data;
    if (res.data.githubReachable) {
      ElMessage.success(`已同步 GitHub Release：v${res.data.latestVersion}`);
    } else {
      ElMessage.warning("未检测到公开的 GitHub Release（仓库为私有或尚未发布 Release），当前使用服务器配置");
    }
  } finally {
    syncingGithub.value = false;
  }
}

async function handleApkUpload(options: UploadRequestOptions) {
  uploadingApk.value = true;
  apkUploadProgress.value = 0;
  const targetVersion = versionForm.latestVersion.trim() || "1.0.0";
  const targetCode = versionForm.latestVersionCode || 100;
  const targetNotes = versionForm.updateNotes.trim();
  const targetForce = versionForm.forceUpdate;

  const uploadViaBackendToOss = async () => {
    const fd = new FormData();
    fd.append("file", options.file);
    fd.append("version", targetVersion);
    fd.append("versionCode", String(targetCode));
    fd.append("releaseNotes", targetNotes);
    fd.append("forceUpdate", String(targetForce));
    const [res, cfgRes] = await Promise.all([uploadAppApk(fd), getConfigs().catch(() => null)]);
    effectiveVersion.value = res.data;
    const savedKey = (cfgRes?.data || []).find(c => c.configKey === "app_download_url")?.configValue;
    versionForm.downloadUrl = savedKey || res.data.downloadUrl;
    apkUploadProgress.value = 100;
    ElMessage.success("APK 已托管至阿里云 OSS 并发布为当前版本");
  };

  try {
    const initRes = await initAppApkUpload({
      fileName: options.file.name,
      version: targetVersion
    });
    const init = initRes.data;
    if (init.directUpload && init.uploadUrl && init.objectKey) {
      try {
        await uploadApkDirectToOss({
          uploadUrl: init.uploadUrl,
          file: options.file,
          contentType: init.contentType,
          onProgress: pct => {
            apkUploadProgress.value = pct;
          }
        });
        const pubRes = await publishAppApk({
          objectKey: init.objectKey,
          version: targetVersion,
          versionCode: targetCode,
          releaseNotes: targetNotes,
          forceUpdate: targetForce
        });
        effectiveVersion.value = pubRes.data;
        versionForm.downloadUrl = init.objectKey;
        apkUploadProgress.value = 100;
        ElMessage.success("APK 已直传阿里云 OSS 并发布为当前版本");
        return;
      } catch (err) {
        if (err instanceof OssDirectNetworkError) {
          ElMessage.warning("浏览器直传 OSS 受跨域限制，已自动通过服务端上传至 OSS");
          await uploadViaBackendToOss();
          return;
        }
        throw err;
      }
    }
    await uploadViaBackendToOss();
  } finally {
    uploadingApk.value = false;
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
              开启后，未登录学生可先游客试玩各境界关卡（进阶考核需登录后参加）
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

    <el-card shadow="never">
      <template #header>
        <div class="flex flex-wrap items-center justify-between gap-2">
          <span class="font-bold text-gray-800">App 版本更新与发布管理</span>
          <div class="flex flex-wrap items-center gap-3 text-xs">
            <el-button link type="success" tag="a" href="/download/" target="_blank">
              打开 App 下载官网
            </el-button>
            <template v-if="effectiveVersion">
              <el-tag :type="effectiveVersion.githubReachable ? 'success' : 'info'" size="small">
                {{ effectiveVersion.githubReachable ? "GitHub Release 已连通" : "当前使用 OSS/系统配置" }}
              </el-tag>
              <span class="text-gray-500">
                当前对外版本：v{{ effectiveVersion.latestVersion }} ({{ effectiveVersion.latestVersionCode }})
              </span>
            </template>
          </div>
        </div>
      </template>

      <el-form label-width="140px" class="max-w-3xl">
        <el-form-item label="GitHub 发布仓库">
          <div class="flex w-full flex-wrap items-center gap-2">
            <el-input
              v-model="versionForm.githubRepo"
              placeholder="格式：用户名/仓库名，如 gonglanglang/Chnagguan"
              class="min-w-[260px] flex-1"
            />
            <el-button :loading="syncingGithub" @click="refreshGithubRelease">
              检测 GitHub Release
            </el-button>
          </div>
        </el-form-item>

        <el-form-item label="最新版本号">
          <div class="flex flex-wrap items-center gap-3">
            <el-input v-model="versionForm.latestVersion" placeholder="如 1.0.1" style="width: 150px" />
            <span class="whitespace-nowrap text-xs text-gray-500">内部编码 (versionCode)：</span>
            <el-input-number v-model="versionForm.latestVersionCode" :min="1" style="width: 130px" />
          </div>
        </el-form-item>

        <el-form-item label="APK 下载地址">
          <div class="w-full space-y-2">
            <div class="flex w-full flex-wrap items-center gap-2">
              <el-input
                v-model="versionForm.downloadUrl"
                placeholder="上传 APK 后自动填充 OSS 对象键（app-releases/...），也可填入 GitHub 直链"
                class="min-w-[260px] flex-1"
              />
              <el-upload
                :show-file-list="false"
                accept=".apk"
                :http-request="handleApkUpload"
              >
                <el-button type="success" plain :loading="uploadingApk">
                  上传 APK 到阿里云 OSS
                </el-button>
              </el-upload>
            </div>
            <el-progress v-if="uploadingApk && apkUploadProgress > 0" :percentage="apkUploadProgress" />
          </div>
        </el-form-item>

        <el-form-item label="强制更新">
          <div class="flex flex-wrap items-center gap-3">
            <el-switch v-model="versionForm.forceUpdate" class="shrink-0" />
            <span class="text-xs text-gray-500">
              开启后，低于该版本的学生端将无法跳过本次更新弹窗
            </span>
          </div>
        </el-form-item>

        <el-form-item label="更新说明">
          <el-input
            v-model="versionForm.updateNotes"
            type="textarea"
            :rows="3"
            placeholder="展示给学生的版本更新内容"
          />
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="savingVersion" @click="saveVersionSettings">
            保存版本设置
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>
