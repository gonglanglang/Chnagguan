package com.guoguanla.module.bank.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class QuestionStatusReq {

    @NotNull(message = "状态不能为空")
    private Integer enabled;
}
