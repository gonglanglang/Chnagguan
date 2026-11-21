import { reactive } from "vue";
import { AppVersionAPI } from "@/api/guoguanla";
import type { AppVersionInfo } from "@/types/guoguanla";

const GITHUB_RELEASE_API = "https://api.github.com/repos/gonglanglang/Chnagguan/releases/latest";

export interface LocalAppVersion {
  version: string;
  versionCode: number;
}

export interface AppUpdateModalState {
  visible: boolean;
  currentVersion: string;
  latestVersion: string;
  latestVersionCode: number;
  forceUpdate: boolean;
  releaseNotes: string;
  noteList: string[];
  downloadUrl: string;
  fallbackUrl: string;
  downloading: boolean;
  progress: number;
  errorMsg: string;
}

const updateState = reactive<AppUpdateModalState>({
  visible: false,
  currentVersion: "1.0.0",
  latestVersion: "",
  latestVersionCode: 0,
  forceUpdate: false,
  releaseNotes: "",
  noteList: [],
  downloadUrl: "",
  fallbackUrl: "",
  downloading: false,
  progress: 0,
  errorMsg: "",
});

let checkingUpdate = false;

export function useAppUpdateState(): AppUpdateModalState {
  return updateState;
}

export function dismissAppUpdateModal(): void {
  if (updateState.forceUpdate || updateState.downloading) return;
  updateState.visible = false;
}

function normalizeVersion(raw?: string | null): string {
  if (!raw) return "1.0.0";
  const trimmed = raw.trim();
  return trimmed.startsWith("v") || trimmed.startsWith("V") ? trimmed.slice(1).trim() : trimmed;
}

function deriveVersionCode(version: string): number {
  const core = normalizeVersion(version).split("-")[0] || "1.0.0";
  const [major = 1, minor = 0, patch = 0] = core.split(".").map((n) => Number(n.replace(/\D/g, "")) || 0);
  return major * 100 + minor * 10 + patch;
}

function compareVersions(v1: string, v2: string): number {
  const a = normalizeVersion(v1).split("-")[0].split(".");
  const b = normalizeVersion(v2).split("-")[0].split(".");
  const len = Math.max(a.length, b.length);
  for (let i = 0; i < len; i++) {
    const na = Number((a[i] || "0").replace(/\D/g, "")) || 0;
    const nb = Number((b[i] || "0").replace(/\D/g, "")) || 0;
    if (na !== nb) return na > nb ? 1 : -1;
  }
  return 0;
}

/**
 * 将后端下发的更新日志拆分为多条清晰的列表项
 */
export function parseReleaseNotesList(raw?: string | null): string[] {
  const text = (raw || "").trim();
  if (!text) {
    return ["优化页面布局与作答体验", "修复已知问题，建议立即更新"];
  }
  const byLines = text
    .split(/\r?\n/)
    .map((line) => line.replace(/^[-*•]\s*/, "").trim())
    .filter(Boolean);
  if (byLines.length > 1) {
    return byLines;
  }
  const normalized = text.replace(/^(过关啦\s*v?[\d.]+\s*更新[:：]\s*)/i, "");
  const parts = normalized
    .split(/[；;]+|(?=\d+[.、]\s*)/)
    .map((s) => s.replace(/^\d+[.、]\s*/, "").trim())
    .filter(Boolean);
  return parts.length > 0 ? parts : [text];
}

export async function getLocalAppVersion(): Promise<LocalAppVersion> {
  const envVer = normalizeVersion(import.meta.env.VITE_APP_VERSION || "1.0.0");
  const fallback: LocalAppVersion = {
    version: envVer,
    versionCode: deriveVersionCode(envVer),
  };

  // #ifdef APP-PLUS
  if (typeof plus !== "undefined" && plus.runtime?.getProperty) {
    return new Promise<LocalAppVersion>((resolve) => {
      try {
        plus.runtime.getProperty(plus.runtime.appid || "", (info) => {
          const ver = normalizeVersion(info?.version || envVer);
          const code = Number(info?.versionCode) || deriveVersionCode(ver);
          resolve({ version: ver, versionCode: code });
        });
      } catch {
        resolve(fallback);
      }
    });
  }
  // #endif

  return fallback;
}

function resolveDownloadUrl(rawUrl?: string): string {
  if (!rawUrl) return "";
  const url = rawUrl.trim();
  if (url.startsWith("http://") || url.startsWith("https://")) {
    return url;
  }
  // #ifdef H5
  return url;
  // #endif
  // #ifndef H5
  const origin = (import.meta.env.VITE_API_URL || "http://47.107.94.90").replace(/\/$/, "");
  return url.startsWith("/") ? `${origin}${url}` : `${origin}/${url}`;
  // #endif
}

