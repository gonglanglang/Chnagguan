package com.guoguanla.module.app;

import com.guoguanla.common.result.Result;
import com.guoguanla.module.app.dto.AppQuizDTO;
import com.guoguanla.module.app.vo.AppQuizVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "学生端-境界进阶考核")
@RestController
@RequestMapping("/api/app/realm/exam")
@RequiredArgsConstructor
public class AppRealmExamController {

    private final AppQuizService quizService;

    @Operation(summary = "开始当前境界进阶考核（随机抽题，不回传答案）")
    @PostMapping("/start")
    public Result<AppQuizVO.StartVO> startExam() {
        return Result.ok(quizService.startAdvanceExam());
    }

    @Operation(summary = "提交进阶考核试卷（计算得分并判定是否突破至下一境界）")
    @PostMapping("/submit")
    public Result<AppQuizVO.SubmitResultVO> submitExam(@Valid @RequestBody AppQuizDTO.SubmitReq req) {
        return Result.ok(quizService.submitAdvanceExam(req));
    }
}
