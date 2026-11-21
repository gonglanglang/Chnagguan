package com.guoguanla.module.bank.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("edu_grade")
public class EduGrade {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String gradeCode;
    private String gradeName;
    private String icon;
    private Integer sortOrder;
    private Integer enabled;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
