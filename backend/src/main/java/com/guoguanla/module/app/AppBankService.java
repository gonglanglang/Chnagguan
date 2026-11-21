package com.guoguanla.module.app;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.security.StpAppUtil;
import com.guoguanla.module.app.dto.AppLoginReq;
import com.guoguanla.module.app.vo.AppUserProfileVO;
import com.guoguanla.module.bank.entity.EduChapter;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.entity.EduGrade;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduChapterMapper;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.bank.mapper.EduGradeMapper;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.progress.entity.UserGateProgress;
import com.guoguanla.module.progress.mapper.UserGateProgressMapper;
import com.guoguanla.module.system.RealmHelperService;
import com.guoguanla.module.system.entity.EduLevelRule;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.mapper.EduLevelRuleMapper;
import com.guoguanla.module.system.mapper.SysConfigMapper;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AppBankService {

    private final AppUserMapper userMapper;
    private final EduGradeMapper gradeMapper;
    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final EduQuestionMapper questionMapper;
    private final EduLevelRuleMapper levelRuleMapper;
    private final UserGateProgressMapper gateProgressMapper;
    private final SysConfigMapper sysConfigMapper;
    private final RealmHelperService realmHelper;
    private final AliyunOssService ossService;

    public AppUserProfileVO.HomeSummaryVO homeSummary(Set<Long> guestPassedGateIds) {
        boolean guestEnabled = isGuestModeEnabled();
        String notice = getConfig("app_notice", "修仙闯关开启：练气至化神六大境界，学成可挑战进阶考核！");

        Long userId = StpAppUtil.getLoginIdOrNull();
        AppUser currentUser = null;
        AppUserProfileVO profile = null;
        if (userId != null) {
            AppUser user = userMapper.selectById(userId);
            if (user != null && user.getStatus() == 1) {
                currentUser = user;
                profile = buildProfileVO(user);
            }
        }

        List<EduGrade> grades = gradeMapper.selectList(
                new LambdaQueryWrapper<EduGrade>()
                        .eq(EduGrade::getEnabled, 1)
                        .orderByAsc(EduGrade::getSortOrder)
        );
        Map<String, Long> chapCounts = chapterMapper.selectList(
                new LambdaQueryWrapper<EduChapter>().eq(EduChapter::getEnabled, 1)
        ).stream().collect(Collectors.groupingBy(EduChapter::getGradeCode, Collectors.counting()));

        List<AppUserProfileVO.GradeItemVO> gradeItems = grades.stream()
                .map(g -> AppUserProfileVO.GradeItemVO.builder()
                        .gradeCode(g.getGradeCode())
                        .gradeName(g.getGradeName())
                        .icon(g.getIcon())
                        .chapterCount(chapCounts.getOrDefault(g.getGradeCode(), 0L))
                        .build())
                .toList();

        List<AppUserProfileVO.RealmItemVO> realms = listRealmsInternal(currentUser, guestPassedGateIds);

        return AppUserProfileVO.HomeSummaryVO.builder()
                .guestModeEnabled(guestEnabled)
                .appNotice(notice)
                .profile(profile)
                .grades(gradeItems)
                .realms(realms)
                .build();
    }

    public List<AppUserProfileVO.RealmItemVO> listRealms(Set<Long> guestPassedGateIds) {
        Long userId = StpAppUtil.getLoginIdOrNull();
        AppUser user = userId != null ? userMapper.selectById(userId) : null;
        return listRealmsInternal(user, guestPassedGateIds);
    }

    private List<AppUserProfileVO.RealmItemVO> listRealmsInternal(AppUser currentUser, Set<Long> guestPassedGateIds) {
        EduRealm userRealm = realmHelper.resolveUserRealm(currentUser);
        Set<Long> passedGateIds = resolvePassedGateIds(guestPassedGateIds);
        List<EduRealm> realms = realmHelper.listOrderedRealms();

        List<EduChapter> allChapters = chapterMapper.selectList(
                new LambdaQueryWrapper<EduChapter>().eq(EduChapter::getEnabled, 1)
        );
        Map<String, List<EduChapter>> chapByGrade = allChapters.stream()
                .collect(Collectors.groupingBy(EduChapter::getGradeCode));
        Map<Long, List<EduGate>> gateByChap = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>().eq(EduGate::getEnabled, 1)
        ).stream().collect(Collectors.groupingBy(EduGate::getChapterId));

        return realms.stream().map(r -> {
            List<EduChapter> chaps = chapByGrade.getOrDefault(r.getGradeCode(), List.of());
            List<EduGate> gates = chaps.stream()
                    .flatMap(ch -> gateByChap.getOrDefault(ch.getId(), List.of()).stream())
                    .toList();
            long passedInRealm = gates.stream().filter(g -> passedGateIds.contains(g.getId())).count();
            int totalGates = gates.size();
            int unlockCfg = r.getUnlockGates() == null ? 0 : r.getUnlockGates();
            int required = unlockCfg > 0 ? Math.min(unlockCfg, totalGates) : totalGates;
            int remaining = Math.max(0, required - (int) passedInRealm);
            boolean hasNext = realmHelper.findNextRealm(r.getRealmOrder()) != null;
            boolean isCurrent = Objects.equals(r.getRealmCode(), userRealm.getRealmCode());
            boolean examEligible = currentUser != null && isCurrent && hasNext && totalGates > 0 && passedInRealm >= required;

            return AppUserProfileVO.RealmItemVO.builder()
                    .realmCode(r.getRealmCode())
                    .realmName(r.getRealmName())
                    .realmOrder(r.getRealmOrder())
                    .gradeCode(r.getGradeCode())
                    .difficultyLabel(r.getDifficultyLabel())
                    .description(r.getDescription())
                    .unlockGates(r.getUnlockGates())
                    .examQuestionCount(r.getExamQuestionCount())
                    .examPassScore(r.getExamPassScore())
                    .chapterCount(chaps.size())
                    .gateCount(totalGates)
                    .passedGateCount(passedInRealm)
                    .unlocked(r.getRealmOrder() <= userRealm.getRealmOrder())
                    .isCurrent(isCurrent)
                    .isLower(r.getRealmOrder() < userRealm.getRealmOrder())
                    .isHigher(r.getRealmOrder() > userRealm.getRealmOrder())
                    .examEligible(examEligible)
                    .examRemainingGates(remaining)
                    .build();
        }).toList();
    }

    public List<AppUserProfileVO.ChapterCardVO> listChaptersByRealm(String realmCode, Set<Long> guestPassedGateIds) {
        EduRealm targetRealm = realmHelper.findByRealmCode(realmCode);
        if (targetRealm == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "境界不存在");
        }
        return listChaptersByGrade(targetRealm.getGradeCode(), guestPassedGateIds);
    }

    public List<AppUserProfileVO.ChapterCardVO> listChaptersByGrade(String gradeCode, Set<Long> guestPassedGateIds) {
        EduRealm targetRealm = realmHelper.findByGradeCode(gradeCode);
        EduRealm userRealm = currentUserRealm();
        boolean lockedByRealm = targetRealm != null && targetRealm.getRealmOrder() > userRealm.getRealmOrder();
        boolean suppressed = targetRealm != null && targetRealm.getRealmOrder() < userRealm.getRealmOrder();

        List<EduChapter> chapters = chapterMapper.selectList(
                new LambdaQueryWrapper<EduChapter>()
                        .eq(EduChapter::getGradeCode, gradeCode)
                        .eq(EduChapter::getEnabled, 1)
                        .orderByAsc(EduChapter::getSortOrder)
                        .orderByAsc(EduChapter::getId)
        );
        if (chapters.isEmpty()) {
            return List.of();
        }
        List<Long> chapIds = chapters.stream().map(EduChapter::getId).toList();
        List<EduGate> allGates = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .in(EduGate::getChapterId, chapIds)
                        .eq(EduGate::getEnabled, 1)
        );
        Map<Long, List<EduGate>> gatesByChap = allGates.stream()
                .collect(Collectors.groupingBy(EduGate::getChapterId));

        Set<Long> passedGateIds = resolvePassedGateIds(guestPassedGateIds);
        return chapters.stream()
                .map(ch -> {
                    List<EduGate> chGates = gatesByChap.getOrDefault(ch.getId(), List.of());
                    int passed = (int) chGates.stream().filter(gt -> passedGateIds.contains(gt.getId())).count();
                    return AppUserProfileVO.ChapterCardVO.builder()
                            .id(ch.getId())
                            .chapterCode(ch.getChapterCode())
                            .gradeCode(ch.getGradeCode())
                            .realmCode(targetRealm != null ? targetRealm.getRealmCode() : "")
                            .realmName(targetRealm != null ? targetRealm.getRealmName() : "")
                            .realmOrder(targetRealm != null ? targetRealm.getRealmOrder() : 1)
                            .name(ch.getName())
                            .description(ch.getDescription())
                            .isCustom(ch.getIsCustom())
                            .passedCount(passed)
                            .totalGates(chGates.size())
                            .lockedByRealm(lockedByRealm)
                            .suppressed(suppressed)
                            .build();
                })
                .toList();
    }

    public List<AppUserProfileVO.GateCardVO> listGatesByChapter(Long chapterId, Set<Long> guestPassedGateIds) {
        EduChapter chapter = chapterMapper.selectById(chapterId);
        if (chapter == null || chapter.getEnabled() == 0) {
            throw new BizException(ErrorCode.NOT_FOUND, "章节不存在或已下架");
        }
        EduRealm targetRealm = realmHelper.findByGradeCode(chapter.getGradeCode());
        EduRealm userRealm = currentUserRealm();
        boolean lockedByRealm = targetRealm != null && targetRealm.getRealmOrder() > userRealm.getRealmOrder();
        boolean suppressed = targetRealm != null && targetRealm.getRealmOrder() < userRealm.getRealmOrder();

        List<EduGate> gates = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .eq(EduGate::getChapterId, chapterId)
                        .eq(EduGate::getEnabled, 1)
                        .orderByAsc(EduGate::getGateIndex)
        );
        if (gates.isEmpty()) {
            return List.of();
        }
        List<Long> gateIds = gates.stream().map(EduGate::getId).toList();
        Map<Long, Long> qCounts = questionMapper.selectList(
                new LambdaQueryWrapper<EduQuestion>()
                        .in(EduQuestion::getGateId, gateIds)
                        .eq(EduQuestion::getEnabled, 1)
        ).stream().collect(Collectors.groupingBy(EduQuestion::getGateId, Collectors.counting()));

        Set<Long> passedGateIds = resolvePassedGateIds(guestPassedGateIds);
        List<AppUserProfileVO.GateCardVO> result = new ArrayList<>();
        boolean prevPassed = true;
        for (EduGate gt : gates) {
            boolean passed = passedGateIds.contains(gt.getId());
            boolean locked = lockedByRealm || (gt.getGateIndex() > 0 && !prevPassed);
            boolean empty = qCounts.getOrDefault(gt.getId(), 0L) == 0;
            result.add(AppUserProfileVO.GateCardVO.builder()
                    .id(gt.getId())
                    .chapterId(gt.getChapterId())
                    .gateIndex(gt.getGateIndex())
                    .gateName(gt.getGateName())
                    .star(gt.getStar())
                    .questionCount(gt.getQuestionCount())
                    .passCount(gt.getPassCount())
                    .passed(passed)
                    .locked(locked)
                    .lockedByRealm(lockedByRealm)
                    .suppressed(suppressed)
                    .empty(empty)
                    .build());
            prevPassed = passed;
        }
        return result;
    }

    public List<AppUserProfileVO.LevelItemVO> listLevels(Integer guestPassedCount) {
        int passed = guestPassedCount == null ? 0 : guestPassedCount;
        Long userId = StpAppUtil.getLoginIdOrNull();
        if (userId != null) {
            AppUser user = userMapper.selectById(userId);
            if (user != null && user.getPassedGateCount() != null) {
                passed = user.getPassedGateCount();
            }
        }
        final int finalPassed = passed;
        return levelRuleMapper.selectList(
                        new LambdaQueryWrapper<EduLevelRule>().orderByAsc(EduLevelRule::getMinGates)
                ).stream()
                .map(lv -> AppUserProfileVO.LevelItemVO.builder()
                        .id(lv.getId())
                        .minGates(lv.getMinGates())
                        .icon(lv.getIcon())
                        .levelName(lv.getLevelName())
                        .quote(lv.getQuote())
                        .unlocked(finalPassed >= lv.getMinGates())
                        .build())
                .toList();
    }

    public AppUserProfileVO currentProfile() {
        return currentProfile("");
    }

    public AppUserProfileVO currentProfile(String baseOrigin) {
        Long userId = StpAppUtil.getLoginIdAsLong();
        AppUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED);
        }
        return buildProfileVO(user, baseOrigin);
    }

    public AppUserProfileVO updateProfile(AppLoginReq.ProfileUpdateReq req) {
        return updateProfile(req, "");
    }

    public AppUserProfileVO updateProfile(AppLoginReq.ProfileUpdateReq req, String baseOrigin) {
        Long userId = StpAppUtil.getLoginIdAsLong();
        AppUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED);
        }
        user.setNickname(req.getNickname().trim());
        if (req.getAvatarUrl() != null && !req.getAvatarUrl().isBlank()) {
            user.setAvatarUrl(req.getAvatarUrl().trim());
        }
        userMapper.updateById(user);
        return buildProfileVO(user, baseOrigin);
    }

    public AppUserProfileVO uploadAvatar(MultipartFile file, String baseOrigin) {
        Long userId = StpAppUtil.getLoginIdAsLong();
        AppUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED);
        }
        AliyunOssService.UploadResult res = ossService.uploadUserAvatar(file, userId, baseOrigin);
        user.setAvatarUrl(res.objectKey());
        userMapper.updateById(user);
        return buildProfileVO(user, baseOrigin);
    }

    public List<AppUserProfileVO.ChapterCardVO> listUserChapterRecords() {
        Long userId = StpAppUtil.getLoginIdAsLong();
        List<UserGateProgress> passedList = gateProgressMapper.selectList(
                new LambdaQueryWrapper<UserGateProgress>()
                        .eq(UserGateProgress::getUserId, userId)
                        .eq(UserGateProgress::getIsPassed, 1)
        );
        if (passedList.isEmpty()) {
            return List.of();
        }
        Map<String, EduRealm> realmByGrade = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getGradeCode, r -> r, (a, b) -> a));
        Map<Long, Long> passedMap = passedList.stream()
                .collect(Collectors.groupingBy(UserGateProgress::getChapterId, Collectors.counting()));
        List<EduChapter> chapters = chapterMapper.selectBatchIds(passedMap.keySet());
        return chapters.stream()
                .sorted(Comparator.comparing(EduChapter::getSortOrder))
                .map(ch -> {
                    EduRealm r = realmByGrade.get(ch.getGradeCode());
                    return AppUserProfileVO.ChapterCardVO.builder()
                            .id(ch.getId())
                            .chapterCode(ch.getChapterCode())
                            .gradeCode(ch.getGradeCode())
                            .realmCode(r != null ? r.getRealmCode() : "")
                            .realmName(r != null ? r.getRealmName() : "")
                            .realmOrder(r != null ? r.getRealmOrder() : 1)
                            .name(ch.getName())
                            .description(ch.getDescription())
                            .isCustom(ch.getIsCustom())
                            .passedCount(passedMap.getOrDefault(ch.getId(), 0L).intValue())
                            .totalGates(4)
                            .build();
                })
                .toList();
    }

    public AppUserProfileVO buildProfileVO(AppUser user) {
        return buildProfileVO(user, "");
    }

    public AppUserProfileVO buildProfileVO(AppUser user, String baseOrigin) {
        int n = user.getPassedGateCount() == null ? 0 : user.getPassedGateCount();
        EduRealm realm = realmHelper.resolveUserRealm(user);
        EduRealm nextRealm = realmHelper.findNextRealm(realm.getRealmOrder());
        RealmHelperService.ExamProgress examProg = realmHelper.computeExamProgress(user.getId(), realm, null);

        EduGrade grade = gradeMapper.selectOne(
                new LambdaQueryWrapper<EduGrade>().eq(EduGrade::getGradeCode, user.getGradeCode()).last("LIMIT 1")
        );
        AppUserProfileVO.LevelProgress levelProgress = computeLevelProgress(n);
        return AppUserProfileVO.builder()
                .id(user.getId())
                .username(user.getUsername())
                .nickname(user.getNickname())
                .avatarUrl(ossService.resolveViewUrl(user.getAvatarUrl(), baseOrigin))
                .gradeCode(user.getGradeCode())
                .gradeName(grade != null ? grade.getGradeName() : user.getGradeCode())
                .realmCode(realm.getRealmCode())
                .realmName(realm.getRealmName())
                .realmOrder(realm.getRealmOrder())
                .difficultyLabel(realm.getDifficultyLabel())
                .nextRealmCode(nextRealm != null ? nextRealm.getRealmCode() : null)
                .nextRealmName(nextRealm != null ? nextRealm.getRealmName() : null)
                .realmPassedGates(examProg.getPassedRealmGates())
                .realmTotalGates(examProg.getTotalRealmGates())
                .examUnlockGates(examProg.getRequiredGates())
                .examRemainingGates(examProg.getRemainingGates())
                .examEligible(examProg.isExamEligible())
                .examQuestionCount(realm.getExamQuestionCount())
                .examPassScore(realm.getExamPassScore())
                .passedGateCount(n)
                .level(levelProgress)
                .build();
    }

    public EduRealm currentUserRealm() {
        Long userId = StpAppUtil.getLoginIdOrNull();
        AppUser user = userId != null ? userMapper.selectById(userId) : null;
        return realmHelper.resolveUserRealm(user);
    }

    public AppUserProfileVO.LevelProgress computeLevelProgress(int passedGates) {
        List<EduLevelRule> rules = levelRuleMapper.selectList(
                new LambdaQueryWrapper<EduLevelRule>().orderByAsc(EduLevelRule::getMinGates)
        );
        if (rules.isEmpty()) {
            return AppUserProfileVO.LevelProgress.builder()
                    .icon("").levelName("练气").quote("").minGates(0).build();
        }
        EduLevelRule current = rules.get(0);
        EduLevelRule next = null;
        for (EduLevelRule r : rules) {
            if (passedGates >= r.getMinGates()) {
                current = r;
            } else {
                next = r;
                break;
            }
        }
        return AppUserProfileVO.LevelProgress.builder()
                .levelId(current.getId())
                .icon(current.getIcon())
                .levelName(current.getLevelName())
                .quote(current.getQuote())
                .minGates(current.getMinGates())
                .nextMinGates(next != null ? next.getMinGates() : null)
                .nextIcon(next != null ? next.getIcon() : null)
                .nextLevelName(next != null ? next.getLevelName() : null)
                .build();
    }

    public Long resolveLevelId(int passedGates) {
        return computeLevelProgress(passedGates).getLevelId();
    }

    public boolean isGuestModeEnabled() {
        return "true".equalsIgnoreCase(getConfig("guest_mode_enabled", "true"));
    }

    private String getConfig(String key, String defaultVal) {
        SysConfig cfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, key).last("LIMIT 1")
        );
        return cfg != null && cfg.getConfigValue() != null ? cfg.getConfigValue() : defaultVal;
    }

    public Set<Long> resolvePassedGateIds(Set<Long> guestPassedGateIds) {
        Long userId = StpAppUtil.getLoginIdOrNull();
        if (userId != null) {
            return gateProgressMapper.selectList(
                            new LambdaQueryWrapper<UserGateProgress>()
                                    .eq(UserGateProgress::getUserId, userId)
                                    .eq(UserGateProgress::getIsPassed, 1)
                    ).stream()
                    .map(UserGateProgress::getGateId)
                    .collect(Collectors.toSet());
        }
        return guestPassedGateIds == null ? Set.of() : guestPassedGateIds;
    }
}
