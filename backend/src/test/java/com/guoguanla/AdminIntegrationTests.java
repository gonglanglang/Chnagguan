package com.guoguanla;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    private String loginAsAdmin() throws Exception {
        String body = objectMapper.writeValueAsString(Map.of("username", "admin", "password", "admin123"));
        MvcResult res = mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andReturn();

        JsonNode root = objectMapper.readTree(res.getResponse().getContentAsString());
        return root.path("data").path("accessToken").asText();
    }

    @Test
    void unauthenticatedAdminEndpointShouldReturn401() throws Exception {
        mockMvc.perform(get("/api/admin/dashboard/overview"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void dashboardUsersBankLevelsAndAuditLogsShouldWorkEndToEnd() throws Exception {
        String token = loginAsAdmin();

        // 1. Dashboard overview checks seeded 51 chapters, 204 gates, 632 questions (612 prototype + 20 Studio diagram questions)
        mockMvc.perform(get("/api/admin/dashboard/overview")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.chapterCount").value(51))
                .andExpect(jsonPath("$.data.gateCount").value(204))
                .andExpect(jsonPath("$.data.questionCount").value(632))
                .andExpect(jsonPath("$.data.staticQuestionCount").value(224))
                .andExpect(jsonPath("$.data.dynamicQuestionCount").value(408));

        // 2. User list & detail & create
        mockMvc.perform(get("/api/admin/users?pageNum=1&pageSize=10")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(4));

        String createUserJson = objectMapper.writeValueAsString(Map.of(
                "username", "test_stu_01",
                "password", "123456",
                "nickname", "测试学生甲",
                "phone", "13911112222",
                "gradeCode", "g7"
        ));
        MvcResult createdUserRes = mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createUserJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        long newUserId = objectMapper.readTree(createdUserRes.getResponse().getContentAsString()).path("data").asLong();

        mockMvc.perform(get("/api/admin/users/" + newUserId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.profile.nickname").value("测试学生甲"))
                .andExpect(jsonPath("$.data.profile.phoneMasked").value("139****2222"));

        // 3. Create custom chapter -> auto-creates 4 gates -> create question & preview dynamic rule
        String createChapJson = objectMapper.writeValueAsString(Map.of(
                "gradeCode", "g7",
                "name", "第1章补充 绝对值专题",
                "description", "绝对值几何意义拓展",
                "sortOrder", 99
        ));
        MvcResult chapRes = mockMvc.perform(post("/api/admin/chapters")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createChapJson))
                .andExpect(status().isOk())
                .andReturn();
        long newChapId = objectMapper.readTree(chapRes.getResponse().getContentAsString()).path("data").asLong();

        MvcResult gatesRes = mockMvc.perform(get("/api/admin/chapters/" + newChapId + "/gates")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(4))
                .andReturn();
        long firstGateId = objectMapper.readTree(gatesRes.getResponse().getContentAsString())
                .path("data").get(0).path("id").asLong();

        // Create static question
        String createQJson = objectMapper.writeValueAsString(Map.ofEntries(
                Map.entry("gradeCode", "g7"),
                Map.entry("chapterId", newChapId),
                Map.entry("gateId", firstGateId),
                Map.entry("questionMode", "STATIC"),
                Map.entry("questionFormat", "SINGLE_CHOICE"),
                Map.entry("stem", "|−9| ="),
                Map.entry("options", List.of("9", "−9", "0", "1/9")),
                Map.entry("answer", Map.of("index", 0)),
                Map.entry("analysis", "负数的绝对值是它的相反数"),
                Map.entry("difficulty", 1),
                Map.entry("tags", List.of("绝对值"))
        ));
        MvcResult qRes = mockMvc.perform(post("/api/admin/questions")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createQJson))
                .andExpect(status().isOk())
                .andReturn();
        long newQId = objectMapper.readTree(qRes.getResponse().getContentAsString()).path("data").asLong();
        assertTrue(newQId > 0);

        // Preview dynamic template generation
        String previewJson = objectMapper.writeValueAsString(Map.of(
                "questionMode", "DYNAMIC_TEMPLATE",
                "count", 3,
                "templateRule", Map.of(
                        "type", "PARAM_TEMPLATE",
                        "vars", Map.of("k", List.of(2, 9)),
                        "stemTpl", "|−{{k}}| =",
                        "ansExpr", "k",
                        "wrongExprs", List.of("-k", "0", "k+1")
                )
        ));
        mockMvc.perform(post("/api/admin/questions/preview-generate")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(previewJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(3));

        // 4. Verify operation audit logs recorded mutations
        mockMvc.perform(get("/api/admin/logs?pageNum=1&pageSize=10")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(3));
    }
}
