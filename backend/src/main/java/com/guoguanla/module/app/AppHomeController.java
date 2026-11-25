package com.guoguanla.module.app;

import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.common.util.ServletUrlHelper;
import com.guoguanla.module.app.dto.AppLoginReq;
import com.guoguanla.module.app.vo.AppQuizVO;
import com.guoguanla.module.app.vo.AppUserProfileVO;
import com.guoguanla.module.system.vo.AppDefaultThemeVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Tag(name = "学生端-首页、修仙境界与个人中心")
@RestController
@RequestMapping("/api/app")
@RequiredArgsConstructor
public class AppHomeController {

    private final AppBankService bankService;
    private final AppQuizService quizService;

    @Operation(summary = "首页概览（修仙境界列表、公告、默认主题与当前学生状态）")
    @GetMapping("/home/summary")
    public Result<AppUserProfileVO.HomeSummaryVO> homeSummary(@RequestParam(required = false) String guestPassedIds) {
        return Result.ok(bankService.homeSummary(parseIds(guestPassedIds)));
    }

    @Operation(summary = "获取后台配置的学生端默认主题（公开接口，用于启动自动同步）")
    @GetMapping("/theme/default")
    public Result<AppDefaultThemeVO> defaultTheme() {
        return Result.ok(bankService.getDefaultTheme());
    }

    @Operation(summary = "获取全部修仙境界与解锁状态")
    @GetMapping("/realms")
    public Result<List<AppUserProfileVO.RealmItemVO>> realms(@RequestParam(required = false) String guestPassedIds) {
        return Result.ok(bankService.listRealms(parseIds(guestPassedIds)));
    }

    @Operation(summary = "按修仙境界查询章节及通关状态")
    @GetMapping("/realms/{realmCode}/chapters")
    public Result<List<AppUserProfileVO.ChapterCardVO>> chaptersByRealm(
            @PathVariable String realmCode,
            @RequestParam(required = false) String guestPassedIds
    ) {
        return Result.ok(bankService.listChaptersByRealm(realmCode, parseIds(guestPassedIds)));
    }

    @Operation(summary = "查询年级下的章节及通关星数（兼容旧路径）")
    @GetMapping("/grades/{gradeCode}/chapters")
    public Result<List<AppUserProfileVO.ChapterCardVO>> chapters(
            @PathVariable String gradeCode,
            @RequestParam(required = false) String guestPassedIds
    ) {
        return Result.ok(bankService.listChaptersByGrade(gradeCode, parseIds(guestPassedIds)));
    }

    @Operation(summary = "查询章节下 4 道关卡及解锁状态")
    @GetMapping("/chapters/{chapterId}/gates")
    public Result<List<AppUserProfileVO.GateCardVO>> gates(
            @PathVariable Long chapterId,
            @RequestParam(required = false) String guestPassedIds
    ) {
        return Result.ok(bankService.listGatesByChapter(chapterId, parseIds(guestPassedIds)));
    }

    @Operation(summary = "段位规则列表（兼容旧接口）")
    @GetMapping("/levels")
    public Result<List<AppUserProfileVO.LevelItemVO>> levels(@RequestParam(required = false) Integer guestPassedCount) {
        return Result.ok(bankService.listLevels(guestPassedCount));
    }

    @Operation(summary = "获取当前学生资料")
    @GetMapping("/user/profile")
    public Result<AppUserProfileVO> profile(HttpServletRequest request) {
        return Result.ok(bankService.currentProfile(ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "修改学生昵称与头像")
    @PutMapping("/user/profile")
    public Result<AppUserProfileVO> updateProfile(
            @Valid @RequestBody AppLoginReq.ProfileUpdateReq req,
            HttpServletRequest request
    ) {
        return Result.ok(bankService.updateProfile(req, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "上传学生头像")
    @PostMapping("/user/avatar")
    public Result<AppUserProfileVO> uploadAvatar(
            @RequestParam("file") MultipartFile file,
            HttpServletRequest request
    ) {
        return Result.ok(bankService.uploadAvatar(file, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "获取各章过关战绩")
    @GetMapping("/user/chapter-records")
    public Result<List<AppUserProfileVO.ChapterCardVO>> chapterRecords() {
        return Result.ok(bankService.listUserChapterRecords());
    }

    @Operation(summary = "分页获取本人解答题画板作答记录")
    @GetMapping("/user/essay-answers")
    public Result<PageResult<AppQuizVO.EssayAnswerRecordVO>> myEssayAnswers(
            @RequestParam(defaultValue = "1") Long pageNum,
            @RequestParam(defaultValue = "10") Long pageSize,
            HttpServletRequest request
    ) {
        return Result.ok(quizService.listMyEssayAnswers(pageNum, pageSize, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "清空本人解答题画板作答记录（数据库永久删除）")
    @DeleteMapping("/user/essay-answers/clear")
    public Result<Void> clearMyEssayAnswers() {
        quizService.clearMyEssayAnswers();
        return Result.ok();
    }

    private Set<Long> parseIds(String csv) {
        if (csv == null || csv.isBlank()) {
            return Set.of();
        }
        return Arrays.stream(csv.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .map(Long::valueOf)
                .collect(Collectors.toSet());
    }
}
