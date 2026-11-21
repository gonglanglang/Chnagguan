package com.guoguanla.module.app;

import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.module.app.dto.AppQuizDTO;
import com.guoguanla.module.app.vo.AppQuizVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "学生端-错题本")
@RestController
@RequestMapping("/api/app/wrong-questions")
@RequiredArgsConstructor
public class AppWrongController {

    private final AppWrongService wrongService;

    @Operation(summary = "分页获取待攻克错题（支持按境界/年级筛选）")
    @GetMapping
    public Result<PageResult<AppQuizVO.WrongQuestionVO>> page(
            @RequestParam(required = false) String gradeCode,
            @RequestParam(required = false) String realmCode,
            @RequestParam(required = false) Long chapterId,
            @RequestParam(defaultValue = "1") Long pageNum,
            @RequestParam(defaultValue = "20") Long pageSize
    ) {
        return Result.ok(wrongService.page(gradeCode, realmCode, chapterId, pageNum, pageSize));
    }

    @Operation(summary = "开始错题重做（最多抽取5题）")
    @PostMapping("/redo/start")
    public Result<AppQuizVO.StartVO> startRedo(@RequestBody(required = false) AppQuizDTO.RedoStartReq req) {
        return Result.ok(wrongService.startRedo(req == null ? new AppQuizDTO.RedoStartReq() : req));
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
}
