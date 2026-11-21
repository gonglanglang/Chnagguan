package com.guoguanla.module.auth;

import com.guoguanla.common.result.Result;
import com.guoguanla.module.auth.dto.AdminLoginReq;
import com.guoguanla.module.auth.dto.AdminRefreshReq;
import com.guoguanla.module.auth.vo.AdminLoginVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Tag(name = "管理后台-认证")
@RestController
@RequestMapping("/api/admin/auth")
@RequiredArgsConstructor
public class AdminAuthController {

    private final AdminAuthService authService;

    @Operation(summary = "管理员登录")
    @PostMapping("/login")
    public Result<AdminLoginVO> login(@Valid @RequestBody AdminLoginReq req) {
        return Result.ok(authService.login(req));
    }

    @Operation(summary = "刷新令牌")
    @PostMapping("/refresh-token")
    public Result<AdminLoginVO> refreshToken(@Valid @RequestBody AdminRefreshReq req) {
        return Result.ok(authService.refreshToken(req));
    }

    @Operation(summary = "当前管理员信息")
    @GetMapping("/me")
    public Result<AdminLoginVO> me() {
        return Result.ok(authService.currentAdmin());
    }

    @Operation(summary = "获取动态菜单路由")
    @GetMapping("/routes")
    public Result<List<Map<String, Object>>> routes() {
        // 静态路由模块已内置于 pure-admin-thin router/modules，此处预留按角色扩展动态路由
        return Result.ok(List.of());
    }

    @Operation(summary = "退出登录")
    @PostMapping("/logout")
    public Result<Void> logout() {
        authService.logout();
        return Result.ok();
    }
}
