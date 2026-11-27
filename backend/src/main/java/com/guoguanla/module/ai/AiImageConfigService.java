package com.guoguanla.module.ai;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.module.ai.dto.AiImageConfigUpdateReq;
import com.guoguanla.module.ai.vo.AiImageConfigVO;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.mapper.SysConfigMapper;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
public class AiImageConfigService {

    public static final String KEY_ENABLED = "ai_image_enabled";
    public static final String KEY_BASE_URL = "ai_image_base_url";
    public static final String KEY_API_KEY = "ai_image_api_key";
    public static final String KEY_MODEL = "ai_image_model";
    public static final String KEY_DEFAULT_SIZE = "ai_image_default_size";
    public static final String KEY_TIMEOUT_SEC = "ai_image_timeout_sec";

    public static final String DEFAULT_BASE_URL = "http://127.0.0.1:8001/v1";
    public static final String DEFAULT_MODEL = "gem_pix_2";
    public static final String DEFAULT_SIZE = "1024x1024";
    public static final int DEFAULT_TIMEOUT_SEC = 120;

    private static final Pattern PIXEL_SIZE_PATTERN = Pattern.compile("^\\d{2,4}x\\d{2,4}$");

    private static final Map<String, String> ASPECT_TO_SIZE = Map.ofEntries(
            Map.entry("1:1", "1024x1024"),
            Map.entry("square", "1024x1024"),
            Map.entry("16:9", "1792x1024"),
            Map.entry("landscape", "1792x1024"),
            Map.entry("9:16", "1024x1792"),
            Map.entry("portrait", "1024x1792"),
            Map.entry("4:3", "1365x1024"),
            Map.entry("3:4", "1024x1365")
    );

    private final SysConfigMapper sysConfigMapper;

    @Data
    @Builder
    public static class RuntimeAiImageConfig {
        private boolean enabled;
        private String baseUrl;
        private String imagesGenerationsUrl;
        private String serviceOrigin;
        private String apiKey;
        private String model;
        private String defaultSize;
        private int timeoutSec;

        public boolean isConfigured() {
            return imagesGenerationsUrl != null && !imagesGenerationsUrl.isBlank()
                    && model != null && !model.isBlank();
        }
    }

