package com.guoguanla.common.security;

import cn.dev33.satoken.jwt.StpLogicJwtForStateless;
import cn.dev33.satoken.stp.SaLoginModel;
import cn.dev33.satoken.stp.StpLogic;

/**
 * 管理后台独立 Sa-Token 鉴权工具（无状态 JWT，30 天有效期，与前台学生端令牌体系隔离）
 */
public final class StpAdminUtil {

    public static final String TYPE = "admin";
    /** Token 有效期：30 天（单位：秒） */
    public static final long TOKEN_TIMEOUT_SECONDS = 30L * 24 * 3600;
    public static final StpLogic STP_LOGIC = new StpLogicJwtForStateless(TYPE);

    private StpAdminUtil() {
    }

    public static String login(Long adminId) {
        STP_LOGIC.login(adminId, new SaLoginModel().setTimeout(TOKEN_TIMEOUT_SECONDS));
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
