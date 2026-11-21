package com.guoguanla.module.progress.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("user_essay_answer")
public class UserEssayAnswer {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String sessionNo;
    private Integer itemIndex;
    private Long userId;
    private Long questionId;
    private String gradeCode;
    private Long chapterId;
    private String chapterName;
    private String gateName;
    private String stem;
    private String referenceAnswer;
    private String answerText;
    private String answerImageKey;
    private Integer selfCorrect;
    private Integer teacherStatus;
    private String teacherComment;
    private Long reviewedBy;
    private LocalDateTime reviewedAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
