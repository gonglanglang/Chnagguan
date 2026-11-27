package com.guoguanla.module.app;

import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.common.util.ServletUrlHelper;
import com.guoguanla.module.app.dto.AppQuizDTO;
import com.guoguanla.module.app.vo.AppQuizVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

@Tag(name = "学生端-错题本")
@RestController
@RequestMapping("/api/app/wrong-questions")
@RequiredArgsConstructor
public class AppWrongController {

    private static final MediaType DOCX_MEDIA_TYPE = MediaType.parseMediaType(
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    );

    private final AppWrongService wrongService;
    private final WrongQuestionDocxService wrongDocxService;

    @Operation(summary = "分页获取待攻克错题（支持按学习阶段/年级筛选）")
    @GetMapping
    public Result<PageResult<AppQuizVO.WrongQuestionVO>> page(
            @RequestParam(required = false) String gradeCode,
            @RequestParam(required = false) String realmCode,
            @RequestParam(required = false) Long chapterId,
            @RequestParam(defaultValue = "1") Long pageNum,
            @RequestParam(defaultValue = "20") Long pageSize,
            HttpServletRequest request
    ) {
        return Result.ok(wrongService.page(
                gradeCode, realmCode, chapterId, pageNum, pageSize, ServletUrlHelper.resolveBaseOrigin(request)
        ));
    }

    @Operation(summary = "开始错题重做（最多抽取5题）")
    @PostMapping("/redo/start")
    public Result<AppQuizVO.StartVO> startRedo(
            @RequestBody(required = false) AppQuizDTO.RedoStartReq req,
            HttpServletRequest request
    ) {
        return Result.ok(wrongService.startRedo(
                req == null ? new AppQuizDTO.RedoStartReq() : req,
                ServletUrlHelper.resolveBaseOrigin(request)
        ));
    }

    @Operation(summary = "错题重做交卷（答对标记已掌握，答错保留并累计错次）")
    @PostMapping("/redo/submit")
    public Result<AppQuizVO.SubmitResultVO> submitRedo(@Valid @RequestBody AppQuizDTO.SubmitReq req) {
        return Result.ok(wrongService.submitRedo(req));
    }

    @Operation(summary = "手动标记错题已掌握")
    @PutMapping("/{id}/master")
    public Result<Void> markMastered(@PathVariable Long id) {
        wrongService.markMastered(id);
        return Result.ok();
    }

    @Operation(summary = "清空待攻克错题")
    @DeleteMapping("/clear")
    public Result<Void> clear() {
        wrongService.clearAll();
        return Result.ok();
    }

    @Operation(summary = "导出错题本为 A4 纸排版 Word (.docx) 文件")
    @PostMapping("/export-docx")
    public ResponseEntity<byte[]> exportDocx(@RequestBody(required = false) AppQuizDTO.WrongExportReq req) {
        WrongQuestionDocxService.DocxExportResult result = wrongDocxService.exportDocx(req);
        String encodedName = URLEncoder.encode(result.fileName(), StandardCharsets.UTF_8)
                .replace("+", "%20");
        return ResponseEntity.ok()
                .contentType(DOCX_MEDIA_TYPE)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + encodedName)
                .header("X-Export-Question-Count", String.valueOf(result.questionCount()))
                .body(result.bytes());
    }
}
