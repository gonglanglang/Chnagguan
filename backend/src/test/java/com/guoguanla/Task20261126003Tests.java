package com.guoguanla;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.module.ai.AiBoardService;
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

import java.util.Base64;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * TASK-20261126-003 专项集成测试：
 * 1) 注册图形验证码接口生成、校验、大小写不敏感、错误拒绝与一次性消费防重放；
 * 2) AI 识题矢量配图解析（含 arc / rightAngle）、字面 \n 换行修复（不破坏 \neq）及无图元时几何矢量自动合成。
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class Task20261126003Tests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private CaptchaService captchaService;

    @Autowired
    private AiBoardService aiBoardService;

    @Test
    void registerCaptchaShouldGenerateValidPngAndEnforceOneTimeVerification() throws Exception {
        // 1. 公开获取图形验证码
        MvcResult capRes = mockMvc.perform(get("/api/app/auth/captcha"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.captchaKey").isNotEmpty())
                .andExpect(jsonPath("$.data.expireSeconds").value(300))
                .andReturn();
        JsonNode data = objectMapper.readTree(capRes.getResponse().getContentAsString()).path("data");
        String imageBase64 = data.path("imageBase64").asText();
        assertThat(imageBase64).startsWith("data:image/png;base64,");
        byte[] pngBytes = Base64.getDecoder().decode(imageBase64.substring("data:image/png;base64,".length()));
        // 校验 PNG 魔数头
        assertThat(pngBytes.length).isGreaterThan(100);
        assertThat(pngBytes[0]).isEqualTo((byte) 0x89);
        assertThat(pngBytes[1]).isEqualTo((byte) 'P');
        assertThat(pngBytes[2]).isEqualTo((byte) 'N');
        assertThat(pngBytes[3]).isEqualTo((byte) 'G');

        // 2. 缺少图形验证码时拒绝注册
        mockMvc.perform(post("/api/app/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "username", "cap_missing_stu",
                                "password", "pass123456",
                                "nickname", "缺验证码",
                                "gradeCode", "g7"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        // 3. 验证码错误时拒绝且立即失效（不能拿同一个 key 二次碰撞）
        String badKey = captchaService.issueForTest("K7P3");
        mockMvc.perform(post("/api/app/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "username", "cap_wrong_stu",
                                "password", "pass123456",
                                "nickname", "错验证码",
                                "gradeCode", "g7",
                                "captchaKey", badKey,
                                "captchaCode", "ZZZZ"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        // 同一 key 即使随后传对答案也应因已消费而被拒绝
        mockMvc.perform(post("/api/app/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "username", "cap_wrong_stu",
                                "password", "pass123456",
                                "nickname", "二次复用",
                                "gradeCode", "g7",
                                "captchaKey", badKey,
                                "captchaCode", "K7P3"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        // 4. 正确验证码（忽略大小写）注册成功，且再次复用被拒绝
        String okKey = captchaService.issueForTest("M9Q2");
        String okUser = "cap_ok_" + System.currentTimeMillis();
        mockMvc.perform(post("/api/app/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "username", okUser,
                                "password", "pass123456",
                                "nickname", "验证成功同学",
                                "gradeCode", "g8",
                                "captchaKey", okKey,
                                "captchaCode", "m9q2"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.token").isNotEmpty());

        mockMvc.perform(post("/api/app/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "username", okUser + "_dup",
                                "password", "pass123456",
                                "nickname", "防重放同学",
                                "gradeCode", "g8",
                                "captchaKey", okKey,
                                "captchaCode", "M9Q2"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void recognizeResultShouldSynthesizeTriangleMedianVectorDiagramAndFixLiteralNewlines() {
        // 模拟大模型识别「三角形中线问题」但 diagrams 为空且文本含双转义 \\n 的真实场景
        String rawJson = """
                {
                  "isValidMathProblem": true,
                  "title": "三角形中线长度求解",
                  "problemText": "如图，$\\\\triangle ABC$ 中，$AD$ 为 $BC$ 的中线，已知 $AB$、$AC$ 及 $\\\\angle A$（$AB \\\\neq AC$），求中线 $AD$ 长。\\\\n注：若将条件换为 $\\\\frac{BD}{CD}=\\\\lambda$ 可用向量法。",
                  "subjectTag": "三角形中线",
                  "questionType": "解答题",
                  "difficulty": "中档",
                  "knownConditions": ["△ABC 中 AD 为 BC 中线"],
                  "targets": ["求中线 AD 长度"],
                  "hasFigure": true,
                  "figureNote": "三角形 ABC 与中线 AD",
                  "figureBoxes": [{"title": "原题配图", "x": 0.05, "y": 0.25, "w": 0.5, "h": 0.4}],
                  "diagrams": []
                }
                """;
        AiBoardVO.RecognizeVO rec = aiBoardService.parseRecognizeResult(rawJson, "vision-model", 150L);

        // 1. 字面 \n 注：已转为真实换行，且 \neq 未被误损
        assertThat(rec.getProblemText()).contains("\n注：");
        assertThat(rec.getProblemText()).doesNotContain("\\n注：");
        assertThat(rec.getProblemText()).contains("\\neq");

        // 2. 自动合成清晰矢量图（△ABC + 中线 AD + 顶点标签 A/B/C/D + ∠A 弧线）
        assertThat(rec.getHasFigure()).isTrue();
        assertThat(rec.getDiagrams()).hasSize(1);
        AiBoardVO.BoardDiagramVO diagram = rec.getDiagrams().get(0);
        assertThat(diagram.getTitle()).contains("ABC").contains("AD");
        assertThat(diagram.getPrimitives()).anyMatch(p -> "polygon".equals(p.getType()));
        assertThat(diagram.getPrimitives()).anyMatch(p -> "line".equals(p.getType()));
        assertThat(diagram.getPrimitives()).anyMatch(p -> "point".equals(p.getType()) && "D".equals(p.getLabel()));
        assertThat(diagram.getPrimitives()).anyMatch(p -> "arc".equals(p.getType()));
    }

    @Test
    void recognizeResultShouldPreserveAiSuppliedArcAndRightAnglePrimitives() {
        String rawJson = """
                {
                  "isValidMathProblem": true,
                  "title": "直角三角形斜边高",
                  "problemText": "如图，在 Rt△ABC 中，∠C=90°。",
                  "hasFigure": true,
                  "diagrams": [
                    {
                      "title": "Rt△ABC",
                      "width": 320,
                      "height": 210,
                      "primitives": [
                        {"type": "polygon", "points": [[60,40],[60,170],[250,170]], "color": "#0F172A"},
                        {"type": "rightAngle", "vx": 60, "vy": 170, "ax": 250, "ay": 170, "bx": 60, "by": 40, "size": 12, "color": "#DC2626"},
                        {"type": "arc", "cx": 250, "cy": 170, "r": 24, "startAngle": 180, "sweepAngle": 34, "color": "#0284C7"}
                      ]
                    }
                  ]
                }
                """;
        AiBoardVO.RecognizeVO rec = aiBoardService.parseRecognizeResult(rawJson, "vision-model", 110L);
        assertThat(rec.getDiagrams()).hasSize(1);
        var prims = rec.getDiagrams().get(0).getPrimitives();
        assertThat(prims).hasSize(3);
        assertThat(prims.get(1).getVx()).isEqualTo(60.0);
        assertThat(prims.get(1).getSize()).isEqualTo(12.0);
        assertThat(prims.get(2).getStartAngle()).isEqualTo(180.0);
        assertThat(prims.get(2).getSweepAngle()).isEqualTo(34.0);
    }
}
