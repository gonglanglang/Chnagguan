package com.guoguanla.module.progress.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("user_gate_progress")
public class UserGateProgress {

    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private Long chapterId;
    private Long gateId;
    private Integer gateIndex;
    private Integer isPassed;
    private Integer bestCorrect;
    private Integer attemptCount;
    private LocalDateTime firstPassedAt;
    private LocalDateTime lastPlayedAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
