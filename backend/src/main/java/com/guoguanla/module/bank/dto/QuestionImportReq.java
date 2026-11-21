package com.guoguanla.module.bank.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

@Data
public class QuestionImportReq {

    @NotNull(message = "目标章节不能为空")
    private Long chapterId;

    @NotNull(message = "目标关卡不能为空")
    private Long gateId;

    @NotEmpty(message = "导入题目列表不能为空")
    private List<Item> items;

    @Data
    public static class Item {
        /** 兼容原版 {q, o, a} 和标准字段 */
        private String q;
        private List<String> o;
        private Integer a;
        private String stem;
        private List<String> options;
        private Integer answerIndex;
        private String analysis;
    }
}
