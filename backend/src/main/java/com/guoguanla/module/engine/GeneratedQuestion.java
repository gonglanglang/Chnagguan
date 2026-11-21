package com.guoguanla.module.engine;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class GeneratedQuestion {

    private String stem;
    private List<String> options;
    private Integer answerIndex;
    private String analysis;
}
