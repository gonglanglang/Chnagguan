package com.guoguanla.module.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.module.ai.dto.AiBoardAnalyzeReq;
import com.guoguanla.module.ai.dto.AiRecognizeReq;
import com.guoguanla.module.ai.dto.AiTestReq;
import com.guoguanla.module.ai.vo.AiBoardVO;
import com.guoguanla.module.ai.vo.AiTestVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Locale;

@Slf4j
@Service
@RequiredArgsConstructor
public class AiBoardService {

    private static final int MAX_IMAGE_BYTES = 8 * 1024 * 1024;
    private static final String DEFAULT_MATH_SYSTEM_PROMPT = """
            你是「过关啦」中小学数学特级教研老师与智能画板板书专家，擅长初一至高三数学解答题识别、启发式思路点拨、学生手写步骤批改与清晰板书排版。
            严格遵守以下要求：
            1. 仅输出合法 JSON 对象，不要附加 Markdown 解释或多余前后缀文字；JSON 字符串值内部如需引用词语请使用中文引号「」或“”，严禁使用未转义英文双引号；
            2. 数学公式使用标准简洁的 LaTeX（用 $...$ 包裹，如 $\\frac{1}{2}$、$x^2-3x+2=0$、$\\sqrt{3}$、$\\triangle ABC$、$\\angle A=60°$）或清晰 Unicode 数学符号，JSON 字符串内的反斜杠务必双写（\\\\frac、\\\\sqrt、\\\\times、\\\\triangle 等）；
            3. 语言精炼、条理清晰，适合直接排版绘制在学生手写白板上阅读；
            4. 当题目涉及几何图形、辅助线或函数坐标系图像时，尽可能在 diagrams 字段给出简洁准确的矢量绘图指令（画布坐标 0~320 x 0~220，留足边距）。
            """;

    private final AiConfigService aiConfigService;
    private final OpenAiCompatibleClient openAiClient;
    private final ObjectMapper objectMapper;

    public AiBoardVO.StatusVO getStudentStatus() {
        AiConfigService.RuntimeAiConfig cfg = aiConfigService.loadRuntimeConfig();
        boolean configured = cfg.isConfigured();
        String msg;
        if (!cfg.isEnabled()) {
            msg = "管理员暂未开启 AI 智能画板功能";
        } else if (!configured) {
            msg = "管理员尚未配置 AI 接口或密钥";
        } else {
            msg = "AI 智能画板已就绪";
        }
        return AiBoardVO.StatusVO.builder()
                .enabled(cfg.isEnabled())
                .configured(configured)
                .modelName(configured ? cfg.getModel() : "")
                .supportsVision(configured)
                .message(msg)
                .build();
    }

