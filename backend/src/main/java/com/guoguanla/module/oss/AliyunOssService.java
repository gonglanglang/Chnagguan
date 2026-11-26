package com.guoguanla.module.oss;

import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/**
 * 阿里云 OSS 上传与私有 Bucket 签名读取服务（配置未启用时自动降级为本地 /downloads/ 托管）。
 */
@Slf4j
@Service
public class AliyunOssService {

    private static final long MAX_IMAGE_BYTES = 10L * 1024 * 1024;
    private static final long MAX_VIDEO_BYTES = 2L * 1024 * 1024 * 1024;
    private static final long MAX_CHUNK_BYTES = 20L * 1024 * 1024;
    private static final long MULTIPART_CHUNK_SIZE = 5L * 1024 * 1024;
    private static final long MAX_ATTACHMENT_BYTES = 50L * 1024 * 1024;
    private static final long DEFAULT_SIGN_TTL_SECONDS = 7200L;
    private static final long PART_UPLOAD_SIGN_TTL_SECONDS = 4L * 3600L;
    private static final long APK_UPLOAD_SIGN_TTL_SECONDS = 3600L;
    private static final String DIRECT_PART_CONTENT_TYPE = "application/octet-stream";
    private static final String APK_CONTENT_TYPE = "application/vnd.android.package-archive";
    private static final Set<String> ALLOWED_ATTACHMENT_EXTS = Set.of(
            "png", "jpg", "jpeg", "webp", "gif",
            "pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "txt", "md", "zip"
    );
    private static final Pattern SAFE_UPLOAD_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{8,128}$");
    private static final Pattern SAFE_VIDEO_KEY_PATTERN = Pattern.compile("^course-videos/[A-Za-z0-9/_.-]{4,240}$");
    private static final Pattern SAFE_APK_KEY_PATTERN = Pattern.compile("^app-releases/[A-Za-z0-9/_.-]{4,240}\\.apk$", Pattern.CASE_INSENSITIVE);
    private static final DateTimeFormatter GMT_FORMATTER =
            DateTimeFormatter.ofPattern("EEE, dd MMM yyyy HH:mm:ss 'GMT'", Locale.ENGLISH).withZone(ZoneOffset.UTC);
    private static final DateTimeFormatter DATE_DIR_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMdd");

    @Value("${guoguanla.oss.enabled:false}")
    private boolean ossEnabled;

    @Value("${guoguanla.oss.endpoint:oss-cn-shenzhen.aliyuncs.com}")
    private String endpoint;

    @Value("${guoguanla.oss.internal-endpoint:}")
    private String internalEndpoint;

    @Value("${guoguanla.oss.custom-domain:}")
    private String customDomain;

    /** 运行时从 sys_config.oss_custom_domain 动态同步的 OSS 自定义域名（优先级高于配置文件，支持后台免重启生效） */
    private volatile String runtimeCustomDomain = "";

    @Value("${guoguanla.oss.bucket:chuangguang}")
    private String bucket;

    @Value("${guoguanla.oss.access-key-id:}")
    private String accessKeyId;

    @Value("${guoguanla.oss.access-key-secret:}")
    private String accessKeySecret;

    @Value("${guoguanla.oss.dir-prefix:essay-answers}")
    private String dirPrefix;