    public RuntimeAiImageConfig loadRuntimeConfig() {
        List<SysConfig> rows = sysConfigMapper.selectList(
                new LambdaQueryWrapper<SysConfig>().in(
                        SysConfig::getConfigKey,
                        List.of(
                                KEY_ENABLED, KEY_BASE_URL, KEY_API_KEY,
                                KEY_MODEL, KEY_DEFAULT_SIZE, KEY_TIMEOUT_SEC
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
        String defaultSize = normalizeSizeOrDefault(map.get(KEY_DEFAULT_SIZE));
        int timeoutSec = parseInt(map.get(KEY_TIMEOUT_SEC), DEFAULT_TIMEOUT_SEC, 10, 300);

        String resolvedEndpoint = "";
        String serviceOrigin = "";
        try {
            resolvedEndpoint = resolveImagesGenerationsUrl(baseUrl);
            serviceOrigin = resolveServiceOrigin(baseUrl);
        } catch (BizException ignored) {
        }

        return RuntimeAiImageConfig.builder()
                .enabled(enabled)
                .baseUrl(baseUrl)
                .imagesGenerationsUrl(resolvedEndpoint)
                .serviceOrigin(serviceOrigin)
                .apiKey(apiKey)
                .model(model)
                .defaultSize(defaultSize)
                .timeoutSec(timeoutSec)
                .build();
    }

    public AiImageConfigVO getAdminConfigView() {
        RuntimeAiImageConfig cfg = loadRuntimeConfig();
        return AiImageConfigVO.builder()
                .enabled(cfg.isEnabled())
                .baseUrl(cfg.getBaseUrl())
                .resolvedEndpoint(cfg.getImagesGenerationsUrl())
                .apiKeyMasked(AiConfigService.maskApiKey(cfg.getApiKey()))
                .hasApiKey(cfg.getApiKey() != null && !cfg.getApiKey().isBlank())
                .model(cfg.getModel())
                .defaultSize(cfg.getDefaultSize())
                .timeoutSec(cfg.getTimeoutSec())
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public AiImageConfigVO updateAdminConfig(AiImageConfigUpdateReq req) {
        String normalizedBase = AiConfigService.normalizeBaseUrl(req.getBaseUrl());
        resolveImagesGenerationsUrl(normalizedBase);

        String model = req.getModel() == null ? "" : req.getModel().trim();
        if (model.isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "生图模型名称不能为空");
        }

        String normalizedSize = normalizeSize(req.getDefaultSize());
        int timeoutSec = req.getTimeoutSec() == null
                ? DEFAULT_TIMEOUT_SEC
                : Math.max(10, Math.min(300, req.getTimeoutSec()));

        upsertConfig(KEY_ENABLED, Boolean.FALSE.equals(req.getEnabled()) ? "false" : "true", "是否启用管理后台 AI 生图服务");
        upsertConfig(KEY_BASE_URL, normalizedBase, "AI 生图服务接口根地址（兼容 Flow Agent 与 OpenAI Images 协议）");
        upsertConfig(KEY_MODEL, model, "AI 生图默认模型名称（如 narwhal / harbor_seal / gem_pix_2 / dall-e-3）");
        upsertConfig(KEY_DEFAULT_SIZE, normalizedSize, "AI 生图默认画幅尺寸");
        upsertConfig(KEY_TIMEOUT_SEC, String.valueOf(timeoutSec), "AI 生图上游请求超时时间（秒）");

        if (Boolean.TRUE.equals(req.getClearApiKey())) {
            upsertConfig(KEY_API_KEY, "", "AI 生图服务 API 密钥（本地 Flow Agent 可留空，云端服务按需配置）");
        } else if (req.getApiKey() != null && !req.getApiKey().trim().isBlank()) {
            String incomingKey = req.getApiKey().trim();
            if (!incomingKey.contains("****")) {
                upsertConfig(KEY_API_KEY, incomingKey, "AI 生图服务 API 密钥（本地 Flow Agent 可留空，云端服务按需配置）");
            }
        }

        return getAdminConfigView();
    }

    /**
     * 将管理员输入的生图接口地址规范为完整的 OpenAI Images 兼容地址：
     * - http://127.0.0.1:8001 -> http://127.0.0.1:8001/v1/images/generations
     * - http://127.0.0.1:8001/v1 -> http://127.0.0.1:8001/v1/images/generations
     * - http://127.0.0.1:8001/api/v1 -> http://127.0.0.1:8001/v1/images/generations
     * - http://127.0.0.1:8001/v1/images/generations -> 原样保留
     */
    public static String resolveImagesGenerationsUrl(String rawBaseUrl) {
        String base = AiConfigService.normalizeBaseUrl(rawBaseUrl);
        String lower = base.toLowerCase(Locale.ROOT);
        if (lower.endsWith("/images/generations")) {
            return base;
        }
        if (lower.endsWith("/api/v1")) {
            return base.substring(0, base.length() - "/api/v1".length()) + "/v1/images/generations";
        }
        if (lower.endsWith("/v1")) {
            return base + "/images/generations";
        }
        return base + "/v1/images/generations";
    }

    /**
     * 提取不带 /v1 或 /v1/images/generations 后缀的服务根路径，用于探测 Flow Agent 的 /health 与 /api/v1/balance。
     */
    public static String resolveServiceOrigin(String rawBaseUrl) {
        String base = AiConfigService.normalizeBaseUrl(rawBaseUrl);
        String lower = base.toLowerCase(Locale.ROOT);
        if (lower.endsWith("/v1/images/generations")) {
            return base.substring(0, base.length() - "/v1/images/generations".length());
        }
        if (lower.endsWith("/images/generations")) {
            return base.substring(0, base.length() - "/images/generations".length());
        }
        if (lower.endsWith("/api/v1")) {
            return base.substring(0, base.length() - "/api/v1".length());
        }
        if (lower.endsWith("/v1")) {
            return base.substring(0, base.length() - "/v1".length());
        }
        return base;
    }

    public static String normalizeSize(String rawSize) {
        if (rawSize == null || rawSize.isBlank()) {
            return DEFAULT_SIZE;
        }
        String trimmed = rawSize.trim().toLowerCase(Locale.ROOT);
        if (ASPECT_TO_SIZE.containsKey(trimmed)) {
            return ASPECT_TO_SIZE.get(trimmed);
        }
        if (PIXEL_SIZE_PATTERN.matcher(trimmed).matches()) {
            return trimmed;
        }
        throw new BizException(
                ErrorCode.BAD_REQUEST,
                "不支持的图片尺寸格式：" + rawSize + "（支持 1024x1024、1792x1024、1024x1792、1365x1024、1024x1365 或 1:1 / 16:9 / 9:16 / 4:3 / 3:4）"
        );
    }

    private String normalizeSizeOrDefault(String rawSize) {
        try {
            return normalizeSize(rawSize);
        } catch (BizException ignored) {
            return DEFAULT_SIZE;
        }
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

    private int parseInt(String raw, int def, int min, int max) {
        if (raw == null || raw.isBlank()) {
            return def;
        }
        try {
            int v = Integer.parseInt(raw);
            return Math.max(min, Math.min(max, v));
        } catch (NumberFormatException e) {
            return def;
        }
    }
}
