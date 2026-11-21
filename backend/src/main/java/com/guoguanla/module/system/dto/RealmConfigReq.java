package com.guoguanla.module.system.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class RealmConfigReq {

    @NotBlank(message = "境界名称不能为空")
    private String realmName;

    @NotBlank(message = "难度标签不能为空")
    private String difficultyLabel;

    private String description = "";

    @NotNull(message = "解锁通关数不能为空")
    @Min(value = 0, message = "解锁通关数不能小于 0")
    private Integer unlockGates;

    @NotNull(message = "进阶抽题数不能为空")
    @Min(value = 1, message = "进阶抽题数至少为 1 题")
    @Max(value = 50, message = "进阶抽题数不能超过 50 题")
    private Integer examQuestionCount;

    @NotNull(message = "进阶及格分数线不能为空")
    @Min(value = 1, message = "进阶及格分数线不能低于 1 分")
    @Max(value = 100, message = "进阶及格分数线不能高于 100 分")
    private Integer examPassScore;
}
