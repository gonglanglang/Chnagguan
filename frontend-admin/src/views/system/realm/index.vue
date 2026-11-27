<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { ElMessage, type UploadRequestOptions } from "element-plus";
import {
  getRealms,
  updateRealm,
  getConfigs,
  updateConfig,
  getAdminDefaultTheme,
  updateAdminDefaultTheme,
  getAiConfig,
  updateAiConfig,
  testAiConfig,
  getAiImageConfig,
  updateAiImageConfig,
  testAiImageConfig,
  getAdminAppVersion,
  initAppApkUpload,
  publishAppApk,
  uploadApkDirectToOss,
  uploadAppApk,
  OssDirectNetworkError,
  type RealmConfig,
  type AppDefaultThemeConfig,
  type AppVersionInfo,
  type AiConfigInfo,
  type AiTestResult,
  type AiImageConfigInfo,
  type AiImageTestResult
} from "@/api/guoguanla";

defineOptions({
  name: "RealmConfigManage"
});

const loading = ref(false);
const savingBasic = ref(false);
const savingTheme = ref(false);
const savingAi = ref(false);
const testingAi = ref(false);
const savingAiImage = ref(false);
const testingAiImageHealth = ref(false);
const testingAiImageGenerate = ref(false);
const savingVersion = ref(false);
const syncingGithub = ref(false);
const uploadingApk = ref(false);
const apkUploadProgress = ref(0);
const realms = ref<RealmConfig[]>([]);
const effectiveVersion = ref<AppVersionInfo | null>(null);
const aiConfigView = ref<AiConfigInfo | null>(null);
const aiTestResult = ref<AiTestResult | null>(null);
const aiImageConfigView = ref<AiImageConfigInfo | null>(null);
const aiImageTestResult = ref<AiImageTestResult | null>(null);

const basicForm = reactive({
  guestMode: true,
  appNotice: ""
});

const skinOptions: Array<{
  code: "welkui" | "skribble" | "forui";
  title: string;
  badge: string;
  desc: string;
}> = [
  {
    code: "welkui",
    title: "WelkUI 漫画风",
    badge: "经典活力",
    desc: "2px 清晰黑描边与硬投影漫画卡片，高对比度辨识"
  },
  {
    code: "skribble",
    title: "Skribble 手绘风",
    badge: "纸感轻盈",
    desc: "铅笔草图线条与暖纸底色，像手写数学练习本"
  },
  {
    code: "forui",
    title: "Forui 现代极简",
    badge: "shadcn/ui",
    desc: "基于 forui.dev 现代克制设计，1px 细腻边框与通透留白"
  }
];

const themeColorPresets = [
  { hex: "#67C6FF", name: "天青漫画" },
  { hex: "#0284C7", name: "晴空蓝" },
  { hex: "#FFDA57", name: "元气暖黄" },
  { hex: "#8DDD9B", name: "青岚薄荷" },
  { hex: "#FFB366", name: "活力暖橙" },
  { hex: "#C5A3FF", name: "丁香淡紫" }
];

const defaultThemeForm = reactive<AppDefaultThemeConfig>({
  uiSkin: "welkui",
  themeHex: "#67C6FF",
  themeName: "天青漫画",
  darkMode: false,
  version: "1"
});

const aiForm = reactive({
  enabled: true,
  baseUrl: "https://api.longcat.chat/openai",
  apiKey: "",
  clearApiKey: false,
  model: "LongCat-2.5",
  visionModel: "",
  temperature: 0.2,
  maxTokens: 4096,
  timeoutSec: 60,
  systemPrompt: ""
});

const aiImageModelOptions = [
  { value: "gem_pix_2", label: "gem_pix_2（Flow Agent 实测推荐）" },
  { value: "narwhal", label: "narwhal（Flow Agent）" },
  { value: "harbor_seal", label: "harbor_seal（Flow Agent）" },
  { value: "dall-e-3", label: "dall-e-3（OpenAI 兼容）" },
  { value: "gpt-image-1", label: "gpt-image-1（OpenAI 兼容）" }
];

const aiImageSizeOptions = [
  { value: "1024x1024", label: "1024x1024（1:1 方形）" },
  { value: "1792x1024", label: "1792x1024（16:9 横屏）" },
  { value: "1024x1792", label: "1024x1792（9:16 竖屏）" },
  { value: "1365x1024", label: "1365x1024（4:3 经典横图）" },
  { value: "1024x1365", label: "1024x1365（3:4 经典竖图）" }
];

