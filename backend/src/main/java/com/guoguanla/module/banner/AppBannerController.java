package com.guoguanla.module.banner;

import com.guoguanla.common.result.Result;
import com.guoguanla.common.util.ServletUrlHelper;
import com.guoguanla.module.banner.vo.BannerVO;
import com.guoguanla.module.oss.AliyunOssService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.concurrent.TimeUnit;

@Tag(name = "学生端-首页师资力量轮播图")
@RestController
@RequestMapping("/api/app/banners")
@RequiredArgsConstructor
public class AppBannerController {

    private final HomeBannerService bannerService;

    @Operation(summary = "获取首页已上架师资力量轮播图列表")
    @GetMapping
    public Result<List<BannerVO.BannerItemVO>> list(HttpServletRequest request) {
        return Result.ok(bannerService.listAppBanners(ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "获取轮播图绑定的师资富文本详情")
    @GetMapping("/{id}")
    public Result<BannerVO.BannerDetailVO> detail(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(bannerService.getAppBannerDetail(id, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "稳定代理访问轮播图封面及富文本插图（兼容私有 OSS 与 App 长期展示）")
    @GetMapping("/media")
    public ResponseEntity<byte[]> media(@RequestParam("key") String key) {
        AliyunOssService.BinaryResource res = bannerService.readBannerMedia(key);
        MediaType mt;
        try {
            mt = MediaType.parseMediaType(res.contentType());
        } catch (Exception e) {
            mt = MediaType.IMAGE_PNG;
        }
        return ResponseEntity.ok()
                .contentType(mt)
                .cacheControl(CacheControl.maxAge(1, TimeUnit.HOURS).cachePublic())
                .body(res.bytes());
    }

    @Operation(summary = "获取内置默认师资轮播封面图")
    @GetMapping("/preset/{code}")
    public ResponseEntity<byte[]> preset(@PathVariable String code) {
        byte[] bytes = bannerService.renderPresetBannerPng(code);
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_PNG)
                .cacheControl(CacheControl.maxAge(24, TimeUnit.HOURS).cachePublic())
                .body(bytes);
    }
}
