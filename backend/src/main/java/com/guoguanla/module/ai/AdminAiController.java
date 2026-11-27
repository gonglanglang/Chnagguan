package com.guoguanla.module.ai;

import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.result.Result;
import com.guoguanla.module.ai.dto.AiConfigUpdateReq;
import com.guoguanla.module.ai.dto.AiImageConfigUpdateReq;
import com.guoguanla.module.ai.dto.AiImageGenerateReq;
import com.guoguanla.module.ai.dto.AiImageTestReq;
import com.guoguanla.module.ai.dto.AiTestReq;
import com.guoguanla.module.ai.vo.AiConfigVO;
import com.guoguanla.module.ai.vo.AiImageConfigVO;
import com.guoguanla.module.ai.vo.AiImageGenerateVO;
import com.guoguanla.module.ai.vo.AiImageTestVO;
import com.guoguanla.module.ai.vo.AiTestVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "管理后台-AI 大模型与生图配置")
@RestController
@RequestMapping("/api/admin/ai")
@RequiredArgsConstructor
public class AdminAiController {

    private final AiConfigService aiConfigService;
    private final AiBoardService aiBoardService;
    private final AiImageConfigService aiImageConfigService;
    private final AiImageService aiImageService;

    @Operation(summary = "获取当前 AI 配置（密钥已脱敏）")
    @GetMapping("/config")
    public Result<AiConfigVO> getConfig() {
        return Result.ok(aiConfigService.getAdminConfigView());
    }

    @Operation(summary = "保存 OpenAI 兼容 AI 配置")
    @OperLog(module = "AI", action = "更新AI大模型配置")
    @PutMapping("/config")
    public Result<AiConfigVO> updateConfig(@Valid @RequestBody AiConfigUpdateReq req) {
        return Result.ok(aiConfigService.updateAdminConfig(req));
    }

    @Operation(summary = "一键测试 AI 模型连通性")
    @PostMapping("/test")
    public Result<AiTestVO> testConnection(@RequestBody(required = false) AiTestReq req) {
        return Result.ok(aiBoardService.testConnection(req));
    }

    @Operation(summary = "获取当前 AI 生图配置（密钥已脱敏）")
    @GetMapping("/image-config")
    public Result<AiImageConfigVO> getImageConfig() {
        return Result.ok(aiImageConfigService.getAdminConfigView());
    }

    @Operation(summary = "保存 AI 生图配置（兼容 Flow Agent 与 OpenAI Images 协议）")
    @OperLog(module = "AI", action = "更新AI生图配置")
    @PutMapping("/image-config")
    public Result<AiImageConfigVO> updateImageConfig(@Valid @RequestBody AiImageConfigUpdateReq req) {
        return Result.ok(aiImageConfigService.updateAdminConfig(req));
    }

    @Operation(summary = "测试 AI 生图服务连通性或发起试生图")
    @PostMapping("/image/test")
    public Result<AiImageTestVO> testImageConnection(@RequestBody(required = false) AiImageTestReq req) {
        return Result.ok(aiImageService.testConnection(req));
    }

    @Operation(summary = "后台通用 AI 生图接口")
    @OperLog(module = "AI", action = "调用AI生图")
    @PostMapping("/image/generate")
    public Result<AiImageGenerateVO> generateImage(
            @Valid @RequestBody AiImageGenerateReq req,
            HttpServletRequest request
    ) {
        return Result.ok(aiImageService.generate(req, resolveBaseOrigin(request)));
    }

    private String resolveBaseOrigin(HttpServletRequest request) {
        if (request == null) {
            return "";
        }
        String scheme = request.getScheme();
        String host = request.getServerName();
        int port = request.getServerPort();
        boolean isDefault = ("http".equalsIgnoreCase(scheme) && port == 80)
                || ("https".equalsIgnoreCase(scheme) && port == 443);
        return isDefault ? (scheme + "://" + host) : (scheme + "://" + host + ":" + port);
    }
}
