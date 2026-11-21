package com.guoguanla.module.bank;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.security.StpAdminUtil;
import com.guoguanla.common.util.JsonHelper;
import com.guoguanla.module.bank.dto.*;
import com.guoguanla.module.bank.entity.EduChapter;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.entity.EduGrade;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduChapterMapper;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.bank.mapper.EduGradeMapper;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import com.guoguanla.module.bank.vo.ChapterVO;
import com.guoguanla.module.bank.vo.GateVO;
import com.guoguanla.module.bank.vo.QuestionVO;
import com.guoguanla.module.engine.GeneratedQuestion;
import com.guoguanla.module.engine.QuestionEngineService;
import com.guoguanla.module.system.RealmHelperService;
import com.guoguanla.module.system.entity.EduRealm;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminBankService {

    private static final List<String> DEFAULT_GATE_NAMES = List.of("基础关", "中档关", "拓展关", "压轴关");

    private final EduGradeMapper gradeMapper;
    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final EduQuestionMapper questionMapper;
    private final QuestionEngineService engineService;
    private final RealmHelperService realmHelper;
    private final ObjectMapper objectMapper;

    public List<EduGrade> listGrades() {
        return gradeMapper.selectList(
                new LambdaQueryWrapper<EduGrade>().orderByAsc(EduGrade::getSortOrder)
        );
    }

    public void updateGrade(Long id, Integer enabled, String icon, String gradeName) {
        EduGrade grade = gradeMapper.selectById(id);
        if (grade == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "年级不存在");
        }
        if (enabled != null) grade.setEnabled(enabled);
        if (icon != null && !icon.isBlank()) grade.setIcon(icon.trim());
        if (gradeName != null && !gradeName.isBlank()) grade.setGradeName(gradeName.trim());
        gradeMapper.updateById(grade);
    }

    public List<ChapterVO> listChapters(String gradeCode, String realmCode, String keyword, Integer enabled) {
        String effectiveGrade = (realmCode != null && !realmCode.isBlank())
                ? realmHelper.resolveGradeCode(realmCode, gradeCode)
                : gradeCode;
        LambdaQueryWrapper<EduChapter> wrapper = new LambdaQueryWrapper<>();
        if (effectiveGrade != null && !effectiveGrade.isBlank()) {
            wrapper.eq(EduChapter::getGradeCode, effectiveGrade.trim());
        }
        if (keyword != null && !keyword.isBlank()) {
            String kw = keyword.trim();
            wrapper.and(w -> w.like(EduChapter::getName, kw)
                    .or().like(EduChapter::getDescription, kw)
                    .or().like(EduChapter::getChapterCode, kw));
        }
        if (enabled != null) {
            wrapper.eq(EduChapter::getEnabled, enabled);
        }
        wrapper.orderByAsc(EduChapter::getSortOrder).orderByAsc(EduChapter::getId);

        List<EduChapter> chapters = chapterMapper.selectList(wrapper);
        if (chapters.isEmpty()) {
            return List.of();
        }
        Map<String, String> gradeNameMap = gradeNameMap();
        Map<String, EduRealm> realmByGrade = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getGradeCode, r -> r, (a, b) -> a));
        List<Long> chapIds = chapters.stream().map(EduChapter::getId).toList();
        Map<Long, Long> gateCountMap = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>().in(EduGate::getChapterId, chapIds)
        ).stream().collect(Collectors.groupingBy(EduGate::getChapterId, Collectors.counting()));
        Map<Long, Long> qCountMap = questionMapper.selectList(
                new LambdaQueryWrapper<EduQuestion>().in(EduQuestion::getChapterId, chapIds)
        ).stream().collect(Collectors.groupingBy(EduQuestion::getChapterId, Collectors.counting()));

        return chapters.stream()
                .map(c -> {
                    EduRealm realm = realmByGrade.get(c.getGradeCode());
                    return ChapterVO.builder()
                            .id(c.getId())
                            .chapterCode(c.getChapterCode())
                            .gradeCode(c.getGradeCode())
                            .gradeName(gradeNameMap.getOrDefault(c.getGradeCode(), c.getGradeCode()))
                            .realmCode(realm != null ? realm.getRealmCode() : "")
                            .realmName(realm != null ? realm.getRealmName() : "")
                            .name(c.getName())
                            .description(c.getDescription())
                            .isCustom(c.getIsCustom())
                            .sortOrder(c.getSortOrder())
                            .enabled(c.getEnabled())
                            .gateCount(gateCountMap.getOrDefault(c.getId(), 0L))
                            .questionCount(qCountMap.getOrDefault(c.getId(), 0L))
                            .updatedAt(c.getUpdatedAt())
                            .build();
                })
                .toList();
    }

    @Transactional(rollbackFor = Exception.class)
    public Long createChapter(ChapterSaveReq req) {
        String code = (req.getChapterCode() == null || req.getChapterCode().isBlank())
                ? "cu-" + req.getGradeCode() + "-" + Long.toString(System.currentTimeMillis(), 36)
                : req.getChapterCode().trim();
        long exists = chapterMapper.selectCount(
                new LambdaQueryWrapper<EduChapter>().eq(EduChapter::getChapterCode, code)
        );
        if (exists > 0) {
            throw new BizException(ErrorCode.CHAPTER_CODE_EXISTS);
        }
        EduChapter ch = new EduChapter();
        ch.setChapterCode(code);
        ch.setGradeCode(req.getGradeCode().trim());
        ch.setName(req.getName().trim());
        ch.setDescription(req.getDescription() == null ? "" : req.getDescription().trim());
        ch.setIsCustom(1);
        ch.setSortOrder(req.getSortOrder() == null ? 0 : req.getSortOrder());
        ch.setEnabled(req.getEnabled() == null ? 1 : req.getEnabled());
        ch.setCreatedBy(currentAdminIdOrNull());
        chapterMapper.insert(ch);

        // 自动初始化默认 4 道关卡
        for (int i = 0; i < DEFAULT_GATE_NAMES.size(); i++) {
            EduGate gate = new EduGate();
            gate.setChapterId(ch.getId());
            gate.setGateIndex(i);
            gate.setGateName(DEFAULT_GATE_NAMES.get(i));
            gate.setStar(i + 1);
            gate.setQuestionCount(3);
            gate.setPassCount(2);
            gate.setEnabled(1);
            gateMapper.insert(gate);
        }
        return ch.getId();
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateChapter(Long id, ChapterSaveReq req) {
        EduChapter ch = chapterMapper.selectById(id);
        if (ch == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "章节不存在");
        }
        ch.setGradeCode(req.getGradeCode().trim());
        ch.setName(req.getName().trim());
        ch.setDescription(req.getDescription() == null ? "" : req.getDescription().trim());
        if (req.getSortOrder() != null) ch.setSortOrder(req.getSortOrder());
        if (req.getEnabled() != null) ch.setEnabled(req.getEnabled());
        chapterMapper.updateById(ch);
    }

    @Transactional(rollbackFor = Exception.class)
    public void deleteChapter(Long id) {
        chapterMapper.deleteById(id);
        gateMapper.delete(new LambdaQueryWrapper<EduGate>().eq(EduGate::getChapterId, id));
        questionMapper.delete(new LambdaQueryWrapper<EduQuestion>().eq(EduQuestion::getChapterId, id));
    }

    public List<GateVO> listGatesByChapter(Long chapterId) {
        List<EduGate> gates = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .eq(EduGate::getChapterId, chapterId)
                        .orderByAsc(EduGate::getGateIndex)
        );
        if (gates.isEmpty()) {
            return List.of();
        }
        List<Long> gateIds = gates.stream().map(EduGate::getId).toList();
        Map<Long, Long> qCountMap = questionMapper.selectList(
                new LambdaQueryWrapper<EduQuestion>()
                        .in(EduQuestion::getGateId, gateIds)
                        .eq(EduQuestion::getEnabled, 1)
        ).stream().collect(Collectors.groupingBy(EduQuestion::getGateId, Collectors.counting()));

        return gates.stream()
                .map(g -> GateVO.builder()
                        .id(g.getId())
                        .chapterId(g.getChapterId())
                        .gateIndex(g.getGateIndex())
                        .gateName(g.getGateName())
                        .star(g.getStar())
                        .questionCount(g.getQuestionCount())
                        .passCount(g.getPassCount())
                        .enabled(g.getEnabled())
                        .actualQuestionCount(qCountMap.getOrDefault(g.getId(), 0L))
                        .build())
                .toList();
    }

    public void updateGate(Long gateId, GateUpdateReq req) {
        EduGate gate = gateMapper.selectById(gateId);
        if (gate == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "关卡不存在");
        }
        if (req.getPassCount() > req.getQuestionCount()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "过关需答对题数不能大于抽题数");
        }
        gate.setGateName(req.getGateName().trim());
        gate.setStar(req.getStar());
        gate.setQuestionCount(req.getQuestionCount());
        gate.setPassCount(req.getPassCount());
        gate.setEnabled(req.getEnabled());
        gateMapper.updateById(gate);
    }

    public PageResult<QuestionVO> pageQuestions(QuestionQueryReq req) {
        long pageNum = req.getPageNum() == null || req.getPageNum() < 1 ? 1L : req.getPageNum();
        long pageSize = req.getPageSize() == null || req.getPageSize() < 1 ? 10L : Math.min(req.getPageSize(), 100L);

        LambdaQueryWrapper<EduQuestion> wrapper = buildQuestionWrapper(req);
        Page<EduQuestion> page = questionMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        List<QuestionVO> records = toQuestionVOs(page.getRecords());
        return PageResult.of(records, page.getTotal(), pageNum, pageSize);
    }

    public QuestionVO getQuestion(Long id) {
        EduQuestion q = questionMapper.selectById(id);
        if (q == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "题目不存在");
        }
        return toQuestionVOs(List.of(q)).get(0);
    }

    @Transactional(rollbackFor = Exception.class)
    public Long createQuestion(QuestionSaveReq req) {
        validateQuestionReq(req);
        EduQuestion q = new EduQuestion();
        applyQuestionSaveReq(q, req);
        q.setSource("ADMIN");
        q.setVersion(1);
        q.setCreatedBy(currentAdminIdOrNull());
        questionMapper.insert(q);
        if (Objects.equals(q.getEnabled(), 1)) {
            syncGateQuestionCountIfNeeded(q.getGateId(), req.getSyncGateCount());
        }
        return q.getId();
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateQuestion(Long id, QuestionSaveReq req) {
        validateQuestionReq(req);
        EduQuestion q = questionMapper.selectById(id);
        if (q == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "题目不存在");
        }
        applyQuestionSaveReq(q, req);
        q.setVersion((q.getVersion() == null ? 1 : q.getVersion()) + 1);
        questionMapper.updateById(q);
        if (Objects.equals(q.getEnabled(), 1)) {
            syncGateQuestionCountIfNeeded(q.getGateId(), req.getSyncGateCount());
        }
    }

    public void updateQuestionStatus(Long id, Integer enabled) {
        EduQuestion q = questionMapper.selectById(id);
        if (q == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "题目不存在");
        }
        q.setEnabled(enabled);
        questionMapper.updateById(q);
        if (Objects.equals(enabled, 1)) {
            syncGateQuestionCountIfNeeded(q.getGateId(), Boolean.TRUE);
        }
    }

    public void deleteQuestion(Long id) {
        questionMapper.deleteById(id);
    }

    public List<GeneratedQuestion> previewGenerate(QuestionPreviewReq req) {
        EduQuestion target;
        if (req.getQuestionId() != null) {
            target = questionMapper.selectById(req.getQuestionId());
            if (target == null) {
                throw new BizException(ErrorCode.NOT_FOUND, "题目不存在");
            }
        } else {
            target = new EduQuestion();
            target.setQuestionMode(req.getQuestionMode());
            target.setQuestionFormat(req.getQuestionFormat() == null ? "SINGLE_CHOICE" : req.getQuestionFormat());
            target.setStem(req.getStem());
            target.setTemplateRuleJson(writeJson(req.getTemplateRule()));
            target.setAnalysis(req.getAnalysis());
        }
        int cnt = req.getCount() == null ? 3 : req.getCount();
        return engineService.previewGenerate(target, cnt);
    }

    @Transactional(rollbackFor = Exception.class)
    public int importQuestionsJson(QuestionImportReq req) {
        EduChapter ch = chapterMapper.selectById(req.getChapterId());
        EduGate gt = gateMapper.selectById(req.getGateId());
        if (ch == null || gt == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "目标章节或关卡不存在");
        }
        int imported = 0;
        for (QuestionImportReq.Item item : req.getItems()) {
            String stem = item.getStem() != null && !item.getStem().isBlank() ? item.getStem().trim() : (item.getQ() == null ? "" : item.getQ().trim());
            List<String> opts = item.getOptions() != null && !item.getOptions().isEmpty() ? item.getOptions() : item.getO();
            Integer ansIdx = item.getAnswerIndex() != null ? item.getAnswerIndex() : item.getA();
            if (stem.isBlank() || opts == null || opts.size() < 2 || ansIdx == null || ansIdx < 0 || ansIdx >= opts.size()) {
                throw new BizException(ErrorCode.IMPORT_FORMAT_INVALID, "存在格式不合法的题目: " + stem);
            }
            EduQuestion q = new EduQuestion();
            q.setGradeCode(ch.getGradeCode());
            q.setChapterId(ch.getId());
            q.setGateId(gt.getId());
            q.setQuestionMode("STATIC");
            q.setQuestionFormat("SINGLE_CHOICE");
            q.setStem(stem);
            q.setOptionsJson(writeJson(opts));
            q.setAnswerJson(writeJson(Map.of("index", ansIdx)));
            q.setAnalysis(item.getAnalysis() == null ? "" : item.getAnalysis());
            q.setDifficulty(gt.getStar());
            q.setTagsJson(writeJson(List.of(ch.getName())));
            q.setSource("IMPORT");
            q.setVersion(1);
            q.setSortOrder(++imported);
            q.setEnabled(1);
            q.setCreatedBy(currentAdminIdOrNull());
            questionMapper.insert(q);
        }
        return imported;
    }

    public List<QuestionVO> exportQuestions(QuestionQueryReq req) {
        req.setPageNum(1L);
        req.setPageSize(2000L);
        LambdaQueryWrapper<EduQuestion> wrapper = buildQuestionWrapper(req);
        List<EduQuestion> list = questionMapper.selectList(wrapper);
        return toQuestionVOs(list);
    }

    private LambdaQueryWrapper<EduQuestion> buildQuestionWrapper(QuestionQueryReq req) {
        LambdaQueryWrapper<EduQuestion> wrapper = new LambdaQueryWrapper<>();
        String effectiveGrade = (req.getRealmCode() != null && !req.getRealmCode().isBlank())
                ? realmHelper.resolveGradeCode(req.getRealmCode(), req.getGradeCode())
                : req.getGradeCode();
        if (effectiveGrade != null && !effectiveGrade.isBlank()) {
            wrapper.eq(EduQuestion::getGradeCode, effectiveGrade.trim());
        }
        if (req.getChapterId() != null) {
            wrapper.eq(EduQuestion::getChapterId, req.getChapterId());
        }
        if (req.getGateId() != null) {
            wrapper.eq(EduQuestion::getGateId, req.getGateId());
        }
        if (req.getQuestionMode() != null && !req.getQuestionMode().isBlank()) {
            wrapper.eq(EduQuestion::getQuestionMode, req.getQuestionMode().trim());
        }
        if (req.getQuestionFormat() != null && !req.getQuestionFormat().isBlank()) {
            wrapper.eq(EduQuestion::getQuestionFormat, req.getQuestionFormat().trim());
        }
        if (req.getEnabled() != null) {
            wrapper.eq(EduQuestion::getEnabled, req.getEnabled());
        }
        if (req.getKeyword() != null && !req.getKeyword().isBlank()) {
            String kw = req.getKeyword().trim();
            wrapper.and(w -> w.like(EduQuestion::getStem, kw).or().like(EduQuestion::getGeneratorCode, kw));
        }
        wrapper.orderByDesc(EduQuestion::getId);
        return wrapper;
    }

    private void validateQuestionReq(QuestionSaveReq req) {
        String fmt = req.getQuestionFormat() == null ? "SINGLE_CHOICE" : req.getQuestionFormat().trim().toUpperCase(Locale.ROOT);
        req.setQuestionFormat(fmt);
        if ("DYNAMIC_TEMPLATE".equalsIgnoreCase(req.getQuestionMode())) {
            if (req.getTemplateRule() == null || req.getTemplateRule().isEmpty()) {
                throw new BizException(ErrorCode.BAD_REQUEST, "动态题必须提供 templateRule 规则");
            }
            EduQuestion probe = new EduQuestion();
            probe.setQuestionMode("DYNAMIC_TEMPLATE");
            probe.setQuestionFormat(fmt);
            probe.setTemplateRuleJson(writeJson(req.getTemplateRule()));
            probe.setAnalysis(req.getAnalysis());
            GeneratedQuestion sample = engineService.generateOne(probe);
            if ("PARAM_TEMPLATE".equalsIgnoreCase(String.valueOf(req.getTemplateRule().get("type")))
                    || req.getStem() == null || req.getStem().isBlank() || req.getStem().contains("{{")) {
                req.setStem(sample.getStem());
            }
            if ("ESSAY".equals(fmt)) {
                req.setOptions(List.of());
                req.setAnswer(Map.of("text", sample.getReferenceAnswer() == null ? "" : sample.getReferenceAnswer()));
            } else {
                req.setOptions(sample.getOptions());
                req.setAnswer(Map.of("index", sample.getAnswerIndex() == null ? 0 : sample.getAnswerIndex()));
            }
        } else {
            if (req.getStem() == null || req.getStem().isBlank()) {
                throw new BizException(ErrorCode.BAD_REQUEST, "题干不能为空");
            }
            if ("ESSAY".equals(fmt)) {
                req.setOptions(List.of());
                String refText = req.getAnswer() != null && req.getAnswer().get("text") != null
                        ? String.valueOf(req.getAnswer().get("text"))
                        : "";
                req.setAnswer(Map.of("text", refText));
            } else {
                if (("SINGLE_CHOICE".equals(fmt) || "MULTI_CHOICE".equals(fmt) || "JUDGE".equals(fmt))
                        && (req.getOptions() == null || req.getOptions().size() < 2)) {
                    throw new BizException(ErrorCode.BAD_REQUEST, "选择题至少需要 2 个选项");
                }
                if (req.getAnswer() == null || req.getAnswer().isEmpty()) {
                    throw new BizException(ErrorCode.BAD_REQUEST, "请指定标准答案");
                }
            }
        }
    }

    private void syncGateQuestionCountIfNeeded(Long gateId, Boolean syncFlag) {
        if (Boolean.FALSE.equals(syncFlag) || gateId == null) {
            return;
        }
        EduGate gate = gateMapper.selectById(gateId);
        if (gate == null) {
            return;
        }
        long enabledCount = questionMapper.selectCount(
                new LambdaQueryWrapper<EduQuestion>()
                        .eq(EduQuestion::getGateId, gateId)
                        .eq(EduQuestion::getEnabled, 1)
        );
        int currentTarget = gate.getQuestionCount() == null ? 0 : gate.getQuestionCount();
        if (enabledCount > currentTarget) {
            gate.setQuestionCount((int) enabledCount);
            gateMapper.updateById(gate);
        }
    }

    private void applyQuestionSaveReq(EduQuestion q, QuestionSaveReq req) {
        q.setGradeCode(req.getGradeCode().trim());
        q.setChapterId(req.getChapterId());
        q.setGateId(req.getGateId());
        q.setQuestionMode(req.getQuestionMode().trim());
        q.setQuestionFormat(req.getQuestionFormat().trim());
        q.setStem(req.getStem().trim());
        q.setOptionsJson(writeJson(req.getOptions() == null ? List.of() : req.getOptions()));
        q.setAnswerJson(writeJson(req.getAnswer() == null ? Map.of() : req.getAnswer()));
        q.setAnalysis(req.getAnalysis() == null ? "" : req.getAnalysis().trim());
        q.setGeneratorCode(req.getGeneratorCode());
        q.setTemplateRuleJson(req.getTemplateRule() == null ? null : writeJson(req.getTemplateRule()));
        q.setDifficulty(req.getDifficulty() == null ? 1 : req.getDifficulty());
        q.setTagsJson(req.getTags() == null ? null : writeJson(req.getTags()));
        q.setExtJson(req.getExt() == null ? null : writeJson(req.getExt()));
        q.setSortOrder(req.getSortOrder() == null ? 0 : req.getSortOrder());
        q.setEnabled(req.getEnabled() == null ? 1 : req.getEnabled());
    }

    private List<QuestionVO> toQuestionVOs(List<EduQuestion> questions) {
        if (questions.isEmpty()) {
            return List.of();
        }
        Map<String, String> gradeMap = gradeNameMap();
        Map<String, EduRealm> realmByGrade = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getGradeCode, r -> r, (a, b) -> a));
        Set<Long> chapIds = questions.stream().map(EduQuestion::getChapterId).collect(Collectors.toSet());
        Set<Long> gateIds = questions.stream().map(EduQuestion::getGateId).collect(Collectors.toSet());
        Map<Long, String> chapMap = chapterMapper.selectBatchIds(chapIds).stream()
                .collect(Collectors.toMap(EduChapter::getId, EduChapter::getName, (a, b) -> a));
        Map<Long, String> gateMap = gateMapper.selectBatchIds(gateIds).stream()
                .collect(Collectors.toMap(EduGate::getId, EduGate::getGateName, (a, b) -> a));

        return questions.stream()
                .map(q -> {
                    EduRealm realm = realmByGrade.get(q.getGradeCode());
                    return QuestionVO.builder()
                            .id(q.getId())
                            .gradeCode(q.getGradeCode())
                            .gradeName(gradeMap.getOrDefault(q.getGradeCode(), q.getGradeCode()))
                            .realmCode(realm != null ? realm.getRealmCode() : "")
                            .realmName(realm != null ? realm.getRealmName() : "")
                            .chapterId(q.getChapterId())
                        .chapterName(chapMap.getOrDefault(q.getChapterId(), ""))
                        .gateId(q.getGateId())
                        .gateName(gateMap.getOrDefault(q.getGateId(), ""))
                        .questionMode(q.getQuestionMode())
                        .questionFormat(q.getQuestionFormat())
                        .stem(q.getStem())
                        .options(readList(q.getOptionsJson()))
                        .answer(readMap(q.getAnswerJson()))
                        .analysis(q.getAnalysis())
                        .generatorCode(q.getGeneratorCode())
                        .templateRule(readMap(q.getTemplateRuleJson()))
                        .difficulty(q.getDifficulty())
                        .tags(readList(q.getTagsJson()))
                        .ext(readMap(q.getExtJson()))
                        .source(q.getSource())
                        .version(q.getVersion())
                            .sortOrder(q.getSortOrder())
                            .enabled(q.getEnabled())
                            .updatedAt(q.getUpdatedAt())
                            .build();
                })
                .toList();
    }

    private Map<String, String> gradeNameMap() {
        return gradeMapper.selectList(null).stream()
                .collect(Collectors.toMap(EduGrade::getGradeCode, EduGrade::getGradeName, (a, b) -> a));
    }

    private Long currentAdminIdOrNull() {
        try {
            return StpAdminUtil.isLogin() ? StpAdminUtil.getLoginIdAsLong() : null;
        } catch (Exception e) {
            return null;
        }
    }

    private String writeJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            throw new BizException(ErrorCode.BAD_REQUEST, "JSON 序列化失败");
        }
    }

    private List<String> readList(String json) {
        return JsonHelper.readStringList(objectMapper, json);
    }

    private Map<String, Object> readMap(String json) {
        return JsonHelper.readMap(objectMapper, json);
    }
}
