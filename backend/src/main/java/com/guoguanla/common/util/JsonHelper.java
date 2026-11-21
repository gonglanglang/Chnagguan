package com.guoguanla.common.util;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.List;
import java.util.Map;

/**
 * 兼容 MySQL 8 与 H2 JSON 列返回格式的解析工具（H2 2.x 会把 JSON 文本再包一层字符串引号）
 */
public final class JsonHelper {

    private JsonHelper() {
    }

    public static JsonNode readTree(ObjectMapper mapper, String raw) throws Exception {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        JsonNode node = mapper.readTree(raw);
        if (node != null && node.isTextual()) {
            String inner = node.asText();
            if (inner != null && (inner.startsWith("{") || inner.startsWith("["))) {
                return mapper.readTree(inner);
            }
        }
        return node;
    }

    public static <T> T readValue(ObjectMapper mapper, String raw, TypeReference<T> ref) throws Exception {
        JsonNode node = readTree(mapper, raw);
        if (node == null) {
            return null;
        }
        return mapper.convertValue(node, ref);
    }

    public static List<String> readStringList(ObjectMapper mapper, String raw) {
        if (raw == null || raw.isBlank()) {
            return List.of();
        }
        try {
            List<String> res = readValue(mapper, raw, new TypeReference<>() {});
            return res == null ? List.of() : res;
        } catch (Exception e) {
            return List.of();
        }
    }

    public static Map<String, Object> readMap(ObjectMapper mapper, String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return readValue(mapper, raw, new TypeReference<>() {});
        } catch (Exception e) {
            return null;
        }
    }
}
