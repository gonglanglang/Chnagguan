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
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
            throw new BizException(ErrorCode.BAD_REQUEST, "请先拍摄、上传或在画板写下数学题目");
        }
        String dataUri = normalizeImageDataUri(req.getImageBase64(), req.getMimeType());
        return recognizeProblemInternal(dataUri, req.getExtraHint(), req.getSourceType());
    }

    public AiBoardVO.RecognizeVO recognizeProblemUpload(MultipartFile file, String extraHint) {
        return recognizeProblemUpload(file, extraHint, "PHOTO");
    }

    public AiBoardVO.RecognizeVO recognizeProblemUpload(MultipartFile file, String extraHint, String sourceType) {
        if (file == null || file.isEmpty()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请上传有效的数学题目图片");
        }
        if (file.getSize() > MAX_IMAGE_BYTES) {
            throw new BizException(ErrorCode.BAD_REQUEST, "图片体积不能超过 8MB");
        }
        try {
            String mime = normalizeMimeType(file.getContentType(), file.getOriginalFilename());
            String b64 = Base64.getEncoder().encodeToString(file.getBytes());
            return recognizeProblemInternal("data:" + mime + ";base64," + b64, extraHint, sourceType);
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            throw new BizException(ErrorCode.BAD_REQUEST, "读取题目图片失败：" + e.getMessage());
        }
    }

    private AiBoardVO.RecognizeVO recognizeProblemInternal(String imageDataUri, String extraHint, String sourceType) {
        AiConfigService.RuntimeAiConfig cfg = requireReadyConfig();
        boolean fromHandwriting = "BOARD_HANDWRITING".equalsIgnoreCase(sourceType);

        StringBuilder userPrompt = new StringBuilder();
        if (fromHandwriting) {
            userPrompt.append("这是一张学生在电子手写画板上手写的图片。请先严格审核图片内容是否为一道【合理、清晰、完整可解的数学题目】。\n");
            userPrompt.append("防乱画硬性规则：如果图片是随手涂鸦、乱画线条、空白、鬼画符、非数学闲聊文字、孤立数字/字母，或残缺不全没有明确运算/求解/证明目标的片段，必须返回 \"isValidMathProblem\": false，并在 invalidReason 中用 1 句话明确告知原因；切勿编造或脑补不存在的题目！\n");
        } else {
            userPrompt.append("请先严格判断图片中是否包含一道【合理、清晰、完整可解的数学题目】。若为无关风景、乱画涂鸦、空白模糊或非数学题，必须返回 \"isValidMathProblem\": false 并在 invalidReason 说明原因。\n");
        }
        userPrompt.append("""
                若确认是合理完整的数学题，请提取完整题干，并对图片中包含的任何几何图形、函数坐标系、数轴或示意图进行【精准矢量重绘】，输出可直接绘制的矢量图元指令 `diagrams`（而不是只截取原图）。
                请严格返回如下 JSON 结构（所有字符串中的 LaTeX 反斜杠请双写）：
                {
                  "isValidMathProblem": true或false,
                  "invalidReason": "仅当 isValidMathProblem 为 false 时填写简短原因，有效题目留空字符串",
                  "title": "简短题目标题（8~18字）",
                  "problemText": "完整规范的题干文本，分小题请使用真实换行符分隔，公式使用 $...$ 包裹",
                  "subjectTag": "核心知识点，如 二次函数 / 全等三角形 / 三角形中线",
                  "questionType": "解答题 / 证明题 / 计算题 / 几何综合 / 填空题 / 选择题",
                  "difficulty": "基础 / 中档 / 拓展 / 压轴",
                  "knownConditions": ["提炼的已知条件1", "已知条件2"],
                  "targets": ["要求解或证明的目标1", "目标2"],
                  "hasFigure": true或false,
                  "figureNote": "若图片包含几何图/坐标系图/表格，简述图形几何关系与顶点位置，否则留空",
                  "diagrams": [
                    {
                      "title": "△ABC 与中线 AD 示意图",
                      "width": 320,
                      "height": 210,
                      "primitives": [
                        {"type": "polygon", "points": [[112, 34], [48, 174], [268, 174]], "color": "#0F172A"},
                        {"type": "line", "x1": 112, "y1": 34, "x2": 158, "y2": 174, "color": "#0284C7"},
                        {"type": "point", "x": 112, "y": 34, "label": "A", "color": "#0F172A"},
                        {"type": "point", "x": 48, "y": 174, "label": "B", "color": "#0F172A"},
                        {"type": "point", "x": 268, "y": 174, "label": "C", "color": "#0F172A"},
                        {"type": "point", "x": 158, "y": 174, "label": "D", "color": "#0284C7"}
                      ]
                    }
                  ],
                  "figureBoxes": [
                    {"title": "原题配图参考", "x": 0.10, "y": 0.42, "w": 0.76, "h": 0.48}
                  ]
                }
                重要要求：
                1. 当图片包含任何几何图形、函数坐标系、数轴、立体图形或统计图时，hasFigure 必须为 true，且**必须在 diagrams 中完整给出 320×210 画布上的矢量重绘指令**（支持图元：polygon、line、polyline、circle、arc、rightAngle、arrow、point、text；画布有效区 x∈[28,292], y∈[24,186]，严禁超出边界截断图形，必须完整标注所有顶点字母与关键角度/直角/辅助虚线）；
                2. figureBoxes 仅作可选原图对照参考（如有图可附带，四周留 3% 边距）；
                3. 纯文字无配图题目，请返回 "hasFigure": false, "diagrams": [], "figureBoxes": []；
                4. 题干中分段落或「注：」请使用合法 JSON 换行，不要在文本里输出字面反斜杠 n。
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
        String problemText = req != null && req.getProblemText() != null ? req.getProblemText().trim() : "";
        if (problemText.isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请先拍照或手写识别一道完整的数学题目，再使用思路、诊断或解题");
        }
        AiConfigService.RuntimeAiConfig cfg = requireReadyConfig();
        List<String> images = new ArrayList<>();
        if (req != null && req.getProblemImageBase64() != null && !req.getProblemImageBase64().isBlank()) {
            images.add(normalizeImageDataUri(req.getProblemImageBase64(), null));
        }
        if (req != null && req.getBoardImageBase64() != null && !req.getBoardImageBase64().isBlank()) {
            images.add(normalizeImageDataUri(req.getBoardImageBase64(), "image/png"));
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
            prompt.append("任务：请为下方数学题直接生成【纯粹最终答案】，并将精简【解题思路】放在步骤字段中以便展示在答案下方。\n");
            prompt.append("硬性要求：\n");
            prompt.append("1. finalAnswer 必须是纯粹、直接、精准的最终答案（支持 $...$，多小问按 (1) ...\\n(2) ... 分行，不要加“答：”“综上所述”等客套前后缀）；\n");
            prompt.append("2. headline 填 \"答案\"，summary 留空字符串 \"\"，pitfalls 返回 []，studentDiagnosis.status 设为 \"NONE\"；\n");
            prompt.append("3. steps 放 2~4 条简洁精炼的解题思路与关键算式推导，供学生查看答案后在下方展开核对；\n");
            prompt.append("4. 非必要不画图，diagrams 优先返回 []。\n");
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
                    .figureBoxes(List.of())
                    .diagrams(List.of())
                    .modelUsed(modelUsed)
                    .latencyMs(latencyMs)
                    .build();
        }

        if (root.has("isValidMathProblem") && !root.path("isValidMathProblem").asBoolean(true)) {
            String reason = textOf(root, "invalidReason", "未检测到完整合理的数学题目，请重新拍照或工整书写后再识别");
            throw new BizException(ErrorCode.BAD_REQUEST, reason);
        }

        String problemText = normalizeDisplayNewlines(textOf(root, "problemText", ""));
        if (problemText.isBlank()) {
            problemText = normalizeDisplayNewlines(textOf(root, "stem", cleanRawFallback(rawContent)));
        }
        if (problemText.replaceAll("\\s+", "").length() < 3) {
            throw new BizException(ErrorCode.BAD_REQUEST, "识别到的题目内容不完整，请写清已知条件与求解目标后再试");
        }
        List<String> knownConditions = readStringList(root.path("knownConditions")).stream()
                .map(AiBoardService::normalizeDisplayNewlines)
                .toList();
        List<String> targets = readStringList(root.path("targets")).stream()
                .map(AiBoardService::normalizeDisplayNewlines)
                .toList();
        String figureNote = normalizeDisplayNewlines(textOf(root, "figureNote", ""));
        List<AiBoardVO.FigureBoxVO> figureBoxes = readFigureBoxes(root.path("figureBoxes"));
        List<AiBoardVO.BoardDiagramVO> diagrams = new ArrayList<>(readDiagrams(root.path("diagrams")));
        boolean hasFigure = root.path("hasFigure").asBoolean(false)
                || !figureBoxes.isEmpty()
                || !diagrams.isEmpty();

        if (diagrams.isEmpty()) {
            AiBoardVO.BoardDiagramVO synthesized = synthesizeFallbackDiagramIfNeeded(
                    problemText, figureNote, knownConditions, hasFigure
            );
            if (synthesized != null) {
                diagrams.add(synthesized);
                hasFigure = true;
            }
        }

        return AiBoardVO.RecognizeVO.builder()
                .title(textOf(root, "title", "数学解答题"))
                .problemText(problemText)
                .subjectTag(textOf(root, "subjectTag", "数学"))
                .questionType(textOf(root, "questionType", "解答题"))
                .difficulty(textOf(root, "difficulty", "中档"))
                .knownConditions(knownConditions)
                .targets(targets)
                .hasFigure(hasFigure)
                .figureNote(figureNote)
                .figureBoxes(figureBoxes)
                .diagrams(diagrams)
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

        // 优先修复单反斜杠 LaTeX（如 \frac/\tfrac/\times/\right/\beta），避免 Jackson 将 \f/\t/\r/\b 静默解析为控制字符
        String repaired = repairLatexBackslashesInJson(candidate);
        try {
            JsonNode node = objectMapper.readTree(repaired);
            if (node != null && node.isObject()) {
                return node;
            }
        } catch (Exception ignored) {
        }

        try {
            JsonNode node = objectMapper.readTree(candidate);
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

    private List<AiBoardVO.FigureBoxVO> readFigureBoxes(JsonNode node) {
        if (node == null || !node.isArray()) return List.of();
        List<AiBoardVO.FigureBoxVO> out = new ArrayList<>();
        for (JsonNode b : node) {
            if (!b.isObject()) continue;
            Double rx = nullableDouble(b, "x");
            Double ry = nullableDouble(b, "y");
            Double rw = nullableDouble(b, "w");
            Double rh = nullableDouble(b, "h");
            if (rx == null || ry == null || rw == null || rh == null) {
                JsonNode bbox = b.path("bbox");
                if (bbox.isArray() && bbox.size() >= 4) {
                    rx = bbox.get(0).asDouble();
                    ry = bbox.get(1).asDouble();
                    rw = bbox.get(2).asDouble() - rx;
                    rh = bbox.get(3).asDouble() - ry;
                }
            }
            if (rx == null || ry == null || rw == null || rh == null) continue;
            // 兼容 0~100 百分比或 0~1000 归一化坐标
            double maxVal = Math.max(Math.max(Math.abs(rx), Math.abs(ry)), Math.max(Math.abs(rw), Math.abs(rh)));
            double scale = 1.0;
            if (maxVal > 1.05 && maxVal <= 100.5) {
                scale = 100.0;
            } else if (maxVal > 100.5 && maxVal <= 1005.0) {
                scale = 1000.0;
            }
            double x = Math.max(0.0, Math.min(0.96, rx / scale));
            double y = Math.max(0.0, Math.min(0.96, ry / scale));
            double w = Math.max(0.0, Math.min(1.0 - x, rw / scale));
            double h = Math.max(0.0, Math.min(1.0 - y, rh / scale));
            if (w < 0.04 || h < 0.04) continue;
            out.add(AiBoardVO.FigureBoxVO.builder()
                    .title(textOf(b, "title", "原题配图"))
                    .x(x)
                    .y(y)
                    .w(w)
                    .h(h)
                    .build());
        }
        return out;
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
                            .startAngle(nullableDouble(p, "startAngle"))
                            .sweepAngle(nullableDouble(p, "sweepAngle"))
                            .vx(nullableDouble(p, "vx"))
                            .vy(nullableDouble(p, "vy"))
                            .ax(nullableDouble(p, "ax"))
                            .ay(nullableDouble(p, "ay"))
                            .bx(nullableDouble(p, "bx"))
                            .by(nullableDouble(p, "by"))
                            .size(nullableDouble(p, "size"))
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

    private static final Pattern LITERAL_NEWLINE_PATTERN = Pattern.compile("\\\\n(?![A-Za-z])");
    private static final Pattern TRIANGLE_NAME_PATTERN = Pattern.compile("(?:Rt)?(?:△|Δ|\\\\triangle)\\s*([A-Z])([A-Z])([A-Z])");
    private static final Pattern QUAD_NAME_PATTERN = Pattern.compile("(?:平行四边形|矩形|长方形|菱形|正方形|梯形|四边形)\\s*([A-Z])([A-Z])([A-Z])([A-Z])");
    private static final Pattern CEVIAN_PATTERN = Pattern.compile("([A-Z])([A-Z])\\s*(?:为|是)[^，。,.；;\\n]{0,12}(?:中线|高线?|角平分线|平分线)");
    private static final Pattern MIDPOINT_PATTERN = Pattern.compile("([A-Z])\\s*(?:为|是)[^，。,.；;\\n]{0,8}中点");
    private static final Pattern RIGHT_ANGLE_VERTEX_PATTERN = Pattern.compile("(?:∠|\\\\angle)\\s*([A-Z])\\s*=\\s*90");

    /**
     * 将大模型偶发双转义输出的字面 "\n"（后接非英文字母，避免误伤 \neq/\notin/\nabla）还原为真实换行符。
     */
    static String normalizeDisplayNewlines(String raw) {
        if (raw == null || raw.isEmpty()) return "";
        String cleaned = LITERAL_NEWLINE_PATTERN.matcher(raw).replaceAll("\n");
        return cleaned.replace("\\r\\n", "\n").trim();
    }

    /**
     * 当视觉模型识别出含配图题目但未返回 diagrams 矢量指令时，根据题干与图形描述合成清晰规范的矢量示意图，
     * 避免客户端只能退化为裁剪模糊/截断的原图截图。
     */
    AiBoardVO.BoardDiagramVO synthesizeFallbackDiagramIfNeeded(
            String problemText,
            String figureNote,
            List<String> knownConditions,
            boolean hasFigure
    ) {
        String combined = (problemText == null ? "" : problemText) + " "
                + (figureNote == null ? "" : figureNote) + " "
                + (knownConditions == null ? "" : String.join(" ", knownConditions));
        boolean mentionsVisual = hasFigure
                || combined.contains("如图")
                || combined.contains("如图所示")
                || combined.contains("△")
                || combined.contains("\\triangle")
                || combined.contains("⊙")
                || combined.contains("抛物线")
                || combined.contains("坐标系");
        if (!mentionsVisual) {
            return null;
        }

        // 1. 三角形（含中线 / 高 / 角平分线 / 直角三角形）
        Matcher triM = TRIANGLE_NAME_PATTERN.matcher(combined);
        if (triM.find() || combined.contains("三角形")) {
            String vA = triM.hitEnd() || triM.groupCount() < 3 ? "A" : triM.group(1);
            String vB = triM.hitEnd() || triM.groupCount() < 3 ? "B" : triM.group(2);
            String vC = triM.hitEnd() || triM.groupCount() < 3 ? "C" : triM.group(3);
            if (!triM.matches()) {
                Matcher reTri = TRIANGLE_NAME_PATTERN.matcher(combined);
                if (reTri.find()) {
                    vA = reTri.group(1);
                    vB = reTri.group(2);
                    vC = reTri.group(3);
                } else {
                    vA = "A";
                    vB = "B";
                    vC = "C";
                }
            }

            boolean isRight = combined.contains("Rt△") || combined.contains("直角三角形") || combined.contains("90°") || combined.contains("90^");
            boolean isMedian = combined.contains("中线") || combined.contains("中点");
            boolean isAltitude = combined.contains("高线") || combined.contains("高，") || combined.contains("高,") || combined.contains("⊥");
            boolean isBisector = combined.contains("角平分线");

            if (isRight && !isMedian) {
                String rightVertex = vC;
                Matcher rvM = RIGHT_ANGLE_VERTEX_PATTERN.matcher(combined);
                if (rvM.find()) {
                    rightVertex = rvM.group(1);
                }
                // 直角置于左下角，便于直观展示直角符号与三边
                String topV = rightVertex.equals(vA) ? vB : vA;
                String rightV = rightVertex.equals(vC) ? vB : vC;
                if (topV.equals(rightV)) {
                    topV = vA;
                    rightV = vB;
                }
                List<AiBoardVO.DiagramPrimitiveVO> prims = new ArrayList<>();
                prims.add(polygonPrim(List.of(List.of(68.0, 40.0), List.of(68.0, 174.0), List.of(258.0, 174.0)), "#0F172A", "#E0F2FE"));
                prims.add(rightAnglePrim(68, 174, 258, 174, 68, 40, 13, "#DC2626"));
                prims.add(pointPrim(68, 40, topV, "#0F172A"));
                prims.add(pointPrim(68, 174, rightVertex, "#DC2626"));
                prims.add(pointPrim(258, 174, rightV, "#0F172A"));
                return AiBoardVO.BoardDiagramVO.builder()
                        .title("Rt△" + vA + vB + vC + " 示意图")
                        .width(320.0)
                        .height(210.0)
                        .primitives(prims)
                        .build();
            }

            // 一般三角形 / 中线 / 高 / 角平分线
            double ax = 112, ay = 34;
            double bx = 48, by = 174;
            double cx = 268, cy = 174;
            List<AiBoardVO.DiagramPrimitiveVO> prims = new ArrayList<>();
            prims.add(polygonPrim(List.of(List.of(ax, ay), List.of(bx, by), List.of(cx, cy)), "#0F172A", "#F8FAFC"));

            String extraPt = null;
            Matcher cevM = CEVIAN_PATTERN.matcher(combined);
            if (cevM.find()) {
                String p1 = cevM.group(1);
                String p2 = cevM.group(2);
                extraPt = p1.equals(vA) ? p2 : (p2.equals(vA) ? p1 : p2);
            } else {
                Matcher midM = MIDPOINT_PATTERN.matcher(combined);
                if (midM.find()) {
                    extraPt = midM.group(1);
                }
            }
            if (extraPt == null && (isMedian || isAltitude || isBisector)) {
                extraPt = "D";
            }

            if (extraPt != null) {
                double dx = isAltitude ? ax : (bx + cx) / 2.0;
                double dy = by;
                prims.add(linePrim(ax, ay, dx, dy, "#0284C7", false));
                if (isAltitude) {
                    prims.add(rightAnglePrim(dx, dy, cx, cy, ax, ay, 11, "#DC2626"));
                } else if (isMedian) {
                    // 等分记号（在 BD 与 DC 中点各画一条细短横截线）
                    double m1 = (bx + dx) / 2.0;
                    double m2 = (dx + cx) / 2.0;
                    prims.add(linePrim(m1, by - 5, m1, by + 5, "#0284C7", false));
                    prims.add(linePrim(m2, by - 5, m2, by + 5, "#0284C7", false));
                }
                prims.add(pointPrim(dx, dy, extraPt, "#0284C7"));
            }

            if (combined.contains("∠" + vA) || combined.contains("\\angle " + vA) || combined.contains("\\angle" + vA)) {
                prims.add(arcPrim(ax, ay, 24, 42, 74, "#EA580C"));
            }
            prims.add(pointPrim(ax, ay, vA, "#0F172A"));
            prims.add(pointPrim(bx, by, vB, "#0F172A"));
            prims.add(pointPrim(cx, cy, vC, "#0F172A"));

            String title = extraPt != null && isMedian
                    ? "△" + vA + vB + vC + " 与中线 " + vA + extraPt
                    : extraPt != null && isAltitude
                        ? "△" + vA + vB + vC + " 与高 " + vA + extraPt
                        : "△" + vA + vB + vC + " 示意图";
            return AiBoardVO.BoardDiagramVO.builder()
                    .title(title)
                    .width(320.0)
                    .height(210.0)
                    .primitives(prims)
                    .build();
        }

        // 2. 四边形（平行四边形 / 矩形 / 正方形 / 菱形 / 梯形）
        Matcher quadM = QUAD_NAME_PATTERN.matcher(combined);
        if (quadM.find() || combined.contains("平行四边形") || combined.contains("梯形") || combined.contains("矩形") || combined.contains("正方形") || combined.contains("菱形")) {
            String a = "A", b = "B", c = "C", d = "D";
            Matcher q2 = QUAD_NAME_PATTERN.matcher(combined);
            if (q2.find()) {
                a = q2.group(1);
                b = q2.group(2);
                c = q2.group(3);
                d = q2.group(4);
            }
            List<List<Double>> pts;
            String title;
            if (combined.contains("正方形")) {
                pts = List.of(List.of(95.0, 42.0), List.of(95.0, 172.0), List.of(225.0, 172.0), List.of(225.0, 42.0));
                title = "正方形 " + a + b + c + d;
            } else if (combined.contains("矩形") || combined.contains("长方形")) {
                pts = List.of(List.of(65.0, 48.0), List.of(65.0, 168.0), List.of(255.0, 168.0), List.of(255.0, 48.0));
                title = "矩形 " + a + b + c + d;
            } else if (combined.contains("菱形")) {
                pts = List.of(List.of(160.0, 34.0), List.of(78.0, 108.0), List.of(160.0, 182.0), List.of(242.0, 108.0));
                title = "菱形 " + a + b + c + d;
            } else if (combined.contains("梯形")) {
                pts = List.of(List.of(100.0, 48.0), List.of(52.0, 172.0), List.of(268.0, 172.0), List.of(220.0, 48.0));
                title = "梯形 " + a + b + c + d;
            } else {
                pts = List.of(List.of(96.0, 46.0), List.of(54.0, 170.0), List.of(224.0, 170.0), List.of(266.0, 46.0));
                title = "平行四边形 " + a + b + c + d;
            }
            List<AiBoardVO.DiagramPrimitiveVO> prims = new ArrayList<>();
            prims.add(polygonPrim(pts, "#0F172A", "#F8FAFC"));
            if (combined.contains("对角线")) {
                prims.add(linePrim(pts.get(0).get(0), pts.get(0).get(1), pts.get(2).get(0), pts.get(2).get(1), "#0284C7", true));
                prims.add(linePrim(pts.get(1).get(0), pts.get(1).get(1), pts.get(3).get(0), pts.get(3).get(1), "#0284C7", true));
            }
            prims.add(pointPrim(pts.get(0).get(0), pts.get(0).get(1), a, "#0F172A"));
            prims.add(pointPrim(pts.get(1).get(0), pts.get(1).get(1), b, "#0F172A"));
            prims.add(pointPrim(pts.get(2).get(0), pts.get(2).get(1), c, "#0F172A"));
            prims.add(pointPrim(pts.get(3).get(0), pts.get(3).get(1), d, "#0F172A"));
            return AiBoardVO.BoardDiagramVO.builder()
                    .title(title)
                    .width(320.0)
                    .height(210.0)
                    .primitives(prims)
                    .build();
        }

        // 3. 圆
        if (combined.contains("⊙") || combined.contains("圆心") || combined.contains("切线") || combined.contains("圆周角") || combined.contains("半径")) {
            List<AiBoardVO.DiagramPrimitiveVO> prims = new ArrayList<>();
            prims.add(AiBoardVO.DiagramPrimitiveVO.builder()
                    .type("circle").cx(160.0).cy(108.0).r(68.0).color("#0F172A").fillColor("#F0F9FF").dashed(false).build());
            prims.add(pointPrim(160, 108, "O", "#DC2626"));
            prims.add(linePrim(160, 108, 228, 108, "#0284C7", false));
            prims.add(pointPrim(228, 108, "A", "#0F172A"));
            if (combined.contains("切线")) {
                prims.add(linePrim(228, 36, 228, 180, "#EA580C", false));
                prims.add(rightAnglePrim(228, 108, 160, 108, 228, 36, 10, "#DC2626"));
            }
            return AiBoardVO.BoardDiagramVO.builder()
                    .title("圆 ⊙O 示意图")
                    .width(320.0)
                    .height(210.0)
                    .primitives(prims)
                    .build();
        }

        // 4. 坐标系与函数
        if (combined.contains("抛物线") || combined.contains("二次函数") || combined.contains("一次函数") || combined.contains("反比例函数") || combined.contains("坐标系")) {
            List<AiBoardVO.DiagramPrimitiveVO> prims = new ArrayList<>();
            prims.add(arrowPrim(28, 148, 294, 148, "#475569"));
            prims.add(arrowPrim(160, 194, 160, 20, "#475569"));
            prims.add(textPrim(286, 154, "x", "#475569"));
            prims.add(textPrim(166, 18, "y", "#475569"));
            prims.add(textPrim(146, 154, "O", "#475569"));
            if (combined.contains("抛物线") || combined.contains("二次函数")) {
                List<List<Double>> curve = new ArrayList<>();
                for (int i = -10; i <= 10; i++) {
                    double x = 160.0 + i * 9.0;
                    double y = 164.0 - (i * i) * 1.2;
                    curve.add(List.of(x, y));
                }
                prims.add(AiBoardVO.DiagramPrimitiveVO.builder()
                        .type("polyline").points(curve).color("#0284C7").dashed(false).build());
            } else {
                prims.add(linePrim(64, 184, 254, 46, "#0284C7", false));
            }
            return AiBoardVO.BoardDiagramVO.builder()
                    .title("函数坐标系示意图")
                    .width(320.0)
                    .height(210.0)
                    .primitives(prims)
                    .build();
        }

        return null;
    }

    private AiBoardVO.DiagramPrimitiveVO polygonPrim(List<List<Double>> pts, String color, String fillColor) {
        return AiBoardVO.DiagramPrimitiveVO.builder()
                .type("polygon").points(pts).color(color).fillColor(fillColor).dashed(false).build();
    }

    private AiBoardVO.DiagramPrimitiveVO linePrim(double x1, double y1, double x2, double y2, String color, boolean dashed) {
        return AiBoardVO.DiagramPrimitiveVO.builder()
                .type("line").x1(x1).y1(y1).x2(x2).y2(y2).color(color).dashed(dashed).build();
    }

    private AiBoardVO.DiagramPrimitiveVO arrowPrim(double x1, double y1, double x2, double y2, String color) {
        return AiBoardVO.DiagramPrimitiveVO.builder()
                .type("arrow").x1(x1).y1(y1).x2(x2).y2(y2).color(color).dashed(false).build();
    }

    private AiBoardVO.DiagramPrimitiveVO pointPrim(double x, double y, String label, String color) {
        return AiBoardVO.DiagramPrimitiveVO.builder()
                .type("point").x(x).y(y).label(label).color(color).dashed(false).build();
    }

    private AiBoardVO.DiagramPrimitiveVO textPrim(double x, double y, String text, String color) {
        return AiBoardVO.DiagramPrimitiveVO.builder()
                .type("text").x(x).y(y).text(text).color(color).dashed(false).build();
    }

    private AiBoardVO.DiagramPrimitiveVO arcPrim(double cx, double cy, double r, double startAngle, double sweepAngle, String color) {
        return AiBoardVO.DiagramPrimitiveVO.builder()
                .type("arc").cx(cx).cy(cy).r(r).startAngle(startAngle).sweepAngle(sweepAngle).color(color).dashed(false).build();
    }

    private AiBoardVO.DiagramPrimitiveVO rightAnglePrim(double vx, double vy, double ax, double ay, double bx, double by, double size, String color) {
        return AiBoardVO.DiagramPrimitiveVO.builder()
                .type("rightAngle").vx(vx).vy(vy).ax(ax).ay(ay).bx(bx).by(by).size(size).color(color).dashed(false).build();
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
