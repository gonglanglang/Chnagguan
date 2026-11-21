package com.guoguanla.module.system;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.mapper.EduRealmMapper;
import com.guoguanla.module.system.mapper.SysConfigMapper;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.util.List;
import java.util.Map;

/**
 * 幂等结构升级与修仙境界初始化（兼容已存量 MySQL 与测试 H2）。
 */
@Slf4j
@Order(1)
@Component
@RequiredArgsConstructor
public class SchemaUpgradeRunner implements ApplicationRunner {

    private static final Map<String, String> GRADE_TO_REALM = Map.of(
            "g7", "lianqi",
            "g8", "zhuji",
            "g9", "jiedan",
            "h1", "jiaying",
            "h2", "yuanying",
            "h3", "huashen"
    );

    private final DataSource dataSource;
    private final JdbcTemplate jdbcTemplate;
    private final EduRealmMapper realmMapper;
    private final AppUserMapper userMapper;
    private final SysConfigMapper sysConfigMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void run(ApplicationArguments args) throws Exception {
        ensureEduRealmTable();
        ensureUserEssayAnswerTable();
        ensureVideoTables();
        boolean addedUserRealm = ensureColumn("app_user", "realm_code", "VARCHAR(24) NOT NULL DEFAULT 'lianqi'");
        ensureColumn("user_quiz_record", "realm_code", "VARCHAR(24) DEFAULT NULL");
        ensureColumn("user_quiz_record", "score", "INT DEFAULT NULL");
        ensureColumn("user_wrong_question", "question_format", "VARCHAR(24) NOT NULL DEFAULT 'SINGLE_CHOICE'");
        ensureColumn("user_wrong_question", "last_answer_image_key", "VARCHAR(512) DEFAULT NULL");
        ensureColumn("user_essay_answer", "realm_code", "VARCHAR(24) NOT NULL DEFAULT ''");
        ensureColumn("user_essay_answer", "gate_id", "BIGINT UNSIGNED DEFAULT NULL");
        ensureColumn("user_essay_answer", "teacher_image_key", "VARCHAR(512) DEFAULT NULL");
        ensureColumn("edu_video_lesson", "cover_image_key", "VARCHAR(512) NOT NULL DEFAULT ''");
        ensureColumn("edu_video_lesson", "notes_attachments", "TEXT DEFAULT NULL");

        seedDefaultRealms();
        repairMojibakeRealms();
        backfillUserRealms(addedUserRealm);
        backfillEssayGateKeys();
        upgradeNoticeCopy();
        ensureAppVersionConfigs();
    }

