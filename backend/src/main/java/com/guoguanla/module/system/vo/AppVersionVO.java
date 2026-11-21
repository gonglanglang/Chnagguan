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
}
