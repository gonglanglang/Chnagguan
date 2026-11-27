package com.guoguanla.module.banner;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.security.StpAdminUtil;
import com.guoguanla.module.banner.dto.BannerDTO;
import com.guoguanla.module.banner.entity.EduHomeBanner;
import com.guoguanla.module.banner.mapper.EduHomeBannerMapper;
import com.guoguanla.module.banner.vo.BannerVO;
import com.guoguanla.module.oss.AliyunOssService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.geom.Ellipse2D;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Slf4j
@Service
@RequiredArgsConstructor
public class HomeBannerService {

    private static final String PRESET_PREFIX = "preset://";
    private static final Pattern SCRIPT_TAG_PATTERN =
            Pattern.compile("(?is)<\\s*(script|iframe|object|embed|form)\\b[^>]*>.*?<\\s*/\\s*\\1\\s*>");
    private static final Pattern SELF_CLOSING_DANGEROUS_PATTERN =
            Pattern.compile("(?is)<\\s*(script|iframe|object|embed)\\b[^>]*/?>");
    private static final Pattern EVENT_ATTR_PATTERN =
            Pattern.compile("(?i)\\s+on[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)");
    private static final Pattern JS_PROTO_PATTERN =
            Pattern.compile("(?i)(href|src)\\s*=\\s*([\"'])\\s*javascript:[^\"']*\\2");
    private static final Pattern RELATIVE_SRC_PATTERN =
            Pattern.compile("(?i)(src\\s*=\\s*[\"'])(/(?:api/app/banners/media\\?[^\"']+|downloads/[^\"']+))([\"'])");

    private final EduHomeBannerMapper bannerMapper;
    private final AliyunOssService ossService;

    private final Map<String, byte[]> presetPngCache = new ConcurrentHashMap<>();

    public List<BannerVO.BannerItemVO> listAdminBanners(String baseOrigin) {
        return bannerMapper.selectList(
                        new LambdaQueryWrapper<EduHomeBanner>()
                                .orderByAsc(EduHomeBanner::getSortOrder)
                                .orderByDesc(EduHomeBanner::getId)
                ).stream()
                .map(b -> toItemVO(b, baseOrigin))
                .toList();
    }

