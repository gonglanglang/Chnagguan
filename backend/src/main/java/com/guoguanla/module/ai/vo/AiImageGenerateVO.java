package com.guoguanla.module.ai.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class AiImageGenerateVO {

    private String model;
    private String size;
    private String endpoint;
    private Long latencyMs;
    private List<GeneratedImageItem> images;

    @Data
    @Builder
    public static class GeneratedImageItem {
        private Integer index;
        private String dataUrl;
        private String remoteUrl;
        private String objectKey;
        private String storedUrl;
        private String storageType;
        private String contentType;
    }
}
