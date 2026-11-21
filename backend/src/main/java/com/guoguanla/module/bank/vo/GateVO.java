package com.guoguanla.module.bank.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class GateVO {

    private Long id;
    private Long chapterId;
    private Integer gateIndex;
    private String gateName;
    private Integer star;
    private Integer questionCount;
    private Integer passCount;
    private Integer enabled;
    private Long actualQuestionCount;
}
