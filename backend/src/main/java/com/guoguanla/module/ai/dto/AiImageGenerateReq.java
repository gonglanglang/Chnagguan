package com.guoguanla.module.ai.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AiImageGenerateReq {

    @NotBlank(message = "图片提示词不能为空")
    private String prompt;

    /**
     * 可选覆盖配置中的默认尺寸（支持 1024x1024 / 1792x1024 / 1024x1792 / 1365x1024 / 1024x1365 或 1:1 / 16:9 等）。
     */
    private String size;

    /**
     * 可选覆盖配置中的默认模型名称。
     */
    private String model;

    @Min(value = 1, message = "单次生成张数至少为 1")
    @Max(value = 4, message = "单次生成张数最多为 4")
    private Integer count = 1;

    /**
     * 是否将生成的图片同步转存至阿里云 OSS（未配置 OSS 时自动存至本地 /downloads/ai-images/）。
     */
    private Boolean saveToStorage = false;
}
