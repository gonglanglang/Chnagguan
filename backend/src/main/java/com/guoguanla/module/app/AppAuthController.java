package com.guoguanla.module.app;

import com.guoguanla.common.result.Result;
import com.guoguanla.module.app.dto.AppLoginReq;
import com.guoguanla.module.app.vo.AppUserProfileVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Tag(name = "学生端-认证与健康检查")
@RestController
@RequestMapping("/api/app")
@RequiredArgsConstructor
public class AppAuthController {

    private final AppAuthService authService;

    @Operation(summary = "健康检查")
    @GetMapping("/health")
    public Result<Map<String, Object>> health() {
        return Result.ok(Map.of("status", "UP", "service", "guoguanla"));
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
}
