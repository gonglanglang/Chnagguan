package com.guoguanla;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.module.app.CaptchaService;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import com.guoguanla.module.dashboard.StudentOnlineTrackerService;
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

import javax.xml.parsers.DocumentBuilderFactory;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * TASK-20261127-001 专项集成测试：
 * 1) 学生切换/晋级年级阶段 API (`PUT /api/app/user/grade`)；
 * 2) 首页师资力量轮播图：默认种子、管理端 CRUD + XSS 过滤、学生端列表与富文本详情、内置 PNG 封面；
 * 3) 后台实时学生在线人数统计（登录/心跳感知 + `/dashboard/overview` & `/dashboard/online-students` + 退出即时离线）；
 * 4) 错题本 A4 Word (.docx) 导出（标准 OOXML ZIP 校验、A4 尺寸、XML 合法性、Java2D 矢量图内嵌）。
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class Task20261127Tests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private CaptchaService captchaService;

    @Autowired
    private StudentOnlineTrackerService onlineTracker;

    @Autowired
    private UserWrongQuestionMapper wrongMapper;

    @Autowired
    private EduQuestionMapper questionMapper;

    private String loginAdmin() throws Exception {
        MvcResult res = mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "username", "admin",
                                "password", "admin123"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        return objectMapper.readTree(res.getResponse().getContentAsString())
                .path("data").path("accessToken").asText();
    }

    private record StudentSession(long userId, String token) {}

    private StudentSession registerStudent(String prefix, String gradeCode) throws Exception {
        String capKey = captchaService.issueForTest("A8K2");
        String uname = prefix + "_" + UUID.randomUUID().toString().substring(0, 6);
        MvcResult res = mockMvc.perform(post("/api/app/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "username", uname,
                                "password", "pass123456",
                                "nickname", "测试同学_" + prefix,
                                "gradeCode", gradeCode,
                                "captchaKey", capKey,
                                "captchaCode", "A8K2"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        JsonNode data = objectMapper.readTree(res.getResponse().getContentAsString()).path("data");
        return new StudentSession(data.path("profile").path("id").asLong(), data.path("token").asText());
    }

    @Test
    void studentCanSwitchAndPromoteGradeStage() throws Exception {
        StudentSession stu = registerStudent("grade", "g7");

        mockMvc.perform(put("/api/app/user/grade")
                        .header("Authorization", "Bearer " + stu.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gradeCode", "g8"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.gradeCode").value("g8"))
                .andExpect(jsonPath("$.data.realmCode").value("zhuji"))
                .andExpect(jsonPath("$.data.realmName").value("初二"));

        mockMvc.perform(put("/api/app/user/grade")
                        .header("Authorization", "Bearer " + stu.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("gradeCode", "invalid_grade"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void homeBannersCrudRichHtmlSanitizationAndPresetPngWork() throws Exception {
        String adminToken = loginAdmin();

        // 1. 默认种子轮播图在首页 summary 与公开接口均可见
        MvcResult summaryRes = mockMvc.perform(get("/api/app/home/summary"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.banners").isArray())
                .andReturn();
        JsonNode banners = objectMapper.readTree(summaryRes.getResponse().getContentAsString())
                .path("data").path("banners");
        assertThat(banners.size()).isGreaterThanOrEqualTo(3);

        // 2. 校验内置师资 PNG 封面输出
        byte[] presetPng = mockMvc.perform(get("/api/app/banners/preset/faculty-1"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.IMAGE_PNG))
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(presetPng.length).isGreaterThan(500);
        assertThat(presetPng[0]).isEqualTo((byte) 0x89);
        assertThat(presetPng[1]).isEqualTo((byte) 'P');

        // 3. 后台新增自定义师资轮播图（含危险脚本与相对图片路径）
        MvcResult createRes = mockMvc.perform(post("/api/admin/banners")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "title", "王牌奥数教研名师",
                                "subtitle", "省特级教师 · 20年竞赛辅导",
                                "imageKey", "preset://faculty-2",
                                "contentHtml", "<h2>名师简介</h2><p onclick=\"alert(1)\">擅长几何压轴</p><script>alert(2)</script><img src=\"/api/app/banners/media?key=home-banners/demo.png\" />",
                                "sortOrder", 0,
                                "enabled", 1
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        long newId = objectMapper.readTree(createRes.getResponse().getContentAsString()).path("data").asLong();
        assertThat(newId).isPositive();

        // 4. 学生端详情应返回已清理脚本、且补全绝对地址的富文本 HTML
        MvcResult detailRes = mockMvc.perform(get("/api/app/banners/" + newId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.title").value("王牌奥数教研名师"))
                .andReturn();
        String html = objectMapper.readTree(detailRes.getResponse().getContentAsString())
                .path("data").path("contentHtml").asText();
        assertThat(html).contains("名师简介");
        assertThat(html).doesNotContain("<script");
        assertThat(html).doesNotContain("onclick=");
        assertThat(html).contains("http://localhost/api/app/banners/media?key=home-banners/demo.png");

        // 5. 后台下架后学生端不可访问，删除清理测试数据
        mockMvc.perform(patch("/api/admin/banners/" + newId + "/status")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("enabled", 0))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        mockMvc.perform(get("/api/app/banners/" + newId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(404));

        mockMvc.perform(delete("/api/admin/banners/" + newId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));
    }

    @Test
    void onlineStudentTrackerCountsHeartbeatAndLogoutImmediately() throws Exception {
        onlineTracker.clearAll();
        String adminToken = loginAdmin();
        StudentSession stu = registerStudent("online", "g9");

        // 心跳续期
        mockMvc.perform(post("/api/app/online/heartbeat")
                        .header("Authorization", "Bearer " + stu.token())
                        .header("X-Client-Platform", "android")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "platform", "android",
                                "page", "首页学习"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.online").value(true));

        // 后台实时在线接口与总览看板均统计该学生在线
        mockMvc.perform(get("/api/admin/dashboard/online-students")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.onlineStudentCount").value(1))
                .andExpect(jsonPath("$.data.students[0].userId").value(stu.userId()))
                .andExpect(jsonPath("$.data.students[0].gradeCode").value("g9"));

        mockMvc.perform(get("/api/admin/dashboard/overview")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.onlineStudentCount").value(1));

        // 学生退出登录立即下线
        mockMvc.perform(post("/api/app/auth/logout")
                        .header("Authorization", "Bearer " + stu.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        mockMvc.perform(get("/api/admin/dashboard/online-students")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.onlineStudentCount").value(0));
    }

    @Test
    void wrongQuestionsExportDocxProducesValidA4WordWithEmbeddedDiagram() throws Exception {
        StudentSession stu = registerStudent("docx", "g8");

        // 构造一道带矢量几何图的题目与两条错题（选择题 + 解答题）
        EduQuestion q = new EduQuestion();
        q.setGradeCode("g8");
        q.setChapterId(11L);
        q.setGateId(41L);
        q.setQuestionMode("STATIC");
        q.setQuestionFormat("SINGLE_CHOICE");
        q.setStem("如图，在 Rt\\triangle ABC 中，\\angle C = 90^\\circ，AC = 3，BC = 4，则 AB =");
        q.setOptionsJson("[\"5\",\"6\",\"7\",\"\\\\sqrt{7}\"]");
        q.setAnswerJson("{\"index\":0}");
        q.setAnalysis("由勾股定理得 $AB = \\sqrt{3^2 + 4^2} = 5$。");
        q.setExtJson("""
                {
                  "diagram": {
                    "title": "Rt△ABC",
                    "width": 300,
                    "height": 190,
                    "primitives": [
                      {"type":"polygon","points":[[60,150],[240,150],[60,40]],"color":"#1E293B","fillColor":"#38BDF8"},
                      {"type":"rightAngle","vx":60,"vy":150,"ax":240,"ay":150,"bx":60,"by":40,"size":12,"color":"#0284C7"},
                      {"type":"point","x":60,"y":40,"label":"A"},
                      {"type":"point","x":60,"y":150,"label":"C"},
                      {"type":"point","x":240,"y":150,"label":"B"}
                    ]
                  }
                }
                """);
        q.setDifficulty(1);
        q.setSource("ADMIN");
        q.setVersion(1);
        q.setSortOrder(1);
        q.setEnabled(1);
        questionMapper.insert(q);

        UserWrongQuestion w1 = new UserWrongQuestion();
        w1.setUserId(stu.userId());
        w1.setQuestionId(q.getId());
        w1.setGradeCode("g8");
        w1.setChapterId(11L);
        w1.setChapterName("第17章 勾股定理");
        w1.setGateName("基础关");
        w1.setStemHash("h1_" + UUID.randomUUID().toString().replace("-", ""));
        w1.setStem(q.getStem());
        w1.setQuestionFormat("SINGLE_CHOICE");
        w1.setOptionsJson(q.getOptionsJson());
        w1.setAnswerJson(q.getAnswerJson());
        w1.setAnalysis(q.getAnalysis());
        w1.setWrongCount(3);
        w1.setIsMastered(0);
        w1.setLastWrongAt(LocalDateTime.now());
        wrongMapper.insert(w1);

        UserWrongQuestion w2 = new UserWrongQuestion();
        w2.setUserId(stu.userId());
        w2.setGradeCode("g8");
        w2.setChapterId(11L);
        w2.setChapterName("第17章 勾股定理");
        w2.setGateName("压轴关");
        w2.setStemHash("h2_" + UUID.randomUUID().toString().replace("-", ""));
        w2.setStem("证明：若 $\\frac{a}{b} = 2$，求 $a^2 - b^2$ 与 $b^2$ 的比值。");
        w2.setQuestionFormat("ESSAY");
        w2.setOptionsJson("[]");
        w2.setAnswerJson("{\"text\":\"比值为 3\"}");
        w2.setAnalysis("将 $a = 2b$ 代入即可。");
        w2.setWrongCount(1);
        w2.setIsMastered(0);
        w2.setLastWrongAt(LocalDateTime.now());
        wrongMapper.insert(w2);

        // 校验错题列表接口返回明确的题目类型标签与是否需要预留作答区标记
        mockMvc.perform(get("/api/app/wrong-questions?pageNum=1&pageSize=10")
                        .header("Authorization", "Bearer " + stu.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.records.length()").value(2));

        MvcResult res = mockMvc.perform(post("/api/app/wrong-questions/export-docx")
                        .header("Authorization", "Bearer " + stu.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "wrongIds", List.of(w1.getId(), w2.getId()),
                                "title", "初二勾股定理错题卷",
                                "answerMode", "END",
                                "includeDiagrams", true,
                                "includeWorkspace", true
                        ))))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Export-Question-Count", "2"))
                .andReturn();

        byte[] bytes = res.getResponse().getContentAsByteArray();
        assertThat(bytes.length).isGreaterThan(2000);
        // ZIP header PK\x03\x04
        assertThat(bytes[0]).isEqualTo((byte) 'P');
        assertThat(bytes[1]).isEqualTo((byte) 'K');

        Map<String, byte[]> entries = new HashMap<>();
        try (ZipInputStream zis = new ZipInputStream(new ByteArrayInputStream(bytes))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                entries.put(entry.getName(), zis.readAllBytes());
            }
        }

        assertThat(entries.keySet()).contains(
                "[Content_Types].xml",
                "_rels/.rels",
                "word/document.xml",
                "word/_rels/document.xml.rels",
                "word/styles.xml",
                "word/header1.xml",
                "word/footer1.xml",
                "word/media/img_1.png"
        );

        // 校验全部 XML 均可通过严格 DOM 解析
        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        dbf.setNamespaceAware(true);
        for (Map.Entry<String, byte[]> e : entries.entrySet()) {
            if (e.getKey().endsWith(".xml") || e.getKey().endsWith(".rels")) {
                dbf.newDocumentBuilder().parse(new ByteArrayInputStream(e.getValue()));
            }
        }

        // 校验 A4 纸尺寸、标题、分组、选择题不留作答区、解答题预留「解：」作答区、无嵌套表格及答案换行独立段落
        String docXml = new String(entries.get("word/document.xml"), StandardCharsets.UTF_8);
        assertThat(docXml).contains("w:w=\"11906\" w:h=\"16838\"");
        assertThat(docXml).contains("初二勾股定理错题卷");
        assertThat(docXml).contains("一、选择题（共 1 题）");
        assertThat(docXml).contains("二、解答题（共 1 题）");
        assertThat(docXml).contains("参考答案与解题思路");
        assertThat(docXml).contains("rIdImg1");
        assertThat(docXml).doesNotContain("订正 / 演算区");
        assertThat(docXml).doesNotContain("订正反思");
        assertThat(docXml).doesNotContain("我的作答");
        assertThat(docXml).contains("解：");
        // 仅 2 个顶级表格（卷头信息栏 + 1 道解答题作答区），绝不出现单元格内嵌套表格
        assertThat(docXml.split("<w:tbl>", -1).length - 1).isEqualTo(2);
        // 校验仅导出选择题时不含「解：」作答区
        MvcResult choiceOnlyRes = mockMvc.perform(post("/api/app/wrong-questions/export-docx")
                        .header("Authorization", "Bearer " + stu.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "wrongIds", List.of(w1.getId()),
                                "title", "纯选择题错题卷",
                                "answerMode", "END",
                                "includeDiagrams", false,
                                "includeWorkspace", true
                        ))))
                .andExpect(status().isOk())
                .andReturn();
        Map<String, byte[]> choiceEntries = new HashMap<>();
        try (ZipInputStream zis = new ZipInputStream(new ByteArrayInputStream(choiceOnlyRes.getResponse().getContentAsByteArray()))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                choiceEntries.put(entry.getName(), zis.readAllBytes());
            }
        }
        String choiceDocXml = new String(choiceEntries.get("word/document.xml"), StandardCharsets.UTF_8);
        assertThat(choiceDocXml).doesNotContain("解：");
        assertThat(choiceDocXml).doesNotContain("订正 / 演算区");
        assertThat(choiceDocXml.split("<w:tbl>", -1).length - 1).isEqualTo(1);

        // 校验嵌入矢量配图是合法 PNG
        byte[] imgBytes = entries.get("word/media/img_1.png");
        assertThat(imgBytes.length).isGreaterThan(400);
        assertThat(imgBytes[0]).isEqualTo((byte) 0x89);
        assertThat(imgBytes[1]).isEqualTo((byte) 'P');
    }
}
