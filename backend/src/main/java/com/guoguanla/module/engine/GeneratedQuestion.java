package com.guoguanla.module.engine;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class GeneratedQuestion {

    private String stem;
    private List<String> options;
    private Integer answerIndex;
    private String analysis;
    private String questionFormat;
    private String referenceAnswer;
    private Map<String, Object> diagram;
    private String imageKey;

    public GeneratedQuestion(String stem, List<String> options, Integer answerIndex, String analysis) {
        this.stem = stem;
        this.options = options;
        this.answerIndex = answerIndex;
        this.analysis = analysis;
        this.questionFormat = "SINGLE_CHOICE";
        this.referenceAnswer = (options != null && answerIndex != null && answerIndex >= 0 && answerIndex < options.size())
                ? options.get(answerIndex)
                : "";
    }

    public GeneratedQuestion(String stem, List<String> options, Integer answerIndex, String analysis,
                             String questionFormat, String referenceAnswer) {
        this.stem = stem;
        this.options = options;
        this.answerIndex = answerIndex;
        this.analysis = analysis;
        this.questionFormat = questionFormat;
        this.referenceAnswer = referenceAnswer;
    }
}