    public AiTestVO testConnection(AiTestReq req) {
        AiConfigService.RuntimeAiConfig saved = aiConfigService.loadRuntimeConfig();
        String baseUrl = (req != null && req.getBaseUrl() != null && !req.getBaseUrl().isBlank())
                ? req.getBaseUrl().trim()
                : saved.getBaseUrl();
        String apiKey = (req != null && req.getApiKey() != null && !req.getApiKey().isBlank() && !req.getApiKey().contains("****"))
                ? req.getApiKey().trim()
                : saved.getApiKey();
        String model = (req != null && req.getModel() != null && !req.getModel().isBlank())
                ? req.getModel().trim()
                : saved.getModel();
        int timeoutSec = (req != null && req.getTimeoutSec() != null)
                ? Math.max(10, Math.min(180, req.getTimeoutSec()))
                : Math.min(30, saved.getTimeoutSec());

        if (apiKey == null || apiKey.isBlank()) {
            return AiTestVO.builder()
                    .ok(false)
                    .endpoint(baseUrl)
                    .model(model)
                    .errorMessage("请先填写 AI API 密钥")
                    .build();
        }

        String endpoint;
        try {
            endpoint = AiConfigService.resolveChatCompletionsUrl(baseUrl);
        } catch (BizException e) {
            return AiTestVO.builder()
                    .ok(false)
                    .endpoint(baseUrl)
                    .model(model)
                    .errorMessage(e.getMessage())
                    .build();
        }

        long start = System.currentTimeMillis();
        try {
            OpenAiCompatibleClient.ChatCallResult res = openAiClient.chat(
                    OpenAiCompatibleClient.ChatCallRequest.builder()
                            .endpoint(endpoint)
                            .apiKey(apiKey)
                            .model(model)
                            .systemPrompt("你是数学连通性检测助手，请用不超过 20 字回答。")
                            .userPrompt("请计算 12 + 34 = ? 并简短回复“连接成功”。")
                            .temperature(0.1)
                            .maxTokens(128)
                            .timeoutSec(timeoutSec)
                            .disableThinking(true)
                            .build()
            );
            return AiTestVO.builder()
                    .ok(true)
                    .latencyMs(res.getLatencyMs())
                    .endpoint(endpoint)
                    .model(res.getModelUsed())
                    .reply(res.getContent())
                    .build();
        } catch (BizException e) {
            return AiTestVO.builder()
                    .ok(false)
                    .latencyMs(System.currentTimeMillis() - start)
                    .endpoint(endpoint)
                    .model(model)
                    .errorMessage(e.getMessage())
                    .build();
        }
    }

    public AiBoardVO.RecognizeVO recognizeProblem(AiRecognizeReq req) {
        if (req == null || req.getImageBase64() == null || req.getImageBase64().isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请先拍摄或上传数学题目图片");
        }
        String dataUri = normalizeImageDataUri(req.getImageBase64(), req.getMimeType());
        return recognizeProblemInternal(dataUri, req.getExtraHint());
    }

    public AiBoardVO.RecognizeVO recognizeProblemUpload(MultipartFile file, String extraHint) {
        if (file == null || file.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请上传有效的数学题目图片");
        }
        if (file.getSize() > MAX_IMAGE_BYTES) {
            throw new BizException(ErrorCode.BAD_REQUEST, "图片体积不能超过 8MB");
        }
        try {
            String mime = normalizeMimeType(file.getContentType(), file.getOriginalFilename());
            String b64 = Base64.getEncoder().encodeToString(file.getBytes());
            return recognizeProblemInternal("data:" + mime + ";base64," + b64, extraHint);
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            throw new BizException(ErrorCode.BAD_REQUEST, "读取题目图片失败：" + e.getMessage());
        }
    }

    private AiBoardVO.RecognizeVO recognizeProblemInternal(String imageDataUri, String extraHint) {
        AiConfigService.RuntimeAiConfig cfg = requireReadyConfig();

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("""
                请仔细识别图片中的数学题目，提取完整题干并结构化输出，方便自动排版绘制到学生的智能手写画板中。
                请严格返回如下 JSON 结构（所有字符串中的 LaTeX 反斜杠请双写）：
                {
                  "title": "简短题目标题（8~18字）",
                  "problemText": "完整规范的题干文本，分小题请使用 \\n 换行，公式使用 $...$ 包裹",
                  "subjectTag": "核心知识点，如 二次函数 / 全等三角形 / 一元二次方程",
                  "questionType": "解答题 / 证明题 / 计算题 / 几何综合 / 填空题 / 选择题",
                  "difficulty": "基础 / 中档 / 拓展 / 压轴",
                  "knownConditions": ["提炼的已知条件1", "已知条件2"],
                  "targets": ["要求解或证明的目标1", "目标2"],
                  "hasFigure": true或false,
                  "figureNote": "若图片包含几何图/坐标系图，简述图形要点，否则留空",
                  "diagrams": []
                }
                注意：仅当图片明显包含几何图形或函数图像时才在 diagrams 中给出 1 个简洁矢量示意图（width:320,height:220，primitives 最多 8 个核心图元）；纯文字题请直接返回 "diagrams": []。
                """);
        if (extraHint != null && !extraHint.isBlank()) {
            userPrompt.append("\n学生补充说明：").append(extraHint.trim());
        }

        OpenAiCompatibleClient.ChatCallResult res = openAiClient.chat(
                OpenAiCompatibleClient.ChatCallRequest.builder()
                        .endpoint(cfg.getChatCompletionsUrl())
                        .apiKey(cfg.getApiKey())
                        .model(cfg.effectiveVisionModel())
                        .systemPrompt(effectiveSystemPrompt(cfg))
                        .userPrompt(userPrompt.toString())
                        .imageDataUris(List.of(imageDataUri))
                        .temperature(Math.min(cfg.getTemperature(), 0.25))
                        .maxTokens(cfg.getMaxTokens())
                        .timeoutSec(cfg.getTimeoutSec())
                        .disableThinking(true)
                        .jsonObjectResponse(true)
                        .build()
        );

        return parseRecognizeResult(res.getContent(), res.getModelUsed(), res.getLatencyMs());
    }

