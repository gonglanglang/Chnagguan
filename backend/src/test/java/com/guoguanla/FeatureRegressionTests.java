package com.guoguanla;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FeatureRegressionTests {

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

    private String loginAdmin() throws Exception {
        MvcResult res = mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("username", "admin", "password", "admin123"))))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(res.getResponse().getContentAsString()).path("data").path("accessToken").asText();
    }

    @Test
    void adminQuestionSyncDynamicConvertPasswordResetAndEssayDrawingFlowShouldWork() throws Exception {
        String adminToken = loginAdmin();

        // 1. Register a clean test student and verify admin password update
        MvcResult regRes = mockMvc.perform(post("/api/app/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "username", "feat_stu_01",
                                "password", "oldpass123",
                                "nickname", "测试小修仙"
                        ))))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode regData = objectMapper.readTree(regRes.getResponse().getContentAsString()).path("data");
        long studentId = regData.path("profile").path("id").asLong();

        // Admin resets student password via dedicated endpoint
        mockMvc.perform(put("/api/admin/users/" + studentId + "/password")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("password", "newpass666"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        // Old password must fail, new password must succeed
        mockMvc.perform(post("/api/app/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("account", "feat_stu_01", "password", "oldpass123"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(10001));

        MvcResult loginNewRes = mockMvc.perform(post("/api/app/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("account", "feat_stu_01", "password", "newpass666"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        String studentToken = objectMapper.readTree(loginNewRes.getResponse().getContentAsString())
                .path("data").path("token").asText();

        // 2. Find chapter 1 gate 1 (seeded 3 questions) & add a static question -> verify questionCount syncs to 4
        MvcResult chapRes = mockMvc.perform(get("/api/admin/chapters?gradeCode=g7")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        long c1Id = objectMapper.readTree(chapRes.getResponse().getContentAsString()).path("data").get(0).path("id").asLong();

        MvcResult gatesRes = mockMvc.perform(get("/api/admin/chapters/" + c1Id + "/gates")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        long gate1Id = objectMapper.readTree(gatesRes.getResponse().getContentAsString()).path("data").get(0).path("id").asLong();

        String customChoiceStem = "自建方程 $\\frac{x}{2} = 5$ 的解是";
        MvcResult createChoiceRes = mockMvc.perform(post("/api/admin/questions")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.ofEntries(
                                Map.entry("gradeCode", "g7"),
                                Map.entry("chapterId", c1Id),
                                Map.entry("gateId", gate1Id),
                                Map.entry("questionMode", "STATIC"),
                                Map.entry("questionFormat", "SINGLE_CHOICE"),
                                Map.entry("stem", customChoiceStem),
                                Map.entry("options", List.of("10", "5", "2.5", "7")),
                                Map.entry("answer", Map.of("index", 0)),
                                Map.entry("analysis", "两边同乘 2 得 x=10")
                        ))))
                .andExpect(status().isOk())
                .andReturn();
        long choiceQId = objectMapper.readTree(createChoiceRes.getResponse().getContentAsString()).path("data").asLong();

        // Check gate questionCount automatically expanded to 4
        mockMvc.perform(get("/api/admin/chapters/" + c1Id + "/gates")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].questionCount").value(greaterThanOrEqualTo(4)));

        // Lower gate questionCount back to 3 and confirm ADMIN priority draw still picks the custom question
        mockMvc.perform(put("/api/admin/gates/" + gate1Id)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "gateName", "基础关",
                                "star", 1,
                                "questionCount", 3,
                                "passCount", 2,
                                "enabled", 1
                        ))))
                .andExpect(status().isOk());

        // 3. Convert the static choice question into DYNAMIC_TEMPLATE (PARAM_TEMPLATE)
        mockMvc.perform(put("/api/admin/questions/" + choiceQId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.ofEntries(
                                Map.entry("gradeCode", "g7"),
                                Map.entry("chapterId", c1Id),
                                Map.entry("gateId", gate1Id),
                                Map.entry("questionMode", "DYNAMIC_TEMPLATE"),
                                Map.entry("questionFormat", "SINGLE_CHOICE"),
                                Map.entry("stem", "计算 ${{a}} + {{b}}$"),
                                Map.entry("templateRule", Map.of(
                                        "type", "PARAM_TEMPLATE",
                                        "vars", Map.of("a", List.of(10, 10), "b", List.of(5, 5)),
                                        "stemTpl", "动态转换题：求 ${{a}} + {{b}}$ =",
                                        "ansExpr", "a + b",
                                        "wrongExprs", List.of("a - b", "a * b", "a + b + 1")
                                )),
                                Map.entry("analysis", "直接相加 {{a}} + {{b}}")
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        // 4. Add a STATIC ESSAY question into the same gate
        mockMvc.perform(post("/api/admin/questions")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.ofEntries(
                                Map.entry("gradeCode", "g7"),
                                Map.entry("chapterId", c1Id),
                                Map.entry("gateId", gate1Id),
                                Map.entry("questionMode", "STATIC"),
                                Map.entry("questionFormat", "ESSAY"),
                                Map.entry("stem", "解答题：请写出计算 $(-2)^3 + |{-5}|$ 的完整步骤。"),
                                Map.entry("answer", Map.of("text", "解：原式 $= -8 + 5 = -3$")),
                                Map.entry("analysis", "先算乘方和绝对值，再相加")
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        // Start gate quiz: verify both ADMIN questions (dynamic converted choice + essay) are drawn & no answers leaked
        MvcResult startRes = mockMvc.perform(post("/api/app/quiz/start")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gateId", gate1Id))))
                .andExpect(status().isOk())
                .andReturn();
        String startRaw = startRes.getResponse().getContentAsString();
        assertFalse(startRaw.contains("referenceAnswer"));
        assertFalse(startRaw.contains("原式 $= -8"));
        JsonNode startData = objectMapper.readTree(startRaw).path("data");
        String sessionNo = startData.path("sessionNo").asText();
        JsonNode items = startData.path("items");

        Integer essayIdx = null;
        boolean sawDynamicConverted = false;
        List<Map<String, Object>> submitAnswers = new ArrayList<>();
        for (JsonNode it : items) {
            int idx = it.path("itemIndex").asInt();
            String fmt = it.path("questionFormat").asText();
            String stem = it.path("stem").asText();
            if (stem.startsWith("动态转换题：求 $10 + 5$")) {
                sawDynamicConverted = true;
            }
            if ("ESSAY".equals(fmt)) {
                essayIdx = idx;
            } else {
                submitAnswers.add(Map.of("itemIndex", idx, "selectedIndex", 0));
            }
        }
        assertTrue(sawDynamicConverted, "Dynamic converted ADMIN question must be drawn");
        assertNotNull(essayIdx, "Essay ADMIN question must be drawn");

        // 5. Student uploads avatar and drawing PNG image (check-item enters pending review, no self-grade)
        MockMultipartFile avatarFile = new MockMultipartFile("file", "avatar.png", "image/png", MINIMAL_PNG);
        mockMvc.perform(multipart("/api/app/user/avatar")
                        .file(avatarFile)
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.avatarUrl").isNotEmpty());

        MockMultipartFile pngFile = new MockMultipartFile("file", "drawing.png", "image/png", MINIMAL_PNG);
        MvcResult uploadRes = mockMvc.perform(multipart("/api/app/quiz/upload-answer-image")
                        .file(pngFile)
                        .param("sessionNo", sessionNo)
                        .param("itemIndex", String.valueOf(essayIdx))
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.objectKey").isNotEmpty())
                .andReturn();
        String imgKey = objectMapper.readTree(uploadRes.getResponse().getContentAsString())
                .path("data").path("objectKey").asText();

        mockMvc.perform(post("/api/app/quiz/check-item")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", sessionNo,
                                "itemIndex", essayIdx,
                                "answerText", "答案是 -3",
                                "answerImageKey", imgKey
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.questionFormat").value("ESSAY"))
                .andExpect(jsonPath("$.data.pendingReview").value(true))
                .andExpect(jsonPath("$.data.answerImageUrl").isNotEmpty());

        submitAnswers.add(Map.of(
                "itemIndex", essayIdx,
                "answerText", "答案是 -3",
                "answerImageKey", imgKey
        ));

        mockMvc.perform(post("/api/app/quiz/submit")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", sessionNo,
                                "answers", submitAnswers
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.pendingReviewCount").value(1));

        // While essay is pending teacher review, it must NOT be placed into wrong-questions yet
        MvcResult pendingWrongRes = mockMvc.perform(get("/api/app/wrong-questions?pageNum=1&pageSize=10")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andReturn();
        for (JsonNode w : objectMapper.readTree(pendingWrongRes.getResponse().getContentAsString()).path("data").path("records")) {
            assertNotEquals("ESSAY", w.path("questionFormat").asText(), "Pending essay should not enter wrong book before teacher review");
        }

        // Student essay-answers endpoint returns saved drawing record
        MvcResult myEssayRes = mockMvc.perform(get("/api/app/user/essay-answers?pageNum=1&pageSize=10")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.records.length()").value(1))
                .andExpect(jsonPath("$.data.records[0].answerText").value("答案是 -3"))
                .andReturn();
        long essayId = objectMapper.readTree(myEssayRes.getResponse().getContentAsString())
                .path("data").path("records").get(0).path("id").asLong();

        // Admin inspects session detail + rejects (status=2) -> enters wrong-questions; then approves (status=1) -> mastered
        mockMvc.perform(get("/api/admin/users/" + studentId + "/quiz-records/" + sessionNo)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(items.size()));

        mockMvc.perform(put("/api/admin/users/essay-answers/" + essayId + "/review")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "teacherStatus", 2,
                                "teacherComment", "需补充过程"
                        ))))
                .andExpect(status().isOk());

        MvcResult wrongRes = mockMvc.perform(get("/api/app/wrong-questions?pageNum=1&pageSize=10")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode wrongRecords = objectMapper.readTree(wrongRes.getResponse().getContentAsString())
                .path("data").path("records");
        JsonNode essayWrong = null;
        for (JsonNode w : wrongRecords) {
            if ("ESSAY".equals(w.path("questionFormat").asText())) {
                essayWrong = w;
                break;
            }
        }
        assertNotNull(essayWrong, "Rejected ESSAY should enter wrong questions");
        assertFalse(essayWrong.path("lastAnswerImageUrl").asText("").isBlank());
        assertEquals("解：原式 $= -8 + 5 = -3$", essayWrong.path("referenceAnswer").asText(""));

        // Admin inspects essay detail + image proxy + uploads PC annotation image + approves
        mockMvc.perform(get("/api/admin/users/essay-answers/" + essayId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.studentNickname").value("测试小修仙"));

        mockMvc.perform(get("/api/admin/users/essay-answers/" + essayId + "/image")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.IMAGE_PNG));

        MockMultipartFile reviewPng = new MockMultipartFile("file", "review.png", "image/png", MINIMAL_PNG);
        MvcResult reviewUploadRes = mockMvc.perform(multipart("/api/admin/users/essay-answers/" + essayId + "/review-image")
                        .file(reviewPng)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.objectKey").isNotEmpty())
                .andReturn();
        String reviewImgKey = objectMapper.readTree(reviewUploadRes.getResponse().getContentAsString())
                .path("data").path("objectKey").asText();

        mockMvc.perform(put("/api/admin/users/essay-answers/" + essayId + "/review")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "teacherStatus", 1,
                                "teacherComment", "步骤清晰，非常棒",
                                "teacherImageKey", reviewImgKey
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        mockMvc.perform(get("/api/app/user/essay-answers?pageNum=1&pageSize=10")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.records[0].teacherStatus").value(1))
                .andExpect(jsonPath("$.data.records[0].teacherComment").value("步骤清晰，非常棒"))
                .andExpect(jsonPath("$.data.records[0].teacherImageUrl").isNotEmpty());

        // 6. Re-submit essay in the same realm + chapter + gate -> must overwrite & reset to pending review (still only 1 row)
        MvcResult startRes2 = mockMvc.perform(post("/api/app/quiz/start")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gateId", gate1Id))))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode startData2 = objectMapper.readTree(startRes2.getResponse().getContentAsString()).path("data");
        String sessionNo2 = startData2.path("sessionNo").asText();
        Integer essayIdx2 = null;
        for (JsonNode it : startData2.path("items")) {
            if ("ESSAY".equals(it.path("questionFormat").asText())) {
                essayIdx2 = it.path("itemIndex").asInt();
                break;
            }
        }
        assertNotNull(essayIdx2);
        mockMvc.perform(post("/api/app/quiz/check-item")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", sessionNo2,
                                "itemIndex", essayIdx2,
                                "answerText", "重交新步骤：-3",
                                "answerImageKey", imgKey
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/app/user/essay-answers?pageNum=1&pageSize=10")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.records[0].id").value(essayId))
                .andExpect(jsonPath("$.data.records[0].answerText").value("重交新步骤：-3"))
                .andExpect(jsonPath("$.data.records[0].teacherStatus").value(0))
                .andExpect(jsonPath("$.data.records[0].teacherComment").value(""));

        // 7. Admin Video Series & Multi-Lesson flow + App Cultivate video APIs
        MockMultipartFile coverFile = new MockMultipartFile("file", "cover.png", "image/png", MINIMAL_PNG);
        MvcResult coverUploadRes = mockMvc.perform(multipart("/api/admin/videos/upload-cover")
                        .file(coverFile)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        String coverKey = objectMapper.readTree(coverUploadRes.getResponse().getContentAsString())
                .path("data").path("objectKey").asText();

        MockMultipartFile videoFile = new MockMultipartFile("file", "lesson1.mp4", "video/mp4", new byte[] { 0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70 });
        MvcResult videoUploadRes = mockMvc.perform(multipart("/api/admin/videos/upload-media")
                        .file(videoFile)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        String videoKey = objectMapper.readTree(videoUploadRes.getResponse().getContentAsString())
                .path("data").path("objectKey").asText();

        MvcResult seriesCreateRes = mockMvc.perform(post("/api/admin/videos/series")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "title", "练气期一元一次方程精讲",
                                "coverImageKey", coverKey,
                                "intro", "从移项变号到分数方程完整通关",
                                "realmCode", "lianqi",
                                "enabled", 1
                        ))))
                .andExpect(status().isOk())
                .andReturn();
        long seriesId = objectMapper.readTree(seriesCreateRes.getResponse().getContentAsString()).path("data").asLong();

        mockMvc.perform(post("/api/admin/videos/series/" + seriesId + "/lessons")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "title", "第1节：移项变号口诀",
                                "videoKey", videoKey,
                                "classNotes", "移项要变号，求解 $ax=b$。",
                                "sortOrder", 1,
                                "enabled", 1
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/admin/videos/series/" + seriesId + "/lessons")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "title", "第2节：去分母与分数化简",
                                "videoKey", videoKey,
                                "classNotes", "同乘最小公倍数去分母。",
                                "sortOrder", 2,
                                "enabled", 1
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/app/videos/series?realmCode=lianqi"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.records[0].lessonCount").value(2))
                .andExpect(jsonPath("$.data.records[0].coverImageUrl").isNotEmpty());

        mockMvc.perform(get("/api/app/videos/series/" + seriesId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.lessons.length()").value(2))
                .andExpect(jsonPath("$.data.lessons[0].classNotes").value("移项要变号，求解 $ax=b$。"));

        // 8. Chunked multipart video upload + note attachments (备注 + 附件)
        MvcResult initRes = mockMvc.perform(post("/api/admin/videos/upload-media/init")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "fileName", "chunked_lecture.mp4",
                                "contentType", "video/mp4",
                                "fileSize", 16
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.uploadId").isNotEmpty())
                .andExpect(jsonPath("$.data.chunkSize").value(5242880))
                .andExpect(jsonPath("$.data.directUpload").value(false))
                .andExpect(jsonPath("$.data.partUploadUrls").isArray())
                .andReturn();
        JsonNode initData = objectMapper.readTree(initRes.getResponse().getContentAsString()).path("data");
        String uploadId = initData.path("uploadId").asText();
        String chunkObjectKey = initData.path("objectKey").asText();

        MockMultipartFile part1 = new MockMultipartFile("file", "part1", "application/octet-stream", new byte[] { 0, 0, 0, 24, 102, 116, 121, 112 });
        MockMultipartFile part2 = new MockMultipartFile("file", "part2", "application/octet-stream", new byte[] { 105, 115, 111, 109, 0, 0, 2, 0 });
        MvcResult p1Res = mockMvc.perform(multipart("/api/admin/videos/upload-media/part")
                        .file(part1)
                        .param("uploadId", uploadId)
                        .param("objectKey", chunkObjectKey)
                        .param("partNumber", "1")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        String eTag1 = objectMapper.readTree(p1Res.getResponse().getContentAsString()).path("data").path("eTag").asText();

        MvcResult p2Res = mockMvc.perform(multipart("/api/admin/videos/upload-media/part")
                        .file(part2)
                        .param("uploadId", uploadId)
                        .param("objectKey", chunkObjectKey)
                        .param("partNumber", "2")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        String eTag2 = objectMapper.readTree(p2Res.getResponse().getContentAsString()).path("data").path("eTag").asText();

        mockMvc.perform(post("/api/admin/videos/upload-media/complete")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "uploadId", uploadId,
                                "objectKey", chunkObjectKey,
                                "parts", List.of(Map.of("partNumber", 1, "eTag", ""))
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        MvcResult compRes = mockMvc.perform(post("/api/admin/videos/upload-media/complete")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "uploadId", uploadId,
                                "objectKey", chunkObjectKey,
                                "parts", List.of(
                                        Map.of("partNumber", 1, "eTag", eTag1),
                                        Map.of("partNumber", 2, "eTag", eTag2)
                                )
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.objectKey").isNotEmpty())
                .andExpect(jsonPath("$.data.previewUrl").isNotEmpty())
                .andReturn();
        String mergedVideoKey = objectMapper.readTree(compRes.getResponse().getContentAsString())
                .path("data").path("objectKey").asText();

        MockMultipartFile badExe = new MockMultipartFile("file", "virus.exe", "application/octet-stream", new byte[] { 1, 2, 3 });
        mockMvc.perform(multipart("/api/admin/videos/upload-attachment")
                        .file(badExe)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        MockMultipartFile pdfAtt = new MockMultipartFile("file", "有理数讲义.pdf", "application/pdf", "%PDF-1.4\nhello".getBytes());
        MvcResult attRes = mockMvc.perform(multipart("/api/admin/videos/upload-attachment")
                        .file(pdfAtt)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("有理数讲义.pdf"))
                .andReturn();
        JsonNode attData = objectMapper.readTree(attRes.getResponse().getContentAsString()).path("data");

        mockMvc.perform(post("/api/admin/videos/series/" + seriesId + "/lessons")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "title", "第3节：分片视频与附件讲义",
                                "coverImageKey", coverKey,
                                "videoKey", mergedVideoKey,
                                "classNotes", "请结合附件讲义预习重点。",
                                "notesAttachments", List.of(Map.of(
                                        "name", attData.path("name").asText(),
                                        "objectKey", attData.path("objectKey").asText(),
                                        "size", attData.path("size").asLong(),
                                        "contentType", attData.path("contentType").asText()
                                )),
                                "sortOrder", 3,
                                "enabled", 1
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/app/videos/series/" + seriesId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.lessons.length()").value(3))
                .andExpect(jsonPath("$.data.lessons[2].coverImageUrl").isNotEmpty())
                .andExpect(jsonPath("$.data.lessons[2].classNotes").value("请结合附件讲义预习重点。"))
                .andExpect(jsonPath("$.data.lessons[2].notesAttachments[0].name").value("有理数讲义.pdf"))
                .andExpect(jsonPath("$.data.lessons[2].notesAttachments[0].url").isNotEmpty());
    }
}
