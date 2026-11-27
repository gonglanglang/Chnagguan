package com.guoguanla.module.progress.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("user_essay_answer")
public class UserEssayAnswer {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String sessionNo;
    private Integer itemIndex;
    private Long userId;
    private Long questionId;
    private String gradeCode;
    private String realmCode;
    private Long chapterId;
    private String chapterName;
    private Long gateId;
    private String gateName;
    private String stem;
    private String referenceAnswer;
    private String answerText;
    private String answerImageKey;
    /** AI 批改状态：0 未判题，1 正确通过，2 存在错误待订正 */
    private Integer aiStatus;
    /** AI 批改得分：0~100 */
    private Integer aiScore;
    /** AI 批改评语与错因定位 */
    private String aiComment;
    /** 执行 AI 批改的模型名称 */
    private String aiModel;
    /** AI 验证完成时间 */
    private LocalDateTime verifiedAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
