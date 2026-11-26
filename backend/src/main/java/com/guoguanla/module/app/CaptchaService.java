package com.guoguanla.module.app;

import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.module.app.vo.AppUserProfileVO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.geom.AffineTransform;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 注册图形验证码服务（纯 Java2D 生成，内置无系统字体兜底矢量字形渲染，零外部依赖，支持一次性消费与 TTL 过期清理）。
 */
@Slf4j
@Service
public class CaptchaService {

    /** 去除易混淆字符 0/O/1/I/l */
    private static final String CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    private static final int CODE_LENGTH = 4;
    private static final int IMAGE_WIDTH = 132;
    private static final int IMAGE_HEIGHT = 46;
    private static final long TTL_MILLIS = 5 * 60 * 1000L;
    private static final int MAX_ENTRIES = 5000;

    private static final Color[] CHAR_PALETTE = new Color[]{
            new Color(15, 23, 42),
            new Color(2, 132, 199),
            new Color(5, 150, 105),
            new Color(180, 83, 9),
            new Color(124, 58, 237),
            new Color(190, 18, 60)
    };

    private final SecureRandom random = new SecureRandom();
    private final ConcurrentHashMap<String, CaptchaEntry> store = new ConcurrentHashMap<>();

    private record CaptchaEntry(String code, long expiresAtMillis) {}

    /**
     * 生成新的图形验证码并缓存，返回给客户端展示（绝不返回明文答案）。
     */
    public AppUserProfileVO.CaptchaVO generate() {
        purgeExpiredIfNeeded();
        String code = randomCode(CODE_LENGTH);
        String key = UUID.randomUUID().toString().replace("-", "");
        store.put(key, new CaptchaEntry(code, System.currentTimeMillis() + TTL_MILLIS));
        String dataUri = renderPngDataUri(code);
        return AppUserProfileVO.CaptchaVO.builder()
                .captchaKey(key)
                .imageBase64(dataUri)
                .expireSeconds((int) (TTL_MILLIS / 1000L))
                .build();
    }

    /**
     * 校验并一次性消费验证码（无论校验成功与否均立即移除，防止暴力猜测与重放）。
     */
    public void verifyAndConsume(String captchaKey, String inputCode) {
        if (captchaKey == null || captchaKey.isBlank() || inputCode == null || inputCode.isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请输入图形验证码");
        }
        CaptchaEntry entry = store.remove(captchaKey.trim());
        if (entry == null || System.currentTimeMillis() > entry.expiresAtMillis()) {
            throw new BizException(ErrorCode.BAD_REQUEST, "图形验证码已过期或无效，请点击图片刷新重试");
        }
        if (!entry.code().equalsIgnoreCase(inputCode.trim())) {
            throw new BizException(ErrorCode.BAD_REQUEST, "图形验证码错误，请刷新后重新输入");
        }
    }

    /**
     * 仅用于自动化集成测试注入可预测验证码，不暴露任何 HTTP 接口。
     */
    public String issueForTest(String fixedCode) {
        String normalized = (fixedCode == null || fixedCode.isBlank()) ? "A7K9" : fixedCode.trim().toUpperCase();
        String key = "test_" + UUID.randomUUID().toString().replace("-", "");
        store.put(key, new CaptchaEntry(normalized, System.currentTimeMillis() + TTL_MILLIS));
        return key;
    }

