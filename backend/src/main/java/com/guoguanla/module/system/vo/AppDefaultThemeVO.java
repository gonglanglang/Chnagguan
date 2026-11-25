package com.guoguanla.module.system.vo;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AppDefaultThemeVO {

    /** 默认 UI 皮肤：welkui / skribble / forui */
    private String uiSkin;

    /** 默认主题强调色 HEX，如 #67C6FF */
    private String themeHex;

    /** 默认主题强调色名称，如 天青漫画 */
    private String themeName;

    /** 默认是否启用暗黑模式 */
    private boolean darkMode;

    /** 主题配置版本号（后台每次修改自动递增时间戳） */
    private String version;
}
