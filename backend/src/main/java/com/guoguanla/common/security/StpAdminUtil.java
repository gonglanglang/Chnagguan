package com.guoguanla.common.security;

import cn.dev33.satoken.jwt.StpLogicJwtForSimple;
import cn.dev33.satoken.stp.StpLogic;

/**
 * 管理后台独立 Sa-Token 鉴权工具（与前台学生端令牌体系隔离）
 */
public final class StpAdminUtil {

    public static final String TYPE = "admin";
    public static final StpLogic STP_LOGIC = new StpLogicJwtForSimple(TYPE);

    private StpAdminUtil() {
    }

    public static String login(Long adminId) {
        STP_LOGIC.login(adminId);
        return STP_LOGIC.getTokenValue();
    }

    public static void logout() {
        STP_LOGIC.logout();
    }

    public static void checkLogin() {
        STP_LOGIC.checkLogin();
    }

    public static Long getLoginIdAsLong() {
        return STP_LOGIC.getLoginIdAsLong();
    }

    public static boolean isLogin() {
        return STP_LOGIC.isLogin();
    }
}
