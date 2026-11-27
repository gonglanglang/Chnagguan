package com.guoguanla.module.banner.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

public class BannerDTO {

    @Data
    public static class SaveReq {
        @NotBlank(message = "轮播标题不能为空")
        @Size(max = 128, message = "标题不能超过 128 字")
        private String title;

        @Size(max = 255, message = "副标题不能超过 255 字")
        private String subtitle;

        @NotBlank(message = "请上传轮播图图片")
        @Size(max = 512, message = "图片标识过长")
        private String imageKey;

        private String contentHtml;

        private Integer sortOrder;

        private Integer enabled;
    }

    @Data
    public static class StatusReq {
        @NotNull(message = "状态不能为空")
        private Integer enabled;
    }
}
