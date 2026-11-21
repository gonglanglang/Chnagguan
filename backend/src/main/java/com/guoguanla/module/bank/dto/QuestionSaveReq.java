package com.guoguanla.module.bank.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;
import java.util.Map;

@Data
public class QuestionSaveReq {

    @NotBlank(message = "年级不能为空")
    private String gradeCode;

    @NotNull(message = "章节不能为空")
    private Long chapterId;

    @NotNull(message = "关卡不能为空")
    private Long gateId;

    /** STATIC / DYNAMIC_TEMPLATE */
    @NotBlank(message = "出题模式不能为空")
    private String questionMode = "STATIC";

    /** SINGLE_CHOICE / MULTI_CHOICE / FILL_BLANK / JUDGE */
    @NotBlank(message = "题型格式不能为空")
    private String questionFormat = "SINGLE_CHOICE";

    @NotBlank(message = "题干不能为空")
    private String stem;

    /** 选项列表（弹性数组，默认4项，支持判断题2项或更多） */
    private List<String> options;

    /** 标准答案结构，如 {"index": 0} 或 {"indexes": [0, 2]} 或 {"values": ["3"]} */
    private Map<String, Object> answer;

    private String analysis = "";
    private String generatorCode;
    private Map<String, Object> templateRule;
    private Integer difficulty = 1;
    private List<String> tags;
    private Map<String, Object> ext;
    private Integer sortOrder = 0;
    private Integer enabled = 1;
}
