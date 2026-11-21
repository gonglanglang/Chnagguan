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
        boolean addedUserRealm = ensureColumn("app_user", "realm_code", "VARCHAR(24) NOT NULL DEFAULT 'lianqi'");
        ensureColumn("user_quiz_record", "realm_code", "VARCHAR(24) DEFAULT NULL");
        ensureColumn("user_quiz_record", "score", "INT DEFAULT NULL");

        seedDefaultRealms();
        repairMojibakeRealms();
        backfillUserRealms(addedUserRealm);
        upgradeNoticeCopy();
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
}
