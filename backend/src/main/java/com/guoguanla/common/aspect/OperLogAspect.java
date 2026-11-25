package com.guoguanla.common.aspect;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.security.StpAdminUtil;
import com.guoguanla.module.system.entity.SysAdmin;
import com.guoguanla.module.system.entity.SysOperLog;
import com.guoguanla.module.system.mapper.SysAdminMapper;
import com.guoguanla.module.system.mapper.SysOperLogMapper;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@Aspect
@Component
@RequiredArgsConstructor
public class OperLogAspect {

    private final SysOperLogMapper operLogMapper;
    private final SysAdminMapper adminMapper;
    private final ObjectMapper objectMapper;

    @Around("@annotation(operLog)")
    public Object around(ProceedingJoinPoint joinPoint, OperLog operLog) throws Throwable {
        Object result = joinPoint.proceed();
        try {
            saveLog(joinPoint, operLog);
        } catch (Exception e) {
            log.warn("Failed to record operation log: {}", e.getMessage());
        }
        return result;
    }

    private void saveLog(ProceedingJoinPoint joinPoint, OperLog operLog) {
        if (!StpAdminUtil.isLogin()) {
            return;
        }
        Long adminId = StpAdminUtil.getLoginIdAsLong();
        SysAdmin admin = adminMapper.selectById(adminId);
        String adminName = admin != null ? admin.getRealName() : "Admin#" + adminId;

        List<Object> safeArgs = new ArrayList<>();
        for (Object arg : joinPoint.getArgs()) {
            if (arg == null || arg instanceof ServletRequest || arg instanceof ServletResponse || arg instanceof MultipartFile) {
                continue;
            }
            safeArgs.add(arg);
        }

        String detailJson = "{}";
        try {
            detailJson = objectMapper.writeValueAsString(Map.of("args", safeArgs));
            detailJson = detailJson.replaceAll("(?i)(\"(?:apiKey|password|secret|accessKeySecret|token)\"\\s*:\\s*\")([^\"]*)(\")", "$1***$3");
            if (detailJson.length() > 4000) {
                detailJson = objectMapper.writeValueAsString(Map.of("truncated", true, "summary", operLog.action()));
            }
        } catch (Exception ignored) {
        }

        String ip = "";
        ServletRequestAttributes attrs = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attrs != null) {
            HttpServletRequest req = attrs.getRequest();
            ip = req.getRemoteAddr();
        }

        SysOperLog entry = new SysOperLog();
        entry.setAdminId(adminId);
        entry.setAdminName(adminName);
        entry.setModule(operLog.module());
        entry.setAction(operLog.action());
        entry.setDetailJson(detailJson);
        entry.setIp(ip);
        operLogMapper.insert(entry);
    }
}