    public AiBoardVO.GuidanceVO generateIdeas(AiBoardAnalyzeReq req) {
        return runBoardGuidance("IDEAS", req);
    }

    public AiBoardVO.GuidanceVO diagnoseHandwriting(AiBoardAnalyzeReq req) {
        if (req == null || req.getBoardImageBase64() == null || req.getBoardImageBase64().isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请先在画板上写下你的解题过程，再点击诊断");
        }
        return runBoardGuidance("DIAGNOSE", req);
    }

    public AiBoardVO.GuidanceVO solveProblem(AiBoardAnalyzeReq req) {
        return runBoardGuidance("SOLVE", req);
    }

    public AiBoardVO.GuidanceVO analyzeSolution(AiBoardAnalyzeReq req) {
        return solveProblem(req);
    }

    private AiBoardVO.GuidanceVO runBoardGuidance(String mode, AiBoardAnalyzeReq req) {
        AiConfigService.RuntimeAiConfig cfg = requireReadyConfig();
        String problemText = req != null && req.getProblemText() != null ? req.getProblemText().trim() : "";
        List<String> images = new ArrayList<>();
        if (req != null && req.getProblemImageBase64() != null && !req.getProblemImageBase64().isBlank()) {
            images.add(normalizeImageDataUri(req.getProblemImageBase64(), null));
        }
        if (req != null && req.getBoardImageBase64() != null && !req.getBoardImageBase64().isBlank()) {
            images.add(normalizeImageDataUri(req.getBoardImageBase64(), "image/png"));
        }
        if (problemText.isBlank() && images.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请先拍照识别题目、输入题干或在画板上写下题目");
        }

        boolean isIdeas = "IDEAS".equals(mode);
        boolean isDiagnose = "DIAGNOSE".equals(mode);
        StringBuilder prompt = new StringBuilder();
        if (isIdeas) {
            prompt.append("任务：请为下方数学题生成简洁清晰的【解题思路引导】，用于逐笔手写绘制在白板上。\n");
            prompt.append("硬性约束：\n");
            prompt.append("1. 只引导学生思考方向、破题切入点、通用公式原型、辅助线做法与解题方法，绝不能直接算出最终数值或泄露最终答案！\n");
            prompt.append("2. steps 控制在 3~5 步，每步简明精炼（1~2句话），只给通用公式或转化思路（如配方法公式、判别式、三角形面积公式），不要替学生算出最终得数；\n");
            prompt.append("3. finalAnswer 必须留空字符串 \"\"；studentDiagnosis.status 设为 \"NONE\" 且内容留空；\n");
            prompt.append("4. 若涉及几何或函数图像，请在 diagrams 给出 1 个准确坐标的矢量示意图（坐标 0~320 x 0~220），便于画板按坐标逐笔绘制。\n");
        } else if (isDiagnose) {
            prompt.append("任务：请批改【诊断】图片中学生在画板上手写的数学解题过程。\n");
            prompt.append("硬性约束：\n");
            prompt.append("1. 严禁直接给出完整解答步骤或泄露最终正确答案！finalAnswer 必须留空字符串 \"\"！\n");
            prompt.append("2. 仔细阅读学生画板上的手写字迹与推导过程，在 studentDiagnosis 中准确判定 status（CORRECT 全部正确 / PARTIAL 思路对但未写完或有疏漏 / INCORRECT 存在错误），简明指出对在哪里、错在哪一步及错因；\n");
            prompt.append("3. 在 steps 中按学生作答顺序逐条列出批注（例如：第1步正确/第2步符号有误，建议重算该项），仅提示检查方向，不直接剧透答案；\n");
            prompt.append("4. 语言像老师红笔批改一样简短干脆，不要客套废话；diagrams 返回空数组 []。\n");
        } else {
            prompt.append("任务：请直接给出下方数学题的【完整规范解题过程与最终答案】，用于逐笔板书绘制在白板上。\n");
            prompt.append("要求：\n");
            prompt.append("1. 语言精炼、格式规范（标准“解：/ 证明：”板书推导，无花哨修饰与多余客套）；\n");
            prompt.append("2. steps 按实际推导逻辑给出清晰分步与关键数学算式，finalAnswer 写出明确最终答案；\n");
            prompt.append("3. studentDiagnosis.status 设为 \"NONE\" 且内容留空；\n");
            prompt.append("4. 若涉及几何图形或函数图像，请在 diagrams 给出 1 个准确坐标的矢量示意图（0~320 x 0~220）。\n");
        }

        if (!problemText.isBlank()) {
            prompt.append("\n【数学题目】\n").append(problemText).append("\n");
        } else {
            prompt.append("\n【数学题目】请直接结合图片中的题目内容进行处理。\n");
        }
        if (req != null && req.getUserNotes() != null && !req.getUserNotes().isBlank()) {
            prompt.append("\n【补充说明】\n").append(req.getUserNotes().trim()).append("\n");
        }

        prompt.append("""

                请严格输出合法 JSON（不要输出 Markdown 以外的解释，JSON 字符串内 LaTeX 反斜杠双写）：
                {
                  "headline": "简明核心方法或诊断结论（10~20字）",
                  "summary": "1句话简短总领（不超过40字）",
                  "knowledgePoints": ["知识点1"],
                  "studentDiagnosis": {
                    "status": "NONE 或 CORRECT 或 PARTIAL 或 INCORRECT",
                    "comment": "对学生手写过程的简明总体判定（非诊断模式留空）",
                    "mistakePoint": "具体错误步骤定位（无错或非诊断模式留空）",
                    "suggestion": "自主检查或订正方向（不给答案，非诊断模式留空）"
                  },
                  "steps": [
                    {
                      "stepNo": 1,
                      "title": "简短步骤标题（4~10字）",
                      "content": "该步骤的简洁文字引导/批注/推理说明",
                      "formula": "该步骤的关键数学公式或算式，支持 $...$，无则留空",
                      "highlight": "简短要点提示，无则留空"
                    }
                  ],
                  "finalAnswer": "仅解题模式填写明确最终答案；思路模式与诊断模式必须为空字符串",
                  "pitfalls": ["易错点提醒（最多2条，简短）"],
                  "diagrams": [
                    {
                      "title": "示意图标题（不需要画图时返回 []）",
                      "width": 320,
                      "height": 220,
                      "primitives": [
                        {"type": "arrow", "x1": 24, "y1": 190, "x2": 296, "y2": 190, "color": "#334155"},
                        {"type": "arrow", "x1": 50, "y1": 205, "x2": 50, "y2": 20, "color": "#334155"},
                        {"type": "polyline", "points": [[60,170],[110,95],[160,60],[210,95],[260,170]], "color": "#2563EB"},
                        {"type": "line", "x1": 160, "y1": 40, "x2": 160, "y2": 190, "color": "#DC2626", "dashed": true},
                        {"type": "point", "x": 160, "y": 60, "label": "C", "color": "#DC2626"}
                      ]
                    }
                  ]
                }
                """);

        String targetModel = images.isEmpty() ? cfg.getModel() : cfg.effectiveVisionModel();
        OpenAiCompatibleClient.ChatCallResult res = openAiClient.chat(
                OpenAiCompatibleClient.ChatCallRequest.builder()
                        .endpoint(cfg.getChatCompletionsUrl())
                        .apiKey(cfg.getApiKey())
                        .model(targetModel)
                        .systemPrompt(effectiveSystemPrompt(cfg))
                        .userPrompt(prompt.toString())
                        .imageDataUris(images)
                        .temperature(cfg.getTemperature())
                        .maxTokens(cfg.getMaxTokens())
                        .timeoutSec(cfg.getTimeoutSec())
                        .disableThinking(true)
                        .jsonObjectResponse(true)
                        .build()
        );

        return parseGuidanceResult(mode, res.getContent(), res.getModelUsed(), res.getLatencyMs());
    }

