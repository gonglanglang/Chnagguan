package com.guoguanla.module.system;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.util.JsonHelper;
import com.guoguanla.module.bank.entity.EduChapter;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduChapterMapper;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.io.InputStream;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 幂等题库几何/函数矢量配图回填与 JSXGraph 制图工作台新题种子器：
 * 1. 自动为尚未设置 diagram / imageUrl / imageKey 的存量可视化题目补齐带 studioState 的矢量配图；
 * 2. 自动为缺少 studioState 的历史内置配图升级补齐 JSXGraph 可编辑 studioState（严禁覆盖管理员手动上传的图片或已含 studioState 的编辑结果）；
 * 3. 幂等导入由新制图工具生成的带图题目（db/studio-diagram-questions.json），按 (gate_id, stem) 去重，不重复插入。
 */
@Slf4j
@Order(3)
@Component
@RequiredArgsConstructor
public class QuestionDiagramBackfillRunner implements ApplicationRunner {

    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final EduQuestionMapper questionMapper;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void run(ApplicationArguments args) throws Exception {
        List<EduChapter> chapters = chapterMapper.selectList(null);
        List<EduGate> gates = gateMapper.selectList(null);

        Map<Long, String> chapterCodeById = chapters.stream()
                .collect(Collectors.toMap(EduChapter::getId, EduChapter::getChapterCode, (a, b) -> a));
        Map<String, EduChapter> chapterByCode = chapters.stream()
                .filter(c -> c.getChapterCode() != null && !c.getChapterCode().isBlank())
                .collect(Collectors.toMap(EduChapter::getChapterCode, c -> c, (a, b) -> a));
        Map<Long, Integer> gateIndexById = gates.stream()
                .collect(Collectors.toMap(EduGate::getId, EduGate::getGateIndex, (a, b) -> a));
        Map<String, EduGate> gateByChapterAndIndex = gates.stream()
                .collect(Collectors.toMap(
                        g -> g.getChapterId() + ":" + g.getGateIndex(),
                        g -> g,
                        (a, b) -> a
                ));

        backfillAndUpgradeDiagrams(chapterCodeById, gateIndexById);
        seedStudioDiagramQuestions(chapterByCode, gateByChapterAndIndex);
    }

    private void backfillAndUpgradeDiagrams(
            Map<Long, String> chapterCodeById,
            Map<Long, Integer> gateIndexById
    ) throws Exception {
        ClassPathResource resource = new ClassPathResource("db/question-diagrams.json");
        if (!resource.exists()) {
            log.debug("question-diagrams.json not found, skipping question diagram backfill");
            return;
        }

        Map<String, Object> bySlotKey = new HashMap<>();
        Map<String, Object> byStem = new HashMap<>();
        try (InputStream is = resource.getInputStream()) {
            JsonNode root = objectMapper.readTree(is);
            for (JsonNode item : root.path("items")) {
                String key = item.path("key").asText("");
                String stem = item.path("stem").asText("");
                JsonNode diagramNode = item.path("diagram");
                if (diagramNode.isMissingNode() || diagramNode.isNull()) continue;
                Object diagramObj = objectMapper.convertValue(diagramNode, Map.class);
                if (!key.isBlank()) {
                    bySlotKey.put(key, diagramObj);
                }
                if (!stem.isBlank()) {
                    byStem.put(stem.trim(), diagramObj);
                }
            }
        }
        if (bySlotKey.isEmpty() && byStem.isEmpty()) {
            return;
        }

        List<EduQuestion> questions = questionMapper.selectList(
                new LambdaQueryWrapper<EduQuestion>().eq(EduQuestion::getEnabled, 1)
        );
        int backfilled = 0;
        int upgraded = 0;
        for (EduQuestion q : questions) {
            Map<String, Object> ext = JsonHelper.readMap(objectMapper, q.getExtJson());
            if (hasUploadedImage(ext) || hasStudioDiagram(ext)) {
                continue;
            }
            boolean hadLegacyDiagram = hasLegacyDiagramWithoutStudio(ext);

            String chapCode = chapterCodeById.get(q.getChapterId());
            Integer gateIdx = gateIndexById.get(q.getGateId());
            Object matchedDiagram = null;
            if (chapCode != null && gateIdx != null && q.getSortOrder() != null) {
                matchedDiagram = bySlotKey.get(chapCode + ":" + gateIdx + ":" + q.getSortOrder());
            }
            if (matchedDiagram == null && q.getStem() != null) {
                matchedDiagram = byStem.get(q.getStem().trim());
            }
            if (matchedDiagram == null) {
                continue;
            }

            Map<String, Object> nextExt = ext == null ? new LinkedHashMap<>() : new LinkedHashMap<>(ext);
            nextExt.put("diagram", matchedDiagram);
            q.setExtJson(objectMapper.writeValueAsString(nextExt));
            questionMapper.updateById(q);
            if (hadLegacyDiagram) {
                upgraded++;
            } else {
                backfilled++;
            }
        }

        if (backfilled > 0 || upgraded > 0) {
            log.info("Question diagram sync complete: backfilled={}, upgradedToStudioState={}", backfilled, upgraded);
        }
    }

