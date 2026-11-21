package com.guoguanla.module.app.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

@Data
public class AppQuizDTO {

    @Data
    public static class StartReq {
        @NotNull(message = "关卡ID不能为空")
        private Long gateId;
        private List<Long> guestPassedGateIds;
    }

    @Data
    public static class CheckItemReq {
        @NotBlank(message = "会话编号不能为空")
        private String sessionNo;
        @NotNull(message = "题号不能为空")
        private Integer itemIndex;
        /** 选择题作答索引 */
        private Integer selectedIndex;
        /** 解答题文字作答补充 */
        private String answerText;
        /** 解答题手写板上传返回的对象键或URL */
        private String answerImageKey;
        /** 解答题是否已自评 */
        private Boolean selfCorrect;
    }

    @Data
    public static class EssayGradeReq {
        @NotBlank(message = "会话编号不能为空")
        private String sessionNo;
        @NotNull(message = "题号不能为空")
        private Integer itemIndex;
        @NotNull(message = "自评结果不能为空")
        private Boolean correct;
        private String answerText;
        private String answerImageKey;
    }

    @Data
    public static class SubmitReq {
        @NotBlank(message = "会话编号不能为空")
        private String sessionNo;
        private List<AnswerSelection> answers;
    }

    @Data
    public static class AnswerSelection {
        private Integer itemIndex;
        private Integer selectedIndex;
        private String answerText;
        private String answerImageKey;
        private Boolean selfCorrect;
    }

    @Data
    public static class RedoStartReq {
        private String gradeCode;
        private String realmCode;
        private Long chapterId;
        private Integer limit = 5;
    }
}
