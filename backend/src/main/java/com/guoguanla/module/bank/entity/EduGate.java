package com.guoguanla.module.bank.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("edu_gate")
public class EduGate {

    @TableId(type = IdType.AUTO)
    private Long id;
    private Long chapterId;
    private Integer gateIndex;
    private String gateName;
    private Integer star;
    private Integer questionCount;
    private Integer passCount;
    private Integer enabled;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @TableLogic
    private Integer deleted;
}
