package com.guoguanla.common.security;

import cn.dev33.satoken.jwt.StpLogicJwtForStateless;
import cn.dev33.satoken.stp.SaLoginModel;
import cn.dev33.satoken.stp.StpLogic;

/**
 * 学生端独立 Sa-Token 鉴权工具（无状态 JWT，30 天有效期，服务重启与 App 覆盖升级均不丢登录态）
 */
public final class StpAppUtil {

    public static final String TYPE = "app";
    /** Token 有效期：30 天（单位：秒） */
    public static final long TOKEN_TIMEOUT_SECONDS = 30L * 24 * 3600;
    public static final StpLogic STP_LOGIC = new StpLogicJwtForStateless(TYPE);

    private StpAppUtil() {
    }

    public static String login(Long userId) {
        STP_LOGIC.login(userId, new SaLoginModel().setTimeout(TOKEN_TIMEOUT_SECONDS));
        return STP_LOGIC.getTokenValue();
    }

    public static void logout() {
        STP_LOGIC.logout();
    }

    public static void checkLogin() {
        STP_LOGIC.checkLogin();
    }

    public static boolean isLogin() {
        return STP_LOGIC.isLogin();
    }

    public static Long getLoginIdAsLong() {
        return STP_LOGIC.getLoginIdAsLong();
    }

    public static Long getLoginIdOrNull() {
        try {
            return STP_LOGIC.isLogin() ? STP_LOGIC.getLoginIdAsLong() : null;
        } catch (Exception e) {
            return null;
        }
    }
}
