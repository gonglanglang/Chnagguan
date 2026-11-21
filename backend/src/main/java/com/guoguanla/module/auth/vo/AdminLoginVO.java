package com.guoguanla.module.auth.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class AdminLoginVO {

    private Long id;
    private String username;
    private String nickname;
    private String avatar;
    private List<String> roles;
    private List<String> permissions;
    private String accessToken;
    private String refreshToken;
    /** 兼容 pure-admin-thin: yyyy/MM/dd HH:mm:ss */
    private String expires;
}
