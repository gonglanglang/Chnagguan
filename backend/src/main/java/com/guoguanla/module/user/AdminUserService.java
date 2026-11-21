package com.guoguanla.module.user;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.security.StpAdminUtil;
import com.guoguanla.common.util.JsonHelper;
import com.guoguanla.module.bank.entity.EduChapter;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.entity.EduGrade;
import com.guoguanla.module.bank.mapper.EduChapterMapper;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.bank.mapper.EduGradeMapper;
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.progress.entity.UserEssayAnswer;
import com.guoguanla.module.progress.entity.UserGateProgress;
import com.guoguanla.module.progress.entity.UserQuizRecord;
import com.guoguanla.module.progress.entity.UserWrongQuestion;
import com.guoguanla.module.progress.mapper.UserEssayAnswerMapper;
import com.guoguanla.module.progress.mapper.UserGateProgressMapper;
import com.guoguanla.module.progress.mapper.UserQuizRecordMapper;
import com.guoguanla.module.progress.mapper.UserWrongQuestionMapper;
import com.guoguanla.module.system.RealmHelperService;
import com.guoguanla.module.system.entity.EduLevelRule;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.system.mapper.EduLevelRuleMapper;
import com.guoguanla.module.user.dto.UserCreateReq;
import com.guoguanla.module.user.dto.UserQueryReq;
import com.guoguanla.module.user.dto.UserUpdateReq;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import com.guoguanla.module.user.vo.UserDetailVO;
import com.guoguanla.module.user.vo.UserPageVO;
import lombok.RequiredArgsConstructor;
import org.mindrot.jbcrypt.BCrypt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminUserService {

    private final AppUserMapper userMapper;
    private final EduGradeMapper gradeMapper;
    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final EduLevelRuleMapper levelRuleMapper;
    private final UserGateProgressMapper gateProgressMapper;
    private final UserQuizRecordMapper quizRecordMapper;
    private final UserWrongQuestionMapper wrongMapper;
    private final UserEssayAnswerMapper essayAnswerMapper;
    private final AliyunOssService ossService;
    private final RealmHelperService realmHelper;
    private final ObjectMapper objectMapper;

    public PageResult<UserPageVO> page(UserQueryReq req) {
        long pageNum = req.getPageNum() == null || req.getPageNum() < 1 ? 1L : req.getPageNum();
        long pageSize = req.getPageSize() == null || req.getPageSize() < 1 ? 10L : Math.min(req.getPageSize(), 100L);

        LambdaQueryWrapper<AppUser> wrapper = new LambdaQueryWrapper<>();
        if (req.getKeyword() != null && !req.getKeyword().isBlank()) {
            String kw = req.getKeyword().trim();
            wrapper.and(w -> w.like(AppUser::getNickname, kw)
                    .or().like(AppUser::getUsername, kw)
                    .or().like(AppUser::getPhone, kw));
        }
        if (req.getRealmCode() != null && !req.getRealmCode().isBlank()) {
            wrapper.eq(AppUser::getRealmCode, req.getRealmCode().trim());
        } else if (req.getGradeCode() != null && !req.getGradeCode().isBlank()) {
            wrapper.eq(AppUser::getGradeCode, req.getGradeCode().trim());
        }
        if (req.getStatus() != null) {
            wrapper.eq(AppUser::getStatus, req.getStatus());
        }
        wrapper.orderByDesc(AppUser::getPassedGateCount).orderByDesc(AppUser::getId);

        Page<AppUser> page = userMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        if (page.getRecords().isEmpty()) {
            return PageResult.of(List.of(), page.getTotal(), pageNum, pageSize);
        }

        Map<String, String> gradeNameMap = gradeMapper.selectList(null).stream()
                .collect(Collectors.toMap(EduGrade::getGradeCode, EduGrade::getGradeName, (a, b) -> a));
        Map<String, EduRealm> realmMap = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getRealmCode, r -> r, (a, b) -> a));
        List<EduLevelRule> levels = levelRuleMapper.selectList(
                new LambdaQueryWrapper<EduLevelRule>().orderByAsc(EduLevelRule::getMinGates)
        );
        List<Long> userIds = page.getRecords().stream().map(AppUser::getId).toList();
        Map<Long, Long> wrongCountMap = wrongMapper.selectList(
                new LambdaQueryWrapper<UserWrongQuestion>()
                        .in(UserWrongQuestion::getUserId, userIds)
                        .eq(UserWrongQuestion::getIsMastered, 0)
        ).stream().collect(Collectors.groupingBy(UserWrongQuestion::getUserId, Collectors.counting()));

        List<UserPageVO> records = page.getRecords().stream()
                .map(u -> toPageVO(u, gradeNameMap, realmMap, levels, wrongCountMap.getOrDefault(u.getId(), 0L)))
                .toList();

        return PageResult.of(records, page.getTotal(), pageNum, pageSize);
    }

    public UserDetailVO detail(Long userId) {
        return detail(userId, "");
    }

    public UserDetailVO detail(Long userId, String baseOrigin) {
        AppUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "学生用户不存在");
        }
        Map<String, String> gradeNameMap = gradeMapper.selectList(null).stream()
                .collect(Collectors.toMap(EduGrade::getGradeCode, EduGrade::getGradeName, (a, b) -> a));
        Map<String, EduRealm> realmMap = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getRealmCode, r -> r, (a, b) -> a));
        List<EduLevelRule> levels = levelRuleMapper.selectList(
                new LambdaQueryWrapper<EduLevelRule>().orderByAsc(EduLevelRule::getMinGates)
        );
        long wrongCount = wrongMapper.selectCount(
                new LambdaQueryWrapper<UserWrongQuestion>()
                        .eq(UserWrongQuestion::getUserId, userId)
                        .eq(UserWrongQuestion::getIsMastered, 0)
        );
        UserPageVO profile = toPageVO(user, gradeNameMap, realmMap, levels, wrongCount);

        Map<Long, EduChapter> chapterMap = chapterMapper.selectList(null).stream()
                .collect(Collectors.toMap(EduChapter::getId, c -> c, (a, b) -> a));
        Map<Long, EduGate> gateMap = gateMapper.selectList(null).stream()
                .collect(Collectors.toMap(EduGate::getId, g -> g, (a, b) -> a));

        List<UserGateProgress> progresses = gateProgressMapper.selectList(
                new LambdaQueryWrapper<UserGateProgress>()
                        .eq(UserGateProgress::getUserId, userId)
                        .eq(UserGateProgress::getIsPassed, 1)
        );
        Map<Long, List<UserGateProgress>> groupedProg = progresses.stream()
                .collect(Collectors.groupingBy(UserGateProgress::getChapterId));
        List<UserDetailVO.ChapterProgressItem> chapterProgress = groupedProg.entrySet().stream()
                .map(entry -> {
                    EduChapter ch = chapterMap.get(entry.getKey());
                    LocalDateTime latest = entry.getValue().stream()
                            .map(UserGateProgress::getLastPlayedAt)
                            .filter(Objects::nonNull)
                            .max(LocalDateTime::compareTo)
                            .orElse(null);
                    return UserDetailVO.ChapterProgressItem.builder()
                            .chapterId(entry.getKey())
                            .gradeCode(ch != null ? ch.getGradeCode() : "")
                            .chapterName(ch != null ? ch.getName() : "未知章节")
                            .passedCount(entry.getValue().size())
                            .totalGates(4)
                            .lastPlayedAt(latest)
                            .build();
                })
                .sorted(Comparator.comparing(UserDetailVO.ChapterProgressItem::getChapterId))
                .toList();

        List<UserWrongQuestion> wrongs = wrongMapper.selectList(
                new LambdaQueryWrapper<UserWrongQuestion>()
                        .eq(UserWrongQuestion::getUserId, userId)
                        .orderByDesc(UserWrongQuestion::getLastWrongAt)
                        .last("LIMIT 30")
        );
        List<UserDetailVO.WrongItem> wrongItems = wrongs.stream()
                .map(w -> {
                    String fmt = (w.getQuestionFormat() == null || w.getQuestionFormat().isBlank())
                            ? "SINGLE_CHOICE" : w.getQuestionFormat();
                    return UserDetailVO.WrongItem.builder()
                            .id(w.getId())
                            .gradeCode(w.getGradeCode())
                            .chapterName(w.getChapterName())
                            .gateName(w.getGateName())
                            .questionFormat(fmt)
                            .stem(w.getStem())
                            .options(parseOptions(w.getOptionsJson()))
                            .answerIndex(parseAnswerIndex(w.getAnswerJson()))
                            .referenceAnswer(parseReferenceAnswer(w.getAnswerJson()))
                            .lastAnswerImageUrl(ossService.resolveViewUrl(w.getLastAnswerImageKey(), baseOrigin))
                            .wrongCount(w.getWrongCount())
                            .isMastered(w.getIsMastered())
                            .lastWrongAt(w.getLastWrongAt())
                            .build();
                })
                .toList();

        List<UserQuizRecord> records = quizRecordMapper.selectList(
                new LambdaQueryWrapper<UserQuizRecord>()
                        .eq(UserQuizRecord::getUserId, userId)
                        .orderByDesc(UserQuizRecord::getStartedAt)
                        .last("LIMIT 20")
        );
        List<UserDetailVO.QuizRecordItem> recordItems = records.stream()
                .map(r -> {
                    EduChapter ch = r.getChapterId() != null ? chapterMap.get(r.getChapterId()) : null;
                    EduGate gt = r.getGateId() != null ? gateMap.get(r.getGateId()) : null;
                    String title = "ADVANCE_EXAM".equals(r.getMode())
                            ? "境界进阶考核"
                            : (ch != null ? ch.getName() : "错题重做");
                    String gateLabel = "ADVANCE_EXAM".equals(r.getMode())
                            ? (realmMap.containsKey(r.getRealmCode()) ? realmMap.get(r.getRealmCode()).getRealmName() : "-")
                            : (gt != null ? gt.getGateName() : "-");
                    return UserDetailVO.QuizRecordItem.builder()
                            .id(r.getId())
                            .sessionNo(r.getSessionNo())
                            .mode(r.getMode())
                            .realmCode(r.getRealmCode())
                            .score(r.getScore())
                            .chapterName(title)
                            .gateName(gateLabel)
                            .totalCount(r.getTotalCount())
                            .correctCount(r.getCorrectCount())
                            .isPassed(r.getIsPassed())
                            .startedAt(r.getStartedAt())
                            .submittedAt(r.getSubmittedAt())
                            .build();
                })
                .toList();

        return UserDetailVO.builder()
                .profile(profile)
                .chapterProgress(chapterProgress)
                .wrongQuestions(wrongItems)
                .recentRecords(recordItems)
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public Long create(UserCreateReq req) {
        long exists = userMapper.selectCount(
                new LambdaQueryWrapper<AppUser>().eq(AppUser::getUsername, req.getUsername().trim())
        );
        if (exists > 0) {
            throw new BizException(ErrorCode.USER_EXISTS);
        }
        EduRealm targetRealm = resolveTargetRealm(req.getRealmCode(), req.getGradeCode());
        AppUser user = new AppUser();
        user.setUsername(req.getUsername().trim());
        user.setPasswordHash(BCrypt.hashpw(req.getPassword(), BCrypt.gensalt()));
        user.setNickname(req.getNickname().trim());
        user.setPhone(req.getPhone() == null || req.getPhone().isBlank() ? null : req.getPhone().trim());
        user.setRealmCode(targetRealm.getRealmCode());
        user.setGradeCode(targetRealm.getGradeCode());
        user.setPassedGateCount(0);
        user.setCurrentLevelId(1L);
        user.setRemark(req.getRemark() == null ? "" : req.getRemark());
        user.setStatus(1);
        user.setLastActiveAt(LocalDateTime.now());
        userMapper.insert(user);
        return user.getId();
    }

    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, UserUpdateReq req) {
        AppUser user = userMapper.selectById(id);
        if (user == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "用户不存在");
        }
        user.setNickname(req.getNickname().trim());
        if ((req.getRealmCode() != null && !req.getRealmCode().isBlank())
                || (req.getGradeCode() != null && !req.getGradeCode().isBlank())) {
            EduRealm targetRealm = resolveTargetRealm(req.getRealmCode(), req.getGradeCode());
            user.setRealmCode(targetRealm.getRealmCode());
            user.setGradeCode(targetRealm.getGradeCode());
        }
        if (req.getPhone() != null) {
            user.setPhone(req.getPhone().isBlank() ? null : req.getPhone().trim());
        }
        if (req.getRemark() != null) {
            user.setRemark(req.getRemark());
        }
        if (req.getStatus() != null) {
            user.setStatus(req.getStatus());
        }
        if (req.getPassword() != null && !req.getPassword().isBlank()) {
            validateAndApplyPassword(user, req.getPassword());
        }
        userMapper.updateById(user);
    }

    @Transactional(rollbackFor = Exception.class)
    public void updatePassword(Long id, String password) {
        AppUser user = userMapper.selectById(id);
        if (user == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "学生用户不存在");
        }
        validateAndApplyPassword(user, password);
        userMapper.updateById(user);
    }

    private void validateAndApplyPassword(AppUser user, String rawPassword) {
        String trimmed = rawPassword == null ? "" : rawPassword.trim();
        if (trimmed.length() < 6 || trimmed.length() > 64) {
            throw new BizException(ErrorCode.BAD_REQUEST, "登录密码长度需在 6~64 位之间");
        }
        user.setPasswordHash(BCrypt.hashpw(trimmed, BCrypt.gensalt()));
    }

    public List<UserDetailVO.QuizSessionItemVO> getQuizRecordDetail(Long userId, String sessionNo, String baseOrigin) {
        UserQuizRecord record = quizRecordMapper.selectOne(
                new LambdaQueryWrapper<UserQuizRecord>()
                        .eq(UserQuizRecord::getSessionNo, sessionNo)
                        .eq(UserQuizRecord::getUserId, userId)
                        .last("LIMIT 1")
        );
        if (record == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "答题记录不存在");
        }
        try {
            JsonNode arr = JsonHelper.readTree(objectMapper, record.getQuestionSnapshotJson());
            List<UserDetailVO.QuizSessionItemVO> items = new ArrayList<>();
            if (arr != null && arr.isArray()) {
                for (JsonNode n : arr) {
                    String fmt = n.path("questionFormat").asText("SINGLE_CHOICE");
                    List<String> opts = new ArrayList<>();
                    if (n.path("options").isArray()) {
                        for (JsonNode op : n.path("options")) {
                            opts.add(op.asText(""));
                        }
                    }
                    int ansIdx = n.path("answerIndex").asInt(0);
                    Integer userIdx = n.hasNonNull("userIndex") ? n.get("userIndex").asInt() : null;
                    Boolean selfCorrect = n.hasNonNull("userSelfCorrect") ? n.get("userSelfCorrect").asBoolean() : null;
                    boolean correct = "ESSAY".equalsIgnoreCase(fmt)
                            ? Boolean.TRUE.equals(selfCorrect)
                            : Objects.equals(ansIdx, userIdx);
                    String imgKey = n.path("userAnswerImageKey").asText("");
                    items.add(UserDetailVO.QuizSessionItemVO.builder()
                            .itemIndex(n.path("itemIndex").asInt(0))
                            .questionFormat(fmt)
                            .stem(n.path("stem").asText(""))
                            .options(opts)
                            .answerIndex(ansIdx)
                            .userIndex(userIdx)
                            .referenceAnswer(n.path("referenceAnswer").asText(""))
                            .userAnswerText(n.path("userAnswerText").asText(""))
                            .userAnswerImageUrl(ossService.resolveViewUrl(imgKey, baseOrigin))
                            .userSelfCorrect(selfCorrect)
                            .correct(correct)
                            .analysis(n.path("analysis").asText(""))
                            .build());
                }
            }
            return items;
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            throw new BizException(ErrorCode.INTERNAL_ERROR, "解析答题明细失败");
        }
    }

    public PageResult<UserDetailVO.EssayAnswerItem> listUserEssayAnswers(Long userId, Long pageNum, Long pageSize, String baseOrigin) {
        long p = pageNum == null || pageNum < 1 ? 1L : pageNum;
        long s = pageSize == null || pageSize < 1 ? 10L : Math.min(pageSize, 50L);
        Page<UserEssayAnswer> page = essayAnswerMapper.selectPage(
                new Page<>(p, s),
                new LambdaQueryWrapper<UserEssayAnswer>()
                        .eq(UserEssayAnswer::getUserId, userId)
                        .orderByDesc(UserEssayAnswer::getCreatedAt)
        );
        List<UserDetailVO.EssayAnswerItem> list = page.getRecords().stream()
                .map(e -> UserDetailVO.EssayAnswerItem.builder()
                        .id(e.getId())
                        .sessionNo(e.getSessionNo())
                        .itemIndex(e.getItemIndex())
                        .userId(e.getUserId())
                        .chapterName(e.getChapterName())
                        .gateName(e.getGateName())
                        .stem(e.getStem())
                        .referenceAnswer(e.getReferenceAnswer())
                        .answerText(e.getAnswerText())
                        .answerImageUrl(ossService.resolveViewUrl(e.getAnswerImageKey(), baseOrigin))
                        .selfCorrect(e.getSelfCorrect())
                        .teacherStatus(e.getTeacherStatus())
                        .teacherComment(e.getTeacherComment())
                        .createdAt(e.getCreatedAt())
                        .reviewedAt(e.getReviewedAt())
                        .build())
                .toList();
        return PageResult.of(list, page.getTotal(), p, s);
    }

    @Transactional(rollbackFor = Exception.class)
    public void reviewEssayAnswer(Long essayId, Integer teacherStatus, String teacherComment) {
        UserEssayAnswer ans = essayAnswerMapper.selectById(essayId);
        if (ans == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "解答题作答记录不存在");
        }
        int status = (teacherStatus == null || (teacherStatus != 1 && teacherStatus != 2)) ? 1 : teacherStatus;
        ans.setTeacherStatus(status);
        ans.setTeacherComment(teacherComment == null ? "" : teacherComment.trim());
        try {
            if (StpAdminUtil.isLogin()) {
                ans.setReviewedBy(StpAdminUtil.getLoginIdAsLong());
            }
        } catch (Exception ignored) {
        }
        ans.setReviewedAt(LocalDateTime.now());
        essayAnswerMapper.updateById(ans);
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateRealm(Long id, String realmCode) {
        AppUser user = userMapper.selectById(id);
        if (user == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "学生用户不存在");
        }
        EduRealm targetRealm = realmHelper.findByRealmCode(realmCode);
        if (targetRealm == null) {
            throw new BizException(ErrorCode.BAD_REQUEST, "无效的境界编码: " + realmCode);
        }
        user.setRealmCode(targetRealm.getRealmCode());
        user.setGradeCode(targetRealm.getGradeCode());
        userMapper.updateById(user);
    }

    public void updateStatus(Long id, Integer status) {
        AppUser user = userMapper.selectById(id);
        if (user == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "用户不存在");
        }
        user.setStatus(status);
        userMapper.updateById(user);
    }

    public void delete(Long id) {
        userMapper.deleteById(id);
    }

    private EduRealm resolveTargetRealm(String realmCode, String gradeCode) {
        EduRealm r = realmHelper.findByRealmCode(realmCode);
        if (r != null) return r;
        r = realmHelper.findByGradeCode(gradeCode);
        if (r != null) return r;
        return realmHelper.resolveUserRealm(null);
    }

    private UserPageVO toPageVO(AppUser u, Map<String, String> gradeMap,
                                Map<String, EduRealm> realmMap,
                                List<EduLevelRule> levels, long wrongCount) {
        EduLevelRule lv = resolveLevel(levels, u.getPassedGateCount());
        EduRealm realm = realmMap.getOrDefault(u.getRealmCode(), realmHelper.resolveUserRealm(u));
        return UserPageVO.builder()
                .id(u.getId())
                .username(u.getUsername())
                .nickname(u.getNickname())
                .phoneMasked(maskPhone(u.getPhone()))
                .wxOpenidMasked(maskOpenId(u.getWxOpenid()))
                .avatarUrl(u.getAvatarUrl())
                .gradeCode(u.getGradeCode())
                .gradeName(gradeMap.getOrDefault(u.getGradeCode(), u.getGradeCode()))
                .realmCode(realm.getRealmCode())
                .realmName(realm.getRealmName())
                .realmOrder(realm.getRealmOrder())
                .passedGateCount(u.getPassedGateCount() == null ? 0 : u.getPassedGateCount())
                .levelIcon(lv != null ? lv.getIcon() : "")
                .levelName(realm.getRealmName())
                .wrongCount(wrongCount)
                .status(u.getStatus())
                .remark(u.getRemark())
                .lastActiveAt(u.getLastActiveAt())
                .createdAt(u.getCreatedAt())
                .build();
    }

    private EduLevelRule resolveLevel(List<EduLevelRule> levels, Integer passedGates) {
        int n = passedGates == null ? 0 : passedGates;
        EduLevelRule cur = levels.isEmpty() ? null : levels.get(0);
        for (EduLevelRule lv : levels) {
            if (n >= lv.getMinGates()) {
                cur = lv;
            }
        }
        return cur;
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) return phone == null ? "" : phone;
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }

    private String maskOpenId(String openId) {
        if (openId == null || openId.length() <= 8) return openId == null ? "" : openId;
        return openId.substring(0, 4) + "****" + openId.substring(openId.length() - 4);
    }

    private List<String> parseOptions(String json) {
        return JsonHelper.readStringList(objectMapper, json);
    }

    private Integer parseAnswerIndex(String json) {
        try {
            JsonNode node = JsonHelper.readTree(objectMapper, json);
            return node != null ? node.path("index").asInt(0) : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    private String parseReferenceAnswer(String json) {
        try {
            JsonNode node = JsonHelper.readTree(objectMapper, json);
            return node != null ? node.path("text").asText("") : "";
        } catch (Exception e) {
            return "";
        }
    }
}
