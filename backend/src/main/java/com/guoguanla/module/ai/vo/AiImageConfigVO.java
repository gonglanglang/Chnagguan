package com.guoguanla.module.ai.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AiImageConfigVO {

    private Boolean enabled;
    private String baseUrl;
    private String resolvedEndpoint;
    private String apiKeyMasked;
    private Boolean hasApiKey;
    private String model;
    private String defaultSize;
    private Integer timeoutSec;
}
