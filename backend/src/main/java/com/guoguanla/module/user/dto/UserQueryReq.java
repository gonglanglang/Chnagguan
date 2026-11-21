package com.guoguanla.module.user.dto;

import lombok.Data;

@Data
public class UserQueryReq {

    private String keyword;
    private String gradeCode;
    private String realmCode;
    private Integer status;
    private Long pageNum = 1L;
    private Long pageSize = 10L;
}