    private AiConfigService.RuntimeAiConfig requireReadyConfig() {
        AiConfigService.RuntimeAiConfig cfg = aiConfigService.loadRuntimeConfig();
        if (!cfg.isEnabled()) {
            throw new BizException(ErrorCode.AI_DISABLED);
        }
        if (!cfg.isConfigured()) {
            throw new BizException(ErrorCode.AI_NOT_CONFIGURED);
        }
        return cfg;
    }

    private String effectiveSystemPrompt(AiConfigService.RuntimeAiConfig cfg) {
        if (cfg.getSystemPrompt() != null && !cfg.getSystemPrompt().isBlank()) {
            return cfg.getSystemPrompt() + "\n\n" + DEFAULT_MATH_SYSTEM_PROMPT;
        }
        return DEFAULT_MATH_SYSTEM_PROMPT;
    }

    public AiBoardVO.RecognizeVO parseRecognizeResult(String rawContent, String modelUsed, long latencyMs) {
        JsonNode root = tryParseJsonObject(rawContent);
        if (root == null) {
            // 容错降级：模型返回了纯文本题干而非 JSON
            String fallback = cleanRawFallback(rawContent);
            return AiBoardVO.RecognizeVO.builder()
                    .title("拍照识别数学题")
                    .problemText(fallback)
                    .subjectTag("数学综合")
                    .questionType("解答题")
                    .difficulty("中档")
                    .knownConditions(List.of())
                    .targets(List.of())
                    .hasFigure(false)
                    .figureNote("")
                    .diagrams(List.of())
                    .modelUsed(modelUsed)
                    .latencyMs(latencyMs)
                    .build();
        }

        String problemText = textOf(root, "problemText", "");
        if (problemText.isBlank()) {
            problemText = textOf(root, "stem", cleanRawFallback(rawContent));
        }

        return AiBoardVO.RecognizeVO.builder()
                .title(textOf(root, "title", "数学解答题"))
                .problemText(problemText)
                .subjectTag(textOf(root, "subjectTag", "数学"))
                .questionType(textOf(root, "questionType", "解答题"))
                .difficulty(textOf(root, "difficulty", "中档"))
                .knownConditions(readStringList(root.path("knownConditions")))
                .targets(readStringList(root.path("targets")))
                .hasFigure(root.path("hasFigure").asBoolean(false))
                .figureNote(textOf(root, "figureNote", ""))
                .diagrams(readDiagrams(root.path("diagrams")))
                .modelUsed(modelUsed)
                .latencyMs(latencyMs)
                .build();
    }

