package com.guoguanla.module.ai.vo;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

public class AiBoardVO {

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class StatusVO {
        private Boolean enabled;
        private Boolean configured;
        private String modelName;
        private Boolean supportsVision;
        private String message;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RecognizeVO {
        private String title;
        private String problemText;
        private String subjectTag;
        private String questionType;
        private String difficulty;
        private List<String> knownConditions;
        private List<String> targets;
        private Boolean hasFigure;
        private String figureNote;
        private List<FigureBoxVO> figureBoxes;
        private List<BoardDiagramVO> diagrams;
        private String modelUsed;
        private Long latencyMs;
    }

    /**
     * 题目配图在原图中的归一化边界框（0.0 ~ 1.0），用于客户端从高分辨率原图 1:1 精准裁剪还原。
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class FigureBoxVO {
        private String title;
        private Double x;
        private Double y;
        private Double w;
        private Double h;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class GuidanceVO {
        /**
         * IDEAS（解题思路） / ANALYZE（解题过程与诊断）
         */
        private String mode;
        private String headline;
        private String summary;
        private List<String> knowledgePoints;
        private StudentDiagnosisVO studentDiagnosis;
        private List<BoardStepVO> steps;
        private String finalAnswer;
        private List<String> pitfalls;
        private List<BoardDiagramVO> diagrams;
        private String modelUsed;
        private Long latencyMs;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class StudentDiagnosisVO {
        /**
         * NONE（未作答）/ CORRECT（完全正确）/ PARTIAL（方向正确/部分完成）/ INCORRECT（存在错误）
         */
        private String status;
        private String comment;
        private String mistakePoint;
        private String suggestion;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class BoardStepVO {
        private Integer stepNo;
        private String title;
        private String content;
        private String formula;
        private String highlight;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class BoardDiagramVO {
        private String title;
        private Double width;
        private Double height;
        private List<DiagramPrimitiveVO> primitives;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DiagramPrimitiveVO {
        /**
         * line / arrow / circle / polygon / polyline / point / text
         */
        private String type;
        private Double x1;
        private Double y1;
        private Double x2;
        private Double y2;
        private Double cx;
        private Double cy;
        private Double r;
        private Double x;
        private Double y;
        private List<List<Double>> points;
        private String label;
        private String text;
        private String color;
        private String fillColor;
        private Boolean dashed;
    }
}
