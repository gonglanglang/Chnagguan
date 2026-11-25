package com.guoguanla.module.ai.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class AiTestReq {

    /**
     * 可选覆盖参数，留空则回退读取数据库当前保存的配置。
     */
    private String baseUrl;

    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    private String apiKey;

    private String model;

    private Integer timeoutSec;
}
