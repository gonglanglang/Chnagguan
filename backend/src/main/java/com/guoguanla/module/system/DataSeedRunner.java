package com.guoguanla.module.system;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.module.bank.entity.EduChapter;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.entity.EduGrade;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduChapterMapper;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.bank.mapper.EduGradeMapper;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import com.guoguanla.module.progress.entity.UserGateProgress;
import com.guoguanla.module.progress.entity.UserQuizRecord;
import com.guoguanla.module.progress.entity.UserWrongQuestion;
import com.guoguanla.module.progress.mapper.UserGateProgressMapper;
import com.guoguanla.module.progress.mapper.UserQuizRecordMapper;
import com.guoguanla.module.progress.mapper.UserWrongQuestionMapper;
import com.guoguanla.module.system.entity.EduLevelRule;
import com.guoguanla.module.system.entity.SysAdmin;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.mapper.EduLevelRuleMapper;
import com.guoguanla.module.system.mapper.SysAdminMapper;
import com.guoguanla.module.system.mapper.SysConfigMapper;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.mindrot.jbcrypt.BCrypt;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.*;

/**
 * 幂等初始化服务：空库时自动写入默认管理员、系统参数、原版 51 章 204 关题库及演示学生数据。
 */
@Slf4j
@Order(2)
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "guoguanla.seed.enabled", havingValue = "true", matchIfMissing = true)
public class DataSeedRunner implements ApplicationRunner {

    private final SysAdminMapper adminMapper;
    private final SysConfigMapper configMapper;
    private final EduLevelRuleMapper levelRuleMapper;
    private final EduGradeMapper gradeMapper;
    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final EduQuestionMapper questionMapper;
    private final AppUserMapper userMapper;
    private final UserGateProgressMapper gateProgressMapper;
    private final UserQuizRecordMapper quizRecordMapper;
    private final UserWrongQuestionMapper wrongMapper;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void run(ApplicationArguments args) throws Exception {
        seedAdmins();
        seedConfigs();
        Map<Long, Long> gateIdMap = seedPrototypeBank();
        seedDemoUsers(gateIdMap);
    }

    private void seedAdmins() {
        if (adminMapper.selectCount(null) > 0) {
            return;
        }
        SysAdmin superAdmin = new SysAdmin();
        superAdmin.setUsername("admin");
        superAdmin.setPasswordHash(BCrypt.hashpw("admin123", BCrypt.gensalt()));
        superAdmin.setRealName("超级管理员");
        superAdmin.setRoleCode("SUPER_ADMIN");
        superAdmin.setStatus(1);
        adminMapper.insert(superAdmin);

        SysAdmin teacher = new SysAdmin();
        teacher.setUsername("teacher");
        teacher.setPasswordHash(BCrypt.hashpw("teacher123", BCrypt.gensalt()));
        teacher.setRealName("张教研老师");
        teacher.setRoleCode("TEACHER");
        teacher.setStatus(1);
        adminMapper.insert(teacher);
        log.info("Initialized default admin accounts (admin / teacher)");
    }

    private void seedConfigs() {
        if (configMapper.selectCount(null) > 0) {
            return;
        }
        insertConfig("guest_mode_enabled", "true", "是否允许学生端免登录游客试玩第1章");
        insertConfig("default_question_count", "3", "新关卡默认每次抽题数");
        insertConfig("default_pass_count", "2", "新关卡默认最少答对过关数");
        insertConfig("app_notice",
                "1. 全年级同步闯关：初一至高三 51 章 204 关自由开放练习，支持基础关 → 下一关 → 下一章 → 跨年级连续闯关；\n"
                        + "2. 精绘数学矢量配图：526 道几何、函数、统计与立体几何题目均配有清晰矢量图，点击可全屏缩放；\n"
                        + "3. AI 智能手写画板：支持拍照与手写识题，自动矢量重绘几何配图并提供思路引导、过程诊断与解题核对；\n"
                        + "4. 错题本高效巩固：闯关错题自动收录，重做答对即标记掌握并移出。",
                "前台首页学习公告文案");
    }

    private void insertConfig(String key, String value, String desc) {
        SysConfig cfg = new SysConfig();
        cfg.setConfigKey(key);
        cfg.setConfigValue(value);
        cfg.setDescription(desc);
        configMapper.insert(cfg);
    }

