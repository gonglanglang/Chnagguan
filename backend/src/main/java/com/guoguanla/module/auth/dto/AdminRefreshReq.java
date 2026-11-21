package com.guoguanla.module.auth.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AdminRefreshReq {

    @NotBlank(message = "refreshToken 不能为空")
    private String refreshToken;
}
