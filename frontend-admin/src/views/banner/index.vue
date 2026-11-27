<script setup lang="ts">
import "@wangeditor-next/editor/dist/css/style.css";
import { ref, reactive, shallowRef, onMounted, onBeforeUnmount } from "vue";
import { ElMessage, ElMessageBox, type UploadRequestOptions } from "element-plus";
import { Editor, Toolbar } from "@wangeditor-next/editor-for-vue";
import type { IDomEditor, IEditorConfig, IToolbarConfig } from "@wangeditor-next/editor";
import {
  getAdminBanners,
  getAdminBannerDetail,
  createAdminBanner,
  updateAdminBanner,
  toggleAdminBannerStatus,
  deleteAdminBanner,
  uploadAdminBannerImage,
  type HomeBannerItem
} from "@/api/guoguanla";

defineOptions({
  name: "HomeBannerManage"
});

const loading = ref(false);
const saving = ref(false);
const uploadingCover = ref(false);
const list = ref<HomeBannerItem[]>([]);

const dialogVisible = ref(false);
const previewMode = ref<"split" | "edit" | "preview">("split");
const editingId = ref<number | null>(null);
const editorRef = shallowRef<IDomEditor | null>(null);

const form = reactive({
  title: "",
  subtitle: "",
  imageKey: "",
  imageUrl: "",
  contentHtml: "",
  sortOrder: 0,
  enabled: 1
});

const presetCovers = [
  { key: "preset://faculty-1", label: "核心教研蓝", url: "/api/app/banners/preset/faculty-1" },
  { key: "preset://faculty-2", label: "中考几何绿", url: "/api/app/banners/preset/faculty-2" },
  { key: "preset://faculty-3", label: "高考压轴紫", url: "/api/app/banners/preset/faculty-3" }
];

const toolbarConfig: Partial<IToolbarConfig> = {
  excludeKeys: ["uploadVideo", "insertVideo", "group-video", "fullScreen"]
};

const editorConfig: Partial<IEditorConfig> = {
  placeholder: "请输入该轮播图对应的师资力量富文本详细介绍（支持标题、重点加粗、列表、引用、上传图片，App 端将原生渲染展示）...",
  MENU_CONF: {
    uploadImage: {
      async customUpload(file: File, insertFn: (url: string, alt?: string, href?: string) => void) {
        try {
          const fd = new FormData();
          fd.append("file", file);
          const res = await uploadAdminBannerImage(fd);
          const url = res.data.mediaUrl || res.data.previewUrl;
          insertFn(url, file.name, "");
          ElMessage.success("富文本图片已上传并插入");
        } catch (err: any) {
          ElMessage.error(err?.message || "富文本图片上传失败");
        }
      }
    }
  }
};

function handleEditorCreated(editor: IDomEditor) {
  editorRef.value = editor;
}

function destroyEditor() {
  if (editorRef.value) {
    editorRef.value.destroy();
    editorRef.value = null;
  }
}

async function fetchList() {
  loading.value = true;
  try {
    const res = await getAdminBanners();
    list.value = res.data || [];
  } finally {
    loading.value = false;
  }
}

function openCreate() {
  editingId.value = null;
  form.title = "";
  form.subtitle = "";
  form.imageKey = "preset://faculty-1";
  form.imageUrl = "/api/app/banners/preset/faculty-1";
  form.contentHtml =
    "<h2>名师团队介绍</h2><p>在此填写老师的教学履历、核心教研成果与提分方法，支持插入多张师资风采照片。</p><ul><li><strong>教学年限：</strong>10 年以上一线初高中毕业班带班经验</li><li><strong>擅长板块：</strong>几何辅助线模型、二次函数压轴、导数与圆锥曲线</li></ul>";
  form.sortOrder = list.value.length + 1;
  form.enabled = 1;
  previewMode.value = "split";
  dialogVisible.value = true;
}

