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
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "学生端-闯关答题")
@RestController
@RequestMapping("/api/app/quiz")
@RequiredArgsConstructor
public class AppQuizController {

    private final AppQuizService quizService;

    @Operation(summary = "开始关卡答题（服务端动态生成题目，不返回答案）")
    @PostMapping("/start")
    public Result<AppQuizVO.StartVO> start(
            @Valid @RequestBody AppQuizDTO.StartReq req,
            HttpServletRequest request
    ) {
        return Result.ok(quizService.startGateQuiz(req, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "上传解答题绘制图片至阿里云OSS")
    @PostMapping("/upload-answer-image")
    public Result<AppQuizVO.UploadAnswerImageVO> uploadAnswerImage(
            @RequestParam("file") MultipartFile file,
            @RequestParam("sessionNo") String sessionNo,
            @RequestParam(value = "itemIndex", defaultValue = "0") Integer itemIndex,
            HttpServletRequest request
    ) {
        return Result.ok(quizService.uploadEssayImage(
                sessionNo,
                itemIndex,
                file,
                ServletUrlHelper.resolveBaseOrigin(request)
        ));
    }

    @Operation(summary = "单题提交判题（选择题服务端判分，解答题调用 AI 实时视觉/文字批改）")
    @PostMapping("/check-item")
    public Result<AppQuizVO.CheckItemVO> checkItem(
            @Valid @RequestBody AppQuizDTO.CheckItemReq req,
            HttpServletRequest request
    ) {
        return Result.ok(quizService.checkItem(req, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "整关交卷结算（更新进度、判断段位晋升、返回下一关信息与错题入库）")
    @PostMapping("/submit")
    public Result<AppQuizVO.SubmitResultVO> submit(
            @Valid @RequestBody AppQuizDTO.SubmitReq req,
            HttpServletRequest request
    ) {
        return Result.ok(quizService.submitGateQuiz(req, ServletUrlHelper.resolveBaseOrigin(request)));
    }
}
