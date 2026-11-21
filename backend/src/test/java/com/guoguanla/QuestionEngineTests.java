package com.guoguanla;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.engine.GeneratedQuestion;
import com.guoguanla.module.engine.QuestionEngineService;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;

import java.io.InputStream;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class QuestionEngineTests {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final QuestionEngineService engineService = new QuestionEngineService(objectMapper);

    @Test
    void all408PrototypeDynamicTemplatesShouldGenerateValidQuestions() throws Exception {
        ClassPathResource resource = new ClassPathResource("db/prototype-bank.json");
        assertTrue(resource.exists(), "prototype-bank.json must exist");

        int dynamicCount = 0;
        try (InputStream is = resource.getInputStream()) {
            JsonNode root = objectMapper.readTree(is);
            for (JsonNode qNode : root.path("questions")) {
                if (!"DYNAMIC_TEMPLATE".equals(qNode.path("questionMode").asText())) {
                    continue;
                }
                dynamicCount++;
                EduQuestion q = new EduQuestion();
                q.setId((long) dynamicCount);
                q.setQuestionMode("DYNAMIC_TEMPLATE");
                q.setTemplateRuleJson(objectMapper.writeValueAsString(qNode.path("templateRule")));
                q.setAnalysis(qNode.path("analysis").asText(""));

                GeneratedQuestion gen = engineService.generateOne(q);
                assertNotNull(gen.getStem(), "Stem missing for " + qNode.path("generatorCode").asText());
                assertFalse(gen.getStem().isBlank());
                assertNotNull(gen.getOptions());
                assertEquals(4, gen.getOptions().size(), "Expected 4 options for " + qNode.path("generatorCode").asText());
                assertNotNull(gen.getAnswerIndex());
                assertTrue(gen.getAnswerIndex() >= 0 && gen.getAnswerIndex() < 4);
            }
        }
        assertEquals(408, dynamicCount, "Expected exactly 408 prototype dynamic generators");
    }

    @Test
    void paramTemplateShouldGenerateRandomizedValidQuestion() throws Exception {
        EduQuestion q = new EduQuestion();
        q.setQuestionMode("DYNAMIC_TEMPLATE");
        q.setAnalysis("绝对值非负性求和");
        q.setTemplateRuleJson(objectMapper.writeValueAsString(Map.of(
                "type", "PARAM_TEMPLATE",
                "vars", Map.of("a", List.of(2, 6), "b", List.of(1, 5)),
                "stemTpl", "若 |x - {{a}}| + |y + {{b}}| = 0，则 x + y =",
                "ansExpr", "a - b",
                "wrongExprs", List.of("a + b", "-a + b", "-a - b")
        )));

        List<GeneratedQuestion> samples = engineService.previewGenerate(q, 5);
        assertEquals(5, samples.size());
        for (GeneratedQuestion g : samples) {
            assertTrue(g.getStem().contains("|x - "));
            assertEquals(4, g.getOptions().size());
            assertEquals(4, g.getOptions().stream().distinct().count());
            assertTrue(g.getAnswerIndex() >= 0 && g.getAnswerIndex() < 4);
        }
    }

    @Test
    void latexBracesAndEssayParamTemplateShouldRenderCorrectly() throws Exception {
        EduQuestion fracQ = new EduQuestion();
        fracQ.setQuestionMode("DYNAMIC_TEMPLATE");
        fracQ.setQuestionFormat("SINGLE_CHOICE");
        fracQ.setTemplateRuleJson(objectMapper.writeValueAsString(Map.of(
                "type", "PARAM_TEMPLATE",
                "vars", Map.of("a", List.of(2, 2), "b", List.of(3, 3)),
                "stemTpl", "计算 $\\frac{{{a}}}{{{b}}} + 1$",
                "ansExpr", "frac(a + b, b)"
        )));
        GeneratedQuestion fracGen = engineService.generateOne(fracQ);
        assertEquals("计算 $\\frac{2}{3} + 1$", fracGen.getStem());
        assertEquals(4, fracGen.getOptions().size());
        assertTrue(fracGen.getOptions().contains("5/3"));

        EduQuestion essayQ = new EduQuestion();
        essayQ.setQuestionMode("DYNAMIC_TEMPLATE");
        essayQ.setQuestionFormat("ESSAY");
        essayQ.setAnalysis("将 $a={{a}}$ 代入计算");
        essayQ.setTemplateRuleJson(objectMapper.writeValueAsString(Map.of(
                "type", "PARAM_TEMPLATE",
                "vars", Map.of("a", List.of(4, 4), "b", List.of(5, 5)),
                "stemTpl", "已知 $x={{a}}$，求 $x+{{b}}$ 的值并写出过程。",
                "ansExpr", "解：$x + {{b}} = {{a + b}}$"
        )));
        GeneratedQuestion essayGen = engineService.generateOne(essayQ);
        assertEquals("ESSAY", essayGen.getQuestionFormat());
        assertTrue(essayGen.getOptions().isEmpty());
        assertEquals("解：$x + 5 = 9$", essayGen.getReferenceAnswer());
        assertEquals("将 $a=4$ 代入计算", essayGen.getAnalysis());
    }
}
