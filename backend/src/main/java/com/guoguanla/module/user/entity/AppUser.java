package com.guoguanla.module.user.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("app_user")
public class AppUser {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String username;
    private String passwordHash;
    private String phone;
    private String wxOpenid;
    private String wxUnionid;
    private String nickname;
    private String avatarUrl;
    private String gradeCode;
    private String realmCode;
    private Integer passedGateCount;
    private Long currentLevelId;
    private String extJson;
    private String remark;
    private Integer status;
    private LocalDateTime lastActiveAt;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @TableLogic
    private Integer deleted;
}
