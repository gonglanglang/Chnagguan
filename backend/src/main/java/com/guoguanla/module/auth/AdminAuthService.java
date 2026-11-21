package com.guoguanla.module.auth;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.security.StpAdminUtil;
import com.guoguanla.module.auth.dto.AdminLoginReq;
import com.guoguanla.module.auth.dto.AdminRefreshReq;
import com.guoguanla.module.auth.vo.AdminLoginVO;
import com.guoguanla.module.system.entity.SysAdmin;
import com.guoguanla.module.system.mapper.SysAdminMapper;
import lombok.RequiredArgsConstructor;
import org.mindrot.jbcrypt.BCrypt;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class AdminAuthService {

    private static final DateTimeFormatter EXPIRES_FMT = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss");
    /** 开发态刷新令牌映射（生产接入 Redis 时可替换为 Redis 存储） */
    private final Map<String, Long> refreshStore = new ConcurrentHashMap<>();

    private final SysAdminMapper sysAdminMapper;

    public AdminLoginVO login(AdminLoginReq req) {
        SysAdmin admin = sysAdminMapper.selectOne(
                new LambdaQueryWrapper<SysAdmin>()
                        .eq(SysAdmin::getUsername, req.getUsername().trim())
                        .last("LIMIT 1")
        );
        if (admin == null || !BCrypt.checkpw(req.getPassword(), admin.getPasswordHash())) {
            throw new BizException(ErrorCode.AUTH_FAILED);
        }
        if (admin.getStatus() == null || admin.getStatus() == 0) {
            throw new BizException(ErrorCode.ACCOUNT_DISABLED);
        }

        admin.setLastLoginAt(LocalDateTime.now());
        sysAdminMapper.updateById(admin);

        return issueTokens(admin);
    }

    public AdminLoginVO refreshToken(AdminRefreshReq req) {
        Long adminId = refreshStore.remove(req.getRefreshToken());
        if (adminId == null) {
            throw new BizException(ErrorCode.TOKEN_INVALID);
        }
        SysAdmin admin = sysAdminMapper.selectById(adminId);
        if (admin == null || admin.getStatus() == 0) {
            throw new BizException(ErrorCode.ACCOUNT_DISABLED);
        }
        return issueTokens(admin);
    }

    public AdminLoginVO currentAdmin() {
        Long adminId = StpAdminUtil.getLoginIdAsLong();
        SysAdmin admin = sysAdminMapper.selectById(adminId);
        if (admin == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED);
        }
        return buildVO(admin, StpAdminUtil.STP_LOGIC.getTokenValue(), null);
    }

    public void logout() {
        StpAdminUtil.logout();
    }

    private AdminLoginVO issueTokens(SysAdmin admin) {
        String accessToken = StpAdminUtil.login(admin.getId());
        String raw = admin.getId() + ":" + System.nanoTime();
        String refreshToken = "rt_" + Base64.getUrlEncoder().withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
        refreshStore.put(refreshToken, admin.getId());
        return buildVO(admin, accessToken, refreshToken);
    }

    private AdminLoginVO buildVO(SysAdmin admin, String accessToken, String refreshToken) {
        List<String> roles = List.of(admin.getRoleCode());
        List<String> perms = "SUPER_ADMIN".equals(admin.getRoleCode())
                ? List.of("*:*:*")
                : List.of("bank:view", "bank:edit", "user:view");
        String expires = LocalDateTime.now().plusHours(24).format(EXPIRES_FMT);
        return AdminLoginVO.builder()
                .id(admin.getId())
                .username(admin.getUsername())
                .nickname(admin.getRealName())
                .avatar(admin.getAvatarUrl() == null ? "" : admin.getAvatarUrl())
                .roles(roles)
                .permissions(perms)
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .expires(expires)
                .build();
    }
}
