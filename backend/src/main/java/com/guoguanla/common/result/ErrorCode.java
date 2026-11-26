package com.guoguanla.common.result;

import lombok.Getter;

@Getter
public enum ErrorCode {

    SUCCESS(200, "ok"),
    BAD_REQUEST(400, "请求参数错误"),
    UNAUTHORIZED(401, "未登录或登录已过期"),
    FORBIDDEN(403, "无权限访问该资源"),
    NOT_FOUND(404, "目标资源不存在"),
    INTERNAL_ERROR(500, "系统内部异常"),

    // 10001+ 用户与认证
    AUTH_FAILED(10001, "账号或密码错误"),
    ACCOUNT_DISABLED(10002, "账号已被禁用"),
    TOKEN_INVALID(10003, "刷新令牌无效或已过期"),
    USER_EXISTS(10004, "用户名或手机号已存在"),

    // 20001+ 题库与关卡
    CHAPTER_CODE_EXISTS(20001, "章节编码已存在"),
    QUESTION_RULE_INVALID(20002, "动态出题模板规则无效"),
    IMPORT_FORMAT_INVALID(20003, "导入数据格式不正确"),
    GATE_LOCKED(20004, "请先通过上一关才能解锁本关"),
    GATE_EMPTY(20005, "当前关卡暂未配置题目"),
    REALM_LOCKED(20006, "当前学习阶段不足，请先通过阶段升级测评后再挑战"),
    REALM_EXAM_LOCKED(20007, "尚未达到阶段升级测评条件，请继续完成本阶段关卡"),
    REALM_MAX_REACHED(20008, "已达最高学习阶段，无需继续升级"),
    REALM_EXAM_EMPTY(20009, "当前学习阶段题库为空，无法生成升级测评试卷"),

    // 30001+ 答题与错题
    QUIZ_SESSION_INVALID(30001, "答题会话不存在或无权访问"),
    QUIZ_ALREADY_SUBMITTED(30002, "本次答题已交卷，请勿重复提交"),
    GUEST_MODE_DISABLED(30003, "游客模式未开启，请先登录"),

    // 40001+ AI 智能画板
    AI_DISABLED(40001, "AI 智能画板功能暂未开启"),
    AI_NOT_CONFIGURED(40002, "AI 服务尚未配置完成，请管理员在后台配置接口与密钥"),
    AI_UPSTREAM_ERROR(40003, "AI 模型服务调用失败，请稍后重试"),
    AI_PARSE_ERROR(40004, "AI 返回结果格式异常，请稍后重试");

    private final int code;
    private final String message;

    ErrorCode(int code, String message) {
        this.code = code;
        this.message = message;
    }
}
