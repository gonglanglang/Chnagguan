package com.guoguanla.module.system.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("edu_realm")
public class EduRealm {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String realmCode;
    private String realmName;
    private Integer realmOrder;
    private String gradeCode;
    private String difficultyLabel;
    private String description;
    private Integer unlockGates;
    private Integer examQuestionCount;
    private Integer examPassScore;
    private Integer enabled;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
