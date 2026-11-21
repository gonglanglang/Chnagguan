package com.guoguanla.module.video.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("edu_video_lesson")
public class EduVideoLesson {

    @TableId(type = IdType.AUTO)
    private Long id;
    private Long seriesId;
    private String title;
    private String videoKey;
    private Integer durationSec;
    private String classNotes;
    private Integer sortOrder;
    private Integer enabled;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @TableLogic
    private Integer deleted;
}
