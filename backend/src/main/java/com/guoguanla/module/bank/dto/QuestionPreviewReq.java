package com.guoguanla.module.bank.dto;

import lombok.Data;

import java.util.Map;

@Data
public class QuestionPreviewReq {

    private Long questionId;
    private String questionMode = "DYNAMIC_TEMPLATE";
    private Map<String, Object> templateRule;
    private String analysis;
    private Integer count = 3;
}
