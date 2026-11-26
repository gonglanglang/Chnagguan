package com.guoguanla.module.system;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.module.bank.entity.EduChapter;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduChapterMapper;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.system.dto.AppDefaultThemeReq;
import com.guoguanla.module.system.dto.RealmConfigReq;
import com.guoguanla.module.system.entity.EduLevelRule;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.entity.SysOperLog;
import com.guoguanla.module.system.mapper.EduLevelRuleMapper;
import com.guoguanla.module.system.mapper.EduRealmMapper;
import com.guoguanla.module.system.mapper.SysConfigMapper;
import com.guoguanla.module.system.mapper.SysOperLogMapper;
import com.guoguanla.module.system.vo.AppDefaultThemeVO;
import com.guoguanla.module.system.vo.RealmConfigVO;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminSystemService {

    public static final Set<String> ALLOWED_UI_SKINS = Set.of("welkui", "skribble", "forui");
    public static final String KEY_DEFAULT_UI_SKIN = "app_default_ui_skin";
    public static final String KEY_DEFAULT_THEME_HEX = "app_default_theme_hex";
    public static final String KEY_DEFAULT_THEME_NAME = "app_default_theme_name";
    public static final String KEY_DEFAULT_DARK_MODE = "app_default_dark_mode";
    public static final String KEY_DEFAULT_THEME_VERSION = "app_default_theme_version";

    private final EduRealmMapper realmMapper;
    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final EduQuestionMapper questionMapper;
    private final AppUserMapper userMapper;
    private final EduLevelRuleMapper levelRuleMapper;
    private final SysConfigMapper sysConfigMapper;
    private final SysOperLogMapper operLogMapper;
    private final AliyunOssService ossService;

    public List<RealmConfigVO> listRealms() {
        List<EduRealm> realms = realmMapper.selectList(
                new LambdaQueryWrapper<EduRealm>().orderByAsc(EduRealm::getRealmOrder)
        );
        List<EduChapter> chapters = chapterMapper.selectList(null);
        List<EduGate> gates = gateMapper.selectList(null);
        List<EduQuestion> questions = questionMapper.selectList(null);
        List<AppUser> users = userMapper.selectList(null);

        Map<Long, String> chapGradeMap = chapters.stream()
                .collect(Collectors.toMap(EduChapter::getId, EduChapter::getGradeCode, (a, b) -> a));
        Map<String, Long> chapCount = chapters.stream()
                .collect(Collectors.groupingBy(EduChapter::getGradeCode, Collectors.counting()));
        Map<String, Long> gateCount = gates.stream()
                .filter(g -> chapGradeMap.containsKey(g.getChapterId()))
                .collect(Collectors.groupingBy(g -> chapGradeMap.get(g.getChapterId()), Collectors.counting()));
        Map<String, Long> qCount = questions.stream()
                .collect(Collectors.groupingBy(EduQuestion::getGradeCode, Collectors.counting()));
        Map<String, Long> stuCount = users.stream()
                .filter(u -> u.getRealmCode() != null)
                .collect(Collectors.groupingBy(AppUser::getRealmCode, Collectors.counting()));

        return realms.stream()
                .map(r -> RealmConfigVO.builder()
                        .id(r.getId())
                        .realmCode(r.getRealmCode())
                        .realmName(r.getRealmName())
                        .realmOrder(r.getRealmOrder())
                        .gradeCode(r.getGradeCode())
                        .difficultyLabel(r.getDifficultyLabel())
                        .description(r.getDescription())
                        .unlockGates(r.getUnlockGates())
                        .examQuestionCount(r.getExamQuestionCount())
                        .examPassScore(r.getExamPassScore())
                        .enabled(r.getEnabled())
                        .chapterCount(chapCount.getOrDefault(r.getGradeCode(), 0L))
                        .gateCount(gateCount.getOrDefault(r.getGradeCode(), 0L))
                        .questionCount(qCount.getOrDefault(r.getGradeCode(), 0L))
                        .studentCount(stuCount.getOrDefault(r.getRealmCode(), 0L))
                        .build())
                .toList();
    }

    public void updateRealm(Long id, RealmConfigReq req) {
        EduRealm exist = realmMapper.selectById(id);
        if (exist == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "学习阶段配置不存在");
        }
        exist.setRealmName(req.getRealmName().trim());
        exist.setDifficultyLabel(req.getDifficultyLabel().trim());
        exist.setDescription(req.getDescription() == null ? "" : req.getDescription().trim());
        exist.setUnlockGates(req.getUnlockGates());
        exist.setExamQuestionCount(req.getExamQuestionCount());
        exist.setExamPassScore(req.getExamPassScore());
        realmMapper.updateById(exist);
    }

    public List<EduLevelRule> listLevels() {
        return levelRuleMapper.selectList(
                new LambdaQueryWrapper<EduLevelRule>().orderByAsc(EduLevelRule::getMinGates)
        );
    }

    public void updateLevel(Long id, EduLevelRule req) {
        EduLevelRule exist = levelRuleMapper.selectById(id);
        if (exist == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "段位不存在");
        }
        exist.setMinGates(req.getMinGates());
        exist.setIcon(req.getIcon());
        exist.setLevelName(req.getLevelName());
        exist.setQuote(req.getQuote());
        if (req.getSortOrder() != null) {
            exist.setSortOrder(req.getSortOrder());
        }
        levelRuleMapper.updateById(exist);
    }

    public List<SysConfig> listConfigs() {
        List<SysConfig> list = sysConfigMapper.selectList(
                new LambdaQueryWrapper<SysConfig>().orderByAsc(SysConfig::getId)
        );
        for (SysConfig item : list) {
            if (isSensitiveConfigKey(item.getConfigKey())) {
                item.setConfigValue(maskSecret(item.getConfigValue()));
            }
        }
        return list;
    }

    private boolean isSensitiveConfigKey(String key) {
        if (key == null) return false;
        String lower = key.toLowerCase();
        return lower.contains("api_key") || lower.contains("secret") || lower.contains("password") || lower.contains("token");
    }

    private String maskSecret(String raw) {
        if (raw == null || raw.isBlank()) {
            return "";
        }
        String s = raw.trim();
        if (s.length() <= 8) {
            return "****";
        }
        return s.substring(0, 4) + "****" + s.substring(s.length() - 4);
    }

    public void updateConfig(String key, String value) {
        if (key == null || key.isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "配置项 Key 不能为空");
        }
        String trimmedKey = key.trim();
        String finalValue = value == null ? "" : value;
        if ("app_update_notes".equals(trimmedKey)) {
            finalValue = AppVersionService.validateReleaseNotes(finalValue);
        } else if ("oss_custom_domain".equals(trimmedKey)) {
            finalValue = AliyunOssService.normalizeAndValidateCustomDomain(finalValue);
            ossService.setRuntimeCustomDomain(finalValue);
        }
        SysConfig cfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, trimmedKey)
        );
        if (cfg == null) {
            SysConfig created = new SysConfig();
            created.setConfigKey(trimmedKey);
            created.setConfigValue(finalValue);
            created.setDescription("后台配置项");
            sysConfigMapper.insert(created);
        } else {
            cfg.setConfigValue(finalValue);
            sysConfigMapper.updateById(cfg);
        }
        if (trimmedKey.startsWith("app_default_") && !KEY_DEFAULT_THEME_VERSION.equals(trimmedKey)) {
            upsertConfigInternal(KEY_DEFAULT_THEME_VERSION, String.valueOf(System.currentTimeMillis()), "学生端默认主题配置版本号");
        }
    }

    public AppDefaultThemeVO getDefaultTheme() {
        String rawSkin = readConfigValue(KEY_DEFAULT_UI_SKIN, "welkui").trim().toLowerCase(Locale.ROOT);
        String uiSkin = ALLOWED_UI_SKINS.contains(rawSkin) ? rawSkin : "welkui";
        String themeHex = normalizeHexColor(readConfigValue(KEY_DEFAULT_THEME_HEX, "#67C6FF"));
        String themeName = readConfigValue(KEY_DEFAULT_THEME_NAME, "天青漫画").trim();
        if (themeName.isEmpty()) {
            themeName = "天青漫画";
        }
        boolean darkMode = "true".equalsIgnoreCase(readConfigValue(KEY_DEFAULT_DARK_MODE, "false").trim());
        String version = readConfigValue(KEY_DEFAULT_THEME_VERSION, "1").trim();
        if (version.isEmpty()) {
            version = "1";
        }
        return AppDefaultThemeVO.builder()
                .uiSkin(uiSkin)
                .themeHex(themeHex)
                .themeName(themeName)
                .darkMode(darkMode)
                .version(version)
                .build();
    }

    public AppDefaultThemeVO updateDefaultTheme(AppDefaultThemeReq req) {
        String rawSkin = req.getUiSkin() == null ? "" : req.getUiSkin().trim().toLowerCase(Locale.ROOT);
        if (!ALLOWED_UI_SKINS.contains(rawSkin)) {
            throw new BizException(ErrorCode.BAD_REQUEST, "不支持的默认皮肤类型，可选值：welkui / skribble / forui");
        }
        String rawHex = req.getThemeHex() == null || req.getThemeHex().isBlank()
                ? readConfigValue(KEY_DEFAULT_THEME_HEX, "#67C6FF")
                : req.getThemeHex().trim();
        if (!rawHex.matches("^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$")) {
            throw new BizException(ErrorCode.BAD_REQUEST, "默认主题色必须为合法的十六进制色值（如 #67C6FF）");
        }
        String normalizedHex = normalizeHexColor(rawHex);
        String themeName = (req.getThemeName() == null || req.getThemeName().isBlank())
                ? readConfigValue(KEY_DEFAULT_THEME_NAME, "天青漫画")
                : req.getThemeName().trim();
        if (themeName.length() > 32) {
            themeName = themeName.substring(0, 32);
        }
        boolean darkMode = req.getDarkMode() != null
                ? req.getDarkMode()
                : "true".equalsIgnoreCase(readConfigValue(KEY_DEFAULT_DARK_MODE, "false"));
        String version = String.valueOf(System.currentTimeMillis());

        upsertConfigInternal(KEY_DEFAULT_UI_SKIN, rawSkin, "学生端默认 UI 组件皮肤（welkui / skribble / forui）");
        upsertConfigInternal(KEY_DEFAULT_THEME_HEX, normalizedHex, "学生端默认主题强调色 HEX");
        upsertConfigInternal(KEY_DEFAULT_THEME_NAME, themeName, "学生端默认主题强调色名称");
        upsertConfigInternal(KEY_DEFAULT_DARK_MODE, darkMode ? "true" : "false", "学生端默认是否启用暗黑模式");
        upsertConfigInternal(KEY_DEFAULT_THEME_VERSION, version, "学生端默认主题配置版本号（后台保存时自动更新）");

        return AppDefaultThemeVO.builder()
                .uiSkin(rawSkin)
                .themeHex(normalizedHex)
                .themeName(themeName)
                .darkMode(darkMode)
                .version(version)
                .build();
    }

    private String readConfigValue(String key, String fallback) {
        SysConfig cfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, key).last("LIMIT 1")
        );
        return cfg != null && cfg.getConfigValue() != null ? cfg.getConfigValue() : fallback;
    }

    private void upsertConfigInternal(String key, String value, String desc) {
        SysConfig cfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, key).last("LIMIT 1")
        );
        if (cfg == null) {
            SysConfig created = new SysConfig();
            created.setConfigKey(key);
            created.setConfigValue(value);
            created.setDescription(desc);
            sysConfigMapper.insert(created);
        } else {
            cfg.setConfigValue(value);
            sysConfigMapper.updateById(cfg);
        }
    }

    private String normalizeHexColor(String raw) {
        String s = raw == null ? "" : raw.trim().replace("#", "").toUpperCase(Locale.ROOT);
        if (s.length() == 3) {
            s = "" + s.charAt(0) + s.charAt(0) + s.charAt(1) + s.charAt(1) + s.charAt(2) + s.charAt(2);
        }
        if (!s.matches("^[0-9A-F]{6}$")) {
            return "#67C6FF";
        }
        return "#" + s;
    }

    public PageResult<SysOperLog> pageLogs(String module, Long pageNum, Long pageSize) {
        long p = pageNum == null || pageNum < 1 ? 1L : pageNum;
        long s = pageSize == null || pageSize < 1 ? 15L : Math.min(pageSize, 100L);
        LambdaQueryWrapper<SysOperLog> wrapper = new LambdaQueryWrapper<>();
        if (module != null && !module.isBlank()) {
            wrapper.eq(SysOperLog::getModule, module.trim());
        }
        wrapper.orderByDesc(SysOperLog::getId);
        return PageResult.of(operLogMapper.selectPage(new Page<>(p, s), wrapper));
    }
}
