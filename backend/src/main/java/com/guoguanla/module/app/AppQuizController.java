package com.guoguanla.module.app;

import com.guoguanla.common.result.Result;
import com.guoguanla.module.app.dto.AppQuizDTO;
import com.guoguanla.module.app.vo.AppQuizVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "学生端-闯关答题")
@RestController
@RequestMapping("/api/app/quiz")
@RequiredArgsConstructor
public class AppQuizController {

    private final AppQuizService quizService;

    @Operation(summary = "开始关卡答题（服务端动态生成题目，不返回答案）")
    @PostMapping("/start")
    public Result<AppQuizVO.StartVO> start(@Valid @RequestBody AppQuizDTO.StartReq req) {
        return Result.ok(quizService.startGateQuiz(req));
    }

    @Operation(summary = "单题提交判题（返回对错、正确答案与解析）")
    @PostMapping("/check-item")
    public Result<AppQuizVO.CheckItemVO> checkItem(@Valid @RequestBody AppQuizDTO.CheckItemReq req) {
        return Result.ok(quizService.checkItem(req));
    }

    @Operation(summary = "整关交卷结算（更新进度、判断段位晋升与错题入库）")
    @PostMapping("/submit")
    public Result<AppQuizVO.SubmitResultVO> submit(@Valid @RequestBody AppQuizDTO.SubmitReq req) {
        return Result.ok(quizService.submitGateQuiz(req));
    }
}
