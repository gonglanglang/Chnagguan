package com.guoguanla.module.system;

import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.module.system.dto.RealmConfigReq;
import com.guoguanla.module.system.entity.EduLevelRule;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.entity.SysOperLog;
import com.guoguanla.module.system.vo.RealmConfigVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Tag(name = "管理后台-境界与系统配置")
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminSystemController {

    private final AdminSystemService systemService;

    @Operation(summary = "修仙境界与进阶考核规则列表")
    @GetMapping("/realms")
    public Result<List<RealmConfigVO>> listRealms() {
        return Result.ok(systemService.listRealms());
    }

    @Operation(summary = "保存修仙境界与进阶抽题/分数线配置")
    @OperLog(module = "REALM", action = "修改境界进阶配置")
    @PutMapping("/realms/{id}")
    public Result<Void> updateRealm(@PathVariable Long id, @Valid @RequestBody RealmConfigReq req) {
        systemService.updateRealm(id, req);
        return Result.ok();
    }

    @Operation(summary = "段位规则列表")
    @GetMapping("/levels")
    public Result<List<EduLevelRule>> listLevels() {
        return Result.ok(systemService.listLevels());
    }

    @Operation(summary = "编辑段位规则")
    @OperLog(module = "LEVEL", action = "修改段位规则")
    @PutMapping("/levels/{id}")
    public Result<Void> updateLevel(@PathVariable Long id, @RequestBody EduLevelRule req) {
        systemService.updateLevel(id, req);
        return Result.ok();
    }

    @Operation(summary = "系统参数列表")
    @GetMapping("/configs")
    public Result<List<SysConfig>> listConfigs() {
        return Result.ok(systemService.listConfigs());
    }

    @Operation(summary = "更新系统参数")
    @OperLog(module = "SYSTEM", action = "修改系统参数")
    @PutMapping("/configs")
    public Result<Void> updateConfig(@RequestBody Map<String, String> body) {
        systemService.updateConfig(body.get("configKey"), body.get("configValue"));
        return Result.ok();
    }

    @Operation(summary = "分页查询操作审计日志")
    @GetMapping("/logs")
    public Result<PageResult<SysOperLog>> pageLogs(
            @RequestParam(required = false) String module,
            @RequestParam(defaultValue = "1") Long pageNum,
            @RequestParam(defaultValue = "15") Long pageSize
    ) {
        return Result.ok(systemService.pageLogs(module, pageNum, pageSize));
    }
}
