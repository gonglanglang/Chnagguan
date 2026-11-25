package com.guoguanla;

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
import com.guoguanla.module.engine.GeneratedQuestion;
import com.guoguanla.module.engine.QuestionEngineService;
import com.guoguanla.module.progress.entity.UserQuizRecord;
import com.guoguanla.module.progress.mapper.UserQuizRecordMapper;
import com.guoguanla.module.system.QuestionDiagramBackfillRunner;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * TASK-20261126-001 专项集成与回归测试：
 * 1) 后台默认主题配置（GET/PUT /api/admin/theme/default、公开 GET /api/app/theme/default、首页同步）
 * 2) 关卡提交后返回下一关/下一章第 1 关信息
 * 3) 题目几何矢量配图动态变量渲染、图片上传接口、防作弊不泄露答案与幂等配图回填器
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class Task20261126Tests {

    private static final byte[] MINIMAL_PNG = new byte[] {
            (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, (byte) 0xC4, (byte) 0x89
    };

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private EduChapterMapper chapterMapper;

    @Autowired
    private EduGateMapper gateMapper;

    @Autowired
    private EduQuestionMapper questionMapper;

    @Autowired
    private QuestionEngineService engineService;

    @Autowired
    private QuestionDiagramBackfillRunner diagramBackfillRunner;

    @Autowired
    private UserQuizRecordMapper quizRecordMapper;

    private List<Map<String, Object>> buildAllCorrectAnswers(String sessionNo) throws Exception {
        UserQuizRecord rec = quizRecordMapper.selectOne(
                new LambdaQueryWrapper<UserQuizRecord>().eq(UserQuizRecord::getSessionNo, sessionNo)
        );
        assertNotNull(rec, "Quiz session record should exist");
        JsonNode snaps = JsonHelper.readTree(objectMapper, rec.getQuestionSnapshotJson());
        assertNotNull(snaps);
        assertTrue(snaps.isArray() && snaps.size() > 0, "Quiz snapshot should have items");
        java.util.ArrayList<Map<String, Object>> ans = new java.util.ArrayList<>();
        for (JsonNode s : snaps) {
            int idx = s.path("itemIndex").asInt();
            String fmt = s.path("questionFormat").asText("SINGLE_CHOICE");
            if ("ESSAY".equals(fmt)) {
                ans.add(Map.of("itemIndex", idx, "answerText", "解答过程", "selfCorrect", true));
            } else {
                ans.add(Map.of("itemIndex", idx, "selectedIndex", s.path("answerIndex").asInt(0)));
            }
        }
        return ans;
    }

    private String loginAdmin() throws Exception {
        MvcResult res = mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("username", "admin", "password", "admin123"))))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(res.getResponse().getContentAsString())
                .path("data").path("accessToken").asText();
    }

    @Test
    void defaultThemeAdminControlAndPublicSyncShouldWork() throws Exception {
        // Public endpoint should work without auth
        MvcResult pubInit = mockMvc.perform(get("/api/app/theme/default"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.uiSkin").isString())
                .andExpect(jsonPath("$.data.themeHex").isString())
                .andReturn();
        String initialVersion = objectMapper.readTree(pubInit.getResponse().getContentAsString())
                .path("data").path("version").asText("1");

        // Admin endpoint must require login
        mockMvc.perform(get("/api/admin/theme/default"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));

        String adminToken = loginAdmin();

        // Validation: invalid skin & invalid hex should fail with 400
        mockMvc.perform(put("/api/admin/theme/default")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "uiSkin", "invalid_skin",
                                "themeHex", "#67C6FF",
                                "themeName", "非法皮肤",
                                "darkMode", false
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        mockMvc.perform(put("/api/admin/theme/default")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "uiSkin", "forui",
                                "themeHex", "not-a-hex",
                                "themeName", "非法颜色",
                                "darkMode", false
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        // Update default theme to Forui + dark mode + custom hex
        MvcResult updateRes = mockMvc.perform(put("/api/admin/theme/default")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "uiSkin", "forui",
                                "themeHex", "#0ea5e9",
                                "themeName", "晴空蓝",
                                "darkMode", true
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.uiSkin").value("forui"))
                .andExpect(jsonPath("$.data.themeHex").value("#0EA5E9"))
                .andExpect(jsonPath("$.data.themeName").value("晴空蓝"))
                .andExpect(jsonPath("$.data.darkMode").value(true))
                .andReturn();
        String bumpedVersion = objectMapper.readTree(updateRes.getResponse().getContentAsString())
                .path("data").path("version").asText();
        assertNotEquals(initialVersion, bumpedVersion, "Updating default theme must bump version");

        // Public endpoint & home summary must reflect the updated default theme immediately
        mockMvc.perform(get("/api/app/theme/default"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.uiSkin").value("forui"))
                .andExpect(jsonPath("$.data.themeHex").value("#0EA5E9"))
                .andExpect(jsonPath("$.data.darkMode").value(true))
                .andExpect(jsonPath("$.data.version").value(bumpedVersion));

        mockMvc.perform(get("/api/app/home/summary"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.defaultTheme.uiSkin").value("forui"))
                .andExpect(jsonPath("$.data.defaultTheme.version").value(bumpedVersion));

        // Restore standard default theme so other tests observe baseline
        mockMvc.perform(put("/api/admin/theme/default")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "uiSkin", "welkui",
                                "themeHex", "#67C6FF",
                                "themeName", "天青漫画",
                                "darkMode", false
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));
    }

    @Test
    void quizSubmitShouldReturnSameChapterAndCrossChapterNextGate() throws Exception {
        // Pick first two chapters in g7 that have playable gates
        List<EduChapter> g7Chapters = chapterMapper.selectList(
                new LambdaQueryWrapper<EduChapter>()
                        .eq(EduChapter::getGradeCode, "g7")
                        .eq(EduChapter::getEnabled, 1)
                        .orderByAsc(EduChapter::getSortOrder, EduChapter::getId)
        );
        assertTrue(g7Chapters.size() >= 2, "Need at least 2 chapters in g7 for cross-chapter test");

        EduChapter ch1 = g7Chapters.get(0);
        EduChapter ch2 = g7Chapters.get(1);
        List<EduGate> ch1Gates = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .eq(EduGate::getChapterId, ch1.getId())
                        .eq(EduGate::getEnabled, 1)
                        .orderByAsc(EduGate::getGateIndex, EduGate::getId)
        );
        List<EduGate> ch2Gates = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .eq(EduGate::getChapterId, ch2.getId())
                        .eq(EduGate::getEnabled, 1)
                        .orderByAsc(EduGate::getGateIndex, EduGate::getId)
        );
        assertTrue(ch1Gates.size() >= 2);
        assertFalse(ch2Gates.isEmpty());

        // 0) Failing Gate 1 should NOT unlock next gate
        EduGate gate1 = ch1Gates.get(0);
        EduGate gate2 = ch1Gates.get(1);
        MvcResult startFail = mockMvc.perform(post("/api/app/quiz/start")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gateId", gate1.getId()))))
                .andExpect(status().isOk())
                .andReturn();
        String sessionFail = objectMapper.readTree(startFail.getResponse().getContentAsString())
                .path("data").path("sessionNo").asText();
        mockMvc.perform(post("/api/app/quiz/submit")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", sessionFail,
                                "answers", List.of(),
                                "durationSec", 8
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.passed").value(false))
                .andExpect(jsonPath("$.data.nextGateId").doesNotExist());

        // 1) Start & PASS Gate 1 of ch1 -> should point to Gate 2 of ch1 (same chapter)
        MvcResult start1 = mockMvc.perform(post("/api/app/quiz/start")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gateId", gate1.getId()))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        String session1 = objectMapper.readTree(start1.getResponse().getContentAsString())
                .path("data").path("sessionNo").asText();

        mockMvc.perform(post("/api/app/quiz/submit")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", session1,
                                "answers", buildAllCorrectAnswers(session1),
                                "durationSec", 12
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.passed").value(true))
                .andExpect(jsonPath("$.data.nextGateId").value(gate2.getId()))
                .andExpect(jsonPath("$.data.nextGateIndex").value(gate2.getGateIndex()))
                .andExpect(jsonPath("$.data.nextChapterId").value(ch1.getId()))
                .andExpect(jsonPath("$.data.nextGateCrossChapter").value(false));

        // 2) Start & PASS last gate of ch1 -> should point to Gate 1 of ch2 (cross chapter)
        EduGate lastGateCh1 = ch1Gates.get(ch1Gates.size() - 1);
        EduGate firstGateCh2 = ch2Gates.get(0);
        List<Long> prevPassed = ch1Gates.subList(0, ch1Gates.size() - 1).stream()
                .map(EduGate::getId).toList();
        MvcResult startLast = mockMvc.perform(post("/api/app/quiz/start")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "gateId", lastGateCh1.getId(),
                                "guestPassedGateIds", prevPassed
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        String sessionLast = objectMapper.readTree(startLast.getResponse().getContentAsString())
                .path("data").path("sessionNo").asText();

        mockMvc.perform(post("/api/app/quiz/submit")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", sessionLast,
                                "answers", buildAllCorrectAnswers(sessionLast),
                                "durationSec", 15
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.passed").value(true))
                .andExpect(jsonPath("$.data.nextGateId").value(firstGateCh2.getId()))
                .andExpect(jsonPath("$.data.nextGateIndex").value(firstGateCh2.getGateIndex()))
                .andExpect(jsonPath("$.data.nextChapterId").value(ch2.getId()))
                .andExpect(jsonPath("$.data.nextChapterName").value(ch2.getName()))
                .andExpect(jsonPath("$.data.nextGateCrossChapter").value(true));
    }

    @Test
    void questionDiagramDynamicRenderUploadAndIdempotentBackfillShouldWork() throws Exception {
        // 1) Dynamic diagram variable substitution in QuestionEngineService
        EduQuestion dynTri = new EduQuestion();
        dynTri.setId(999901L);
        dynTri.setQuestionMode("DYNAMIC_TEMPLATE");
        dynTri.setQuestionFormat("SINGLE_CHOICE");
        dynTri.setStem("如图，在 △ABC 中，∠A={{a}}°，∠B={{b}}°，求外角 ∠ACD。");
        dynTri.setTemplateRuleJson(objectMapper.writeValueAsString(Map.of(
                "type", "PARAM_TEMPLATE",
                "vars", Map.of("a", List.of(42, 42), "b", List.of(58, 58)),
                "stemTpl", "如图，在 △ABC 中，∠A={{a}}°，∠B={{b}}°，求外角 ∠ACD。",
                "ansExpr", "a + b",
                "wrongExprs", List.of("180 - a - b", "a + b + 10", "b - a")
        )));
        dynTri.setExtJson(objectMapper.writeValueAsString(Map.of(
                "diagram", Map.of(
                        "title", "三角形外角示意",
                        "width", 300,
                        "height", 180,
                        "primitives", List.of(
                                Map.of("type", "polygon", "points", List.of(
                                        List.of(50, 140), List.of(190, 140), List.of(110, 40)
                                )),
                                Map.of("type", "text", "x", 110, "y", 58, "text", "{{a}}°"),
                                Map.of("type", "text", "x", 72, "y", 132, "text", "{{b}}°"),
                                Map.of("type", "text", "x", 225, "y", 125, "text", "∠ACD=?")
                        )
                )
        )));

        GeneratedQuestion gen = engineService.generateOne(dynTri);
        assertNotNull(gen.getDiagram(), "Generated dynamic question must include rendered diagram");
        String diagramJson = objectMapper.writeValueAsString(gen.getDiagram());
        assertTrue(diagramJson.contains("42°"), "Diagram must substitute {{a}} -> 42°");
        assertTrue(diagramJson.contains("58°"), "Diagram must substitute {{b}} -> 58°");
        assertFalse(diagramJson.contains("{{"), "No raw template placeholders should remain in diagram");
        assertEquals("100", gen.getOptions().get(gen.getAnswerIndex()));

        // 2) Admin image upload + create question with diagram & imageKey -> returned by quiz/start without leaking answers
        String adminToken = loginAdmin();
        MockMultipartFile png = new MockMultipartFile("file", "triangle-fig.png", "image/png", MINIMAL_PNG);
        MvcResult uploadRes = mockMvc.perform(multipart("/api/admin/questions/upload-image")
                        .file(png)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.objectKey").isNotEmpty())
                .andExpect(jsonPath("$.data.previewUrl").isNotEmpty())
                .andReturn();
        String imageKey = objectMapper.readTree(uploadRes.getResponse().getContentAsString())
                .path("data").path("objectKey").asText();

        EduChapter anyChap = chapterMapper.selectList(
                new LambdaQueryWrapper<EduChapter>().eq(EduChapter::getEnabled, 1).last("LIMIT 1")
        ).get(0);
        EduGate anyGate = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>().eq(EduGate::getChapterId, anyChap.getId()).orderByAsc(EduGate::getGateIndex).last("LIMIT 1")
        ).get(0);

        Map<String, Object> customDiagram = Map.of(
                "title", "自定义直角三角形",
                "width", 280,
                "height", 180,
                "primitives", List.of(
                        Map.of("type", "polygon", "points", List.of(List.of(40, 140), List.of(220, 140), List.of(40, 40))),
                        Map.of("type", "rightAngle", "vx", 40, "vy", 140, "ax", 220, "ay", 140, "bx", 40, "by", 40, "size", 14)
                )
        );

        Map<String, Object> createPayload = Map.ofEntries(
                Map.entry("gradeCode", anyChap.getGradeCode()),
                Map.entry("chapterId", anyChap.getId()),
                Map.entry("gateId", anyGate.getId()),
                Map.entry("questionMode", "STATIC"),
                Map.entry("questionFormat", "SINGLE_CHOICE"),
                Map.entry("stem", "如图，在 Rt△ABC 中，∠C=90°，AC=3，BC=4，则 AB="),
                Map.entry("options", List.of("5", "6", "7", "25")),
                Map.entry("answer", Map.of("index", 0)),
                Map.entry("analysis", "由勾股定理 AB = √(3²+4²) = 5"),
                Map.entry("ext", Map.of("diagram", customDiagram, "imageKey", imageKey)),
                Map.entry("syncGateCount", true)
        );
        MvcResult createRes = mockMvc.perform(post("/api/admin/questions")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createPayload)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        long createdQId = objectMapper.readTree(createRes.getResponse().getContentAsString()).path("data").asLong();

        // Admin detail should resolve signed imageUrl in ext
        mockMvc.perform(get("/api/admin/questions/" + createdQId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ext.diagram.title").value("自定义直角三角形"))
                .andExpect(jsonPath("$.data.ext.imageUrl").isNotEmpty());

        // Start quiz on that gate -> custom question must appear with diagram & imageUrl, and ZERO answer leakage
        MvcResult startRes = mockMvc.perform(post("/api/app/quiz/start")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gateId", anyGate.getId()))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        JsonNode items = objectMapper.readTree(startRes.getResponse().getContentAsString())
                .path("data").path("items");
        boolean foundCustom = false;
        for (JsonNode item : items) {
            // Hard anti-cheat assertion: no answer/analysis field leaked
            assertTrue(item.path("answer").isMissingNode());
            assertTrue(item.path("answerIndex").isMissingNode());
            assertTrue(item.path("analysis").isMissingNode());
            if (item.path("stem").asText().contains("Rt△ABC")) {
                foundCustom = true;
                assertEquals("自定义直角三角形", item.path("diagram").path("title").asText());
                assertFalse(item.path("imageUrl").asText("").isBlank());
            }
        }
        assertTrue(foundCustom, "Newly created question with diagram should be picked in gate quiz");

        // 3) Backfill runner must remain idempotent and never overwrite custom question diagram
        diagramBackfillRunner.run(new DefaultApplicationArguments());
        EduQuestion afterBackfill = questionMapper.selectById(createdQId);
        assertTrue(afterBackfill.getExtJson().contains("自定义直角三角形"),
                "Backfill runner must NOT overwrite existing custom diagram");

        // Cleanup created test question
        mockMvc.perform(delete("/api/admin/questions/" + createdQId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk());
    }
}
