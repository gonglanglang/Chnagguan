package com.guoguanla.module.user.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class UserUpdateReq {

    @NotBlank(message = "昵称不能为空")
    private String nickname;

    private String gradeCode;
    private String realmCode;
    private String phone;
    private String remark;
    private Integer status;
    /** 选填：非空时同步重置学生登录密码（至少6位） */
    private String password;
}
