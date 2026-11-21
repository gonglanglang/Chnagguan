package com.guoguanla.module.app;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.security.StpAppUtil;
import com.guoguanla.common.util.JsonHelper;
import com.guoguanla.module.app.dto.AppQuizDTO;
import com.guoguanla.module.app.vo.AppQuizVO;
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.progress.entity.UserQuizRecord;
import com.guoguanla.module.progress.entity.UserWrongQuestion;
import com.guoguanla.module.progress.mapper.UserQuizRecordMapper;
import com.guoguanla.module.progress.mapper.UserWrongQuestionMapper;
import com.guoguanla.module.system.RealmHelperService;
import com.guoguanla.module.system.entity.EduRealm;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AppWrongService {

    private final UserWrongQuestionMapper wrongMapper;
    private final UserQuizRecordMapper quizRecordMapper;
    private final AppQuizService quizService;
    private final RealmHelperService realmHelper;
    private final AliyunOssService ossService;
    private final ObjectMapper objectMapper;

    public PageResult<AppQuizVO.WrongQuestionVO> page(String gradeCode, String realmCode, Long chapterId, Long pageNum, Long pageSize) {
        return page(gradeCode, realmCode, chapterId, pageNum, pageSize, "");
    }

    public PageResult<AppQuizVO.WrongQuestionVO> page(String gradeCode, String realmCode, Long chapterId, Long pageNum, Long pageSize, String baseOrigin) {
        Long userId = StpAppUtil.getLoginIdAsLong();
        long p = pageNum == null || pageNum < 1 ? 1L : pageNum;
        long s = pageSize == null || pageSize < 1 ? 20L : Math.min(pageSize, 100L);

        String effectiveGrade = (realmCode != null && !realmCode.isBlank())
                ? realmHelper.resolveGradeCode(realmCode, gradeCode)
                : gradeCode;

        LambdaQueryWrapper<UserWrongQuestion> wrapper = new LambdaQueryWrapper<UserWrongQuestion>()
                .eq(UserWrongQuestion::getUserId, userId)
                .eq(UserWrongQuestion::getIsMastered, 0);
        if (effectiveGrade != null && !effectiveGrade.isBlank()) {
            wrapper.eq(UserWrongQuestion::getGradeCode, effectiveGrade.trim());
        }
        if (chapterId != null) {
            wrapper.eq(UserWrongQuestion::getChapterId, chapterId);
        }
        wrapper.orderByDesc(UserWrongQuestion::getLastWrongAt);

        Map<String, EduRealm> realmByGrade = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getGradeCode, r -> r, (a, b) -> a));

        Page<UserWrongQuestion> page = wrongMapper.selectPage(new Page<>(p, s), wrapper);
        List<AppQuizVO.WrongQuestionVO> items = page.getRecords().stream()
                .map(w -> {
                    EduRealm realm = realmByGrade.get(w.getGradeCode());
                    String fmt = normalizeFormat(w.getQuestionFormat());
                    return AppQuizVO.WrongQuestionVO.builder()
                            .id(w.getId())
                            .gradeCode(w.getGradeCode())
                            .realmCode(realm != null ? realm.getRealmCode() : "")
                            .realmName(realm != null ? realm.getRealmName() : "")
                            .chapterId(w.getChapterId())
                            .chapterName(w.getChapterName())
                            .gateName(w.getGateName())
                            .questionFormat(fmt)
                            .stem(w.getStem())
                            .options(parseOptions(w.getOptionsJson()))
                            .answerIndex(parseAnswerIndex(w.getAnswerJson()))
                            .referenceAnswer(parseReferenceAnswer(w.getAnswerJson()))
                            .lastAnswerImageUrl(ossService.resolveViewUrl(w.getLastAnswerImageKey(), baseOrigin))
                            .analysis(w.getAnalysis())
                            .wrongCount(w.getWrongCount())
                            .lastWrongAt(w.getLastWrongAt())
                            .build();
                })
                .toList();
        return PageResult.of(items, page.getTotal(), p, s);
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.StartVO startRedo(AppQuizDTO.RedoStartReq req) {
        Long userId = StpAppUtil.getLoginIdAsLong();
        int limit = req.getLimit() == null ? 5 : Math.max(1, Math.min(req.getLimit(), 10));

        String effectiveGrade = (req.getRealmCode() != null && !req.getRealmCode().isBlank())
                ? realmHelper.resolveGradeCode(req.getRealmCode(), req.getGradeCode())
                : req.getGradeCode();

        LambdaQueryWrapper<UserWrongQuestion> wrapper = new LambdaQueryWrapper<UserWrongQuestion>()
                .eq(UserWrongQuestion::getUserId, userId)
                .eq(UserWrongQuestion::getIsMastered, 0);
        if (effectiveGrade != null && !effectiveGrade.isBlank()) {
            wrapper.eq(UserWrongQuestion::getGradeCode, effectiveGrade.trim());
        }
        if (req.getChapterId() != null) {
            wrapper.eq(UserWrongQuestion::getChapterId, req.getChapterId());
        }
        wrapper.orderByDesc(UserWrongQuestion::getLastWrongAt).last("LIMIT " + limit);

        List<UserWrongQuestion> wrongs = wrongMapper.selectList(wrapper);
        if (wrongs.isEmpty()) {
            throw new BizException(ErrorCode.NOT_FOUND, "暂无待消灭的错题");
        }

        List<AppQuizService.SnapshotItem> snapshots = new ArrayList<>(wrongs.size());
        List<AppQuizVO.ClientQuestionItem> clientItems = new ArrayList<>(wrongs.size());
        for (int i = 0; i < wrongs.size(); i++) {
            UserWrongQuestion w = wrongs.get(i);
            String fmt = normalizeFormat(w.getQuestionFormat());
            List<String> opts = parseOptions(w.getOptionsJson());
            int ansIdx = parseAnswerIndex(w.getAnswerJson());
            String refAns = "ESSAY".equals(fmt)
                    ? parseReferenceAnswer(w.getAnswerJson())
                    : ((ansIdx >= 0 && ansIdx < opts.size()) ? opts.get(ansIdx) : "");

            AppQuizService.SnapshotItem snap = new AppQuizService.SnapshotItem();
            snap.setItemIndex(i);
            snap.setQuestionId(w.getQuestionId());
            snap.setChapterId(w.getChapterId());
            snap.setGradeCode(w.getGradeCode());
            snap.setWrongId(w.getId());
            snap.setQuestionFormat(fmt);
            snap.setStem(w.getStem());
            snap.setOptions(opts);
            snap.setAnswerIndex(ansIdx);
            snap.setReferenceAnswer(refAns);
            snap.setAnalysis(w.getAnalysis());
            snapshots.add(snap);

            clientItems.add(AppQuizVO.ClientQuestionItem.builder()
                    .itemIndex(i)
                    .questionFormat(fmt)
                    .stem(w.getStem())
                    .options(opts)
                    .build());
        }

        String sessionNo = "RD" + UUID.randomUUID().toString().replace("-", "").substring(0, 16).toUpperCase();
        UserQuizRecord record = new UserQuizRecord();
        record.setSessionNo(sessionNo);
        record.setUserId(userId);
        record.setMode("REDO_WRONG");
        record.setQuestionSnapshotJson(quizService.writeJson(snapshots));
        record.setTotalCount(clientItems.size());
        record.setCorrectCount(0);
        record.setIsPassed(0);
        record.setStatus(0);
        record.setStartedAt(LocalDateTime.now());
        quizRecordMapper.insert(record);

        int passNeed = (int) Math.ceil(clientItems.size() * 2.0 / 3.0);
        return AppQuizVO.StartVO.builder()
                .sessionNo(sessionNo)
                .mode("REDO_WRONG")
                .chapterName("错题重做")
                .gateName("消灭错题")
                .star(0)
                .passCount(passNeed)
                .totalCount(clientItems.size())
                .guestMode(false)
                .items(clientItems)
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public AppQuizVO.SubmitResultVO submitRedo(AppQuizDTO.SubmitReq req) {
        UserQuizRecord record = quizService.loadAuthorizedSession(req.getSessionNo());
        if (record.getStatus() != null && record.getStatus() == 1) {
            throw new BizException(ErrorCode.QUIZ_ALREADY_SUBMITTED);
        }
        List<AppQuizService.SnapshotItem> snapshots = quizService.readSnapshots(record.getQuestionSnapshotJson());
        quizService.applyBatchAnswers(record, snapshots, req.getAnswers());

        int correctCount = 0;
        int pendingReviewCount = 0;
        int masteredCount = 0;
        List<AppQuizVO.WrongReviewItem> stillWrong = new ArrayList<>();
        LocalDateTime now = LocalDateTime.now();

        for (AppQuizService.SnapshotItem item : snapshots) {
            boolean right = quizService.isSnapshotItemCorrect(item);
            boolean pendingReview = quizService.isEssaySubmittedPendingReview(item);
            UserWrongQuestion wq = item.getWrongId() != null ? wrongMapper.selectById(item.getWrongId()) : null;
            if (right) {
                correctCount++;
                if (wq != null) {
                    wq.setIsMastered(1);
                    wq.setMasteredAt(now);
                    if (item.getUserAnswerImageKey() != null && !item.getUserAnswerImageKey().isBlank()) {
                        wq.setLastAnswerImageKey(item.getUserAnswerImageKey());
                    }
                    wrongMapper.updateById(wq);
                    masteredCount++;
                }
            } else if (pendingReview) {
                pendingReviewCount++;
                if (wq != null && item.getUserAnswerImageKey() != null && !item.getUserAnswerImageKey().isBlank()) {
                    wq.setLastAnswerImageKey(item.getUserAnswerImageKey());
                    wrongMapper.updateById(wq);
                }
            } else {
                if (wq != null) {
                    wq.setWrongCount((wq.getWrongCount() == null ? 0 : wq.getWrongCount()) + 1);
                    wq.setLastWrongAt(now);
                    if (item.getUserAnswerImageKey() != null && !item.getUserAnswerImageKey().isBlank()) {
                        wq.setLastAnswerImageKey(item.getUserAnswerImageKey());
                    }
                    wrongMapper.updateById(wq);
                }
                stillWrong.add(quizService.toWrongReviewItem(item));
            }
        }

        int passNeed = (int) Math.ceil(snapshots.size() * 2.0 / 3.0);
        boolean passed = correctCount >= passNeed;
        record.setQuestionSnapshotJson(quizService.writeJson(snapshots));
        record.setCorrectCount(correctCount);
        record.setIsPassed(passed ? 1 : 0);
        record.setStatus(1);
        record.setSubmittedAt(now);
        quizRecordMapper.updateById(record);

        return AppQuizVO.SubmitResultVO.builder()
                .sessionNo(record.getSessionNo())
                .mode("REDO_WRONG")
                .totalCount(snapshots.size())
                .correctCount(correctCount)
                .pendingReviewCount(pendingReviewCount)
                .passCount(passNeed)
                .passed(passed)
                .newlyPassed(false)
                .wrongItems(stillWrong)
                .masteredCount(masteredCount)
                .build();
    }

    public void markMastered(Long wrongId) {
        Long userId = StpAppUtil.getLoginIdAsLong();
        UserWrongQuestion wq = wrongMapper.selectById(wrongId);
        if (wq == null || !Objects.equals(wq.getUserId(), userId)) {
            throw new BizException(ErrorCode.NOT_FOUND, "错题记录不存在");
        }
        wq.setIsMastered(1);
        wq.setMasteredAt(LocalDateTime.now());
        wrongMapper.updateById(wq);
    }

    public void clearAll() {
        Long userId = StpAppUtil.getLoginIdAsLong();
        wrongMapper.update(null, new LambdaUpdateWrapper<UserWrongQuestion>()
                .eq(UserWrongQuestion::getUserId, userId)
                .eq(UserWrongQuestion::getIsMastered, 0)
                .set(UserWrongQuestion::getIsMastered, 1)
                .set(UserWrongQuestion::getMasteredAt, LocalDateTime.now()));
    }

    private String normalizeFormat(String format) {
        if (format == null || format.isBlank()) {
            return "SINGLE_CHOICE";
        }
        return format.trim().toUpperCase(Locale.ROOT);
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
