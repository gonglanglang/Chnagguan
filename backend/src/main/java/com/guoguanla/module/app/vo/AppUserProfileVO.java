package com.guoguanla.module.app.vo;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class AppUserProfileVO {

    private Long id;
    private String username;
    private String nickname;
    private String avatarUrl;
    private String gradeCode;
    private String gradeName;
    private String realmCode;
    private String realmName;
    private Integer realmOrder;
    private String difficultyLabel;
    private String nextRealmCode;
    private String nextRealmName;
    private Integer realmPassedGates;
    private Integer realmTotalGates;
    private Integer examUnlockGates;
    private Integer examRemainingGates;
    private boolean examEligible;
    private Integer examQuestionCount;
    private Integer examPassScore;
    private Integer passedGateCount;
    private LevelProgress level;

    @Data
    @Builder
    public static class LevelProgress {
        private Long levelId;
        private String icon;
        private String levelName;
        private String quote;
        private Integer minGates;
        private Integer nextMinGates;
        private String nextIcon;
        private String nextLevelName;
    }

    @Data
    @Builder
    public static class AuthVO {
        private String token;
        private AppUserProfileVO profile;
    }

    @Data
    @Builder
    public static class HomeSummaryVO {
        private boolean guestModeEnabled;
        private String appNotice;
        private AppUserProfileVO profile;
        private List<GradeItemVO> grades;
        private List<RealmItemVO> realms;
    }

    @Data
    @Builder
    public static class GradeItemVO {
        private String gradeCode;
        private String gradeName;
        private String icon;
        private long chapterCount;
    }

    @Data
    @Builder
    public static class RealmItemVO {
        private String realmCode;
        private String realmName;
        private Integer realmOrder;
        private String gradeCode;
        private String difficultyLabel;
        private String description;
        private Integer unlockGates;
        private Integer examQuestionCount;
        private Integer examPassScore;
        private long chapterCount;
        private long gateCount;
        private long passedGateCount;
        private boolean unlocked;
        @JsonProperty("isCurrent")
        private boolean isCurrent;
        @JsonProperty("isLower")
        private boolean isLower;
        @JsonProperty("isHigher")
        private boolean isHigher;
        private boolean examEligible;
        private Integer examRemainingGates;
    }

    @Data
    @Builder
    public static class ChapterCardVO {
        private Long id;
        private String chapterCode;
        private String gradeCode;
        private String realmCode;
        private String realmName;
        private Integer realmOrder;
        private String name;
        private String description;
        private Integer isCustom;
        private int passedCount;
        private int totalGates;
        private boolean lockedByRealm;
        private boolean suppressed;
    }

    @Data
    @Builder
    public static class GateCardVO {
        private Long id;
        private Long chapterId;
        private Integer gateIndex;
        private String gateName;
        private Integer star;
        private Integer questionCount;
        private Integer passCount;
        private boolean passed;
        private boolean locked;
        private boolean lockedByRealm;
        private boolean suppressed;
        private boolean empty;
    }

    @Data
    @Builder
    public static class LevelItemVO {
        private Long id;
        private Integer minGates;
        private String icon;
        private String levelName;
        private String quote;
        private boolean unlocked;
    }
}
