package com.guoguanla.module.app;

import com.guoguanla.common.result.Result;
import com.guoguanla.common.security.StpAppUtil;
import com.guoguanla.module.app.dto.AppLoginReq;
import com.guoguanla.module.app.vo.AppUserProfileVO;
import com.guoguanla.module.dashboard.StudentOnlineTrackerService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

@Tag(name = "学生端-认证与健康检查")
@RestController
@RequestMapping("/api/app")
@RequiredArgsConstructor
public class AppAuthController {

    private final AppAuthService authService;
    private final CaptchaService captchaService;
    private final StudentOnlineTrackerService onlineTracker;

    @Operation(summary = "健康检查")
    @GetMapping("/health")
    public Result<Map<String, Object>> health() {
        return Result.ok(Map.of("status", "UP", "service", "guoguanla"));
    }

    @Operation(summary = "获取注册图形验证码")
    @GetMapping("/auth/captcha")
    public Result<AppUserProfileVO.CaptchaVO> captcha() {
        return Result.ok(captchaService.generate());
    }

    @Operation(summary = "学生账号登录")
    @PostMapping("/auth/login")
    public Result<AppUserProfileVO.AuthVO> login(@Valid @RequestBody AppLoginReq req) {
        return Result.ok(authService.login(req));
    }

    @Operation(summary = "学生注册")
    @PostMapping("/auth/register")
    public Result<AppUserProfileVO.AuthVO> register(@Valid @RequestBody AppLoginReq.RegisterReq req) {
        return Result.ok(authService.register(req));
    }

    @Operation(summary = "退出登录")
    @PostMapping("/auth/logout")
    public Result<Void> logout() {
        authService.logout();
        return Result.ok();
    }

    @Operation(summary = "学生端前台在线心跳（用于后台实时在线人数统计）")
    @PostMapping("/online/heartbeat")
    public Result<Map<String, Object>> heartbeat(
            @RequestBody(required = false) Map<String, Object> body,
            @RequestHeader(value = "X-Client-Platform", required = false) String headerPlatform
    ) {
        Long userId = StpAppUtil.getLoginIdOrNull();
        boolean online = false;
        if (userId != null) {
            String page = body != null && body.get("page") != null ? String.valueOf(body.get("page")) : "在线学习";
            String platform = body != null && body.get("platform") != null
                    ? String.valueOf(body.get("platform"))
                    : headerPlatform;
            onlineTracker.touchUser(userId, page, platform);
            online = true;
        }
        return Result.ok(Map.of(
                "online", online,
                "serverTime", LocalDateTime.now().toString()
        ));
    }
}
