package com.guoguanla.module.bank.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ChapterSaveReq {

    @NotBlank(message = "年级不能为空")
    private String gradeCode;

    private String chapterCode;

    @NotBlank(message = "章节名称不能为空")
    private String name;

    private String description = "";
    private Integer sortOrder = 0;
    private Integer enabled = 1;
}
