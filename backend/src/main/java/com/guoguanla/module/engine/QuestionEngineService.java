package com.guoguanla.module.engine;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.util.JsonHelper;
import com.guoguanla.module.bank.entity.EduQuestion;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.mozilla.javascript.*;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.ThreadLocalRandom;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 混合出题引擎：同时支持静态题、原版 JS 生成器表达式（沙箱 Rhino 执行）与后台参数化 JSON 模板（纯 Java 表达式解析）。
 * 兼容选择题与解答题。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class QuestionEngineService {

    /**
     * 禁止匹配嵌套花括号，使 LaTeX 如 \frac{{{a}}}{{{b}}} 只替换最内层的 {{a}} 与 {{b}}。
     */
    private static final Pattern PLACEHOLDER_PATTERN = Pattern.compile("\\{\\{([^{}]+)\\}\\}");

    private static final String HELPER_JS = """
            function R(a, b) { return Math.floor(Math.random() * (b - a + 1)) + a; }
            function sh(arr) {
              var a = arr.slice();
              for (var i = a.length - 1; i > 0; i--) {
                var j = Math.floor(Math.random() * (i + 1));
                var tmp = a[i]; a[i] = a[j]; a[j] = tmp;
              }
              return a;
            }
            function mkg(q, ans, wrongs) {
              var seen = {}; seen[String(ans)] = true;
              var d = [];
              for (var k = 0; k < wrongs.length; k++) {
                var w = String(wrongs[k]);
                if (!seen[w]) { seen[w] = true; d.push(w); }
              }
              var i = 0;
              var num = parseFloat(ans);
              if (isFinite(num) && String(num) === String(ans).trim()) {
                var cand = [num + 1, num - 1, num + 2, num - 2];
                while (d.length < 3) {
                  var v = String(cand[i++ % 4]);
                  if (!seen[v]) { seen[v] = true; d.push(v); }
                }
              } else {
                var suf = ['+1', '−1', '×2', '½'];
                while (d.length < 3) {
                  var v2 = String(ans) + suf[i++ % 4];
                  if (!seen[v2]) { seen[v2] = true; d.push(v2); }
                }
              }
              var merged = [String(ans)].concat(d.slice(0, 3));
              var o = sh(merged);
              return { q: String(q), o: o, a: o.indexOf(String(ans)) };
            }
            function frac(n, d) {
              var a = n, b = d;
              while (b) { var t = b; b = a % b; a = t; }
              if (a === d) return '1';
              if (a === 1) return String(n) + '/' + String(d);
              return String(n / a) + '/' + String(d / a);
            }
            """;

    private static final ContextFactory SANDBOX_FACTORY = new ContextFactory() {
        @Override
        protected Context makeContext() {
            Context cx = super.makeContext();
            cx.setLanguageVersion(Context.VERSION_ES6);
            cx.setOptimizationLevel(-1);
            cx.setInstructionObserverThreshold(20_000);
            cx.setClassShutter(fullClassName -> false);
            return cx;
        }

        @Override
        protected void observeInstructionCount(Context cx, int instructionCount) {
            throw new IllegalStateException("Dynamic question script exceeded instruction limit");
        }
    };

    private final ObjectMapper objectMapper;

    public List<GeneratedQuestion> previewGenerate(EduQuestion question, int count) {
        int safeCount = Math.max(1, Math.min(count, 10));
        List<GeneratedQuestion> list = new ArrayList<>(safeCount);
        for (int i = 0; i < safeCount; i++) {
            list.add(generateOne(question));
        }
        return list;
    }

    public GeneratedQuestion generateOne(EduQuestion question) {
        String format = normalizeFormat(question.getQuestionFormat());
        Map<String, Object> ext = JsonHelper.readMap(objectMapper, question.getExtJson());
        if ("STATIC".equalsIgnoreCase(question.getQuestionMode())) {
            GeneratedQuestion gen = fromStatic(question, format);
            attachFigure(gen, ext, null);
            return gen;
        }
        String ruleJson = question.getTemplateRuleJson();
        if (ruleJson == null || ruleJson.isBlank()) {
            throw new BizException(ErrorCode.QUESTION_RULE_INVALID, "动态题缺少 templateRuleJson 配置");
        }
        try {
            JsonNode ruleNode = JsonHelper.readTree(objectMapper, ruleJson);
            String type = ruleNode.path("type").asText("PARAM_TEMPLATE");
            if ("PROTOTYPE_JS_EXPR".equalsIgnoreCase(type)) {
                String source = ruleNode.path("source").asText("");
                GeneratedQuestion gen = executeSandboxedJs(source, question.getAnalysis(), format);
                attachFigure(gen, ext, null);
                return gen;
            }
            if ("PARAM_TEMPLATE".equalsIgnoreCase(type)) {
                return executeParamTemplate(ruleNode, question.getAnalysis(), format, ext);
            }
            throw new BizException(ErrorCode.QUESTION_RULE_INVALID, "不支持的动态模板类型: " + type);
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Dynamic question generation error: id={}, err={}", question.getId(), e.getMessage());
            throw new BizException(ErrorCode.QUESTION_RULE_INVALID, "动态模板生成失败: " + e.getMessage());
        }
    }

    private GeneratedQuestion fromStatic(EduQuestion q, String format) {
        try {
            if ("ESSAY".equalsIgnoreCase(format)) {
                JsonNode ansNode = JsonHelper.readTree(objectMapper, q.getAnswerJson());
                String ref = ansNode != null ? ansNode.path("text").asText("") : "";
                return new GeneratedQuestion(q.getStem(), List.of(), 0, q.getAnalysis(), "ESSAY", ref);
            }
            List<String> options = q.getOptionsJson() == null || q.getOptionsJson().isBlank()
                    ? List.of()
                    : JsonHelper.readValue(objectMapper, q.getOptionsJson(), new TypeReference<>() {});
            JsonNode ansNode = JsonHelper.readTree(objectMapper, q.getAnswerJson());
            int ansIndex = ansNode != null && ansNode.has("index") ? ansNode.get("index").asInt(0) : 0;
            String ref = (ansIndex >= 0 && ansIndex < options.size()) ? options.get(ansIndex) : "";
            return new GeneratedQuestion(q.getStem(), options, ansIndex, q.getAnalysis(), format, ref);
        } catch (Exception e) {
            throw new BizException(ErrorCode.QUESTION_RULE_INVALID, "静态题目 JSON 解析失败: " + e.getMessage());
        }
    }

    private GeneratedQuestion executeSandboxedJs(String fnSource, String analysis, String format) {
        if (fnSource == null || fnSource.isBlank()) {
            throw new BizException(ErrorCode.QUESTION_RULE_INVALID, "生成器函数源码为空");
        }
        Context cx = SANDBOX_FACTORY.enterContext();
        try {
            Scriptable scope = cx.initSafeStandardObjects();
            cx.evaluateString(scope, HELPER_JS, "helpers.js", 1, null);
            Object raw = cx.evaluateString(scope, "var __genFn = (" + fnSource + "); __genFn();", "generator.js", 1, null);
            if (!(raw instanceof Scriptable obj)) {
                throw new IllegalStateException("生成器未返回对象");
            }
            String q = Context.toString(ScriptableObject.getProperty(obj, "q"));
            if ("ESSAY".equalsIgnoreCase(format)) {
                Object refObj = ScriptableObject.getProperty(obj, "ref");
                if (refObj == Scriptable.NOT_FOUND) {
                    refObj = ScriptableObject.getProperty(obj, "ans");
                }
                String ref = refObj == Scriptable.NOT_FOUND ? "" : Context.toString(refObj);
                return new GeneratedQuestion(q, List.of(), 0, analysis, "ESSAY", ref);
            }
            Object oObj = ScriptableObject.getProperty(obj, "o");
            Object aObj = ScriptableObject.getProperty(obj, "a");
            if (!(oObj instanceof NativeArray arr)) {
                throw new IllegalStateException("生成器返回值缺少 o 选项数组");
            }
            List<String> opts = new ArrayList<>();
            for (int i = 0; i < arr.size(); i++) {
                opts.add(Context.toString(arr.get(i)));
            }
            int ansIdx = ((Number) Context.jsToJava(aObj, Number.class)).intValue();
            String ref = (ansIdx >= 0 && ansIdx < opts.size()) ? opts.get(ansIdx) : "";
            return new GeneratedQuestion(q, opts, ansIdx, analysis, format, ref);
        } finally {
            Context.exit();
        }
    }

    private GeneratedQuestion executeParamTemplate(JsonNode rule, String analysis, String format, Map<String, Object> ext) {
        Map<String, Number> vars = new LinkedHashMap<>();
        JsonNode varsNode = rule.path("vars");
        if (varsNode.isObject()) {
            Iterator<Map.Entry<String, JsonNode>> fields = varsNode.fields();
            while (fields.hasNext()) {
                Map.Entry<String, JsonNode> entry = fields.next();
                JsonNode range = entry.getValue();
                if (range.isArray() && range.size() >= 2) {
                    int min = range.get(0).asInt();
                    int max = range.get(1).asInt();
                    if (min > max) {
                        int t = min;
                        min = max;
                        max = t;
                    }
                    int val = ThreadLocalRandom.current().nextInt(min, max + 1);
                    vars.put(entry.getKey(), val);
                } else if (range.isNumber()) {
                    vars.put(entry.getKey(), range.asDouble());
                }
            }
        }

        String stemTpl = rule.path("stemTpl").asText("");
        if (stemTpl.isBlank()) {
            throw new IllegalArgumentException("stemTpl 不能为空");
        }
        String stem = renderTemplate(stemTpl, vars);
        String renderedAnalysis = renderOptionalTemplate(analysis, vars);
        String ansExpr = rule.path("ansExpr").asText("");

        if ("ESSAY".equalsIgnoreCase(format)) {
            String refAns = renderEssayAnswer(ansExpr, vars);
            GeneratedQuestion gen = new GeneratedQuestion(stem, List.of(), 0, renderedAnalysis, "ESSAY", refAns);
            attachFigure(gen, ext, vars);
            return gen;
        }

        if (ansExpr.isBlank()) {
            throw new IllegalArgumentException("ansExpr 不能为空");
        }
        String ans = renderExprOrTpl(ansExpr, vars);

        List<String> candidates = new ArrayList<>();
        Set<String> seen = new LinkedHashSet<>();
        seen.add(ans);

        JsonNode wrongExprs = rule.path("wrongExprs");
        if (wrongExprs.isArray()) {
            for (JsonNode w : wrongExprs) {
                String txt = w.asText("").trim();
                if (txt.isEmpty()) continue;
                String wVal = renderExprOrTpl(txt, vars);
                if (!wVal.isBlank() && seen.add(wVal)) {
                    candidates.add(wVal);
                }
            }
        }
        // 自动兜底补齐 3 个不同干扰项（与原版 mkg 逻辑一致）
        try {
            double num = Double.parseDouble(ans);
            double[] offsets = {1, -1, 2, -2, 3, -3};
            int idx = 0;
            while (candidates.size() < 3 && idx < offsets.length) {
                String v = SafeParamEvaluator.formatNumber(num + offsets[idx++]);
                if (seen.add(v)) {
                    candidates.add(v);
                }
            }
        } catch (NumberFormatException ignored) {
            String[] suffixes = {"+1", "−1", "×2", "½"};
            int idx = 0;
            while (candidates.size() < 3 && idx < suffixes.length) {
                String v = ans + suffixes[idx++];
                if (seen.add(v)) {
                    candidates.add(v);
                }
            }
        }

        List<String> options = new ArrayList<>();
        options.add(ans);
        for (int i = 0; i < Math.min(3, candidates.size()); i++) {
            options.add(candidates.get(i));
        }
        Collections.shuffle(options);
        int ansIndex = options.indexOf(ans);
        GeneratedQuestion gen = new GeneratedQuestion(stem, options, ansIndex, renderedAnalysis, format, ans);
        attachFigure(gen, ext, vars);
        return gen;
    }

    @SuppressWarnings("unchecked")
    private void attachFigure(GeneratedQuestion gen, Map<String, Object> ext, Map<String, Number> vars) {
        if (ext == null || ext.isEmpty()) {
            return;
        }
        Object imgKeyObj = ext.get("imageKey");
        if (imgKeyObj == null || String.valueOf(imgKeyObj).isBlank()) {
            imgKeyObj = ext.get("imageUrl");
        }
        if (imgKeyObj != null && !String.valueOf(imgKeyObj).isBlank()) {
            gen.setImageKey(String.valueOf(imgKeyObj).trim());
        }
        Object diagObj = ext.get("diagram");
        if (diagObj instanceof Map<?, ?> rawMap && !rawMap.isEmpty()) {
            Map<String, Object> cloned = (Map<String, Object>) renderDiagramNode(rawMap, vars);
            gen.setDiagram(cloned);
        }
    }

    private Object renderDiagramNode(Object node, Map<String, Number> vars) {
        if (node == null) return null;
        if (node instanceof String str) {
            if (vars != null && !vars.isEmpty() && str.contains("{{")) {
                try {
                    return renderTemplate(str, vars);
                } catch (Exception ignored) {
                    return str;
                }
            }
            return str;
        }
        if (node instanceof Map<?, ?> map) {
            Map<String, Object> copy = new LinkedHashMap<>();
            for (Map.Entry<?, ?> entry : map.entrySet()) {
                copy.put(String.valueOf(entry.getKey()), renderDiagramNode(entry.getValue(), vars));
            }
            return copy;
        }
        if (node instanceof List<?> list) {
            List<Object> copy = new ArrayList<>(list.size());
            for (Object item : list) {
                copy.add(renderDiagramNode(item, vars));
            }
            return copy;
        }
        return node;
    }

    private String renderEssayAnswer(String ansExpr, Map<String, Number> vars) {
        if (ansExpr == null || ansExpr.isBlank()) {
            return "";
        }
        if (ansExpr.contains("{{")) {
            return renderTemplate(ansExpr, vars);
        }
        try {
            return SafeParamEvaluator.evalString(ansExpr, vars);
        } catch (Exception ignored) {
            return ansExpr.trim();
        }
    }

    private String renderOptionalTemplate(String input, Map<String, Number> vars) {
        if (input == null || input.isBlank()) {
            return "";
        }
        if (!input.contains("{{")) {
            return input;
        }
        return renderTemplate(input, vars);
    }

    private String renderExprOrTpl(String input, Map<String, Number> vars) {
        if (input.contains("{{")) {
            return renderTemplate(input, vars);
        }
        return SafeParamEvaluator.evalString(input, vars);
    }

    private String renderTemplate(String tpl, Map<String, Number> vars) {
        Matcher matcher = PLACEHOLDER_PATTERN.matcher(tpl);
        StringBuilder sb = new StringBuilder();
        while (matcher.find()) {
            String expr = matcher.group(1).trim();
            String replacement = SafeParamEvaluator.evalString(expr, vars);
            matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(sb);
        return sb.toString();
    }

    private String normalizeFormat(String format) {
        if (format == null || format.isBlank()) {
            return "SINGLE_CHOICE";
        }
        return format.trim().toUpperCase(Locale.ROOT);
    }
}
