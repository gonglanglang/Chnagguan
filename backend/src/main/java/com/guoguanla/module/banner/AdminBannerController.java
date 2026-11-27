package com.guoguanla.module.banner;

import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.result.Result;
import com.guoguanla.common.util.ServletUrlHelper;
import com.guoguanla.module.banner.dto.BannerDTO;
import com.guoguanla.module.banner.vo.BannerVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@Tag(name = "管理后台-首页师资力量轮播图")
@RestController
@RequestMapping("/api/admin/banners")
@RequiredArgsConstructor
public class AdminBannerController {

    private final HomeBannerService bannerService;

    @Operation(summary = "查询全部轮播图列表")
    @GetMapping
    public Result<List<BannerVO.BannerItemVO>> list(HttpServletRequest request) {
        return Result.ok(bannerService.listAdminBanners(ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "查询单条轮播图详情（含富文本）")
    @GetMapping("/{id}")
    public Result<BannerVO.BannerDetailVO> detail(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(bannerService.getAdminBannerDetail(id, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "新增轮播图")
    @OperLog(module = "BANNER", action = "CREATE_BANNER")
    @PostMapping
    public Result<Long> create(@Valid @RequestBody BannerDTO.SaveReq req) {
        return Result.ok(bannerService.createBanner(req));
    }

    @Operation(summary = "更新轮播图与绑定富文本")
    @OperLog(module = "BANNER", action = "UPDATE_BANNER")
    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @Valid @RequestBody BannerDTO.SaveReq req) {
        bannerService.updateBanner(id, req);
        return Result.ok();
    }

    @Operation(summary = "上架/下架轮播图")
    @OperLog(module = "BANNER", action = "TOGGLE_BANNER_STATUS")
    @PatchMapping("/{id}/status")
    public Result<Void> toggleStatus(@PathVariable Long id, @Valid @RequestBody BannerDTO.StatusReq req) {
        bannerService.updateStatus(id, req.getEnabled());
        return Result.ok();
    }

    @Operation(summary = "删除轮播图")
    @OperLog(module = "BANNER", action = "DELETE_BANNER")
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        bannerService.deleteBanner(id);
        return Result.ok();
    }

    @Operation(summary = "上传轮播图封面或富文本内插图")
    @PostMapping("/upload-image")
    public Result<BannerVO.UploadImageVO> uploadImage(
            @RequestParam("file") MultipartFile file,
            HttpServletRequest request
    ) {
        return Result.ok(bannerService.uploadBannerImage(file, ServletUrlHelper.resolveBaseOrigin(request)));
    }
}
