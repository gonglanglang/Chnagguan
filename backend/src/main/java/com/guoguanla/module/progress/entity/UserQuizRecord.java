package com.guoguanla.module.progress.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("user_quiz_record")
public class UserQuizRecord {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String sessionNo;
    private Long userId;
    private String mode;
    private String realmCode;
    private Integer score;
    private Long chapterId;
    private Long gateId;
    private String questionSnapshotJson;
    private Integer totalCount;
    private Integer correctCount;
    private Integer isPassed;
    private Integer status;
    private LocalDateTime startedAt;
    private LocalDateTime submittedAt;
}
