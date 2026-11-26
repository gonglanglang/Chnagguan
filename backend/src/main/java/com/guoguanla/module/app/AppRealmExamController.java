package com.guoguanla.module.app;

import com.guoguanla.common.result.Result;
import com.guoguanla.common.util.ServletUrlHelper;
import com.guoguanla.module.app.dto.AppQuizDTO;
import com.guoguanla.module.app.vo.AppQuizVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "学生端-阶段升级测评")
@RestController
@RequestMapping("/api/app/realm/exam")
@RequiredArgsConstructor
public class AppRealmExamController {

    private final AppQuizService quizService;

    @Operation(summary = "开始当前学习阶段升级测评（随机抽题，不回传答案）")
    @PostMapping("/start")
    public Result<AppQuizVO.StartVO> startExam(HttpServletRequest request) {
        return Result.ok(quizService.startAdvanceExam(ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "提交阶段升级测评试卷（计算得分并判定是否晋升至下一阶段）")
    @PostMapping("/submit")
    public Result<AppQuizVO.SubmitResultVO> submitExam(
            @Valid @RequestBody AppQuizDTO.SubmitReq req,
            HttpServletRequest request
    ) {
        return Result.ok(quizService.submitAdvanceExam(req, ServletUrlHelper.resolveBaseOrigin(request)));
    }
}
