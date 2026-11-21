package com.guoguanla.module.video;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.result.PageResult;
import com.guoguanla.common.security.StpAdminUtil;
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.system.RealmHelperService;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.video.dto.VideoDTO;
import com.guoguanla.module.video.entity.EduVideoLesson;
import com.guoguanla.module.video.entity.EduVideoSeries;
import com.guoguanla.module.video.mapper.EduVideoLessonMapper;
import com.guoguanla.module.video.mapper.EduVideoSeriesMapper;
import com.guoguanla.module.video.vo.VideoVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class VideoService {

    private final EduVideoSeriesMapper seriesMapper;
    private final EduVideoLessonMapper lessonMapper;
    private final RealmHelperService realmHelper;
    private final AliyunOssService ossService;

    public PageResult<VideoVO.SeriesVO> pageSeries(
            String realmCode,
            String keyword,
            boolean enabledOnly,
            Long pageNum,
            Long pageSize,
            String baseOrigin
    ) {
        long p = pageNum == null || pageNum < 1 ? 1L : pageNum;
        long s = pageSize == null || pageSize < 1 ? 10L : Math.min(pageSize, 50L);

        LambdaQueryWrapper<EduVideoSeries> wrapper = new LambdaQueryWrapper<>();
        if (enabledOnly) {
            wrapper.eq(EduVideoSeries::getEnabled, 1);
        }
        if (realmCode != null && !realmCode.isBlank()) {
            String rc = realmCode.trim();
            if (enabledOnly) {
                wrapper.and(w -> w.eq(EduVideoSeries::getRealmCode, rc)
                        .or().eq(EduVideoSeries::getRealmCode, ""));
            } else {
                wrapper.eq(EduVideoSeries::getRealmCode, rc);
            }
        }
        if (keyword != null && !keyword.isBlank()) {
            String kw = keyword.trim();
            wrapper.and(w -> w.like(EduVideoSeries::getTitle, kw)
                    .or().like(EduVideoSeries::getIntro, kw));
        }
        wrapper.orderByAsc(EduVideoSeries::getSortOrder).orderByDesc(EduVideoSeries::getId);

        Page<EduVideoSeries> page = seriesMapper.selectPage(new Page<>(p, s), wrapper);
        if (page.getRecords().isEmpty()) {
            return PageResult.of(List.of(), page.getTotal(), p, s);
        }

        List<Long> seriesIds = page.getRecords().stream().map(EduVideoSeries::getId).toList();
        LambdaQueryWrapper<EduVideoLesson> lessonWrapper = new LambdaQueryWrapper<EduVideoLesson>()
                .in(EduVideoLesson::getSeriesId, seriesIds);
        if (enabledOnly) {
            lessonWrapper.eq(EduVideoLesson::getEnabled, 1);
        }
        Map<Long, Long> countMap = lessonMapper.selectList(lessonWrapper).stream()
                .collect(Collectors.groupingBy(EduVideoLesson::getSeriesId, Collectors.counting()));

        Map<String, String> realmNameMap = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getRealmCode, EduRealm::getRealmName, (a, b) -> a));

        List<VideoVO.SeriesVO> records = page.getRecords().stream()
                .map(item -> toSeriesVO(item, realmNameMap, countMap.getOrDefault(item.getId(), 0L), baseOrigin))
                .toList();
        return PageResult.of(records, page.getTotal(), p, s);
    }

    public VideoVO.SeriesDetailVO getSeriesDetail(Long seriesId, boolean enabledOnly, String baseOrigin) {
        EduVideoSeries series = seriesMapper.selectById(seriesId);
        if (series == null || (enabledOnly && series.getEnabled() == 0)) {
            throw new BizException(ErrorCode.NOT_FOUND, "教学视频系列不存在或已下架");
        }

        LambdaQueryWrapper<EduVideoLesson> lw = new LambdaQueryWrapper<EduVideoLesson>()
                .eq(EduVideoLesson::getSeriesId, seriesId)
                .orderByAsc(EduVideoLesson::getSortOrder)
                .orderByAsc(EduVideoLesson::getId);
        if (enabledOnly) {
            lw.eq(EduVideoLesson::getEnabled, 1);
        }
        List<EduVideoLesson> lessons = lessonMapper.selectList(lw);

        Map<String, String> realmNameMap = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getRealmCode, EduRealm::getRealmName, (a, b) -> a));
        VideoVO.SeriesVO seriesVO = toSeriesVO(series, realmNameMap, lessons.size(), baseOrigin);
        List<VideoVO.LessonVO> lessonVOs = lessons.stream()
                .map(l -> toLessonVO(l, baseOrigin))
                .toList();

        return VideoVO.SeriesDetailVO.builder()
                .series(seriesVO)
                .lessons(lessonVOs)
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public Long createSeries(VideoDTO.SeriesSaveReq req) {
        EduVideoSeries entity = new EduVideoSeries();
        applySeriesReq(entity, req);
        try {
            if (StpAdminUtil.isLogin()) {
                entity.setCreatedBy(StpAdminUtil.getLoginIdAsLong());
            }
        } catch (Exception ignored) {
        }
        seriesMapper.insert(entity);
        return entity.getId();
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateSeries(Long id, VideoDTO.SeriesSaveReq req) {
        EduVideoSeries entity = seriesMapper.selectById(id);
        if (entity == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "教学视频系列不存在");
        }
        applySeriesReq(entity, req);
        seriesMapper.updateById(entity);
    }

    @Transactional(rollbackFor = Exception.class)
    public void deleteSeries(Long id) {
        EduVideoSeries entity = seriesMapper.selectById(id);
        if (entity == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "教学视频系列不存在");
        }
        seriesMapper.deleteById(id);
        lessonMapper.delete(new LambdaQueryWrapper<EduVideoLesson>().eq(EduVideoLesson::getSeriesId, id));
    }

    @Transactional(rollbackFor = Exception.class)
    public Long createLesson(Long seriesId, VideoDTO.LessonSaveReq req) {
        EduVideoSeries series = seriesMapper.selectById(seriesId);
        if (series == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "所属教学视频系列不存在");
        }
        EduVideoLesson lesson = new EduVideoLesson();
        lesson.setSeriesId(seriesId);
        applyLessonReq(lesson, req);
        lessonMapper.insert(lesson);
        return lesson.getId();
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateLesson(Long lessonId, VideoDTO.LessonSaveReq req) {
        EduVideoLesson lesson = lessonMapper.selectById(lessonId);
        if (lesson == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "视频课时不存在");
        }
        applyLessonReq(lesson, req);
        lessonMapper.updateById(lesson);
    }

    @Transactional(rollbackFor = Exception.class)
    public void deleteLesson(Long lessonId) {
        lessonMapper.deleteById(lessonId);
    }

    public AliyunOssService.UploadResult uploadCover(MultipartFile file, String baseOrigin) {
        return ossService.uploadVideoCover(file, baseOrigin);
    }

    public AliyunOssService.UploadResult uploadMedia(MultipartFile file, String baseOrigin) {
        return ossService.uploadCourseVideo(file, baseOrigin);
    }

    private void applySeriesReq(EduVideoSeries entity, VideoDTO.SeriesSaveReq req) {
        entity.setTitle(req.getTitle().trim());
        entity.setCoverImageKey(req.getCoverImageKey() == null ? "" : req.getCoverImageKey().trim());
        entity.setIntro(req.getIntro() == null ? "" : req.getIntro().trim());
        entity.setRealmCode(req.getRealmCode() == null ? "" : req.getRealmCode().trim());
        entity.setSortOrder(req.getSortOrder() == null ? 0 : req.getSortOrder());
        entity.setEnabled(req.getEnabled() == null ? 1 : (req.getEnabled() == 0 ? 0 : 1));
    }

    private void applyLessonReq(EduVideoLesson lesson, VideoDTO.LessonSaveReq req) {
        lesson.setTitle(req.getTitle().trim());
        lesson.setVideoKey(req.getVideoKey().trim());
        lesson.setDurationSec(req.getDurationSec() == null ? 0 : Math.max(0, req.getDurationSec()));
        lesson.setClassNotes(req.getClassNotes() == null ? "" : req.getClassNotes());
        lesson.setSortOrder(req.getSortOrder() == null ? 0 : req.getSortOrder());
        lesson.setEnabled(req.getEnabled() == null ? 1 : (req.getEnabled() == 0 ? 0 : 1));
    }

    private VideoVO.SeriesVO toSeriesVO(
            EduVideoSeries item,
            Map<String, String> realmNameMap,
            long lessonCount,
            String baseOrigin
    ) {
        String rc = item.getRealmCode() == null ? "" : item.getRealmCode();
        String rName = rc.isBlank() ? "全境界通用" : realmNameMap.getOrDefault(rc, rc);
        return VideoVO.SeriesVO.builder()
                .id(item.getId())
                .title(item.getTitle())
                .coverImageKey(item.getCoverImageKey() == null ? "" : item.getCoverImageKey())
                .coverImageUrl(ossService.resolveViewUrl(item.getCoverImageKey(), baseOrigin))
                .intro(item.getIntro() == null ? "" : item.getIntro())
                .realmCode(rc)
                .realmName(rName)
                .sortOrder(item.getSortOrder())
                .enabled(item.getEnabled())
                .lessonCount(lessonCount)
                .createdAt(item.getCreatedAt())
                .updatedAt(item.getUpdatedAt())
                .build();
    }

    private VideoVO.LessonVO toLessonVO(EduVideoLesson l, String baseOrigin) {
        return VideoVO.LessonVO.builder()
                .id(l.getId())
                .seriesId(l.getSeriesId())
                .title(l.getTitle())
                .videoKey(l.getVideoKey() == null ? "" : l.getVideoKey())
                .videoUrl(ossService.resolveViewUrl(l.getVideoKey(), baseOrigin))
                .durationSec(l.getDurationSec() == null ? 0 : l.getDurationSec())
                .classNotes(l.getClassNotes() == null ? "" : l.getClassNotes())
                .sortOrder(l.getSortOrder())
                .enabled(l.getEnabled())
                .createdAt(l.getCreatedAt())
                .updatedAt(l.getUpdatedAt())
                .build();
    }
}
