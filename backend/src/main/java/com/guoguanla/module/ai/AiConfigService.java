package com.guoguanla.module.ai;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.module.ai.dto.AiConfigUpdateReq;
import com.guoguanla.module.ai.vo.AiConfigVO;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.mapper.SysConfigMapper;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AiConfigService {

    public static final String KEY_ENABLED = "ai_enabled";
    public static final String KEY_BASE_URL = "ai_base_url";
    public static final String KEY_API_KEY = "ai_api_key";
    public static final String KEY_MODEL = "ai_model";
    public static final String KEY_VISION_MODEL = "ai_vision_model";
    public static final String KEY_TEMPERATURE = "ai_temperature";
    public static final String KEY_MAX_TOKENS = "ai_max_tokens";
    public static final String KEY_TIMEOUT_SEC = "ai_timeout_sec";
    public static final String KEY_SYSTEM_PROMPT = "ai_system_prompt";

    private static final String DEFAULT_BASE_URL = "https://api.longcat.chat/openai";
    private static final String DEFAULT_MODEL = "LongCat-2.5";

    private final SysConfigMapper sysConfigMapper;

    @Data
    @Builder
    public static class RuntimeAiConfig {
        private boolean enabled;
        private String baseUrl;
        private String chatCompletionsUrl;
        private String apiKey;
        private String model;
        private String visionModel;
        private double temperature;
        private int maxTokens;
        private int timeoutSec;
        private String systemPrompt;

        public boolean isConfigured() {
            return chatCompletionsUrl != null && !chatCompletionsUrl.isBlank()
                    && apiKey != null && !apiKey.isBlank()
                    && model != null && !model.isBlank();
        }

        public String effectiveVisionModel() {
            return (visionModel != null && !visionModel.isBlank()) ? visionModel : model;
        }
    }

    public RuntimeAiConfig loadRuntimeConfig() {
        List<SysConfig> rows = sysConfigMapper.selectList(
                new LambdaQueryWrapper<SysConfig>().in(
                        SysConfig::getConfigKey,
                        List.of(
                                KEY_ENABLED, KEY_BASE_URL, KEY_API_KEY, KEY_MODEL,
                                KEY_VISION_MODEL, KEY_TEMPERATURE, KEY_MAX_TOKENS,
                                KEY_TIMEOUT_SEC, KEY_SYSTEM_PROMPT
                        )
                )
        );
        Map<String, String> map = new HashMap<>();
        for (SysConfig row : rows) {
            map.put(row.getConfigKey(), row.getConfigValue() == null ? "" : row.getConfigValue().trim());
        }

        boolean enabled = !"false".equalsIgnoreCase(map.getOrDefault(KEY_ENABLED, "true"));
        String baseUrl = map.getOrDefault(KEY_BASE_URL, DEFAULT_BASE_URL);
        if (baseUrl.isBlank()) {
            baseUrl = DEFAULT_BASE_URL;
        }
        String apiKey = map.getOrDefault(KEY_API_KEY, "");
        String model = map.getOrDefault(KEY_MODEL, DEFAULT_MODEL);
        if (model.isBlank()) {
            model = DEFAULT_MODEL;
        }
        String visionModel = map.getOrDefault(KEY_VISION_MODEL, "");
        double temperature = parseDouble(map.get(KEY_TEMPERATURE), 0.2, 0.0, 1.5);
        int maxTokens = parseInt(map.get(KEY_MAX_TOKENS), 4096, 256, 32768);
        int timeoutSec = parseInt(map.get(KEY_TIMEOUT_SEC), 60, 10, 180);
        String systemPrompt = map.getOrDefault(KEY_SYSTEM_PROMPT, "");

        String resolved = "";
        try {
            resolved = resolveChatCompletionsUrl(baseUrl);
        } catch (BizException ignored) {
        }

        return RuntimeAiConfig.builder()
                .enabled(enabled)
                .baseUrl(baseUrl)
                .chatCompletionsUrl(resolved)
                .apiKey(apiKey)
                .model(model)
                .visionModel(visionModel)
                .temperature(temperature)
                .maxTokens(maxTokens)
                .timeoutSec(timeoutSec)
                .systemPrompt(systemPrompt)
                .build();
    }

    public AiConfigVO getAdminConfigView() {
        RuntimeAiConfig cfg = loadRuntimeConfig();
        return AiConfigVO.builder()
                .enabled(cfg.isEnabled())
                .baseUrl(cfg.getBaseUrl())
                .resolvedEndpoint(cfg.getChatCompletionsUrl())
                .apiKeyMasked(maskApiKey(cfg.getApiKey()))
                .hasApiKey(cfg.getApiKey() != null && !cfg.getApiKey().isBlank())
                .model(cfg.getModel())
                .visionModel(cfg.getVisionModel())
                .temperature(cfg.getTemperature())
                .maxTokens(cfg.getMaxTokens())
                .timeoutSec(cfg.getTimeoutSec())
                .systemPrompt(cfg.getSystemPrompt())
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public AiConfigVO updateAdminConfig(AiConfigUpdateReq req) {
        String normalizedBase = normalizeBaseUrl(req.getBaseUrl());
        // 校验解析后的 URL 合法性
        resolveChatCompletionsUrl(normalizedBase);

        String model = req.getModel() == null ? "" : req.getModel().trim();
        if (model.isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "模型名称不能为空");
        }

        upsertConfig(KEY_ENABLED, Boolean.FALSE.equals(req.getEnabled()) ? "false" : "true", "是否启用学生端 AI 智能手写画板");
        upsertConfig(KEY_BASE_URL, normalizedBase, "OpenAI 兼容格式 AI 接口根地址");
        upsertConfig(KEY_MODEL, model, "默认 AI 模型名称");
        upsertConfig(KEY_VISION_MODEL, req.getVisionModel() == null ? "" : req.getVisionModel().trim(), "视觉识图模型名称（留空则复用默认模型）");

        double temp = req.getTemperature() == null ? 0.2 : Math.max(0.0, Math.min(1.5, req.getTemperature()));
        int maxTokens = req.getMaxTokens() == null ? 4096 : Math.max(256, Math.min(32768, req.getMaxTokens()));
        int timeoutSec = req.getTimeoutSec() == null ? 60 : Math.max(10, Math.min(180, req.getTimeoutSec()));

        upsertConfig(KEY_TEMPERATURE, String.valueOf(temp), "AI 采样温度（0.0~1.5）");
        upsertConfig(KEY_MAX_TOKENS, String.valueOf(maxTokens), "AI 单次最大输出 Token 数");
        upsertConfig(KEY_TIMEOUT_SEC, String.valueOf(timeoutSec), "AI 上游请求超时时间（秒）");
        upsertConfig(KEY_SYSTEM_PROMPT, req.getSystemPrompt() == null ? "" : req.getSystemPrompt().trim(), "自定义 AI 数学助教系统提示词");

        if (Boolean.TRUE.equals(req.getClearApiKey())) {
            upsertConfig(KEY_API_KEY, "", "AI 服务 API 密钥（仅服务端保存，脱敏展示）");
        } else if (req.getApiKey() != null && !req.getApiKey().trim().isBlank()) {
            String incomingKey = req.getApiKey().trim();
            if (!incomingKey.contains("****")) {
                upsertConfig(KEY_API_KEY, incomingKey, "AI 服务 API 密钥（仅服务端保存，脱敏展示）");
            }
        }

        return getAdminConfigView();
    }

    public static String normalizeBaseUrl(String raw) {
        if (raw == null || raw.isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "AI 接口地址不能为空");
        }
        String trimmed = raw.trim();
        while (trimmed.endsWith("/")) {
            trimmed = trimmed.substring(0, trimmed.length() - 1);
        }
        try {
            URI uri = URI.create(trimmed);
            String scheme = uri.getScheme();
            if (scheme == null || (!"https".equalsIgnoreCase(scheme) && !"http".equalsIgnoreCase(scheme))) {
                throw new BizException(ErrorCode.BAD_REQUEST, "AI 接口地址必须以 http:// 或 https:// 开头");
            }
            if (uri.getHost() == null || uri.getHost().isBlank()) {
                throw new BizException(ErrorCode.BAD_REQUEST, "AI 接口地址缺少有效域名");
            }
        } catch (IllegalArgumentException e) {
            throw new BizException(ErrorCode.BAD_REQUEST, "AI 接口地址格式无效");
        }
        return trimmed;
    }

    /**
     * 将管理员输入的任意 OpenAI 风格地址规范为完整的 chat/completions 请求地址：
     * - https://api.longcat.chat/openai -> https://api.longcat.chat/openai/v1/chat/completions
     * - https://api.longcat.chat/openai/v1 -> https://api.longcat.chat/openai/v1/chat/completions
     * - https://api.longcat.chat/openai/v1/chat/completions -> 原样保留
     */
    public static String resolveChatCompletionsUrl(String rawBaseUrl) {
        String base = normalizeBaseUrl(rawBaseUrl);
        String lower = base.toLowerCase();
        if (lower.endsWith("/chat/completions")) {
            return base;
        }
        if (lower.endsWith("/v1")) {
            return base + "/chat/completions";
        }
        return base + "/v1/chat/completions";
    }

    public static String maskApiKey(String raw) {
        if (raw == null || raw.isBlank()) {
            return "";
        }
        String s = raw.trim();
        if (s.length() <= 8) {
            return "****";
        }
        int head = Math.min(6, s.length() / 3);
        int tail = Math.min(4, s.length() / 4);
        return s.substring(0, head) + "****" + s.substring(s.length() - tail);
    }

    private void upsertConfig(String key, String value, String desc) {
        SysConfig existing = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, key)
        );
        if (existing == null) {
            SysConfig created = new SysConfig();
            created.setConfigKey(key);
            created.setConfigValue(value);
            created.setDescription(desc);
            sysConfigMapper.insert(created);
        } else {
            existing.setConfigValue(value);
            if (existing.getDescription() == null || existing.getDescription().isBlank()) {
                existing.setDescription(desc);
            }
            sysConfigMapper.updateById(existing);
        }
    }

    private double parseDouble(String raw, double def, double min, double max) {
        if (raw == null || raw.isBlank()) return def;
        try {
            double v = Double.parseDouble(raw);
            return Math.max(min, Math.min(max, v));
        } catch (NumberFormatException e) {
            return def;
        }
    }

    private int parseInt(String raw, int def, int min, int max) {
        if (raw == null || raw.isBlank()) return def;
        try {
            int v = Integer.parseInt(raw);
            return Math.max(min, Math.min(max, v));
        } catch (NumberFormatException e) {
            return def;
        }
    }
}
