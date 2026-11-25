package com.guoguanla.module.ai.dto;

import lombok.Data;

@Data
public class AiBoardAnalyzeReq {

    /**
     * 当前画板上的数学题干文本（可为空但此时必须提供题目图或画板图）
     */
    private String problemText;

    /**
     * 学生当前手写画板导出的 PNG/JPEG Base64（用于 AI 诊断手写过程）
     */
    private String boardImageBase64;

    /**
     * 可选：原始拍题照片 Base64（若题含复杂几何图可一并发送辅助视觉理解）
     */
    private String problemImageBase64;

    /**
     * 学生补充提问或希望重点分析的疑问
     */
    private String userNotes;

    /**
     * 是否有学生手写笔迹（辅助服务端决定是否开启手写诊断段落）
     */
    private Boolean hasHandwriting;
}
