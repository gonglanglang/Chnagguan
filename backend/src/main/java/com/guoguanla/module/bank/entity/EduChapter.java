package com.guoguanla.module.bank.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("edu_chapter")
public class EduChapter {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String chapterCode;
    private String gradeCode;
    private String name;
    private String description;
    private Integer isCustom;
    private String extJson;
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
