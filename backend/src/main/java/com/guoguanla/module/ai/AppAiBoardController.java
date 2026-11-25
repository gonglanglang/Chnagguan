package com.guoguanla.module.ai;

import com.guoguanla.common.result.Result;
import com.guoguanla.module.ai.dto.AiBoardAnalyzeReq;
import com.guoguanla.module.ai.dto.AiRecognizeReq;
import com.guoguanla.module.ai.vo.AiBoardVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "学生端-AI 智能手写画板")
@RestController
@RequestMapping("/api/app/ai")
@RequiredArgsConstructor
public class AppAiBoardController {

    private final AiBoardService aiBoardService;

    @Operation(summary = "获取 AI 智能画板可用状态（绝不返回密钥）")
    @GetMapping("/status")
    public Result<AiBoardVO.StatusVO> status() {
        return Result.ok(aiBoardService.getStudentStatus());
    }

    @Operation(summary = "拍照/Base64 识别数学题目并结构化解析")
    @PostMapping("/recognize-problem")
    public Result<AiBoardVO.RecognizeVO> recognizeProblem(@RequestBody AiRecognizeReq req) {
        return Result.ok(aiBoardService.recognizeProblem(req));
    }

    @Operation(summary = "Multipart 上传图片识别数学题目")
    @PostMapping("/recognize-problem/upload")
    public Result<AiBoardVO.RecognizeVO> recognizeProblemUpload(
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false) String extraHint,
            @RequestParam(required = false) String sourceType
    ) {
        return Result.ok(aiBoardService.recognizeProblemUpload(file, extraHint, sourceType));
    }

    @Operation(summary = "AI 生成启发式解题思路（仅给思路/公式/方法，不直接给答案）")
    @PostMapping("/board/ideas")
    public Result<AiBoardVO.GuidanceVO> generateIdeas(@RequestBody AiBoardAnalyzeReq req) {
        return Result.ok(aiBoardService.generateIdeas(req));
    }

    @Operation(summary = "AI 诊断学生手写解题过程（仅诊断对错与错因，不直接给答案）")
    @PostMapping("/board/diagnose")
    public Result<AiBoardVO.GuidanceVO> diagnoseHandwriting(@RequestBody AiBoardAnalyzeReq req) {
        return Result.ok(aiBoardService.diagnoseHandwriting(req));
    }

    @Operation(summary = "AI 直接绘制完整规范解题过程与答案")
    @PostMapping("/board/solve")
    public Result<AiBoardVO.GuidanceVO> solveProblem(@RequestBody AiBoardAnalyzeReq req) {
        return Result.ok(aiBoardService.solveProblem(req));
    }

    @Operation(summary = "兼容旧路径：AI 解题过程分析")
    @PostMapping("/board/analyze")
    public Result<AiBoardVO.GuidanceVO> analyzeSolution(@RequestBody AiBoardAnalyzeReq req) {
        return Result.ok(aiBoardService.solveProblem(req));
    }
}
