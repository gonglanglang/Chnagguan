package com.guoguanla.module.video.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("edu_video_series")
public class EduVideoSeries {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String title;
    private String coverImageKey;
    private String intro;
    private String realmCode;
    private Integer sortOrder;
    private Integer enabled;
    private Long createdBy;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @TableLogic
    private Integer deleted;
}
