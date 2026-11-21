package com.guoguanla.module.bank.dto;

import lombok.Data;

import java.util.Map;

@Data
public class QuestionPreviewReq {

    private Long questionId;
    private String questionMode = "DYNAMIC_TEMPLATE";
    private String questionFormat = "SINGLE_CHOICE";
    private String stem;
    private Map<String, Object> templateRule;
    private String analysis;
    private Integer count = 3;
}