const aiImageForm = reactive({
  enabled: true,
  baseUrl: "http://127.0.0.1:8001/v1",
  apiKey: "",
  clearApiKey: false,
  model: "gem_pix_2",
  defaultSize: "1024x1024",
  timeoutSec: 120,
  testPrompt: "a glowing crystal lotus on calm water, clean minimalist illustration"
});

const versionForm = reactive({
  githubRepo: "gonglanglang/Chnagguan",
  latestVersion: "1.0.0",
  latestVersionCode: 100,
  downloadUrl: "",
  ossCustomDomain: "",
  forceUpdate: false,
  updateNotes: ""
});

async function fetchAll() {
  loading.value = true;
  try {
    const [realmRes, cfgRes, verRes, aiRes, aiImgRes, themeRes] = await Promise.all([
      getRealms(),
      getConfigs(),
      getAdminAppVersion(false),
      getAiConfig().catch(() => null),
      getAiImageConfig().catch(() => null),
      getAdminDefaultTheme().catch(() => null)
    ]);
    realms.value = realmRes.data;
    const cfgList = cfgRes.data || [];
    const map = new Map(cfgList.map(c => [c.configKey, c.configValue]));
    basicForm.guestMode = map.has("guest_mode_enabled")
      ? map.get("guest_mode_enabled") === "true"
      : true;
    basicForm.appNotice = map.get("app_notice") || "";

    if (themeRes?.data) {
      defaultThemeForm.uiSkin = themeRes.data.uiSkin || "welkui";
      defaultThemeForm.themeHex = themeRes.data.themeHex || "#67C6FF";
      defaultThemeForm.themeName = themeRes.data.themeName || "天青漫画";
      defaultThemeForm.darkMode = Boolean(themeRes.data.darkMode);
      defaultThemeForm.version = themeRes.data.version || "1";
    }

    versionForm.githubRepo = map.get("github_release_repo") || "gonglanglang/Chnagguan";
    versionForm.latestVersion = map.get("app_latest_version") || "1.0.0";
    versionForm.latestVersionCode = Number(map.get("app_latest_version_code") || 100);
    versionForm.downloadUrl = map.get("app_download_url") || "";
    versionForm.ossCustomDomain = map.get("oss_custom_domain") || verRes.data?.ossCustomDomain || "";
    versionForm.forceUpdate = map.get("app_force_update") === "true";
    versionForm.updateNotes = map.get("app_update_notes") || "";
    effectiveVersion.value = verRes.data;

    if (aiRes?.data) {
      applyAiConfigView(aiRes.data);
    }
    if (aiImgRes?.data) {
      applyAiImageConfigView(aiImgRes.data);
    }
  } finally {
    loading.value = false;
  }
}

function applyAiConfigView(data: AiConfigInfo) {
  aiConfigView.value = data;
  aiForm.enabled = data.enabled;
  aiForm.baseUrl = data.baseUrl || "https://api.longcat.chat/openai";
  aiForm.apiKey = "";
  aiForm.clearApiKey = false;
  aiForm.model = data.model || "LongCat-2.5";
  aiForm.visionModel = data.visionModel || "";
  aiForm.temperature = data.temperature ?? 0.2;
  aiForm.maxTokens = data.maxTokens ?? 4096;
  aiForm.timeoutSec = data.timeoutSec ?? 60;
  aiForm.systemPrompt = data.systemPrompt || "";
}

async function saveAiSettings() {
  if (!aiForm.baseUrl.trim()) {
    ElMessage.warning("请填写 OpenAI 格式接口地址");
    return;
  }
  if (!aiForm.model.trim()) {
    ElMessage.warning("请填写默认模型名称");
    return;
  }
  savingAi.value = true;
  try {
    const res = await updateAiConfig({
      enabled: aiForm.enabled,
      baseUrl: aiForm.baseUrl.trim(),
      apiKey: aiForm.apiKey.trim(),
      clearApiKey: aiForm.clearApiKey,
      model: aiForm.model.trim(),
      visionModel: aiForm.visionModel.trim(),
      temperature: aiForm.temperature,
      maxTokens: aiForm.maxTokens,
      timeoutSec: aiForm.timeoutSec,
      systemPrompt: aiForm.systemPrompt.trim()
    });
    applyAiConfigView(res.data);
    ElMessage.success("AI 大模型配置已保存并立即生效");
  } finally {
    savingAi.value = false;
  }
}

