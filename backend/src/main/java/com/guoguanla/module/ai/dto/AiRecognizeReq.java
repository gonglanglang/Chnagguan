package com.guoguanla.module.ai.dto;

import lombok.Data;

@Data
public class AiRecognizeReq {

    /**
     * 题目照片 Base64（可含 data:image/jpeg;base64,... 前缀，或纯 Base64 字符串）
     */
    private String imageBase64;

    /**
     * 图片 MIME 类型（如 image/jpeg、image/png），未带 data URI 前缀时生效
     */
    private String mimeType;

    /**
     * 可选补充说明（例如“只需要识别第 2 小问”）
     */
    private String extraHint;

    /**
     * 图片来源：PHOTO（拍照/相册，默认）或 BOARD_HANDWRITING（画板手写识题）
     */
    private String sourceType;
}
