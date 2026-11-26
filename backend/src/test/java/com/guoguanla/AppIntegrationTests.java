package com.guoguanla;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.module.progress.entity.UserWrongQuestion;
import com.guoguanla.module.progress.mapper.UserWrongQuestionMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
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
class AppIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserWrongQuestionMapper wrongMapper;

    @Test
    void studentFlowAntiCheatAndWrongRedoFixShouldWork() throws Exception {
        // 1. Register new student
        String regJson = objectMapper.writeValueAsString(Map.of(
                "username", "app_stu_001",
                "password", "123456",
                "nickname", "小明",
                "gradeCode", "g7"
        ));
        MvcResult regRes = mockMvc.perform(post("/api/app/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(regJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.token").isNotEmpty())
                .andReturn();

        String studentToken = objectMapper.readTree(regRes.getResponse().getContentAsString())
                .path("data").path("token").asText();

        // 2. Token isolation: student token MUST NOT access admin endpoints
        mockMvc.perform(get("/api/admin/dashboard/overview")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isUnauthorized());

        // 3. Get g7 chapters & c1 gates
        MvcResult chapRes = mockMvc.perform(get("/api/app/grades/g7/chapters")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()", greaterThanOrEqualTo(10)))
                .andExpect(jsonPath("$.data[0].chapterCode").value("c1"))
                .andReturn();
        long c1Id = objectMapper.readTree(chapRes.getResponse().getContentAsString())
                .path("data").get(0).path("id").asLong();

        MvcResult gateRes = mockMvc.perform(get("/api/app/chapters/" + c1Id + "/gates")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(4))
                .andExpect(jsonPath("$.data[0].locked").value(false))
                .andExpect(jsonPath("$.data[1].locked").value(true))
                .andReturn();
        JsonNode gatesNode = objectMapper.readTree(gateRes.getResponse().getContentAsString()).path("data");
        long gate1Id = gatesNode.get(0).path("id").asLong();
        long gate2Id = gatesNode.get(1).path("id").asLong();

        // Attempting locked gate 2 must fail
        mockMvc.perform(post("/api/app/quiz/start")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gateId", gate2Id))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(20004));

        // 4. Start gate 1 -> ensure NO answer leaked in start response
        MvcResult startRes = mockMvc.perform(post("/api/app/quiz/start")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gateId", gate1Id))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items.length()").value(3))
                .andReturn();

        String startRaw = startRes.getResponse().getContentAsString();
        assertFalse(startRaw.contains("answerIndex"), "Quiz start MUST NOT leak answerIndex");
        JsonNode startData = objectMapper.readTree(startRaw).path("data");
        String sessionNo = startData.path("sessionNo").asText();

        // Check items one by one: intentionally answer item 0 right, item 1 right, item 2 wrong
        List<Map<String, Object>> answers = new ArrayList<>();
        for (int i = 0; i < 3; i++) {
            MvcResult chkRes = mockMvc.perform(post("/api/app/quiz/check-item")
                            .header("Authorization", "Bearer " + studentToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(Map.of(
                                    "sessionNo", sessionNo,
                                    "itemIndex", i,
                                    "selectedIndex", 0
                            ))))
                    .andExpect(status().isOk())
                    .andReturn();
            int correctIdx = objectMapper.readTree(chkRes.getResponse().getContentAsString())
                    .path("data").path("correctIndex").asInt();
            int finalPick = (i < 2) ? correctIdx : (correctIdx + 1) % 4;
            answers.add(Map.of("itemIndex", i, "selectedIndex", finalPick));
        }

        // Submit gate 1 -> 2/3 correct -> passed! Gate 2 unlocks!
        mockMvc.perform(post("/api/app/quiz/submit")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", sessionNo,
                                "answers", answers
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.passed").value(true))
                .andExpect(jsonPath("$.data.newlyPassed").value(true))
                .andExpect(jsonPath("$.data.correctCount").value(2))
                .andExpect(jsonPath("$.data.wrongItems.length()").value(1));

        // Verify gate 2 is now unlocked & dynamic gate 2 starts properly
        mockMvc.perform(get("/api/app/chapters/" + c1Id + "/gates")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].passed").value(true))
                .andExpect(jsonPath("$.data[1].locked").value(false));

        // 5. Verify wrong book recorded 1 item & redo RIGHT marks it mastered!
        MvcResult wrongRes = mockMvc.perform(get("/api/app/wrong-questions")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andReturn();
        long wrongId = objectMapper.readTree(wrongRes.getResponse().getContentAsString())
                .path("data").path("records").get(0).path("id").asLong();
        int wrongAnsIdx = objectMapper.readTree(wrongRes.getResponse().getContentAsString())
                .path("data").path("records").get(0).path("answerIndex").asInt();

        MvcResult redoStartRes = mockMvc.perform(post("/api/app/wrong-questions/redo/start")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items.length()").value(1))
                .andReturn();
        String redoSession = objectMapper.readTree(redoStartRes.getResponse().getContentAsString())
                .path("data").path("sessionNo").asText();

        mockMvc.perform(post("/api/app/wrong-questions/redo/submit")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", redoSession,
                                "answers", List.of(Map.of("itemIndex", 0, "selectedIndex", wrongAnsIdx))
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.masteredCount").value(1));

        UserWrongQuestion masteredWq = wrongMapper.selectById(wrongId);
        assertEquals(1, masteredWq.getIsMastered());

        // 6. Cross-realm free learning: lianqi user CAN browse & challenge zhuji (g8) gates without level lock
        MvcResult zhujiChaps = mockMvc.perform(get("/api/app/realms/zhuji/chapters")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].lockedByRealm").value(false))
                .andReturn();
        long zhujiChapId = objectMapper.readTree(zhujiChaps.getResponse().getContentAsString())
                .path("data").get(0).path("id").asLong();
        MvcResult zhujiGates = mockMvc.perform(get("/api/app/chapters/" + zhujiChapId + "/gates")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].lockedByRealm").value(false))
                .andExpect(jsonPath("$.data[0].locked").value(false))
                .andReturn();
        long zhujiGate1Id = objectMapper.readTree(zhujiGates.getResponse().getContentAsString())
                .path("data").get(0).path("id").asLong();

        mockMvc.perform(post("/api/app/quiz/start")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gateId", zhujiGate1Id))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.suppressedMode").value(false));

        // 7. Admin lowers unlockGates for lianqi to 1, sets examQuestionCount=3, passScore=60 -> student takes advance exam & promotes to zhuji!
        String adminLoginJson = objectMapper.writeValueAsString(Map.of("username", "admin", "password", "admin123"));
        String adminToken = objectMapper.readTree(mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(adminLoginJson))
                .andReturn().getResponse().getContentAsString()).path("data").path("accessToken").asText();

        long lianqiId = objectMapper.readTree(mockMvc.perform(get("/api/admin/realms")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(6))
                .andReturn().getResponse().getContentAsString()).path("data").get(0).path("id").asLong();

        mockMvc.perform(put("/api/admin/realms/" + lianqiId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "realmName", "初一",
                                "difficultyLabel", "难度一 · 基础",
                                "description", "测试升级测评条件",
                                "unlockGates", 1,
                                "examQuestionCount", 3,
                                "examPassScore", 60
                        ))))
                .andExpect(status().isOk());

        MvcResult examStartRes = mockMvc.perform(post("/api/app/realm/exam/start")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("ADVANCE_EXAM"))
                .andExpect(jsonPath("$.data.items.length()").value(3))
                .andReturn();
        String examStartRaw = examStartRes.getResponse().getContentAsString();
        assertFalse(examStartRaw.contains("answerIndex"), "Advance exam MUST NOT leak answerIndex");
        String examSession = objectMapper.readTree(examStartRaw).path("data").path("sessionNo").asText();

        List<Map<String, Object>> examAnswers = new ArrayList<>();
        for (int i = 0; i < 3; i++) {
            MvcResult chk = mockMvc.perform(post("/api/app/quiz/check-item")
                            .header("Authorization", "Bearer " + studentToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(Map.of(
                                    "sessionNo", examSession,
                                    "itemIndex", i,
                                    "selectedIndex", 0
                            ))))
                    .andReturn();
            int rightIdx = objectMapper.readTree(chk.getResponse().getContentAsString())
                    .path("data").path("correctIndex").asInt();
            examAnswers.add(Map.of("itemIndex", i, "selectedIndex", rightIdx));
        }

        mockMvc.perform(post("/api/app/realm/exam/submit")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", examSession,
                                "answers", examAnswers
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.passed").value(true))
                .andExpect(jsonPath("$.data.score").value(100))
                .andExpect(jsonPath("$.data.promotedRealm.realmCode").value("zhuji"));

        // 8. Now zhuji student CAN suppress realm to play lianqi gate 1 (suppressedMode == true)!
        mockMvc.perform(post("/api/app/quiz/start")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gateId", gate1Id))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.suppressedMode").value(true));

        // 9. Admin can directly modify student realm via PUT /api/admin/users/{id}/realm
        long stuId = objectMapper.readTree(regRes.getResponse().getContentAsString())
                .path("data").path("profile").path("id").asLong();
        mockMvc.perform(put("/api/admin/users/" + stuId + "/realm")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"realmCode\":\"yuanying\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        mockMvc.perform(get("/api/app/user/profile")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.realmCode").value("yuanying"))
                .andExpect(jsonPath("$.data.realmName").value("高二"));
    }
}