async function openEdit(row: HomeBannerItem) {
  loading.value = true;
  try {
    const res = await getAdminBannerDetail(row.id);
    const d = res.data;
    editingId.value = d.id;
    form.title = d.title || "";
    form.subtitle = d.subtitle || "";
    form.imageKey = d.imageKey || "";
    form.imageUrl = d.imageUrl || "";
    form.contentHtml = d.contentHtml || "";
    form.sortOrder = d.sortOrder ?? 0;
    form.enabled = d.enabled ?? 1;
    previewMode.value = "split";
    dialogVisible.value = true;
  } finally {
    loading.value = false;
  }
}

function selectPresetCover(preset: { key: string; url: string }) {
  form.imageKey = preset.key;
  form.imageUrl = preset.url;
}

async function handleCoverUpload(options: UploadRequestOptions) {
  uploadingCover.value = true;
  try {
    const fd = new FormData();
    fd.append("file", options.file);
    const res = await uploadAdminBannerImage(fd);
    form.imageKey = res.data.objectKey;
    form.imageUrl = res.data.mediaUrl || res.data.previewUrl;
    ElMessage.success("轮播图封面上传成功");
  } finally {
    uploadingCover.value = false;
  }
}

async function handleSave() {
  if (!form.title.trim()) {
    ElMessage.warning("请填写轮播图标题");
    return;
  }
  if (!form.imageKey.trim()) {
    ElMessage.warning("请先上传轮播图封面或选择预设封面");
    return;
  }
  saving.value = true;
  try {
    const payload = {
      title: form.title.trim(),
      subtitle: form.subtitle.trim(),
      imageKey: form.imageKey.trim(),
      contentHtml: form.contentHtml,
      sortOrder: Number(form.sortOrder) || 0,
      enabled: form.enabled
    };
    if (editingId.value) {
      await updateAdminBanner(editingId.value, payload);
      ElMessage.success("师资轮播图已更新保存");
    } else {
      await createAdminBanner(payload);
      ElMessage.success("新增师资轮播图成功");
    }
    dialogVisible.value = false;
    await fetchList();
  } finally {
    saving.value = false;
  }
}

async function handleToggleStatus(row: HomeBannerItem, val: number) {
  await toggleAdminBannerStatus(row.id, val);
  row.enabled = val;
  ElMessage.success(val === 1 ? "已上架至首页轮播" : "已下架隐藏");
}

async function handleDelete(row: HomeBannerItem) {
  await ElMessageBox.confirm(`确定删除轮播图「${row.title}」吗？删除后学生端首页将不再展示。`, "确认删除", {
    type: "warning"
  });
  await deleteAdminBanner(row.id);
  ElMessage.success("已删除");
  await fetchList();
}

onMounted(fetchList);
onBeforeUnmount(destroyEditor);
</script>

