package com.guoguanla.module.user.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class UserStatusReq {

    @NotNull(message = "状态不能为空")
    private Integer status;
}
