package com.guoguanla.module.dashboard;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.module.bank.entity.EduChapter;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.entity.EduGrade;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduChapterMapper;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.bank.mapper.EduGradeMapper;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import com.guoguanla.module.dashboard.vo.DashboardOverviewVO;
import com.guoguanla.module.progress.entity.UserWrongQuestion;
import com.guoguanla.module.progress.mapper.UserQuizRecordMapper;
import com.guoguanla.module.progress.mapper.UserWrongQuestionMapper;
import com.guoguanla.module.system.RealmHelperService;
import com.guoguanla.module.system.entity.EduLevelRule;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.system.mapper.EduLevelRuleMapper;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminDashboardService {

    private final AppUserMapper appUserMapper;
    private final EduGradeMapper gradeMapper;
    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final EduQuestionMapper questionMapper;
    private final EduLevelRuleMapper levelRuleMapper;
    private final UserQuizRecordMapper quizRecordMapper;
    private final UserWrongQuestionMapper wrongMapper;
    private final RealmHelperService realmHelper;
    private final StudentOnlineTrackerService onlineTracker;

    public DashboardOverviewVO.OnlineSummaryVO onlineStudents() {
        return onlineTracker.getOnlineSnapshot();
    }

    public DashboardOverviewVO overview() {
        DashboardOverviewVO.OnlineSummaryVO onlineSnap = onlineTracker.getOnlineSnapshot();
        long userCount = appUserMapper.selectCount(null);
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        long activeUserCount = appUserMapper.selectCount(
                new LambdaQueryWrapper<AppUser>().ge(AppUser::getLastActiveAt, todayStart)
        );
        long chapterCount = chapterMapper.selectCount(null);
        long gateCount = gateMapper.selectCount(null);
        long questionCount = questionMapper.selectCount(null);
        long staticQuestionCount = questionMapper.selectCount(
                new LambdaQueryWrapper<EduQuestion>().eq(EduQuestion::getQuestionMode, "STATIC")
        );
        long dynamicQuestionCount = questionMapper.selectCount(
                new LambdaQueryWrapper<EduQuestion>().eq(EduQuestion::getQuestionMode, "DYNAMIC_TEMPLATE")
        );
        long totalQuizCount = quizRecordMapper.selectCount(null);
        long totalWrongCount = wrongMapper.selectCount(
                new LambdaQueryWrapper<UserWrongQuestion>().eq(UserWrongQuestion::getIsMastered, 0)
        );

        List<EduGrade> grades = gradeMapper.selectList(
                new LambdaQueryWrapper<EduGrade>().orderByAsc(EduGrade::getSortOrder)
        );
        List<EduChapter> allChapters = chapterMapper.selectList(null);
        List<EduQuestion> allQuestions = questionMapper.selectList(null);
        List<AppUser> allUsers = appUserMapper.selectList(null);

        Map<String, Long> chapByGrade = allChapters.stream()
                .collect(Collectors.groupingBy(EduChapter::getGradeCode, Collectors.counting()));
        Map<String, Long> qByGrade = allQuestions.stream()
                .collect(Collectors.groupingBy(EduQuestion::getGradeCode, Collectors.counting()));
        Map<String, Long> uByGrade = allUsers.stream()
                .collect(Collectors.groupingBy(AppUser::getGradeCode, Collectors.counting()));
        Map<String, Long> uByRealm = allUsers.stream()
                .collect(Collectors.groupingBy(u -> realmHelper.resolveUserRealm(u).getRealmCode(), Collectors.counting()));

        List<DashboardOverviewVO.GradeStatItem> gradeStats = grades.stream()
                .map(g -> DashboardOverviewVO.GradeStatItem.builder()
                        .gradeCode(g.getGradeCode())
                        .gradeName(g.getGradeName())
                        .icon(g.getIcon())
                        .chapterCount(chapByGrade.getOrDefault(g.getGradeCode(), 0L))
                        .questionCount(qByGrade.getOrDefault(g.getGradeCode(), 0L))
                        .studentCount(uByGrade.getOrDefault(g.getGradeCode(), 0L))
                        .build())
                .toList();

        List<EduRealm> realms = realmHelper.listAllRealmsForAdmin();
        List<DashboardOverviewVO.RealmStatItem> realmStats = realms.stream()
                .map(r -> DashboardOverviewVO.RealmStatItem.builder()
                        .realmCode(r.getRealmCode())
                        .realmName(r.getRealmName())
                        .difficultyLabel(r.getDifficultyLabel())
                        .gradeCode(r.getGradeCode())
                        .chapterCount(chapByGrade.getOrDefault(r.getGradeCode(), 0L))
                        .questionCount(qByGrade.getOrDefault(r.getGradeCode(), 0L))
                        .studentCount(uByRealm.getOrDefault(r.getRealmCode(), 0L))
                        .build())
                .toList();

        List<EduLevelRule> levels = levelRuleMapper.selectList(
                new LambdaQueryWrapper<EduLevelRule>().orderByAsc(EduLevelRule::getMinGates)
        );
        List<DashboardOverviewVO.LevelStatItem> levelStats = levels.stream()
                .map(lv -> {
                    long cnt = allUsers.stream()
                            .filter(u -> Objects.equals(resolveLevelId(levels, u.getPassedGateCount()), lv.getId()))
                            .count();
                    return DashboardOverviewVO.LevelStatItem.builder()
                            .levelName(lv.getLevelName())
                            .icon(lv.getIcon())
                            .userCount(cnt)
                            .build();
                })
                .toList();

        List<UserWrongQuestion> wrongs = wrongMapper.selectList(
                new LambdaQueryWrapper<UserWrongQuestion>().eq(UserWrongQuestion::getIsMastered, 0)
        );
        Map<String, List<UserWrongQuestion>> wrongGrouped = wrongs.stream()
                .collect(Collectors.groupingBy(w -> w.getGradeCode() + "|" + w.getChapterName()));
        List<DashboardOverviewVO.TopWrongChapterItem> topWrongs = wrongGrouped.values().stream()
                .map(list -> DashboardOverviewVO.TopWrongChapterItem.builder()
                        .gradeCode(list.get(0).getGradeCode())
                        .chapterName(list.get(0).getChapterName())
                        .wrongCount(list.stream().mapToLong(w -> w.getWrongCount() == null ? 1 : w.getWrongCount()).sum())
                        .build())
                .sorted(Comparator.comparingLong(DashboardOverviewVO.TopWrongChapterItem::getWrongCount).reversed())
                .limit(8)
                .toList();

        return DashboardOverviewVO.builder()
                .userCount(userCount)
                .activeUserCount(activeUserCount)
                .onlineStudentCount(onlineSnap.getOnlineStudentCount())
                .onlineWindowMinutes(onlineSnap.getOnlineWindowMinutes())
                .onlineByGrade(onlineSnap.getGradeDistribution())
                .onlineStudents(onlineSnap.getStudents())
                .chapterCount(chapterCount)
                .gateCount(gateCount)
                .questionCount(questionCount)
                .staticQuestionCount(staticQuestionCount)
                .dynamicQuestionCount(dynamicQuestionCount)
                .totalQuizCount(totalQuizCount)
                .totalWrongCount(totalWrongCount)
                .gradeStats(gradeStats)
                .realmStats(realmStats)
                .levelStats(levelStats)
                .topWrongChapters(topWrongs)
                .build();
    }

    private Long resolveLevelId(List<EduLevelRule> levels, Integer passedGates) {
        int n = passedGates == null ? 0 : passedGates;
        Long current = levels.isEmpty() ? null : levels.get(0).getId();
        for (EduLevelRule lv : levels) {
            if (n >= lv.getMinGates()) {
                current = lv.getId();
            }
        }
        return current;
    }
}
