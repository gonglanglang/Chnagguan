package com.guoguanla.module.system;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.mapper.SysConfigMapper;
import com.guoguanla.module.system.vo.AppVersionVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * App 版本检查与更新发布服务：支持 GitHub Releases 自动同步与本地服务器 APK 托管兜底。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AppVersionService {

    private static final Pattern REPO_PATTERN = Pattern.compile("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$");
    private static final Pattern CODE_HINT_PATTERN = Pattern.compile("\\[?versionCode\\s*[:=]\\s*(\\d+)]?", Pattern.CASE_INSENSITIVE);
    private static final long CACHE_TTL_MS = 180_000L;

    private final SysConfigMapper sysConfigMapper;
    private final ObjectMapper objectMapper;

    @Value("${guoguanla.upload-dir:./downloads}")
    private String uploadDir;

    @Value("${guoguanla.github.token:}")
    private String githubToken;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .followRedirects(HttpClient.Redirect.NORMAL)
            .build();

    private volatile GithubReleaseCache cachedRelease;

    private record GithubReleaseInfo(
            String version,
            Integer versionCode,
            String notes,
            String apkDownloadUrl,
            String htmlUrl,
            String publishedAt
    ) {}

    private record GithubReleaseCache(String repo, long fetchedAtMs, boolean reachable, GithubReleaseInfo info) {}

    public AppVersionVO checkLatestVersion(String currentVersion, Integer currentVersionCode, String baseOrigin, boolean forceRefresh) {
        Map<String, String> cfg = loadConfigMap();

        String githubRepo = cfg.getOrDefault("github_release_repo", "gonglanglang/Chnagguan").trim();
        String cfgVersion = normalizeVersion(cfg.getOrDefault("app_latest_version", "1.0.0"));
        Integer cfgCode = parseIntOrNull(cfg.get("app_latest_version_code"));
        if (cfgCode == null) {
            cfgCode = deriveVersionCode(cfgVersion);
        }
        String cfgNotes = cfg.getOrDefault("app_update_notes", "");
        String cfgUrl = cfg.getOrDefault("app_download_url", "").trim();
        boolean cfgForce = "true".equalsIgnoreCase(cfg.getOrDefault("app_force_update", "false").trim());

        GithubReleaseCache ghCache = fetchGithubRelease(githubRepo, forceRefresh);
        GithubReleaseInfo gh = ghCache != null ? ghCache.info() : null;
        boolean githubReachable = ghCache != null && ghCache.reachable();

        String latestVersion = cfgVersion;
        Integer latestCode = cfgCode;
        String notes = cfgNotes;
        String downloadUrl = cfgUrl;
        String githubReleaseUrl = "";
        String publishedAt = "";
        String source = "SERVER_CONFIG";

        if (gh != null) {
            githubReleaseUrl = gh.htmlUrl();
            publishedAt = gh.publishedAt();
            int cmp = compareVersions(gh.version(), cfgVersion);
            if (cmp > 0) {
                latestVersion = gh.version();
                latestCode = gh.versionCode();
                if (gh.notes() != null && !gh.notes().isBlank()) {
                    notes = gh.notes();
                }
                if (gh.apkDownloadUrl() != null && !gh.apkDownloadUrl().isBlank()) {
                    downloadUrl = gh.apkDownloadUrl();
                } else {
                    downloadUrl = gh.htmlUrl();
                }
                source = "GITHUB_RELEASE";
            } else if (cmp == 0) {
                if ((downloadUrl == null || downloadUrl.isBlank()) && gh.apkDownloadUrl() != null && !gh.apkDownloadUrl().isBlank()) {
                    downloadUrl = gh.apkDownloadUrl();
                    source = "GITHUB_RELEASE";
                }
                if ((notes == null || notes.isBlank()) && gh.notes() != null) {
                    notes = gh.notes();
                }
            }
        }

        String resolvedUrl = resolveAbsoluteUrl(downloadUrl, baseOrigin);
        boolean hasDownloadTarget = (resolvedUrl != null && !resolvedUrl.isBlank())
                || (githubReleaseUrl != null && !githubReleaseUrl.isBlank());
        boolean hasUpdate = hasDownloadTarget && isNewer(latestVersion, latestCode, currentVersion, currentVersionCode);

        return AppVersionVO.builder()
                .currentVersion(normalizeVersion(currentVersion))
                .latestVersion(latestVersion)
                .latestVersionCode(latestCode)
                .hasUpdate(hasUpdate)
                .forceUpdate(hasUpdate && cfgForce)
                .releaseNotes(notes)
                .downloadUrl(resolvedUrl)
                .githubReleaseUrl(githubReleaseUrl)
                .githubRepo(githubRepo)
                .githubReachable(githubReachable)
                .publishedAt(publishedAt)
                .source(source)
                .build();
    }

    public AppVersionVO uploadApk(
            MultipartFile file,
            String version,
            Integer versionCode,
            String releaseNotes,
            Boolean forceUpdate,
            String baseOrigin
    ) {
        if (file == null || file.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请选择要上传的 APK 安装包");
        }
        String origName = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().trim();
        if (!origName.toLowerCase().endsWith(".apk")) {
            throw new BizException(ErrorCode.BAD_REQUEST, "仅支持上传 .apk 格式的 Android 安装包");
        }

        String cleanVersion = normalizeVersion(version);
        if (cleanVersion.isBlank()) {
            cleanVersion = loadConfigMap().getOrDefault("app_latest_version", "1.0.0");
        }
        String safeVersion = cleanVersion.replaceAll("[^0-9A-Za-z._-]", "");
        if (safeVersion.isBlank()) {
            safeVersion = String.valueOf(System.currentTimeMillis());
        }
        String fileName = "guoguanla-v" + safeVersion + ".apk";

        try {
            Path dir = Path.of(uploadDir).toAbsolutePath().normalize();
            Files.createDirectories(dir);
            Path target = dir.resolve(fileName);
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            log.error("Failed to save APK file", e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "保存 APK 文件失败: " + e.getMessage());
        }

        int finalCode = versionCode != null && versionCode > 0 ? versionCode : deriveVersionCode(cleanVersion);
        upsertConfig("app_latest_version", cleanVersion, "App最新版本号");
        upsertConfig("app_latest_version_code", String.valueOf(finalCode), "App最新版本数字编码(versionCode)");
        upsertConfig("app_download_url", "/downloads/" + fileName, "App最新APK下载地址");
        if (releaseNotes != null) {
            upsertConfig("app_update_notes", releaseNotes.trim(), "App最新版本更新日志");
        }
        if (forceUpdate != null) {
            upsertConfig("app_force_update", String.valueOf(forceUpdate), "App是否强制更新");
        }

        return checkLatestVersion(null, null, baseOrigin, false);
    }

    private GithubReleaseCache fetchGithubRelease(String repo, boolean forceRefresh) {
        if (repo == null || !REPO_PATTERN.matcher(repo).matches()) {
            return null;
        }
        GithubReleaseCache existing = this.cachedRelease;
        long now = System.currentTimeMillis();
        if (!forceRefresh && existing != null && repo.equals(existing.repo()) && (now - existing.fetchedAtMs() < CACHE_TTL_MS)) {
            return existing;
        }

        try {
            HttpRequest.Builder reqBuilder = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.github.com/repos/" + repo + "/releases/latest"))
                    .timeout(Duration.ofSeconds(4))
                    .header("Accept", "application/vnd.github+json")
                    .header("User-Agent", "guoguanla-backend/1.0")
                    .GET();
            if (githubToken != null && !githubToken.isBlank()) {
                reqBuilder.header("Authorization", "Bearer " + githubToken.trim());
            }

            HttpResponse<String> resp = httpClient.send(reqBuilder.build(), HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() >= 200 && resp.statusCode() < 300) {
                JsonNode root = objectMapper.readTree(resp.body());
                String tagName = root.path("tag_name").asText("");
                String version = normalizeVersion(tagName);
                String body = root.path("body").asText("");
                String htmlUrl = root.path("html_url").asText("");
                String publishedAt = root.path("published_at").asText("");

                String apkUrl = "";
                for (JsonNode asset : root.path("assets")) {
                    String name = asset.path("name").asText("").toLowerCase();
                    if (name.endsWith(".apk")) {
                        apkUrl = asset.path("browser_download_url").asText("");
                        break;
                    }
                }
                int code = parseCodeFromNotes(body, version);
                GithubReleaseInfo info = new GithubReleaseInfo(version, code, body, apkUrl, htmlUrl, publishedAt);
                GithubReleaseCache fresh = new GithubReleaseCache(repo, now, true, info);
                this.cachedRelease = fresh;
                return fresh;
            }
            // 404 may mean no releases yet OR private repo without token
            log.debug("GitHub releases/latest returned status {} for {}", resp.statusCode(), repo);
            GithubReleaseCache miss = new GithubReleaseCache(repo, now, false, null);
            this.cachedRelease = miss;
            return miss;
        } catch (Exception e) {
            log.debug("GitHub releases/latest check failed for {}: {}", repo, e.getMessage());
            GithubReleaseCache err = new GithubReleaseCache(repo, now, false, null);
            this.cachedRelease = err;
            return err;
        }
    }

    private Map<String, String> loadConfigMap() {
        List<SysConfig> list = sysConfigMapper.selectList(null);
        return list.stream().collect(Collectors.toMap(
                SysConfig::getConfigKey,
                c -> c.getConfigValue() == null ? "" : c.getConfigValue(),
                (a, b) -> b
        ));
    }

    private void upsertConfig(String key, String value, String desc) {
        SysConfig cfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, key).last("LIMIT 1")
        );
        if (cfg == null) {
            SysConfig created = new SysConfig();
            created.setConfigKey(key);
            created.setConfigValue(value);
            created.setDescription(desc);
            sysConfigMapper.insert(created);
        } else {
            cfg.setConfigValue(value);
            sysConfigMapper.updateById(cfg);
        }
    }

    private String resolveAbsoluteUrl(String url, String baseOrigin) {
        if (url == null || url.isBlank()) {
            return "";
        }
        String trimmed = url.trim();
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
            return trimmed;
        }
        if (baseOrigin == null || baseOrigin.isBlank()) {
            return trimmed;
        }
        String origin = baseOrigin.endsWith("/") ? baseOrigin.substring(0, baseOrigin.length() - 1) : baseOrigin;
        return trimmed.startsWith("/") ? origin + trimmed : origin + "/" + trimmed;
    }

    private boolean isNewer(String latestVer, Integer latestCode, String currentVer, Integer currentCode) {
        String normCurrent = normalizeVersion(currentVer);
        if (!normCurrent.isBlank() && latestVer != null && !latestVer.isBlank()) {
            int cmp = compareVersions(latestVer, normCurrent);
            if (cmp != 0) {
                return cmp > 0;
            }
        }
        if (currentCode != null && latestCode != null) {
            return latestCode > currentCode;
        }
        return false;
    }

    static int compareVersions(String v1, String v2) {
        String a = normalizeVersion(v1).split("-", 2)[0];
        String b = normalizeVersion(v2).split("-", 2)[0];
        if (a.isBlank() && b.isBlank()) return 0;
        if (a.isBlank()) return -1;
        if (b.isBlank()) return 1;
        String[] pa = a.split("\\.");
        String[] pb = b.split("\\.");
        int len = Math.max(pa.length, pb.length);
        for (int i = 0; i < len; i++) {
            int na = i < pa.length ? parseDigits(pa[i]) : 0;
            int nb = i < pb.length ? parseDigits(pb[i]) : 0;
            if (na != nb) {
                return Integer.compare(na, nb);
            }
        }
        return 0;
    }

    private static int parseDigits(String part) {
        String digits = part.replaceAll("[^0-9]", "");
        if (digits.isEmpty()) return 0;
        try {
            return Integer.parseInt(digits);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    static String normalizeVersion(String raw) {
        if (raw == null) return "";
        String s = raw.trim();
        if (s.startsWith("v") || s.startsWith("V")) {
            s = s.substring(1).trim();
        }
        return s;
    }

    private static int parseCodeFromNotes(String body, String version) {
        if (body != null) {
            Matcher m = CODE_HINT_PATTERN.matcher(body);
            if (m.find()) {
                try {
                    return Integer.parseInt(m.group(1));
                } catch (NumberFormatException ignored) {
                }
            }
        }
        return deriveVersionCode(version);
    }

    static int deriveVersionCode(String version) {
        String core = normalizeVersion(version).split("-", 2)[0];
        if (core.isBlank()) return 100;
        String[] parts = core.split("\\.");
        int major = parts.length > 0 ? parseDigits(parts[0]) : 1;
        int minor = parts.length > 1 ? parseDigits(parts[1]) : 0;
        int patch = parts.length > 2 ? parseDigits(parts[2]) : 0;
        return major * 100 + minor * 10 + patch;
    }

    private static Integer parseIntOrNull(String val) {
        if (val == null || val.isBlank()) return null;
        try {
            return Integer.parseInt(val.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
