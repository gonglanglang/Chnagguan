<script setup lang="ts">
import { ref, watch, nextTick, onBeforeUnmount } from "vue";
import { MathfieldElement } from "mathlive";
import "mathlive/static.css";
import "mathlive/fonts.css";
import MathFormulaText from "./MathFormulaText.vue";
import { wrapLatexDelimiter } from "@/utils/math";

defineOptions({
  name: "MathFormulaDialog"
});

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    initialLatex?: string;
    targetLabel?: string;
  }>(),
  {
    initialLatex: "",
    targetLabel: "题目内容"
  }
);

const emit = defineEmits<{
  (e: "update:modelValue", val: boolean): void;
  (e: "insert", formattedLatex: string): void;
}>();

let mathLiveConfigured = false;
function ensureMathLiveConfigured() {
  if (mathLiveConfigured) return;
  MathfieldElement.fontsDirectory = `${import.meta.env.BASE_URL}mathlive/fonts`;
  MathfieldElement.soundsDirectory = null;
  mathLiveConfigured = true;
}

interface QuickTemplate {
  label: string;
  snippet: string;
}

const STRUCTURE_TEMPLATES: QuickTemplate[] = [
  { label: "分数 a/b", snippet: "\\frac{#?}{#?}" },
  { label: "二次根号 √", snippet: "\\sqrt{#?}" },
  { label: "n次根号", snippet: "\\sqrt[#?]{#?}" },
  { label: "次方/上标 x²", snippet: "^{#?}" },
  { label: "角标/下标 aₙ", snippet: "_{#?}" },
  { label: "绝对值 |x|", snippet: "\\left| #? \\right|" },
  { label: "圆括号 ()", snippet: "\\left( #? \\right)" },
  { label: "方程组 { }", snippet: "\\begin{cases} #? \\\\ #? \\end{cases}" },
  { label: "分数幂 x^(m/n)", snippet: "#@^{\\frac{#?}{#?}}" }
];

const SYMBOL_TEMPLATES: QuickTemplate[] = [
  { label: "±", snippet: "\\pm" },
  { label: "×", snippet: "\\times" },
  { label: "÷", snippet: "\\div" },
  { label: "·", snippet: "\\cdot" },
  { label: "≠", snippet: "\\ne" },
  { label: "≤", snippet: "\\le" },
  { label: "≥", snippet: "\\ge" },
  { label: "≈", snippet: "\\approx" },
  { label: "π", snippet: "\\pi" },
  { label: "°", snippet: "^{\\circ}" },
  { label: "△", snippet: "\\triangle" },
  { label: "∠", snippet: "\\angle" },
  { label: "⊥", snippet: "\\perp" },
  { label: "∥", snippet: "\\parallel" },
  { label: "∞", snippet: "\\infty" },
  { label: "∈", snippet: "\\in" },
  { label: "∪", snippet: "\\cup" },
  { label: "∩", snippet: "\\cap" },
  { label: "sin", snippet: "\\sin" },
  { label: "cos", snippet: "\\cos" },
  { label: "tan", snippet: "\\tan" },
  { label: "log", snippet: "\\log_{#?}{#?}" },
  { label: "∑", snippet: "\\sum_{i=1}^{n}" },
  { label: "lim", snippet: "\\lim_{x \\to #?}" },
  { label: "∫", snippet: "\\int_{#?}^{#?}" }
];

const mathFieldRef = ref<MathfieldElement | null>(null);
const keyboardHostRef = ref<HTMLElement | null>(null);
const latexText = ref("");
const displayMode = ref(false);
const showVirtualKeyboard = ref(true);

function mountKeyboardIntoHost() {
  const vk = window.mathVirtualKeyboard;
  if (!vk) return;
  if (showVirtualKeyboard.value && keyboardHostRef.value) {
    vk.container = keyboardHostRef.value;
    vk.show({ animate: false });
  } else {
    vk.hide({ animate: false });
  }
}