    private String randomCode(int length) {
        StringBuilder sb = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            sb.append(CODE_ALPHABET.charAt(random.nextInt(CODE_ALPHABET.length())));
        }
        return sb.toString();
    }

    private void purgeExpiredIfNeeded() {
        long now = System.currentTimeMillis();
        if (store.size() > 256) {
            store.entrySet().removeIf(e -> now > e.getValue().expiresAtMillis());
        }
        if (store.size() >= MAX_ENTRIES) {
            int toRemove = store.size() - (MAX_ENTRIES / 2);
            Iterator<Map.Entry<String, CaptchaEntry>> it = store.entrySet().iterator();
            while (it.hasNext() && toRemove > 0) {
                it.next();
                it.remove();
                toRemove--;
            }
        }
    }

    private String renderPngDataUri(String code) {
        BufferedImage img = new BufferedImage(IMAGE_WIDTH, IMAGE_HEIGHT, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);

            // 柔和浅色底纹渐变
            GradientPaint bg = new GradientPaint(
                    0, 0, new Color(248, 250, 252),
                    IMAGE_WIDTH, IMAGE_HEIGHT, new Color(239, 246, 255)
            );
            g.setPaint(bg);
            g.fillRect(0, 0, IMAGE_WIDTH, IMAGE_HEIGHT);

            // 干扰弧线与细线
            for (int i = 0; i < 6; i++) {
                g.setColor(new Color(148 + random.nextInt(70), 163 + random.nextInt(60), 184 + random.nextInt(60)));
                g.setStroke(new BasicStroke(1.2f));
                int x1 = random.nextInt(IMAGE_WIDTH / 2);
                int y1 = random.nextInt(IMAGE_HEIGHT);
                int x2 = IMAGE_WIDTH / 2 + random.nextInt(IMAGE_WIDTH / 2);
                int y2 = random.nextInt(IMAGE_HEIGHT);
                g.drawLine(x1, y1, x2, y2);
            }

            // 干扰噪点
            for (int i = 0; i < 42; i++) {
                g.setColor(new Color(100 + random.nextInt(120), 116 + random.nextInt(110), 139 + random.nextInt(100)));
                int x = random.nextInt(IMAGE_WIDTH);
                int y = random.nextInt(IMAGE_HEIGHT);
                g.fillOval(x, y, 2, 2);
            }

            // 绘制 4 位字符（优先使用系统 SansSerif 字体，极简无字体 Linux 环境自动降级矢量笔画）
            boolean renderedByFont = tryDrawCharsWithFont(g, code);
            if (!renderedByFont) {
                drawCharsWithVectorStrokes(g, code);
            }
        } finally {
            g.dispose();
        }

        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            ImageIO.write(img, "png", baos);
            return "data:image/png;base64," + Base64.getEncoder().encodeToString(baos.toByteArray());
        } catch (Exception e) {
            throw new BizException(ErrorCode.INTERNAL_ERROR, "生成图形验证码失败");
        }
    }

    private boolean tryDrawCharsWithFont(Graphics2D g, String code) {
        try {
            Font font = new Font(Font.SANS_SERIF, Font.BOLD, 28);
            g.setFont(font);
            FontMetrics fm = g.getFontMetrics();
            if (fm.charWidth('A') <= 0) {
                return false;
            }
            int step = (IMAGE_WIDTH - 20) / code.length();
            for (int i = 0; i < code.length(); i++) {
                String ch = String.valueOf(code.charAt(i));
                int cx = 14 + i * step + random.nextInt(5);
                int cy = 32 + random.nextInt(6) - 3;
                double angle = Math.toRadians(random.nextInt(32) - 16);

                AffineTransform old = g.getTransform();
                g.setColor(CHAR_PALETTE[random.nextInt(CHAR_PALETTE.length)]);
                g.rotate(angle, cx + 8, cy - 10);
                g.drawString(ch, cx, cy);
                g.setTransform(old);
            }
            return true;
        } catch (Throwable t) {
            log.warn("System font unavailable for captcha rendering, falling back to vector strokes: {}", t.getMessage());
            return false;
        }
    }

    /**
     * 无系统字体兜底：使用 3x5 节点坐标系直接绘制清晰防机器识读字符，保证在任意最小化 Linux/Docker 环境下可用。
     */
    private void drawCharsWithVectorStrokes(Graphics2D g, String code) {
        int step = (IMAGE_WIDTH - 24) / code.length();
        g.setStroke(new BasicStroke(2.6f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
        for (int i = 0; i < code.length(); i++) {
            char ch = Character.toUpperCase(code.charAt(i));
            int ox = 14 + i * step;
            int oy = 11 + random.nextInt(5);
            double angle = Math.toRadians(random.nextInt(24) - 12);
            AffineTransform old = g.getTransform();
            g.setColor(CHAR_PALETTE[random.nextInt(CHAR_PALETTE.length)]);
            g.rotate(angle, ox + 9, oy + 12);
            int[][] segs = vectorSegmentsFor(ch);
            for (int[] s : segs) {
                g.drawLine(ox + s[0], oy + s[1], ox + s[2], oy + s[3]);
            }
            g.setTransform(old);
        }
    }

    private int[][] vectorSegmentsFor(char ch) {
        // 字符盒宽 18、高 24（顶 0, 中 12, 底 24; 左 0, 中 9, 右 18）
        return switch (ch) {
            case '2' -> new int[][]{{0, 0, 18, 0}, {18, 0, 18, 12}, {18, 12, 0, 12}, {0, 12, 0, 24}, {0, 24, 18, 24}};
            case '3' -> new int[][]{{0, 0, 18, 0}, {18, 0, 18, 24}, {3, 12, 18, 12}, {0, 24, 18, 24}};
            case '4' -> new int[][]{{0, 0, 0, 13}, {0, 13, 18, 13}, {14, 0, 14, 24}};
            case '5' -> new int[][]{{18, 0, 0, 0}, {0, 0, 0, 12}, {0, 12, 18, 12}, {18, 12, 18, 24}, {18, 24, 0, 24}};
            case '6' -> new int[][]{{18, 0, 0, 0}, {0, 0, 0, 24}, {0, 12, 18, 12}, {18, 12, 18, 24}, {0, 24, 18, 24}};
            case '7' -> new int[][]{{0, 0, 18, 0}, {18, 0, 7, 24}};
            case '8' -> new int[][]{{0, 0, 18, 0}, {0, 12, 18, 12}, {0, 24, 18, 24}, {0, 0, 0, 24}, {18, 0, 18, 24}};
            case '9' -> new int[][]{{0, 0, 18, 0}, {0, 0, 0, 12}, {0, 12, 18, 12}, {18, 0, 18, 24}, {0, 24, 18, 24}};
            case 'A' -> new int[][]{{0, 24, 9, 0}, {9, 0, 18, 24}, {3, 15, 15, 15}};
            case 'B' -> new int[][]{{0, 0, 0, 24}, {0, 0, 14, 0}, {14, 0, 17, 6}, {17, 6, 13, 12}, {0, 12, 14, 12}, {14, 12, 18, 18}, {18, 18, 14, 24}, {0, 24, 14, 24}};
            case 'C' -> new int[][]{{18, 2, 2, 2}, {2, 2, 0, 12}, {0, 12, 2, 22}, {2, 22, 18, 22}};
            case 'D' -> new int[][]{{0, 0, 0, 24}, {0, 0, 12, 0}, {12, 0, 18, 12}, {18, 12, 12, 24}, {0, 24, 12, 24}};
            case 'E' -> new int[][]{{0, 0, 0, 24}, {0, 0, 18, 0}, {0, 12, 14, 12}, {0, 24, 18, 24}};
            case 'F' -> new int[][]{{0, 0, 0, 24}, {0, 0, 18, 0}, {0, 12, 14, 12}};
            case 'G' -> new int[][]{{18, 2, 2, 2}, {2, 2, 0, 12}, {0, 12, 2, 23}, {2, 23, 18, 23}, {18, 23, 18, 13}, {10, 13, 18, 13}};
            case 'H' -> new int[][]{{0, 0, 0, 24}, {18, 0, 18, 24}, {0, 12, 18, 12}};
            case 'J' -> new int[][]{{4, 0, 18, 0}, {14, 0, 14, 20}, {14, 20, 8, 24}, {8, 24, 2, 20}};
            case 'K' -> new int[][]{{0, 0, 0, 24}, {18, 0, 2, 12}, {2, 12, 18, 24}};
            case 'L' -> new int[][]{{0, 0, 0, 24}, {0, 24, 18, 24}};
            case 'M' -> new int[][]{{0, 24, 0, 0}, {0, 0, 9, 13}, {9, 13, 18, 0}, {18, 0, 18, 24}};
            case 'N' -> new int[][]{{0, 24, 0, 0}, {0, 0, 18, 24}, {18, 24, 18, 0}};
            case 'P' -> new int[][]{{0, 0, 0, 24}, {0, 0, 16, 0}, {16, 0, 16, 12}, {16, 12, 0, 12}};
            case 'Q' -> new int[][]{{0, 0, 18, 0}, {18, 0, 18, 22}, {18, 22, 0, 22}, {0, 22, 0, 0}, {11, 15, 19, 25}};
            case 'R' -> new int[][]{{0, 0, 0, 24}, {0, 0, 16, 0}, {16, 0, 16, 12}, {16, 12, 0, 12}, {8, 12, 18, 24}};
            case 'S' -> new int[][]{{18, 0, 0, 0}, {0, 0, 0, 12}, {0, 12, 18, 12}, {18, 12, 18, 24}, {18, 24, 0, 24}};
            case 'T' -> new int[][]{{0, 0, 18, 0}, {9, 0, 9, 24}};
            case 'U' -> new int[][]{{0, 0, 0, 22}, {0, 22, 18, 22}, {18, 22, 18, 0}};
            case 'V' -> new int[][]{{0, 0, 9, 24}, {9, 24, 18, 0}};
            case 'W' -> new int[][]{{0, 0, 4, 24}, {4, 24, 9, 11}, {9, 11, 14, 24}, {14, 24, 18, 0}};
            case 'X' -> new int[][]{{0, 0, 18, 24}, {18, 0, 0, 24}};
            case 'Y' -> new int[][]{{0, 0, 9, 12}, {18, 0, 9, 12}, {9, 12, 9, 24}};
            case 'Z' -> new int[][]{{0, 0, 18, 0}, {18, 0, 0, 24}, {0, 24, 18, 24}};
            default -> new int[][]{{0, 0, 18, 0}, {18, 0, 18, 24}, {18, 24, 0, 24}, {0, 24, 0, 0}};
        };
    }
}