async function fetchGithubFallback(local: LocalAppVersion): Promise<AppVersionInfo | null> {
  return new Promise((resolve) => {
    uni.request({
      url: GITHUB_RELEASE_API,
      method: "GET",
      timeout: 5000,
      header: { Accept: "application/vnd.github+json" },
      success: (res) => {
        if (res.statusCode < 200 || res.statusCode >= 300 || !res.data || typeof res.data !== "object") {
          resolve(null);
          return;
        }
        const data = res.data as Record<string, any>;
        const latestVersion = normalizeVersion(data.tag_name || "");
        if (!latestVersion) {
          resolve(null);
          return;
        }
        const assets = Array.isArray(data.assets) ? data.assets : [];
        const apkAsset = assets.find((a: any) => String(a?.name || "").toLowerCase().endsWith(".apk"));
        const downloadUrl = String(apkAsset?.browser_download_url || data.html_url || "");
        const hasUpdate = Boolean(downloadUrl) && compareVersions(latestVersion, local.version) > 0;
        resolve({
          currentVersion: local.version,
          latestVersion,
          latestVersionCode: deriveVersionCode(latestVersion),
          hasUpdate,
          forceUpdate: false,
          releaseNotes: String(data.body || ""),
          downloadUrl,
          githubReleaseUrl: String(data.html_url || ""),
          githubRepo: "gonglanglang/Chnagguan",
          githubReachable: true,
          publishedAt: String(data.published_at || ""),
          source: "GITHUB_DIRECT",
        });
      },
      fail: () => resolve(null),
    });
  });
}

export function startAppUpdateDownload(): void {
  if (updateState.downloading) return;
  const downloadUrl = updateState.downloadUrl || updateState.fallbackUrl;
  const fallbackUrl = updateState.fallbackUrl || downloadUrl;
  if (!downloadUrl) return;

  // #ifdef APP-PLUS
  const isDirectApk = downloadUrl.toLowerCase().includes(".apk") || downloadUrl.includes("/downloads/");
  if (!isDirectApk || typeof plus === "undefined") {
    if (typeof plus !== "undefined" && plus.runtime?.openURL) {
      plus.runtime.openURL(downloadUrl || fallbackUrl);
    }
    return;
  }

  updateState.downloading = true;
  updateState.progress = 0;
  updateState.errorMsg = "";

  const downloadTask = uni.downloadFile({
    url: downloadUrl,
    success: (res) => {
      updateState.downloading = false;
      if (res.statusCode === 200 && res.tempFilePath) {
        updateState.progress = 100;
        plus.runtime.install(
          res.tempFilePath,
          { force: false },
          () => {
            updateState.visible = false;
          },
          () => {
            updateState.errorMsg = "安装包拉起失败，已为您打开浏览器下载";
            plus.runtime.openURL(downloadUrl);
          },
        );
      } else {
        updateState.errorMsg = "下载失败，已为您跳转浏览器下载";
        plus.runtime.openURL(downloadUrl || fallbackUrl);
      }
    },
    fail: () => {
      updateState.downloading = false;
      updateState.errorMsg = "下载超时，已为您跳转浏览器下载";
      plus.runtime.openURL(downloadUrl || fallbackUrl);
    },
  });

  downloadTask.onProgressUpdate((progress) => {
    if (typeof progress.progress === "number") {
      updateState.progress = progress.progress;
    }
  });
  // #endif

  // #ifndef APP-PLUS
  uni.setClipboardData({
    data: downloadUrl || fallbackUrl,
    success: () => {
      uni.showToast({ title: "已复制新版本下载链接", icon: "none" });
    },
  });
  // #endif
}

export async function checkAppUpdate(options: { silent?: boolean } = {}): Promise<void> {
  if (checkingUpdate) return;
  checkingUpdate = true;

  try {
    const local = await getLocalAppVersion();
    let info: AppVersionInfo | null = null;

    try {
      info = await AppVersionAPI.checkLatest({
        currentVersion: local.version,
        versionCode: local.versionCode,
      });
    } catch {
      info = await fetchGithubFallback(local);
    }

    if (!info) {
      if (!options.silent) {
        uni.showToast({ title: "暂时无法连接更新服务器", icon: "none" });
      }
      return;
    }

    if (!info.hasUpdate) {
      if (!options.silent) {
        uni.showToast({ title: `当前已是最新版本 v${local.version}`, icon: "none" });
      }
      return;
    }

    const downloadUrl = resolveDownloadUrl(info.downloadUrl);
    const fallbackUrl = info.githubReleaseUrl || downloadUrl;
    if (!downloadUrl && !fallbackUrl) {
      if (!options.silent) {
        uni.showToast({ title: `当前已是最新版本 v${local.version}`, icon: "none" });
      }
      return;
    }

    updateState.currentVersion = local.version;
    updateState.latestVersion = info.latestVersion || local.version;
    updateState.latestVersionCode = info.latestVersionCode || 0;
    updateState.forceUpdate = Boolean(info.forceUpdate);
    updateState.releaseNotes = info.releaseNotes || "";
    updateState.noteList = parseReleaseNotesList(info.releaseNotes);
    updateState.downloadUrl = downloadUrl;
    updateState.fallbackUrl = fallbackUrl;
    updateState.downloading = false;
    updateState.progress = 0;
    updateState.errorMsg = "";
    updateState.visible = true;
  } finally {
    checkingUpdate = false;
  }
}
