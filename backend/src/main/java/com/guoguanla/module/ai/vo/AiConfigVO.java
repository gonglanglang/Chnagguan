package com.guoguanla.module.ai.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AiConfigVO {

    private Boolean enabled;
    private String baseUrl;
    private String resolvedEndpoint;
    private String apiKeyMasked;
    private Boolean hasApiKey;
    private String model;
    private String visionModel;
    private Double temperature;
    private Integer maxTokens;
    private Integer timeoutSec;
    private String systemPrompt;
}
