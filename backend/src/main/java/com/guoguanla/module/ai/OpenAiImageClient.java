package com.guoguanla.module.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.SocketTimeoutException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Component
@RequiredArgsConstructor
public class OpenAiImageClient {

    private static final int MAX_DOWNLOAD_BYTES = 15 * 1024 * 1024;

    private final ObjectMapper objectMapper;

    @Data
    @Builder
    public static class ImageCallRequest {
        private String endpoint;
        private String apiKey;
        private String model;
        private String prompt;
        private String size;
        private int count;
        private int timeoutSec;
    }

    @Data
    @Builder
    public static class RawImageItem {
        private byte[] bytes;
        private String contentType;
        private String dataUrl;
        private String remoteUrl;
    }

    @Data
    @Builder
    public static class ImageCallResult {
        private List<RawImageItem> items;
        private String modelUsed;
        private long latencyMs;
    }

    @Data
    @Builder
    public static class HealthProbeResult {
        private boolean ok;
        private long latencyMs;
        private String healthUrl;
        private boolean engineReady;
        private Integer accountCount;
        private Integer totalCredits;
        private String summary;
        private String errorMessage;
    }

    public HealthProbeResult probeFlowHealth(String serviceOrigin, String apiKey, int timeoutSec) {
        long start = System.currentTimeMillis();
        String healthUrl = serviceOrigin + "/health";
        int readTimeoutMs = Math.max(5, Math.min(20, timeoutSec)) * 1000;

        try {
            HttpResponsePayload healthResp = sendGet(healthUrl, apiKey, readTimeoutMs);
            long latencyMs = System.currentTimeMillis() - start;
            if (healthResp.status() == 404) {
                return HealthProbeResult.builder()
                        .ok(false)
                        .latencyMs(latencyMs)
                        .healthUrl(healthUrl)
                        .errorMessage("目标接口不支持 Flow Agent /health 探活（HTTP 404），若为云端 OpenAI 兼容生图服务，请直接点击「立即试生图测试」验证")
                        .build();
            }
            if (healthResp.status() < 200 || healthResp.status() >= 300) {
                String upstream = extractUpstreamError(healthResp.body());
                return HealthProbeResult.builder()
                        .ok(false)
                        .latencyMs(latencyMs)
                        .healthUrl(healthUrl)
                        .errorMessage(buildFriendlyStatusMessage(healthResp.status(), upstream))
                        .build();
            }

            JsonNode healthJson = objectMapper.readTree(healthResp.body());
            String status = healthJson.path("status").asText("");
            boolean engineReady = healthJson.path("engine").asBoolean(true);
            if (!"ok".equalsIgnoreCase(status) && !healthJson.has("engine")) {
                return HealthProbeResult.builder()
                        .ok(false)
                        .latencyMs(latencyMs)
                        .healthUrl(healthUrl)
                        .errorMessage("健康检查返回格式异常：" + healthResp.body())
                        .build();
            }

            Integer accountCount = null;
            Integer totalCredits = null;
            try {
                HttpResponsePayload balResp = sendGet(serviceOrigin + "/api/v1/balance", apiKey, readTimeoutMs);
                if (balResp.status() >= 200 && balResp.status() < 300) {
                    JsonNode balJson = objectMapper.readTree(balResp.body());
                    if (balJson.has("accounts") && balJson.get("accounts").isArray()) {
                        accountCount = balJson.get("accounts").size();
                    }
                    if (balJson.has("total_credits")) {
                        totalCredits = balJson.get("total_credits").asInt(0);
                    }
                }
            } catch (Exception ignored) {
                // 非 Flow Agent 兼容服务可能无 /api/v1/balance，忽略即可
            }

            String summary;
            if (!engineReady) {
                summary = "服务已响应，但底层 Flow 引擎二进制不可用，请检查 flow-agent/bin/flow-windows.exe";
            } else if (accountCount != null && accountCount > 0) {
                summary = String.format("Flow Agent 在线且引擎就绪，已加载 %d 个 Google Flow 账号，缓存总积分 %d",
                        accountCount, totalCredits == null ? 0 : totalCredits);
            } else if (accountCount != null) {
                summary = "Flow Agent 在线且引擎就绪，但当前暂未同步到 Google Flow 登录 Cookie（请保持 Bridge 运行并在 Chrome 打开 https://labs.google/fx/tools/flow 登录后刷新）";
            } else {
                summary = "AI 生图服务健康检查通过";
            }

            return HealthProbeResult.builder()
                    .ok(engineReady)
                    .latencyMs(System.currentTimeMillis() - start)
                    .healthUrl(healthUrl)
                    .engineReady(engineReady)
                    .accountCount(accountCount)
                    .totalCredits(totalCredits)
                    .summary(summary)
                    .errorMessage(engineReady ? null : summary)
                    .build();
        } catch (SocketTimeoutException e) {
            return HealthProbeResult.builder()
                    .ok(false)
                    .latencyMs(System.currentTimeMillis() - start)
                    .healthUrl(healthUrl)
                    .errorMessage("连接生图服务超时，请确认服务地址可达且已启动")
                    .build();
        } catch (Exception e) {
            return HealthProbeResult.builder()
                    .ok(false)
                    .latencyMs(System.currentTimeMillis() - start)
                    .healthUrl(healthUrl)
                    .errorMessage("无法连接生图服务：" + e.getMessage())
                    .build();
        }
    }