    public AiBoardVO.GuidanceVO parseGuidanceResult(String mode, String rawContent, String modelUsed, long latencyMs) {
        JsonNode root = tryParseJsonObject(rawContent);
        if (root == null) {
            String fallback = cleanRawFallback(rawContent);
            List<AiBoardVO.BoardStepVO> fallbackSteps = splitPlainLinesToSteps(fallback);
            return AiBoardVO.GuidanceVO.builder()
                    .mode(mode)
                    .headline("IDEAS".equals(mode) ? "AI 解题思路" : "AI 解题过程分析")
                    .summary("")
                    .knowledgePoints(List.of())
                    .steps(fallbackSteps)
                    .finalAnswer("")
                    .pitfalls(List.of())
                    .diagrams(List.of())
                    .modelUsed(modelUsed)
                    .latencyMs(latencyMs)
                    .build();
        }

        AiBoardVO.StudentDiagnosisVO diagnosis = null;
        JsonNode diagNode = root.path("studentDiagnosis");
        if (diagNode.isObject()) {
            String status = textOf(diagNode, "status", "NONE").toUpperCase(Locale.ROOT);
            String comment = textOf(diagNode, "comment", "");
            String mistake = textOf(diagNode, "mistakePoint", "");
            String suggestion = textOf(diagNode, "suggestion", "");
            if (!comment.isBlank() || !mistake.isBlank() || !"NONE".equals(status)) {
                diagnosis = AiBoardVO.StudentDiagnosisVO.builder()
                        .status(status)
                        .comment(comment)
                        .mistakePoint(mistake)
                        .suggestion(suggestion)
                        .build();
            }
        }

        List<AiBoardVO.BoardStepVO> steps = new ArrayList<>();
        JsonNode stepsNode = root.path("steps");
        if (stepsNode.isArray()) {
            int autoNo = 1;
            for (JsonNode s : stepsNode) {
                if (!s.isObject()) continue;
                int no = s.path("stepNo").asInt(autoNo);
                steps.add(AiBoardVO.BoardStepVO.builder()
                        .stepNo(no)
                        .title(textOf(s, "title", "第 " + no + " 步"))
                        .content(textOf(s, "content", ""))
                        .formula(textOf(s, "formula", ""))
                        .highlight(textOf(s, "highlight", ""))
                        .build());
                autoNo++;
            }
        }

        boolean hideFinalAnswer = "IDEAS".equalsIgnoreCase(mode) || "DIAGNOSE".equalsIgnoreCase(mode);
        String defaultHeadline = switch (mode == null ? "" : mode.toUpperCase(Locale.ROOT)) {
            case "IDEAS" -> "解题思路";
            case "DIAGNOSE" -> "手写诊断";
            default -> "规范解题";
        };
        return AiBoardVO.GuidanceVO.builder()
                .mode(mode)
                .headline(textOf(root, "headline", defaultHeadline))
                .summary(textOf(root, "summary", ""))
                .knowledgePoints(readStringList(root.path("knowledgePoints")))
                .studentDiagnosis(diagnosis)
                .steps(steps)
                .finalAnswer(hideFinalAnswer ? "" : textOf(root, "finalAnswer", ""))
                .pitfalls(readStringList(root.path("pitfalls")))
                .diagrams(readDiagrams(root.path("diagrams")))
                .modelUsed(modelUsed)
                .latencyMs(latencyMs)
                .build();
    }