function teardownKeyboard() {
  const vk = window.mathVirtualKeyboard;
  if (!vk) return;
  vk.hide({ animate: false });
  vk.container = null;
}

watch(
  () => props.modelValue,
  async visible => {
    if (visible) {
      ensureMathLiveConfigured();
      latexText.value = props.initialLatex || "";
      displayMode.value = false;
      await nextTick();
      const mf = mathFieldRef.value;
      if (mf) {
        mf.mathVirtualKeyboardPolicy = "manual";
        mf.value = latexText.value;
        mountKeyboardIntoHost();
        mf.focus?.();
      }
    } else {
      teardownKeyboard();
    }
  }
);

watch(showVirtualKeyboard, async () => {
  if (!props.modelValue) return;
  await nextTick();
  mountKeyboardIntoHost();
  mathFieldRef.value?.focus?.();
});

onBeforeUnmount(() => {
  teardownKeyboard();
});

function handleMathInput() {
  if (!mathFieldRef.value) return;
  latexText.value = mathFieldRef.value.value;
}

function handleSourceEdit(val: string) {
  latexText.value = val;
  if (mathFieldRef.value && mathFieldRef.value.value !== val) {
    mathFieldRef.value.setValue(val, { silenceNotifications: true });
  }
}

function insertTemplate(snippet: string) {
  const mf = mathFieldRef.value;
  if (!mf) return;
  mf.insert(snippet, {
    insertionMode: "replaceSelection",
    selectionMode: "placeholder",
    focus: true
  });
  latexText.value = mf.value;
}

function handleClear() {
  latexText.value = "";
  if (mathFieldRef.value) {
    mathFieldRef.value.setValue("", { silenceNotifications: true });
    mathFieldRef.value.focus?.();
  }
}

function handleClose() {
  teardownKeyboard();
  emit("update:modelValue", false);
}

function handleConfirm() {
  const formatted = wrapLatexDelimiter(latexText.value, displayMode.value);
  if (!formatted) return;
  emit("insert", formatted);
  handleClose();
}
</script>

<template>
  <el-dialog
    :model-value="modelValue"
    width="780px"
    top="4vh"
    :close-on-click-modal="false"
    append-to-body
    @close="handleClose"
  >
    <template #header>
      <div class="flex items-center gap-2">
        <span class="text-base font-bold text-gray-800">数学公式可视化编辑器</span>
        <el-tag type="success" size="small">插入位置：{{ targetLabel }}</el-tag>
      </div>
    </template>

    <div class="space-y-3">
      <div class="rounded-lg border border-gray-200 bg-gray-50 p-3 space-y-2">
        <div class="flex flex-wrap items-center gap-1.5">
          <span class="mr-1 text-xs font-medium text-gray-500">常用结构：</span>
          <el-button
            v-for="item in STRUCTURE_TEMPLATES"
            :key="item.label"
            size="small"
            plain
            @click="insertTemplate(item.snippet)"
          >
            {{ item.label }}
          </el-button>
        </div>
        <div class="flex flex-wrap items-center gap-1">
          <span class="mr-1 text-xs font-medium text-gray-500">常用符号：</span>
          <el-button
            v-for="item in SYMBOL_TEMPLATES"
            :key="item.label"
            size="small"
            class="symbol-btn"
            @click="insertTemplate(item.snippet)"
          >
            {{ item.label }}
          </el-button>
        </div>
      </div>

      <div>
        <div class="mb-1 flex items-center justify-between">
          <span class="text-xs text-gray-500">
            可视化编辑区（点击上方按钮、虚拟键盘按键，或按 <code>/</code> 自动生成分数）
          </span>
          <el-button
            link
            type="primary"
            size="small"
            @click="showVirtualKeyboard = !showVirtualKeyboard"
          >
            {{ showVirtualKeyboard ? "收起虚拟键盘" : "展开虚拟键盘" }}
          </el-button>
        </div>
        <math-field
          ref="mathFieldRef"
          class="visual-math-field"
          @input="handleMathInput"
        />
      </div>

      <div v-if="showVirtualKeyboard" ref="keyboardHostRef" class="math-kbd-host" />

      <div class="rounded-lg border border-green-100 bg-green-50/50 p-3 space-y-2">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex flex-wrap items-center gap-3 text-xs text-gray-600">
            <span class="font-medium whitespace-nowrap">排版方式：</span>
            <el-radio-group v-model="displayMode" size="small">
              <el-radio :value="false">行内公式（适合题干/选项混排）</el-radio>
              <el-radio :value="true">居中公式（适合复杂推导/方程组）</el-radio>
            </el-radio-group>
          </div>
          <div class="flex items-center gap-2 text-xs text-gray-600">
            <span class="whitespace-nowrap">实际效果：</span>
            <span class="rounded bg-white px-2 py-0.5 border border-gray-200">
              <MathFormulaText
                :text="latexText.trim() ? wrapLatexDelimiter(latexText, false) : '等待输入公式'"
                inline
              />
            </span>
          </div>
        </div>

        <el-input
          :model-value="latexText"
          size="small"
          placeholder="这里会同步显示公式源码，也可以直接粘贴 LaTeX 公式"
          @update:model-value="handleSourceEdit"
        >
          <template #prepend>LaTeX</template>
        </el-input>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-between">
        <el-button size="small" @click="handleClear">清空公式</el-button>
        <div class="flex gap-2">
          <el-button @click="handleClose">取消</el-button>
          <el-button
            type="primary"
            :disabled="!latexText.trim()"
            @click="handleConfirm"
          >
            插入到{{ targetLabel }}
          </el-button>
        </div>
      </div>
    </template>
  </el-dialog>
