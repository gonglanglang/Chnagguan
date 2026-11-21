package com.guoguanla.module.oss;

import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
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
import java.util.Base64;
import java.util.Locale;
import java.util.UUID;

/**
 * 阿里云 OSS 上传与私有 Bucket 签名读取服务（配置未启用时自动降级为本地 /downloads/ 托管）。
 */
@Slf4j
@Service
public class AliyunOssService {

    private static final long MAX_IMAGE_BYTES = 10L * 1024 * 1024;
    private static final long DEFAULT_SIGN_TTL_SECONDS = 7200L;
    private static final DateTimeFormatter GMT_FORMATTER =
            DateTimeFormatter.ofPattern("EEE, dd MMM yyyy HH:mm:ss 'GMT'", Locale.ENGLISH).withZone(ZoneOffset.UTC);
    private static final DateTimeFormatter DATE_DIR_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMdd");

    @Value("${guoguanla.oss.enabled:false}")
    private boolean ossEnabled;

    @Value("${guoguanla.oss.endpoint:oss-cn-beijing.aliyuncs.com}")
    private String endpoint;

    @Value("${guoguanla.oss.bucket:chuangguan2026}")
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
        String cleanEndpoint = stripScheme(endpoint);
        String url = "https://" + bucket.trim() + "." + cleanEndpoint + "/" + objectKey;
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

    String generatePresignedGetUrl(String objectKey, long ttlSeconds) {
        String cleanKey = objectKey.startsWith("/") ? objectKey.substring(1) : objectKey;
        long expires = Instant.now().getEpochSecond() + Math.max(60L, ttlSeconds);
        String stringToSign = "GET\n\n\n" + expires + "\n/" + bucket.trim() + "/" + cleanKey;
        String signature = signHmacSha1(accessKeySecret.trim(), stringToSign);
        String encodedAk = URLEncoder.encode(accessKeyId.trim(), StandardCharsets.UTF_8);
        String encodedSig = URLEncoder.encode(signature, StandardCharsets.UTF_8);
        String cleanEndpoint = stripScheme(endpoint);
        return "https://" + bucket.trim() + "." + cleanEndpoint + "/" + cleanKey
                + "?OSSAccessKeyId=" + encodedAk
                + "&Expires=" + expires
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
}
