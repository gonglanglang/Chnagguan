package com.guoguanla.module.dashboard;

import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.guoguanla.module.dashboard.vo.DashboardOverviewVO;
import com.guoguanla.module.system.RealmHelperService;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

/**
 * 学生实时在线状态追踪服务（5 分钟活动窗口，支持接口自动感知 + APP 前台心跳 + 退出即时下线）。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentOnlineTrackerService {

    public static final int ONLINE_WINDOW_MINUTES = 5;
    private static final long ONLINE_WINDOW_MS = ONLINE_WINDOW_MINUTES * 60L * 1000L;
    private static final long DB_TOUCH_THROTTLE_MS = 60L * 1000L;

    private final AppUserMapper appUserMapper;
    private final RealmHelperService realmHelper;

    private final ConcurrentHashMap<Long, OnlineEntry> onlineMap = new ConcurrentHashMap<>();

    private record OnlineEntry(
            long userId,
            long lastSeenEpochMs,
            String lastAction,
            String platform,
            long lastDbTouchEpochMs
    ) {}

    public void touchUser(Long userId, String action, String platform) {
        if (userId == null || userId <= 0) {
            return;
        }
        long nowMs = System.currentTimeMillis();
        String safeAction = normalizeAction(action);
        String safePlatform = (platform == null || platform.isBlank()) ? "app" : platform.trim();

        boolean[] shouldTouchDb = {false};
        onlineMap.compute(userId, (id, prev) -> {
            long prevDb = prev == null ? 0L : prev.lastDbTouchEpochMs();
            long nextDb = prevDb;
            if (nowMs - prevDb >= DB_TOUCH_THROTTLE_MS) {
                shouldTouchDb[0] = true;
                nextDb = nowMs;
            }
            String mergedPlatform = (platform == null || platform.isBlank()) && prev != null
                    ? prev.platform()
                    : safePlatform;
            return new OnlineEntry(id, nowMs, safeAction, mergedPlatform, nextDb);
        });

        if (shouldTouchDb[0]) {
            try {
                appUserMapper.update(null, new LambdaUpdateWrapper<AppUser>()
                        .eq(AppUser::getId, userId)
                        .set(AppUser::getLastActiveAt, LocalDateTime.now()));
            } catch (Exception e) {
                log.debug("Throttled lastActiveAt update skipped for userId={}: {}", userId, e.getMessage());
            }
        }
    }

    public void markOffline(Long userId) {
        if (userId != null) {
            onlineMap.remove(userId);
        }
    }

    public void clearAll() {
        onlineMap.clear();
    }

    public DashboardOverviewVO.OnlineSummaryVO getOnlineSnapshot() {
        long nowMs = System.currentTimeMillis();
        long cutoff = nowMs - ONLINE_WINDOW_MS;

        // 清理超时离线记录
        onlineMap.entrySet().removeIf(entry -> entry.getValue().lastSeenEpochMs() < cutoff);

        List<OnlineEntry> activeEntries = onlineMap.values().stream()
                .filter(e -> e.lastSeenEpochMs() >= cutoff)
                .sorted(Comparator.comparingLong(OnlineEntry::lastSeenEpochMs).reversed())
                .toList();

        if (activeEntries.isEmpty()) {
            return DashboardOverviewVO.OnlineSummaryVO.builder()
                    .onlineStudentCount(0L)
                    .onlineWindowMinutes(ONLINE_WINDOW_MINUTES)
                    .serverTime(LocalDateTime.now())
                    .gradeDistribution(List.of())
                    .students(List.of())
                    .build();
        }

        List<Long> ids = activeEntries.stream().map(OnlineEntry::userId).toList();
        Map<Long, AppUser> userMap = appUserMapper.selectBatchIds(ids).stream()
                .filter(u -> u.getStatus() == null || u.getStatus() == 1)
                .collect(Collectors.toMap(AppUser::getId, u -> u, (a, b) -> a));

        Map<String, String> gradeNameMap = new LinkedHashMap<>();
        Map<String, Long> gradeCountMap = new LinkedHashMap<>();
        for (EduRealm r : realmHelper.listOrderedRealms()) {
            gradeNameMap.put(r.getGradeCode(), r.getRealmName());
        }

        List<DashboardOverviewVO.OnlineStudentItem> students = new ArrayList<>();
        for (OnlineEntry entry : activeEntries) {
            AppUser u = userMap.get(entry.userId());
            if (u == null) {
                onlineMap.remove(entry.userId());
                continue;
            }
            EduRealm realm = realmHelper.resolveUserRealm(u);
            String gCode = realm.getGradeCode();
            String gName = realm.getRealmName();
            gradeNameMap.putIfAbsent(gCode, gName);
            gradeCountMap.merge(gCode, 1L, Long::sum);

            if (students.size() < 30) {
                long secAgo = Math.max(0L, (nowMs - entry.lastSeenEpochMs()) / 1000L);
                LocalDateTime lastSeen = LocalDateTime.ofInstant(
                        Instant.ofEpochMilli(entry.lastSeenEpochMs()),
                        ZoneId.systemDefault()
                );
                students.add(DashboardOverviewVO.OnlineStudentItem.builder()
                        .userId(u.getId())
                        .username(u.getUsername())
                        .nickname(u.getNickname())
                        .gradeCode(gCode)
                        .gradeName(gName)
                        .realmName(realm.getRealmName())
                        .platform(entry.platform())
                        .lastAction(entry.lastAction())
                        .lastSeenAt(lastSeen)
                        .secondsAgo(secAgo)
                        .build());
            }
        }

        long totalOnline = gradeCountMap.values().stream().mapToLong(Long::longValue).sum();
        List<DashboardOverviewVO.OnlineGradeCountItem> dist = gradeCountMap.entrySet().stream()
                .map(e -> DashboardOverviewVO.OnlineGradeCountItem.builder()
                        .gradeCode(e.getKey())
                        .gradeName(gradeNameMap.getOrDefault(e.getKey(), e.getKey()))
                        .count(e.getValue())
                        .build())
                .toList();

        return DashboardOverviewVO.OnlineSummaryVO.builder()
                .onlineStudentCount(totalOnline)
                .onlineWindowMinutes(ONLINE_WINDOW_MINUTES)
                .serverTime(LocalDateTime.now())
                .gradeDistribution(dist)
                .students(students)
                .build();
    }

    private String normalizeAction(String raw) {
        if (raw == null || raw.isBlank()) {
            return "在线学习";
        }
        String s = raw.trim();
        if (s.contains("/quiz/")) return "闯关答题";
        if (s.contains("/wrong-questions")) return "错题巩固";
        if (s.contains("/videos")) return "数学课堂";
        if (s.contains("/ai/")) return "AI 智能画板";
        if (s.contains("/banners")) return "查看师资介绍";
        if (s.contains("/home") || s.contains("/grades") || s.contains("/realms")) return "浏览首页";
        if (s.contains("/heartbeat")) return "在线学习";
        return s.length() > 24 ? s.substring(0, 24) : s;
    }
}
