package com.guoguanla.module.video.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

public class VideoVO {

    @Data
    @Builder
    public static class SeriesVO {
        private Long id;
        private String title;
        private String coverImageKey;
        private String coverImageUrl;
        private String intro;
        private String realmCode;
        private String realmName;
        private Integer sortOrder;
        private Integer enabled;
        private long lessonCount;
        private LocalDateTime createdAt;
        private LocalDateTime updatedAt;
    }

    @Data
    @Builder
    public static class NoteAttachmentVO {
        private String name;
        private String objectKey;
        private String url;
        private Long size;
        private String contentType;
    }

    @Data
    @Builder
    public static class LessonVO {
        private Long id;
        private Long seriesId;
        private String title;
        private String coverImageKey;
        private String coverImageUrl;
        private String videoKey;
        private String videoUrl;
        private Integer durationSec;
        private String classNotes;
        private List<NoteAttachmentVO> notesAttachments;
        private Integer sortOrder;
        private Integer enabled;
        private LocalDateTime createdAt;
        private LocalDateTime updatedAt;
    }

    @Data
    @Builder
    public static class SeriesDetailVO {
        private SeriesVO series;
        private List<LessonVO> lessons;
    }
}
