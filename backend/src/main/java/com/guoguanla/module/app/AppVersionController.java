package com.guoguanla.module.app;

import com.guoguanla.common.result.Result;
import com.guoguanla.module.system.AppVersionService;
import com.guoguanla.module.system.vo.AppVersionVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@Tag(name = "学生端-App版本检查")
@RestController
@RequestMapping("/api/app/version")
@RequiredArgsConstructor
public class AppVersionController {

    private final AppVersionService appVersionService;

    @Operation(summary = "检测 App 是否有新版本更新")
    @GetMapping("/latest")
    public Result<AppVersionVO> latest(
            @RequestParam(required = false) String currentVersion,
            @RequestParam(required = false) Integer versionCode
    ) {
        String baseOrigin = ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
        return Result.ok(appVersionService.checkLatestVersion(currentVersion, versionCode, baseOrigin, false));
    }
}