    public ImageCallResult generateImages(ImageCallRequest req) {
        try {
            return executeGenerate(req, true);
        } catch (BizException e) {
            if (e.getMessage() != null
                    && (e.getMessage().contains("HTTP 400") || e.getMessage().contains("response_format"))) {
                log.info("Upstream rejected response_format, retrying minimal image generation payload: model={}", req.getModel());
                return executeGenerate(req, false);
            }
            throw e;
        }
    }

    private ImageCallResult executeGenerate(ImageCallRequest req, boolean includeResponseFormat) {
        long start = System.currentTimeMillis();
        HttpURLConnection conn = null;
        try {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("model", req.getModel());
            payload.put("prompt", req.getPrompt());
            payload.put("n", Math.max(1, Math.min(4, req.getCount())));
            payload.put("size", req.getSize());
            if (includeResponseFormat) {
                payload.put("response_format", "b64_json");
            }

            byte[] bodyBytes = objectMapper.writeValueAsString(payload).getBytes(StandardCharsets.UTF_8);
            int timeoutMs = Math.max(10, Math.min(300, req.getTimeoutSec())) * 1000;

            conn = (HttpURLConnection) URI.create(req.getEndpoint()).toURL().openConnection();
            conn.setRequestMethod("POST");
            conn.setDoOutput(true);
            conn.setDoInput(true);
            conn.setInstanceFollowRedirects(true);
            conn.setConnectTimeout(15000);
            conn.setReadTimeout(timeoutMs);
            conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
            conn.setRequestProperty("Accept", "application/json");
            if (req.getApiKey() != null && !req.getApiKey().isBlank()) {
                conn.setRequestProperty("Authorization", "Bearer " + req.getApiKey().trim());
            }
            conn.setFixedLengthStreamingMode(bodyBytes.length);

            try (OutputStream os = conn.getOutputStream()) {
                os.write(bodyBytes);
                os.flush();
            }

            int status = conn.getResponseCode();
            InputStream respStream = (status >= 200 && status < 300)
                    ? conn.getInputStream()
                    : conn.getErrorStream();
            String body = readStreamUtf8(respStream);
            long latencyMs = System.currentTimeMillis() - start;

            if (status < 200 || status >= 300) {
                String upstreamMsg = extractUpstreamError(body);
                log.warn("AI image upstream error status={} endpoint={} model={} msg={}",
                        status, req.getEndpoint(), req.getModel(), upstreamMsg);
                throw new BizException(ErrorCode.AI_UPSTREAM_ERROR, buildFriendlyStatusMessage(status, upstreamMsg));
            }

            JsonNode root = objectMapper.readTree(body);
            JsonNode dataArr = root.path("data");
            if (!dataArr.isArray() || dataArr.isEmpty()) {
                throw new BizException(ErrorCode.AI_PARSE_ERROR, "AI 生图服务未返回有效图片数据");
            }

            List<RawImageItem> items = new ArrayList<>();
            for (JsonNode node : dataArr) {
                String b64 = node.path("b64_json").asText("");
                String remoteUrl = node.path("url").asText("");
                if (!b64.isBlank()) {
                    byte[] decoded = Base64.getDecoder().decode(b64.replaceAll("\\s+", ""));
                    String mime = detectImageMime(decoded, null);
                    items.add(RawImageItem.builder()
                            .bytes(decoded)
                            .contentType(mime)
                            .dataUrl("data:" + mime + ";base64," + Base64.getEncoder().encodeToString(decoded))
                            .remoteUrl(remoteUrl)
                            .build());
                } else if (!remoteUrl.isBlank()) {
                    DownloadedBinary downloaded = tryDownloadImage(remoteUrl, req.getApiKey());
                    if (downloaded != null) {
                        String mime = detectImageMime(downloaded.bytes(), downloaded.contentType());
                        items.add(RawImageItem.builder()
                                .bytes(downloaded.bytes())
                                .contentType(mime)
                                .dataUrl("data:" + mime + ";base64," + Base64.getEncoder().encodeToString(downloaded.bytes()))
                                .remoteUrl(remoteUrl)
                                .build());
                    } else {
                        items.add(RawImageItem.builder()
                                .bytes(null)
                                .contentType("image/png")
                                .dataUrl("")
                                .remoteUrl(remoteUrl)
                                .build());
                    }
                }
            }

            if (items.isEmpty()) {
                throw new BizException(ErrorCode.AI_PARSE_ERROR, "AI 生图结果中不包含可解析的 b64_json 或 url");
            }

            String modelUsed = root.path("flow").path("model").asText("");
            if (modelUsed.isBlank()) {
                modelUsed = req.getModel();
            }

            return ImageCallResult.builder()
                    .items(items)
                    .modelUsed(modelUsed)
                    .latencyMs(latencyMs)
                    .build();
        } catch (BizException e) {
            throw e;
        } catch (SocketTimeoutException e) {
            throw new BizException(ErrorCode.AI_UPSTREAM_ERROR, "AI 生图响应超时，请稍后重试或适当调大超时秒数");
        } catch (Exception e) {
            log.warn("AI image request failed endpoint={} err={}", req.getEndpoint(), e.getMessage());
            throw new BizException(ErrorCode.AI_UPSTREAM_ERROR, "无法连接 AI 生图服务：" + e.getMessage());
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }

    private record HttpResponsePayload(int status, String body) {}

    private record DownloadedBinary(byte[] bytes, String contentType) {}

    private HttpResponsePayload sendGet(String url, String apiKey, int readTimeoutMs) throws Exception {
        HttpURLConnection conn = null;
        try {
            conn = (HttpURLConnection) URI.create(url).toURL().openConnection();
            conn.setRequestMethod("GET");
            conn.setInstanceFollowRedirects(true);
            conn.setConnectTimeout(8000);
            conn.setReadTimeout(readTimeoutMs);
            conn.setRequestProperty("Accept", "application/json");
            if (apiKey != null && !apiKey.isBlank()) {
                conn.setRequestProperty("Authorization", "Bearer " + apiKey.trim());
            }
            int status = conn.getResponseCode();
            InputStream stream = (status >= 200 && status < 300) ? conn.getInputStream() : conn.getErrorStream();
            return new HttpResponsePayload(status, readStreamUtf8(stream));
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }

    private DownloadedBinary tryDownloadImage(String url, String apiKey) {
        HttpURLConnection conn = null;
        try {
            conn = (HttpURLConnection) URI.create(url).toURL().openConnection();
            conn.setRequestMethod("GET");
            conn.setInstanceFollowRedirects(true);
            conn.setConnectTimeout(8000);
            conn.setReadTimeout(20000);
            if (apiKey != null && !apiKey.isBlank()) {
                conn.setRequestProperty("Authorization", "Bearer " + apiKey.trim());
            }
            int status = conn.getResponseCode();
            if (status < 200 || status >= 300) {
                return null;
            }
            byte[] bytes = readStreamBytes(conn.getInputStream(), MAX_DOWNLOAD_BYTES);
            if (bytes.length == 0) {
                return null;
            }
            return new DownloadedBinary(bytes, conn.getContentType());
        } catch (Exception e) {
            log.debug("Failed to download generated image from url={}: {}", url, e.getMessage());
            return null;
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }

    private String readStreamUtf8(InputStream is) throws Exception {
        if (is == null) {
            return "";
        }
        return new String(readStreamBytes(is, MAX_DOWNLOAD_BYTES), StandardCharsets.UTF_8);
    }

    private byte[] readStreamBytes(InputStream is, int maxBytes) throws Exception {
        try (InputStream in = is; ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buf = new byte[4096];
            int total = 0;
            int n;
            while ((n = in.read(buf)) != -1) {
                total += n;
                if (total > maxBytes) {
                    throw new BizException(ErrorCode.AI_UPSTREAM_ERROR, "上游响应体过大");
                }
                out.write(buf, 0, n);
            }
            return out.toByteArray();
        }
    }

    public static String detectImageMime(byte[] bytes, String headerContentType) {
        if (bytes != null && bytes.length >= 4) {
            if ((bytes[0] & 0xFF) == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
                return "image/png";
            }
            if ((bytes[0] & 0xFF) == 0xFF && (bytes[1] & 0xFF) == 0xD8 && (bytes[2] & 0xFF) == 0xFF) {
                return "image/jpeg";
            }
            if (bytes.length >= 12
                    && bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F'
                    && bytes[8] == 'W' && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P') {
                return "image/webp";
            }
        }
        if (headerContentType != null && !headerContentType.isBlank()) {
            String clean = headerContentType.split(";")[0].trim().toLowerCase();
            if (clean.startsWith("image/")) {
                return clean;
            }
        }
        return "image/jpeg";
    }

    private String extractUpstreamError(String body) {
        if (body == null || body.isBlank()) {
            return "";
        }
        try {
            JsonNode root = objectMapper.readTree(body);
            String msg = root.path("detail").asText("");
            if (!msg.isBlank()) {
                return msg;
            }
            msg = root.path("error").path("message").asText("");
            if (!msg.isBlank()) {
                return msg;
            }
            msg = root.path("message").asText("");
            if (!msg.isBlank()) {
                return msg;
            }
        } catch (Exception ignored) {
        }
        return body.length() > 260 ? body.substring(0, 260) : body;
    }

    private String buildFriendlyStatusMessage(int status, String upstreamMsg) {
        String detail = (upstreamMsg == null || upstreamMsg.isBlank()) ? "" : ("：" + upstreamMsg);
        return switch (status) {
            case 400 -> "AI 生图请求参数不被上游接受 (HTTP 400)" + detail;
            case 401 -> "AI 生图 API 密钥无效或已过期 (HTTP 401)" + detail;
            case 403 -> "AI 生图服务拒绝访问或权限不足 (HTTP 403)" + detail;
            case 404 -> "AI 生图接口地址或路由不存在 (HTTP 404)" + detail;
            case 422 -> "AI 生图参数校验失败 (HTTP 422)" + detail;
            case 429 -> "AI 生图请求过于频繁或额度不足 (HTTP 429)" + detail;
            case 502 -> "Flow Agent 上游生成失败，请确认 Chrome 已打开 Google Flow 且扩展已连接 (HTTP 502)" + detail;
            default -> "AI 生图服务返回异常 (HTTP " + status + ")" + detail;
        };
    }
}
