package com.guoguanla.common.security;

import cn.dev33.satoken.jwt.StpLogicJwtForSimple;
import cn.dev33.satoken.stp.StpLogic;

/**
 * 学生端独立 Sa-Token 鉴权工具（与管理后台令牌体系严格隔离）
 */
public final class StpAppUtil {

    public static final String TYPE = "app";
    public static final StpLogic STP_LOGIC = new StpLogicJwtForSimple(TYPE);

    private StpAppUtil() {
    }

    public static String login(Long userId) {
        STP_LOGIC.login(userId);
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