</template>

<style lang="scss" scoped>
.symbol-btn {
  min-width: 30px;
  padding: 4px 8px;
  margin-left: 0 !important;
}

.visual-math-field {
  display: block;
  width: 100%;
  min-height: 76px;
  padding: 10px 14px;
  font-size: 22px;
  background-color: #fff;
  border: 1.5px solid #cbd5e1;
  border-radius: 8px;
  transition: border-color 0.2s, box-shadow 0.2s;

  &:focus-within {
    border-color: #16a34a;
    box-shadow: 0 0 0 3px rgb(22 163 74 / 12%);
  }
}

.math-kbd-host {
  position: relative;
  width: 100%;
  overflow: hidden;
  background: #f1f5f9;
  border: 1px solid #cbd5e1;
  border-radius: 8px;

  --keyboard-zindex: 4000;
  --keyboard-accent-color: #16a34a;
  --keyboard-background: #f1f5f9;
  --keyboard-border: #cbd5e1;
  --keyboard-horizontal-rule: 1px solid #e2e8f0;
  --keyboard-toolbar-text: #334155;
  --keyboard-toolbar-background-hover: #e2e8f0;
  --keyboard-padding-top: 6px;
  --keyboard-padding-bottom: 8px;
  --keyboard-padding-horizontal: 6px;
  --keycap-background: #ffffff;
  --keycap-background-hover: #f0fdf4;
  --keycap-text: #1e293b;
  --keycap-border: #cbd5e1;
  --keycap-border-bottom: #94a3b8;
  --keycap-secondary-background: #e2e8f0;
  --keycap-secondary-background-hover: #cbd5e1;
  --keycap-secondary-text: #0f172a;
  --keycap-secondary-border: #cbd5e1;
  --keycap-secondary-border-bottom: #94a3b8;
  --keycap-height: 42px;
  --keycap-gap: 6px;
}

:deep(.ML__keyboard),
:deep(.ML__keyboard > .MLK__backdrop),
:deep(.MLK__plate) {
  position: relative !important;
  top: 0 !important;
  bottom: 0 !important;
  left: 0 !important;
  width: 100% !important;
  height: auto !important;
  transform: none !important;
}
</style>
