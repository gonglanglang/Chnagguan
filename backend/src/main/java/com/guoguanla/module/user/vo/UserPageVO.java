package com.guoguanla.module.user.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class UserPageVO {

    private Long id;
    private String username;
    private String nickname;
    private String phoneMasked;
    private String wxOpenidMasked;
    private String avatarUrl;
    private String gradeCode;
    private String gradeName;
    private String realmCode;
    private String realmName;
    private Integer realmOrder;
    private Integer passedGateCount;
    private String levelIcon;
    private String levelName;
    private Long wrongCount;
    private Long pendingEssayCount;
    private Integer status;
    private String remark;
    private LocalDateTime lastActiveAt;
    private LocalDateTime createdAt;
}