    private Map<Long, Long> seedPrototypeBank() throws Exception {
        Map<Long, Long> gateIdMap = new HashMap<>();
        if (gradeMapper.selectCount(null) > 0) {
            return gateIdMap;
        }
        ClassPathResource resource = new ClassPathResource("db/prototype-bank.json");
        if (!resource.exists()) {
            log.warn("prototype-bank.json not found, skipping prototype bank seed");
            return gateIdMap;
        }
        try (InputStream is = resource.getInputStream()) {
            JsonNode root = objectMapper.readTree(is);

            for (JsonNode lvNode : root.path("levels")) {
                EduLevelRule lv = new EduLevelRule();
                lv.setMinGates(lvNode.get("minGates").asInt());
                lv.setIcon(lvNode.get("icon").asText());
                lv.setLevelName(lvNode.get("levelName").asText());
                lv.setQuote(lvNode.get("quote").asText());
                lv.setSortOrder(lvNode.get("sortOrder").asInt());
                levelRuleMapper.insert(lv);
            }

            for (JsonNode gNode : root.path("grades")) {
                EduGrade g = new EduGrade();
                g.setGradeCode(gNode.get("gradeCode").asText());
                g.setGradeName(gNode.get("gradeName").asText());
                g.setIcon(gNode.get("icon").asText());
                g.setSortOrder(gNode.get("sortOrder").asInt());
                g.setEnabled(1);
                gradeMapper.insert(g);
            }

            Map<Long, Long> chapIdMap = new HashMap<>();
            for (JsonNode cNode : root.path("chapters")) {
                EduChapter c = new EduChapter();
                c.setChapterCode(cNode.get("chapterCode").asText());
                c.setGradeCode(cNode.get("gradeCode").asText());
                c.setName(cNode.get("name").asText());
                c.setDescription(cNode.path("description").asText(""));
                c.setIsCustom(0);
                c.setSortOrder(cNode.get("sortOrder").asInt());
                c.setEnabled(1);
                chapterMapper.insert(c);
                chapIdMap.put(cNode.get("id").asLong(), c.getId());
            }

            for (JsonNode gtNode : root.path("gates")) {
                Long newChapId = chapIdMap.get(gtNode.get("chapterId").asLong());
                EduGate gt = new EduGate();
                gt.setChapterId(newChapId);
                gt.setGateIndex(gtNode.get("gateIndex").asInt());
                gt.setGateName(gtNode.get("gateName").asText());
                gt.setStar(gtNode.get("star").asInt());
                gt.setQuestionCount(gtNode.get("questionCount").asInt(3));
                gt.setPassCount(gtNode.get("passCount").asInt(2));
                gt.setEnabled(1);
                gateMapper.insert(gt);
                gateIdMap.put(gtNode.get("id").asLong(), gt.getId());
            }

            for (JsonNode qNode : root.path("questions")) {
                Long newChapId = chapIdMap.get(qNode.get("chapterId").asLong());
                Long newGateId = gateIdMap.get(qNode.get("gateId").asLong());
                EduQuestion q = new EduQuestion();
                q.setGradeCode(qNode.get("gradeCode").asText());
                q.setChapterId(newChapId);
                q.setGateId(newGateId);
                q.setQuestionMode(qNode.get("questionMode").asText());
                q.setQuestionFormat(qNode.get("questionFormat").asText("SINGLE_CHOICE"));
                q.setStem(qNode.get("stem").asText());
                q.setOptionsJson(objectMapper.writeValueAsString(qNode.get("options")));
                q.setAnswerJson(objectMapper.writeValueAsString(qNode.get("answer")));
                q.setAnalysis(qNode.path("analysis").asText(""));
                if (!qNode.path("generatorCode").isNull()) {
                    q.setGeneratorCode(qNode.get("generatorCode").asText());
                }
                if (!qNode.path("templateRule").isNull()) {
                    q.setTemplateRuleJson(objectMapper.writeValueAsString(qNode.get("templateRule")));
                }
                q.setDifficulty(qNode.path("difficulty").asInt(1));
                q.setTagsJson(objectMapper.writeValueAsString(qNode.path("tags")));
                q.setSource("PROTOTYPE");
                q.setVersion(1);
                q.setSortOrder(qNode.path("sortOrder").asInt(0));
                q.setEnabled(1);
                questionMapper.insert(q);
            }
            log.info("Seeded prototype bank: 6 grades, 51 chapters, 204 gates, 612 questions, 10 levels");
        }
        return gateIdMap;
    }

