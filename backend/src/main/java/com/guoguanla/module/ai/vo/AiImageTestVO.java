package com.guoguanla.module.ai.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AiImageTestVO {

    private Boolean ok;
    /**
     * HEALTH（健康与额度探测）或 GENERATE（真实试生图）。
     */
    private String mode;
    private Long latencyMs;
    private String endpoint;
    private String model;
    private Boolean engineReady;
    private Integer accountCount;
    private Integer totalCredits;
    private String message;
    private String imageDataUrl;
    private String imageUrl;
    private String errorMessage;
}