    /**
     * 强容错 JSON 解析：支持剥离 ```json 代码块、提取首个平衡 JSON 对象、并自动修复数学 LaTeX 单反斜杠导致的非法转义。
     */
    JsonNode tryParseJsonObject(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String candidate = extractJsonSubstring(raw);
        if (candidate == null || candidate.isBlank()) return null;

        try {
            JsonNode node = objectMapper.readTree(candidate);
            if (node != null && node.isObject()) {
                return node;
            }
        } catch (Exception ignored) {
        }

        String repaired = repairLatexBackslashesInJson(candidate);
        try {
            JsonNode node = objectMapper.readTree(repaired);
            if (node != null && node.isObject()) {
                return node;
            }
        } catch (Exception e) {
            log.warn("Failed to parse AI JSON even after LaTeX repair: {}", e.getMessage());
        }
        return null;
    }

    static String extractJsonSubstring(String raw) {
        String s = raw.trim();
        if (s.startsWith("```")) {
            int firstNewline = s.indexOf('\n');
            if (firstNewline > 0) {
                s = s.substring(firstNewline + 1);
            }
            int lastFence = s.lastIndexOf("```");
            if (lastFence >= 0) {
                s = s.substring(0, lastFence);
            }
            s = s.trim();
        }
        int start = s.indexOf('{');
        int end = s.lastIndexOf('}');
        if (start >= 0 && end > start) {
            return s.substring(start, end + 1);
        }
        return s;
    }

