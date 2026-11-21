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
        @NotNull(message = "选项索引不能为空")
        private Integer selectedIndex;
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
    }

    @Data
    public static class RedoStartReq {
        private String gradeCode;
        private String realmCode;
        private Long chapterId;
        private Integer limit = 5;
    }
}
