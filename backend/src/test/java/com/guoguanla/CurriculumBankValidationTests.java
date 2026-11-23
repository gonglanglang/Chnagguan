package com.guoguanla;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.engine.GeneratedQuestion;
import com.guoguanla.module.engine.QuestionEngineService;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

class CurriculumBankValidationTests {

    private static final Pattern UNRENDERED_PLACEHOLDER = Pattern.compile("\\{\\{[^}]+\\}\\}");

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final QuestionEngineService engineService = new QuestionEngineService(objectMapper);

    @Test
    void all867CurriculumQuestionsShouldRenderCleanlyInQuestionEngine() throws Exception {
        Path jsonPath = Path.of("..", "scripts", "output", "curriculum-bank-20261122.json");
        Assumptions.assumeTrue(Files.exists(jsonPath), "未找到全量题库导出文件，跳过引擎压测");

        JsonNode root = objectMapper.readTree(Files.readString(jsonPath));
        assertEquals(51, root.get("totalChapters").asInt());
        assertEquals(867, root.get("totalQuestions").asInt());

        JsonNode questions = root.get("questions");
        assertTrue(questions.isArray());
        assertEquals(867, questions.size());

        int dynamicInstances = 0;
        for (int i = 0; i < questions.size(); i++) {
            JsonNode qNode = questions.get(i);
            String label = qNode.get("chapterCode").asText()
                    + "-g" + qNode.get("gateIndex").asInt()
                    + "-s" + qNode.get("sortOrder").asInt();

            EduQuestion q = new EduQuestion();
            q.setId((long) (10000 + i));
            q.setGradeCode(qNode.get("gradeCode").asText());
            q.setChapterId(1L);
            q.setGateId(1L);
            q.setQuestionMode(qNode.get("questionMode").asText());
            q.setQuestionFormat(qNode.get("questionFormat").asText());
            q.setStem(qNode.get("stem").asText());
            q.setOptionsJson(objectMapper.writeValueAsString(qNode.get("options")));
            q.setAnswerJson(objectMapper.writeValueAsString(qNode.get("answer")));
            q.setAnalysis(qNode.get("analysis").asText());
            q.setGeneratorCode(qNode.get("generatorCode").isNull() ? null : qNode.get("generatorCode").asText());
            q.setTemplateRuleJson(qNode.get("templateRule").isNull()
                    ? null
                    : objectMapper.writeValueAsString(qNode.get("templateRule")));
            q.setDifficulty(qNode.get("difficulty").asInt());
            q.setTagsJson(objectMapper.writeValueAsString(qNode.get("tags")));
            q.setEnabled(1);
            q.setDeleted(0);

            int runs = "DYNAMIC_TEMPLATE".equals(q.getQuestionMode()) ? 30 : 1;
            for (int r = 0; r < runs; r++) {
                GeneratedQuestion gen = engineService.generateOne(q);
                assertNotNull(gen, label + " 生成结果为 null");
                assertNotNull(gen.getStem(), label + " stem 为 null");
                assertFalse(gen.getStem().isBlank(), label + " stem 为空");
                assertFalse(UNRENDERED_PLACEHOLDER.matcher(gen.getStem()).find() || gen.getStem().contains("{{"),
                        label + " 存在未渲染占位符: " + gen.getStem());
                assertNotNull(gen.getAnalysis(), label + " analysis 为 null");
                assertFalse(gen.getAnalysis().isBlank(), label + " analysis 为空");
                assertFalse(UNRENDERED_PLACEHOLDER.matcher(gen.getAnalysis()).find() || gen.getAnalysis().contains("{{"),
                        label + " 解析存在未渲染占位符: " + gen.getAnalysis());

                if ("ESSAY".equals(q.getQuestionFormat())) {
                    assertEquals("ESSAY", gen.getQuestionFormat(), label);
                    assertNotNull(gen.getReferenceAnswer(), label + " 解答题参考答案为空");
                    assertFalse(gen.getReferenceAnswer().isBlank(), label + " 解答题参考答案为空白");
                } else {
                    List<String> opts = gen.getOptions();
                    assertNotNull(opts, label + " options 为 null");
                    assertEquals(4, opts.size(), label + " 选项个数不为 4: " + opts);
                    assertNotNull(gen.getAnswerIndex(), label + " answerIndex 为 null");
                    assertTrue(gen.getAnswerIndex() >= 0 && gen.getAnswerIndex() < 4,
                            label + " answerIndex 越界: " + gen.getAnswerIndex());

                    Set<String> distinct = opts.stream()
                            .map(String::trim)
                            .peek(opt -> {
                                assertFalse(opt.isEmpty(), label + " 存在空选项");
                                assertFalse(opt.contains("NaN") || opt.contains("Infinity"),
                                        label + " 选项出现非法数值: " + opt);
                                assertFalse(opt.endsWith("×2") || opt.endsWith("½") || opt.contains("（变式"),
                                        label + " 触发了选项兜底去重: " + opt);
                                assertFalse(UNRENDERED_PLACEHOLDER.matcher(opt).find() || opt.contains("{{"),
                                        label + " 选项未渲染占位符: " + opt);
                            })
                            .collect(Collectors.toSet());
                    assertEquals(4, distinct.size(), label + " Java引擎生成出现重复选项(或回退伪造): " + opts);
                }

                if ("DYNAMIC_TEMPLATE".equals(q.getQuestionMode())) {
                    dynamicInstances++;
                }
            }
        }
        assertEquals(357 * 30, dynamicInstances);
    }
}
