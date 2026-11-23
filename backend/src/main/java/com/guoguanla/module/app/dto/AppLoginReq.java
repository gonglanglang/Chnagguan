package com.guoguanla.module.app.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class AppLoginReq {

    @NotBlank(message = "账号或手机号不能为空")
    private String account;

    @NotBlank(message = "密码不能为空")
    private String password;

    private List<Long> guestPassedGateIds;

    @Data
    public static class RegisterReq {
        @NotBlank(message = "用户名不能为空")
        @Size(min = 3, max = 32, message = "用户名长度需为 3~32 位")
        private String username;

        @NotBlank(message = "密码不能为空")
        @Size(min = 6, max = 32, message = "密码长度需为 6~32 位")
        private String password;

        @NotBlank(message = "昵称不能为空")
        private String nickname;

        @NotBlank(message = "请选择所在年级")
        private String gradeCode;
        private String realmCode;
        private List<Long> guestPassedGateIds;
    }

    @Data
    public static class ProfileUpdateReq {
        @NotBlank(message = "昵称不能为空")
        private String nickname;

        private String avatarUrl;
        private String gradeCode;
    }
}