    /**
     * 修复大模型在 JSON 字符串中输出未双写反斜杠的 LaTeX 数学命令（如 \frac, \sqrt, \times, \triangle, \beta, \right 等）。
     */
    static String repairLatexBackslashesInJson(String json) {
        StringBuilder out = new StringBuilder(json.length() + 64);
        boolean inString = false;
        int len = json.length();
        for (int i = 0; i < len; i++) {
            char c = json.charAt(i);
            if (c == '"') {
                // 判断引号前连续反斜杠数量
                int bsCount = 0;
                for (int k = i - 1; k >= 0 && json.charAt(k) == '\\'; k--) {
                    bsCount++;
                }
                if (bsCount % 2 == 0) {
                    inString = !inString;
                }
                out.append(c);
                continue;
            }
            if (inString && c == '\\' && i + 1 < len) {
                char next = json.charAt(i + 1);
                if (next == '\\' || next == '"' || next == '/' || next == 'u') {
                    // 合法转义（保留原样；若为 \\ 则把两个都拷贝避免重复判断）
                    out.append(c).append(next);
                    i++;
                    continue;
                }
                if (next == 'n') {
                    // 若后接字母（如 \neq, \notin），极大概率是 LaTeX 命令而非换行
                    if (i + 2 < len && Character.isLetter(json.charAt(i + 2))) {
                        out.append("\\\\");
                    } else {
                        out.append(c);
                    }
                    continue;
                }
                if (next == 't' || next == 'f' || next == 'r' || next == 'b') {
                    // 若后接字母（如 \times, \triangle, \text, \frac, \right, \beta），判定为 LaTeX 命令并双写反斜杠
                    if (i + 2 < len && Character.isLetter(json.charAt(i + 2))) {
                        out.append("\\\\");
                    } else {
                        out.append(c);
                    }
                    continue;
                }
                // 其他非法 JSON 转义（如 \sqrt, \alpha, \pi, \angle, \cdot, \left, \Delta）一律补双反斜杠
                out.append("\\\\");
                continue;
            }
            out.append(c);
        }
        return out.toString();
    }

