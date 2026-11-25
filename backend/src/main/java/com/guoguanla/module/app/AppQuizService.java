package com.guoguanla.module.app;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.security.StpAppUtil;
import com.guoguanla.common.util.JsonHelper;
import com.guoguanla.module.app.dto.AppQuizDTO;
import com.guoguanla.module.app.vo.AppQuizVO;
import com.guoguanla.module.app.vo.AppUserProfileVO;
import com.guoguanla.module.bank.entity.EduChapter;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduChapterMapper;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import com.guoguanla.module.engine.GeneratedQuestion;
import com.guoguanla.module.engine.QuestionEngineService;
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
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AppQuizService {

    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final EduQuestionMapper questionMapper;
    private final UserGateProgressMapper gateProgressMapper;
    private final UserQuizRecordMapper quizRecordMapper;
    private final UserWrongQuestionMapper wrongMapper;
    private final UserEssayAnswerMapper essayAnswerMapper;
    private final AppUserMapper userMapper;
    private final QuestionEngineService engineService;
    private final AliyunOssService ossService;
    private final AppBankService bankService;
    private final RealmHelperService realmHelper;
    private final ObjectMapper objectMapper;

    @Data
    public static class SnapshotItem {
        private Integer itemIndex;
        private Long questionId;
        private Long chapterId;
        private String gradeCode;
        private Long wrongId;
        private String questionFormat;
        private String stem;
        private List<String> options;
        private Integer answerIndex;
        private String referenceAnswer;
        private String analysis;
        private Map<String, Object> diagram;
        private String imageKey;
        private Integer userIndex;
        private String userAnswerText;
        private String userAnswerImageKey;
        private Boolean userSelfCorrect;
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.StartVO startGateQuiz(AppQuizDTO.StartReq req) {
        return startGateQuiz(req, "");
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.StartVO startGateQuiz(AppQuizDTO.StartReq req, String baseOrigin) {
        Long userId = StpAppUtil.getLoginIdOrNull();
        boolean guestMode = userId == null;
        if (guestMode && !bankService.isGuestModeEnabled()) {
            throw new BizException(ErrorCode.GUEST_MODE_DISABLED);
        }

        EduGate gate = gateMapper.selectById(req.getGateId());
        if (gate == null || gate.getEnabled() == 0) {
            throw new BizException(ErrorCode.NOT_FOUND, "关卡不存在或已禁用");
        }
        EduChapter chapter = chapterMapper.selectById(gate.getChapterId());
        if (chapter == null || chapter.getEnabled() == 0) {
            throw new BizException(ErrorCode.NOT_FOUND, "所属章节不存在或已下架");
        }

        AppUser user = userId != null ? userMapper.selectById(userId) : null;
        EduRealm userRealm = realmHelper.resolveUserRealm(user);
        EduRealm targetRealm = realmHelper.findByGradeCode(chapter.getGradeCode());
        boolean suppressedMode = targetRealm != null && targetRealm.getRealmOrder() < userRealm.getRealmOrder();

        Set<Long> guestPassed = req.getGuestPassedGateIds() == null
                ? Set.of()
                : new HashSet<>(req.getGuestPassedGateIds());
        Set<Long> passedGateIds = bankService.resolvePassedGateIds(guestPassed);

        // 校验上一关解锁状态
        if (gate.getGateIndex() > 0) {
            EduGate prevGate = gateMapper.selectOne(
                    new LambdaQueryWrapper<EduGate>()
                            .eq(EduGate::getChapterId, gate.getChapterId())
                            .eq(EduGate::getGateIndex, gate.getGateIndex() - 1)
                            .last("LIMIT 1")
            );
            if (prevGate != null && !passedGateIds.contains(prevGate.getId())) {
                throw new BizException(ErrorCode.GATE_LOCKED);
            }
        }

        List<EduQuestion> pool = questionMapper.selectList(
                new LambdaQueryWrapper<EduQuestion>()
                        .eq(EduQuestion::getGateId, gate.getId())
                        .eq(EduQuestion::getEnabled, 1)
                        .orderByAsc(EduQuestion::getSortOrder)
                        .orderByAsc(EduQuestion::getId)
        );
        if (pool.isEmpty()) {
            throw new BizException(ErrorCode.GATE_EMPTY);
        }

        // 优先纳入管理后台人工录入/导入的题目，防止自定义新题被固定抽题数截断遗漏
        List<EduQuestion> adminPool = new ArrayList<>();
        List<EduQuestion> builtInPool = new ArrayList<>();
        for (EduQuestion q : pool) {
            if ("ADMIN".equalsIgnoreCase(q.getSource()) || "IMPORT".equalsIgnoreCase(q.getSource())) {
                adminPool.add(q);
            } else {
                builtInPool.add(q);
            }
        }
        Collections.shuffle(adminPool);
        Collections.shuffle(builtInPool);
        List<EduQuestion> combined = new ArrayList<>(pool.size());
        combined.addAll(adminPool);
        combined.addAll(builtInPool);

        int takeCount = Math.min(gate.getQuestionCount(), combined.size());
        List<EduQuestion> picked = new ArrayList<>(combined.subList(0, takeCount));
        Collections.shuffle(picked);

        List<SnapshotItem> snapshots = new ArrayList<>(takeCount);
        List<AppQuizVO.ClientQuestionItem> clientItems = new ArrayList<>(takeCount);

        for (int i = 0; i < picked.size(); i++) {
            EduQuestion q = picked.get(i);
            GeneratedQuestion gen = engineService.generateOne(q);
            SnapshotItem snap = toSnapshot(i, q, gen);
            snapshots.add(snap);

            clientItems.add(AppQuizVO.ClientQuestionItem.builder()
                    .itemIndex(i)
                    .questionFormat(snap.getQuestionFormat())
                    .stem(gen.getStem())
                    .options(gen.getOptions())
                    .diagram(gen.getDiagram())
                    .imageUrl(ossService.resolveViewUrl(gen.getImageKey(), baseOrigin))
                    .build());
        }

        String sessionNo = "QZ" + UUID.randomUUID().toString().replace("-", "").substring(0, 16).toUpperCase();
        UserQuizRecord record = new UserQuizRecord();
        record.setSessionNo(sessionNo);
        record.setUserId(guestMode ? 0L : userId);
        record.setMode("GATE");
        record.setRealmCode(targetRealm != null ? targetRealm.getRealmCode() : null);
        record.setChapterId(chapter.getId());
        record.setGateId(gate.getId());
        record.setQuestionSnapshotJson(writeJson(snapshots));
        record.setTotalCount(clientItems.size());
        record.setCorrectCount(0);
        record.setIsPassed(0);
        record.setStatus(0);
        record.setStartedAt(LocalDateTime.now());
        quizRecordMapper.insert(record);

        return AppQuizVO.StartVO.builder()
                .sessionNo(sessionNo)
                .mode("GATE")
                .realmCode(targetRealm != null ? targetRealm.getRealmCode() : null)
                .realmName(targetRealm != null ? targetRealm.getRealmName() : null)
                .realmOrder(targetRealm != null ? targetRealm.getRealmOrder() : null)
                .suppressedMode(suppressedMode)
                .chapterId(chapter.getId())
                .chapterName(chapter.getName())
                .gateId(gate.getId())
                .gateName(gate.getGateName())
                .star(gate.getStar())
                .passCount(Math.min(gate.getPassCount(), clientItems.size()))
                .totalCount(clientItems.size())
                .guestMode(guestMode)
                .items(clientItems)
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.StartVO startAdvanceExam() {
        return startAdvanceExam("");
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.StartVO startAdvanceExam(String baseOrigin) {
        Long userId = StpAppUtil.getLoginIdAsLong();
        AppUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED);
        }
        EduRealm currentRealm = realmHelper.resolveUserRealm(user);
        EduRealm nextRealm = realmHelper.findNextRealm(currentRealm.getRealmOrder());
        if (nextRealm == null) {
            throw new BizException(ErrorCode.REALM_MAX_REACHED);
        }

        RealmHelperService.ExamProgress examProg = realmHelper.computeExamProgress(userId, currentRealm, null);
        if (!examProg.isExamEligible()) {
            throw new BizException(
                    ErrorCode.REALM_EXAM_LOCKED,
                    "尚未完成「" + currentRealm.getRealmName() + "」要求关卡（还差 " + examProg.getRemainingGates() + " 关）"
            );
        }

        List<EduQuestion> pool = questionMapper.selectList(
                new LambdaQueryWrapper<EduQuestion>()
                        .eq(EduQuestion::getGradeCode, currentRealm.getGradeCode())
                        .eq(EduQuestion::getEnabled, 1)
        );
        if (pool.isEmpty()) {
            throw new BizException(ErrorCode.REALM_EXAM_EMPTY);
        }

        List<EduQuestion> shuffled = new ArrayList<>(pool);
        Collections.shuffle(shuffled);
        int requested = currentRealm.getExamQuestionCount() == null ? 5 : currentRealm.getExamQuestionCount();
        int takeCount = Math.max(1, Math.min(requested, shuffled.size()));
        List<EduQuestion> picked = shuffled.subList(0, takeCount);

        List<SnapshotItem> snapshots = new ArrayList<>(takeCount);
        List<AppQuizVO.ClientQuestionItem> clientItems = new ArrayList<>(takeCount);
        for (int i = 0; i < picked.size(); i++) {
            EduQuestion q = picked.get(i);
            GeneratedQuestion gen = engineService.generateOne(q);
            SnapshotItem snap = toSnapshot(i, q, gen);
            snapshots.add(snap);
            clientItems.add(AppQuizVO.ClientQuestionItem.builder()
                    .itemIndex(i)
                    .questionFormat(snap.getQuestionFormat())
                    .stem(gen.getStem())
                    .options(gen.getOptions())
                    .diagram(gen.getDiagram())
                    .imageUrl(ossService.resolveViewUrl(gen.getImageKey(), baseOrigin))
                    .build());
        }

        String sessionNo = "EX" + UUID.randomUUID().toString().replace("-", "").substring(0, 16).toUpperCase();
        UserQuizRecord record = new UserQuizRecord();
        record.setSessionNo(sessionNo);
        record.setUserId(userId);
        record.setMode("ADVANCE_EXAM");
        record.setRealmCode(currentRealm.getRealmCode());
        record.setQuestionSnapshotJson(writeJson(snapshots));
        record.setTotalCount(clientItems.size());
        record.setCorrectCount(0);
        record.setScore(0);
        record.setIsPassed(0);
        record.setStatus(0);
        record.setStartedAt(LocalDateTime.now());
        quizRecordMapper.insert(record);

        int passScore = currentRealm.getExamPassScore() == null ? 60 : currentRealm.getExamPassScore();
        return AppQuizVO.StartVO.builder()
                .sessionNo(sessionNo)
                .mode("ADVANCE_EXAM")
                .realmCode(currentRealm.getRealmCode())
                .realmName(currentRealm.getRealmName())
                .realmOrder(currentRealm.getRealmOrder())
                .suppressedMode(false)
                .passScore(passScore)
                .chapterName(currentRealm.getRealmName() + " · 进阶考核")
                .gateName("突破至「" + nextRealm.getRealmName() + "」")
                .star(5)
                .passCount((int) Math.ceil(clientItems.size() * passScore / 100.0))
                .totalCount(clientItems.size())
                .guestMode(false)
                .items(clientItems)
                .build();
    }

    public AppQuizVO.UploadAnswerImageVO uploadEssayImage(String sessionNo, Integer itemIndex, MultipartFile file, String baseOrigin) {
        UserQuizRecord record = loadAuthorizedSession(sessionNo);
        AliyunOssService.UploadResult res = ossService.uploadEssayAnswerImage(
                file, record.getUserId(), record.getSessionNo(), itemIndex, baseOrigin
        );
        return AppQuizVO.UploadAnswerImageVO.builder()
                .objectKey(res.objectKey())
                .previewUrl(res.previewUrl())
                .storageType(res.storageType())
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.CheckItemVO checkItem(AppQuizDTO.CheckItemReq req) {
        return checkItem(req, "");
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.CheckItemVO checkItem(AppQuizDTO.CheckItemReq req, String baseOrigin) {
        UserQuizRecord record = loadAuthorizedSession(req.getSessionNo());
        List<SnapshotItem> snapshots = readSnapshots(record.getQuestionSnapshotJson());
        if (req.getItemIndex() < 0 || req.getItemIndex() >= snapshots.size()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "题号超出范围");
        }
        SnapshotItem item = snapshots.get(req.getItemIndex());
        String fmt = normalizeFormat(item.getQuestionFormat());

        if ("ESSAY".equals(fmt)) {
            String text = req.getAnswerText() == null ? "" : req.getAnswerText().trim();
            String imageKey = req.getAnswerImageKey() == null ? "" : req.getAnswerImageKey().trim();
            if (text.isEmpty() && imageKey.isEmpty()) {
                throw new BizException(ErrorCode.BAD_REQUEST, "请先在绘制面板作答或填写解答内容");
            }
            item.setUserAnswerText(text);
            if (!imageKey.isEmpty()) {
                item.setUserAnswerImageKey(imageKey);
            }
            if (req.getSelfCorrect() != null) {
                item.setUserSelfCorrect(req.getSelfCorrect());
            }
            record.setQuestionSnapshotJson(writeJson(snapshots));
            quizRecordMapper.updateById(record);

            upsertEssayAnswerRecord(record, item);
            boolean pendingReview = item.getUserSelfCorrect() == null;

            return AppQuizVO.CheckItemVO.builder()
                    .itemIndex(item.getItemIndex())
                    .questionFormat("ESSAY")
                    .correct(Boolean.TRUE.equals(item.getUserSelfCorrect()))
                    .correctIndex(0)
                    .referenceAnswer(pendingReview ? "" : safeStr(item.getReferenceAnswer()))
                    .answerText(safeStr(item.getUserAnswerText()))
                    .answerImageUrl(ossService.resolveViewUrl(item.getUserAnswerImageKey(), baseOrigin))
                    .selfCorrect(item.getUserSelfCorrect())
                    .pendingReview(pendingReview)
                    .analysis(pendingReview ? "" : safeStr(item.getAnalysis()))
                    .build();
        }

        if (req.getSelectedIndex() == null) {
            throw new BizException(ErrorCode.BAD_REQUEST, "选项索引不能为空");
        }
        item.setUserIndex(req.getSelectedIndex());
        record.setQuestionSnapshotJson(writeJson(snapshots));
        quizRecordMapper.updateById(record);

        boolean correct = Objects.equals(item.getAnswerIndex(), req.getSelectedIndex());
        return AppQuizVO.CheckItemVO.builder()
                .itemIndex(item.getItemIndex())
                .questionFormat(fmt)
                .correct(correct)
                .correctIndex(item.getAnswerIndex())
                .referenceAnswer(safeStr(item.getReferenceAnswer()))
                .analysis(safeStr(item.getAnalysis()))
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.CheckItemVO gradeEssayItem(AppQuizDTO.EssayGradeReq req, String baseOrigin) {
        UserQuizRecord record = loadAuthorizedSession(req.getSessionNo());
        List<SnapshotItem> snapshots = readSnapshots(record.getQuestionSnapshotJson());
        if (req.getItemIndex() < 0 || req.getItemIndex() >= snapshots.size()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "题号超出范围");
        }
        SnapshotItem item = snapshots.get(req.getItemIndex());
        if (!"ESSAY".equalsIgnoreCase(item.getQuestionFormat())) {
            throw new BizException(ErrorCode.BAD_REQUEST, "该题不是解答题");
        }
        if (req.getAnswerText() != null) {
            item.setUserAnswerText(req.getAnswerText().trim());
        }
        if (req.getAnswerImageKey() != null && !req.getAnswerImageKey().isBlank()) {
            item.setUserAnswerImageKey(req.getAnswerImageKey().trim());
        }
        item.setUserSelfCorrect(req.getCorrect());
        record.setQuestionSnapshotJson(writeJson(snapshots));
        quizRecordMapper.updateById(record);

        upsertEssayAnswerRecord(record, item);

        return AppQuizVO.CheckItemVO.builder()
                .itemIndex(item.getItemIndex())
                .questionFormat("ESSAY")
                .correct(Boolean.TRUE.equals(req.getCorrect()))
                .correctIndex(0)
                .referenceAnswer(safeStr(item.getReferenceAnswer()))
                .answerText(safeStr(item.getUserAnswerText()))
                .answerImageUrl(ossService.resolveViewUrl(item.getUserAnswerImageKey(), baseOrigin))
                .selfCorrect(item.getUserSelfCorrect())
                .analysis(safeStr(item.getAnalysis()))
                .build();
    }

    public PageResult<AppQuizVO.EssayAnswerRecordVO> listMyEssayAnswers(Long pageNum, Long pageSize, String baseOrigin) {
        Long userId = StpAppUtil.getLoginIdAsLong();
        long p = pageNum == null || pageNum < 1 ? 1L : pageNum;
        long s = pageSize == null || pageSize < 1 ? 10L : Math.min(pageSize, 50L);

        Map<String, EduRealm> realmByGrade = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getGradeCode, r -> r, (a, b) -> a));

        Page<UserEssayAnswer> page = essayAnswerMapper.selectPage(
                new Page<>(p, s),
                new LambdaQueryWrapper<UserEssayAnswer>()
                        .eq(UserEssayAnswer::getUserId, userId)
                        .orderByDesc(UserEssayAnswer::getUpdatedAt)
                        .orderByDesc(UserEssayAnswer::getId)
        );
        Set<Long> qIds = page.getRecords().stream()
                .map(UserEssayAnswer::getQuestionId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<Long, EduQuestion> qMap = qIds.isEmpty()
                ? Map.of()
                : questionMapper.selectBatchIds(qIds).stream()
                .collect(Collectors.toMap(EduQuestion::getId, q -> q, (a, b) -> a));

        List<AppQuizVO.EssayAnswerRecordVO> records = page.getRecords().stream()
                .map(e -> {
                    EduRealm realm = e.getRealmCode() != null && !e.getRealmCode().isBlank()
                            ? realmHelper.findByRealmCode(e.getRealmCode())
                            : realmByGrade.get(e.getGradeCode());
                    QuestionFigureMeta fig = extractQuestionFigure(qMap.get(e.getQuestionId()), baseOrigin);
                    return AppQuizVO.EssayAnswerRecordVO.builder()
                            .id(e.getId())
                            .sessionNo(e.getSessionNo())
                            .itemIndex(e.getItemIndex())
                            .realmCode(realm != null ? realm.getRealmCode() : safeStr(e.getRealmCode()))
                            .realmName(realm != null ? realm.getRealmName() : "")
                            .chapterName(e.getChapterName())
                            .gateId(e.getGateId())
                            .gateName(e.getGateName())
                            .stem(e.getStem())
                            .diagram(fig.diagram())
                            .imageUrl(fig.imageUrl())
                            .referenceAnswer(e.getReferenceAnswer())
                            .answerText(e.getAnswerText())
                            .answerImageUrl(ossService.resolveViewUrl(e.getAnswerImageKey(), baseOrigin))
                            .selfCorrect(e.getSelfCorrect())
                            .teacherStatus(e.getTeacherStatus())
                            .teacherComment(e.getTeacherComment())
                            .teacherImageUrl(ossService.resolveViewUrl(e.getTeacherImageKey(), baseOrigin))
                            .createdAt(e.getCreatedAt())
                            .reviewedAt(e.getReviewedAt())
                            .build();
                })
                .toList();
        return PageResult.of(records, page.getTotal(), p, s);
    }

    @Transactional(rollbackFor = Exception.class)
    public void clearMyEssayAnswers() {
        Long userId = StpAppUtil.getLoginIdAsLong();
        essayAnswerMapper.delete(
                new LambdaQueryWrapper<UserEssayAnswer>()
                        .eq(UserEssayAnswer::getUserId, userId)
        );
    }

    private record EvalOutcome(
            int correctCount,
            int pendingReviewCount,
            List<SnapshotItem> wrongSnaps,
            List<AppQuizVO.WrongReviewItem> wrongReview
    ) {}

    private record GateOutcome(
            boolean newlyPassed,
            int totalPassed,
            AppUserProfileVO.LevelProgress promotedLevel
    ) {}

    private record NextGateTarget(
            Long gateId,
            Integer gateIndex,
            String gateName,
            Long chapterId,
            String chapterName,
            boolean crossChapter
    ) {}

    private record QuestionFigureMeta(
            Map<String, Object> diagram,
            String imageUrl
    ) {}

    private EvalOutcome evaluateSnapshots(List<SnapshotItem> snapshots, String baseOrigin) {
        int correctCount = 0;
        int pendingReviewCount = 0;
        List<SnapshotItem> wrongSnaps = new ArrayList<>();
        List<AppQuizVO.WrongReviewItem> wrongReview = new ArrayList<>();
        for (SnapshotItem item : snapshots) {
            if (isSnapshotItemCorrect(item)) {
                correctCount++;
            } else if (isEssaySubmittedPendingReview(item)) {
                pendingReviewCount++;
            } else {
                wrongSnaps.add(item);
                wrongReview.add(toWrongReviewItem(item, baseOrigin));
            }
        }
        return new EvalOutcome(correctCount, pendingReviewCount, wrongSnaps, wrongReview);
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.SubmitResultVO submitGateQuiz(AppQuizDTO.SubmitReq req) {
        return submitGateQuiz(req, "");
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.SubmitResultVO submitGateQuiz(AppQuizDTO.SubmitReq req, String baseOrigin) {
        UserQuizRecord record = loadAuthorizedSession(req.getSessionNo());
        if (record.getStatus() != null && record.getStatus() == 1) {
            throw new BizException(ErrorCode.QUIZ_ALREADY_SUBMITTED);
        }
        List<SnapshotItem> snapshots = readSnapshots(record.getQuestionSnapshotJson());
        applyBatchAnswers(record, snapshots, req.getAnswers());

        EvalOutcome eval = evaluateSnapshots(snapshots, baseOrigin);
        EduGate gate = gateMapper.selectById(record.getGateId());
        EduChapter chapter = chapterMapper.selectById(record.getChapterId());
        int passCount = gate != null ? Math.min(gate.getPassCount(), snapshots.size()) : (int) Math.ceil(snapshots.size() * 2.0 / 3.0);
        boolean passed = eval.correctCount() >= passCount;
        int score = snapshots.isEmpty() ? 0 : (int) Math.round(eval.correctCount() * 100.0 / snapshots.size());

        record.setQuestionSnapshotJson(writeJson(snapshots));
        record.setCorrectCount(eval.correctCount());
        record.setScore(score);
        record.setIsPassed(passed ? 1 : 0);
        record.setStatus(1);
        record.setSubmittedAt(LocalDateTime.now());
        quizRecordMapper.updateById(record);

        GateOutcome gateOut = new GateOutcome(false, 0, null);
        Long userId = StpAppUtil.getLoginIdOrNull();
        boolean alreadyPassedBefore = false;
        if (userId != null && record.getUserId() != 0L && gate != null && chapter != null) {
            UserGateProgress prevProg = gateProgressMapper.selectOne(
                    new LambdaQueryWrapper<UserGateProgress>()
                            .eq(UserGateProgress::getUserId, userId)
                            .eq(UserGateProgress::getGateId, gate.getId())
                            .last("LIMIT 1")
            );
            alreadyPassedBefore = prevProg != null && prevProg.getIsPassed() != null && prevProg.getIsPassed() == 1;
            gateOut = applyGatePassOutcome(userId, gate, chapter, eval.correctCount(), passed);
            recordWrongQuestions(userId, chapter, gate.getGateName(), eval.wrongSnaps());
        }

        NextGateTarget nextGate = (gate != null && chapter != null && (passed || alreadyPassedBefore))
                ? resolveNextPlayableGate(chapter, gate)
                : null;

        return AppQuizVO.SubmitResultVO.builder()
                .sessionNo(record.getSessionNo())
                .mode("GATE")
                .totalCount(snapshots.size())
                .correctCount(eval.correctCount())
                .pendingReviewCount(eval.pendingReviewCount())
                .score(score)
                .passCount(passCount)
                .passed(passed)
                .newlyPassed(gateOut.newlyPassed())
                .totalPassedGates(gateOut.totalPassed())
                .promotedLevel(gateOut.promotedLevel())
                .wrongItems(eval.wrongReview())
                .masteredCount(0)
                .nextGateId(nextGate != null ? nextGate.gateId() : null)
                .nextGateIndex(nextGate != null ? nextGate.gateIndex() : null)
                .nextGateName(nextGate != null ? nextGate.gateName() : null)
                .nextChapterId(nextGate != null ? nextGate.chapterId() : null)
                .nextChapterName(nextGate != null ? nextGate.chapterName() : null)
                .nextGateCrossChapter(nextGate != null && nextGate.crossChapter())
                .build();
    }

    private NextGateTarget resolveNextPlayableGate(EduChapter currentChapter, EduGate currentGate) {
        // 1. 优先查找同章节的下一道已启用且有题关卡
        List<EduGate> sameChapterNext = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .eq(EduGate::getChapterId, currentChapter.getId())
                        .eq(EduGate::getEnabled, 1)
                        .gt(EduGate::getGateIndex, currentGate.getGateIndex())
                        .orderByAsc(EduGate::getGateIndex)
        );
        for (EduGate candidate : sameChapterNext) {
            if (hasEnabledQuestions(candidate.getId())) {
                return new NextGateTarget(
                        candidate.getId(),
                        candidate.getGateIndex(),
                        candidate.getGateName(),
                        currentChapter.getId(),
                        currentChapter.getName(),
                        false
                );
            }
        }

        // 2. 当前章节已到最后一关：顺延至同年级下一章节的第 1 道有题关卡
        List<EduChapter> gradeChapters = chapterMapper.selectList(
                new LambdaQueryWrapper<EduChapter>()
                        .eq(EduChapter::getGradeCode, currentChapter.getGradeCode())
                        .eq(EduChapter::getEnabled, 1)
                        .orderByAsc(EduChapter::getSortOrder)
                        .orderByAsc(EduChapter::getId)
        );
        boolean passedCurrent = false;
        for (EduChapter ch : gradeChapters) {
            if (!passedCurrent) {
                if (Objects.equals(ch.getId(), currentChapter.getId())) {
                    passedCurrent = true;
                }
                continue;
            }
            List<EduGate> chGates = gateMapper.selectList(
                    new LambdaQueryWrapper<EduGate>()
                            .eq(EduGate::getChapterId, ch.getId())
                            .eq(EduGate::getEnabled, 1)
                            .orderByAsc(EduGate::getGateIndex)
            );
            for (EduGate candidate : chGates) {
                if (hasEnabledQuestions(candidate.getId())) {
                    return new NextGateTarget(
                            candidate.getId(),
                            candidate.getGateIndex(),
                            candidate.getGateName(),
                            ch.getId(),
                            ch.getName(),
                            true
                    );
                }
            }
        }
        return null;
    }

    private boolean hasEnabledQuestions(Long gateId) {
        if (gateId == null) return false;
        Long cnt = questionMapper.selectCount(
                new LambdaQueryWrapper<EduQuestion>()
                        .eq(EduQuestion::getGateId, gateId)
                        .eq(EduQuestion::getEnabled, 1)
        );
        return cnt != null && cnt > 0;
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.SubmitResultVO submitAdvanceExam(AppQuizDTO.SubmitReq req) {
        return submitAdvanceExam(req, "");
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.SubmitResultVO submitAdvanceExam(AppQuizDTO.SubmitReq req, String baseOrigin) {
        UserQuizRecord record = loadAuthorizedSession(req.getSessionNo());
        if (!"ADVANCE_EXAM".equals(record.getMode())) {
            throw new BizException(ErrorCode.BAD_REQUEST, "当前会话不是进阶考核");
        }
        if (record.getStatus() != null && record.getStatus() == 1) {
            throw new BizException(ErrorCode.QUIZ_ALREADY_SUBMITTED);
        }
        Long userId = StpAppUtil.getLoginIdAsLong();
        AppUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED);
        }

        List<SnapshotItem> snapshots = readSnapshots(record.getQuestionSnapshotJson());
        applyBatchAnswers(record, snapshots, req.getAnswers());

        EvalOutcome eval = evaluateSnapshots(snapshots, baseOrigin);
        EduRealm examRealm = realmHelper.findByRealmCode(record.getRealmCode());
        if (examRealm == null) {
            examRealm = realmHelper.resolveUserRealm(user);
        }
        int passScore = examRealm.getExamPassScore() == null ? 60 : examRealm.getExamPassScore();
        int score = snapshots.isEmpty() ? 0 : (int) Math.round(eval.correctCount() * 100.0 / snapshots.size());
        boolean passed = score >= passScore;

        LocalDateTime now = LocalDateTime.now();
        record.setQuestionSnapshotJson(writeJson(snapshots));
        record.setCorrectCount(eval.correctCount());
        record.setScore(score);
        record.setIsPassed(passed ? 1 : 0);
        record.setStatus(1);
        record.setSubmittedAt(now);
        quizRecordMapper.updateById(record);

        recordExamWrongQuestions(userId, examRealm, eval.wrongSnaps());
        AppUserProfileVO.RealmItemVO promotedRealm = applyAdvanceExamPromotion(user, examRealm, passed, now);

        return AppQuizVO.SubmitResultVO.builder()
                .sessionNo(record.getSessionNo())
                .mode("ADVANCE_EXAM")
                .totalCount(snapshots.size())
                .correctCount(eval.correctCount())
                .pendingReviewCount(eval.pendingReviewCount())
                .score(score)
                .passScore(passScore)
                .passCount((int) Math.ceil(snapshots.size() * passScore / 100.0))
                .passed(passed)
                .newlyPassed(promotedRealm != null)
                .totalPassedGates(user.getPassedGateCount() == null ? 0 : user.getPassedGateCount())
                .promotedRealm(promotedRealm)
                .wrongItems(eval.wrongReview())
                .masteredCount(0)
                .build();
    }

    private GateOutcome applyGatePassOutcome(Long userId, EduGate gate, EduChapter chapter, int correctCount, boolean passed) {
        AppUser user = userMapper.selectById(userId);
        if (user == null) {
            return new GateOutcome(false, 0, null);
        }
        int beforeTotal = user.getPassedGateCount() == null ? 0 : user.getPassedGateCount();
        AppUserProfileVO.LevelProgress beforeLevel = bankService.computeLevelProgress(beforeTotal);

        UserGateProgress prog = gateProgressMapper.selectOne(
                new LambdaQueryWrapper<UserGateProgress>()
                        .eq(UserGateProgress::getUserId, userId)
                        .eq(UserGateProgress::getGateId, gate.getId())
                        .last("LIMIT 1")
        );
        boolean newlyPassed = false;
        LocalDateTime now = LocalDateTime.now();
        if (prog == null) {
            prog = new UserGateProgress();
            prog.setUserId(userId);
            prog.setChapterId(chapter.getId());
            prog.setGateId(gate.getId());
            prog.setGateIndex(gate.getGateIndex());
            prog.setIsPassed(passed ? 1 : 0);
            prog.setBestCorrect(correctCount);
            prog.setAttemptCount(1);
            prog.setFirstPassedAt(passed ? now : null);
            prog.setLastPlayedAt(now);
            gateProgressMapper.insert(prog);
            newlyPassed = passed;
        } else {
            boolean wasPassed = prog.getIsPassed() != null && prog.getIsPassed() == 1;
            if (!wasPassed && passed) {
                prog.setIsPassed(1);
                prog.setFirstPassedAt(now);
                newlyPassed = true;
            }
            prog.setBestCorrect(Math.max(prog.getBestCorrect() == null ? 0 : prog.getBestCorrect(), correctCount));
            prog.setAttemptCount((prog.getAttemptCount() == null ? 0 : prog.getAttemptCount()) + 1);
            prog.setLastPlayedAt(now);
            gateProgressMapper.updateById(prog);
        }

        long distinctPassed = gateProgressMapper.selectCount(
                new LambdaQueryWrapper<UserGateProgress>()
                        .eq(UserGateProgress::getUserId, userId)
                        .eq(UserGateProgress::getIsPassed, 1)
        );
        int totalPassed = (int) distinctPassed;
        AppUserProfileVO.LevelProgress afterLevel = bankService.computeLevelProgress(totalPassed);
        AppUserProfileVO.LevelProgress promotedLevel = !Objects.equals(beforeLevel.getLevelName(), afterLevel.getLevelName())
                ? afterLevel : null;

        user.setPassedGateCount(totalPassed);
        user.setCurrentLevelId(afterLevel.getLevelId());
        user.setLastActiveAt(now);
        userMapper.updateById(user);
        return new GateOutcome(newlyPassed, totalPassed, promotedLevel);
    }

    private AppUserProfileVO.RealmItemVO applyAdvanceExamPromotion(AppUser user, EduRealm examRealm, boolean passed, LocalDateTime now) {
        if (!passed || user == null) {
            return null;
        }
        EduRealm userCurrent = realmHelper.resolveUserRealm(user);
        EduRealm nextRealm = realmHelper.findNextRealm(examRealm.getRealmOrder());
        if (nextRealm == null || userCurrent.getRealmOrder() > examRealm.getRealmOrder()) {
            return null;
        }
        user.setRealmCode(nextRealm.getRealmCode());
        user.setGradeCode(nextRealm.getGradeCode());
        user.setLastActiveAt(now);
        userMapper.updateById(user);
        return AppUserProfileVO.RealmItemVO.builder()
                .realmCode(nextRealm.getRealmCode())
                .realmName(nextRealm.getRealmName())
                .realmOrder(nextRealm.getRealmOrder())
                .gradeCode(nextRealm.getGradeCode())
                .difficultyLabel(nextRealm.getDifficultyLabel())
                .description(nextRealm.getDescription())
                .unlockGates(nextRealm.getUnlockGates())
                .examQuestionCount(nextRealm.getExamQuestionCount())
                .examPassScore(nextRealm.getExamPassScore())
                .unlocked(true)
                .isCurrent(true)
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public void syncEssayTeacherReview(UserEssayAnswer ans, boolean approved) {
        if (ans == null) return;
        UserQuizRecord record = quizRecordMapper.selectOne(
                new LambdaQueryWrapper<UserQuizRecord>()
                        .eq(UserQuizRecord::getSessionNo, ans.getSessionNo())
                        .last("LIMIT 1")
        );
        LocalDateTime now = LocalDateTime.now();
        SnapshotItem targetSnap = null;
        if (record != null) {
            List<SnapshotItem> snapshots = readSnapshots(record.getQuestionSnapshotJson());
            for (SnapshotItem item : snapshots) {
                if (Objects.equals(item.getItemIndex(), ans.getItemIndex())) {
                    item.setUserSelfCorrect(approved);
                    targetSnap = item;
                    break;
                }
            }
            int correctCount = (int) snapshots.stream().filter(this::isSnapshotItemCorrect).count();
            int score = snapshots.isEmpty() ? 0 : (int) Math.round(correctCount * 100.0 / snapshots.size());
            record.setQuestionSnapshotJson(writeJson(snapshots));
            record.setCorrectCount(correctCount);
            record.setScore(score);

            boolean passed = false;
            if ("ADVANCE_EXAM".equals(record.getMode())) {
                AppUser user = ans.getUserId() != null && ans.getUserId() > 0 ? userMapper.selectById(ans.getUserId()) : null;
                EduRealm examRealm = realmHelper.findByRealmCode(record.getRealmCode());
                if (examRealm == null && user != null) {
                    examRealm = realmHelper.resolveUserRealm(user);
                }
                int passScore = examRealm != null && examRealm.getExamPassScore() != null ? examRealm.getExamPassScore() : 60;
                passed = score >= passScore;
                if (user != null && examRealm != null) {
                    applyAdvanceExamPromotion(user, examRealm, passed, now);
                }
            } else if ("REDO_WRONG".equals(record.getMode())) {
                int passNeed = (int) Math.ceil(snapshots.size() * 2.0 / 3.0);
                passed = correctCount >= passNeed;
            } else {
                EduGate gate = record.getGateId() != null ? gateMapper.selectById(record.getGateId()) : null;
                EduChapter chapter = record.getChapterId() != null ? chapterMapper.selectById(record.getChapterId()) : null;
                int passCount = gate != null ? Math.min(gate.getPassCount(), snapshots.size())
                        : (int) Math.ceil(snapshots.size() * 2.0 / 3.0);
                passed = correctCount >= passCount;
                if (ans.getUserId() != null && ans.getUserId() > 0 && gate != null && chapter != null) {
                    applyGatePassOutcome(ans.getUserId(), gate, chapter, correctCount, passed);
                }
            }
            record.setIsPassed(passed ? 1 : 0);
            quizRecordMapper.updateById(record);
        }

        if (ans.getUserId() == null || ans.getUserId() <= 0) {
            return;
        }
        if (targetSnap == null) {
            targetSnap = new SnapshotItem();
            targetSnap.setItemIndex(ans.getItemIndex());
            targetSnap.setQuestionId(ans.getQuestionId());
            targetSnap.setChapterId(ans.getChapterId());
            targetSnap.setGradeCode(ans.getGradeCode());
            targetSnap.setQuestionFormat("ESSAY");
            targetSnap.setStem(ans.getStem());
            targetSnap.setOptions(List.of());
            targetSnap.setReferenceAnswer(ans.getReferenceAnswer());
            targetSnap.setUserAnswerText(ans.getAnswerText());
            targetSnap.setUserAnswerImageKey(ans.getAnswerImageKey());
        }
        String stemHash = sha256(safeStr(targetSnap.getStem()) + "|ESSAY|" + safeStr(targetSnap.getReferenceAnswer()));
        if (!approved) {
            upsertWrongItem(
                    ans.getUserId(),
                    safeStr(ans.getGradeCode()),
                    ans.getChapterId() == null ? 0L : ans.getChapterId(),
                    safeStr(ans.getChapterName()),
                    safeStr(ans.getGateName()),
                    targetSnap,
                    now
            );
        } else {
            UserWrongQuestion exist = wrongMapper.selectOne(
                    new LambdaQueryWrapper<UserWrongQuestion>()
                            .eq(UserWrongQuestion::getUserId, ans.getUserId())
                            .eq(UserWrongQuestion::getStemHash, stemHash)
                            .eq(UserWrongQuestion::getIsMastered, 0)
                            .last("LIMIT 1")
            );
            if (exist != null) {
                exist.setIsMastered(1);
                exist.setMasteredAt(now);
                wrongMapper.updateById(exist);
            }
        }
    }

    public UserQuizRecord loadAuthorizedSession(String sessionNo) {
        UserQuizRecord record = quizRecordMapper.selectOne(
                new LambdaQueryWrapper<UserQuizRecord>()
                        .eq(UserQuizRecord::getSessionNo, sessionNo)
                        .last("LIMIT 1")
        );
        if (record == null) {
            throw new BizException(ErrorCode.QUIZ_SESSION_INVALID);
        }
        Long currentUserId = StpAppUtil.getLoginIdOrNull();
        if (record.getUserId() != 0L && !Objects.equals(record.getUserId(), currentUserId)) {
            throw new BizException(ErrorCode.QUIZ_SESSION_INVALID);
        }
        return record;
    }

    public void applyBatchAnswers(UserQuizRecord record, List<SnapshotItem> snapshots, List<AppQuizDTO.AnswerSelection> answers) {
        if (answers == null || answers.isEmpty()) {
            return;
        }
        for (AppQuizDTO.AnswerSelection sel : answers) {
            if (sel.getItemIndex() == null || sel.getItemIndex() < 0 || sel.getItemIndex() >= snapshots.size()) {
                continue;
            }
            SnapshotItem item = snapshots.get(sel.getItemIndex());
            if ("ESSAY".equalsIgnoreCase(item.getQuestionFormat())) {
                if (sel.getAnswerText() != null) {
                    item.setUserAnswerText(sel.getAnswerText().trim());
                }
                if (sel.getAnswerImageKey() != null && !sel.getAnswerImageKey().isBlank()) {
                    item.setUserAnswerImageKey(sel.getAnswerImageKey().trim());
                }
                if (sel.getSelfCorrect() != null) {
                    item.setUserSelfCorrect(sel.getSelfCorrect());
                }
                if ((item.getUserAnswerText() != null && !item.getUserAnswerText().isBlank())
                        || (item.getUserAnswerImageKey() != null && !item.getUserAnswerImageKey().isBlank())) {
                    upsertEssayAnswerRecord(record, item);
                }
            } else if (sel.getSelectedIndex() != null) {
                item.setUserIndex(sel.getSelectedIndex());
            }
        }
    }

    public boolean isSnapshotItemCorrect(SnapshotItem item) {
        if ("ESSAY".equalsIgnoreCase(item.getQuestionFormat())) {
            return Boolean.TRUE.equals(item.getUserSelfCorrect());
        }
        return Objects.equals(item.getAnswerIndex(), item.getUserIndex());
    }

    public boolean isEssaySubmittedPendingReview(SnapshotItem item) {
        if (!"ESSAY".equalsIgnoreCase(item.getQuestionFormat())) {
            return false;
        }
        if (item.getUserSelfCorrect() != null) {
            return false;
        }
        boolean hasText = item.getUserAnswerText() != null && !item.getUserAnswerText().isBlank();
        boolean hasImg = item.getUserAnswerImageKey() != null && !item.getUserAnswerImageKey().isBlank();
        return hasText || hasImg;
    }

    private void upsertEssayAnswerRecord(UserQuizRecord record, SnapshotItem item) {
        Long userId = record.getUserId() == null ? 0L : record.getUserId();
        Long chapterId = item.getChapterId() != null ? item.getChapterId() : record.getChapterId();
        Long gateId = record.getGateId();
        String realmCode = safeStr(record.getRealmCode());
        if (realmCode.isBlank() && item.getGradeCode() != null && !item.getGradeCode().isBlank()) {
            EduRealm byGrade = realmHelper.findByGradeCode(item.getGradeCode());
            if (byGrade != null) {
                realmCode = safeStr(byGrade.getRealmCode());
            }
        }

        String chapterName = "";
        String gateName = "";
        if ("ADVANCE_EXAM".equals(record.getMode())) {
            EduRealm r = realmHelper.findByRealmCode(realmCode);
            chapterName = (r != null ? r.getRealmName() : "") + "进阶考核";
            gateName = "进阶考核";
        } else if ("REDO_WRONG".equals(record.getMode())) {
            chapterName = "错题重做";
            gateName = "消灭错题";
        } else {
            EduChapter ch = chapterId != null ? chapterMapper.selectById(chapterId) : null;
            EduGate gt = gateId != null ? gateMapper.selectById(gateId) : null;
            chapterName = ch != null ? ch.getName() : "";
            gateName = gt != null ? gt.getGateName() : "";
        }

        // 同学生 + 同境界 + 同章节 + 同关卡唯一保留最新 1 条，再次提交直接覆盖并重置为待批改
        UserEssayAnswer exist = null;
        if (userId > 0L && "GATE".equals(record.getMode()) && chapterId != null && gateId != null) {
            final String resolvedRealm = realmCode;
            exist = essayAnswerMapper.selectOne(
                    new LambdaQueryWrapper<UserEssayAnswer>()
                            .eq(UserEssayAnswer::getUserId, userId)
                            .eq(UserEssayAnswer::getChapterId, chapterId)
                            .eq(UserEssayAnswer::getGateId, gateId)
                            .and(!resolvedRealm.isBlank(), w -> w.eq(UserEssayAnswer::getRealmCode, resolvedRealm)
                                    .or().eq(UserEssayAnswer::getRealmCode, ""))
                            .orderByDesc(UserEssayAnswer::getId)
                            .last("LIMIT 1")
            );
            if (exist == null && !gateName.isBlank()) {
                exist = essayAnswerMapper.selectOne(
                        new LambdaQueryWrapper<UserEssayAnswer>()
                                .eq(UserEssayAnswer::getUserId, userId)
                                .eq(UserEssayAnswer::getChapterId, chapterId)
                                .isNull(UserEssayAnswer::getGateId)
                                .eq(UserEssayAnswer::getGateName, gateName)
                                .orderByDesc(UserEssayAnswer::getId)
                                .last("LIMIT 1")
                );
            }
        }
        if (exist == null) {
            exist = essayAnswerMapper.selectOne(
                    new LambdaQueryWrapper<UserEssayAnswer>()
                            .eq(UserEssayAnswer::getSessionNo, record.getSessionNo())
                            .eq(UserEssayAnswer::getItemIndex, item.getItemIndex())
                            .last("LIMIT 1")
            );
        }

        Integer selfVal = item.getUserSelfCorrect() == null ? null : (item.getUserSelfCorrect() ? 1 : 0);
        LocalDateTime now = LocalDateTime.now();
        if (exist != null) {
            boolean sameSessionItem = Objects.equals(exist.getSessionNo(), record.getSessionNo())
                    && Objects.equals(exist.getItemIndex(), item.getItemIndex());
            exist.setSessionNo(record.getSessionNo());
            exist.setItemIndex(item.getItemIndex());
            exist.setQuestionId(item.getQuestionId());
            exist.setGradeCode(safeStr(item.getGradeCode()));
            exist.setRealmCode(realmCode);
            exist.setChapterId(chapterId);
            exist.setChapterName(chapterName);
            exist.setGateId(gateId);
            exist.setGateName(gateName);
            exist.setStem(safeStr(item.getStem()));
            exist.setReferenceAnswer(safeStr(item.getReferenceAnswer()));
            exist.setAnswerText(safeStr(item.getUserAnswerText()));

            if (!sameSessionItem) {
                exist.setAnswerImageKey(safeStr(item.getUserAnswerImageKey()));
                exist.setSelfCorrect(selfVal);
                exist.setTeacherStatus(0);
                exist.setTeacherComment("");
                exist.setTeacherImageKey(null);
                exist.setReviewedBy(null);
                exist.setReviewedAt(null);
                exist.setCreatedAt(now);
            } else {
                if (item.getUserAnswerImageKey() != null && !item.getUserAnswerImageKey().isBlank()) {
                    exist.setAnswerImageKey(item.getUserAnswerImageKey());
                }
                if (selfVal != null) {
                    exist.setSelfCorrect(selfVal);
                }
            }
            essayAnswerMapper.updateById(exist);
            return;
        }

        UserEssayAnswer ans = new UserEssayAnswer();
        ans.setSessionNo(record.getSessionNo());
        ans.setItemIndex(item.getItemIndex());
        ans.setUserId(userId);
        ans.setQuestionId(item.getQuestionId());
        ans.setGradeCode(safeStr(item.getGradeCode()));
        ans.setRealmCode(realmCode);
        ans.setChapterId(chapterId);
        ans.setChapterName(chapterName);
        ans.setGateId(gateId);
        ans.setGateName(gateName);
        ans.setStem(safeStr(item.getStem()));
        ans.setReferenceAnswer(safeStr(item.getReferenceAnswer()));
        ans.setAnswerText(safeStr(item.getUserAnswerText()));
        ans.setAnswerImageKey(safeStr(item.getUserAnswerImageKey()));
        ans.setSelfCorrect(selfVal);
        ans.setTeacherStatus(0);
        ans.setTeacherComment("");
        ans.setTeacherImageKey(null);
        essayAnswerMapper.insert(ans);
    }

    private SnapshotItem toSnapshot(int idx, EduQuestion q, GeneratedQuestion gen) {
        String fmt = normalizeFormat(gen.getQuestionFormat() != null ? gen.getQuestionFormat() : q.getQuestionFormat());
        SnapshotItem snap = new SnapshotItem();
        snap.setItemIndex(idx);
        snap.setQuestionId(q.getId());
        snap.setChapterId(q.getChapterId());
        snap.setGradeCode(q.getGradeCode());
        snap.setQuestionFormat(fmt);
        snap.setStem(gen.getStem());
        snap.setOptions(gen.getOptions() == null ? List.of() : gen.getOptions());
        snap.setAnswerIndex(gen.getAnswerIndex() == null ? 0 : gen.getAnswerIndex());
        snap.setReferenceAnswer(safeStr(gen.getReferenceAnswer()));
        snap.setAnalysis(gen.getAnalysis());
        snap.setDiagram(gen.getDiagram());
        snap.setImageKey(gen.getImageKey());
        return snap;
    }

    public AppQuizVO.WrongReviewItem toWrongReviewItem(SnapshotItem item) {
        return toWrongReviewItem(item, "");
    }

    public AppQuizVO.WrongReviewItem toWrongReviewItem(SnapshotItem item, String baseOrigin) {
        String fmt = normalizeFormat(item.getQuestionFormat());
        String rightOpt;
        if ("ESSAY".equals(fmt)) {
            rightOpt = safeStr(item.getReferenceAnswer());
        } else {
            rightOpt = (item.getOptions() != null && item.getAnswerIndex() != null
                    && item.getAnswerIndex() >= 0 && item.getAnswerIndex() < item.getOptions().size())
                    ? item.getOptions().get(item.getAnswerIndex())
                    : "";
        }
        return AppQuizVO.WrongReviewItem.builder()
                .stem(item.getStem())
                .questionFormat(fmt)
                .correctAnswer(rightOpt)
                .analysis(item.getAnalysis())
                .diagram(item.getDiagram())
                .imageUrl(ossService.resolveViewUrl(item.getImageKey(), baseOrigin))
                .build();
    }

    @SuppressWarnings("unchecked")
    private QuestionFigureMeta extractQuestionFigure(EduQuestion q, String baseOrigin) {
        if (q == null || q.getExtJson() == null || q.getExtJson().isBlank()) {
            return new QuestionFigureMeta(null, "");
        }
        Map<String, Object> ext = JsonHelper.readMap(objectMapper, q.getExtJson());
        if (ext == null || ext.isEmpty()) {
            return new QuestionFigureMeta(null, "");
        }
        Map<String, Object> diagram = ext.get("diagram") instanceof Map<?, ?> m && !m.isEmpty()
                ? (Map<String, Object>) m
                : null;
        Object rawImg = ext.get("imageKey");
        if (rawImg == null || String.valueOf(rawImg).isBlank()) {
            rawImg = ext.get("imageUrl");
        }
        String imageUrl = (rawImg != null && !String.valueOf(rawImg).isBlank())
                ? ossService.resolveViewUrl(String.valueOf(rawImg).trim(), baseOrigin)
                : "";
        return new QuestionFigureMeta(diagram, imageUrl);
    }

    private void recordWrongQuestions(Long userId, EduChapter chapter, String gateName, List<SnapshotItem> wrongSnaps) {
        LocalDateTime now = LocalDateTime.now();
        for (SnapshotItem item : wrongSnaps) {
            upsertWrongItem(userId, chapter.getGradeCode(), chapter.getId(), chapter.getName(), gateName, item, now);
        }
    }

    private void recordExamWrongQuestions(Long userId, EduRealm realm, List<SnapshotItem> wrongSnaps) {
        if (wrongSnaps.isEmpty()) return;
        Set<Long> chapIds = wrongSnaps.stream()
                .map(SnapshotItem::getChapterId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<Long, EduChapter> chapMap = chapIds.isEmpty()
                ? Map.of()
                : chapterMapper.selectBatchIds(chapIds).stream().collect(Collectors.toMap(EduChapter::getId, c -> c));

        LocalDateTime now = LocalDateTime.now();
        for (SnapshotItem item : wrongSnaps) {
            EduChapter ch = item.getChapterId() != null ? chapMap.get(item.getChapterId()) : null;
            Long chapId = ch != null ? ch.getId() : 0L;
            String chapName = ch != null ? ch.getName() : (realm.getRealmName() + "进阶题库");
            upsertWrongItem(userId, realm.getGradeCode(), chapId, chapName, "进阶考核", item, now);
        }
    }

    private void upsertWrongItem(Long userId, String gradeCode, Long chapterId, String chapterName,
                                 String gateName, SnapshotItem item, LocalDateTime now) {
        String fmt = normalizeFormat(item.getQuestionFormat());
        boolean isEssay = "ESSAY".equals(fmt);
        String hash = isEssay
                ? sha256(item.getStem() + "|ESSAY|" + safeStr(item.getReferenceAnswer()))
                : sha256(item.getStem() + "|" + writeJson(item.getOptions()));
        UserWrongQuestion exist = wrongMapper.selectOne(
                new LambdaQueryWrapper<UserWrongQuestion>()
                        .eq(UserWrongQuestion::getUserId, userId)
                        .eq(UserWrongQuestion::getStemHash, hash)
                        .last("LIMIT 1")
        );
        if (exist == null) {
            UserWrongQuestion wq = new UserWrongQuestion();
            wq.setUserId(userId);
            wq.setQuestionId(item.getQuestionId());
            wq.setGradeCode(gradeCode);
            wq.setChapterId(chapterId);
            wq.setChapterName(chapterName);
            wq.setGateName(gateName);
            wq.setStemHash(hash);
            wq.setStem(item.getStem());
            wq.setQuestionFormat(fmt);
            wq.setOptionsJson(writeJson(isEssay ? List.of() : item.getOptions()));
            wq.setAnswerJson(writeJson(isEssay
                    ? Map.of("text", safeStr(item.getReferenceAnswer()))
                    : Map.of("index", item.getAnswerIndex() == null ? 0 : item.getAnswerIndex())));
            wq.setLastAnswerImageKey(safeStr(item.getUserAnswerImageKey()));
            wq.setAnalysis(item.getAnalysis());
            wq.setWrongCount(1);
            wq.setIsMastered(0);
            wq.setLastWrongAt(now);
            wrongMapper.insert(wq);
        } else {
            exist.setWrongCount((exist.getWrongCount() == null ? 0 : exist.getWrongCount()) + 1);
            exist.setIsMastered(0);
            exist.setMasteredAt(null);
            exist.setLastWrongAt(now);
            if (item.getUserAnswerImageKey() != null && !item.getUserAnswerImageKey().isBlank()) {
                exist.setLastAnswerImageKey(item.getUserAnswerImageKey());
            }
            wrongMapper.updateById(exist);
        }
    }

    public List<SnapshotItem> readSnapshots(String json) {
        try {
            return JsonHelper.readValue(objectMapper, json, new TypeReference<>() {});
        } catch (Exception e) {
            throw new BizException(ErrorCode.INTERNAL_ERROR, "答题会话快照解析失败");
        }
    }

    public String writeJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            throw new BizException(ErrorCode.INTERNAL_ERROR);
        }
    }

    private String normalizeFormat(String format) {
        if (format == null || format.isBlank()) {
            return "SINGLE_CHOICE";
        }
        return format.trim().toUpperCase(Locale.ROOT);
    }

    private String safeStr(String s) {
        return s == null ? "" : s;
    }

    private String sha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder();
            for (byte b : hash) {
                hex.append(String.format("%02x", b));
            }
            return hex.toString();
        } catch (Exception e) {
            throw new BizException(ErrorCode.INTERNAL_ERROR);
        }
    }
}
