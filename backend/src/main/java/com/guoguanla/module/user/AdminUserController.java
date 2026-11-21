package com.guoguanla.module.user;

import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.module.user.dto.UserCreateReq;
import com.guoguanla.module.user.dto.UserQueryReq;
import com.guoguanla.module.user.dto.UserStatusReq;
import com.guoguanla.module.user.dto.UserUpdateReq;
import com.guoguanla.module.user.vo.UserDetailVO;
import com.guoguanla.module.user.vo.UserPageVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Tag(name = "管理后台-用户管理")
@RestController
@RequestMapping("/api/admin/users")
@RequiredArgsConstructor
public class AdminUserController {

    private final AdminUserService userService;

    @Operation(summary = "分页查询学生用户")
    @GetMapping
    public Result<PageResult<UserPageVO>> page(UserQueryReq req) {
        return Result.ok(userService.page(req));
    }

    @Operation(summary = "查看用户详细信息与战绩")
    @GetMapping("/{id}")
    public Result<UserDetailVO> detail(@PathVariable Long id) {
        return Result.ok(userService.detail(id));
    }

    @Operation(summary = "新增学生用户")
    @OperLog(module = "USER", action = "新增学生用户")
    @PostMapping
    public Result<Long> create(@Valid @RequestBody UserCreateReq req) {
        return Result.ok(userService.create(req));
    }

    @Operation(summary = "编辑学生用户信息")
    @OperLog(module = "USER", action = "编辑学生用户信息")
    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @Valid @RequestBody UserUpdateReq req) {
        userService.update(id, req);
        return Result.ok();
    }

    @Operation(summary = "调整学生修仙境界")
    @OperLog(module = "USER", action = "调整学生修仙境界")
    @PutMapping("/{id}/realm")
    public Result<Void> updateRealm(@PathVariable Long id, @RequestBody Map<String, String> body) {
        userService.updateRealm(id, body.get("realmCode"));
        return Result.ok();
    }

    @Operation(summary = "启停学生账号")
    @OperLog(module = "USER", action = "修改学生账号状态")
    @PutMapping("/{id}/status")
    public Result<Void> updateStatus(@PathVariable Long id, @Valid @RequestBody UserStatusReq req) {
        userService.updateStatus(id, req.getStatus());
        return Result.ok();
    }

    @Operation(summary = "删除学生用户")
    @OperLog(module = "USER", action = "删除学生用户")
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        userService.delete(id);
        return Result.ok();
    }
}
