package com.guoguanla.module.dashboard.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class DashboardOverviewVO {

    private long userCount;
    private long activeUserCount;
    private long chapterCount;
    private long gateCount;
    private long questionCount;
    private long staticQuestionCount;
    private long dynamicQuestionCount;
    private long totalQuizCount;
    private long totalWrongCount;
    private List<GradeStatItem> gradeStats;
    private List<RealmStatItem> realmStats;
    private List<LevelStatItem> levelStats;
    private List<TopWrongChapterItem> topWrongChapters;

    @Data
    @Builder
    public static class GradeStatItem {
        private String gradeCode;
        private String gradeName;
        private String icon;
        private long chapterCount;
        private long questionCount;
        private long studentCount;
    }

    @Data
    @Builder
    public static class RealmStatItem {
        private String realmCode;
        private String realmName;
        private String difficultyLabel;
        private String gradeCode;
        private long chapterCount;
        private long questionCount;
        private long studentCount;
    }

    @Data
    @Builder
    public static class LevelStatItem {
        private String levelName;
        private String icon;
        private long userCount;
    }

    @Data
    @Builder
    public static class TopWrongChapterItem {
        private String chapterName;
        private String gradeCode;
        private long wrongCount;
    }
}
