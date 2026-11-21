package com.guoguanla.module.video.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

public class VideoDTO {

    @Data
    public static class SeriesSaveReq {
        @NotBlank(message = "系列标题不能为空")
        private String title;
        private String coverImageKey = "";
        private String intro = "";
        private String realmCode = "";
        private Integer sortOrder = 0;
        private Integer enabled = 1;
    }

    @Data
    public static class LessonSaveReq {
        @NotBlank(message = "课时标题不能为空")
        private String title;
        @NotBlank(message = "请先上传课程视频")
        private String videoKey;
        private Integer durationSec = 0;
        private String classNotes = "";
        private Integer sortOrder = 0;
        private Integer enabled = 1;
    }
}
