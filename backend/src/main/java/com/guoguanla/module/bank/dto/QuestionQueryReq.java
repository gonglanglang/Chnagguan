package com.guoguanla.module.bank.dto;

import lombok.Data;

@Data
public class QuestionQueryReq {

    private String gradeCode;
    private String realmCode;
    private Long chapterId;
    private Long gateId;
    private String questionMode;
    private String questionFormat;
    private Integer enabled;
    private String keyword;
    private Long pageNum = 1L;
    private Long pageSize = 10L;
}
