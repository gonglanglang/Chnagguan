package com.guoguanla.module.system;

import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.system.dto.AppDefaultThemeReq;
import com.guoguanla.module.system.dto.RealmConfigReq;
import com.guoguanla.module.system.entity.EduLevelRule;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.entity.SysOperLog;
import com.guoguanla.module.system.vo.AppDefaultThemeVO;
import com.guoguanla.module.system.vo.AppVersionVO;
import com.guoguanla.module.system.vo.RealmConfigVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.util.List;
import java.util.Map;

@Tag(name = "管理后台-境界与系统配置")
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminSystemController {

    private final AdminSystemService systemService;
    private final AppVersionService appVersionService;

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

    @Operation(summary = "读取学生端默认主题配置")
    @GetMapping("/theme/default")
    public Result<AppDefaultThemeVO> getDefaultTheme() {
        return Result.ok(systemService.getDefaultTheme());
    }

    @Operation(summary = "更新学生端默认主题配置（下次进入生效）")
    @OperLog(module = "SYSTEM", action = "修改学生端默认主题")
    @PutMapping("/theme/default")
    public Result<AppDefaultThemeVO> updateDefaultTheme(@Valid @RequestBody AppDefaultThemeReq req) {
        return Result.ok(systemService.updateDefaultTheme(req));
    }

    @Operation(summary = "检测并刷新 App 最新版本（含 GitHub Releases）")
    @GetMapping("/app/version/latest")
    public Result<AppVersionVO> checkAppVersion(@RequestParam(defaultValue = "false") boolean refresh) {
        String baseOrigin = ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
        return Result.ok(appVersionService.checkLatestVersion(null, null, baseOrigin, refresh));
    }

    @Operation(summary = "初始化 APK 直传阿里云 OSS 预签名上传地址")
    @PostMapping("/app/upload-apk/init")
    public Result<AliyunOssService.DirectPutInitResult> initApkUpload(@Valid @RequestBody ApkInitReq req) {
        return Result.ok(appVersionService.initApkDirectUpload(req.getFileName(), req.getVersion()));
    }

    @Operation(summary = "登记直传 OSS 后的 APK 版本信息并发布")
    @OperLog(module = "SYSTEM", action = "发布OSS直传APK版本")
    @PostMapping("/app/upload-apk/publish")
    public Result<AppVersionVO> publishApk(@Valid @RequestBody ApkPublishReq req) {
        String baseOrigin = ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
        return Result.ok(appVersionService.publishUploadedApk(
                req.getObjectKey(),
                req.getVersion(),
                req.getVersionCode(),
                req.getReleaseNotes(),
                req.getForceUpdate(),
                baseOrigin
        ));
    }

    @Operation(summary = "上传 APK 更新包至阿里云 OSS（或本地降级）并发布为最新版本")
    @OperLog(module = "SYSTEM", action = "上传发布APK安装包")
    @PostMapping("/app/upload-apk")
    public Result<AppVersionVO> uploadApk(
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false) String version,
            @RequestParam(required = false) Integer versionCode,
            @RequestParam(required = false) String releaseNotes,
            @RequestParam(required = false) Boolean forceUpdate
    ) {
        String baseOrigin = ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
        return Result.ok(appVersionService.uploadApk(file, version, versionCode, releaseNotes, forceUpdate, baseOrigin));
    }

    @Data
    public static class ApkInitReq {
        @NotBlank(message = "安装包文件名不能为空")
        private String fileName;
        private String version = "";
    }

    @Data
    public static class ApkPublishReq {
        @NotBlank(message = "objectKey 不能为空")
        private String objectKey;
        private String version = "";
        private Integer versionCode;
        private String releaseNotes;
        private Boolean forceUpdate;
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