<template>
  <div v-loading="loading" class="space-y-4">
    <el-card shadow="never">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 class="text-base font-bold text-gray-800">首页师资力量轮播图配置</h2>
          <p class="mt-1 text-xs text-gray-500">
            配置学生端 App 首页顶部的师资力量轮播图；每张轮播图均绑定独立富文本详情页，学生点击轮播图即可在 App 内原生渲染查看。
          </p>
        </div>
        <div class="flex items-center gap-2">
          <el-button plain @click="fetchList">刷新</el-button>
          <el-button type="primary" @click="openCreate">+ 新增轮播图</el-button>
        </div>
      </div>
    </el-card>

    <el-card shadow="never">
      <el-table :data="list" border stripe class="w-full">
        <el-table-column label="排序" width="76" align="center" prop="sortOrder" />
        <el-table-column label="轮播封面图" width="210" align="center">
          <template #default="{ row }">
            <div class="mx-auto h-20 w-44 overflow-hidden rounded-lg border border-slate-200 bg-slate-50">
              <img
                v-if="row.imageUrl"
                :src="row.imageUrl"
                :alt="row.title"
                class="h-full w-full object-cover"
              />
              <div v-else class="flex h-full items-center justify-center text-xs text-slate-400">
                暂无图片
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="标题与师资标签" min-width="240">
          <template #default="{ row }">
            <div class="font-bold text-slate-800">{{ row.title }}</div>
            <div class="mt-1 text-xs text-slate-500">{{ row.subtitle || "暂无副标题" }}</div>
          </template>
        </el-table-column>
        <el-table-column label="详情富文本" width="120" align="center">
          <template #default="{ row }">
            <el-tag :type="row.hasDetailContent ? 'success' : 'info'" size="small">
              {{ row.hasDetailContent ? "已配置详情" : "未配置" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="展示状态" width="110" align="center">
          <template #default="{ row }">
            <el-switch
              :model-value="row.enabled"
              :active-value="1"
              :inactive-value="0"
              @change="(val: string | number | boolean) => handleToggleStatus(row, Number(val))"
            />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="160" align="center" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="openEdit(row)">编辑图文</el-button>
            <el-button link type="danger" size="small" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 轮播图 + 富文本详情编辑弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="editingId ? '编辑师资轮播图与富文本详情' : '新增师资轮播图'"
      width="1180px"
      top="3vh"
      destroy-on-close
      :close-on-click-modal="false"
      @closed="destroyEditor"
    >
      <div class="space-y-4">
        <!-- 基础配置区 -->
        <div class="grid grid-cols-1 gap-4 rounded-xl border border-slate-200 bg-slate-50/70 p-4 md:grid-cols-12">
          <div class="space-y-3 md:col-span-7">
            <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <div class="mb-1 text-xs font-semibold text-slate-600">轮播图标题 *</div>
                <el-input v-model="form.title" maxlength="128" placeholder="如：清北名师数学教研团队" />
              </div>
              <div>
                <div class="mb-1 text-xs font-semibold text-slate-600">副标题 / 师资简介标签</div>
                <el-input v-model="form.subtitle" maxlength="255" placeholder="如：10年一线教研 · 中高考压轴精讲" />
              </div>
            </div>
            <div class="flex flex-wrap items-center gap-4">
              <div class="flex items-center gap-2">
                <span class="text-xs font-semibold text-slate-600">排序权重</span>
                <el-input-number v-model="form.sortOrder" :min="0" :max="999" size="small" style="width: 100px" />
                <span class="text-xs text-slate-400">数字越小越靠前</span>
              </div>
              <div class="flex items-center gap-2">
                <span class="text-xs font-semibold text-slate-600">立即上架</span>
                <el-switch v-model="form.enabled" :active-value="1" :inactive-value="0" size="small" />
              </div>
            </div>
          </div>

          <!-- 封面图上传 -->
          <div class="space-y-2 md:col-span-5">
            <div class="flex items-center justify-between">
              <span class="text-xs font-semibold text-slate-600">轮播图封面（建议 16:7 横版，如 960×400）*</span>
              <el-upload :show-file-list="false" accept="image/*" :http-request="handleCoverUpload">
                <el-button size="small" type="primary" plain :loading="uploadingCover">
                  上传封面图
                </el-button>
              </el-upload>
            </div>
            <div class="relative h-28 w-full overflow-hidden rounded-lg border border-slate-200 bg-white">
              <img
                v-if="form.imageUrl"
                :src="form.imageUrl"
                alt="封面预览"
                class="h-full w-full object-cover"
              />
              <div v-else class="flex h-full items-center justify-center text-xs text-slate-400">
                请上传轮播图封面
              </div>
            </div>
            <div class="flex flex-wrap items-center gap-1.5">
              <span class="text-[11px] text-slate-400">内置预设：</span>
              <el-button
                v-for="p in presetCovers"
                :key="p.key"
                size="small"
                :type="form.imageKey === p.key ? 'primary' : 'default'"
                plain
                @click="selectPresetCover(p)"
              >
                {{ p.label }}
              </el-button>
            </div>
          </div>
        </div>

        <!-- 富文本编辑 + App 详情实时预览 -->
        <div class="space-y-2">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span class="text-sm font-bold text-slate-800">绑定详情页富文本内容（点击轮播图后 App 原生渲染）</span>
              <span class="ml-2 text-xs text-slate-400">支持图文混排、颜色强调、列表、表格、引用</span>
            </div>
            <el-radio-group v-model="previewMode" size="small">
              <el-radio-button value="split">双栏编辑+App预览</el-radio-button>
              <el-radio-button value="edit">仅富文本编辑</el-radio-button>
              <el-radio-button value="preview">仅App预览</el-radio-button>
            </el-radio-group>
          </div>

          <div class="grid grid-cols-1 gap-4 lg:grid-cols-12">
            <div
              v-show="previewMode !== 'preview'"
              :class="previewMode === 'split' ? 'lg:col-span-8' : 'lg:col-span-12'"
              class="overflow-hidden rounded-xl border border-slate-200 bg-white"
            >
              <Toolbar
                style="border-bottom: 1px solid #e2e8f0"
                :editor="editorRef"
                :defaultConfig="toolbarConfig"
                mode="default"
              />
              <Editor
                v-model="form.contentHtml"
                style="height: 390px; overflow-y: hidden"
                :defaultConfig="editorConfig"
                mode="default"
                @onCreated="handleEditorCreated"
              />
            </div>

            <!-- App 端详情实时预览框 -->
            <div
              v-show="previewMode !== 'edit'"
              :class="previewMode === 'split' ? 'lg:col-span-4' : 'lg:col-span-12'"
              class="flex flex-col items-center justify-center rounded-xl border border-slate-200 bg-slate-100 p-3"
            >
              <div class="mb-2 text-xs font-semibold text-slate-500">App 详情页渲染预览（375px 宽）</div>
              <div class="flex h-[430px] w-[320px] flex-col overflow-hidden rounded-[24px] border-[6px] border-slate-800 bg-white shadow-lg">
                <div class="flex h-9 shrink-0 items-center justify-between border-b border-slate-100 px-3 text-xs font-bold text-slate-800">
                  <span>‹ 返回</span>
                  <span class="max-w-[180px] truncate">{{ form.title || "师资详情" }}</span>
                  <span class="w-6" />
                </div>
                <div class="min-h-0 flex-1 overflow-y-auto">
                  <img
                    v-if="form.imageUrl"
                    :src="form.imageUrl"
                    alt="封面"
                    class="h-32 w-full object-cover"
                  />
                  <div class="p-3.5">
                    <div class="text-base font-extrabold text-slate-900">{{ form.title || "未命名标题" }}</div>
                    <div v-if="form.subtitle" class="mt-1 text-xs text-slate-500">{{ form.subtitle }}</div>
                    <div class="my-3 h-px bg-slate-100" />
                    <div
                      class="app-rich-preview text-xs leading-relaxed text-slate-700"
                      v-html="form.contentHtml || '<p style=&quot;color:#94a3b8&quot;>暂无富文本内容</p>'"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">
          {{ editingId ? "保存修改" : "发布轮播图" }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.app-rich-preview :deep(h1),
.app-rich-preview :deep(h2),
.app-rich-preview :deep(h3) {
  margin: 0.6em 0 0.35em;
  font-weight: 800;
  color: #0f172a;
}
.app-rich-preview :deep(h2) {
  font-size: 15px;
}
.app-rich-preview :deep(h3) {
  font-size: 13.5px;
}
.app-rich-preview :deep(p) {
  margin: 0.45em 0;
}
.app-rich-preview :deep(ul),
.app-rich-preview :deep(ol) {
  padding-left: 1.25em;
  margin: 0.45em 0;
}
.app-rich-preview :deep(ul) {
  list-style: disc;
}
.app-rich-preview :deep(ol) {
  list-style: decimal;
}
.app-rich-preview :deep(blockquote) {
  padding: 6px 10px;
  margin: 8px 0;
  color: #475569;
  background: #f8fafc;
  border-left: 3px solid #0284c7;
  border-radius: 4px;
}
.app-rich-preview :deep(img) {
  max-width: 100%;
  margin: 6px 0;
  border-radius: 8px;
}
</style>
