package com.guoguanla.module.app;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
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
import com.guoguanla.module.progress.entity.UserGateProgress;
import com.guoguanla.module.progress.entity.UserQuizRecord;
import com.guoguanla.module.progress.entity.UserWrongQuestion;
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
    private final AppUserMapper userMapper;
    private final QuestionEngineService engineService;
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
        private String analysis;
        private Integer userIndex;
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.StartVO startGateQuiz(AppQuizDTO.StartReq req) {
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
        if (targetRealm != null && targetRealm.getRealmOrder() > userRealm.getRealmOrder()) {
            throw new BizException(
                    ErrorCode.REALM_LOCKED,
                    "境界不足：当前为「" + userRealm.getRealmName() + "」，需进阶至「" + targetRealm.getRealmName() + "」方可挑战"
            );
        }
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

        List<EduQuestion> shuffled = new ArrayList<>(pool);
        Collections.shuffle(shuffled);
        int takeCount = Math.min(gate.getQuestionCount(), shuffled.size());
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
                    .questionFormat(q.getQuestionFormat())
                    .stem(gen.getStem())
                    .options(gen.getOptions())
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
            snapshots.add(toSnapshot(i, q, gen));
            clientItems.add(AppQuizVO.ClientQuestionItem.builder()
                    .itemIndex(i)
                    .questionFormat(q.getQuestionFormat())
                    .stem(gen.getStem())
                    .options(gen.getOptions())
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

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.CheckItemVO checkItem(AppQuizDTO.CheckItemReq req) {
        UserQuizRecord record = loadAuthorizedSession(req.getSessionNo());
        List<SnapshotItem> snapshots = readSnapshots(record.getQuestionSnapshotJson());
        if (req.getItemIndex() < 0 || req.getItemIndex() >= snapshots.size()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "题号超出范围");
        }
        SnapshotItem item = snapshots.get(req.getItemIndex());
        item.setUserIndex(req.getSelectedIndex());
        record.setQuestionSnapshotJson(writeJson(snapshots));
        quizRecordMapper.updateById(record);

        boolean correct = Objects.equals(item.getAnswerIndex(), req.getSelectedIndex());
        return AppQuizVO.CheckItemVO.builder()
                .itemIndex(item.getItemIndex())
                .correct(correct)
                .correctIndex(item.getAnswerIndex())
                .analysis(item.getAnalysis() == null ? "" : item.getAnalysis())
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.SubmitResultVO submitGateQuiz(AppQuizDTO.SubmitReq req) {
        UserQuizRecord record = loadAuthorizedSession(req.getSessionNo());
        if (record.getStatus() != null && record.getStatus() == 1) {
            throw new BizException(ErrorCode.QUIZ_ALREADY_SUBMITTED);
        }
        List<SnapshotItem> snapshots = readSnapshots(record.getQuestionSnapshotJson());
        applyBatchAnswers(snapshots, req.getAnswers());

        int correctCount = 0;
        List<SnapshotItem> wrongSnaps = new ArrayList<>();
        List<AppQuizVO.WrongReviewItem> wrongReview = new ArrayList<>();
        for (SnapshotItem item : snapshots) {
            if (Objects.equals(item.getAnswerIndex(), item.getUserIndex())) {
                correctCount++;
            } else {
                wrongSnaps.add(item);
                wrongReview.add(toWrongReviewItem(item));
            }
        }

        EduGate gate = gateMapper.selectById(record.getGateId());
        EduChapter chapter = chapterMapper.selectById(record.getChapterId());
        int passCount = gate != null ? Math.min(gate.getPassCount(), snapshots.size()) : (int) Math.ceil(snapshots.size() * 2.0 / 3.0);
        boolean passed = correctCount >= passCount;
        int score = snapshots.isEmpty() ? 0 : (int) Math.round(correctCount * 100.0 / snapshots.size());

        record.setQuestionSnapshotJson(writeJson(snapshots));
        record.setCorrectCount(correctCount);
        record.setScore(score);
        record.setIsPassed(passed ? 1 : 0);
        record.setStatus(1);
        record.setSubmittedAt(LocalDateTime.now());
        quizRecordMapper.updateById(record);

        boolean newlyPassed = false;
        int totalPassed = 0;
        AppUserProfileVO.LevelProgress promotedLevel = null;

        Long userId = StpAppUtil.getLoginIdOrNull();
        if (userId != null && record.getUserId() != 0L) {
            AppUser user = userMapper.selectById(userId);
            int beforeTotal = user.getPassedGateCount() == null ? 0 : user.getPassedGateCount();
            AppUserProfileVO.LevelProgress beforeLevel = bankService.computeLevelProgress(beforeTotal);

            UserGateProgress prog = gateProgressMapper.selectOne(
                    new LambdaQueryWrapper<UserGateProgress>()
                            .eq(UserGateProgress::getUserId, userId)
                            .eq(UserGateProgress::getGateId, gate.getId())
                            .last("LIMIT 1")
            );
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
            totalPassed = (int) distinctPassed;
            AppUserProfileVO.LevelProgress afterLevel = bankService.computeLevelProgress(totalPassed);
            if (!Objects.equals(beforeLevel.getLevelName(), afterLevel.getLevelName())) {
                promotedLevel = afterLevel;
            }

            user.setPassedGateCount(totalPassed);
            user.setCurrentLevelId(afterLevel.getLevelId());
            user.setLastActiveAt(now);
            userMapper.updateById(user);

            recordWrongQuestions(userId, chapter, gate.getGateName(), wrongSnaps);
        }

        return AppQuizVO.SubmitResultVO.builder()
                .sessionNo(record.getSessionNo())
                .mode("GATE")
                .totalCount(snapshots.size())
                .correctCount(correctCount)
                .score(score)
                .passCount(passCount)
                .passed(passed)
                .newlyPassed(newlyPassed)
                .totalPassedGates(totalPassed)
                .promotedLevel(promotedLevel)
                .wrongItems(wrongReview)
                .masteredCount(0)
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.SubmitResultVO submitAdvanceExam(AppQuizDTO.SubmitReq req) {
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
        applyBatchAnswers(snapshots, req.getAnswers());

        int correctCount = 0;
        List<SnapshotItem> wrongSnaps = new ArrayList<>();
        List<AppQuizVO.WrongReviewItem> wrongReview = new ArrayList<>();
        for (SnapshotItem item : snapshots) {
            if (Objects.equals(item.getAnswerIndex(), item.getUserIndex())) {
                correctCount++;
            } else {
                wrongSnaps.add(item);
                wrongReview.add(toWrongReviewItem(item));
            }
        }

        EduRealm examRealm = realmHelper.findByRealmCode(record.getRealmCode());
        if (examRealm == null) {
            examRealm = realmHelper.resolveUserRealm(user);
        }
        int passScore = examRealm.getExamPassScore() == null ? 60 : examRealm.getExamPassScore();
        int score = snapshots.isEmpty() ? 0 : (int) Math.round(correctCount * 100.0 / snapshots.size());
        boolean passed = score >= passScore;

        LocalDateTime now = LocalDateTime.now();
        record.setQuestionSnapshotJson(writeJson(snapshots));
        record.setCorrectCount(correctCount);
        record.setScore(score);
        record.setIsPassed(passed ? 1 : 0);
        record.setStatus(1);
        record.setSubmittedAt(now);
        quizRecordMapper.updateById(record);

        recordExamWrongQuestions(userId, examRealm, wrongSnaps);

        AppUserProfileVO.RealmItemVO promotedRealm = null;
        if (passed) {
            EduRealm userCurrent = realmHelper.resolveUserRealm(user);
            EduRealm nextRealm = realmHelper.findNextRealm(examRealm.getRealmOrder());
            if (nextRealm != null && userCurrent.getRealmOrder() <= examRealm.getRealmOrder()) {
                user.setRealmCode(nextRealm.getRealmCode());
                user.setGradeCode(nextRealm.getGradeCode());
                user.setLastActiveAt(now);
                userMapper.updateById(user);
                promotedRealm = AppUserProfileVO.RealmItemVO.builder()
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
        }

        return AppQuizVO.SubmitResultVO.builder()
                .sessionNo(record.getSessionNo())
                .mode("ADVANCE_EXAM")
                .totalCount(snapshots.size())
                .correctCount(correctCount)
                .score(score)
                .passScore(passScore)
                .passCount((int) Math.ceil(snapshots.size() * passScore / 100.0))
                .passed(passed)
                .newlyPassed(promotedRealm != null)
                .totalPassedGates(user.getPassedGateCount() == null ? 0 : user.getPassedGateCount())
                .promotedRealm(promotedRealm)
                .wrongItems(wrongReview)
                .masteredCount(0)
                .build();
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

    public void applyBatchAnswers(List<SnapshotItem> snapshots, List<AppQuizDTO.AnswerSelection> answers) {
        if (answers == null || answers.isEmpty()) {
            return;
        }
        for (AppQuizDTO.AnswerSelection sel : answers) {
            if (sel.getItemIndex() != null && sel.getItemIndex() >= 0 && sel.getItemIndex() < snapshots.size()) {
                snapshots.get(sel.getItemIndex()).setUserIndex(sel.getSelectedIndex());
            }
        }
    }

    private SnapshotItem toSnapshot(int idx, EduQuestion q, GeneratedQuestion gen) {
        SnapshotItem snap = new SnapshotItem();
        snap.setItemIndex(idx);
        snap.setQuestionId(q.getId());
        snap.setChapterId(q.getChapterId());
        snap.setGradeCode(q.getGradeCode());
        snap.setQuestionFormat(q.getQuestionFormat());
        snap.setStem(gen.getStem());
        snap.setOptions(gen.getOptions());
        snap.setAnswerIndex(gen.getAnswerIndex());
        snap.setAnalysis(gen.getAnalysis());
        return snap;
    }

    private AppQuizVO.WrongReviewItem toWrongReviewItem(SnapshotItem item) {
        String rightOpt = (item.getOptions() != null && item.getAnswerIndex() != null
                && item.getAnswerIndex() < item.getOptions().size())
                ? item.getOptions().get(item.getAnswerIndex())
                : "";
        return AppQuizVO.WrongReviewItem.builder()
                .stem(item.getStem())
                .correctAnswer(rightOpt)
                .analysis(item.getAnalysis())
                .build();
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
        String hash = sha256(item.getStem() + "|" + writeJson(item.getOptions()));
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
            wq.setOptionsJson(writeJson(item.getOptions()));
            wq.setAnswerJson(writeJson(Map.of("index", item.getAnswerIndex())));
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
