package com.guoguanla.module.system;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.module.bank.entity.EduChapter;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.mapper.EduChapterMapper;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.progress.entity.UserGateProgress;
import com.guoguanla.module.progress.mapper.UserGateProgressMapper;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.system.mapper.EduRealmMapper;
import com.guoguanla.module.user.entity.AppUser;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RealmHelperService {

    private final EduRealmMapper realmMapper;
    private final EduChapterMapper chapterMapper;
    private final EduGateMapper gateMapper;
    private final UserGateProgressMapper gateProgressMapper;

    @Data
    @Builder
    public static class ExamProgress {
        private int passedRealmGates;
        private int totalRealmGates;
        private int requiredGates;
        private int remainingGates;
        private boolean examEligible;
    }

    public List<EduRealm> listOrderedRealms() {
        return realmMapper.selectList(
                new LambdaQueryWrapper<EduRealm>()
                        .eq(EduRealm::getEnabled, 1)
                        .orderByAsc(EduRealm::getRealmOrder)
        );
    }

    public List<EduRealm> listAllRealmsForAdmin() {
        return realmMapper.selectList(
                new LambdaQueryWrapper<EduRealm>().orderByAsc(EduRealm::getRealmOrder)
        );
    }

    public EduRealm findByRealmCode(String realmCode) {
        if (realmCode == null || realmCode.isBlank()) return null;
        return realmMapper.selectOne(
                new LambdaQueryWrapper<EduRealm>().eq(EduRealm::getRealmCode, realmCode.trim()).last("LIMIT 1")
        );
    }

    public EduRealm findByGradeCode(String gradeCode) {
        if (gradeCode == null || gradeCode.isBlank()) return null;
        return realmMapper.selectOne(
                new LambdaQueryWrapper<EduRealm>().eq(EduRealm::getGradeCode, gradeCode.trim()).last("LIMIT 1")
        );
    }

    public EduRealm resolveUserRealm(AppUser user) {
        List<EduRealm> ordered = listAllRealmsForAdmin();
        if (ordered.isEmpty()) {
            EduRealm fallback = new EduRealm();
            fallback.setRealmCode("lianqi");
            fallback.setRealmName("初一");
            fallback.setRealmOrder(1);
            fallback.setGradeCode("g7");
            fallback.setDifficultyLabel("难度一 · 基础");
            fallback.setUnlockGates(0);
            fallback.setExamQuestionCount(5);
            fallback.setExamPassScore(60);
            return fallback;
        }
        if (user != null) {
            if (user.getRealmCode() != null && !user.getRealmCode().isBlank()) {
                for (EduRealm r : ordered) {
                    if (user.getRealmCode().equalsIgnoreCase(r.getRealmCode())) return r;
                }
            }
            if (user.getGradeCode() != null && !user.getGradeCode().isBlank()) {
                for (EduRealm r : ordered) {
                    if (user.getGradeCode().equalsIgnoreCase(r.getGradeCode())) return r;
                }
            }
        }
        return ordered.get(0);
    }

    public EduRealm findNextRealm(int currentOrder) {
        return realmMapper.selectOne(
                new LambdaQueryWrapper<EduRealm>()
                        .gt(EduRealm::getRealmOrder, currentOrder)
                        .eq(EduRealm::getEnabled, 1)
                        .orderByAsc(EduRealm::getRealmOrder)
                        .last("LIMIT 1")
        );
    }

    public String resolveGradeCode(String realmCode, String gradeCodeFallback) {
        EduRealm r = findByRealmCode(realmCode);
        if (r != null) return r.getGradeCode();
        return gradeCodeFallback;
    }

    public ExamProgress computeExamProgress(Long userId, EduRealm realm, Set<Long> passedGateIdsOverride) {
        List<EduChapter> chaps = chapterMapper.selectList(
                new LambdaQueryWrapper<EduChapter>()
                        .eq(EduChapter::getGradeCode, realm.getGradeCode())
                        .eq(EduChapter::getEnabled, 1)
        );
        if (chaps.isEmpty()) {
            return ExamProgress.builder()
                    .passedRealmGates(0).totalRealmGates(0).requiredGates(0).remainingGates(0).examEligible(false)
                    .build();
        }
        List<Long> chapIds = chaps.stream().map(EduChapter::getId).toList();
        List<EduGate> gates = gateMapper.selectList(
                new LambdaQueryWrapper<EduGate>()
                        .in(EduGate::getChapterId, chapIds)
                        .eq(EduGate::getEnabled, 1)
        );
        int totalGates = gates.size();
        Set<Long> passedIds = passedGateIdsOverride != null ? passedGateIdsOverride : loadUserPassedGateIds(userId);
        int passedInRealm = (int) gates.stream().filter(g -> passedIds.contains(g.getId())).count();

        int unlockCfg = realm.getUnlockGates() == null ? 0 : realm.getUnlockGates();
        int required = unlockCfg > 0 ? Math.min(unlockCfg, totalGates) : totalGates;
        int remaining = Math.max(0, required - passedInRealm);
        boolean eligible = userId != null && totalGates > 0 && passedInRealm >= required
                && findNextRealm(realm.getRealmOrder()) != null;

        return ExamProgress.builder()
                .passedRealmGates(passedInRealm)
                .totalRealmGates(totalGates)
                .requiredGates(required)
                .remainingGates(remaining)
                .examEligible(eligible)
                .build();
    }

    private Set<Long> loadUserPassedGateIds(Long userId) {
        if (userId == null) return Set.of();
        return gateProgressMapper.selectList(
                        new LambdaQueryWrapper<UserGateProgress>()
                                .eq(UserGateProgress::getUserId, userId)
                                .eq(UserGateProgress::getIsPassed, 1)
                ).stream()
                .map(UserGateProgress::getGateId)
                .collect(Collectors.toSet());
    }
}
