package com.guoguanla.module.user.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class UserDetailVO {

    private UserPageVO profile;
    private List<ChapterProgressItem> chapterProgress;
    private List<WrongItem> wrongQuestions;
    private List<QuizRecordItem> recentRecords;

    @Data
    @Builder
    public static class ChapterProgressItem {
        private Long chapterId;
        private String gradeCode;
        private String chapterName;
        private int passedCount;
        private int totalGates;
        private LocalDateTime lastPlayedAt;
    }

    @Data
    @Builder
    public static class WrongItem {
        private Long id;
        private String gradeCode;
        private String chapterName;
        private String gateName;
        private String stem;
        private List<String> options;
        private Integer answerIndex;
        private Integer wrongCount;
        private Integer isMastered;
        private LocalDateTime lastWrongAt;
    }

    @Data
    @Builder
    public static class QuizRecordItem {
        private Long id;
        private String sessionNo;
        private String mode;
        private String realmCode;
        private Integer score;
        private String chapterName;
        private String gateName;
        private Integer totalCount;
        private Integer correctCount;
        private Integer isPassed;
        private LocalDateTime startedAt;
        private LocalDateTime submittedAt;
    }
}
