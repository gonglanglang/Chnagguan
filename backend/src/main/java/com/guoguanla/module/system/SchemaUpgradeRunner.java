package com.guoguanla.module.system;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.module.banner.entity.EduHomeBanner;
import com.guoguanla.module.banner.mapper.EduHomeBannerMapper;
import com.guoguanla.module.oss.AliyunOssService;
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
import java.util.Set;

/**
 * 幂等结构升级与学习阶段初始化（兼容已存量 MySQL 与测试 H2）。
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

    private static final Set<String> LEGACY_CULTIVATION_REALM_NAMES = Set.of(
            "练气", "筑基", "结丹", "假婴", "元婴", "化神"
    );

    private final DataSource dataSource;
    private final JdbcTemplate jdbcTemplate;
    private final EduRealmMapper realmMapper;
    private final AppUserMapper userMapper;
    private final SysConfigMapper sysConfigMapper;
    private final EduHomeBannerMapper homeBannerMapper;
    private final AliyunOssService ossService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void run(ApplicationArguments args) throws Exception {
        ensureEduRealmTable();
        ensureUserEssayAnswerTable();
        ensureVideoTables();
        ensureHomeBannerTable();
        upgradeSysConfigValueColumn();
        boolean addedUserRealm = ensureColumn("app_user", "realm_code", "VARCHAR(24) NOT NULL DEFAULT 'lianqi'");
        ensureColumn("app_user", "email", "VARCHAR(128) DEFAULT NULL");
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
        migrateCultivationTermsToNormal();
        backfillUserRealms(addedUserRealm);
        backfillEssayGateKeys();
        upgradeNoticeCopy();
        ensureAppVersionConfigs();
        ensureAiConfigs();
        ensureDefaultThemeConfigs();
        seedDefaultHomeBanners();
        syncOssCustomDomain();
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

    private void ensureHomeBannerTable() {
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS edu_home_banner (
                  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                  title VARCHAR(128) NOT NULL,
                  subtitle VARCHAR(255) NOT NULL DEFAULT '',
                  image_key VARCHAR(512) NOT NULL DEFAULT '',
                  content_html MEDIUMTEXT DEFAULT NULL,
                  sort_order INT NOT NULL DEFAULT 0,
                  enabled TINYINT NOT NULL DEFAULT 1,
                  created_by BIGINT UNSIGNED DEFAULT NULL,
                  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  deleted TINYINT NOT NULL DEFAULT 0,
                  PRIMARY KEY (id),
                  KEY idx_banner_enabled_sort (enabled, deleted, sort_order)
                )
                """);
    }

    private void seedDefaultHomeBanners() {
        if (homeBannerMapper.selectCount(null) > 0) {
            return;
        }
        List<EduHomeBanner> defaults = List.of(
                buildDefaultBanner(
                        "初高中数学金牌教研团队",
                        "10年+一线教学沉淀 · 人教版全51章体系打磨",
                        "preset://faculty-1",
                        """
                        <h2>过关啦核心教研团队介绍</h2>
                        <p>过关啦数学教研团队由多位拥有 <strong>10 年以上初高中重点中学一线执教经验</strong> 的资深数学老师联合组建，严格对标人教版教材大纲，系统打磨初一至高三全 51 章 204 道阶梯关卡。</p>
                        <h3>核心教学特色</h3>
                        <ul>
                          <li><strong>阶梯闯关设计：</strong>每章细分为基础关、中档关、拓展关与压轴关，夯实基础的同时稳步拔高。</li>
                          <li><strong>动静结合出题：</strong>精选经典母题与智能参数变式题相结合，杜绝机械背答案。</li>
                          <li><strong>手写作答精批：</strong>解答题支持手写画板作答，老师在线批注点评并自动同步错题本。</li>
                        </ul>
                        <blockquote><p>“把每一道易错基础题练透，就是数学提分最稳妥的捷径。”</p></blockquote>
                        """,
                        1
                ),
                buildDefaultBanner(
                        "中考几何模型与辅助线名师组",
                        "省重点骨干名师领衔 · 专攻全等、圆与动态压轴",
                        "preset://faculty-2",
                        """
                        <h2>中考几何专项教研组</h2>
                        <p>由省重点初中数学备课组长领衔，专注初中平面几何知识体系构建与中考压轴模型拆解，累计编写高质量几何配图题 <strong>300+ 道</strong>。</p>
                        <h3>核心授课与研发方向</h3>
                        <ul>
                          <li><strong>核心几何模型：</strong>手拉手全等、一线三垂直、将军饮马、胡不归、隐圆与阿氏圆。</li>
                          <li><strong>精准矢量配图：</strong>每道几何题配备标准比例矢量图形，帮助同学建立直观空间感与识图能力。</li>
                          <li><strong>辅助线思维链：</strong>结合 AI 智能画板分步启发，引导同学独立想出关键辅助线。</li>
                        </ul>
                        """,
                        2
                ),
                buildDefaultBanner(
                        "高考函数导数与解析几何名师团",
                        "清北硕博教研领衔 · 冲刺高中数学高分突破",
                        "preset://faculty-3",
                        """
                        <h2>高中数学高阶教研名师团</h2>
                        <p>针对高中数学知识跨度大、综合性强等痛点，团队精心构建 <strong>高一夯实 → 高二深化 → 高三专题冲刺</strong> 三阶训练闭环。</p>
                        <h3>重点攻克专题</h3>
                        <ol>
                          <li><strong>函数与导数：</strong>单调性分类讨论、极值点偏移、隐零点与恒成立放缩。</li>
                          <li><strong>解析几何：</strong>直线与圆锥曲线联立、韦达定理化简、定点定值与最值问题。</li>
                          <li><strong>立体几何与概率统计：</strong>空间向量建系、条件概率与正态分布建模。</li>
                        </ol>
                        """,
                        3
                )
        );
        defaults.forEach(homeBannerMapper::insert);
        log.info("Seeded {} default home faculty banners", defaults.size());
    }

    private EduHomeBanner buildDefaultBanner(String title, String subtitle, String imageKey, String html, int sortOrder) {
        EduHomeBanner b = new EduHomeBanner();
        b.setTitle(title);
        b.setSubtitle(subtitle);
        b.setImageKey(imageKey);
        b.setContentHtml(html.trim());
        b.setSortOrder(sortOrder);
        b.setEnabled(1);
        return b;
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

    private void upgradeSysConfigValueColumn() {
        try (Connection conn = dataSource.getConnection()) {
            String product = conn.getMetaData().getDatabaseProductName();
            int colSize = -1;
            String typeName = "";
            try (ResultSet rs = conn.getMetaData().getColumns(conn.getCatalog(), null, null, null)) {
                while (rs.next()) {
                    String t = rs.getString("TABLE_NAME");
                    String c = rs.getString("COLUMN_NAME");
                    if ("sys_config".equalsIgnoreCase(t) && "config_value".equalsIgnoreCase(c)) {
                        colSize = rs.getInt("COLUMN_SIZE");
                        typeName = rs.getString("TYPE_NAME") == null ? "" : rs.getString("TYPE_NAME").toUpperCase();
                        break;
                    }
                }
            }
            if (colSize > 0 && colSize < 4000 && !typeName.contains("TEXT") && !typeName.contains("CLOB")) {
                if (product != null && product.toLowerCase().contains("mysql")) {
                    jdbcTemplate.execute("ALTER TABLE sys_config MODIFY COLUMN config_value TEXT DEFAULT NULL");
                } else {
                    jdbcTemplate.execute("ALTER TABLE sys_config ALTER COLUMN config_value TEXT");
                }
                log.info("Upgraded sys_config.config_value from {}({}) to TEXT", typeName, colSize);
            }
        } catch (Exception e) {
            log.warn("Skipped upgrading sys_config.config_value to TEXT: {}", e.getMessage());
        }
    }

    private List<EduRealm> buildDefaultRealms() {
        return List.of(
                buildRealm("lianqi", "初一", 1, "g7", "难度一 · 基础", "初一数学核心基础：有理数、整式、一元一次方程与几何初步", 0, 5, 60),
                buildRealm("zhuji", "初二", 2, "g8", "难度二 · 入门", "初二数学能力进阶：三角形全等、轴对称、勾股定理与一次函数", 0, 5, 60),
                buildRealm("jiedan", "初三", 3, "g9", "难度三 · 提升", "初三中考冲刺阶段：一元二次方程、二次函数、圆与相似综合", 0, 6, 70),
                buildRealm("jiaying", "高一", 4, "h1", "难度四 · 强化", "高一高中衔接强化：集合逻辑、函数性质、指数对数与三角函数", 0, 6, 70),
                buildRealm("yuanying", "高二", 5, "h2", "难度五 · 高阶", "高二数学深化突破：空间向量、解析几何、数列与一元函数导数", 0, 8, 75),
                buildRealm("huashen", "高三", 6, "h3", "难度六 · 冲刺", "高三综合压轴冲刺：函数导数、圆锥曲线、概率统计与高考专题", 0, 8, 80)
        );
    }

    private void seedDefaultRealms() {
        if (realmMapper.selectCount(null) > 0) {
            return;
        }
        buildDefaultRealms().forEach(realmMapper::insert);
        log.info("Seeded 6 default study stages (初一 -> 高三)");
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
        Map<String, EduRealm> defMap = buildDefaultRealms().stream()
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
                log.info("Repaired mojibake text for stage {}", existing.getRealmCode());
            }
        }
    }

    private void migrateCultivationTermsToNormal() {
        Map<String, EduRealm> defMap = buildDefaultRealms().stream()
                .collect(java.util.stream.Collectors.toMap(EduRealm::getRealmCode, d -> d));
        for (EduRealm existing : realmMapper.selectList(null)) {
            EduRealm d = defMap.get(existing.getRealmCode());
            if (d == null) continue;
            boolean changed = false;
            String curName = existing.getRealmName() == null ? "" : existing.getRealmName().trim();
            if (LEGACY_CULTIVATION_REALM_NAMES.contains(curName)) {
                existing.setRealmName(d.getRealmName());
                changed = true;
            }
            String curDesc = existing.getDescription() == null ? "" : existing.getDescription();
            if (containsCultivationKeyword(curDesc)) {
                existing.setDescription(d.getDescription());
                changed = true;
            }
            String curDiff = existing.getDifficultyLabel() == null ? "" : existing.getDifficultyLabel();
            if (curDiff.contains("巅峰") && "huashen".equals(existing.getRealmCode())) {
                existing.setDifficultyLabel(d.getDifficultyLabel());
                changed = true;
            }
            if (changed) {
                realmMapper.updateById(existing);
                log.info("Migrated legacy stage terminology for {} -> {}", existing.getRealmCode(), existing.getRealmName());
            }
        }
    }

    private boolean containsCultivationKeyword(String s) {
        if (s == null || s.isBlank()) return false;
        return s.contains("修仙") || s.contains("境界") || s.contains("修炼")
                || s.contains("引气") || s.contains("道基") || s.contains("凝丹")
                || s.contains("化凡") || s.contains("元婴") || s.contains("大道至简")
                || s.contains("练气") || s.contains("筑基") || s.contains("结丹")
                || s.contains("假婴") || s.contains("化神");
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

    private static final String DEFAULT_RICH_NOTICE =
            "1. 全年级同步闯关：初一至高三 51 章 204 关自由开放练习，支持基础关 → 下一关 → 下一章 → 跨年级连续闯关；\n"
                    + "2. 精绘数学矢量配图：526 道几何、函数、统计与立体几何题目均配有清晰矢量图，点击可全屏缩放；\n"
                    + "3. AI 智能手写画板：支持拍照与手写识题，自动矢量重绘几何配图并提供思路引导、过程诊断与解题核对；\n"
                    + "4. 错题本高效巩固：闯关错题自动收录，重做答对即标记掌握并移出。";

    private void upgradeNoticeCopy() {
        SysConfig cfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, "app_notice").last("LIMIT 1")
        );
        if (cfg != null && cfg.getConfigValue() != null) {
            String cur = cfg.getConfigValue().trim();
            if (containsCultivationKeyword(cur)
                    || "初一至高三全章节已开放，支持自由刷题、阶段升级测评与错题巩固！".equals(cur)
                    || cur.isEmpty()) {
                cfg.setConfigValue(DEFAULT_RICH_NOTICE);
                sysConfigMapper.updateById(cfg);
            }
        }
        SysConfig notesCfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, "app_update_notes").last("LIMIT 1")
        );
        if (notesCfg != null && notesCfg.getConfigValue() != null
                && notesCfg.getConfigValue().startsWith("1. 初始正式版发布，支持六大修仙境界闯关")) {
            notesCfg.setConfigValue("1. 初始正式版发布，支持初一至高三全阶段闯关与错题巩固\n2. 支持在线检测新版本更新");
            sysConfigMapper.updateById(notesCfg);
        }
    }

    private void ensureAppVersionConfigs() {
        ensureConfig("github_release_repo", "gonglanglang/Chnagguan", "GitHub Release 发布仓库 (owner/repo)");
        ensureConfig("app_latest_version", "1.0.0", "App最新版本号");
        ensureConfig("app_latest_version_code", "100", "App最新版本数字编码(versionCode)");
        ensureConfig("app_update_notes", "1. 初始正式版发布，支持初一至高三全阶段闯关与错题巩固\n2. 支持在线检测新版本更新", "App最新版本更新日志（最多2500字）");
        ensureConfig("app_download_url", "", "App最新APK下载地址");
        ensureConfig("app_force_update", "false", "App是否强制更新");
        ensureConfig("oss_custom_domain", "", "阿里云 OSS 自定义加速域名（绑定 CNAME 后客户端直连 OSS 高速下载 APK）");
    }

    private void syncOssCustomDomain() {
        SysConfig cfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, "oss_custom_domain").last("LIMIT 1")
        );
        if (cfg != null && cfg.getConfigValue() != null && !cfg.getConfigValue().isBlank()) {
            try {
                ossService.setRuntimeCustomDomain(cfg.getConfigValue());
                log.info("Loaded runtime OSS custom domain from sys_config: {}", ossService.getEffectiveCustomDomain());
            } catch (Exception e) {
                log.warn("Ignored invalid sys_config.oss_custom_domain '{}': {}", cfg.getConfigValue(), e.getMessage());
            }
        }
    }

    private void ensureAiConfigs() {
        ensureConfig("ai_enabled", "true", "是否启用学生端 AI 智能手写画板");
        ensureConfig("ai_base_url", "https://api.longcat.chat/openai", "OpenAI 兼容格式 AI 接口根地址");
        ensureConfig("ai_api_key", "", "AI 服务 API 密钥（仅服务端保存，脱敏展示）");
        ensureConfig("ai_model", "LongCat-2.5", "默认 AI 模型名称");
        ensureConfig("ai_vision_model", "", "视觉识图模型名称（留空则复用默认模型）");
        ensureConfig("ai_temperature", "0.2", "AI 采样温度（0.0~1.5，数学求解建议 0.2）");
        ensureConfig("ai_max_tokens", "4096", "AI 单次最大输出 Token 数");
        ensureConfig("ai_timeout_sec", "90", "AI 上游请求超时时间（秒）");
        ensureConfig("ai_system_prompt", "", "自定义 AI 数学助教系统提示词（留空使用内置教研提示词）");
    }

    private void ensureDefaultThemeConfigs() {
        ensureConfig("app_default_ui_skin", "welkui", "学生端默认 UI 组件皮肤（welkui / skribble / forui）");
        ensureConfig("app_default_theme_hex", "#67C6FF", "学生端默认主题强调色 HEX");
        ensureConfig("app_default_theme_name", "天青漫画", "学生端默认主题强调色名称");
        ensureConfig("app_default_dark_mode", "false", "学生端默认是否启用暗黑模式");
        ensureConfig("app_default_theme_version", "1", "学生端默认主题配置版本号（后台保存时自动更新）");
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
