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
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Component
@RequiredArgsConstructor
public class OpenAiCompatibleClient {

    private final ObjectMapper objectMapper;

    @Data
    @Builder
    public static class ChatCallRequest {
        private String endpoint;
        private String apiKey;
        private String model;
        private String systemPrompt;
        private String userPrompt;
        private List<String> imageDataUris;
        private double temperature;
        private int maxTokens;
        private int timeoutSec;
        /**
         * 可选：是否显式关闭上游推理模型的长思考链（如 LongCat-2.5 的 thinking={"type":"disabled"}），
         * 以避免思考 Token 耗尽 max_tokens 截断 JSON 并显著提速；
         * 若上游服务商不支持该扩展字段返回 HTTP 400，客户端自动去除后无缝重试。
         */
        private boolean disableThinking;
    }

    @Data
    @Builder
    public static class ChatCallResult {
        private String content;
        private String modelUsed;
        private long latencyMs;
    }

    public ChatCallResult chat(ChatCallRequest req) {
        try {
            return executeChat(req, req.isDisableThinking());
        } catch (BizException e) {
            if (req.isDisableThinking() && e.getMessage() != null
                    && (e.getMessage().contains("HTTP 400") || e.getMessage().contains("thinking"))) {
                log.info("Upstream rejected thinking parameter, retrying with standard OpenAI payload: model={}", req.getModel());
                return executeChat(req, false);
            }
            throw e;
        }
    }

    private ChatCallResult executeChat(ChatCallRequest req, boolean includeDisableThinking) {
        long start = System.currentTimeMillis();
        HttpURLConnection conn = null;
        try {
            List<Map<String, Object>> messages = new ArrayList<>();
            if (req.getSystemPrompt() != null && !req.getSystemPrompt().isBlank()) {
                messages.add(Map.of("role", "system", "content", req.getSystemPrompt()));
            }

            List<String> images = req.getImageDataUris() == null ? List.of() : req.getImageDataUris().stream()
                    .filter(u -> u != null && !u.isBlank())
                    .toList();

            if (images.isEmpty()) {
                messages.add(Map.of("role", "user", "content", req.getUserPrompt()));
            } else {
                List<Map<String, Object>> parts = new ArrayList<>();
                parts.add(Map.of("type", "text", "text", req.getUserPrompt()));
                for (String dataUri : images) {
                    parts.add(Map.of(
                            "type", "image_url",
                            "image_url", Map.of("url", dataUri)
                    ));
                }
                messages.add(Map.of("role", "user", "content", parts));
            }

            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("model", req.getModel());
            payload.put("messages", messages);
            payload.put("temperature", req.getTemperature());
            payload.put("max_tokens", req.getMaxTokens());
            payload.put("stream", false);
            if (includeDisableThinking) {
                payload.put("thinking", Map.of("type", "disabled"));
            }

            byte[] bodyBytes = objectMapper.writeValueAsString(payload).getBytes(StandardCharsets.UTF_8);
            int timeoutMs = Math.max(10, Math.min(180, req.getTimeoutSec())) * 1000;

            conn = (HttpURLConnection) URI.create(req.getEndpoint()).toURL().openConnection();
            conn.setRequestMethod("POST");
            conn.setDoOutput(true);
            conn.setDoInput(true);
            conn.setInstanceFollowRedirects(true);
            conn.setConnectTimeout(15000);
            conn.setReadTimeout(timeoutMs);
            conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
            conn.setRequestProperty("Accept", "application/json");
            conn.setRequestProperty("Authorization", "Bearer " + req.getApiKey());
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
                log.warn("AI upstream error status={} endpoint={} model={} msg={}",
                        status, req.getEndpoint(), req.getModel(), upstreamMsg);
                throw new BizException(ErrorCode.AI_UPSTREAM_ERROR, buildFriendlyStatusMessage(status, upstreamMsg));
            }

            JsonNode root = objectMapper.readTree(body);
            JsonNode choices = root.path("choices");
            if (!choices.isArray() || choices.isEmpty()) {
                throw new BizException(ErrorCode.AI_PARSE_ERROR, "AI 未返回有效回复内容");
            }
            JsonNode messageNode = choices.get(0).path("message");
            String content = extractMessageContent(messageNode);
            if (content.isBlank()) {
                throw new BizException(ErrorCode.AI_PARSE_ERROR, "AI 返回内容为空");
            }
            String actualModel = root.path("model").asText(req.getModel());
            return ChatCallResult.builder()
                    .content(content)
                    .modelUsed(actualModel)
                    .latencyMs(latencyMs)
                    .build();
        } catch (BizException e) {
            throw e;
        } catch (SocketTimeoutException e) {
            throw new BizException(ErrorCode.AI_UPSTREAM_ERROR, "AI 响应超时，请稍后重试或适当调大超时秒数");
        } catch (Exception e) {
            log.warn("AI request failed endpoint={} err={}", req.getEndpoint(), e.getMessage());
            throw new BizException(ErrorCode.AI_UPSTREAM_ERROR, "无法连接 AI 服务：" + e.getMessage());
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }

    private String readStreamUtf8(InputStream is) throws Exception {
        if (is == null) return "";
        try (InputStream in = is; ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buf = new byte[4096];
            int n;
            while ((n = in.read(buf)) != -1) {
                out.write(buf, 0, n);
            }
            return out.toString(StandardCharsets.UTF_8);
        }
    }

    private String extractMessageContent(JsonNode messageNode) {
        JsonNode contentNode = messageNode.path("content");
        if (contentNode.isTextual()) {
            return contentNode.asText("").trim();
        }
        if (contentNode.isArray()) {
            StringBuilder sb = new StringBuilder();
            for (JsonNode part : contentNode) {
                if (part.isTextual()) {
                    sb.append(part.asText());
                } else if (part.has("text")) {
                    sb.append(part.path("text").asText(""));
                }
            }
            return sb.toString().trim();
        }
        return "";
    }

    private String extractUpstreamError(String body) {
        if (body == null || body.isBlank()) {
            return "";
        }
        try {
            JsonNode root = objectMapper.readTree(body);
            String msg = root.path("error").path("message").asText("");
            if (!msg.isBlank()) return msg;
            msg = root.path("message").asText("");
            if (!msg.isBlank()) return msg;
        } catch (Exception ignored) {
        }
        return body.length() > 180 ? body.substring(0, 180) : body;
    }

    private String buildFriendlyStatusMessage(int status, String upstreamMsg) {
        String detail = (upstreamMsg == null || upstreamMsg.isBlank()) ? "" : ("：" + upstreamMsg);
        return switch (status) {
            case 401 -> "AI API 密钥无效或已过期 (HTTP 401)" + detail;
            case 403 -> "AI 服务拒绝访问或权限不足 (HTTP 403)" + detail;
            case 404 -> "AI 接口地址或模型名称不存在 (HTTP 404)" + detail;
            case 429 -> "AI 服务请求过于频繁或额度不足 (HTTP 429)" + detail;
            default -> "AI 服务返回异常 (HTTP " + status + ")" + detail;
        };
    }
}