    public BannerVO.BannerDetailVO getAdminBannerDetail(Long id, String baseOrigin) {
        EduHomeBanner banner = bannerMapper.selectById(id);
        if (banner == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "轮播图不存在");
        }
        return toDetailVO(banner, baseOrigin);
    }

    public Long createBanner(BannerDTO.SaveReq req) {
        EduHomeBanner banner = new EduHomeBanner();
        banner.setTitle(req.getTitle().trim());
        banner.setSubtitle(req.getSubtitle() == null ? "" : req.getSubtitle().trim());
        banner.setImageKey(req.getImageKey().trim());
        banner.setContentHtml(sanitizeHtml(req.getContentHtml()));
        banner.setSortOrder(req.getSortOrder() == null ? 0 : req.getSortOrder());
        banner.setEnabled(req.getEnabled() == null ? 1 : (req.getEnabled() == 0 ? 0 : 1));
        try {
            banner.setCreatedBy(StpAdminUtil.getLoginIdAsLong());
        } catch (Exception ignored) {
            // Allow unit tests or internal seed calls without admin session
        }
        bannerMapper.insert(banner);
        return banner.getId();
    }

    public void updateBanner(Long id, BannerDTO.SaveReq req) {
        EduHomeBanner existing = bannerMapper.selectById(id);
        if (existing == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "轮播图不存在");
        }
        existing.setTitle(req.getTitle().trim());
        existing.setSubtitle(req.getSubtitle() == null ? "" : req.getSubtitle().trim());
        existing.setImageKey(req.getImageKey().trim());
        existing.setContentHtml(sanitizeHtml(req.getContentHtml()));
        if (req.getSortOrder() != null) {
            existing.setSortOrder(req.getSortOrder());
        }
        if (req.getEnabled() != null) {
            existing.setEnabled(req.getEnabled() == 0 ? 0 : 1);
        }
        bannerMapper.updateById(existing);
    }

    public void updateStatus(Long id, Integer enabled) {
        EduHomeBanner existing = bannerMapper.selectById(id);
        if (existing == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "轮播图不存在");
        }
        existing.setEnabled(enabled != null && enabled == 1 ? 1 : 0);
        bannerMapper.updateById(existing);
    }

    public void deleteBanner(Long id) {
        EduHomeBanner existing = bannerMapper.selectById(id);
        if (existing == null) {
            throw new BizException(ErrorCode.NOT_FOUND, "轮播图不存在");
        }
        bannerMapper.deleteById(id);
    }

    public BannerVO.UploadImageVO uploadBannerImage(MultipartFile file, String baseOrigin) {
        AliyunOssService.UploadResult res = ossService.uploadBannerImage(file, baseOrigin);
        String mediaPath = "/api/app/banners/media?key=" + URLEncoder.encode(res.objectKey(), StandardCharsets.UTF_8);
        String mediaUrl = combineOrigin(baseOrigin, mediaPath);
        return BannerVO.UploadImageVO.builder()
                .objectKey(res.objectKey())
                .previewUrl(res.previewUrl())
                .mediaUrl(mediaUrl)
                .storageType(res.storageType())
                .build();
    }

    public List<BannerVO.BannerItemVO> listAppBanners(String baseOrigin) {
        return bannerMapper.selectList(
                        new LambdaQueryWrapper<EduHomeBanner>()
                                .eq(EduHomeBanner::getEnabled, 1)
                                .orderByAsc(EduHomeBanner::getSortOrder)
                                .orderByDesc(EduHomeBanner::getId)
                ).stream()
                .map(b -> toItemVO(b, baseOrigin))
                .toList();
    }

    public BannerVO.BannerDetailVO getAppBannerDetail(Long id, String baseOrigin) {
        EduHomeBanner banner = bannerMapper.selectById(id);
        if (banner == null || banner.getEnabled() == null || banner.getEnabled() == 0) {
            throw new BizException(ErrorCode.NOT_FOUND, "师资详情不存在或已下架");
        }
        return toDetailVO(banner, baseOrigin);
    }

    public AliyunOssService.BinaryResource readBannerMedia(String key) {
        if (key == null || key.isBlank()) {
            throw new BizException(ErrorCode.NOT_FOUND, "图片不存在");
        }
        String clean = key.trim();
        if (clean.contains("..") || clean.contains("\\")) {
            throw new BizException(ErrorCode.BAD_REQUEST, "非法图片路径");
        }
        if (!(clean.startsWith("home-banners/") || clean.startsWith("/downloads/home-banners/"))) {
            throw new BizException(ErrorCode.FORBIDDEN, "无权访问该资源");
        }
        return ossService.readObjectBytes(clean);
    }

    public byte[] renderPresetBannerPng(String code) {
        String safeCode = (code == null || code.isBlank()) ? "faculty-1" : code.trim().toLowerCase();
        return presetPngCache.computeIfAbsent(safeCode, this::generatePresetBannerBytes);
    }

    public String resolveBannerImageUrl(String imageKey, String baseOrigin) {
        if (imageKey == null || imageKey.isBlank()) {
            return "";
        }
        String trimmed = imageKey.trim();
        if (trimmed.startsWith(PRESET_PREFIX)) {
            String code = trimmed.substring(PRESET_PREFIX.length()).replaceAll("[^A-Za-z0-9_-]", "");
            if (code.isEmpty()) code = "faculty-1";
            return combineOrigin(baseOrigin, "/api/app/banners/preset/" + code);
        }
        if (trimmed.startsWith("home-banners/") || trimmed.startsWith("/downloads/home-banners/")) {
            return combineOrigin(
                    baseOrigin,
                    "/api/app/banners/media?key=" + URLEncoder.encode(trimmed, StandardCharsets.UTF_8)
            );
        }
        return ossService.resolveViewUrl(trimmed, baseOrigin);
    }

    public String resolveHtmlMediaUrls(String rawHtml, String baseOrigin) {
        if (rawHtml == null || rawHtml.isBlank()) {
            return "";
        }
        String safe = sanitizeHtml(rawHtml);
        if (baseOrigin == null || baseOrigin.isBlank()) {
            return safe;
        }
        String cleanOrigin = baseOrigin.endsWith("/")
                ? baseOrigin.substring(0, baseOrigin.length() - 1)
                : baseOrigin;
        Matcher matcher = RELATIVE_SRC_PATTERN.matcher(safe);
        StringBuffer sb = new StringBuffer();
        while (matcher.find()) {
            String prefix = matcher.group(1);
            String path = matcher.group(2);
            String suffix = matcher.group(3);
            matcher.appendReplacement(sb, Matcher.quoteReplacement(prefix + cleanOrigin + path + suffix));
        }
        matcher.appendTail(sb);
        return sb.toString();
    }

    public static String sanitizeHtml(String rawHtml) {
        if (rawHtml == null) {
            return "";
        }
        String cleaned = SCRIPT_TAG_PATTERN.matcher(rawHtml).replaceAll("");
        cleaned = SELF_CLOSING_DANGEROUS_PATTERN.matcher(cleaned).replaceAll("");
        cleaned = EVENT_ATTR_PATTERN.matcher(cleaned).replaceAll("");
        cleaned = JS_PROTO_PATTERN.matcher(cleaned).replaceAll("$1=$2#$2");
        return cleaned.trim();
    }

    private BannerVO.BannerItemVO toItemVO(EduHomeBanner b, String baseOrigin) {
        return BannerVO.BannerItemVO.builder()
                .id(b.getId())
                .title(b.getTitle())
                .subtitle(b.getSubtitle() == null ? "" : b.getSubtitle())
                .imageKey(b.getImageKey() == null ? "" : b.getImageKey())
                .imageUrl(resolveBannerImageUrl(b.getImageKey(), baseOrigin))
                .sortOrder(b.getSortOrder() == null ? 0 : b.getSortOrder())
                .enabled(b.getEnabled() == null ? 1 : b.getEnabled())
                .hasDetailContent(b.getContentHtml() != null && !b.getContentHtml().isBlank())
                .updatedAt(b.getUpdatedAt())
                .build();
    }

    private BannerVO.BannerDetailVO toDetailVO(EduHomeBanner b, String baseOrigin) {
        return BannerVO.BannerDetailVO.builder()
                .id(b.getId())
                .title(b.getTitle())
                .subtitle(b.getSubtitle() == null ? "" : b.getSubtitle())
                .imageKey(b.getImageKey() == null ? "" : b.getImageKey())
                .imageUrl(resolveBannerImageUrl(b.getImageKey(), baseOrigin))
                .contentHtml(resolveHtmlMediaUrls(b.getContentHtml(), baseOrigin))
                .sortOrder(b.getSortOrder() == null ? 0 : b.getSortOrder())
                .enabled(b.getEnabled() == null ? 1 : b.getEnabled())
                .createdAt(b.getCreatedAt())
                .updatedAt(b.getUpdatedAt())
                .build();
    }

    private String combineOrigin(String baseOrigin, String path) {
        if (baseOrigin == null || baseOrigin.isBlank()) {
            return path;
        }
        String clean = baseOrigin.endsWith("/") ? baseOrigin.substring(0, baseOrigin.length() - 1) : baseOrigin;
        return clean + path;
    }

    private byte[] generatePresetBannerBytes(String code) {
        int w = 960;
        int h = 400;
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);

            Color c1;
            Color c2;
            Color accent;
            String badge;
            String heading;
            String sub;
            String formula;
            switch (code) {
                case "faculty-2" -> {
                    c1 = new Color(0x06, 0x5F, 0x46);
                    c2 = new Color(0x0D, 0x94, 0x88);
                    accent = new Color(0xA7, 0xF3, 0xD0);
                    badge = "中考几何教研组";
                    heading = "几何模型与辅助线精讲团队";
                    sub = "一线省重点骨干名师 · 专攻三角形/圆/动态压轴";
                    formula = "△ABC ≌ △DEF  ·  sin²α + cos²α = 1";
                }
                case "faculty-3" -> {
                    c1 = new Color(0x31, 0x2E, 0x81);
                    c2 = new Color(0x4F, 0x46, 0xE5);
                    accent = new Color(0xC7, 0xD2, 0xFE);
                    badge = "高考压轴教研组";
                    heading = "高中函数导数与解析几何名师团";
                    sub = "清北硕博教研领衔 · 1对1 解题思维拆解";
                    formula = "f'(x) = 0  ·  x²/a² + y²/b² = 1";
                }
                default -> {
                    c1 = new Color(0x03, 0x69, 0xA1);
                    c2 = new Color(0x02, 0x84, 0xC7);
                    accent = new Color(0xBA, 0xE6, 0xFD);
                    badge = "过关啦核心师资";
                    heading = "初高中同步数学金牌教研团队";
                    sub = "10年+ 教研沉淀 · 51章体系化闯关与手写批改";
                    formula = "a² + b² = c²  ·  y = ax² + bx + c";
                }
            }

            GradientPaint bg = new GradientPaint(0, 0, c1, w, h, c2);
            g.setPaint(bg);
            g.fillRect(0, 0, w, h);

            // Subtle geometric backdrop
            g.setColor(new Color(255, 255, 255, 24));
            g.fill(new Ellipse2D.Double(650, -60, 380, 380));
            g.fill(new Ellipse2D.Double(720, 170, 260, 260));
            g.setStroke(new BasicStroke(2.2f));
            g.setColor(new Color(255, 255, 255, 42));
            g.drawPolygon(new int[]{710, 860, 775}, new int[]{290, 290, 125}, 3);
            g.drawOval(695, 95, 190, 190);

            // Badge pill
            g.setColor(new Color(255, 255, 255, 36));
            g.fill(new RoundRectangle2D.Double(56, 54, 210, 42, 21, 21));
            g.setColor(accent);
            g.setFont(resolveCjkFont(Font.BOLD, 20));
            g.drawString(badge, 78, 82);

            // Main heading
            g.setColor(Color.WHITE);
            g.setFont(resolveCjkFont(Font.BOLD, 42));
            g.drawString(heading, 56, 172);

            // Subtitle
            g.setColor(new Color(255, 255, 255, 220));
            g.setFont(resolveCjkFont(Font.PLAIN, 23));
            g.drawString(sub, 56, 224);

            // Formula pill at bottom
            g.setColor(new Color(15, 23, 42, 72));
            g.fill(new RoundRectangle2D.Double(56, 276, 460, 56, 14, 14));
            g.setColor(accent);
            g.setFont(resolveCjkFont(Font.BOLD, 22));
            g.drawString(formula, 78, 312);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ImageIO.write(img, "png", baos);
            return baos.toByteArray();
        } catch (Exception e) {
            log.warn("Failed to render preset banner PNG ({}): {}", code, e.getMessage());
            return new byte[0];
        } finally {
            g.dispose();
        }
    }

    private Font resolveCjkFont(int style, int size) {
        String[] candidates = {"Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "WenQuanYi Micro Hei", Font.SANS_SERIF};
        for (String name : candidates) {
            Font f = new Font(name, style, size);
            if (f.canDisplay('数')) {
                return f;
            }
        }
        return new Font(Font.SANS_SERIF, style, size);
    }
}
