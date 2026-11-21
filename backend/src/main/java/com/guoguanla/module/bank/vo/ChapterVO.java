package com.guoguanla.module.bank.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class ChapterVO {

    private Long id;
    private String chapterCode;
    private String gradeCode;
    private String gradeName;
    private String realmCode;
    private String realmName;
    private String name;
    private String description;
    private Integer isCustom;
    private Integer sortOrder;
    private Integer enabled;
    private Long gateCount;
    private Long questionCount;
    private LocalDateTime updatedAt;
}
