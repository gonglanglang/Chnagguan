package com.guoguanla.module.video;

import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.result.Result;
import com.guoguanla.common.util.ServletUrlHelper;
import com.guoguanla.module.video.vo.VideoVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "学生端-数学教学视频")
@RestController
@RequestMapping("/api/app/videos")
@RequiredArgsConstructor
public class AppVideoController {

    private final VideoService videoService;

    @Operation(summary = "分页获取已上架教学视频系列")
    @GetMapping("/series")
    public Result<PageResult<VideoVO.SeriesVO>> pageSeries(
            @RequestParam(required = false) String realmCode,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") Long pageNum,
            @RequestParam(defaultValue = "20") Long pageSize,
            HttpServletRequest request
    ) {
        return Result.ok(videoService.pageSeries(
                realmCode, keyword, true, pageNum, pageSize, ServletUrlHelper.resolveBaseOrigin(request)
        ));
    }

    @Operation(summary = "获取教学视频系列详情及课时、课堂笔记")
    @GetMapping("/series/{id}")
    public Result<VideoVO.SeriesDetailVO> seriesDetail(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(videoService.getSeriesDetail(id, true, ServletUrlHelper.resolveBaseOrigin(request)));
    }
}
