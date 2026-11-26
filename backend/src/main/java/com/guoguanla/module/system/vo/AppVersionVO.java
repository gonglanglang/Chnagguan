package com.guoguanla.module.system.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AppVersionVO {
    private String currentVersion;
    private String latestVersion;
    private Integer latestVersionCode;
    private Boolean hasUpdate;
    private Boolean forceUpdate;
    private String releaseNotes;
    private String downloadUrl;
    private String githubReleaseUrl;
    private String githubRepo;
    private Boolean githubReachable;
    private String publishedAt;
    private String source;
    /** APK 下载通道：OSS_DIRECT（OSS 自定义域名直连高速）/ SERVER_PROXY（服务端内网中转）/ EXTERNAL_DIRECT（外链直下）/ LOCAL（本地目录） */
    private String downloadChannel;
    /** 当前生效的 OSS 自定义加速域名（空表示未配置） */
    private String ossCustomDomain;
}
