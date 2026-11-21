package com.guoguanla.module.bank.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class GateUpdateReq {

    @NotBlank(message = "关卡名称不能为空")
    private String gateName;

    @NotNull(message = "星级不能为空")
    @Min(1)
    private Integer star;

    @NotNull(message = "抽题数不能为空")
    @Min(1)
    private Integer questionCount;

    @NotNull(message = "过关要求不能为空")
    @Min(1)
    private Integer passCount;

    @NotNull(message = "状态不能为空")
    private Integer enabled;
}
