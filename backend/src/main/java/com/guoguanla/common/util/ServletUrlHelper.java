package com.guoguanla.common.util;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

public final class ServletUrlHelper {

    private ServletUrlHelper() {}

    public static String resolveBaseOrigin(HttpServletRequest request) {
        if (request == null) {
            return "";
        }
        try {
            return ServletUriComponentsBuilder.fromRequestUri(request)
                    .replacePath(null)
                    .replaceQuery(null)
                    .build()
                    .toUriString();
        } catch (Exception e) {
            return "";
        }
    }
}
