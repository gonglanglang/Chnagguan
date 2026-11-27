package com.guoguanla.module.ai.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class AiImageTestReq {

    private String baseUrl;

    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    private String apiKey;

    private String model;

    private String size;

    private Integer timeoutSec;

    /**
     * false（默认）：仅探测服务健康与 Flow Agent 余额状态（快速、不消耗生图额度）；
     * true：实际发起 1 次生图请求，返回预览图与耗时。
     */
    private Boolean generateSample = false;

    /**
     * 试生图提示词（仅 generateSample=true 时生效，留空使用内置示例提示词）。
     */
    private String prompt;
}
