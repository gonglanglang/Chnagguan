package com.guoguanla.module.ai.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AiImageConfigUpdateReq {

    private Boolean enabled = true;

    @NotBlank(message = "AI 生图接口地址不能为空")
    private String baseUrl;

    /**
     * 选填：本地 Flow Agent 无需密钥；云端 OpenAI 兼容生图服务按需填写。
     * 留空则保持原有已保存密钥不变；输入新值则更新。
     * WRITE_ONLY 确保序列化进审计日志时不会输出明文密钥。
     */
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    private String apiKey;

    /**
     * 若明确置为 true，则清空已保存的 API 密钥。
     */
    private Boolean clearApiKey = false;

    @NotBlank(message = "生图模型名称不能为空")
    private String model;

    /**
     * 默认画幅尺寸（支持 1024x1024 / 1792x1024 / 1024x1792 / 1365x1024 / 1024x1365 或 1:1 / 16:9 等）。
     */
    private String defaultSize = "1024x1024";

    @Min(value = 10, message = "超时时间不能小于 10 秒")
    @Max(value = 300, message = "超时时间不能大于 300 秒")
    private Integer timeoutSec = 120;
}
