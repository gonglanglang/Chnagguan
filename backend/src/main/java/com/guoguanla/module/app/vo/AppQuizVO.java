package com.guoguanla.module.app.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

public class AppQuizVO {

    @Data
    @Builder
    public static class StartVO {
        private String sessionNo;
        private String mode;
        private String realmCode;
        private String realmName;
        private Integer realmOrder;
        private boolean suppressedMode;
        private Integer passScore;
        private Long chapterId;
        private String chapterName;
        private Long gateId;
        private String gateName;
        private Integer star;
        private Integer passCount;
        private Integer totalCount;
        private boolean guestMode;
        private List<ClientQuestionItem> items;
    }

    @Data
    @Builder
    public static class ClientQuestionItem {
        private Integer itemIndex;
        private String questionFormat;
        private String stem;
        private List<String> options;
        private Map<String, Object> diagram;
        private String imageUrl;
    }

    @Data
    @Builder
    public static class UploadAnswerImageVO {
        private String objectKey;
        private String previewUrl;
        private String storageType;
    }

    @Data
    @Builder
    public static class CheckItemVO {
        private Integer itemIndex;
        private String questionFormat;
        private boolean correct;
        private Integer correctIndex;
        private String referenceAnswer;
        private String answerText;
        private String answerImageUrl;
        private Integer aiScore;
        private String aiComment;
        private String aiModel;
        private String analysis;
    }

    @Data
    @Builder
    public static class SubmitResultVO {
        private String sessionNo;
        private String mode;
        private Integer totalCount;
        private Integer correctCount;
        private Integer score;
        private Integer passScore;
        private Integer passCount;
        private boolean passed;
        private boolean newlyPassed;
        private Integer totalPassedGates;
        private AppUserProfileVO.LevelProgress promotedLevel;
        private AppUserProfileVO.RealmItemVO promotedRealm;
        private List<WrongReviewItem> wrongItems;
        private int masteredCount;
        /** 通关后可直接进入的下一关信息（支持同章下一关、同年级下一章第1关及跨年级下一年级第1章第1关） */
        private Long nextGateId;
        private Integer nextGateIndex;
        private String nextGateName;
        private Long nextChapterId;
        private String nextChapterName;
        private boolean nextGateCrossChapter;
        private String nextGradeCode;
        private String nextGradeName;
        private boolean nextGateCrossGrade;
    }

    @Data
    @Builder
    public static class WrongReviewItem {
        private String stem;
        private String questionFormat;
        private String correctAnswer;
        private String analysis;
        private Map<String, Object> diagram;
        private String imageUrl;
    }

    @Data
    @Builder
    public static class WrongQuestionVO {
        private Long id;
        private String gradeCode;
        private String realmCode;
        private String realmName;
        private Long chapterId;
        private String chapterName;
        private String gateName;
        private String questionFormat;
        private String questionTypeLabel;
        private Boolean needsAnswerSpace;
        private String stem;
        private List<String> options;
        private Integer answerIndex;
        private String referenceAnswer;
        private String lastAnswerImageUrl;
        private String analysis;
        private Map<String, Object> diagram;
        private String imageUrl;
        private Integer wrongCount;
        private LocalDateTime lastWrongAt;
    }

    @Data
    @Builder
    public static class EssayAnswerRecordVO {
        private Long id;
        private String sessionNo;
        private Integer itemIndex;
        private String realmCode;
        private String realmName;
        private String chapterName;
        private Long gateId;
        private String gateName;
        private String stem;
        private Map<String, Object> diagram;
        private String imageUrl;
        private String referenceAnswer;
        private String answerText;
        private String answerImageUrl;
        private Integer aiStatus;
        private Integer aiScore;
        private String aiComment;
        private String aiModel;
        private LocalDateTime createdAt;
        private LocalDateTime verifiedAt;
    }
}
