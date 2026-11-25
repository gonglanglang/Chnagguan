package com.guoguanla.module.system.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AppDefaultThemeReq {

    @NotBlank(message = "默认 UI 皮肤不能为空")
    private String uiSkin;

    private String themeHex;

    private String themeName;

    private Boolean darkMode;
}
