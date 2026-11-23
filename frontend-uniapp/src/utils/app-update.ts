import { reactive } from "vue";
import { AppVersionAPI } from "@/api/guoguanla";
import type { AppVersionInfo } from "@/types/guoguanla";

const GITHUB_RELEASE_API = "https://api.github.com/repos/gonglanglang/Chnagguan/releases/latest";
const MIN_VALID_APK_BYTES = 100 * 1024;
const PROGRESS_THROTTLE_MS = 100;

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
  downloadedBytes: number;
  totalBytes: number;
  downloadedFilePath: string;
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
  downloadedBytes: 0,
  totalBytes: 0,
  downloadedFilePath: "",
  errorMsg: "",
});

let checkingUpdate = false;
let downloadSessionId = 0;
let activeDownloaderTask: PlusDownloaderDownload | null = null;
let activeUniDownloadTask: UniApp.DownloadTask | null = null;

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
  const [major = 1, minor = 0, patch = 0] = core
    .split(".")
    .map((n) => Number(n.replace(/\D/g, "")) || 0);
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
 * 判断下载地址是否为应用内可直接下载的 APK 文件或后端流式下载端点
 */
export function isDirectApkDownloadUrl(rawUrl?: string | null): boolean {
  const trimmed = (rawUrl || "").trim();
  if (!trimmed) return false;
  const pathOnly = trimmed.split(/[?#]/)[0].toLowerCase();
  if (!pathOnly) return false;
  if (
    pathOnly.endsWith(".html") ||
    pathOnly.endsWith(".htm") ||
    pathOnly.includes("/releases/tag/") ||
    pathOnly.endsWith("/releases/latest")
  ) {
    return false;
  }
  return (
    pathOnly.endsWith(".apk") ||
    pathOnly.includes("/api/app/version/download") ||
    pathOnly.includes("/downloads/")
  );
}

/**
 * 格式化安装包下载字节大小（KB / MB）
 */
export function formatUpdateByteSize(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 MB";
  if (bytes < 1024 * 1024) {
    return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

/**
 * 计算下载中百分比（下载完成后再显式置为 100%）
 */
export function computeDownloadPercent(downloadedBytes: number, totalBytes: number): number {
  if (!Number.isFinite(totalBytes) || totalBytes <= 0) return 0;
  const safeDownloaded = Math.max(0, Number.isFinite(downloadedBytes) ? downloadedBytes : 0);
  return Math.min(99, Math.max(0, Math.round((safeDownloaded * 100) / totalBytes)));
}

/**
 * 生成规范化本地安装包路径（确保始终带 .apk 扩展名以正确调起系统安装器）
 */
export function buildApkSavePath(version: string): string {
  const safe = normalizeVersion(version).replace(/[^0-9A-Za-z._-]/g, "_") || "latest";
  return `_downloads/guoguanla-v${safe}.apk`;
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
        if (
          res.statusCode < 200 ||
          res.statusCode >= 300 ||
          !res.data ||
          typeof res.data !== "object"
        ) {
          resolve(null);
          return;
        }
        const data = res.data as Record<string, unknown>;
        const latestVersion = normalizeVersion(
          typeof data.tag_name === "string" ? data.tag_name : "",
        );
        if (!latestVersion) {
          resolve(null);
          return;
        }
        const assets = Array.isArray(data.assets)
          ? (data.assets as Array<Record<string, unknown>>)
          : [];
        const apkAsset = assets.find((a) =>
          String(a?.name || "")
            .toLowerCase()
            .endsWith(".apk"),
        );
        const downloadUrl = String(apkAsset?.browser_download_url || data.html_url || "");
        const hasUpdate = Boolean(downloadUrl) && compareVersions(latestVersion, local.version) > 0;
        resolve({
          currentVersion: local.version,
          latestVersion,
          latestVersionCode: deriveVersionCode(latestVersion),
          hasUpdate,
          forceUpdate: false,
          releaseNotes: typeof data.body === "string" ? data.body : "",
          downloadUrl,
          githubReleaseUrl: typeof data.html_url === "string" ? data.html_url : "",
          githubRepo: "gonglanglang/Chnagguan",
          githubReachable: true,
          publishedAt: typeof data.published_at === "string" ? data.published_at : "",
          source: "GITHUB_DIRECT",
        });
      },
      fail: () => resolve(null),
    });
  });
}

function localFileExists(relativePath: string): Promise<boolean> {
  return new Promise((resolve) => {
    // #ifdef APP-PLUS
    if (typeof plus !== "undefined" && plus.io?.resolveLocalFileSystemURL) {
      plus.io.resolveLocalFileSystemURL(
        relativePath,
        () => resolve(true),
        () => resolve(false),
      );
      return;
    }
    // #endif
    resolve(false);
  });
}

