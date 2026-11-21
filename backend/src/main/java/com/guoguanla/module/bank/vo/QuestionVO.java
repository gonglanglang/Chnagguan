package com.guoguanla.module.bank.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Data
@Builder
public class QuestionVO {

    private Long id;
    private String gradeCode;
    private String gradeName;
    private String realmCode;
    private String realmName;
    private Long chapterId;
    private String chapterName;
    private Long gateId;
    private String gateName;
    private String questionMode;
    private String questionFormat;
    private String stem;
    private List<String> options;
    private Map<String, Object> answer;
    private String analysis;
    private String generatorCode;
    private Map<String, Object> templateRule;
    private Integer difficulty;
    private List<String> tags;
    private Map<String, Object> ext;
    private String source;
    private Integer version;
    private Integer sortOrder;
    private Integer enabled;
    private LocalDateTime updatedAt;
}
