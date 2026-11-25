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
 * 幂等题库几何/函数矢量配图回填器：
 * 在 SchemaUpgradeRunner(@Order 1) 与 DataSeedRunner(@Order 2) 之后执行，
 * 自动为尚未设置 diagram / imageUrl / imageKey 的存量几何、三角形、圆、函数与立体几何题补齐矢量配图，
 * 严禁覆盖老师或管理员已经手动配置/上传过配图的题目。
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

        Map<Long, String> chapterCodeMap = chapterMapper.selectList(null).stream()
                .collect(Collectors.toMap(EduChapter::getId, EduChapter::getChapterCode, (a, b) -> a));
        Map<Long, Integer> gateIndexMap = gateMapper.selectList(null).stream()
                .collect(Collectors.toMap(EduGate::getId, EduGate::getGateIndex, (a, b) -> a));

        List<EduQuestion> questions = questionMapper.selectList(
                new LambdaQueryWrapper<EduQuestion>().eq(EduQuestion::getEnabled, 1)
        );
        int updated = 0;
        for (EduQuestion q : questions) {
            Map<String, Object> ext = JsonHelper.readMap(objectMapper, q.getExtJson());
            if (hasExistingFigure(ext)) {
                continue;
            }
            String chapCode = chapterCodeMap.get(q.getChapterId());
            Integer gateIdx = gateIndexMap.get(q.getGateId());
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
            updated++;
        }

        if (updated > 0) {
            log.info("Backfilled vector geometry/function diagrams for {} questions", updated);
        }
    }

    private boolean hasExistingFigure(Map<String, Object> ext) {
        if (ext == null || ext.isEmpty()) return false;
        Object d = ext.get("diagram");
        if (d instanceof Map<?, ?> m && !m.isEmpty()) return true;
        Object url = ext.get("imageUrl");
        if (url != null && !String.valueOf(url).isBlank()) return true;
        Object key = ext.get("imageKey");
        return key != null && !String.valueOf(key).isBlank();
    }
}
