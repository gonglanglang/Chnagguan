package com.guoguanla.module.system.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class RealmConfigVO {
    private Long id;
    private String realmCode;
    private String realmName;
    private Integer realmOrder;
    private String gradeCode;
    private String difficultyLabel;
    private String description;
    private Integer unlockGates;
    private Integer examQuestionCount;
    private Integer examPassScore;
    private Integer enabled;
    private long chapterCount;
    private long gateCount;
    private long questionCount;
    private long studentCount;
}
