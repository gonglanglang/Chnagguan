package com.guoguanla.module.app;

import com.guoguanla.common.result.Result;
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.system.AppVersionService;
import com.guoguanla.module.system.vo.AppVersionVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.io.InputStream;
import java.net.URI;

@Tag(name = "学生端-App版本检查")
@RestController
@RequestMapping("/api/app/version")
@RequiredArgsConstructor
public class AppVersionController {

    private final AppVersionService appVersionService;

    @Operation(summary = "检测 App 是否有新版本更新")
    @GetMapping("/latest")
    public Result<AppVersionVO> latest(
            @RequestParam(required = false) String currentVersion,
            @RequestParam(required = false) Integer versionCode
    ) {
        String baseOrigin = ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
        return Result.ok(appVersionService.checkLatestVersion(currentVersion, versionCode, baseOrigin, false));
    }

    @Operation(summary = "下载最新 App 安装包（OSS CNAME 直跳或经内网从 OSS 流式转发）")
    @GetMapping("/download")
    public ResponseEntity<StreamingResponseBody> downloadLatest(
            @RequestHeader(value = "Range", required = false) String rangeHeader
    ) {
        String baseOrigin = ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
        AppVersionService.DownloadAction action = appVersionService.prepareDownload(rangeHeader, baseOrigin);
        if (action.ossStream() != null) {
            AliyunOssService.OssObjectStream stream = action.ossStream();
            ResponseEntity.BodyBuilder builder = ResponseEntity.status(stream.statusCode())
                    .header(HttpHeaders.CACHE_CONTROL, "no-store, no-cache, must-revalidate")
                    .header(HttpHeaders.CONTENT_TYPE, stream.contentType())
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + action.fileName() + "\"")
                    .header(HttpHeaders.ACCEPT_RANGES, "bytes");
            if (stream.contentLength() >= 0) {
                builder.contentLength(stream.contentLength());
            }
            if (stream.contentRange() != null && !stream.contentRange().isBlank()) {
                builder.header(HttpHeaders.CONTENT_RANGE, stream.contentRange());
            }
            StreamingResponseBody body = out -> {
                try (InputStream in = stream.body()) {
                    in.transferTo(out);
                }
            };
            return builder.body(body);
        }
        String target = action.redirectUrl();
        if (target == null || target.isBlank()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
        return ResponseEntity.status(HttpStatus.FOUND)
                .header(HttpHeaders.CACHE_CONTROL, "no-store, no-cache, must-revalidate")
                .location(URI.create(target))
                .build();
    }
}
