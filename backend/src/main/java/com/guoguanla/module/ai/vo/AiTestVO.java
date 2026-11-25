package com.guoguanla.module.ai.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AiTestVO {

    private Boolean ok;
    private Long latencyMs;
    private String endpoint;
    private String model;
    private String reply;
    private String errorMessage;
}
