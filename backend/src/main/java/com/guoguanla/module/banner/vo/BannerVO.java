package com.guoguanla.module.banner.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

public class BannerVO {

    @Data
    @Builder
    public static class BannerItemVO {
        private Long id;
        private String title;
        private String subtitle;
        private String imageKey;
        private String imageUrl;
        private Integer sortOrder;
        private Integer enabled;
        private boolean hasDetailContent;
        private LocalDateTime updatedAt;
    }

    @Data
    @Builder
    public static class BannerDetailVO {
        private Long id;
        private String title;
        private String subtitle;
        private String imageKey;
        private String imageUrl;
        private String contentHtml;
        private Integer sortOrder;
        private Integer enabled;
        private LocalDateTime createdAt;
        private LocalDateTime updatedAt;
    }

    @Data
    @Builder
    public static class UploadImageVO {
        private String objectKey;
        private String previewUrl;
        private String mediaUrl;
        private String storageType;
    }
}
