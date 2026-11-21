package com.guoguanla.module.video;

import com.guoguanla.common.annotation.OperLog;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.common.util.ServletUrlHelper;
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.video.dto.VideoDTO;
import com.guoguanla.module.video.vo.VideoVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@Tag(name = "管理后台-教学视频系列管理")
@RestController
@RequestMapping("/api/admin/videos")
@RequiredArgsConstructor
public class AdminVideoController {

    private final VideoService videoService;

    @Operation(summary = "分页查询教学视频系列")
    @GetMapping("/series")
    public Result<PageResult<VideoVO.SeriesVO>> pageSeries(
            @RequestParam(required = false) String realmCode,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") Long pageNum,
            @RequestParam(defaultValue = "10") Long pageSize,
            HttpServletRequest request
    ) {
        return Result.ok(videoService.pageSeries(
                realmCode, keyword, false, pageNum, pageSize, ServletUrlHelper.resolveBaseOrigin(request)
        ));
    }

    @Operation(summary = "获取教学视频系列详情及课时列表")
    @GetMapping("/series/{id}")
    public Result<VideoVO.SeriesDetailVO> seriesDetail(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(videoService.getSeriesDetail(id, false, ServletUrlHelper.resolveBaseOrigin(request)));
    }

    @Operation(summary = "新增教学视频系列")
    @OperLog(module = "VIDEO", action = "新增教学视频系列")
    @PostMapping("/series")
    public Result<Long> createSeries(@Valid @RequestBody VideoDTO.SeriesSaveReq req) {
        return Result.ok(videoService.createSeries(req));
    }

    @Operation(summary = "编辑教学视频系列")
    @OperLog(module = "VIDEO", action = "编辑教学视频系列")
    @PutMapping("/series/{id}")
    public Result<Void> updateSeries(@PathVariable Long id, @Valid @RequestBody VideoDTO.SeriesSaveReq req) {
        videoService.updateSeries(id, req);
        return Result.ok();
    }

    @Operation(summary = "删除教学视频系列")
    @OperLog(module = "VIDEO", action = "删除教学视频系列")
    @DeleteMapping("/series/{id}")
    public Result<Void> deleteSeries(@PathVariable Long id) {
        videoService.deleteSeries(id);
        return Result.ok();
    }

    @Operation(summary = "上传系列封面图")
    @PostMapping("/upload-cover")
    public Result<Map<String, String>> uploadCover(
            @RequestParam("file") MultipartFile file,
            HttpServletRequest request
    ) {
        AliyunOssService.UploadResult res = videoService.uploadCover(file, ServletUrlHelper.resolveBaseOrigin(request));
        return Result.ok(Map.of(
                "objectKey", res.objectKey(),
                "previewUrl", res.previewUrl(),
                "storageType", res.storageType()
        ));
    }

    @Operation(summary = "上传教学视频文件")
    @PostMapping("/upload-media")
    public Result<Map<String, String>> uploadMedia(
            @RequestParam("file") MultipartFile file,
            HttpServletRequest request
    ) {
        AliyunOssService.UploadResult res = videoService.uploadMedia(file, ServletUrlHelper.resolveBaseOrigin(request));
        return Result.ok(Map.of(
                "objectKey", res.objectKey(),
                "previewUrl", res.previewUrl(),
                "storageType", res.storageType()
        ));
    }

    @Operation(summary = "为系列新增视频课时")
    @OperLog(module = "VIDEO", action = "新增视频课时")
    @PostMapping("/series/{seriesId}/lessons")
    public Result<Long> createLesson(
            @PathVariable Long seriesId,
            @Valid @RequestBody VideoDTO.LessonSaveReq req
    ) {
        return Result.ok(videoService.createLesson(seriesId, req));
    }

    @Operation(summary = "编辑视频课时与课堂笔记")
    @OperLog(module = "VIDEO", action = "编辑视频课时")
    @PutMapping("/lessons/{lessonId}")
    public Result<Void> updateLesson(
            @PathVariable Long lessonId,
            @Valid @RequestBody VideoDTO.LessonSaveReq req
    ) {
        videoService.updateLesson(lessonId, req);
        return Result.ok();
    }

    @Operation(summary = "删除视频课时")
    @OperLog(module = "VIDEO", action = "删除视频课时")
    @DeleteMapping("/lessons/{lessonId}")
    public Result<Void> deleteLesson(@PathVariable Long lessonId) {
        videoService.deleteLesson(lessonId);
        return Result.ok();
    }
}
