package com.guoguanla.module.ai.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AiConfigUpdateReq {

    private Boolean enabled = true;

    @NotBlank(message = "AI 接口地址不能为空")
    private String baseUrl;

    /**
     * 留空则保持原有已保存密钥不变；输入新值则更新。
     * WRITE_ONLY 确保序列化进审计日志时不会输出明文密钥。
     */
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    private String apiKey;

    /**
     * 若明确置为 true，则清空已保存的 API 密钥。
     */
    private Boolean clearApiKey = false;

    @NotBlank(message = "模型名称不能为空")
    private String model;

    /**
     * 可选：单独指定视觉识图模型；留空时默认复用 model。
     */
    private String visionModel;

    @DecimalMin(value = "0.0", message = "温度不能小于 0")
    @DecimalMax(value = "1.5", message = "温度不能大于 1.5")
    private Double temperature = 0.2;

    @Min(value = 256, message = "最大输出 Token 不能小于 256")
    @Max(value = 32768, message = "最大输出 Token 不能大于 32768")
    private Integer maxTokens = 4096;

    @Min(value = 10, message = "超时时间不能小于 10 秒")
    @Max(value = 180, message = "超时时间不能大于 180 秒")
    private Integer timeoutSec = 60;

    private String systemPrompt;
}
