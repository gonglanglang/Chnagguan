package com.guoguanla.module.ai;

import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.result.Result;
import com.guoguanla.module.ai.dto.AiConfigUpdateReq;
import com.guoguanla.module.ai.dto.AiTestReq;
import com.guoguanla.module.ai.vo.AiConfigVO;
import com.guoguanla.module.ai.vo.AiTestVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "管理后台-AI 大模型配置")
@RestController
@RequestMapping("/api/admin/ai")
@RequiredArgsConstructor
public class AdminAiController {

    private final AiConfigService aiConfigService;
    private final AiBoardService aiBoardService;

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
}
