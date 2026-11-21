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

    /** SINGLE_CHOICE / MULTI_CHOICE / FILL_BLANK / JUDGE / ESSAY */
    @NotBlank(message = "题型格式不能为空")
    private String questionFormat = "SINGLE_CHOICE";

    /** STATIC 模式下必填；DYNAMIC_TEMPLATE 模式可留空由模板试生成自动填充示例题干 */
    private String stem;

    /** 选项列表（弹性数组，默认4项，解答题可为空） */
    private List<String> options;

    /** 标准答案结构，如 {"index": 0}、{"indexes": [0, 2]}、{"values": ["3"]} 或 {"text": "解答题参考答案"} */
    private Map<String, Object> answer;

    private String analysis = "";
    private String generatorCode;
    private Map<String, Object> templateRule;
    private Integer difficulty = 1;
    private List<String> tags;
    private Map<String, Object> ext;
    private Integer sortOrder = 0;
    private Integer enabled = 1;

    /** 新增或启用题目时是否同步扩大关卡抽题数，避免新题被抽题上限遗漏 */
    private Boolean syncGateCount = true;
}
