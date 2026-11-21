package com.guoguanla.module.video.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import lombok.Data;

import java.util.List;

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
    public static class NoteAttachmentItem {
        @NotBlank(message = "附件文件名不能为空")
        private String name;
        @NotBlank(message = "附件对象键不能为空")
        private String objectKey;
        private Long size = 0L;
        private String contentType = "";
    }

    @Data
    public static class LessonSaveReq {
        @NotBlank(message = "课时标题不能为空")
        private String title;
        private String coverImageKey = "";
        @NotBlank(message = "请先上传课程视频")
        private String videoKey;
        private Integer durationSec = 0;
        private String classNotes = "";
        private List<NoteAttachmentItem> notesAttachments;
        private Integer sortOrder = 0;
        private Integer enabled = 1;
    }

    @Data
    public static class VideoMultipartInitReq {
        @NotBlank(message = "文件名不能为空")
        private String fileName;
        private String contentType = "";
        @Min(value = 1, message = "文件大小必须大于 0")
        private long fileSize;
    }

    @Data
    public static class CompletedPartReq {
        @Min(value = 1, message = "分片序号必须从 1 开始")
        private int partNumber;
        @NotBlank(message = "分片 ETag 不能为空")
        @JsonProperty("eTag")
        @JsonAlias({"etag", "ETag"})
        private String eTag;
    }

    @Data
    public static class VideoMultipartCompleteReq {
        @NotBlank(message = "uploadId 不能为空")
        private String uploadId;
        @NotBlank(message = "objectKey 不能为空")
        private String objectKey;
        @NotEmpty(message = "至少需要一个已上传分片")
        private List<@Valid CompletedPartReq> parts;
    }

    @Data
    public static class VideoMultipartAbortReq {
        @NotBlank(message = "uploadId 不能为空")
        private String uploadId;
        @NotBlank(message = "objectKey 不能为空")
        private String objectKey;
    }
}
