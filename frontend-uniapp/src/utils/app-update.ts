import { AppVersionAPI } from "@/api/guoguanla";
import type { AppVersionInfo } from "@/types/guoguanla";

const GITHUB_RELEASE_API = "https://api.github.com/repos/gonglanglang/Chnagguan/releases/latest";

export interface LocalAppVersion {
  version: string;
  versionCode: number;
}

let checkingUpdate = false;

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

function downloadAndInstallApk(downloadUrl: string, fallbackUrl: string): void {
  // #ifdef APP-PLUS
  const isDirectApk = downloadUrl.toLowerCase().includes(".apk") || downloadUrl.includes("/downloads/");
  if (!isDirectApk || typeof plus === "undefined") {
    if (typeof plus !== "undefined" && plus.runtime?.openURL) {
      plus.runtime.openURL(downloadUrl || fallbackUrl);
    }
    return;
  }

  let waitingBox: any = null;
  try {
    waitingBox = plus.nativeUI.showWaiting("正在下载更新包 0%...");
  } catch {
    uni.showLoading({ title: "正在下载安装包...", mask: true });
  }

  const downloadTask = uni.downloadFile({
    url: downloadUrl,
    success: (res) => {
      try {
        waitingBox?.close?.();
      } catch {
        // ignore
      }
      uni.hideLoading();

      if (res.statusCode === 200 && res.tempFilePath) {
        plus.runtime.install(
          res.tempFilePath,
          { force: false },
          () => {
            // Installer launched cleanly
          },
          () => {
            uni.showToast({ title: "正在跳转浏览器下载安装", icon: "none" });
            plus.runtime.openURL(downloadUrl);
          },
        );
      } else {
        uni.showToast({ title: "下载失败，已跳转浏览器下载", icon: "none" });
        plus.runtime.openURL(downloadUrl || fallbackUrl);
      }
    },
    fail: () => {
      try {
        waitingBox?.close?.();
      } catch {
        // ignore
      }
      uni.hideLoading();
      uni.showToast({ title: "下载超时，已跳转浏览器下载", icon: "none" });
      plus.runtime.openURL(downloadUrl || fallbackUrl);
    },
  });

  downloadTask.onProgressUpdate((progress) => {
    if (waitingBox?.setTitle && typeof progress.progress === "number") {
      waitingBox.setTitle(`正在下载更新包 ${progress.progress}%...`);
    }
  });
  // #endif

  // #ifndef APP-PLUS
  const target = downloadUrl || fallbackUrl;
  uni.setClipboardData({
    data: target,
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

    const notes = info.releaseNotes?.trim() || "优化答题体验并修复已知问题，建议立即更新。";
    uni.showModal({
      title: `发现新版本 v${info.latestVersion}`,
      content: notes,
      showCancel: !info.forceUpdate,
      confirmText: "立即更新",
      cancelText: "暂不更新",
      success: (res) => {
        if (res.confirm) {
          downloadAndInstallApk(downloadUrl || fallbackUrl, fallbackUrl);
        }
      },
    });
  } finally {
    checkingUpdate = false;
  }
}
