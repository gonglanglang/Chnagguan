package com.guoguanla.module.bank.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("edu_question")
public class EduQuestion {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String gradeCode;
    private Long chapterId;
    private Long gateId;
    private String questionMode;
    private String questionFormat;
    private String stem;
    private String optionsJson;
    private String answerJson;
    private String analysis;
    private String generatorCode;
    private String templateRuleJson;
    private Integer difficulty;
    private String tagsJson;
    private String extJson;
    private String source;
    private Integer version;
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