    @Value("${guoguanla.upload-dir:./downloads}")
    private String uploadDir;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(6))
            .build();

    public record UploadResult(String objectKey, String previewUrl, String storageType) {}

    public record DirectPutInitResult(
            String objectKey,
            String uploadUrl,
            String contentType,
            String storageType,
            boolean directUpload
    ) {}

    public record OssObjectStream(
            int statusCode,
            long contentLength,
            String contentType,
            String contentRange,
            InputStream body
    ) {}

    public String getEffectiveCustomDomain() {
        String runtime = runtimeCustomDomain == null ? "" : runtimeCustomDomain.trim();
        if (!runtime.isEmpty()) {
            return runtime;
        }
        return customDomain == null ? "" : customDomain.trim();
    }

    public void setRuntimeCustomDomain(String rawDomain) {
        this.runtimeCustomDomain = normalizeAndValidateCustomDomain(rawDomain);
    }

    public static String normalizeAndValidateCustomDomain(String rawDomain) {
        if (rawDomain == null || rawDomain.isBlank()) {
            return "";
        }
        String trimmed = rawDomain.trim();
        String withScheme = (trimmed.startsWith("http://") || trimmed.startsWith("https://"))
                ? trimmed
                : ("https://" + trimmed);
        if (withScheme.endsWith("/")) {
            withScheme = withScheme.replaceAll("/+$", "");
        }
        URI uri;
        try {
            uri = URI.create(withScheme);
        } catch (Exception e) {
            throw new BizException(ErrorCode.BAD_REQUEST, "OSS 自定义域名格式无效，请填写如 https://cdn.example.com");
        }
        String scheme = uri.getScheme();
        String host = uri.getHost();
        if (scheme == null || (!scheme.equalsIgnoreCase("https") && !scheme.equalsIgnoreCase("http"))
                || host == null || host.isBlank() || !host.contains(".")) {
            throw new BizException(ErrorCode.BAD_REQUEST, "OSS 自定义域名格式无效，请填写完整域名（如 https://cdn.example.com）");
        }
        if ((uri.getPath() != null && !uri.getPath().isBlank())
                || uri.getQuery() != null || uri.getFragment() != null) {
            throw new BizException(ErrorCode.BAD_REQUEST, "OSS 自定义域名仅需填写协议与域名，不要附加路径或参数");
        }
        String lowerHost = host.toLowerCase(Locale.ROOT);
        if (lowerHost.equals("aliyuncs.com") || lowerHost.endsWith(".aliyuncs.com")) {
            throw new BizException(
                    ErrorCode.BAD_REQUEST,
                    "不能填写阿里云 OSS 默认域名（*.aliyuncs.com），阿里云安全策略禁止通过默认域名下载 .apk 文件；请填写已绑定到该 Bucket 的自定义 CNAME 或 CDN 域名"
            );
        }
        return withScheme;
    }

    public boolean hasCustomDomain() {
        return !getEffectiveCustomDomain().isBlank();
    }

    private String resolveBackendBaseUrl() {
        if (internalEndpoint != null && !internalEndpoint.isBlank()) {
            return "http://" + bucket.trim() + "." + stripScheme(internalEndpoint);
        }
        return "https://" + bucket.trim() + "." + stripScheme(endpoint);
    }

    private String resolvePublicGetBaseUrl() {
        String effective = getEffectiveCustomDomain();
        if (!effective.isBlank()) {
            if (effective.startsWith("http://") || effective.startsWith("https://")) {
                return effective.endsWith("/") ? effective.substring(0, effective.length() - 1) : effective;
            }
            return "https://" + stripScheme(effective);
        }
        return "https://" + bucket.trim() + "." + stripScheme(endpoint);
    }

    public record MultipartPartUploadUrl(int partNumber, String uploadUrl) {}

    public record MultipartInitResult(
            String uploadId,
            String objectKey,
            long chunkSize,
            String storageType,
            boolean directUpload,
            String partContentType,
            List<MultipartPartUploadUrl> partUploadUrls
    ) {}

    public record MultipartPartResult(int partNumber, String eTag) {}

    public record CompletedPart(int partNumber, String eTag) {}

    public record AttachmentUploadResult(
            String name,
            String objectKey,
            String previewUrl,
            long size,
            String contentType,
            String storageType
    ) {}

    public boolean isOssConfigured() {
        return ossEnabled
                && accessKeyId != null && !accessKeyId.isBlank()
                && accessKeySecret != null && !accessKeySecret.isBlank()
                && endpoint != null && !endpoint.isBlank()
                && bucket != null && !bucket.isBlank();
    }

    public UploadResult uploadEssayAnswerImage(MultipartFile file, Long userId, String sessionNo, Integer itemIndex, String baseOrigin) {
        String cleanPrefix = sanitizeSegment(dirPrefix, "essay-answers");
        String cleanSession = sanitizeSegment(sessionNo, "QZ");
        String uid = userId == null ? "0" : String.valueOf(userId);
        int idx = itemIndex == null ? 0 : Math.max(0, itemIndex);
        return uploadImageFile(file, cleanPrefix, "u" + uid + "_" + cleanSession + "_i" + idx, baseOrigin);
    }

    public UploadResult uploadUserAvatar(MultipartFile file, Long userId, String baseOrigin) {
        String uid = userId == null ? "0" : String.valueOf(userId);
        return uploadImageFile(file, "avatars", "avatar_u" + uid, baseOrigin);
    }

    public UploadResult uploadTeacherReviewImage(MultipartFile file, Long essayId, String baseOrigin) {
        String eid = essayId == null ? "0" : String.valueOf(essayId);
        return uploadImageFile(file, "teacher-reviews", "review_e" + eid, baseOrigin);
    }

    public UploadResult uploadVideoCover(MultipartFile file, String baseOrigin) {
        return uploadImageFile(file, "video-covers", "cover", baseOrigin);
    }

    public UploadResult uploadQuestionFigure(MultipartFile file, String baseOrigin) {
        return uploadImageFile(file, "question-figures", "qfig", baseOrigin);
    }

    public UploadResult uploadCourseVideo(MultipartFile file, String baseOrigin) {
        if (file == null || file.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请先选择要上传的视频文件");
        }
        if (file.getSize() <= 0 || file.getSize() > MAX_VIDEO_BYTES) {
            throw new BizException(ErrorCode.BAD_REQUEST, "单个视频文件大小需在 500MB 以内");
        }
        MediaMeta meta = detectVideoMeta(file.getContentType(), file.getOriginalFilename());
        String datePart = LocalDate.now().format(DATE_DIR_FORMATTER);
        String rand = UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        String objectKey = "course-videos/" + datePart + "/lesson_" + rand + "." + meta.ext();

        if (isOssConfigured()) {
            uploadMultipartFileViaTempToOss(
                    file, "ggl-video-", "." + meta.ext(),
                    objectKey, meta.contentType(), Duration.ofMinutes(10), "读取视频文件失败"
            );
            return new UploadResult(objectKey, generatePresignedGetUrl(objectKey, DEFAULT_SIGN_TTL_SECONDS), "ALIYUN_OSS");
        }

        String relPath = "/downloads/" + objectKey;
        try {
            Path target = Path.of(uploadDir).toAbsolutePath().normalize().resolve(objectKey).normalize();
            Files.createDirectories(target.getParent());
            file.transferTo(target);
        } catch (IOException e) {
            log.error("Failed to save course video locally", e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "保存视频文件失败");
        }
        return new UploadResult(relPath, resolveViewUrl(relPath, baseOrigin), "LOCAL");
    }

    public DirectPutInitResult initAppApkDirectUpload(String fileName, String version) {
        String origName = fileName == null ? "" : fileName.trim();
        if (!origName.toLowerCase(Locale.ROOT).endsWith(".apk")) {
            throw new BizException(ErrorCode.BAD_REQUEST, "仅支持上传 .apk 格式的 Android 安装包");
        }
        if (!isOssConfigured()) {
            return new DirectPutInitResult("", "", "", "LOCAL", false);
        }
        String safeFileName = buildSafeApkFileName(version);
        String objectKey = "app-releases/" + safeFileName;
        String uploadUrl = generatePresignedPutUrl(objectKey, APK_CONTENT_TYPE, APK_UPLOAD_SIGN_TTL_SECONDS);
        return new DirectPutInitResult(objectKey, uploadUrl, APK_CONTENT_TYPE, "ALIYUN_OSS", true);
    }

    public UploadResult uploadAppApk(MultipartFile file, String safeFileName, String baseOrigin) {
        if (file == null || file.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请选择要上传的 APK 安装包");
        }
        String origName = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().trim();
        if (!origName.toLowerCase(Locale.ROOT).endsWith(".apk")) {
            throw new BizException(ErrorCode.BAD_REQUEST, "仅支持上传 .apk 格式的 Android 安装包");
        }
        if (isOssConfigured()) {
            String objectKey = sanitizeAppApkKey("app-releases/" + safeFileName);
            uploadMultipartFileViaTempToOss(
                    file, "ggl-apk-", ".apk",
                    objectKey, APK_CONTENT_TYPE, Duration.ofMinutes(5), "读取 APK 安装包失败"
            );
            return new UploadResult(objectKey, generatePresignedGetUrl(objectKey, DEFAULT_SIGN_TTL_SECONDS), "ALIYUN_OSS");
        }
        String relPath = "/downloads/" + safeFileName;
        try {
            Path target = Path.of(uploadDir).toAbsolutePath().normalize().resolve(safeFileName).normalize();
            Files.createDirectories(target.getParent());
            file.transferTo(target);
        } catch (IOException e) {
            log.error("Failed to save APK file locally", e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "保存 APK 文件失败: " + e.getMessage());
        }
        return new UploadResult(relPath, resolveViewUrl(relPath, baseOrigin), "LOCAL");
    }

    public MultipartInitResult initCourseVideoMultipart(String fileName, String contentType, long fileSize) {
        if (fileSize <= 0 || fileSize > MAX_VIDEO_BYTES) {
            throw new BizException(ErrorCode.BAD_REQUEST, "单个视频文件大小需在 2GB 以内");
        }
        MediaMeta meta = detectVideoMeta(contentType, fileName);
        String datePart = LocalDate.now().format(DATE_DIR_FORMATTER);
        String rand = UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        String objectKey = "course-videos/" + datePart + "/lesson_" + rand + "." + meta.ext();

        int totalParts = Math.max(1, (int) ((fileSize + MULTIPART_CHUNK_SIZE - 1) / MULTIPART_CHUNK_SIZE));
        if (totalParts > 10000) {
            throw new BizException(ErrorCode.BAD_REQUEST, "视频分片总数不能超过 10000 片");
        }

        if (isOssConfigured()) {
            String uploadId = initiateOssMultipartUpload(objectKey, meta.contentType());
            List<MultipartPartUploadUrl> partUploadUrls = new ArrayList<>(totalParts);
            for (int partNumber = 1; partNumber <= totalParts; partNumber++) {
                partUploadUrls.add(new MultipartPartUploadUrl(
                        partNumber,
                        generatePresignedPartUploadUrl(objectKey, uploadId, partNumber, PART_UPLOAD_SIGN_TTL_SECONDS)
                ));
            }
            return new MultipartInitResult(
                    uploadId,
                    objectKey,
                    MULTIPART_CHUNK_SIZE,
                    "ALIYUN_OSS",
                    true,
                    DIRECT_PART_CONTENT_TYPE,
                    partUploadUrls
            );
        }

        String uploadId = UUID.randomUUID().toString().replace("-", "");
        try {
            Path chunkDir = resolveChunkDir(uploadId);
            Files.createDirectories(chunkDir);
        } catch (IOException e) {
            log.error("Failed to create local chunk directory", e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "初始化本地分片目录失败");
        }
        return new MultipartInitResult(uploadId, objectKey, MULTIPART_CHUNK_SIZE, "LOCAL", false, "", List.of());
    }

    public MultipartPartResult uploadCourseVideoPart(
            String uploadId,
            String objectKey,
            int partNumber,
            MultipartFile chunkFile
    ) {
        String safeUploadId = sanitizeUploadId(uploadId);
        String safeKey = sanitizeCourseVideoKey(objectKey);
        if (partNumber < 1 || partNumber > 10000) {
            throw new BizException(ErrorCode.BAD_REQUEST, "分片序号需在 1 ~ 10000 之间");
        }
        if (chunkFile == null || chunkFile.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "分片内容不能为空");
        }
        if (chunkFile.getSize() > MAX_CHUNK_BYTES) {
            throw new BizException(ErrorCode.BAD_REQUEST, "单个分片大小不能超过 20MB");
        }

        byte[] bytes;
        try {
            bytes = chunkFile.getBytes();
        } catch (IOException e) {
            throw new BizException(ErrorCode.BAD_REQUEST, "读取视频分片失败");
        }

        if (isOssConfigured()) {
            String eTag = uploadOssPart(safeKey, safeUploadId, partNumber, bytes);
            return new MultipartPartResult(partNumber, eTag);
        }

        try {
            Path chunkDir = resolveChunkDir(safeUploadId);
            Files.createDirectories(chunkDir);
            Path partPath = chunkDir.resolve("part_" + String.format("%05d", partNumber) + ".bin");
            Files.write(partPath, bytes);
            return new MultipartPartResult(partNumber, "\"LOCAL-PART-" + partNumber + "\"");
        } catch (IOException e) {
            log.error("Failed to write local chunk part", e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "保存视频分片失败");
        }
    }

    public UploadResult completeCourseVideoMultipart(
            String uploadId,
            String objectKey,
            List<CompletedPart> parts,
            String baseOrigin
    ) {
        String safeUploadId = sanitizeUploadId(uploadId);
        String safeKey = sanitizeCourseVideoKey(objectKey);
        if (parts == null || parts.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "缺少已完成分片信息");
        }

        if (isOssConfigured()) {
            List<CompletedPart> resolvedParts = resolveCompletedPartsForOss(safeKey, safeUploadId, parts);
            completeOssMultipartUpload(safeKey, safeUploadId, resolvedParts);
            return new UploadResult(safeKey, generatePresignedGetUrl(safeKey, DEFAULT_SIGN_TTL_SECONDS), "ALIYUN_OSS");
        }

        List<CompletedPart> sorted = parts.stream()
                .filter(Objects::nonNull)
                .peek(part -> {
                    if (part.eTag() == null || part.eTag().isBlank()) {
                        throw new BizException(ErrorCode.BAD_REQUEST, "第 " + part.partNumber() + " 个分片缺少有效 ETag");
                    }
                })
                .sorted(Comparator.comparingInt(CompletedPart::partNumber))
                .toList();

        Path chunkDir = resolveChunkDir(safeUploadId);
        Path target = Path.of(uploadDir).toAbsolutePath().normalize().resolve(safeKey).normalize();
        Path baseDir = Path.of(uploadDir).toAbsolutePath().normalize();
        if (!target.startsWith(baseDir)) {
            throw new BizException(ErrorCode.BAD_REQUEST, "非法目标文件路径");
        }
        try {
            Files.createDirectories(target.getParent());
            try (OutputStream out = Files.newOutputStream(target)) {
                for (CompletedPart part : sorted) {
                    Path partPath = chunkDir.resolve("part_" + String.format("%05d", part.partNumber()) + ".bin");
                    if (!Files.exists(partPath)) {
                        throw new BizException(ErrorCode.BAD_REQUEST, "缺少第 " + part.partNumber() + " 个分片");
                    }
                    Files.copy(partPath, out);
                }
            }
        } catch (BizException e) {
            throw e;
        } catch (IOException e) {
            log.error("Failed to merge local video chunks", e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "合并视频分片失败");
        } finally {
            cleanupChunkDir(chunkDir);
        }
        String relPath = "/downloads/" + safeKey;
        return new UploadResult(relPath, resolveViewUrl(relPath, baseOrigin), "LOCAL");
    }

    public void abortCourseVideoMultipart(String uploadId, String objectKey) {
        if (uploadId == null || uploadId.isBlank()) return;
        String safeUploadId;
        String safeKey;
        try {
            safeUploadId = sanitizeUploadId(uploadId);
            safeKey = sanitizeCourseVideoKey(objectKey);
        } catch (BizException ignored) {
            return;
        }
        if (isOssConfigured()) {
            abortOssMultipartUpload(safeKey, safeUploadId);
        } else {
            cleanupChunkDir(resolveChunkDir(safeUploadId));
        }
    }

    public AttachmentUploadResult uploadNoteAttachment(MultipartFile file, String baseOrigin) {
        if (file == null || file.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请先选择要上传的附件");
        }
        if (file.getSize() <= 0 || file.getSize() > MAX_ATTACHMENT_BYTES) {
            throw new BizException(ErrorCode.BAD_REQUEST, "单个附件大小需在 50MB 以内");
        }
        String originalName = sanitizeAttachmentName(file.getOriginalFilename());
        MediaMeta meta = detectAttachmentMeta(file.getContentType(), originalName);
        String datePart = LocalDate.now().format(DATE_DIR_FORMATTER);
        String rand = UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        String objectKey = "class-notes-attachments/" + datePart + "/att_" + rand + "." + meta.ext();

        if (isOssConfigured()) {
            uploadMultipartFileViaTempToOss(
                    file, "ggl-att-", "." + meta.ext(),
                    objectKey, meta.contentType(), Duration.ofMinutes(3), "读取附件失败"
            );
            return new AttachmentUploadResult(
                    originalName,
                    objectKey,
                    generatePresignedGetUrl(objectKey, DEFAULT_SIGN_TTL_SECONDS),
                    file.getSize(),
                    meta.contentType(),
                    "ALIYUN_OSS"
            );
        }

        String relPath = "/downloads/" + objectKey;
        try {
            Path target = Path.of(uploadDir).toAbsolutePath().normalize().resolve(objectKey).normalize();
            Files.createDirectories(target.getParent());
            file.transferTo(target);
        } catch (IOException e) {
            log.error("Failed to save note attachment locally", e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "保存附件失败");
        }
        return new AttachmentUploadResult(
                originalName,
                relPath,
                resolveViewUrl(relPath, baseOrigin),
                file.getSize(),
                meta.contentType(),
                "LOCAL"
        );
    }

    public record BinaryResource(byte[] bytes, String contentType) {}

    public BinaryResource readObjectBytes(String keyOrUrl) {
        if (keyOrUrl == null || keyOrUrl.isBlank()) {
            throw new BizException(ErrorCode.NOT_FOUND, "图片不存在");
        }
        String trimmed = keyOrUrl.trim();
        if (trimmed.startsWith("/downloads/")) {
            String rel = trimmed.substring("/downloads/".length());
            Path base = Path.of(uploadDir).toAbsolutePath().normalize();
            Path target = base.resolve(rel).normalize();
            if (!target.startsWith(base) || !Files.exists(target)) {
                throw new BizException(ErrorCode.NOT_FOUND, "本地图片文件不存在");
            }
            try {
                byte[] bytes = Files.readAllBytes(target);
                ImageMeta meta = detectImageMeta(bytes, null, target.getFileName().toString());
                return new BinaryResource(bytes, meta.contentType());
            } catch (IOException e) {
                throw new BizException(ErrorCode.INTERNAL_ERROR, "读取图片失败");
            }
        }
        String viewUrl = resolveViewUrl(trimmed, "");
        if (!viewUrl.startsWith("http://") && !viewUrl.startsWith("https://")) {
            throw new BizException(ErrorCode.NOT_FOUND, "图片地址无效");
        }
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(viewUrl))
                    .timeout(Duration.ofSeconds(15))
                    .GET()
                    .build();
            HttpResponse<byte[]> resp = httpClient.send(request, HttpResponse.BodyHandlers.ofByteArray());
            if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
                throw new BizException(ErrorCode.NOT_FOUND, "读取云端图片失败 (" + resp.statusCode() + ")");
            }
            byte[] bytes = resp.body();
            String ct = resp.headers().firstValue("Content-Type").orElse("image/png");
            return new BinaryResource(bytes, ct);
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("Failed to fetch object bytes for key={}", keyOrUrl, e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "读取云端图片异常");
        }
    }

    private UploadResult uploadImageFile(MultipartFile file, String folder, String filenamePrefix, String baseOrigin) {
        if (file == null || file.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请先选择图片");
        }
        byte[] bytes;
        try {
            bytes = file.getBytes();
        } catch (IOException e) {
            throw new BizException(ErrorCode.BAD_REQUEST, "读取图片失败");
        }
        if (bytes.length == 0 || bytes.length > MAX_IMAGE_BYTES) {
            throw new BizException(ErrorCode.BAD_REQUEST, "图片大小需在 10MB 以内");
        }

        ImageMeta meta = detectImageMeta(bytes, file.getContentType(), file.getOriginalFilename());
        String datePart = LocalDate.now().format(DATE_DIR_FORMATTER);
        String rand = UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        String objectKey = folder + "/" + datePart + "/" + filenamePrefix + "_" + rand + "." + meta.ext();

        if (isOssConfigured()) {
            putToOss(objectKey, bytes, meta.contentType());
            String previewUrl = generatePresignedGetUrl(objectKey, DEFAULT_SIGN_TTL_SECONDS);
            return new UploadResult(objectKey, previewUrl, "ALIYUN_OSS");
        }

        String relPath = "/downloads/" + objectKey;
        try {
            Path target = Path.of(uploadDir).toAbsolutePath().normalize().resolve(objectKey).normalize();
            Files.createDirectories(target.getParent());
            Files.write(target, bytes);
        } catch (IOException e) {
            log.error("Failed to save image locally", e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "保存图片失败");
        }
        return new UploadResult(relPath, resolveViewUrl(relPath, baseOrigin), "LOCAL");
    }

    public String resolveViewUrl(String keyOrUrl, String baseOrigin) {
        if (keyOrUrl == null || keyOrUrl.isBlank()) {
            return "";
        }
        String trimmed = keyOrUrl.trim();
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
            return trimmed;
        }
        if (trimmed.startsWith("/downloads/")) {
            if (baseOrigin == null || baseOrigin.isBlank()) {
                return trimmed;
            }
            String cleanOrigin = baseOrigin.endsWith("/") ? baseOrigin.substring(0, baseOrigin.length() - 1) : baseOrigin;
            return cleanOrigin + trimmed;
        }
        if (isOssConfigured()) {
            return generatePresignedGetUrl(trimmed, DEFAULT_SIGN_TTL_SECONDS);
        }
        String rel = "/downloads/" + (trimmed.startsWith("/") ? trimmed.substring(1) : trimmed);
        if (baseOrigin == null || baseOrigin.isBlank()) {
            return rel;
        }
        String cleanOrigin = baseOrigin.endsWith("/") ? baseOrigin.substring(0, baseOrigin.length() - 1) : baseOrigin;
        return cleanOrigin + rel;
    }

    void putToOss(String objectKey, byte[] bytes, String contentType) {
        String url = resolveBackendBaseUrl() + "/" + objectKey;
        String dateHeader = GMT_FORMATTER.format(Instant.now());
        String stringToSign = "PUT\n\n" + contentType + "\n" + dateHeader + "\n/" + bucket.trim() + "/" + objectKey;
        String signature = signHmacSha1(accessKeySecret.trim(), stringToSign);
        String authHeader = "OSS " + accessKeyId.trim() + ":" + signature;

        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(15))
                    .header("Date", dateHeader)
                    .header("Content-Type", contentType)
                    .header("Authorization", authHeader)
                    .PUT(HttpRequest.BodyPublishers.ofByteArray(bytes))
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                log.error("OSS upload failed: status={}, body={}", response.statusCode(), response.body());
                throw new BizException(ErrorCode.INTERNAL_ERROR, "阿里云 OSS 上传失败 (" + response.statusCode() + ")");
            }
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("OSS upload exception for key={}", objectKey, e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "上传至阿里云 OSS 异常: " + e.getMessage());
        }
    }

    void putFileToOss(String objectKey, Path filePath, String contentType, Duration timeout) {
        String url = resolveBackendBaseUrl() + "/" + objectKey;
        String dateHeader = GMT_FORMATTER.format(Instant.now());
        String stringToSign = "PUT\n\n" + contentType + "\n" + dateHeader + "\n/" + bucket.trim() + "/" + objectKey;
        String signature = signHmacSha1(accessKeySecret.trim(), stringToSign);
        String authHeader = "OSS " + accessKeyId.trim() + ":" + signature;

        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(timeout)
                    .header("Date", dateHeader)
                    .header("Content-Type", contentType)
                    .header("Authorization", authHeader)
                    .PUT(HttpRequest.BodyPublishers.ofFile(filePath))
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                log.error("OSS file upload failed: status={}, body={}", response.statusCode(), response.body());
                throw new BizException(ErrorCode.INTERNAL_ERROR, "阿里云 OSS 上传失败 (" + response.statusCode() + ")");
            }
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("OSS file upload exception for key={}", objectKey, e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "上传至阿里云 OSS 异常: " + e.getMessage());
        }
    }

    String generatePresignedGetUrl(String objectKey, long ttlSeconds) {
        String cleanKey = objectKey.startsWith("/") ? objectKey.substring(1) : objectKey;
        long expires = Instant.now().getEpochSecond() + Math.max(60L, ttlSeconds);
        String stringToSign = "GET\n\n\n" + expires + "\n/" + bucket.trim() + "/" + cleanKey;
        String signature = signHmacSha1(accessKeySecret.trim(), stringToSign);
        String encodedAk = URLEncoder.encode(accessKeyId.trim(), StandardCharsets.UTF_8);
        String encodedSig = URLEncoder.encode(signature, StandardCharsets.UTF_8);
        return resolvePublicGetBaseUrl() + "/" + cleanKey
                + "?OSSAccessKeyId=" + encodedAk
                + "&Expires=" + expires
                + "&Signature=" + encodedSig;
    }

    public OssObjectStream openInternalObjectStream(String objectKey, String rangeHeader) {
        String cleanKey = objectKey.startsWith("/") ? objectKey.substring(1) : objectKey;
        String url = resolveBackendBaseUrl() + "/" + cleanKey;
        String dateHeader = GMT_FORMATTER.format(Instant.now());
        String stringToSign = "GET\n\n\n" + dateHeader + "\n/" + bucket.trim() + "/" + cleanKey;
        String authHeader = "OSS " + accessKeyId.trim() + ":" + signHmacSha1(accessKeySecret.trim(), stringToSign);

        try {
            HttpRequest.Builder builder = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofMinutes(5))
                    .header("Date", dateHeader)
                    .header("Authorization", authHeader)
                    .GET();
            if (rangeHeader != null && !rangeHeader.isBlank()) {
                builder.header("Range", rangeHeader.trim());
            }
            HttpResponse<InputStream> resp = httpClient.send(builder.build(), HttpResponse.BodyHandlers.ofInputStream());
            if (resp.statusCode() != 200 && resp.statusCode() != 206) {
                try (InputStream errIn = resp.body()) {
                    String errBody = new String(errIn.readNBytes(2048), StandardCharsets.UTF_8);
                    log.error("OSS internal stream failed: key={}, status={}, body={}", cleanKey, resp.statusCode(), errBody);
                }
                throw new BizException(ErrorCode.NOT_FOUND, "读取 OSS 安装包失败 (" + resp.statusCode() + ")");
            }
            long contentLength = resp.headers().firstValueAsLong("Content-Length").orElse(-1L);
            String ct = resp.headers().firstValue("Content-Type").orElse(APK_CONTENT_TYPE);
            String contentRange = resp.headers().firstValue("Content-Range").orElse("");
            return new OssObjectStream(resp.statusCode(), contentLength, ct, contentRange, resp.body());
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("OSS internal stream exception: key={}", cleanKey, e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "拉取 OSS 安装包异常: " + e.getMessage());
        }
    }

    public String generatePresignedPutUrl(String objectKey, String contentType, long ttlSeconds) {
        String cleanKey = objectKey.startsWith("/") ? objectKey.substring(1) : objectKey;
        long expires = Instant.now().getEpochSecond() + Math.max(60L, ttlSeconds);
        String ct = (contentType == null || contentType.isBlank()) ? "application/octet-stream" : contentType.trim();
        String stringToSign = "PUT\n\n" + ct + "\n" + expires + "\n/" + bucket.trim() + "/" + cleanKey;
        String signature = signHmacSha1(accessKeySecret.trim(), stringToSign);
        String encodedAk = URLEncoder.encode(accessKeyId.trim(), StandardCharsets.UTF_8);
        String encodedSig = URLEncoder.encode(signature, StandardCharsets.UTF_8);
        String cleanEndpoint = stripScheme(endpoint);
        return "https://" + bucket.trim() + "." + cleanEndpoint + "/" + cleanKey
                + "?OSSAccessKeyId=" + encodedAk
                + "&Expires=" + expires
                + "&Signature=" + encodedSig;
    }

    public String generatePresignedPartUploadUrl(String objectKey, String uploadId, int partNumber, long ttlSeconds) {
        long expires = Instant.now().getEpochSecond() + Math.max(60L, ttlSeconds);
        return generatePresignedPartUploadUrlAt(objectKey, uploadId, partNumber, expires);
    }

    String generatePresignedPartUploadUrlAt(String objectKey, String uploadId, int partNumber, long expiresEpochSec) {
        if (partNumber < 1 || partNumber > 10000) {
            throw new BizException(ErrorCode.BAD_REQUEST, "分片序号需在 1 ~ 10000 之间");
        }
        String cleanKey = sanitizeCourseVideoKey(objectKey);
        String cleanUploadId = sanitizeUploadId(uploadId);
        // Aliyun OSS query subresources sorted lexicographically: partNumber then uploadId
        String canonicalResource = "/" + bucket.trim() + "/" + cleanKey
                + "?partNumber=" + partNumber + "&uploadId=" + cleanUploadId;
        String stringToSign = "PUT\n\n" + DIRECT_PART_CONTENT_TYPE + "\n" + expiresEpochSec + "\n" + canonicalResource;
        String signature = signHmacSha1(accessKeySecret.trim(), stringToSign);
        String encodedAk = URLEncoder.encode(accessKeyId.trim(), StandardCharsets.UTF_8);
        String encodedSig = URLEncoder.encode(signature, StandardCharsets.UTF_8);
        String cleanEndpoint = stripScheme(endpoint);
        return "https://" + bucket.trim() + "." + cleanEndpoint + "/" + cleanKey
                + "?partNumber=" + partNumber
                + "&uploadId=" + URLEncoder.encode(cleanUploadId, StandardCharsets.UTF_8)
                + "&OSSAccessKeyId=" + encodedAk
                + "&Expires=" + expiresEpochSec
                + "&Signature=" + encodedSig;
    }

    static String signHmacSha1(String secret, String data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA1"));
            byte[] raw = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(raw);
        } catch (Exception e) {
            throw new IllegalStateException("HMAC-SHA1 signing failed", e);
        }
    }

    private record ImageMeta(String ext, String contentType) {}
    private record MediaMeta(String ext, String contentType) {}

    private MediaMeta detectVideoMeta(String contentType, String filename) {
        String ct = contentType == null ? "" : contentType.toLowerCase(Locale.ROOT);
        String fn = filename == null ? "" : filename.toLowerCase(Locale.ROOT);
        if (ct.contains("webm") || fn.endsWith(".webm")) {
            return new MediaMeta("webm", "video/webm");
        }
        if (ct.contains("quicktime") || fn.endsWith(".mov")) {
            return new MediaMeta("mov", "video/quicktime");
        }
        if (ct.contains("mp4") || fn.endsWith(".mp4") || ct.startsWith("video/")) {
            return new MediaMeta("mp4", "video/mp4");
        }
        throw new BizException(ErrorCode.BAD_REQUEST, "仅支持 MP4 / WEBM / MOV 视频格式");
    }

    private ImageMeta detectImageMeta(byte[] bytes, String contentType, String filename) {
        if (bytes.length >= 8
                && (bytes[0] & 0xFF) == 0x89 && bytes[1] == 'P' && bytes[2] == 'N' && bytes[3] == 'G') {
            return new ImageMeta("png", "image/png");
        }
        if (bytes.length >= 3
                && (bytes[0] & 0xFF) == 0xFF && (bytes[1] & 0xFF) == 0xD8 && (bytes[2] & 0xFF) == 0xFF) {
            return new ImageMeta("jpg", "image/jpeg");
        }
        if (bytes.length >= 12
                && bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F'
                && bytes[8] == 'W' && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P') {
            return new ImageMeta("webp", "image/webp");
        }
        String ct = contentType == null ? "" : contentType.toLowerCase(Locale.ROOT);
        String fn = filename == null ? "" : filename.toLowerCase(Locale.ROOT);
        if (ct.contains("jpeg") || fn.endsWith(".jpg") || fn.endsWith(".jpeg")) {
            return new ImageMeta("jpg", "image/jpeg");
        }
        if (ct.contains("webp") || fn.endsWith(".webp")) {
            return new ImageMeta("webp", "image/webp");
        }
        if (ct.contains("png") || fn.endsWith(".png")) {
            return new ImageMeta("png", "image/png");
        }
        throw new BizException(ErrorCode.BAD_REQUEST, "仅支持 PNG / JPG / WEBP 图片格式");
    }

    private String stripScheme(String ep) {
        String s = ep == null ? "" : ep.trim();
        if (s.startsWith("https://")) s = s.substring(8);
        else if (s.startsWith("http://")) s = s.substring(7);
        while (s.endsWith("/")) s = s.substring(0, s.length() - 1);
        return s;
    }

    private String sanitizeSegment(String raw, String fallback) {
        if (raw == null || raw.isBlank()) return fallback;
        String cleaned = raw.trim().replaceAll("[^A-Za-z0-9_-]", "");
        return cleaned.isEmpty() ? fallback : cleaned;
    }

    private String sanitizeUploadId(String uploadId) {
        String trimmed = uploadId == null ? "" : uploadId.trim();
        if (!SAFE_UPLOAD_ID_PATTERN.matcher(trimmed).matches()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "无效的分片上传会话标识");
        }
        return trimmed;
    }

    private String sanitizeCourseVideoKey(String objectKey) {
        String trimmed = objectKey == null ? "" : objectKey.trim();
        while (trimmed.startsWith("/")) {
            trimmed = trimmed.substring(1);
        }
        if (trimmed.contains("..") || !SAFE_VIDEO_KEY_PATTERN.matcher(trimmed).matches()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "无效的视频对象路径");
        }
        return trimmed;
    }

    public String sanitizeAppApkKey(String objectKey) {
        String trimmed = objectKey == null ? "" : objectKey.trim();
        while (trimmed.startsWith("/")) {
            trimmed = trimmed.substring(1);
        }
        if (trimmed.contains("..") || !SAFE_APK_KEY_PATTERN.matcher(trimmed).matches()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "无效的 APK 安装包对象路径");
        }
        return trimmed;
    }

    public static String buildSafeApkFileName(String version) {
        String clean = version == null ? "" : version.trim();
        if (clean.startsWith("v") || clean.startsWith("V")) {
            clean = clean.substring(1).trim();
        }
        String safeVersion = clean.replaceAll("[^0-9A-Za-z._-]", "");
        if (safeVersion.isBlank()) {
            safeVersion = String.valueOf(System.currentTimeMillis());
        }
        return "guoguanla-v" + safeVersion + ".apk";
    }

    private void uploadMultipartFileViaTempToOss(
            MultipartFile file,
            String tempPrefix,
            String tempSuffix,
            String objectKey,
            String contentType,
            Duration timeout,
            String readErrorMsg
    ) {
        Path tempFile = null;
        try {
            tempFile = Files.createTempFile(tempPrefix, tempSuffix);
            file.transferTo(tempFile);
            putFileToOss(objectKey, tempFile, contentType, timeout);
        } catch (BizException e) {
            throw e;
        } catch (IOException e) {
            log.error("Failed to buffer multipart file for objectKey={}", objectKey, e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, readErrorMsg);
        } finally {
            if (tempFile != null) {
                try {
                    Files.deleteIfExists(tempFile);
                } catch (IOException ignored) {
                }
            }
        }
    }

    private String sanitizeAttachmentName(String raw) {
        String name = raw == null ? "课程附件" : raw.trim().replace("\\", "/");
        int slashIdx = name.lastIndexOf('/');
        if (slashIdx >= 0) {
            name = name.substring(slashIdx + 1);
        }
        name = name.replaceAll("[\\r\\n<>]", "");
        return name.isBlank() ? "课程附件" : (name.length() > 120 ? name.substring(0, 120) : name);
    }

    private MediaMeta detectAttachmentMeta(String contentType, String filename) {
        String lower = filename == null ? "" : filename.toLowerCase(Locale.ROOT);
        int dot = lower.lastIndexOf('.');
        String ext = dot >= 0 && dot < lower.length() - 1 ? lower.substring(dot + 1) : "";
        if (!ALLOWED_ATTACHMENT_EXTS.contains(ext)) {
            throw new BizException(ErrorCode.BAD_REQUEST, "附件仅支持 PDF、Word、PPT、Excel、TXT/MD、ZIP 或常见图片格式");
        }
        String resolvedCt = switch (ext) {
            case "pdf" -> "application/pdf";
            case "doc" -> "application/msword";
            case "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            case "ppt" -> "application/vnd.ms-powerpoint";
            case "pptx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation";
            case "xls" -> "application/vnd.ms-excel";
            case "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            case "txt", "md" -> "text/plain; charset=utf-8";
            case "zip" -> "application/zip";
            case "png" -> "image/png";
            case "jpg", "jpeg" -> "image/jpeg";
            case "webp" -> "image/webp";
            case "gif" -> "image/gif";
            default -> (contentType != null && !contentType.isBlank()) ? contentType : "application/octet-stream";
        };
        return new MediaMeta(ext, resolvedCt);
    }

    private Path resolveChunkDir(String safeUploadId) {
        Path base = Path.of(uploadDir).toAbsolutePath().normalize().resolve(".chunks").normalize();
        Path dir = base.resolve(safeUploadId).normalize();
        if (!dir.startsWith(base)) {
            throw new BizException(ErrorCode.BAD_REQUEST, "非法分片目录");
        }
        return dir;
    }

    private void cleanupChunkDir(Path dir) {
        if (dir == null || !Files.exists(dir)) return;
        try (Stream<Path> walk = Files.walk(dir)) {
            walk.sorted(Comparator.reverseOrder()).forEach(p -> {
                try {
                    Files.deleteIfExists(p);
                } catch (IOException ignored) {
                }
            });
        } catch (IOException ignored) {
        }
    }

    private String initiateOssMultipartUpload(String objectKey, String contentType) {
        String url = resolveBackendBaseUrl() + "/" + objectKey + "?uploads";
        String dateHeader = GMT_FORMATTER.format(Instant.now());
        String stringToSign = "POST\n\n" + contentType + "\n" + dateHeader + "\n/" + bucket.trim() + "/" + objectKey + "?uploads";
        String authHeader = "OSS " + accessKeyId.trim() + ":" + signHmacSha1(accessKeySecret.trim(), stringToSign);

        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(15))
                    .header("Date", dateHeader)
                    .header("Content-Type", contentType)
                    .header("Authorization", authHeader)
                    .POST(HttpRequest.BodyPublishers.noBody())
                    .build();
            HttpResponse<String> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
                log.error("OSS init multipart failed: status={}, body={}", resp.statusCode(), resp.body());
                throw new BizException(ErrorCode.INTERNAL_ERROR, "初始化阿里云 OSS 分片上传失败 (" + resp.statusCode() + ")");
            }
            Document doc = parseXmlDocument(resp.body());
            String uploadId = doc.getElementsByTagName("UploadId").item(0).getTextContent();
            if (uploadId == null || uploadId.isBlank()) {
                throw new BizException(ErrorCode.INTERNAL_ERROR, "OSS 未返回有效 UploadId");
            }
            return uploadId.trim();
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("OSS init multipart exception for key={}", objectKey, e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "初始化 OSS 分片上传异常: " + e.getMessage());
        }
    }

    private List<CompletedPart> resolveCompletedPartsForOss(String objectKey, String uploadId, List<CompletedPart> rawParts) {
        List<CompletedPart> sorted = rawParts.stream()
                .filter(Objects::nonNull)
                .sorted(Comparator.comparingInt(CompletedPart::partNumber))
                .toList();
        boolean missingAnyEtag = sorted.stream().anyMatch(p -> p.eTag() == null || p.eTag().isBlank());
        if (!missingAnyEtag) {
            return sorted;
        }
        Map<Integer, String> ossEtags = listOssPartETags(objectKey, uploadId);
        List<CompletedPart> resolved = new ArrayList<>(sorted.size());
        for (CompletedPart part : sorted) {
            String tag = part.eTag();
            if (tag == null || tag.isBlank()) {
                tag = ossEtags.get(part.partNumber());
            }
            if (tag == null || tag.isBlank()) {
                throw new BizException(ErrorCode.BAD_REQUEST, "第 " + part.partNumber() + " 个分片未上传完成或缺少有效 ETag");
            }
            resolved.add(new CompletedPart(part.partNumber(), tag));
        }
        return resolved;
    }

    private Map<Integer, String> listOssPartETags(String objectKey, String uploadId) {
        String resourceQuery = "uploadId=" + uploadId;
        Map<Integer, String> eTagMap = new HashMap<>();
        String marker = null;

        try {
            while (true) {
                String url = resolveBackendBaseUrl() + "/" + objectKey + "?" + resourceQuery
                        + (marker != null && !marker.isBlank()
                        ? "&part-number-marker=" + URLEncoder.encode(marker, StandardCharsets.UTF_8)
                        : "");
                String dateHeader = GMT_FORMATTER.format(Instant.now());
                String stringToSign = "GET\n\n\n" + dateHeader + "\n/" + bucket.trim() + "/" + objectKey + "?" + resourceQuery;
                String authHeader = "OSS " + accessKeyId.trim() + ":" + signHmacSha1(accessKeySecret.trim(), stringToSign);

                HttpRequest req = HttpRequest.newBuilder()
                        .uri(URI.create(url))
                        .timeout(Duration.ofSeconds(30))
                        .header("Date", dateHeader)
                        .header("Authorization", authHeader)
                        .GET()
                        .build();
                HttpResponse<String> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
                if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
                    log.error("OSS list parts failed: status={}, body={}", resp.statusCode(), resp.body());
                    throw new BizException(ErrorCode.INTERNAL_ERROR, "查询 OSS 已上传分片列表失败 (" + resp.statusCode() + ")");
                }
                ListPartsPage page = parseListPartsXml(resp.body());
                eTagMap.putAll(page.partETags());
                if (!page.truncated() || page.nextMarker() == null || page.nextMarker().isBlank()) {
                    break;
                }
                marker = page.nextMarker();
            }
            return eTagMap;
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("OSS list parts exception for key={}", objectKey, e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "查询 OSS 已上传分片异常: " + e.getMessage());
        }
    }

    public record ListPartsPage(Map<Integer, String> partETags, boolean truncated, String nextMarker) {}

    public static ListPartsPage parseListPartsXml(String xmlBody) {
        try {
            Document doc = parseXmlDocument(xmlBody);
            Map<Integer, String> map = new HashMap<>();
            NodeList partNodes = doc.getElementsByTagName("Part");
            for (int i = 0; i < partNodes.getLength(); i++) {
                Node node = partNodes.item(i);
                if (node.getNodeType() != Node.ELEMENT_NODE) continue;
                Element el = (Element) node;
                String numText = firstTagText(el, "PartNumber");
                String tagText = firstTagText(el, "ETag");
                if (!numText.isBlank() && !tagText.isBlank()) {
                    map.put(Integer.parseInt(numText.trim()), tagText.trim());
                }
            }
            boolean truncated = "true".equalsIgnoreCase(firstTagText(doc.getDocumentElement(), "IsTruncated"));
            String nextMarker = firstTagText(doc.getDocumentElement(), "NextPartNumberMarker");
            return new ListPartsPage(map, truncated, nextMarker);
        } catch (Exception e) {
            throw new BizException(ErrorCode.INTERNAL_ERROR, "解析 OSS 分片列表 XML 失败: " + e.getMessage());
        }
    }

    private static Document parseXmlDocument(String xmlBody) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        return factory.newDocumentBuilder()
                .parse(new ByteArrayInputStream(xmlBody.getBytes(StandardCharsets.UTF_8)));
    }

    private static String firstTagText(Element parent, String tagName) {
        if (parent == null) return "";
        NodeList nodes = parent.getElementsByTagName(tagName);
        if (nodes.getLength() == 0) return "";
        String text = nodes.item(0).getTextContent();
        return text == null ? "" : text.trim();
    }

    private String uploadOssPart(String objectKey, String uploadId, int partNumber, byte[] bytes) {
        String query = "partNumber=" + partNumber + "&uploadId=" + uploadId;
        String url = resolveBackendBaseUrl() + "/" + objectKey + "?" + query;
        String contentType = "application/octet-stream";
        String dateHeader = GMT_FORMATTER.format(Instant.now());
        String stringToSign = "PUT\n\n" + contentType + "\n" + dateHeader + "\n/" + bucket.trim() + "/" + objectKey + "?" + query;
        String authHeader = "OSS " + accessKeyId.trim() + ":" + signHmacSha1(accessKeySecret.trim(), stringToSign);

        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofMinutes(3))
                    .header("Date", dateHeader)
                    .header("Content-Type", contentType)
                    .header("Authorization", authHeader)
                    .PUT(HttpRequest.BodyPublishers.ofByteArray(bytes))
                    .build();
            HttpResponse<String> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
                log.error("OSS part upload failed: part={}, status={}, body={}", partNumber, resp.statusCode(), resp.body());
                throw new BizException(ErrorCode.INTERNAL_ERROR, "上传第 " + partNumber + " 分片到 OSS 失败 (" + resp.statusCode() + ")");
            }
            String eTag = resp.headers().firstValue("ETag").orElse("").trim();
            if (eTag.isEmpty()) {
                throw new BizException(ErrorCode.INTERNAL_ERROR, "OSS 未返回第 " + partNumber + " 分片的 ETag");
            }
            return eTag;
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("OSS part upload exception: part={}, key={}", partNumber, objectKey, e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "上传第 " + partNumber + " 分片异常: " + e.getMessage());
        }
    }

    private void completeOssMultipartUpload(String objectKey, String uploadId, List<CompletedPart> parts) {
        String query = "uploadId=" + uploadId;
        String url = resolveBackendBaseUrl() + "/" + objectKey + "?" + query;
        String contentType = "application/xml";
        String dateHeader = GMT_FORMATTER.format(Instant.now());
        String stringToSign = "POST\n\n" + contentType + "\n" + dateHeader + "\n/" + bucket.trim() + "/" + objectKey + "?" + query;
        String authHeader = "OSS " + accessKeyId.trim() + ":" + signHmacSha1(accessKeySecret.trim(), stringToSign);

        StringBuilder xml = new StringBuilder("<CompleteMultipartUpload>");
        for (CompletedPart part : parts) {
            String tag = part.eTag() == null ? "" : part.eTag().trim();
            if (!tag.startsWith("\"")) {
                tag = "\"" + tag + "\"";
            }
            xml.append("<Part><PartNumber>")
                    .append(part.partNumber())
                    .append("</PartNumber><ETag>")
                    .append(escapeXml(tag))
                    .append("</ETag></Part>");
        }
        xml.append("</CompleteMultipartUpload>");

        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofMinutes(2))
                    .header("Date", dateHeader)
                    .header("Content-Type", contentType)
                    .header("Authorization", authHeader)
                    .POST(HttpRequest.BodyPublishers.ofString(xml.toString(), StandardCharsets.UTF_8))
                    .build();
            HttpResponse<String> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
                log.error("OSS complete multipart failed: status={}, body={}", resp.statusCode(), resp.body());
                throw new BizException(ErrorCode.INTERNAL_ERROR, "合并阿里云 OSS 视频分片失败 (" + resp.statusCode() + ")");
            }
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("OSS complete multipart exception for key={}", objectKey, e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "合并 OSS 视频分片异常: " + e.getMessage());
        }
    }

    private void abortOssMultipartUpload(String objectKey, String uploadId) {
        String query = "uploadId=" + uploadId;
        String url = resolveBackendBaseUrl() + "/" + objectKey + "?" + query;
        String dateHeader = GMT_FORMATTER.format(Instant.now());
        String stringToSign = "DELETE\n\n\n" + dateHeader + "\n/" + bucket.trim() + "/" + objectKey + "?" + query;
        String authHeader = "OSS " + accessKeyId.trim() + ":" + signHmacSha1(accessKeySecret.trim(), stringToSign);
        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(15))
                    .header("Date", dateHeader)
                    .header("Authorization", authHeader)
                    .DELETE()
                    .build();
            httpClient.send(req, HttpResponse.BodyHandlers.ofString());
        } catch (Exception e) {
            log.warn("Failed to abort OSS multipart upload: key={}, err={}", objectKey, e.getMessage());
        }
    }

    private String escapeXml(String raw) {
        return raw.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }
}