async function handleTestAi() {
  testingAi.value = true;
  aiTestResult.value = null;
  try {
    const res = await testAiConfig({
      baseUrl: aiForm.baseUrl.trim(),
      apiKey: aiForm.apiKey.trim() || undefined,
      model: aiForm.model.trim(),
      timeoutSec: aiForm.timeoutSec
    });
    aiTestResult.value = res.data;
    if (res.data.ok) {
      ElMessage.success(`AI 连通成功（${res.data.latencyMs ?? 0}ms）`);
    } else {
      ElMessage.error(res.data.errorMessage || "AI 连通性测试失败");
    }
  } finally {
    testingAi.value = false;
  }
}

function applyAiImageConfigView(data: AiImageConfigInfo) {
  aiImageConfigView.value = data;
  aiImageForm.enabled = data.enabled;
  aiImageForm.baseUrl = data.baseUrl || "http://127.0.0.1:8001/v1";
  aiImageForm.apiKey = "";
  aiImageForm.clearApiKey = false;
  aiImageForm.model = data.model || "gem_pix_2";
  aiImageForm.defaultSize = data.defaultSize || "1024x1024";
  aiImageForm.timeoutSec = data.timeoutSec ?? 120;
}

function applyFlowAgentPreset() {
  aiImageForm.enabled = true;
  aiImageForm.baseUrl = "http://127.0.0.1:8001/v1";
  aiImageForm.apiKey = "";
  aiImageForm.clearApiKey = true;
  aiImageForm.model = "gem_pix_2";
  aiImageForm.defaultSize = "1024x1024";
  aiImageForm.timeoutSec = 120;
  ElMessage.info("已填入本地 Flow Agent 默认参数，点击「保存生图配置」生效");
}

async function saveAiImageSettings() {
  if (!aiImageForm.baseUrl.trim()) {
    ElMessage.warning("请填写 AI 生图接口地址");
    return;
  }
  if (!aiImageForm.model.trim()) {
    ElMessage.warning("请填写生图模型名称");
    return;
  }
  savingAiImage.value = true;
  try {
    const res = await updateAiImageConfig({
      enabled: aiImageForm.enabled,
      baseUrl: aiImageForm.baseUrl.trim(),
      apiKey: aiImageForm.apiKey.trim(),
      clearApiKey: aiImageForm.clearApiKey,
      model: aiImageForm.model.trim(),
      defaultSize: aiImageForm.defaultSize,
      timeoutSec: aiImageForm.timeoutSec
    });
    applyAiImageConfigView(res.data);
    ElMessage.success("AI 生图配置已保存并立即生效");
  } finally {
    savingAiImage.value = false;
  }
}

async function handleTestAiImage(generateSample: boolean) {
  if (!aiImageForm.baseUrl.trim()) {
    ElMessage.warning("请先填写 AI 生图接口地址");
    return;
  }
  if (generateSample) {
    testingAiImageGenerate.value = true;
  } else {
    testingAiImageHealth.value = true;
  }
  aiImageTestResult.value = null;
  try {
    const res = await testAiImageConfig({
      baseUrl: aiImageForm.baseUrl.trim(),
      apiKey: aiImageForm.apiKey.trim() || undefined,
      model: aiImageForm.model.trim(),
      size: aiImageForm.defaultSize,
      timeoutSec: aiImageForm.timeoutSec,
      generateSample,
      prompt: generateSample ? aiImageForm.testPrompt.trim() || undefined : undefined
    });
    aiImageTestResult.value = res.data;
    if (res.data.ok) {
      ElMessage.success(
        generateSample
          ? `试生图成功（${res.data.latencyMs ?? 0}ms）`
          : `生图服务已连通（${res.data.latencyMs ?? 0}ms）`
      );
    } else {
      ElMessage.error(res.data.errorMessage || "AI 生图测试失败");
    }
  } finally {
    testingAiImageHealth.value = false;
    testingAiImageGenerate.value = false;
  }
}