    private void ensureEduRealmTable() {
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS edu_realm (
                  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                  realm_code VARCHAR(24) NOT NULL,
                  realm_name VARCHAR(32) NOT NULL,
                  realm_order INT NOT NULL,
                  grade_code VARCHAR(16) NOT NULL,
                  difficulty_label VARCHAR(32) NOT NULL,
                  description VARCHAR(255) NOT NULL DEFAULT '',
                  unlock_gates INT NOT NULL DEFAULT 0,
                  exam_question_count INT NOT NULL DEFAULT 5,
                  exam_pass_score INT NOT NULL DEFAULT 60,
                  enabled TINYINT NOT NULL DEFAULT 1,
                  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  PRIMARY KEY (id),
                  UNIQUE KEY uk_realm_code (realm_code),
                  UNIQUE KEY uk_realm_grade (grade_code)
                )
                """);
    }

    private void ensureUserEssayAnswerTable() {
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS user_essay_answer (
                  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                  session_no VARCHAR(64) NOT NULL,
                  item_index INT NOT NULL DEFAULT 0,
                  user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
                  question_id BIGINT UNSIGNED DEFAULT NULL,
                  grade_code VARCHAR(16) NOT NULL DEFAULT '',
                  realm_code VARCHAR(24) NOT NULL DEFAULT '',
                  chapter_id BIGINT UNSIGNED DEFAULT NULL,
                  chapter_name VARCHAR(100) NOT NULL DEFAULT '',
                  gate_id BIGINT UNSIGNED DEFAULT NULL,
                  gate_name VARCHAR(32) NOT NULL DEFAULT '',
                  stem TEXT NOT NULL,
                  reference_answer TEXT DEFAULT NULL,
                  answer_text TEXT DEFAULT NULL,
                  answer_image_key VARCHAR(512) DEFAULT NULL,
                  self_correct TINYINT DEFAULT NULL,
                  teacher_status TINYINT NOT NULL DEFAULT 0,
                  teacher_comment VARCHAR(512) NOT NULL DEFAULT '',
                  teacher_image_key VARCHAR(512) DEFAULT NULL,
                  reviewed_by BIGINT UNSIGNED DEFAULT NULL,
                  reviewed_at DATETIME DEFAULT NULL,
                  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  PRIMARY KEY (id),
                  UNIQUE KEY uk_session_item (session_no, item_index),
                  KEY idx_essay_user_time (user_id, created_at)
                )
                """);
    }

    private void ensureVideoTables() {
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS edu_video_series (
                  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                  title VARCHAR(128) NOT NULL,
                  cover_image_key VARCHAR(512) NOT NULL DEFAULT '',
                  intro TEXT DEFAULT NULL,
                  realm_code VARCHAR(24) NOT NULL DEFAULT '',
                  sort_order INT NOT NULL DEFAULT 0,
                  enabled TINYINT NOT NULL DEFAULT 1,
                  created_by BIGINT UNSIGNED DEFAULT NULL,
                  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  deleted TINYINT NOT NULL DEFAULT 0,
                  PRIMARY KEY (id),
                  KEY idx_video_series_realm (realm_code, enabled, sort_order)
                )
                """);
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS edu_video_lesson (
                  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                  series_id BIGINT UNSIGNED NOT NULL,
                  title VARCHAR(128) NOT NULL,
                  cover_image_key VARCHAR(512) NOT NULL DEFAULT '',
                  video_key VARCHAR(512) NOT NULL DEFAULT '',
                  duration_sec INT NOT NULL DEFAULT 0,
                  class_notes MEDIUMTEXT DEFAULT NULL,
                  notes_attachments TEXT DEFAULT NULL,
                  sort_order INT NOT NULL DEFAULT 0,
                  enabled TINYINT NOT NULL DEFAULT 1,
                  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  deleted TINYINT NOT NULL DEFAULT 0,
                  PRIMARY KEY (id),
                  KEY idx_video_lesson_series (series_id, enabled, sort_order)
                )
                """);
    }

    private void backfillEssayGateKeys() {
        for (Map.Entry<String, String> entry : GRADE_TO_REALM.entrySet()) {
            jdbcTemplate.update(
                    "UPDATE user_essay_answer SET realm_code = ? WHERE (realm_code IS NULL OR realm_code = '') AND grade_code = ?",
                    entry.getValue(),
                    entry.getKey()
            );
        }
        List<Map<String, Object>> missingGateRows = jdbcTemplate.queryForList(
                "SELECT id, session_no FROM user_essay_answer WHERE gate_id IS NULL"
        );
        for (Map<String, Object> row : missingGateRows) {
            Object idObj = row.get("id");
            Object sessObj = row.get("session_no");
            if (idObj == null || sessObj == null) continue;
            List<Long> gateIds = jdbcTemplate.queryForList(
                    "SELECT gate_id FROM user_quiz_record WHERE session_no = ? LIMIT 1",
                    Long.class,
                    String.valueOf(sessObj)
            );
            if (!gateIds.isEmpty() && gateIds.get(0) != null) {
                jdbcTemplate.update(
                        "UPDATE user_essay_answer SET gate_id = ? WHERE id = ?",
                        gateIds.get(0),
                        ((Number) idObj).longValue()
                );
            }
        }
    }

    private boolean ensureColumn(String table, String column, String definition) throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            if (!hasColumn(conn, table, column)) {
                jdbcTemplate.execute("ALTER TABLE " + table + " ADD COLUMN " + column + " " + definition);
                log.info("Added missing column {}.{}", table, column);
                return true;
            }
        }
        return false;
    }

    private boolean hasColumn(Connection conn, String tableName, String columnName) throws Exception {
        try (ResultSet rs = conn.getMetaData().getColumns(conn.getCatalog(), null, null, null)) {
            while (rs.next()) {
                String t = rs.getString("TABLE_NAME");
                String c = rs.getString("COLUMN_NAME");
                if (tableName.equalsIgnoreCase(t) && columnName.equalsIgnoreCase(c)) {
                    return true;
                }
            }
        }
        return false;
    }

    private void seedDefaultRealms() {
        if (realmMapper.selectCount(null) > 0) {
            return;
        }
        List<EduRealm> defaults = List.of(
                buildRealm("lianqi", "练气", 1, "g7", "难度一 · 基础", "引气入体，夯实有理数与基础代数根基", 0, 5, 60),
                buildRealm("zhuji", "筑基", 2, "g8", "难度二 · 入门", "道基初成，攻克几何证明与一次函数", 0, 5, 60),
                buildRealm("jiedan", "结丹", 3, "g9", "难度三 · 提升", "凝丹聚元，突破二次函数与圆的综合", 0, 6, 70),
                buildRealm("jiaying", "假婴", 4, "h1", "难度四 · 强化", "化凡入圣，修习集合函数与三角恒等", 0, 6, 70),
                buildRealm("yuanying", "元婴", 5, "h2", "难度五 · 高阶", "元婴初醒，参悟数列圆锥曲线与导数", 0, 8, 75),
                buildRealm("huashen", "化神", 6, "h3", "难度六 · 巅峰", "大道至简，贯通综合压轴与巅峰冲刺", 0, 8, 80)
        );
        defaults.forEach(realmMapper::insert);
        log.info("Seeded 6 default cultivation realms (练气 -> 化神)");
    }

    private EduRealm buildRealm(String code, String name, int order, String gradeCode,
                                String diffLabel, String desc, int unlockGates, int qCount, int passScore) {
        EduRealm r = new EduRealm();
        r.setRealmCode(code);
        r.setRealmName(name);
        r.setRealmOrder(order);
        r.setGradeCode(gradeCode);
        r.setDifficultyLabel(diffLabel);
        r.setDescription(desc);
        r.setUnlockGates(unlockGates);
        r.setExamQuestionCount(qCount);
        r.setExamPassScore(passScore);
        r.setEnabled(1);
        return r;
    }

    private void repairMojibakeRealms() {
        List<EduRealm> defaults = List.of(
                buildRealm("lianqi", "练气", 1, "g7", "难度一 · 基础", "引气入体，夯实有理数与基础代数根基", 0, 5, 60),
                buildRealm("zhuji", "筑基", 2, "g8", "难度二 · 入门", "道基初成，攻克几何证明与一次函数", 0, 5, 60),
                buildRealm("jiedan", "结丹", 3, "g9", "难度三 · 提升", "凝丹聚元，突破二次函数与圆的综合", 0, 6, 70),
                buildRealm("jiaying", "假婴", 4, "h1", "难度四 · 强化", "化凡入圣，修习集合函数与三角恒等", 0, 6, 70),
                buildRealm("yuanying", "元婴", 5, "h2", "难度五 · 高阶", "元婴初醒，参悟数列圆锥曲线与导数", 0, 8, 75),
                buildRealm("huashen", "化神", 6, "h3", "难度六 · 巅峰", "大道至简，贯通综合压轴与巅峰冲刺", 0, 8, 80)
        );
        Map<String, EduRealm> defMap = defaults.stream()
                .collect(java.util.stream.Collectors.toMap(EduRealm::getRealmCode, d -> d));
        for (EduRealm existing : realmMapper.selectList(null)) {
            EduRealm d = defMap.get(existing.getRealmCode());
            if (d == null) continue;
            if (looksLikeMojibake(existing.getRealmName())
                    || looksLikeMojibake(existing.getDifficultyLabel())
                    || looksLikeMojibake(existing.getDescription())) {
                existing.setRealmName(d.getRealmName());
                existing.setDifficultyLabel(d.getDifficultyLabel());
                existing.setDescription(d.getDescription());
                realmMapper.updateById(existing);
                log.info("Repaired mojibake text for realm {}", existing.getRealmCode());
            }
        }
    }

    private boolean looksLikeMojibake(String s) {
        if (s == null || s.isEmpty()) return false;
        for (int i = 0; i < s.length(); i++) {
            char ch = s.charAt(i);
            if ((ch >= 0x0080 && ch <= 0x00FF) && (s.contains("ç") || s.contains("é") || s.contains("å") || s.contains("Â"))) {
                return true;
            }
        }
        return false;
    }

    private void backfillUserRealms(boolean forceSyncFromGrade) {
        List<AppUser> users = userMapper.selectList(null);
        for (AppUser u : users) {
            if (forceSyncFromGrade || u.getRealmCode() == null || u.getRealmCode().isBlank()) {
                u.setRealmCode(GRADE_TO_REALM.getOrDefault(u.getGradeCode(), "lianqi"));
                userMapper.updateById(u);
            }
        }
    }

    private void upgradeNoticeCopy() {
        SysConfig cfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, "app_notice").last("LIMIT 1")
        );
        if (cfg != null && cfg.getConfigValue() != null && cfg.getConfigValue().startsWith("初一到高三全章节已就绪")) {
            cfg.setConfigValue("修仙闯关开启：练气至化神六大境界，学成可挑战进阶考核！");
            sysConfigMapper.updateById(cfg);
        }
    }

    private void ensureAppVersionConfigs() {
        ensureConfig("github_release_repo", "gonglanglang/Chnagguan", "GitHub Release 发布仓库 (owner/repo)");
        ensureConfig("app_latest_version", "1.0.0", "App最新版本号");
        ensureConfig("app_latest_version_code", "100", "App最新版本数字编码(versionCode)");
        ensureConfig("app_update_notes", "1. 初始正式版发布，支持六大修仙境界闯关与错题巩固\n2. 支持在线检测新版本更新", "App最新版本更新日志");
        ensureConfig("app_download_url", "", "App最新APK下载地址");
        ensureConfig("app_force_update", "false", "App是否强制更新");
    }

    private void ensureConfig(String key, String value, String desc) {
        long count = sysConfigMapper.selectCount(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, key)
        );
        if (count == 0) {
            SysConfig cfg = new SysConfig();
            cfg.setConfigKey(key);
            cfg.setConfigValue(value);
            cfg.setDescription(desc);
            sysConfigMapper.insert(cfg);
        }
    }
}