    private void seedStudioDiagramQuestions(
            Map<String, EduChapter> chapterByCode,
            Map<String, EduGate> gateByChapterAndIndex
    ) throws Exception {
        ClassPathResource resource = new ClassPathResource("db/studio-diagram-questions.json");
        if (!resource.exists()) {
            return;
        }

        int inserted = 0;
        try (InputStream is = resource.getInputStream()) {
            JsonNode root = objectMapper.readTree(is);
            for (JsonNode item : root.path("items")) {
                String chapterCode = item.path("chapterCode").asText("");
                int gateIndex = item.path("gateIndex").asInt(-1);
                String stem = item.path("stem").asText("").trim();
                if (chapterCode.isBlank() || gateIndex < 0 || stem.isBlank()) {
                    continue;
                }
                EduChapter chapter = chapterByCode.get(chapterCode);
                if (chapter == null) {
                    continue;
                }
                EduGate gate = gateByChapterAndIndex.get(chapter.getId() + ":" + gateIndex);
                if (gate == null) {
                    continue;
                }

                Long exists = questionMapper.selectCount(
                        new LambdaQueryWrapper<EduQuestion>()
                                .eq(EduQuestion::getGateId, gate.getId())
                                .eq(EduQuestion::getStem, stem)
                );
                if (exists != null && exists > 0) {
                    continue;
                }

                EduQuestion q = new EduQuestion();
                q.setGradeCode(item.path("gradeCode").asText(chapter.getGradeCode()));
                q.setChapterId(chapter.getId());
                q.setGateId(gate.getId());
                q.setQuestionMode(item.path("questionMode").asText("STATIC"));
                q.setQuestionFormat(item.path("questionFormat").asText("SINGLE_CHOICE"));
                q.setStem(stem);
                q.setOptionsJson(objectMapper.writeValueAsString(item.path("options")));
                q.setAnswerJson(objectMapper.writeValueAsString(item.path("answer")));
                q.setAnalysis(item.path("analysis").asText(""));
                q.setDifficulty(item.path("difficulty").asInt(2));
                q.setTagsJson(objectMapper.writeValueAsString(item.path("tags")));
                Map<String, Object> ext = new LinkedHashMap<>();
                ext.put("diagram", objectMapper.convertValue(item.path("diagram"), Map.class));
                q.setExtJson(objectMapper.writeValueAsString(ext));
                q.setSource("ADMIN");
                q.setVersion(1);
                q.setSortOrder(item.path("sortOrder").asInt(201));
                q.setEnabled(1);
                questionMapper.insert(q);
                inserted++;

                if (gate.getQuestionCount() == null || gate.getQuestionCount() <= 0) {
                    gate.setQuestionCount(1);
                    gateMapper.updateById(gate);
                }
            }
        }
        if (inserted > 0) {
            log.info("Seeded {} JSXGraph Studio diagram questions", inserted);
        }
    }

    private boolean hasUploadedImage(Map<String, Object> ext) {
        if (ext == null || ext.isEmpty()) return false;
        Object url = ext.get("imageUrl");
        if (url != null && !String.valueOf(url).isBlank()) return true;
        Object key = ext.get("imageKey");
        return key != null && !String.valueOf(key).isBlank();
    }

    private boolean hasStudioDiagram(Map<String, Object> ext) {
        if (ext == null || ext.isEmpty()) return false;
        Object d = ext.get("diagram");
        if (d instanceof Map<?, ?> m && !m.isEmpty()) {
            Object st = m.get("studioState");
            return st instanceof Map<?, ?> sm && !sm.isEmpty();
        }
        return false;
    }

    private boolean hasLegacyDiagramWithoutStudio(Map<String, Object> ext) {
        if (ext == null || ext.isEmpty()) return false;
        Object d = ext.get("diagram");
        return d instanceof Map<?, ?> m && !m.isEmpty() && !hasStudioDiagram(ext);
    }
}