function removeLocalFileIfExists(relativePath: string): Promise<void> {
  return new Promise((resolve) => {
    // #ifdef APP-PLUS
    if (typeof plus !== "undefined" && plus.io?.resolveLocalFileSystemURL) {
      plus.io.resolveLocalFileSystemURL(
        relativePath,
        (entry) => {
          const removable = entry as unknown as {
            remove?: (ok: () => void, err?: () => void) => void;
          };
          if (typeof removable.remove === "function") {
            removable.remove(
              () => resolve(),
              () => resolve(),
            );
          } else {
            resolve();
          }
        },
        () => resolve(),
      );
      return;
    }
    // #endif
    resolve();
  });
}

function installLocalApk(filePath: string): void {
  // #ifdef APP-PLUS
  if (!filePath || typeof plus === "undefined" || !plus.runtime?.install) {
    updateState.errorMsg = "当前环境不支持自动拉起安装，请重试";
    return;
  }
  updateState.errorMsg = "";
  plus.runtime.install(
    filePath,
    { force: false },
    () => {
      updateState.errorMsg = "";
    },
    (err: unknown) => {
      const detail =
        err &&
        typeof err === "object" &&
        "message" in err &&
        typeof err.message === "string" &&
        err.message.trim()
          ? `（${err.message.trim()}）`
          : "";
      updateState.errorMsg = `安装程序拉起失败${detail}，请确认已允许「安装未知来源应用」后点击「立即安装」`;
    },
  );
  // #endif
}

function resetDownloadProgress(): void {
  updateState.downloading = false;
  updateState.progress = 0;
  updateState.downloadedBytes = 0;
  updateState.totalBytes = 0;
  updateState.errorMsg = "";
}

function runPlusDownloader(downloadUrl: string, targetPath: string, sessionId: number): void {
  // #ifdef APP-PLUS
  let settled = false;
  let lastProgressAt = 0;

  const task = plus.downloader.createDownload(
    downloadUrl,
    {
      method: "GET",
      filename: targetPath,
      timeout: 60,
      retry: 1,
    },
    (download, status) => {
      if (settled) return;
      settled = true;
      if (sessionId !== downloadSessionId) return;
      if (activeDownloaderTask === task) {
        activeDownloaderTask = null;
      }
      updateState.downloading = false;

      if (status === 200 && download.filename) {
        const contentType = (download.getResponseHeader?.("Content-Type") || "").toLowerCase();
        const finalDownloaded = Math.max(
          0,
          Number(download.downloadedSize) || updateState.downloadedBytes,
        );
        const finalTotal = Math.max(0, Number(download.totalSize) || updateState.totalBytes);
        const invalidMime =
          contentType.includes("text/html") || contentType.includes("application/json");
        const incomplete =
          (finalTotal > 0 && finalDownloaded > 0 && finalDownloaded < finalTotal) ||
          (finalDownloaded > 0 && finalDownloaded < MIN_VALID_APK_BYTES);

        if (invalidMime || incomplete) {
          void removeLocalFileIfExists(download.filename);
          updateState.progress = 0;
          updateState.downloadedBytes = 0;
          updateState.downloadedFilePath = "";
          updateState.errorMsg = "安装包文件校验未通过，请点击「重新下载」";
          return;
        }

        updateState.progress = 100;
        if (finalTotal > 0) {
          updateState.totalBytes = finalTotal;
          updateState.downloadedBytes = finalTotal;
        } else if (finalDownloaded > 0) {
          updateState.downloadedBytes = finalDownloaded;
        }
        updateState.downloadedFilePath = download.filename;
        installLocalApk(download.filename);
        return;
      }

      void removeLocalFileIfExists(targetPath);
      updateState.progress = 0;
      updateState.downloadedFilePath = "";
      updateState.errorMsg = status
        ? `安装包下载失败（HTTP ${status}），请点击「重新下载」`
        : "网络连接中断或超时，请检查网络后点击「重新下载」";
    },
  );

  activeDownloaderTask = task;

  task.addEventListener("statechanged", (download) => {
    if (settled || sessionId !== downloadSessionId || activeDownloaderTask !== task) return;
    if (download.state === 3) {
      const downloaded = Math.max(0, Number(download.downloadedSize) || 0);
      const total = Math.max(0, Number(download.totalSize) || 0);
      const pct = computeDownloadPercent(downloaded, total);
      const now = Date.now();
      if (
        pct !== updateState.progress ||
        now - lastProgressAt >= PROGRESS_THROTTLE_MS ||
        (total > 0 && updateState.totalBytes !== total)
      ) {
        lastProgressAt = now;
        updateState.downloadedBytes = downloaded;
        if (total > 0) {
          updateState.totalBytes = total;
        }
        updateState.progress = pct;
      }
    }
  });

  task.start();
  // #endif
}

