package com.guoguanla.module.progress.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("user_wrong_question")
public class UserWrongQuestion {

    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private Long questionId;
    private String gradeCode;
    private Long chapterId;
    private String chapterName;
    private String gateName;
    private String stemHash;
    private String stem;
    private String questionFormat;
    private String optionsJson;
    private String answerJson;
    private String lastAnswerImageKey;
    private String analysis;
    private Integer wrongCount;
    private Integer isMastered;
    private LocalDateTime lastWrongAt;
    private LocalDateTime masteredAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
