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
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.progress.entity.UserQuizRecord;
import com.guoguanla.module.progress.mapper.UserQuizRecordMapper;
import com.guoguanla.module.system.SchemaUpgradeRunner;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.system.mapper.EduRealmMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * TASK-20261126-002 专项回归测试：
 * 1) App 更新说明 2500 字容量与超长拦截
 * 2) 跨年级自动衔接下一关（初一最后一章最后一关 -> 初二第 1 章第 1 关；高三最后一关返回空）
 * 3) OSS 自定义加速域名动态配置与 *.aliyuncs.com 默认域名拦截
 * 4) 全端去修仙：默认阶段名与存量修仙数据幂等迁移
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class Task20261126002Tests {

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
    private UserQuizRecordMapper quizRecordMapper;

    @Autowired
    private EduRealmMapper realmMapper;

    @Autowired
    private SchemaUpgradeRunner schemaUpgradeRunner;

    @Autowired
    private AliyunOssService ossService;

    private String loginAdmin() throws Exception {
        MvcResult res = mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("username", "admin", "password", "admin123"))))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(res.getResponse().getContentAsString())
                .path("data").path("accessToken").asText();
    }

    private List<Map<String, Object>> buildAllCorrectAnswers(String sessionNo) throws Exception {
        UserQuizRecord rec = quizRecordMapper.selectOne(
                new LambdaQueryWrapper<UserQuizRecord>().eq(UserQuizRecord::getSessionNo, sessionNo)
        );
        assertNotNull(rec);
        JsonNode snaps = JsonHelper.readTree(objectMapper, rec.getQuestionSnapshotJson());
        List<Map<String, Object>> ans = new ArrayList<>();
        for (JsonNode s : snaps) {
            int idx = s.path("itemIndex").asInt();
            if ("ESSAY".equals(s.path("questionFormat").asText())) {
                ans.add(Map.of("itemIndex", idx, "answerText", "解题过程", "selfCorrect", true));
            } else {
                ans.add(Map.of("itemIndex", idx, "selectedIndex", s.path("answerIndex").asInt(0)));
            }
        }
        return ans;
    }

    @Test
    void appUpdateNotesShouldAllow2500CharsAndReject2501() throws Exception {
        String adminToken = loginAdmin();
        String notes2500 = "更".repeat(2500);
        String notes2501 = "更".repeat(2501);

        mockMvc.perform(put("/api/admin/configs")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "configKey", "app_update_notes",
                                "configValue", notes2501
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        mockMvc.perform(put("/api/admin/configs")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "configKey", "app_update_notes",
                                "configValue", notes2500
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        MvcResult latest = mockMvc.perform(get("/api/app/version/latest"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        String saved = objectMapper.readTree(latest.getResponse().getContentAsString())
                .path("data").path("releaseNotes").asText();
        assertEquals(2500, saved.length(), "2500-char release notes should be persisted intact");

        // Restore short notes for clean state
        mockMvc.perform(put("/api/admin/configs")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "configKey", "app_update_notes",
                                "configValue", "1. 常规版本更新说明"
                        ))))
                .andExpect(status().isOk());
    }

    private boolean hasEnabledQuestions(Long gateId) {
        Long cnt = questionMapper.selectCount(
                new LambdaQueryWrapper<EduQuestion>()
                        .eq(EduQuestion::getGateId, gateId)
                        .eq(EduQuestion::getEnabled, 1)
        );
        return cnt != null && cnt > 0;
    }

    private EduChapter findLastPlayableChapter(String gradeCode) {
        List<EduChapter> chaps = chapterMapper.selectList(
                new LambdaQueryWrapper<EduChapter>()
                        .eq(EduChapter::getGradeCode, gradeCode)
                        .eq(EduChapter::getEnabled, 1)
                        .orderByAsc(EduChapter::getSortOrder, EduChapter::getId)
        );
        for (int i = chaps.size() - 1; i >= 0; i--) {
            EduChapter ch = chaps.get(i);
            List<EduGate> gates = gateMapper.selectList(
                    new LambdaQueryWrapper<EduGate>()
                            .eq(EduGate::getChapterId, ch.getId())
                            .eq(EduGate::getEnabled, 1)
            );
            if (gates.stream().anyMatch(g -> hasEnabledQuestions(g.getId()))) {
                return ch;
            }
        }
        return null;
    }

    private EduChapter findFirstPlayableChapter(String gradeCode) {
        List<EduChapter> chaps = chapterMapper.selectList(
                new LambdaQueryWrapper<EduChapter>()
                        .eq(EduChapter::getGradeCode, gradeCode)
                        .eq(EduChapter::getEnabled, 1)
                        .orderByAsc(EduChapter::getSortOrder, EduChapter::getId)
        );
        for (EduChapter ch : chaps) {
            List<EduGate> gates = gateMapper.selectList(
                    new LambdaQueryWrapper<EduGate>()
                            .eq(EduGate::getChapterId, ch.getId())
                            .eq(EduGate::getEnabled, 1)
            );
            if (gates.stream().anyMatch(g -> hasEnabledQuestions(g.getId()))) {
                return ch;
            }
        }
        return null;
    }

    @Test
    void quizSubmitShouldAdvanceAcrossGradesFromG7ToG8AndStopAfterH3() throws Exception {
        EduChapter lastG7Ch = findLastPlayableChapter("g7");
        EduChapter firstG8Ch = findFirstPlayableChapter("g8");
        assertNotNull(lastG7Ch);
        assertNotNull(firstG8Ch);

        List<EduGate> lastG7Gates = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .eq(EduGate::getChapterId, lastG7Ch.getId())
                        .eq(EduGate::getEnabled, 1)
                        .orderByAsc(EduGate::getGateIndex, EduGate::getId)
        ).stream().filter(g -> hasEnabledQuestions(g.getId())).toList();
        List<EduGate> firstG8Gates = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .eq(EduGate::getChapterId, firstG8Ch.getId())
                        .eq(EduGate::getEnabled, 1)
                        .orderByAsc(EduGate::getGateIndex, EduGate::getId)
        ).stream().filter(g -> hasEnabledQuestions(g.getId())).toList();
        EduGate lastG7Gate = lastG7Gates.get(lastG7Gates.size() - 1);
        EduGate firstG8Gate = firstG8Gates.get(0);
        List<Long> prevG7Passed = lastG7Gates.subList(0, lastG7Gates.size() - 1).stream()
                .map(EduGate::getId).toList();

        MvcResult startRes = mockMvc.perform(post("/api/app/quiz/start")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "gateId", lastG7Gate.getId(),
                                "guestPassedGateIds", prevG7Passed
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        String sessionNo = objectMapper.readTree(startRes.getResponse().getContentAsString())
                .path("data").path("sessionNo").asText();

        mockMvc.perform(post("/api/app/quiz/submit")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", sessionNo,
                                "answers", buildAllCorrectAnswers(sessionNo)
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.passed").value(true))
                .andExpect(jsonPath("$.data.nextGateId").value(firstG8Gate.getId()))
                .andExpect(jsonPath("$.data.nextChapterId").value(firstG8Ch.getId()))
                .andExpect(jsonPath("$.data.nextGateCrossChapter").value(true))
                .andExpect(jsonPath("$.data.nextGateCrossGrade").value(true))
                .andExpect(jsonPath("$.data.nextGradeCode").value("g8"))
                .andExpect(jsonPath("$.data.nextGradeName").value("初二"));

        // Last playable gate of h3 should have no next gate
        EduChapter lastH3Ch = findLastPlayableChapter("h3");
        assertNotNull(lastH3Ch);
        List<EduGate> lastH3Gates = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .eq(EduGate::getChapterId, lastH3Ch.getId())
                        .eq(EduGate::getEnabled, 1)
                        .orderByAsc(EduGate::getGateIndex, EduGate::getId)
        ).stream().filter(g -> hasEnabledQuestions(g.getId())).toList();
        EduGate lastH3Gate = lastH3Gates.get(lastH3Gates.size() - 1);
        List<Long> prevH3Passed = lastH3Gates.subList(0, lastH3Gates.size() - 1).stream()
                .map(EduGate::getId).toList();

        MvcResult startH3 = mockMvc.perform(post("/api/app/quiz/start")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "gateId", lastH3Gate.getId(),
                                "guestPassedGateIds", prevH3Passed
                        ))))
                .andExpect(status().isOk())
                .andReturn();
        String h3Session = objectMapper.readTree(startH3.getResponse().getContentAsString())
                .path("data").path("sessionNo").asText();

        mockMvc.perform(post("/api/app/quiz/submit")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "sessionNo", h3Session,
                                "answers", buildAllCorrectAnswers(h3Session)
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.passed").value(true))
                .andExpect(jsonPath("$.data.nextGateId").doesNotExist())
                .andExpect(jsonPath("$.data.nextGateCrossGrade").value(false));
    }

    @Test
    void ossCustomDomainConfigShouldRejectDefaultAliyunDomainAndSyncRuntime() throws Exception {
        String adminToken = loginAdmin();

        // Default aliyuncs.com domain MUST be rejected due to ApkDownloadForbidden policy
        mockMvc.perform(put("/api/admin/configs")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "configKey", "oss_custom_domain",
                                "configValue", "https://chuangguang.oss-cn-shenzhen.aliyuncs.com"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));

        // Valid custom CNAME domain should be normalized & reflected live
        mockMvc.perform(put("/api/admin/configs")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "configKey", "oss_custom_domain",
                                "configValue", "dl.guoguanla.example.com/"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        assertEquals("https://dl.guoguanla.example.com", ossService.getEffectiveCustomDomain());
        mockMvc.perform(get("/api/admin/app/version/latest")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ossCustomDomain").value("https://dl.guoguanla.example.com"))
                .andExpect(jsonPath("$.data.downloadChannel").isString());

        // Restore empty
        mockMvc.perform(put("/api/admin/configs")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "configKey", "oss_custom_domain",
                                "configValue", ""
                        ))))
                .andExpect(status().isOk());
        assertEquals("", ossService.getEffectiveCustomDomain());
    }

    @Test
    void schemaUpgradeRunnerShouldMigrateLegacyCultivationTermsToNormal() throws Exception {
        EduRealm lianqi = realmMapper.selectOne(
                new LambdaQueryWrapper<EduRealm>().eq(EduRealm::getRealmCode, "lianqi").last("LIMIT 1")
        );
        assertNotNull(lianqi);
        assertEquals("初一", lianqi.getRealmName());

        // Simulate legacy DB row containing cultivation wording
        lianqi.setRealmName("练气");
        lianqi.setDescription("引气入体，夯实有理数与基础代数根基");
        realmMapper.updateById(lianqi);

        schemaUpgradeRunner.run(new DefaultApplicationArguments());

        EduRealm migrated = realmMapper.selectById(lianqi.getId());
        assertEquals("初一", migrated.getRealmName());
        assertFalse(migrated.getDescription().contains("引气"));
    }
}
