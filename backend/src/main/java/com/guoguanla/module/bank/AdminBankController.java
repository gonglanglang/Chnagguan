package com.guoguanla.module.bank;

import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.common.util.ServletUrlHelper;
import com.guoguanla.module.bank.dto.*;
import com.guoguanla.module.bank.entity.EduGrade;
import com.guoguanla.module.bank.vo.ChapterVO;
import com.guoguanla.module.bank.vo.GateVO;
import com.guoguanla.module.bank.vo.QuestionVO;
import com.guoguanla.module.engine.GeneratedQuestion;
import com.guoguanla.module.oss.AliyunOssService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

@Tag(name = "管理后台-题库与关卡配置")
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminBankController {

    private final AdminBankService bankService;

    @Operation(summary = "年级列表")
    @GetMapping("/grades")
    public Result<List<EduGrade>> listGrades() {
        return Result.ok(bankService.listGrades());
    }

    @Operation(summary = "修改年级配置")
    @OperLog(module = "CHAPTER", action = "修改年级配置")
    @PutMapping("/grades/{id}")
    public Result<Void> updateGrade(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        Integer enabled = body.get("enabled") == null ? null : ((Number) body.get("enabled")).intValue();
        String icon = body.get("icon") == null ? null : String.valueOf(body.get("icon"));
        String gradeName = body.get("gradeName") == null ? null : String.valueOf(body.get("gradeName"));
        bankService.updateGrade(id, enabled, icon, gradeName);
        return Result.ok();
    }

    @Operation(summary = "章节列表")
    @GetMapping("/chapters")
    public Result<List<ChapterVO>> listChapters(
            @RequestParam(required = false) String gradeCode,
            @RequestParam(required = false) String realmCode,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Integer enabled
    ) {
        return Result.ok(bankService.listChapters(gradeCode, realmCode, keyword, enabled));
    }

    @Operation(summary = "新增章节（自动初始化4关）")
    @OperLog(module = "CHAPTER", action = "新增章节")
    @PostMapping("/chapters")
    public Result<Long> createChapter(@Valid @RequestBody ChapterSaveReq req) {
        return Result.ok(bankService.createChapter(req));
    }

    @Operation(summary = "编辑章节")
    @OperLog(module = "CHAPTER", action = "编辑章节")
    @PutMapping("/chapters/{id}")
    public Result<Void> updateChapter(@PathVariable Long id, @Valid @RequestBody ChapterSaveReq req) {
        bankService.updateChapter(id, req);
        return Result.ok();
    }

    @Operation(summary = "删除章节")
    @OperLog(module = "CHAPTER", action = "删除章节")
    @DeleteMapping("/chapters/{id}")
    public Result<Void> deleteChapter(@PathVariable Long id) {
        bankService.deleteChapter(id);
        return Result.ok();
    }

    @Operation(summary = "章节下关卡配置列表")
    @GetMapping("/chapters/{chapterId}/gates")
    public Result<List<GateVO>> listGates(@PathVariable Long chapterId) {
        return Result.ok(bankService.listGatesByChapter(chapterId));
    }

    @Operation(summary = "修改关卡规则配置")
    @OperLog(module = "GATE", action = "修改关卡配置")
    @PutMapping("/gates/{gateId}")
    public Result<Void> updateGate(@PathVariable Long gateId, @Valid @RequestBody GateUpdateReq req) {
        bankService.updateGate(gateId, req);
        return Result.ok();
    }

    @Operation(summary = "分页查询题目")
    @GetMapping("/questions")
    public Result<PageResult<QuestionVO>> pageQuestions(QuestionQueryReq req, HttpServletRequest request) {
        return Result.ok(bankService.pageQuestions(req, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "题目详情")
    @GetMapping("/questions/{id}")
    public Result<QuestionVO> getQuestion(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(bankService.getQuestion(id, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "上传题目配图至阿里云 OSS（无 OSS 时本地降级）")
    @OperLog(module = "QUESTION", action = "上传题目配图")
    @PostMapping("/questions/upload-image")
    public Result<AliyunOssService.UploadResult> uploadQuestionImage(
            @RequestParam("file") MultipartFile file,
            HttpServletRequest request
    ) {
        return Result.ok(bankService.uploadQuestionFigure(file, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "新增题目")
    @OperLog(module = "QUESTION", action = "新增题目")
    @PostMapping("/questions")
    public Result<Long> createQuestion(@Valid @RequestBody QuestionSaveReq req) {
        return Result.ok(bankService.createQuestion(req));
    }

    @Operation(summary = "编辑题目")
    @OperLog(module = "QUESTION", action = "编辑题目")
    @PutMapping("/questions/{id}")
    public Result<Void> updateQuestion(@PathVariable Long id, @Valid @RequestBody QuestionSaveReq req) {
        bankService.updateQuestion(id, req);
        return Result.ok();
    }

    @Operation(summary = "上下架题目")
    @OperLog(module = "QUESTION", action = "修改题目上下架状态")
    @PatchMapping("/questions/{id}/status")
    public Result<Void> updateQuestionStatus(@PathVariable Long id, @Valid @RequestBody QuestionStatusReq req) {
        bankService.updateQuestionStatus(id, req.getEnabled());
        return Result.ok();
    }

    @Operation(summary = "删除题目")
    @OperLog(module = "QUESTION", action = "删除题目")
    @DeleteMapping("/questions/{id}")
    public Result<Void> deleteQuestion(@PathVariable Long id) {
        bankService.deleteQuestion(id);
        return Result.ok();
    }

    @Operation(summary = "动态模板试生成预览")
    @PostMapping("/questions/preview-generate")
    public Result<List<GeneratedQuestion>> previewGenerate(@RequestBody QuestionPreviewReq req) {
        return Result.ok(bankService.previewGenerate(req));
    }

    @Operation(summary = "批量JSON导入题目")
    @OperLog(module = "QUESTION", action = "批量导入题目")
    @PostMapping("/questions/import-json")
    public Result<Map<String, Object>> importJson(@Valid @RequestBody QuestionImportReq req) {
        int count = bankService.importQuestionsJson(req);
        return Result.ok(Map.of("importedCount", count));
    }

    @Operation(summary = "导出题目JSON")
    @GetMapping("/questions/export-json")
    public Result<List<QuestionVO>> exportJson(QuestionQueryReq req) {
        return Result.ok(bankService.exportQuestions(req));
    }
}
