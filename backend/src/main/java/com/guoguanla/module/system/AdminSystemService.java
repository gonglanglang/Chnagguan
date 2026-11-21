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
import com.guoguanla.module.system.dto.RealmConfigReq;
import com.guoguanla.module.system.entity.EduLevelRule;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.system.entity.SysConfig;
import com.guoguanla.module.system.entity.SysOperLog;
import com.guoguanla.module.system.mapper.EduLevelRuleMapper;
import com.guoguanla.module.system.mapper.EduRealmMapper;
import com.guoguanla.module.system.mapper.SysConfigMapper;
import com.guoguanla.module.system.mapper.SysOperLogMapper;
import com.guoguanla.module.system.vo.RealmConfigVO;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminSystemService {

    private final EduRealmMapper realmMapper;
    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final EduQuestionMapper questionMapper;
    private final AppUserMapper userMapper;
    private final EduLevelRuleMapper levelRuleMapper;
    private final SysConfigMapper sysConfigMapper;
    private final SysOperLogMapper operLogMapper;

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
            throw new BizException(ErrorCode.NOT_FOUND, "境界配置不存在");
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
        return sysConfigMapper.selectList(
                new LambdaQueryWrapper<SysConfig>().orderByAsc(SysConfig::getId)
        );
    }

    public void updateConfig(String key, String value) {
        if (key == null || key.isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "配置项 Key 不能为空");
        }
        String trimmedKey = key.trim();
        SysConfig cfg = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, trimmedKey)
        );
        if (cfg == null) {
            SysConfig created = new SysConfig();
            created.setConfigKey(trimmedKey);
            created.setConfigValue(value == null ? "" : value);
            created.setDescription("后台配置项");
            sysConfigMapper.insert(created);
            return;
        }
        cfg.setConfigValue(value == null ? "" : value);
        sysConfigMapper.updateById(cfg);
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
