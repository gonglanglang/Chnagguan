package com.guoguanla;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.module.ai.AiBoardService;
import com.guoguanla.module.ai.AiConfigService;
import com.guoguanla.module.ai.vo.AiBoardVO;
import com.guoguanla.module.app.CaptchaService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AiModuleTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AiBoardService aiBoardService;

    @Autowired
    private CaptchaService captchaService;

    private String loginAdminToken() throws Exception {
        MvcResult res = mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"admin\",\"password\":\"admin123\"}"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode root = objectMapper.readTree(res.getResponse().getContentAsString());
        return root.path("data").path("accessToken").asText();
    }

    @Test
    void resolveOpenAiChatCompletionsUrlVariants() {
        assertThat(AiConfigService.resolveChatCompletionsUrl("https://api.longcat.chat/openai"))
                .isEqualTo("https://api.longcat.chat/openai/v1/chat/completions");
        assertThat(AiConfigService.resolveChatCompletionsUrl("https://api.longcat.chat/openai/"))
                .isEqualTo("https://api.longcat.chat/openai/v1/chat/completions");
        assertThat(AiConfigService.resolveChatCompletionsUrl("https://api.openai.com/v1"))
                .isEqualTo("https://api.openai.com/v1/chat/completions");
        assertThat(AiConfigService.resolveChatCompletionsUrl("https://example.com/custom/v1/chat/completions"))
                .isEqualTo("https://example.com/custom/v1/chat/completions");
    }

    @Test
    void parseRecognizeAndGuidanceWithUnescapedLatexJson() {
        String rawWithLatex = """
                ```json
                {
                  "title": "一元二次方程求解",
                  "problemText": "解方程：$x^2 - 3x + \\frac{5}{4} = 0$，并求 $\\Delta$ 的值。\\n(2) 求两根之积。",
                  "subjectTag": "一元二次方程",
                  "questionType": "解答题",
                  "difficulty": "中档",
                  "knownConditions": ["$a=1, b=-3, c=\\frac{5}{4}$"],
                  "targets": ["求出 $x_1, x_2$"],
                  "hasFigure": false,
                  "diagrams": [
                    {
                      "title": "抛物线草图",
                      "width": 320,
                      "height": 220,
                      "primitives": [
                        {"type": "line", "x1": 20, "y1": 180, "x2": 300, "y2": 180, "color": "#334155"},
                        {"type": "polyline", "points": [[60,160],[160,60],[260,160]], "color": "#2563EB"},
                        {"type": "point", "x": 160, "y": 60, "label": "顶点", "color": "#DC2626"}
                      ]
                    }
                  ]
                }
                ```
                """;
        AiBoardVO.RecognizeVO rec = aiBoardService.parseRecognizeResult(rawWithLatex, "LongCat-2.5", 320L);
        assertThat(rec.getTitle()).isEqualTo("一元二次方程求解");
        assertThat(rec.getProblemText()).contains("\\frac{5}{4}");
        assertThat(rec.getProblemText()).contains("\\Delta");
        assertThat(rec.getDiagrams()).hasSize(1);
        assertThat(rec.getDiagrams().get(0).getPrimitives()).hasSize(3);

        String rawGuidance = """
                {
                  "headline": "配方法与求根公式",
                  "summary": "先判别式定根数，再配方或公式求解。",
                  "knowledgePoints": ["判别式", "求根公式"],
                  "studentDiagnosis": {
                    "status": "PARTIAL",
                    "comment": "判别式列式正确，化简时符号漏写。",
                    "mistakePoint": "第2行 $4ac$ 计算错误",
                    "suggestion": "把 $c=\\frac{5}{4}$ 代入 $4\\times 1\\times \\frac{5}{4}=5$"
                  },
                  "steps": [
                    {"stepNo": 1, "title": "计算判别式", "content": "代入系数", "formula": "$\\Delta = (-3)^2 - 4\\times 1\\times \\frac{5}{4} = 4$", "highlight": "注意负号平方为正"},
                    {"stepNo": 2, "title": "代入求根公式", "content": "化简得两根", "formula": "$x = \\frac{3 \\pm 2}{2}$", "highlight": ""}
                  ],
                  "finalAnswer": "$x_1 = \\frac{5}{2},\\; x_2 = \\frac{1}{2}$",
                  "pitfalls": ["符号错误"],
                  "diagrams": []
                }
                """;
        AiBoardVO.GuidanceVO guidance = aiBoardService.parseGuidanceResult("SOLVE", rawGuidance, "LongCat-2.5", 500L);
        assertThat(guidance.getHeadline()).isEqualTo("配方法与求根公式");
        assertThat(guidance.getStudentDiagnosis()).isNotNull();
        assertThat(guidance.getStudentDiagnosis().getStatus()).isEqualTo("PARTIAL");
        assertThat(guidance.getSteps()).hasSize(2);
        assertThat(guidance.getSteps().get(0).getFormula()).contains("\\times");
        assertThat(guidance.getFinalAnswer()).contains("\\frac{5}{2}");

        // 单独校验纯合法 JSON 中单反斜杠 \frac / \times 不会被 Jackson 静默转成控制字符
        String singleSlashJson = "{\"headline\":\"答案\",\"finalAnswer\":\"（1）$\\frac{x^2}{2}+y^2=1$ （2）$k=\\pm\\dfrac{\\sqrt{10}}{2}$\",\"steps\":[]}";
        AiBoardVO.GuidanceVO singleParsed = aiBoardService.parseGuidanceResult("SOLVE", singleSlashJson, "LongCat-2.5", 100L);
        assertThat(singleParsed.getFinalAnswer()).contains("\\frac{x^2}{2}");
        assertThat(singleParsed.getFinalAnswer()).contains("\\dfrac{\\sqrt{10}}{2}");
        assertThat(singleParsed.getFinalAnswer()).doesNotContain("\f");

        // 思路模式与诊断模式必须屏蔽最终答案
        AiBoardVO.GuidanceVO ideasOnly = aiBoardService.parseGuidanceResult("IDEAS", rawGuidance, "LongCat-2.5", 300L);
        assertThat(ideasOnly.getFinalAnswer()).isEmpty();
        AiBoardVO.GuidanceVO diagOnly = aiBoardService.parseGuidanceResult("DIAGNOSE", rawGuidance, "LongCat-2.5", 300L);
        assertThat(diagOnly.getFinalAnswer()).isEmpty();
    }

    @Test
    void diagnoseEndpointRequiresHandwritingImage() throws Exception {
        mockMvc.perform(post("/api/app/ai/board/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"problemText\":\"解方程 x^2-1=0\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void boardGuidanceEndpointsRequireRecognizedProblemFirst() throws Exception {
        mockMvc.perform(post("/api/app/ai/board/ideas")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"problemText\":\"\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        mockMvc.perform(post("/api/app/ai/board/solve")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"problemText\":\"   \"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void recognizeRejectsScribbleOrInvalidMathProblem() {
        String scribbleJson = """
                {
                  "isValidMathProblem": false,
                  "invalidReason": "检测到随手涂鸦线条，并非完整可解的数学题",
                  "problemText": ""
                }
                """;
        org.assertj.core.api.Assertions.assertThatThrownBy(
                () -> aiBoardService.parseRecognizeResult(scribbleJson, "LongCat-2.5", 90L)
        ).hasMessageContaining("涂鸦");
    }

    @Test
    void adminAiConfigSavesSecurelyMasksKeyAndExposesSafeAppStatus() throws Exception {
        String token = loginAdminToken();
        String fakeSecret = "test_fake_key_998877665544";

        // 1. 保存配置（含虚构测试密钥）
        String body = """
                {
                  "enabled": true,
                  "baseUrl": "https://api.longcat.chat/openai",
                  "apiKey": "%s",
                  "model": "LongCat-2.5",
                  "visionModel": "",
                  "temperature": 0.2,
                  "maxTokens": 4096,
                  "timeoutSec": 60,
                  "systemPrompt": "严谨耐心"
                }
                """.formatted(fakeSecret);

        mockMvc.perform(put("/api/admin/ai/config")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.hasApiKey").value(true))
                .andExpect(jsonPath("$.data.apiKeyMasked").value("test_f****5544"))
                .andExpect(jsonPath("$.data.resolvedEndpoint").value("https://api.longcat.chat/openai/v1/chat/completions"));

        // 2. 再次更新但留空 apiKey，应保留原密钥
        mockMvc.perform(put("/api/admin/ai/config")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "enabled": true,
                                  "baseUrl": "https://api.longcat.chat/openai",
                                  "apiKey": "",
                                  "model": "LongCat-2.5"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.hasApiKey").value(true))
                .andExpect(jsonPath("$.data.apiKeyMasked").value("test_f****5544"));

        // 3. 通用 /api/admin/configs 接口和审计日志均不得泄露明文密钥
        String cfgResp = mockMvc.perform(get("/api/admin/configs")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        assertThat(cfgResp).doesNotContain(fakeSecret);

        String logsResp = mockMvc.perform(get("/api/admin/logs")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        assertThat(logsResp).doesNotContain(fakeSecret);

        // 4. 学生端状态接口不暴露任何密钥字段
        String statusResp = mockMvc.perform(get("/api/app/ai/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.enabled").value(true))
                .andExpect(jsonPath("$.data.configured").value(true))
                .andExpect(jsonPath("$.data.modelName").value("LongCat-2.5"))
                .andReturn().getResponse().getContentAsString();
        assertThat(statusResp).doesNotContain(fakeSecret);
    }

    @Test
    void adminAiConfigRejectsUnauthenticatedAccess() throws Exception {
        mockMvc.perform(get("/api/admin/ai/config"))
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void parseRecognizeFigureBoxesNormalizesCoordinates() {
        String raw = """
                {
                  "title": "几何相似三角形",
                  "problemText": "如图，在 $\\triangle ABC$ 中，$DE \\parallel BC$。",
                  "hasFigure": false,
                  "figureBoxes": [
                    {"title": "原题几何图", "x": 0.12, "y": 0.45, "w": 0.72, "h": 0.48},
                    {"title": "千分比兼容框", "x": 100, "y": 200, "w": 500, "h": 400}
                  ],
                  "diagrams": []
                }
                """;
        AiBoardVO.RecognizeVO rec = aiBoardService.parseRecognizeResult(raw, "LongCat-2.5", 180L);
        assertThat(rec.getHasFigure()).isTrue();
        assertThat(rec.getFigureBoxes()).hasSize(2);
        assertThat(rec.getFigureBoxes().get(0).getX()).isEqualTo(0.12);
        assertThat(rec.getFigureBoxes().get(0).getW()).isEqualTo(0.72);
        assertThat(rec.getFigureBoxes().get(1).getX()).isEqualTo(0.1);
        assertThat(rec.getFigureBoxes().get(1).getH()).isEqualTo(0.4);
    }

    @Test
    void appUserCanBindPhoneAndEmailWithoutVerification() throws Exception {
        String uname = "bind_test_" + System.currentTimeMillis();
        String capKey = captchaService.issueForTest("B8N4");
        MvcResult regRes = mockMvc.perform(post("/api/app/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "%s",
                                  "password": "password123",
                                  "nickname": "小测同学",
                                  "gradeCode": "g8",
                                  "captchaKey": "%s",
                                  "captchaCode": "B8N4"
                                }
                                """.formatted(uname, capKey)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        String appToken = objectMapper.readTree(regRes.getResponse().getContentAsString())
                .path("data").path("token").asText();

        mockMvc.perform(put("/api/app/user/profile")
                        .header("Authorization", "Bearer " + appToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nickname": "小测新昵称",
                                  "phone": "13900139888",
                                  "email": "student@example.com"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.nickname").value("小测新昵称"))
                .andExpect(jsonPath("$.data.phone").value("13900139888"))
                .andExpect(jsonPath("$.data.email").value("student@example.com"));

        mockMvc.perform(get("/api/app/user/profile")
                        .header("Authorization", "Bearer " + appToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.phone").value("13900139888"))
                .andExpect(jsonPath("$.data.email").value("student@example.com"));
    }
}