    private void seedDemoUsers(Map<Long, Long> gateIdMap) throws Exception {
        if (userMapper.selectCount(null) > 0) {
            return;
        }
        LocalDateTime now = LocalDateTime.now();
        AppUser s1 = createDemoUser("stu_linxiaoyu", "林小雨", "13800138001", "g7", "lianqi", 14, now.minusHours(1), "初一重点跟进学生");
        AppUser s2 = createDemoUser("stu_chenziyu", "陈子轩", "13800138002", "g8", "zhuji", 28, now.minusHours(3), "初二阶段，可回刷初一巩固基础");
        AppUser s3 = createDemoUser("stu_wangshiqi", "王诗琪", "13800138003", "h1", "jiaying", 6, now.minusDays(1), "初入高一阶段");
        AppUser s4 = createDemoUser("stu_zhaoming", "赵明哲", "13800138004", "h3", "huashen", 65, now.minusMinutes(25), "高三冲刺阶段");

        List<EduGate> allGates = gateMapper.selectList(null);
        if (!allGates.isEmpty()) {
            // 为第一位学生造几条真实过关与错题数据以便后台详情预览
            List<EduGate> firstFew = allGates.stream().limit(4).toList();
            for (EduGate gt : firstFew) {
                UserGateProgress prog = new UserGateProgress();
                prog.setUserId(s1.getId());
                prog.setChapterId(gt.getChapterId());
                prog.setGateId(gt.getId());
                prog.setGateIndex(gt.getGateIndex());
                prog.setIsPassed(1);
                prog.setBestCorrect(3);
                prog.setAttemptCount(1);
                prog.setFirstPassedAt(now.minusDays(2));
                prog.setLastPlayedAt(now.minusHours(2));
                gateProgressMapper.insert(prog);
            }

            UserQuizRecord rec = new UserQuizRecord();
            rec.setSessionNo("QZ" + System.currentTimeMillis());
            rec.setUserId(s1.getId());
            rec.setMode("GATE");
            rec.setChapterId(firstFew.get(0).getChapterId());
            rec.setGateId(firstFew.get(0).getId());
            rec.setQuestionSnapshotJson(objectMapper.writeValueAsString(List.of(
                    Map.of("stem", "−3 的相反数是", "options", List.of("3", "−3", "1/3", "−1/3"), "answerIndex", 0, "userIndex", 0)
            )));
            rec.setTotalCount(3);
            rec.setCorrectCount(2);
            rec.setIsPassed(1);
            rec.setStatus(1);
            rec.setStartedAt(now.minusHours(2));
            rec.setSubmittedAt(now.minusHours(2).plusMinutes(1));
            quizRecordMapper.insert(rec);

            EduChapter ch1 = chapterMapper.selectById(firstFew.get(0).getChapterId());
            String stem1 = "计算 (−2)+5 =";
            UserWrongQuestion w1 = new UserWrongQuestion();
            w1.setUserId(s1.getId());
            w1.setGradeCode("g7");
            w1.setChapterId(ch1.getId());
            w1.setChapterName(ch1.getName());
            w1.setGateName("基础关");
            w1.setStemHash(sha256(stem1));
            w1.setStem(stem1);
            w1.setOptionsJson(objectMapper.writeValueAsString(List.of("−7", "−3", "3", "7")));
            w1.setAnswerJson(objectMapper.writeValueAsString(Map.of("index", 2)));
            w1.setAnalysis("异号两数相加，取绝对值较大加数的符号，并用较大绝对值减去较小绝对值");
            w1.setWrongCount(2);
            w1.setIsMastered(0);
            w1.setLastWrongAt(now.minusHours(2));
            wrongMapper.insert(w1);

            String stem2 = "|−5| =";
            UserWrongQuestion w2 = new UserWrongQuestion();
            w2.setUserId(s2.getId());
            w2.setGradeCode("g7");
            w2.setChapterId(ch1.getId());
            w2.setChapterName(ch1.getName());
            w2.setGateName("基础关");
            w2.setStemHash(sha256(stem2));
            w2.setStem(stem2);
            w2.setOptionsJson(objectMapper.writeValueAsString(List.of("−5", "5", "±5", "1/5")));
            w2.setAnswerJson(objectMapper.writeValueAsString(Map.of("index", 1)));
            w2.setWrongCount(1);
            w2.setIsMastered(0);
            w2.setLastWrongAt(now.minusHours(5));
            wrongMapper.insert(w2);
        }
        log.info("Initialized 4 demo student users (s1..s4={},{},{},{})", s1.getId(), s2.getId(), s3.getId(), s4.getId());
    }

    private AppUser createDemoUser(String username, String nickname, String phone, String gradeCode,
                                   String realmCode, int passedGates, LocalDateTime activeAt, String remark) {
        AppUser u = new AppUser();
        u.setUsername(username);
        u.setPasswordHash(BCrypt.hashpw("123456", BCrypt.gensalt()));
        u.setNickname(nickname);
        u.setPhone(phone);
        u.setGradeCode(gradeCode);
        u.setRealmCode(realmCode);
        u.setPassedGateCount(passedGates);
        u.setCurrentLevelId(1L);
        u.setRemark(remark);
        u.setStatus(1);
        u.setLastActiveAt(activeAt);
        userMapper.insert(u);
        return u;
    }

    private String sha256(String input) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
        StringBuilder hex = new StringBuilder();
        for (byte b : hash) {
            hex.append(String.format("%02x", b));
        }
        return hex.toString();
    }
}