    private List<AiBoardVO.BoardDiagramVO> readDiagrams(JsonNode node) {
        if (node == null || !node.isArray()) return List.of();
        List<AiBoardVO.BoardDiagramVO> list = new ArrayList<>();
        for (JsonNode d : node) {
            if (!d.isObject()) continue;
            List<AiBoardVO.DiagramPrimitiveVO> primitives = new ArrayList<>();
            JsonNode prims = d.path("primitives");
            if (prims.isArray()) {
                for (JsonNode p : prims) {
                    if (!p.isObject()) continue;
                    String type = textOf(p, "type", "").toLowerCase(Locale.ROOT);
                    if (type.isBlank()) continue;
                    List<List<Double>> pts = new ArrayList<>();
                    if (p.path("points").isArray()) {
                        for (JsonNode pt : p.path("points")) {
                            if (pt.isArray() && pt.size() >= 2) {
                                pts.add(List.of(pt.get(0).asDouble(), pt.get(1).asDouble()));
                            }
                        }
                    }
                    primitives.add(AiBoardVO.DiagramPrimitiveVO.builder()
                            .type(type)
                            .x1(nullableDouble(p, "x1"))
                            .y1(nullableDouble(p, "y1"))
                            .x2(nullableDouble(p, "x2"))
                            .y2(nullableDouble(p, "y2"))
                            .cx(nullableDouble(p, "cx"))
                            .cy(nullableDouble(p, "cy"))
                            .r(nullableDouble(p, "r"))
                            .x(nullableDouble(p, "x"))
                            .y(nullableDouble(p, "y"))
                            .points(pts.isEmpty() ? null : pts)
                            .label(textOf(p, "label", null))
                            .text(textOf(p, "text", null))
                            .color(textOf(p, "color", "#1E293B"))
                            .fillColor(textOf(p, "fillColor", null))
                            .dashed(p.path("dashed").asBoolean(false))
                            .build());
                }
            }
            if (!primitives.isEmpty()) {
                double w = d.path("width").asDouble(320.0);
                double h = d.path("height").asDouble(220.0);
                list.add(AiBoardVO.BoardDiagramVO.builder()
                        .title(textOf(d, "title", "示意图"))
                        .width(w > 40 ? w : 320.0)
                        .height(h > 40 ? h : 220.0)
                        .primitives(primitives)
                        .build());
            }
        }
        return list;
    }

    private Double nullableDouble(JsonNode node, String field) {
        JsonNode v = node.path(field);
        return v.isNumber() ? v.asDouble() : null;
    }

    private List<String> readStringList(JsonNode node) {
        if (node == null || !node.isArray()) return List.of();
        List<String> out = new ArrayList<>();
        for (JsonNode item : node) {
            String s = item.asText("").trim();
            if (!s.isBlank()) {
                out.add(s);
            }
        }
        return out;
    }

    private String textOf(JsonNode node, String field, String fallback) {
        JsonNode v = node.path(field);
        if (v.isMissingNode() || v.isNull()) return fallback;
        String s = v.asText("");
        return s.isBlank() ? fallback : s.trim();
    }

    private String cleanRawFallback(String raw) {
        if (raw == null) return "";
        return raw.replace("```json", "").replace("```", "").trim();
    }

    private List<AiBoardVO.BoardStepVO> splitPlainLinesToSteps(String text) {
        String[] lines = text.split("\\r?\\n");
        List<AiBoardVO.BoardStepVO> steps = new ArrayList<>();
        int idx = 1;
        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.isBlank()) continue;
            steps.add(AiBoardVO.BoardStepVO.builder()
                    .stepNo(idx)
                    .title("要点 " + idx)
                    .content(trimmed)
                    .formula("")
                    .highlight("")
                    .build());
            idx++;
        }
        return steps;
    }

    private String normalizeImageDataUri(String raw, String fallbackMime) {
        String s = raw.trim();
        if (s.startsWith("data:image/")) {
            if (s.length() > MAX_IMAGE_BYTES * 2) {
                throw new BizException(ErrorCode.BAD_REQUEST, "图片过大，请压缩后重试");
            }
            return s;
        }
        String mime = (fallbackMime == null || fallbackMime.isBlank()) ? "image/jpeg" : fallbackMime.trim();
        if (!mime.startsWith("image/")) {
            mime = "image/jpeg";
        }
        if (s.length() > MAX_IMAGE_BYTES * 2) {
            throw new BizException(ErrorCode.BAD_REQUEST, "图片过大，请压缩后重试");
        }
        return "data:" + mime + ";base64," + s;
    }

    private String normalizeMimeType(String contentType, String fileName) {
        if (contentType != null && contentType.startsWith("image/")) {
            return contentType;
        }
        if (fileName != null) {
            String lower = fileName.toLowerCase(Locale.ROOT);
            if (lower.endsWith(".png")) return "image/png";
            if (lower.endsWith(".webp")) return "image/webp";
            if (lower.endsWith(".gif")) return "image/gif";
        }
        return "image/jpeg";
    }
}
