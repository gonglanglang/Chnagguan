package com.guoguanla.module.engine;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Map;

/**
 * 纯 Java 受控数学表达式求值器，用于后台配置的 PARAM_TEMPLATE 动态题型（无代码注入风险）。
 * 支持：+ - * / % ^ 括号、变量替换、abs()、sqrt()、min()、max()、frac(n,d)。
 */
public class SafeParamEvaluator {

    private final String expr;
    private final Map<String, Number> vars;
    private int pos = -1;
    private int ch;

    private SafeParamEvaluator(String expr, Map<String, Number> vars) {
        this.expr = expr;
        this.vars = vars;
        nextChar();
    }

    public static String evalString(String expr, Map<String, Number> vars) {
        String trimmed = expr == null ? "" : expr.trim();
        if (trimmed.isEmpty()) {
            return "";
        }
        // 支持 frac(a, b) 返回约分分数字符串
        if (trimmed.startsWith("frac(") && trimmed.endsWith(")")) {
            String inner = trimmed.substring(5, trimmed.length() - 1);
            int commaIdx = findTopLevelComma(inner);
            if (commaIdx > 0) {
                long n = Math.round(evalDouble(inner.substring(0, commaIdx), vars));
                long d = Math.round(evalDouble(inner.substring(commaIdx + 1), vars));
                return frac(n, d);
            }
        }
        double val = evalDouble(trimmed, vars);
        return formatNumber(val);
    }

    public static double evalDouble(String expr, Map<String, Number> vars) {
        SafeParamEvaluator parser = new SafeParamEvaluator(expr, vars);
        double x = parser.parseExpression();
        if (parser.pos < parser.expr.length()) {
            throw new IllegalArgumentException("Unexpected token at position " + parser.pos + " in: " + expr);
        }
        return x;
    }

    public static String formatNumber(double val) {
        if (Double.isNaN(val) || Double.isInfinite(val)) {
            throw new IllegalArgumentException("Invalid numeric result");
        }
        BigDecimal bd = BigDecimal.valueOf(val).setScale(6, RoundingMode.HALF_UP).stripTrailingZeros();
        if (bd.compareTo(BigDecimal.ZERO) == 0) {
            return "0";
        }
        return bd.toPlainString();
    }

    public static String frac(long n, long d) {
        if (d == 0) {
            throw new IllegalArgumentException("Division by zero in frac()");
        }
        if (d < 0) {
            n = -n;
            d = -d;
        }
        long a = Math.abs(n);
        long b = d;
        while (b != 0) {
            long t = b;
            b = a % b;
            a = t;
        }
        long nn = n / a;
        long dd = d / a;
        if (dd == 1) {
            return String.valueOf(nn);
        }
        return nn + "/" + dd;
    }

    private static int findTopLevelComma(String s) {
        int depth = 0;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '(') depth++;
            else if (c == ')') depth--;
            else if (c == ',' && depth == 0) return i;
        }
        return -1;
    }

    private void nextChar() {
        ch = (++pos < expr.length()) ? expr.charAt(pos) : -1;
    }

    private boolean eat(int charToEat) {
        while (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') nextChar();
        if (ch == charToEat) {
            nextChar();
            return true;
        }
        return false;
    }

    private double parseExpression() {
        double x = parseTerm();
        for (;;) {
            if (eat('+')) x += parseTerm();
            else if (eat('-')) x -= parseTerm();
            else return x;
        }
    }

    private double parseTerm() {
        double x = parseFactor();
        for (;;) {
            if (eat('*')) x *= parseFactor();
            else if (eat('/')) {
                double d = parseFactor();
                if (d == 0) throw new IllegalArgumentException("Division by zero");
                x /= d;
            } else if (eat('%')) {
                double d = parseFactor();
                if (d == 0) throw new IllegalArgumentException("Modulo by zero");
                x %= d;
            } else return x;
        }
    }

    private double parseFactor() {
        if (eat('+')) return parseFactor();
        if (eat('-')) return -parseFactor();
        double x;
        int startPos = this.pos;
        if (eat('(')) {
            x = parseExpression();
            if (!eat(')')) {
                throw new IllegalArgumentException("Missing ')'");
            }
        } else if ((ch >= '0' && ch <= '9') || ch == '.') {
            while ((ch >= '0' && ch <= '9') || ch == '.') nextChar();
            x = Double.parseDouble(expr.substring(startPos, this.pos));
        } else if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_') {
            while ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '_') {
                nextChar();
            }
            String name = expr.substring(startPos, this.pos);
            if (eat('(')) {
                double arg1 = parseExpression();
                if ("abs".equals(name)) {
                    if (!eat(')')) throw new IllegalArgumentException("Missing ')' in abs");
                    x = Math.abs(arg1);
                } else if ("sqrt".equals(name)) {
                    if (!eat(')')) throw new IllegalArgumentException("Missing ')' in sqrt");
                    x = Math.sqrt(arg1);
                } else if ("min".equals(name)) {
                    if (!eat(',')) throw new IllegalArgumentException("Expected ',' in min");
                    double arg2 = parseExpression();
                    if (!eat(')')) throw new IllegalArgumentException("Missing ')' in min");
                    x = Math.min(arg1, arg2);
                } else if ("max".equals(name)) {
                    if (!eat(',')) throw new IllegalArgumentException("Expected ',' in max");
                    double arg2 = parseExpression();
                    if (!eat(')')) throw new IllegalArgumentException("Missing ')' in max");
                    x = Math.max(arg1, arg2);
                } else {
                    throw new IllegalArgumentException("Unknown function: " + name);
                }
            } else {
                Number v = vars.get(name);
                if (v == null) {
                    throw new IllegalArgumentException("Unknown variable: " + name);
                }
                x = v.doubleValue();
            }
        } else {
            throw new IllegalArgumentException("Unexpected character: " + (char) ch);
        }
        if (eat('^')) x = Math.pow(x, parseFactor());
        return x;
    }
}