async function saveRealmRow(row: RealmConfig) {
  if (!row.realmName.trim()) {
    ElMessage.warning("请填写学习阶段名称");
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
  ElMessage.success(`已保存「${row.realmName}」阶段配置`);
}

function selectColorPreset(preset: { hex: string; name: string }) {
  defaultThemeForm.themeHex = preset.hex;
  defaultThemeForm.themeName = preset.name;
}

async function saveDefaultThemeSettings() {
  const hex = defaultThemeForm.themeHex.trim().toUpperCase();
  if (!/^#[0-9A-F]{6}$/.test(hex)) {
    ElMessage.warning("请填写合法的 6 位十六进制主题色，例如 #67C6FF");
    return;
  }
  savingTheme.value = true;
  try {
    const res = await updateAdminDefaultTheme({
      uiSkin: defaultThemeForm.uiSkin,
      themeHex: hex,
      themeName: defaultThemeForm.themeName.trim() || "自定义主题",
      darkMode: defaultThemeForm.darkMode
    });
    if (res.data) {
      defaultThemeForm.uiSkin = res.data.uiSkin;
      defaultThemeForm.themeHex = res.data.themeHex;
      defaultThemeForm.themeName = res.data.themeName;
      defaultThemeForm.darkMode = Boolean(res.data.darkMode);
      defaultThemeForm.version = res.data.version;
    }
    ElMessage.success("学生端默认主题已保存，学生下次进入应用将自动生效");
  } finally {
    savingTheme.value = false;
  }
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
  if (versionForm.updateNotes.trim().length > 2500) {
    ElMessage.warning("更新说明不能超过 2500 字");
    return;
  }
  savingVersion.value = true;
  try {
    await Promise.all([
      updateConfig("github_release_repo", versionForm.githubRepo.trim()),
      updateConfig("app_latest_version", versionForm.latestVersion.trim()),
      updateConfig("app_latest_version_code", String(versionForm.latestVersionCode || 100)),
      updateConfig("app_download_url", versionForm.downloadUrl.trim()),
      updateConfig("oss_custom_domain", versionForm.ossCustomDomain.trim()),
      updateConfig("app_force_update", versionForm.forceUpdate ? "true" : "false"),
      updateConfig("app_update_notes", versionForm.updateNotes.trim())
    ]);
    const verRes = await getAdminAppVersion(true);
    effectiveVersion.value = verRes.data;
    versionForm.ossCustomDomain = verRes.data.ossCustomDomain || versionForm.ossCustomDomain.trim();
    ElMessage.success("App 版本与下载通道配置已保存");
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
          <span class="font-bold text-gray-800">年级阶段与升级测评设置</span>
          <span class="text-xs text-gray-500">
            修改完成后点击每行右侧「保存」立即生效
          </span>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        class="mb-4"
        title="配置说明：学生按「初一 → 初二 → 初三 → 高一 → 高二 → 高三」六个阶段循序学习（全阶段题库自由开放）。解锁门槛填 0 表示需学完当前阶段全部关卡，填正数（如 4）表示通过 4 关即可开启阶段升级测评；测评按百分制计算分数线。"
      />

      <el-table :data="realms" border stripe class="w-full">
        <el-table-column label="顺序" width="88" align="center">
          <template #default="{ row }">
            <span class="whitespace-nowrap">第{{ row.realmOrder }}阶段</span>
          </template>
        </el-table-column>

        <el-table-column label="阶段名称" min-width="115">
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
            <span v-else class="whitespace-nowrap text-xs text-gray-400">最高阶段</span>
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
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex items-center gap-2">
            <span class="font-bold text-gray-800">AI 智能画板与大模型配置</span>
            <el-tag
              :type="aiConfigView?.hasApiKey && aiForm.enabled ? 'success' : 'warning'"
              size="small"
            >
              {{
                !aiForm.enabled
                  ? "已关闭"
                  : aiConfigView?.hasApiKey
                    ? `已配置 · ${aiConfigView.model}`
                    : "待配置 API 密钥"
              }}
            </el-tag>
          </div>
          <span v-if="aiConfigView?.resolvedEndpoint" class="text-xs text-gray-500">
            实际请求地址：{{ aiConfigView.resolvedEndpoint }}
          </span>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        class="mb-4"
        title="用于驱动学生端首页「AI 智能手写画板」的拍照识题、AI 解题思路绘制、AI 过程分析与手写诊断。所有请求由后端服务端安全转发，API 密钥仅保存在服务器数据库并全程脱敏，绝不暴露至学生端。"
      />

      <el-form label-width="140px" class="max-w-3xl">
        <el-form-item label="启用 AI 智能画板">
          <div class="flex flex-wrap items-center gap-3">
            <el-switch v-model="aiForm.enabled" class="shrink-0" />
            <span class="text-xs text-gray-500">
              关闭后学生端仍可使用纯手写画板，AI 拍照识题与思路/过程分析将提示未开启
            </span>
          </div>
        </el-form-item>

        <el-form-item label="OpenAI 接口地址">
          <el-input
            v-model="aiForm.baseUrl"
            placeholder="例如：https://api.longcat.chat/openai 或 https://api.openai.com/v1"
          />
          <div class="mt-1 text-xs text-gray-400">
            兼容 OpenAI Chat Completions 协议，后端自动补齐 /v1/chat/completions
          </div>
        </el-form-item>

        <el-form-item label="API 密钥">
          <div class="w-full space-y-2">
            <el-input
              v-model="aiForm.apiKey"
              type="password"
              show-password
              autocomplete="new-password"
              :placeholder="
                aiConfigView?.hasApiKey
                  ? `当前已保存密钥 (${aiConfigView.apiKeyMasked})，留空则保持不变；输入新密钥将覆盖`
                  : '请输入 OpenAI 兼容 API Key'
              "
            />
            <div v-if="aiConfigView?.hasApiKey" class="flex items-center justify-between text-xs text-gray-500">
              <span>已安全保存密钥：{{ aiConfigView.apiKeyMasked }}</span>
              <el-checkbox v-model="aiForm.clearApiKey" size="small">
                保存时清空已保存密钥
              </el-checkbox>
            </div>
          </div>
        </el-form-item>

        <el-form-item label="主模型名称">
          <div class="flex w-full flex-wrap items-center gap-3">
            <el-input
              v-model="aiForm.model"
              placeholder="如 LongCat-2.5"
              class="min-w-[200px] flex-1"
            />
            <span class="whitespace-nowrap text-xs text-gray-500">视觉识图模型（选填）：</span>
            <el-input
              v-model="aiForm.visionModel"
              placeholder="留空则复用主模型"
              class="min-w-[180px] flex-1"
            />
          </div>
        </el-form-item>

        <el-form-item label="采样与超时参数">
          <div class="flex flex-wrap items-center gap-4">
            <div class="flex items-center gap-1.5">
              <span class="text-xs text-gray-500">温度</span>
              <el-input-number
                v-model="aiForm.temperature"
                :min="0"
                :max="1.5"
                :step="0.1"
                :precision="1"
                size="small"
                style="width: 100px"
              />
            </div>
            <div class="flex items-center gap-1.5">
              <span class="text-xs text-gray-500">最大 Token</span>
              <el-input-number
                v-model="aiForm.maxTokens"
                :min="256"
                :max="32768"
                :step="512"
                size="small"
                style="width: 120px"
              />
            </div>
            <div class="flex items-center gap-1.5">
              <span class="text-xs text-gray-500">超时(秒)</span>
              <el-input-number
                v-model="aiForm.timeoutSec"
                :min="10"
                :max="180"
                :step="10"
                size="small"
                style="width: 106px"
              />
            </div>
          </div>
        </el-form-item>

        <el-form-item label="教研系统提示词">
          <el-input
            v-model="aiForm.systemPrompt"
            type="textarea"
            :rows="2"
            placeholder="选填：可补充额外教学风格要求（如侧重初高中人教版规范步骤），留空使用内置数学教研提示词"
          />
        </el-form-item>

        <el-form-item v-if="aiTestResult">
          <el-alert
            :type="aiTestResult.ok ? 'success' : 'error'"
            :closable="true"
            @close="aiTestResult = null"
            class="w-full"
          >
            <template #title>
              <span v-if="aiTestResult.ok">
                连通成功 · 模型 {{ aiTestResult.model }} · 耗时 {{ aiTestResult.latencyMs }}ms
              </span>
              <span v-else>
                连通失败 · {{ aiTestResult.errorMessage }}
              </span>
            </template>
            <div v-if="aiTestResult.ok && aiTestResult.reply" class="mt-1 text-xs text-gray-700">
              模型回复：{{ aiTestResult.reply }}
            </div>
          </el-alert>
        </el-form-item>

        <el-form-item>
          <div class="flex flex-wrap items-center gap-2">
            <el-button type="primary" :loading="savingAi" @click="saveAiSettings">
              保存 AI 配置
            </el-button>
            <el-button type="success" plain :loading="testingAi" @click="handleTestAi">
              测试模型连通性
            </el-button>
          </div>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never">
      <template #header>
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex items-center gap-2">
            <span class="font-bold text-gray-800">AI 生图服务配置（Flow Agent / OpenAI 兼容）</span>
            <el-tag
              :type="aiImageForm.enabled && aiImageConfigView?.resolvedEndpoint ? 'success' : 'warning'"
              size="small"
            >
              {{
                !aiImageForm.enabled
                  ? "已关闭"
                  : aiImageConfigView?.model
                    ? `已启用 · ${aiImageConfigView.model}`
                    : "待保存配置"
              }}
            </el-tag>
          </div>
          <span v-if="aiImageConfigView?.resolvedEndpoint" class="text-xs text-gray-500">
            实际生图地址：{{ aiImageConfigView.resolvedEndpoint }}
          </span>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        class="mb-4"
        title="对接本地搭建的 Flow Agent（默认 http://127.0.0.1:8001/v1，本地无密钥模式）或任意 OpenAI /v1/images/generations 兼容生图服务。使用 Flow Agent 时请保持本地 Bridge (9222) 运行，并在 Chrome 打开 labs.google/fx/tools/flow 保持登录态。"
      />

      <el-form label-width="140px" class="max-w-3xl">
        <el-form-item label="启用 AI 生图服务">
          <div class="flex flex-wrap items-center gap-3">
            <el-switch v-model="aiImageForm.enabled" class="shrink-0" />
            <span class="text-xs text-gray-500">
              开启后，管理后台可通过统一接口 <code>POST /api/admin/ai/image/generate</code> 调用 AI 生图
            </span>
          </div>
        </el-form-item>

        <el-form-item label="生图接口地址">
          <div class="w-full space-y-1.5">
            <div class="flex w-full flex-wrap items-center gap-2">
              <el-input
                v-model="aiImageForm.baseUrl"
                placeholder="例如：http://127.0.0.1:8001/v1 或 https://api.openai.com/v1"
                class="min-w-[260px] flex-1"
              />
              <el-button plain @click="applyFlowAgentPreset">
                填入本地 Flow Agent 默认值
              </el-button>
            </div>
            <div class="text-xs text-gray-400">
              兼容 OpenAI Images 协议，后端自动补齐 /v1/images/generations
            </div>
          </div>
        </el-form-item>

        <el-form-item label="API 密钥（选填）">
          <div class="w-full space-y-2">
            <el-input
              v-model="aiImageForm.apiKey"
              type="password"
              show-password
              autocomplete="new-password"
              :placeholder="
                aiImageConfigView?.hasApiKey
                  ? `当前已保存密钥 (${aiImageConfigView.apiKeyMasked})，留空保持不变；本地 Flow Agent 可勾选清空`
                  : '本地 Flow Agent 无需填写；若对接云端 OpenAI 兼容生图服务请填入 API Key'
              "
            />
            <div v-if="aiImageConfigView?.hasApiKey" class="flex items-center justify-between text-xs text-gray-500">
              <span>已安全保存密钥：{{ aiImageConfigView.apiKeyMasked }}</span>
              <el-checkbox v-model="aiImageForm.clearApiKey" size="small">
                保存时清空已保存密钥
              </el-checkbox>
            </div>
          </div>
        </el-form-item>

        <el-form-item label="模型与默认画幅">
          <div class="flex w-full flex-wrap items-center gap-3">
            <el-select
              v-model="aiImageForm.model"
              filterable
              allow-create
              default-first-option
              placeholder="选择或输入模型名"
              style="width: 240px"
            >
              <el-option
                v-for="opt in aiImageModelOptions"
                :key="opt.value"
                :label="opt.label"
                :value="opt.value"
              />
            </el-select>
            <el-select
              v-model="aiImageForm.defaultSize"
              placeholder="默认图片尺寸"
              style="width: 210px"
            >
              <el-option
                v-for="opt in aiImageSizeOptions"
                :key="opt.value"
                :label="opt.label"
                :value="opt.value"
              />
            </el-select>
            <div class="flex items-center gap-1.5">
              <span class="text-xs text-gray-500">超时(秒)</span>
              <el-input-number
                v-model="aiImageForm.timeoutSec"
                :min="10"
                :max="300"
                :step="10"
                size="small"
                style="width: 106px"
              />
            </div>
          </div>
        </el-form-item>

        <el-form-item label="试生图提示词">
          <el-input
            v-model="aiImageForm.testPrompt"
            type="textarea"
            :rows="2"
            placeholder="点击「立即试生图测试」时使用的提示词（中英文均可，Flow 推荐英文提示词）"
          />
        </el-form-item>

        <el-form-item v-if="aiImageTestResult">
          <div class="w-full space-y-3">
            <el-alert
              :type="aiImageTestResult.ok ? 'success' : 'error'"
              :closable="true"
              @close="aiImageTestResult = null"
              class="w-full"
            >
              <template #title>
                <span v-if="aiImageTestResult.ok">
                  {{ aiImageTestResult.mode === "GENERATE" ? "试生图成功" : "服务探测通过" }}
                  · 模型 {{ aiImageTestResult.model || aiImageForm.model }}
                  · 耗时 {{ aiImageTestResult.latencyMs ?? 0 }}ms
                </span>
                <span v-else>
                  {{ aiImageTestResult.mode === "GENERATE" ? "试生图失败" : "服务探测失败" }}
                  · {{ aiImageTestResult.errorMessage }}
                </span>
              </template>
              <div v-if="aiImageTestResult.message" class="mt-1 text-xs text-gray-700">
                {{ aiImageTestResult.message }}
              </div>
            </el-alert>

            <div
              v-if="aiImageTestResult.ok && (aiImageTestResult.imageDataUrl || aiImageTestResult.imageUrl)"
              class="flex flex-wrap items-start gap-4 rounded-xl border border-slate-200 bg-slate-50 p-3"
            >
              <el-image
                :src="aiImageTestResult.imageDataUrl || aiImageTestResult.imageUrl"
                :preview-src-list="[aiImageTestResult.imageDataUrl || aiImageTestResult.imageUrl || '']"
                fit="contain"
                class="h-44 w-44 rounded-lg border border-slate-200 bg-white"
              />
              <div class="min-w-[200px] flex-1 space-y-2 text-xs text-slate-600">
                <div class="font-semibold text-slate-800">试生图预览（点击图片可放大查看）</div>
                <div>请求接口：<code>{{ aiImageTestResult.endpoint }}</code></div>
                <div v-if="aiImageTestResult.imageUrl">
                  上游地址：<code class="break-all">{{ aiImageTestResult.imageUrl }}</code>
                </div>
                <div class="pt-1">
                  <el-button
                    size="small"
                    type="primary"
                    plain
                    tag="a"
                    :href="aiImageTestResult.imageDataUrl || aiImageTestResult.imageUrl"
                    download="flow-agent-test.jpg"
                  >
                    下载测试图片
                  </el-button>
                </div>
              </div>
            </div>
          </div>
        </el-form-item>

        <el-form-item>
          <div class="flex flex-wrap items-center gap-2">
            <el-button type="primary" :loading="savingAiImage" @click="saveAiImageSettings">
              保存生图配置
            </el-button>
            <el-button
              type="success"
              plain
              :loading="testingAiImageHealth"
              :disabled="testingAiImageGenerate"
              @click="handleTestAiImage(false)"
            >
              检测服务与余额
            </el-button>
            <el-button
              type="warning"
              plain
              :loading="testingAiImageGenerate"
              :disabled="testingAiImageHealth"
              @click="handleTestAiImage(true)"
            >
              立即试生图测试
            </el-button>
          </div>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never">
      <template #header>
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex items-center gap-2">
            <span class="font-bold text-gray-800">学生端默认主题与外观配置</span>
            <el-tag type="primary" size="small">
              {{ skinOptions.find(s => s.code === defaultThemeForm.uiSkin)?.title || defaultThemeForm.uiSkin }}
            </el-tag>
            <el-tag :type="defaultThemeForm.darkMode ? 'info' : 'warning'" size="small">
              {{ defaultThemeForm.darkMode ? "默认暗黑" : "默认浅色" }}
            </el-tag>
          </div>
          <span class="text-xs text-gray-500">配置版本：v{{ defaultThemeForm.version }}</span>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        class="mb-4"
        title="生效规则：保存后，学生端下次启动或重新进入应用时，将自动以此处配置的默认皮肤、主题色与明暗模式为准；学生在当前会话内仍可在「我的 → 主题设置」临时切换体验。"
      />

      <el-form label-width="140px" class="max-w-3xl">
        <el-form-item label="默认界面风格">
          <div class="grid w-full grid-cols-1 gap-3 sm:grid-cols-3">
            <div
              v-for="skin in skinOptions"
              :key="skin.code"
              class="cursor-pointer rounded-xl border-2 p-3 transition"
              :class="
                defaultThemeForm.uiSkin === skin.code
                  ? 'border-sky-500 bg-sky-50/70 shadow-xs'
                  : 'border-slate-200 bg-white hover:border-slate-300'
              "
              @click="defaultThemeForm.uiSkin = skin.code"
            >
              <div class="flex items-center justify-between gap-1">
                <span class="text-sm font-bold text-slate-800">{{ skin.title }}</span>
                <el-tag
                  size="small"
                  :type="defaultThemeForm.uiSkin === skin.code ? 'primary' : 'info'"
                >
                  {{ skin.badge }}
                </el-tag>
              </div>
              <div class="mt-1.5 text-xs leading-relaxed text-slate-500">
                {{ skin.desc }}
              </div>
            </div>
          </div>
        </el-form-item>

        <el-form-item label="默认主题强调色">
          <div class="w-full space-y-2.5">
            <div class="flex flex-wrap items-center gap-2">
              <button
                v-for="preset in themeColorPresets"
                :key="preset.hex"
                type="button"
                class="flex items-center gap-1.5 rounded-lg border px-2.5 py-1.5 text-xs font-medium transition"
                :class="
                  defaultThemeForm.themeHex.toUpperCase() === preset.hex
                    ? 'border-slate-900 bg-slate-900 text-white'
                    : 'border-slate-200 bg-white text-slate-700 hover:border-slate-400'
                "
                @click="selectColorPreset(preset)"
              >
                <span
                  class="inline-block h-3.5 w-3.5 rounded-full border border-black/15"
                  :style="{ backgroundColor: preset.hex }"
                />
                <span>{{ preset.name }}</span>
              </button>
            </div>
            <div class="flex flex-wrap items-center gap-2.5">
              <el-color-picker
                v-model="defaultThemeForm.themeHex"
                @change="(v: string | null) => { if (v) defaultThemeForm.themeHex = v.toUpperCase(); }"
              />
              <el-input
                v-model="defaultThemeForm.themeHex"
                placeholder="#67C6FF"
                style="width: 120px"
              />
              <el-input
                v-model="defaultThemeForm.themeName"
                placeholder="主题名称，如 天青漫画"
                style="width: 180px"
                maxlength="20"
              />
            </div>
          </div>
        </el-form-item>

        <el-form-item label="默认暗黑模式">
          <div class="flex flex-wrap items-center gap-3">
            <el-switch v-model="defaultThemeForm.darkMode" class="shrink-0" />
            <span class="text-xs text-gray-500">
              开启后，学生端下次进入默认使用深色护眼主题；关闭则默认浅色模式
            </span>
          </div>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="savingTheme" @click="saveDefaultThemeSettings">
            保存默认主题配置
          </el-button>
        </el-form-item>
      </el-form>
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
              开启后，未登录学生可先游客试玩各年级关卡（阶段升级测评需登录后参加）
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
              <el-tag
                :type="
                  effectiveVersion.downloadChannel === 'OSS_DIRECT'
                    ? 'success'
                    : effectiveVersion.downloadChannel === 'SERVER_PROXY'
                      ? 'warning'
                      : 'info'
                "
                size="small"
              >
                {{
                  effectiveVersion.downloadChannel === "OSS_DIRECT"
                    ? "OSS 自定义域名直连高速"
                    : effectiveVersion.downloadChannel === "SERVER_PROXY"
                      ? "服务器中转（受服务器带宽限制）"
                      : effectiveVersion.downloadChannel === "EXTERNAL_DIRECT"
                        ? "外链直连下载"
                        : "本地目录托管"
                }}
              </el-tag>
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

        <el-form-item label="OSS 加速域名">
          <div class="w-full space-y-1.5">
            <el-input
              v-model="versionForm.ossCustomDomain"
              placeholder="例如：https://dl.yourdomain.com（留空则经服务器内网中转）"
              clearable
            />
            <div class="text-xs leading-relaxed text-gray-500">
              说明：阿里云 OSS 安全策略禁止默认公网域名（<code>*.aliyuncs.com</code>）下载 <code>.apk</code>，因此未配置自定义域名时须经服务器中转（受服务器出网带宽限制）。在 OSS 控制台为 Bucket 绑定自定义 CNAME/CDN 域名并填写到此处保存后，学生端 App 更新将自动切换为<strong>应用内直连 OSS 满速下载</strong>（无需重启服务，不跳转浏览器）。
            </div>
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
            :rows="6"
            maxlength="2500"
            show-word-limit
            placeholder="展示给学生的版本更新内容（最多支持 2500 字）"
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
