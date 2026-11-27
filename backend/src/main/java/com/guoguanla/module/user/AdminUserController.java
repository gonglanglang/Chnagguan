package com.guoguanla.module.user;

import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.common.util.ServletUrlHelper;
import com.guoguanla.module.user.dto.UserCreateReq;
import com.guoguanla.module.user.dto.UserQueryReq;
import com.guoguanla.module.user.dto.UserStatusReq;
import com.guoguanla.module.user.dto.UserUpdateReq;
import com.guoguanla.module.user.vo.UserDetailVO;
import com.guoguanla.module.user.vo.UserPageVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
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
    public Result<UserDetailVO> detail(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(userService.detail(id, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "查看单次答题会话逐题作答明细")
    @GetMapping("/{id}/quiz-records/{sessionNo}")
    public Result<List<UserDetailVO.QuizSessionItemVO>> quizRecordDetail(
            @PathVariable Long id,
            @PathVariable String sessionNo,
            HttpServletRequest request
    ) {
        return Result.ok(userService.getQuizRecordDetail(id, sessionNo, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "只读分页查看学生解答题 AI 批改记录")
    @GetMapping("/{id}/essay-answers")
    public Result<PageResult<UserDetailVO.EssayAnswerItem>> essayAnswers(
            @PathVariable Long id,
            @RequestParam(required = false, defaultValue = "1") Long pageNum,
            @RequestParam(required = false, defaultValue = "10") Long pageSize,
            HttpServletRequest request
    ) {
        return Result.ok(userService.listUserEssayAnswers(id, pageNum, pageSize, ServletUrlHelper.resolveBaseOrigin(request)));
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

    @Operation(summary = "修改重置学生登录密码")
    @OperLog(module = "USER", action = "修改学生密码")
    @PutMapping("/{id}/password")
    public Result<Void> updatePassword(@PathVariable Long id, @RequestBody Map<String, String> body) {
        userService.updatePassword(id, body.get("password"));
        return Result.ok();
    }

    @Operation(summary = "调整学生学习阶段")
    @OperLog(module = "USER", action = "调整学生学习阶段")
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
