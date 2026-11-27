package com.guoguanla.common.config;

import cn.dev33.satoken.interceptor.SaInterceptor;
import cn.dev33.satoken.router.SaHttpMethod;
import cn.dev33.satoken.router.SaRouter;
import cn.dev33.satoken.stp.StpInterface;
import com.guoguanla.common.security.StpAdminUtil;
import com.guoguanla.common.security.StpAppUtil;
import com.guoguanla.module.dashboard.StudentOnlineTrackerService;
import com.guoguanla.module.system.entity.SysAdmin;
import com.guoguanla.module.system.mapper.SysAdminMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.List;

@Configuration
@RequiredArgsConstructor
public class SaTokenConfig implements WebMvcConfigurer {

    private final SysAdminMapper sysAdminMapper;
    private final StudentOnlineTrackerService onlineTracker;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new SaInterceptor(handle -> {
                    SaRouter.match(SaHttpMethod.OPTIONS).stop();
                    SaRouter.match("/api/admin/**")
                            .notMatch("/api/admin/auth/login", "/api/admin/auth/refresh-token")
                            .check(r -> StpAdminUtil.checkLogin());
                    SaRouter.match("/api/app/user/**", "/api/app/wrong-questions/**", "/api/app/auth/logout")
                            .check(r -> StpAppUtil.checkLogin());
                }))
                .addPathPatterns("/api/**");

        // 自动追踪已登录学生在线活跃度（不含退出接口）
        registry.addInterceptor(new HandlerInterceptor() {
                    @Override
                    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
                        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
                            return true;
                        }
                        String uri = request.getRequestURI();
                        if (uri != null && uri.endsWith("/auth/logout")) {
                            return true;
                        }
                        Long userId = StpAppUtil.getLoginIdOrNull();
                        if (userId != null) {
                            String platform = request.getHeader("X-Client-Platform");
                            onlineTracker.touchUser(userId, uri, platform);
                        }
                        return true;
                    }
                })
                .addPathPatterns("/api/app/**");
    }

    @Bean
    public StpInterface stpInterface() {
        return new StpInterface() {
            @Override
            public List<String> getPermissionList(Object loginId, String loginType) {
                if (!StpAdminUtil.TYPE.equals(loginType)) {
                    return List.of();
                }
                SysAdmin admin = sysAdminMapper.selectById(Long.valueOf(String.valueOf(loginId)));
                if (admin == null || admin.getStatus() == 0) {
                    return List.of();
                }
                if ("SUPER_ADMIN".equals(admin.getRoleCode())) {
                    return List.of("*:*:*");
                }
                return List.of("bank:view", "bank:edit", "user:view");
            }

            @Override
            public List<String> getRoleList(Object loginId, String loginType) {
                if (!StpAdminUtil.TYPE.equals(loginType)) {
                    return List.of();
                }
                SysAdmin admin = sysAdminMapper.selectById(Long.valueOf(String.valueOf(loginId)));
                if (admin == null || admin.getStatus() == 0) {
                    return List.of();
                }
                return List.of(admin.getRoleCode());
            }
        };
    }
}