function runUniFallbackDownloader(downloadUrl: string, sessionId: number): void {
  // #ifdef APP-PLUS
  const task = uni.downloadFile({
    url: downloadUrl,
    timeout: 180000,
    success: (res) => {
      if (sessionId !== downloadSessionId) return;
      if (activeUniDownloadTask === task) {
        activeUniDownloadTask = null;
      }
      updateState.downloading = false;
      if (res.statusCode === 200 && res.tempFilePath) {
        updateState.progress = 100;
        updateState.downloadedFilePath = res.tempFilePath;
        installLocalApk(res.tempFilePath);
      } else {
        updateState.progress = 0;
        updateState.downloadedFilePath = "";
        updateState.errorMsg = `安装包下载失败（HTTP ${res.statusCode || "异常"}），请点击「重新下载」`;
      }
    },
    fail: () => {
      if (sessionId !== downloadSessionId) return;
      if (activeUniDownloadTask === task) {
        activeUniDownloadTask = null;
      }
      updateState.downloading = false;
      updateState.progress = 0;
      updateState.downloadedFilePath = "";
      updateState.errorMsg = "网络连接中断或超时，请检查网络后点击「重新下载」";
    },
  });

  activeUniDownloadTask = task;
  task.onProgressUpdate((progress) => {
    if (sessionId !== downloadSessionId || activeUniDownloadTask !== task) return;
    if (
      typeof progress.totalBytesExpectedToWrite === "number" &&
      progress.totalBytesExpectedToWrite > 0
    ) {
      updateState.totalBytes = progress.totalBytesExpectedToWrite;
    }
    if (typeof progress.totalBytesWritten === "number" && progress.totalBytesWritten >= 0) {
      updateState.downloadedBytes = progress.totalBytesWritten;
    }
    if (typeof progress.progress === "number") {
      updateState.progress = Math.min(99, Math.max(0, progress.progress));
    }
  });
  // #endif
}

export function cancelAppUpdateDownload(): void {
  downloadSessionId += 1;
  if (activeDownloaderTask) {
    try {
      activeDownloaderTask.abort();
    } catch {
      // ignore abort errors
    }
    activeDownloaderTask = null;
  }
  if (activeUniDownloadTask) {
    try {
      activeUniDownloadTask.abort();
    } catch {
      // ignore abort errors
    }
    activeUniDownloadTask = null;
  }
  resetDownloadProgress();
}

export async function reDownloadAppUpdate(): Promise<void> {
  if (updateState.downloading) return;
  const cachedPath = updateState.downloadedFilePath;
  updateState.downloadedFilePath = "";
  resetDownloadProgress();
  if (cachedPath) {
    await removeLocalFileIfExists(cachedPath);
  }
  await startAppUpdateDownload();
}

export async function startAppUpdateDownload(): Promise<void> {
  if (updateState.downloading) return;

  // 已下载完成时直接拉起安装，避免用户授权“未知来源安装”返回后重复下载
  if (updateState.downloadedFilePath) {
    const exists = await localFileExists(updateState.downloadedFilePath);
    if (exists) {
      installLocalApk(updateState.downloadedFilePath);
      return;
    }
    updateState.downloadedFilePath = "";
    updateState.progress = 0;
  }

  const downloadUrl = updateState.downloadUrl || updateState.fallbackUrl;
  const fallbackUrl = updateState.fallbackUrl || downloadUrl;
  if (!downloadUrl) {
    updateState.errorMsg = "未获取到有效安装包下载地址";
    return;
  }

  // #ifdef APP-PLUS
  if (!isDirectApkDownloadUrl(downloadUrl)) {
    updateState.errorMsg = "当前更新地址非安装包直链，请检查后台配置";
    return;
  }
  if (typeof plus === "undefined") {
    updateState.errorMsg = "当前运行环境不支持应用内下载安装";
    return;
  }

  const sessionId = ++downloadSessionId;
  const targetPath = buildApkSavePath(updateState.latestVersion || "latest");
  updateState.downloading = true;
  updateState.progress = 0;
  updateState.downloadedBytes = 0;
  updateState.totalBytes = 0;
  updateState.downloadedFilePath = "";
  updateState.errorMsg = "";

  await removeLocalFileIfExists(targetPath);
  if (sessionId !== downloadSessionId || !updateState.downloading) {
    return;
  }

  if (typeof plus.downloader?.createDownload === "function") {
    runPlusDownloader(downloadUrl, targetPath, sessionId);
  } else {
    runUniFallbackDownloader(downloadUrl, sessionId);
  }
  return;
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

    // 正在应用内下载同一新版本时，不重置当前下载状态，直接确保弹窗可见
    if (
      updateState.downloading &&
      updateState.latestVersion === (info.latestVersion || local.version)
    ) {
      updateState.visible = true;
      return;
    }

    const versionChanged = updateState.latestVersion !== (info.latestVersion || local.version);
    updateState.currentVersion = local.version;
    updateState.latestVersion = info.latestVersion || local.version;
    updateState.latestVersionCode = info.latestVersionCode || 0;
    updateState.forceUpdate = Boolean(info.forceUpdate);
    updateState.releaseNotes = info.releaseNotes || "";
    updateState.noteList = parseReleaseNotesList(info.releaseNotes);
    updateState.downloadUrl = downloadUrl;
    updateState.fallbackUrl = fallbackUrl;
    if (versionChanged) {
      updateState.downloadedFilePath = "";
      resetDownloadProgress();
    } else {
      updateState.errorMsg = "";
    }
    updateState.visible = true;
  } finally {
    checkingUpdate = false;
  }
}
