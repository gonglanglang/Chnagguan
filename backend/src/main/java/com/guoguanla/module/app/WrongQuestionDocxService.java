package com.guoguanla.module.app;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.security.StpAppUtil;
import com.guoguanla.common.util.JsonHelper;
import com.guoguanla.module.app.dto.AppQuizDTO;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import com.guoguanla.module.oss.AliyunOssService;
import com.guoguanla.module.progress.entity.UserWrongQuestion;
import com.guoguanla.module.progress.mapper.UserWrongQuestionMapper;
import com.guoguanla.module.system.RealmHelperService;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.geom.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * 错题本 A4 纸模板 Word (.docx) 导出引擎。
 * 纯 JDK OOXML 打包 + Java2D 高清矢量配图渲染，兼容 Microsoft Word / WPS / 微信文档预览。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class WrongQuestionDocxService {

    private static final int MAX_EXPORT_COUNT = 100;
    private static final int PAGE_CONTENT_WIDTH_TWIPS = 9638; // 210mm A4 - 2*20mm margins
    private static final String[] LETTERS = {"A", "B", "C", "D", "E", "F"};
    private static final Pattern FRAC_PATTERN = Pattern.compile("\\\\[dtcb]?frac\\s*\\{([^{}]+)\\}\\s*\\{([^{}]+)\\}");
    private static final Pattern SQRT_PATTERN = Pattern.compile("\\\\sqrt\\s*\\{([^{}]+)\\}");
    private static final Pattern SUP_BRACE_PATTERN = Pattern.compile("\\^\\{([^{}]+)\\}");
    private static final Pattern SUB_BRACE_PATTERN = Pattern.compile("_\\{([^{}]+)\\}");

    private final UserWrongQuestionMapper wrongMapper;
    private final EduQuestionMapper questionMapper;
    private final AppUserMapper userMapper;
    private final RealmHelperService realmHelper;
    private final AliyunOssService ossService;
    private final ObjectMapper objectMapper;

    public record DocxExportResult(String fileName, byte[] bytes, int questionCount) {}

    private record EmbeddedImage(String relId, String fileName, String ext, byte[] bytes, long cxEmu, long cyEmu) {}

    private record PreparedItem(
            int index,
            String realmName,
            String chapterName,
            String gateName,
            String questionFormat,
            int wrongCount,
            String stem,
            List<String> options,
            int answerIndex,
            String referenceAnswer,
            String analysis,
            EmbeddedImage figureImage
    ) {}

    public DocxExportResult exportDocx(AppQuizDTO.WrongExportReq req) {
        Long userId = StpAppUtil.getLoginIdAsLong();
        AppUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED);
        }
        AppQuizDTO.WrongExportReq safeReq = req == null ? new AppQuizDTO.WrongExportReq() : req;
        List<UserWrongQuestion> wrongs = loadTargetWrongs(userId, safeReq);
        if (wrongs.isEmpty()) {
            throw new BizException(ErrorCode.NOT_FOUND, "暂无可导出的错题记录");
        }

        String answerMode = normalizeAnswerMode(safeReq.getAnswerMode());
        boolean includeDiagrams = safeReq.getIncludeDiagrams() == null || safeReq.getIncludeDiagrams();
        boolean includeWorkspace = safeReq.getIncludeWorkspace() == null || safeReq.getIncludeWorkspace();

        Map<String, EduRealm> realmByGrade = realmHelper.listAllRealmsForAdmin().stream()
                .collect(Collectors.toMap(EduRealm::getGradeCode, r -> r, (a, b) -> a));
        EduRealm userRealm = realmHelper.resolveUserRealm(user);

        String title = (safeReq.getTitle() != null && !safeReq.getTitle().isBlank())
                ? safeReq.getTitle().trim()
                : buildDefaultTitle(safeReq, realmByGrade);

        Map<Long, EduQuestion> qMap = loadQuestionMap(wrongs);
        List<EmbeddedImage> images = new ArrayList<>();
        List<PreparedItem> prepared = new ArrayList<>(wrongs.size());

        // 选择题在前、解答题在后进行试卷化分类排版
        List<UserWrongQuestion> choiceWrongs = new ArrayList<>();
        List<UserWrongQuestion> essayWrongs = new ArrayList<>();
        for (UserWrongQuestion w : wrongs) {
            if ("ESSAY".equalsIgnoreCase(w.getQuestionFormat())) {
                essayWrongs.add(w);
            } else {
                choiceWrongs.add(w);
            }
        }
        List<UserWrongQuestion> ordered = new ArrayList<>(wrongs.size());
        ordered.addAll(choiceWrongs);
        ordered.addAll(essayWrongs);

        int seq = 1;
        for (UserWrongQuestion w : ordered) {
            EduRealm r = realmByGrade.get(w.getGradeCode());
            String fmt = "ESSAY".equalsIgnoreCase(w.getQuestionFormat()) ? "ESSAY" : "SINGLE_CHOICE";
            List<String> opts = JsonHelper.readStringList(objectMapper, w.getOptionsJson());
            int ansIdx = parseAnswerIndex(w.getAnswerJson());
            String refAns = parseReferenceAnswer(w.getAnswerJson());

            EmbeddedImage fig = null;
            if (includeDiagrams) {
                fig = buildFigureImage(qMap.get(w.getQuestionId()), images.size() + 1);
                if (fig != null) {
                    images.add(fig);
                }
            }

            prepared.add(new PreparedItem(
                    seq++,
                    r != null ? r.getRealmName() : w.getGradeCode(),
                    safeStr(w.getChapterName()),
                    safeStr(w.getGateName()),
                    fmt,
                    w.getWrongCount() == null ? 1 : Math.max(1, w.getWrongCount()),
                    formatMathText(safeStr(w.getStem())),
                    opts.stream().map(WrongQuestionDocxService::formatMathText).toList(),
                    ansIdx,
                    formatMathText(refAns),
                    formatMathText(safeStr(w.getAnalysis())),
                    fig
            ));
        }

        String studentName = safeStr(user.getNickname()).isBlank() ? safeStr(user.getUsername()) : safeStr(user.getNickname());
        String dateStr = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
        byte[] docxBytes = buildDocxPackage(
                title,
                studentName,
                userRealm.getRealmName(),
                dateStr,
                prepared,
                images,
                choiceWrongs.size(),
                essayWrongs.size(),
                answerMode,
                includeWorkspace
        );

        String safeFileTitle = title.replaceAll("[\\\\/:*?\"<>|\\s]+", "_");
        if (safeFileTitle.length() > 36) {
            safeFileTitle = safeFileTitle.substring(0, 36);
        }
        String fileName = safeFileTitle + "_" + LocalDate.now().format(DateTimeFormatter.BASIC_ISO_DATE) + ".docx";
        return new DocxExportResult(fileName, docxBytes, prepared.size());
    }

    private List<UserWrongQuestion> loadTargetWrongs(Long userId, AppQuizDTO.WrongExportReq req) {
        if (req.getWrongIds() != null && !req.getWrongIds().isEmpty()) {
            List<Long> cleanIds = req.getWrongIds().stream()
                    .filter(Objects::nonNull)
                    .distinct()
                    .limit(MAX_EXPORT_COUNT)
                    .toList();
            if (!cleanIds.isEmpty()) {
                List<UserWrongQuestion> fetched = wrongMapper.selectList(
                        new LambdaQueryWrapper<UserWrongQuestion>()
                                .eq(UserWrongQuestion::getUserId, userId)
                                .eq(UserWrongQuestion::getIsMastered, 0)
                                .in(UserWrongQuestion::getId, cleanIds)
                );
                Map<Long, UserWrongQuestion> byId = fetched.stream()
                        .collect(Collectors.toMap(UserWrongQuestion::getId, w -> w, (a, b) -> a));
                List<UserWrongQuestion> ordered = new ArrayList<>();
                for (Long id : cleanIds) {
                    UserWrongQuestion item = byId.get(id);
                    if (item != null) ordered.add(item);
                }
                return ordered;
            }
        }

        String effectiveGrade = (req.getRealmCode() != null && !req.getRealmCode().isBlank())
                ? realmHelper.resolveGradeCode(req.getRealmCode(), req.getGradeCode())
                : req.getGradeCode();

        LambdaQueryWrapper<UserWrongQuestion> wrapper = new LambdaQueryWrapper<UserWrongQuestion>()
                .eq(UserWrongQuestion::getUserId, userId)
                .eq(UserWrongQuestion::getIsMastered, 0);
        if (effectiveGrade != null && !effectiveGrade.isBlank()) {
            wrapper.eq(UserWrongQuestion::getGradeCode, effectiveGrade.trim());
        }
        if (Boolean.TRUE.equals(req.getHighFrequencyOnly())) {
            wrapper.ge(UserWrongQuestion::getWrongCount, 2);
        }
        wrapper.orderByDesc(UserWrongQuestion::getLastWrongAt).last("LIMIT " + MAX_EXPORT_COUNT);
        return wrongMapper.selectList(wrapper);
    }

    private String buildDefaultTitle(AppQuizDTO.WrongExportReq req, Map<String, EduRealm> realmByGrade) {
        if (Boolean.TRUE.equals(req.getHighFrequencyOnly())) {
            return "过关啦 · 高频错题专项巩固卷";
        }
        String grade = (req.getRealmCode() != null && !req.getRealmCode().isBlank())
                ? realmHelper.resolveGradeCode(req.getRealmCode(), req.getGradeCode())
                : req.getGradeCode();
        if (grade != null && realmByGrade.containsKey(grade)) {
            return "过关啦 · " + realmByGrade.get(grade).getRealmName() + "数学错题巩固卷";
        }
        return "过关啦 · 数学错题巩固卷";
    }

    private byte[] buildDocxPackage(
            String title,
            String studentName,
            String gradeName,
            String dateStr,
            List<PreparedItem> items,
            List<EmbeddedImage> images,
            int choiceCount,
            int essayCount,
            String answerMode,
            boolean includeWorkspace
    ) {
        try (ByteArrayOutputStream baos = new ByteArrayOutputStream();
             ZipOutputStream zos = new ZipOutputStream(baos, StandardCharsets.UTF_8)) {

            writeZipEntry(zos, "[Content_Types].xml", buildContentTypesXml(images));
            writeZipEntry(zos, "_rels/.rels", buildRootRelsXml());
            writeZipEntry(zos, "word/_rels/document.xml.rels", buildDocumentRelsXml(images));
            writeZipEntry(zos, "word/styles.xml", buildStylesXml());
            writeZipEntry(zos, "word/header1.xml", buildHeaderXml(title));
            writeZipEntry(zos, "word/footer1.xml", buildFooterXml());
            writeZipEntry(zos, "word/document.xml", buildDocumentXml(
                    title, studentName, gradeName, dateStr, items, choiceCount, essayCount, answerMode, includeWorkspace
            ));

            for (EmbeddedImage img : images) {
                ZipEntry entry = new ZipEntry("word/media/" + img.fileName());
                zos.putNextEntry(entry);
                zos.write(img.bytes());
                zos.closeEntry();
            }

            zos.finish();
            return baos.toByteArray();
        } catch (IOException e) {
            log.error("Failed to generate wrong-question docx", e);
            throw new BizException(ErrorCode.INTERNAL_ERROR, "生成 Word 文档失败");
        }
    }

    private void writeZipEntry(ZipOutputStream zos, String path, String content) throws IOException {
        ZipEntry entry = new ZipEntry(path);
        zos.putNextEntry(entry);
        zos.write(content.getBytes(StandardCharsets.UTF_8));
        zos.closeEntry();
    }

    private String buildContentTypesXml(List<EmbeddedImage> images) {
        boolean hasJpg = images.stream().anyMatch(i -> "jpg".equalsIgnoreCase(i.ext()) || "jpeg".equalsIgnoreCase(i.ext()));
        StringBuilder sb = new StringBuilder();
        sb.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>");
        sb.append("<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">");
        sb.append("<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>");
        sb.append("<Default Extension=\"xml\" ContentType=\"application/xml\"/>");
        sb.append("<Default Extension=\"png\" ContentType=\"image/png\"/>");
        if (hasJpg) {
            sb.append("<Default Extension=\"jpg\" ContentType=\"image/jpeg\"/>");
            sb.append("<Default Extension=\"jpeg\" ContentType=\"image/jpeg\"/>");
        }
        sb.append("<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>");
        sb.append("<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>");
        sb.append("<Override PartName=\"/word/header1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml\"/>");
        sb.append("<Override PartName=\"/word/footer1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml\"/>");
        sb.append("</Types>");
        return sb.toString();
    }

    private String buildRootRelsXml() {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
                + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                + "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>"
                + "</Relationships>";
    }

    private String buildDocumentRelsXml(List<EmbeddedImage> images) {
        StringBuilder sb = new StringBuilder();
        sb.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>");
        sb.append("<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">");
        sb.append("<Relationship Id=\"rIdStyles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>");
        sb.append("<Relationship Id=\"rIdHeader1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>");
        sb.append("<Relationship Id=\"rIdFooter1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"/>");
        for (EmbeddedImage img : images) {
            sb.append("<Relationship Id=\"").append(img.relId())
                    .append("\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/")
                    .append(img.fileName()).append("\"/>");
        }
        sb.append("</Relationships>");
        return sb.toString();
    }

    private String buildStylesXml() {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
                + "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                + "<w:docDefaults>"
                + "<w:rPrDefault><w:rPr>"
                + "<w:rFonts w:ascii=\"Calibri\" w:hAnsi=\"Calibri\" w:eastAsia=\"微软雅黑\" w:cs=\"Calibri\"/>"
                + "<w:sz w:val=\"21\"/><w:szCs w:val=\"21\"/><w:color w:val=\"1E293B\"/>"
                + "</w:rPr></w:rPrDefault>"
                + "<w:pPrDefault><w:pPr><w:spacing w:after=\"80\" w:line=\"280\" w:lineRule=\"auto\"/></w:pPr></w:pPrDefault>"
                + "</w:docDefaults>"
                + "<w:style w:type=\"paragraph\" w:default=\"1\" w:styleId=\"Normal\">"
                + "<w:name w:val=\"Normal\"/>"
                + "</w:style>"
                + "</w:styles>";
    }

    private String buildHeaderXml(String title) {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
                + "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                + "<w:p><w:pPr><w:pBdr><w:bottom w:val=\"single\" w:sz=\"4\" w:space=\"4\" w:color=\"CBD5E1\"/></w:pBdr>"
                + "<w:jc w:val=\"right\"/></w:pPr>"
                + "<w:r><w:rPr><w:rFonts w:eastAsia=\"微软雅黑\"/><w:sz w:val=\"17\"/><w:color w:val=\"64748B\"/></w:rPr>"
                + "<w:t>" + xmlEsc(title + "  ·  A4 打印整理版") + "</w:t></w:r>"
                + "</w:p></w:hdr>";
    }

    private String buildFooterXml() {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
                + "<w:ftr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                + "<w:p><w:pPr><w:pBdr><w:top w:val=\"single\" w:sz=\"4\" w:space=\"4\" w:color=\"E2E8F0\"/></w:pBdr>"
                + "<w:jc w:val=\"center\"/></w:pPr>"
                + textRun("第 ", 17, "64748B", false)
                + "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>"
                + "<w:r><w:instrText xml:space=\"preserve\"> PAGE </w:instrText></w:r>"
                + "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>"
                + textRun("1", 17, "64748B", false)
                + "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>"
                + textRun(" 页 / 共 ", 17, "64748B", false)
                + "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>"
                + "<w:r><w:instrText xml:space=\"preserve\"> NUMPAGES </w:instrText></w:r>"
                + "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>"
                + textRun("1", 17, "64748B", false)
                + "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>"
                + textRun(" 页    ·    过关啦数学错题本", 17, "94A3B8", false)
                + "</w:p></w:ftr>";
    }

    private String buildDocumentXml(
            String title,
            String studentName,
            String gradeName,
            String dateStr,
            List<PreparedItem> items,
            int choiceCount,
            int essayCount,
            String answerMode,
            boolean includeWorkspace
    ) {
        StringBuilder body = new StringBuilder();

        // 试卷标题
        body.append("<w:p><w:pPr><w:jc w:val=\"center\"/><w:spacing w:before=\"40\" w:after=\"100\"/></w:pPr>")
                .append(textRun(title, 34, "0F172A", true))
                .append("</w:p>");

        // 副标题元信息
        body.append("<w:p><w:pPr><w:jc w:val=\"center\"/><w:spacing w:after=\"180\"/></w:pPr>")
                .append(textRun("共收录 " + items.size() + " 道错题  |  导出日期：" + dateStr + "  |  纸张规格：标准 A4", 18, "64748B", false))
                .append("</w:p>");

        // 学生卷头信息栏
        body.append(buildStudentInfoTable(studentName, gradeName, dateStr));
        body.append("<w:p><w:pPr><w:spacing w:before=\"0\" w:after=\"120\"/></w:pPr></w:p>");

        boolean hasBothSections = choiceCount > 0 && essayCount > 0;
        boolean renderedChoiceHeader = false;
        boolean renderedEssayHeader = false;

        int imgDocPrId = 10;
        for (PreparedItem item : items) {
            if (hasBothSections) {
                if (!"ESSAY".equals(item.questionFormat()) && !renderedChoiceHeader) {
                    body.append(buildSectionHeading("一、选择题（共 " + choiceCount + " 题）"));
                    renderedChoiceHeader = true;
                } else if ("ESSAY".equals(item.questionFormat()) && !renderedEssayHeader) {
                    body.append(buildSectionHeading("二、解答题（共 " + essayCount + " 题）"));
                    renderedEssayHeader = true;
                }
            } else if (item.index() == 1) {
                String sectionTitle = choiceCount > 0
                        ? "一、选择错题巩固（共 " + choiceCount + " 题）"
                        : "一、解答错题巩固（共 " + essayCount + " 题）";
                body.append(buildSectionHeading(sectionTitle));
            }

            body.append(buildQuestionCardTable(item, answerMode, includeWorkspace, imgDocPrId++));
            body.append("<w:p><w:pPr><w:spacing w:before=\"0\" w:after=\"140\"/></w:pPr></w:p>");
        }

        // 末尾统一附参考答案与解题思路
        if ("END".equals(answerMode)) {
            body.append("<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>");
            body.append("<w:p><w:pPr><w:jc w:val=\"center\"/><w:spacing w:before=\"60\" w:after=\"180\"/></w:pPr>")
                    .append(textRun("参考答案与解题思路", 30, "0F172A", true))
                    .append("</w:p>");
            for (PreparedItem item : items) {
                body.append(buildAnswerKeyCard(item));
            }
        }

        // A4 节属性（210mm x 297mm）
        body.append("<w:sectPr>")
                .append("<w:headerReference w:type=\"default\" r:id=\"rIdHeader1\"/>")
                .append("<w:footerReference w:type=\"default\" r:id=\"rIdFooter1\"/>")
                .append("<w:pgSz w:w=\"11906\" w:h=\"16838\"/>")
                .append("<w:pgMar w:top=\"1134\" w:right=\"1134\" w:bottom=\"1134\" w:left=\"1134\" w:header=\"640\" w:footer=\"640\" w:gutter=\"0\"/>")
                .append("</w:sectPr>");

        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
                + "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\""
                + " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\""
                + " xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\""
                + " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\""
                + " xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
                + "<w:body>" + body + "</w:body></w:document>";
    }

    private String buildStudentInfoTable(String studentName, String gradeName, String dateStr) {
        int colW = PAGE_CONTENT_WIDTH_TWIPS / 4;
        String[] cells = {
                "姓名：" + studentName,
                "年级：" + gradeName,
                "日期：" + dateStr,
                "订正情况：□已掌握"
        };
        StringBuilder sb = new StringBuilder();
        sb.append("<w:tbl><w:tblPr>")
                .append("<w:tblW w:w=\"").append(PAGE_CONTENT_WIDTH_TWIPS).append("\" w:type=\"dxa\"/>")
                .append("<w:tblBorders>")
                .append("<w:top w:val=\"single\" w:sz=\"6\" w:space=\"0\" w:color=\"CBD5E1\"/>")
                .append("<w:bottom w:val=\"single\" w:sz=\"6\" w:space=\"0\" w:color=\"CBD5E1\"/>")
                .append("<w:left w:val=\"single\" w:sz=\"6\" w:space=\"0\" w:color=\"CBD5E1\"/>")
                .append("<w:right w:val=\"single\" w:sz=\"6\" w:space=\"0\" w:color=\"CBD5E1\"/>")
                .append("<w:insideV w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"E2E8F0\"/>")
                .append("</w:tblBorders></w:tblPr>");
        sb.append("<w:tr><w:trPr><w:cantSplit/></w:trPr>");
        for (String c : cells) {
            sb.append("<w:tc><w:tcPr>")
                    .append("<w:tcW w:w=\"").append(colW).append("\" w:type=\"dxa\"/>")
                    .append("<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"F8FAFC\"/>")
                    .append("<w:tcMar><w:top w:w=\"90\" w:type=\"dxa\"/><w:bottom w:w=\"90\" w:type=\"dxa\"/>")
                    .append("<w:left w:w=\"120\" w:type=\"dxa\"/><w:right w:w=\"120\" w:type=\"dxa\"/></w:tcMar>")
                    .append("</w:tcPr>")
                    .append("<w:p><w:pPr><w:spacing w:before=\"0\" w:after=\"0\"/></w:pPr>")
                    .append(textRun(c, 19, "334155", false))
                    .append("</w:p></w:tc>");
        }
        sb.append("</w:tr></w:tbl>");
        return sb.toString();
    }

    private String buildSectionHeading(String text) {
        return "<w:p><w:pPr><w:keepNext/><w:spacing w:before=\"120\" w:after=\"100\"/>"
                + "<w:pBdr><w:left w:val=\"single\" w:sz=\"24\" w:space=\"8\" w:color=\"0284C7\"/></w:pBdr></w:pPr>"
                + textRun(text, 24, "0F172A", true)
                + "</w:p>";
    }

    private String buildQuestionCardTable(PreparedItem item, String answerMode, boolean includeWorkspace, int docPrId) {
        StringBuilder sb = new StringBuilder();
        sb.append("<w:tbl><w:tblPr>")
                .append("<w:tblW w:w=\"").append(PAGE_CONTENT_WIDTH_TWIPS).append("\" w:type=\"dxa\"/>")
                .append("<w:tblBorders>")
                .append("<w:top w:val=\"single\" w:sz=\"6\" w:space=\"0\" w:color=\"CBD5E1\"/>")
                .append("<w:bottom w:val=\"single\" w:sz=\"6\" w:space=\"0\" w:color=\"CBD5E1\"/>")
                .append("<w:left w:val=\"single\" w:sz=\"6\" w:space=\"0\" w:color=\"CBD5E1\"/>")
                .append("<w:right w:val=\"single\" w:sz=\"6\" w:space=\"0\" w:color=\"CBD5E1\"/>")
                .append("<w:insideH w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"E2E8F0\"/>")
                .append("</w:tblBorders></w:tblPr>");

        // Row 1: 题目编号 + 来源标签 + 错次（禁止与题干分开）
        String sourceMeta = item.realmName() + " · " + item.chapterName() + " · " + item.gateName();
        String typeLabel = "ESSAY".equals(item.questionFormat()) ? "解答题" : "选择题";
        sb.append("<w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr>")
                .append("<w:tcW w:w=\"").append(PAGE_CONTENT_WIDTH_TWIPS).append("\" w:type=\"dxa\"/>")
                .append("<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"F1F5F9\"/>")
                .append("<w:tcMar><w:top w:w=\"75\" w:type=\"dxa\"/><w:bottom w:w=\"75\" w:type=\"dxa\"/>")
                .append("<w:left w:w=\"150\" w:type=\"dxa\"/><w:right w:w=\"150\" w:type=\"dxa\"/></w:tcMar>")
                .append("</w:tcPr>")
                .append("<w:p><w:pPr><w:keepNext/><w:spacing w:before=\"0\" w:after=\"0\"/></w:pPr>")
                .append(textRun("第 " + item.index() + " 题", 21, "0369A1", true))
                .append(textRun("  [" + typeLabel + "]  ", 18, "475569", true))
                .append(textRun(sourceMeta, 18, "64748B", false))
                .append(textRun("    ·    累计错 " + item.wrongCount() + " 次", 18, "DC2626", true))
                .append("</w:p></w:tc></w:tr>");

        // Row 2: 题干 + 配图 + 选项 + 作答区 + 可选随题解析（整块 cantSplit 防跨页撕裂）
        sb.append("<w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr>")
                .append("<w:tcW w:w=\"").append(PAGE_CONTENT_WIDTH_TWIPS).append("\" w:type=\"dxa\"/>")
                .append("<w:tcMar><w:top w:w=\"130\" w:type=\"dxa\"/><w:bottom w:w=\"130\" w:type=\"dxa\"/>")
                .append("<w:left w:w=\"160\" w:type=\"dxa\"/><w:right w:w=\"160\" w:type=\"dxa\"/></w:tcMar>")
                .append("</w:tcPr>");

        // 题干（支持多行）
        for (String line : item.stem().split("\\r?\\n")) {
            sb.append("<w:p><w:pPr><w:spacing w:before=\"0\" w:after=\"80\" w:line=\"300\" w:lineRule=\"auto\"/></w:pPr>")
                    .append(textRun(line, 22, "0F172A", false))
                    .append("</w:p>");
        }

        // 配图
        if (item.figureImage() != null) {
            sb.append(buildImageParagraph(item.figureImage(), docPrId));
        }

        // 选项排版
        if (!"ESSAY".equals(item.questionFormat()) && !item.options().isEmpty()) {
            boolean useTwoCol = item.options().size() == 4
                    && item.options().stream().allMatch(o -> o.length() <= 18 && !o.contains("\n"));
            if (useTwoCol) {
                sb.append(buildOptionsTwoColTable(item.options()));
            } else {
                for (int i = 0; i < item.options().size(); i++) {
                    String prefix = i < LETTERS.length ? LETTERS[i] + ". " : ((i + 1) + ". ");
                    sb.append("<w:p><w:pPr><w:ind w:left=\"220\"/><w:spacing w:before=\"20\" w:after=\"50\"/></w:pPr>")
                            .append(textRun(prefix, 21, "0369A1", true))
                            .append(textRun(item.options().get(i), 21, "1E293B", false))
                            .append("</w:p>");
                }
            }
        }

        // 预留手写作答区
        if (includeWorkspace) {
            int blankLines = "ESSAY".equals(item.questionFormat()) ? 5 : 2;
            sb.append("<w:p><w:pPr><w:spacing w:before=\"100\" w:after=\"40\"/>"
                            + "<w:pBdr><w:top w:val=\"dashed\" w:sz=\"4\" w:space=\"4\" w:color=\"CBD5E1\"/></w:pBdr></w:pPr>")
                    .append(textRun("订正 / 演算区：", 18, "94A3B8", false))
                    .append("</w:p>");
            for (int l = 0; l < blankLines; l++) {
                sb.append("<w:p><w:pPr><w:spacing w:before=\"0\" w:after=\"120\"/></w:pPr></w:p>");
            }
        }

        // 随题附答案与解析
        if ("INLINE".equals(answerMode)) {
            sb.append("<w:p><w:pPr><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"F0FDF4\"/>"
                            + "<w:spacing w:before=\"80\" w:after=\"40\"/></w:pPr>")
                    .append(textRun("【参考答案】", 19, "15803D", true))
                    .append(textRun(formatCorrectAnswer(item), 19, "166534", true))
                    .append("</w:p>");
            if (!item.analysis().isBlank()) {
                sb.append("<w:p><w:pPr><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"F0FDF4\"/>"
                                + "<w:spacing w:before=\"0\" w:after=\"60\"/></w:pPr>")
                        .append(textRun("【解题思路】", 19, "15803D", true))
                        .append(textRun(item.analysis(), 19, "334155", false))
                        .append("</w:p>");
            }
        }

        sb.append("</w:tc></w:tr></w:tbl>");
        return sb.toString();
    }

    private String buildOptionsTwoColTable(List<String> options) {
        int innerW = PAGE_CONTENT_WIDTH_TWIPS - 360;
        int halfW = innerW / 2;
        StringBuilder sb = new StringBuilder();
        sb.append("<w:tbl><w:tblPr>")
                .append("<w:tblW w:w=\"").append(innerW).append("\" w:type=\"dxa\"/>")
                .append("<w:tblBorders>")
                .append("<w:top w:val=\"none\"/><w:bottom w:val=\"none\"/><w:left w:val=\"none\"/>")
                .append("<w:right w:val=\"none\"/><w:insideH w:val=\"none\"/><w:insideV w:val=\"none\"/>")
                .append("</w:tblBorders></w:tblPr>");
        for (int row = 0; row < 2; row++) {
            sb.append("<w:tr><w:trPr><w:cantSplit/></w:trPr>");
            for (int col = 0; col < 2; col++) {
                int idx = row * 2 + col;
                sb.append("<w:tc><w:tcPr><w:tcW w:w=\"").append(halfW).append("\" w:type=\"dxa\"/>")
                        .append("<w:tcMar><w:top w:w=\"40\" w:type=\"dxa\"/><w:bottom w:w=\"40\" w:type=\"dxa\"/>")
                        .append("<w:left w:w=\"80\" w:type=\"dxa\"/><w:right w:w=\"80\" w:type=\"dxa\"/></w:tcMar></w:tcPr>")
                        .append("<w:p><w:pPr><w:spacing w:before=\"0\" w:after=\"0\"/></w:pPr>")
                        .append(textRun(LETTERS[idx] + ". ", 21, "0369A1", true))
                        .append(textRun(options.get(idx), 21, "1E293B", false))
                        .append("</w:p></w:tc>");
            }
            sb.append("</w:tr>");
        }
        sb.append("</w:tbl>");
        return sb.toString();
    }

    private String buildAnswerKeyCard(PreparedItem item) {
        StringBuilder sb = new StringBuilder();
        sb.append("<w:p><w:pPr><w:spacing w:before=\"80\" w:after=\"40\"/>"
                        + "<w:pBdr><w:bottom w:val=\"single\" w:sz=\"4\" w:space=\"4\" w:color=\"E2E8F0\"/></w:pBdr></w:pPr>")
                .append(textRun("第 " + item.index() + " 题  ", 20, "0369A1", true))
                .append(textRun("参考答案：" + formatCorrectAnswer(item), 20, "15803D", true));
        if (!item.analysis().isBlank()) {
            sb.append("<w:r><w:br/></w:r>")
                    .append(textRun("解题思路：" + item.analysis(), 19, "475569", false));
        }
        sb.append("</w:p>");
        return sb.toString();
    }

    private String buildImageParagraph(EmbeddedImage img, int docPrId) {
        return "<w:p><w:pPr><w:jc w:val=\"center\"/><w:spacing w:before=\"60\" w:after=\"80\"/></w:pPr>"
                + "<w:r><w:drawing>"
                + "<wp:inline distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\">"
                + "<wp:extent cx=\"" + img.cxEmu() + "\" cy=\"" + img.cyEmu() + "\"/>"
                + "<wp:effectExtent l=\"0\" t=\"0\" r=\"0\" b=\"0\"/>"
                + "<wp:docPr id=\"" + docPrId + "\" name=\"Figure_" + docPrId + "\"/>"
                + "<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect=\"1\"/></wp:cNvGraphicFramePr>"
                + "<a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
                + "<pic:pic>"
                + "<pic:nvPicPr><pic:cNvPr id=\"" + docPrId + "\" name=\"" + img.fileName() + "\"/><pic:cNvPicPr/></pic:nvPicPr>"
                + "<pic:blipFill><a:blip r:embed=\"" + img.relId() + "\"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>"
                + "<pic:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"" + img.cxEmu() + "\" cy=\"" + img.cyEmu() + "\"/></a:xfrm>"
                + "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></pic:spPr>"
                + "</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>";
    }

    private String textRun(String text, int halfPts, String hexColor, boolean bold) {
        StringBuilder sb = new StringBuilder("<w:r><w:rPr>");
        sb.append("<w:rFonts w:ascii=\"Calibri\" w:hAnsi=\"Calibri\" w:eastAsia=\"微软雅黑\" w:cs=\"Calibri\"/>");
        if (bold) sb.append("<w:b/>");
        sb.append("<w:color w:val=\"").append(hexColor).append("\"/>");
        sb.append("<w:sz w:val=\"").append(halfPts).append("\"/><w:szCs w:val=\"").append(halfPts).append("\"/>");
        sb.append("</w:rPr><w:t xml:space=\"preserve\">").append(xmlEsc(text)).append("</w:t></w:r>");
        return sb.toString();
    }

    private String formatCorrectAnswer(PreparedItem item) {
        if ("ESSAY".equals(item.questionFormat())) {
            return item.referenceAnswer().isBlank() ? "见解析" : item.referenceAnswer();
        }
        int idx = item.answerIndex();
        if (idx >= 0 && idx < item.options().size()) {
            String letter = idx < LETTERS.length ? LETTERS[idx] : String.valueOf(idx + 1);
            return letter + ". " + item.options().get(idx);
        }
        return item.referenceAnswer().isBlank() ? "见解析" : item.referenceAnswer();
    }

    @SuppressWarnings("unchecked")
    private EmbeddedImage buildFigureImage(EduQuestion q, int imgIdx) {
        if (q == null || q.getExtJson() == null || q.getExtJson().isBlank()) {
            return null;
        }
        Map<String, Object> ext = JsonHelper.readMap(objectMapper, q.getExtJson());
        if (ext == null || ext.isEmpty()) {
            return null;
        }

        // 1. 优先将矢量几何图渲染为 2x 高清 PNG
        if (ext.get("diagram") instanceof Map<?, ?> rawDiag && !rawDiag.isEmpty()) {
            try {
                byte[] png = renderDiagramToPng((Map<String, Object>) rawDiag);
                if (png != null && png.length > 0) {
                    return createEmbeddedImage(imgIdx, "png", png);
                }
            } catch (Exception e) {
                log.debug("Failed to render diagram PNG for qId={}: {}", q.getId(), e.getMessage());
            }
        }

        // 2. 回退读取上传的图片配图
        Object rawImg = ext.get("imageKey");
        if (rawImg == null || String.valueOf(rawImg).isBlank()) {
            rawImg = ext.get("imageUrl");
        }
        if (rawImg != null && !String.valueOf(rawImg).isBlank()) {
            try {
                AliyunOssService.BinaryResource bin = ossService.readObjectBytes(String.valueOf(rawImg).trim());
                if (bin != null && bin.bytes() != null && bin.bytes().length > 0) {
                    String extName = bin.contentType() != null && bin.contentType().contains("jpeg") ? "jpg" : "png";
                    return createEmbeddedImage(imgIdx, extName, bin.bytes());
                }
            } catch (Exception e) {
                log.debug("Failed to read uploaded figure for qId={}: {}", q.getId(), e.getMessage());
            }
        }
        return null;
    }

    private EmbeddedImage createEmbeddedImage(int imgIdx, String ext, byte[] bytes) {
        int pxW = 600;
        int pxH = 380;
        try {
            BufferedImage bi = ImageIO.read(new ByteArrayInputStream(bytes));
            if (bi != null && bi.getWidth() > 0 && bi.getHeight() > 0) {
                pxW = bi.getWidth();
                pxH = bi.getHeight();
            }
        } catch (Exception ignored) {
            // Use fallback aspect ratio
        }
        // 最大宽 86mm，最大高 56mm（1mm = 36000 EMU）
        double maxWmm = 86.0;
        double maxHmm = 56.0;
        double ratio = (double) pxW / pxH;
        double wMm = maxWmm;
        double hMm = wMm / ratio;
        if (hMm > maxHmm) {
            hMm = maxHmm;
            wMm = hMm * ratio;
        }
        long cx = Math.round(wMm * 36000.0);
        long cy = Math.round(hMm * 36000.0);
        return new EmbeddedImage("rIdImg" + imgIdx, "img_" + imgIdx + "." + ext, ext, bytes, cx, cy);
    }

    @SuppressWarnings("unchecked")
    private byte[] renderDiagramToPng(Map<String, Object> diagram) throws IOException {
        List<?> primitives = diagram.get("primitives") instanceof List<?> list ? list : List.of();
        if (primitives.isEmpty()) return null;

        double srcW = asDouble(diagram.get("width"), 320.0);
        double srcH = asDouble(diagram.get("height"), 210.0);
        double scale = 2.0;
        int outW = Math.max(240, (int) Math.round(srcW * scale));
        int outH = Math.max(160, (int) Math.round(srcH * scale));

        BufferedImage bi = new BufferedImage(outW, outH, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = bi.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
            g.setColor(Color.WHITE);
            g.fillRect(0, 0, outW, outH);
            g.scale(scale, scale);

            for (Object obj : primitives) {
                if (!(obj instanceof Map<?, ?> raw)) continue;
                Map<String, Object> p = (Map<String, Object>) raw;
                String type = safeStr(p.get("type"));
                Color strokeCol = parseHexColor(safeStr(p.get("color")), new Color(0x1E, 0x29, 0x3B));
                Color fillCol = parseOptionalHexColor(p.get("fillColor") != null ? safeStr(p.get("fillColor")) : safeStr(p.get("fill")));
                float sw = (float) asDouble(p.get("strokeWidth"), 1.9);
                boolean dashed = Boolean.TRUE.equals(p.get("dashed"));
                Stroke stroke = dashed
                        ? new BasicStroke(sw, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND, 10f, new float[]{5f, 4f}, 0f)
                        : new BasicStroke(sw, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND);

                switch (type) {
                    case "line" -> {
                        g.setColor(strokeCol);
                        g.setStroke(stroke);
                        g.draw(new Line2D.Double(
                                asDouble(p.get("x1"), 0), asDouble(p.get("y1"), 0),
                                asDouble(p.get("x2"), 0), asDouble(p.get("y2"), 0)
                        ));
                    }
                    case "arrow" -> {
                        double x1 = asDouble(p.get("x1"), 0), y1 = asDouble(p.get("y1"), 0);
                        double x2 = asDouble(p.get("x2"), 0), y2 = asDouble(p.get("y2"), 0);
                        g.setColor(strokeCol);
                        g.setStroke(stroke);
                        g.draw(new Line2D.Double(x1, y1, x2, y2));
                        double ang = Math.atan2(y2 - y1, x2 - x1);
                        double hl = 7.5;
                        Path2D.Double head = new Path2D.Double();
                        head.moveTo(x2, y2);
                        head.lineTo(x2 - hl * Math.cos(ang - Math.PI / 6), y2 - hl * Math.sin(ang - Math.PI / 6));
                        head.lineTo(x2 - hl * Math.cos(ang + Math.PI / 6), y2 - hl * Math.sin(ang + Math.PI / 6));
                        head.closePath();
                        g.fill(head);
                    }
                    case "circle" -> {
                        double cx = asDouble(p.get("cx"), 0), cy = asDouble(p.get("cy"), 0), r = asDouble(p.get("r"), 20);
                        Ellipse2D.Double oval = new Ellipse2D.Double(cx - r, cy - r, r * 2, r * 2);
                        if (fillCol != null) {
                            g.setColor(new Color(fillCol.getRed(), fillCol.getGreen(), fillCol.getBlue(), 52));
                            g.fill(oval);
                        }
                        g.setColor(strokeCol);
                        g.setStroke(stroke);
                        g.draw(oval);
                    }
                    case "arc" -> {
                        double cx = asDouble(p.get("cx"), 0), cy = asDouble(p.get("cy"), 0), r = asDouble(p.get("r"), 18);
                        double startDeg = asDouble(p.get("startAngle"), 0);
                        double sweepDeg = asDouble(p.get("sweepAngle"), 90);
                        // Java2D Arc2D angles are CCW from 3 o'clock, SVG/Canvas are CW
                        Arc2D.Double arc = new Arc2D.Double(cx - r, cy - r, r * 2, r * 2, -startDeg, -sweepDeg,
                                fillCol != null ? Arc2D.PIE : Arc2D.OPEN);
                        if (fillCol != null) {
                            g.setColor(new Color(fillCol.getRed(), fillCol.getGreen(), fillCol.getBlue(), 52));
                            g.fill(arc);
                        }
                        g.setColor(strokeCol);
                        g.setStroke(stroke);
                        g.draw(new Arc2D.Double(cx - r, cy - r, r * 2, r * 2, -startDeg, -sweepDeg, Arc2D.OPEN));
                    }
                    case "rightAngle" -> {
                        double vx = asDouble(p.get("vx"), 0), vy = asDouble(p.get("vy"), 0);
                        double ax = asDouble(p.get("ax"), 0), ay = asDouble(p.get("ay"), 0);
                        double bx = asDouble(p.get("bx"), 0), by = asDouble(p.get("by"), 0);
                        double sz = asDouble(p.get("size"), 11);
                        double da = Math.hypot(ax - vx, ay - vy);
                        double db = Math.hypot(bx - vx, by - vy);
                        if (da > 0 && db > 0) {
                            double ux = (ax - vx) / da * sz, uy = (ay - vy) / da * sz;
                            double wx = (bx - vx) / db * sz, wy = (by - vy) / db * sz;
                            Path2D.Double rp = new Path2D.Double();
                            rp.moveTo(vx + ux, vy + uy);
                            rp.lineTo(vx + ux + wx, vy + uy + wy);
                            rp.lineTo(vx + wx, vy + wy);
                            g.setColor(strokeCol);
                            g.setStroke(new BasicStroke(1.5f));
                            g.draw(rp);
                        }
                    }
                    case "polygon", "polyline" -> {
                        List<double[]> pts = extractPoints(p.get("points"));
                        if (pts.size() >= 2) {
                            Path2D.Double path = new Path2D.Double();
                            path.moveTo(pts.get(0)[0], pts.get(0)[1]);
                            for (int i = 1; i < pts.size(); i++) {
                                path.lineTo(pts.get(i)[0], pts.get(i)[1]);
                            }
                            if ("polygon".equals(type)) {
                                path.closePath();
                                if (fillCol != null) {
                                    g.setColor(new Color(fillCol.getRed(), fillCol.getGreen(), fillCol.getBlue(), 45));
                                    g.fill(path);
                                }
                            }
                            g.setColor(strokeCol);
                            g.setStroke(stroke);
                            g.draw(path);
                        }
                    }
                    case "point" -> {
                        double x = asDouble(p.get("x"), 0), y = asDouble(p.get("y"), 0);
                        g.setColor(strokeCol);
                        g.fill(new Ellipse2D.Double(x - 3.0, y - 3.0, 6.0, 6.0));
                        String lbl = safeStr(p.get("label"));
                        if (!lbl.isBlank()) {
                            g.setFont(resolveFont(Font.BOLD, 12));
                            g.drawString(lbl, (float) (x + 5), (float) (y - 4));
                        }
                    }
                    case "text" -> {
                        double x = asDouble(p.get("x"), 0), y = asDouble(p.get("y"), 0);
                        String txt = safeStr(p.get("text"));
                        if (!txt.isBlank()) {
                            g.setColor(strokeCol);
                            g.setFont(resolveFont(Font.BOLD, (int) Math.round(asDouble(p.get("fontSize"), 12))));
                            g.drawString(txt, (float) x, (float) (y + 11));
                        }
                    }
                    default -> {
                        // Ignore unknown primitives
                    }
                }
            }
        } finally {
            g.dispose();
        }
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        ImageIO.write(bi, "png", baos);
        return baos.toByteArray();
    }

    private List<double[]> extractPoints(Object raw) {
        if (!(raw instanceof List<?> list)) return List.of();
        List<double[]> result = new ArrayList<>();
        for (Object item : list) {
            if (item instanceof List<?> pair && pair.size() >= 2) {
                result.add(new double[]{asDouble(pair.get(0), 0), asDouble(pair.get(1), 0)});
            }
        }
        return result;
    }

    private Color parseHexColor(String hex, Color fallback) {
        Color c = parseOptionalHexColor(hex);
        return c != null ? c : fallback;
    }

    private Color parseOptionalHexColor(String hex) {
        if (hex == null || hex.isBlank() || "none".equalsIgnoreCase(hex.trim())) return null;
        String clean = hex.trim().replace("#", "");
        if (clean.length() != 6) return null;
        try {
            return new Color(Integer.parseInt(clean, 16));
        } catch (Exception e) {
            return null;
        }
    }

    private Font resolveFont(int style, int size) {
        String[] candidates = {"Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", Font.SANS_SERIF};
        for (String name : candidates) {
            Font f = new Font(name, style, size);
            if (f.canDisplay('数')) return f;
        }
        return new Font(Font.SANS_SERIF, style, size);
    }

    /** 将常见 LaTeX 数学记号美化为适合 Word A4 纸清晰排版的 Unicode 数学文本 */
    public static String formatMathText(String raw) {
        if (raw == null || raw.isBlank()) return "";
        String s = raw.replace("\\n", "\n");
        s = s.replace("$$", "").replace("$", "");

        // 反复展开 \frac{a}{b} -> (a)/(b) 或 a/b
        for (int i = 0; i < 4; i++) {
            Matcher m = FRAC_PATTERN.matcher(s);
            if (!m.find()) break;
            s = m.replaceAll(mr -> {
                String num = mr.group(1).trim();
                String den = mr.group(2).trim();
                String left = num.length() > 1 && num.matches(".*[+\\-\\s].*") ? "(" + num + ")" : num;
                String right = den.length() > 1 && den.matches(".*[+\\-\\s].*") ? "(" + den + ")" : den;
                return left + "/" + right;
            });
        }
        for (int i = 0; i < 3; i++) {
            Matcher m = SQRT_PATTERN.matcher(s);
            if (!m.find()) break;
            s = m.replaceAll(mr -> {
                String inner = mr.group(1).trim();
                return inner.length() == 1 ? "√" + inner : "√(" + inner + ")";
            });
        }

        s = s.replace("\\times", "×")
                .replace("\\cdot", "·")
                .replace("\\div", "÷")
                .replace("\\pm", "±")
                .replace("\\mp", "∓")
                .replace("\\le", "≤")
                .replace("\\leq", "≤")
                .replace("\\ge", "≥")
                .replace("\\geq", "≥")
                .replace("\\ne", "≠")
                .replace("\\neq", "≠")
                .replace("\\approx", "≈")
                .replace("\\equiv", "≡")
                .replace("\\infty", "∞")
                .replace("\\pi", "π")
                .replace("\\alpha", "α")
                .replace("\\beta", "β")
                .replace("\\gamma", "γ")
                .replace("\\theta", "θ")
                .replace("\\Delta", "Δ")
                .replace("\\angle", "∠")
                .replace("\\triangle", "△")
                .replace("\\perp", "⊥")
                .replace("\\parallel", "∥")
                .replace("\\cong", "≌")
                .replace("\\sim", "∽")
                .replace("\\circ", "°")
                .replace("\\in", "∈")
                .replace("\\notin", "∉")
                .replace("\\subset", "⊂")
                .replace("\\subseteq", "⊆")
                .replace("\\cup", "∪")
                .replace("\\cap", "∩")
                .replace("\\emptyset", "∅")
                .replace("\\forall", "∀")
                .replace("\\exists", "∃")
                .replace("\\Rightarrow", "⇒")
                .replace("\\rightarrow", "→")
                .replace("\\to", "→")
                .replace("\\left", "")
                .replace("\\right", "")
                .replace("\\,", " ")
                .replace("\\;", " ")
                .replace("\\quad", "  ")
                .replace("\\{", "{")
                .replace("\\}", "}");

        s = replaceSuperscripts(s);
        s = replaceSubscripts(s);
        return s.trim();
    }

    private static String replaceSuperscripts(String s) {
        Matcher m = SUP_BRACE_PATTERN.matcher(s);
        StringBuffer sb = new StringBuffer();
        while (m.find()) {
            String inner = m.group(1).trim();
            String mapped = toSup(inner);
            m.appendReplacement(sb, Matcher.quoteReplacement(mapped != null ? mapped : "^(" + inner + ")"));
        }
        m.appendTail(sb);
        return sb.toString()
                .replace("^2", "²")
                .replace("^3", "³")
                .replace("^0", "⁰")
                .replace("^1", "¹");
    }

    private static String replaceSubscripts(String s) {
        Matcher m = SUB_BRACE_PATTERN.matcher(s);
        StringBuffer sb = new StringBuffer();
        while (m.find()) {
            String inner = m.group(1).trim();
            String mapped = toSub(inner);
            m.appendReplacement(sb, Matcher.quoteReplacement(mapped != null ? mapped : "_" + inner));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    private static String toSup(String raw) {
        StringBuilder out = new StringBuilder();
        for (char c : raw.toCharArray()) {
            switch (c) {
                case '0' -> out.append('⁰');
                case '1' -> out.append('¹');
                case '2' -> out.append('²');
                case '3' -> out.append('³');
                case '4' -> out.append('⁴');
                case '5' -> out.append('⁵');
                case '6' -> out.append('⁶');
                case '7' -> out.append('⁷');
                case '8' -> out.append('⁸');
                case '9' -> out.append('⁹');
                case '+' -> out.append('⁺');
                case '-' -> out.append('⁻');
                case 'n' -> out.append('ⁿ');
                default -> {
                    return null;
                }
            }
        }
        return out.toString();
    }

    private static String toSub(String raw) {
        StringBuilder out = new StringBuilder();
        for (char c : raw.toCharArray()) {
            switch (c) {
                case '0' -> out.append('₀');
                case '1' -> out.append('₁');
                case '2' -> out.append('₂');
                case '3' -> out.append('₃');
                case '4' -> out.append('₄');
                case '5' -> out.append('₅');
                case '6' -> out.append('₆');
                case '7' -> out.append('₇');
                case '8' -> out.append('₈');
                case '9' -> out.append('₉');
                default -> {
                    return null;
                }
            }
        }
        return out.toString();
    }

    private Map<Long, EduQuestion> loadQuestionMap(List<UserWrongQuestion> list) {
        Set<Long> ids = list.stream().map(UserWrongQuestion::getQuestionId).filter(Objects::nonNull).collect(Collectors.toSet());
        if (ids.isEmpty()) return Map.of();
        return questionMapper.selectBatchIds(ids).stream()
                .collect(Collectors.toMap(EduQuestion::getId, q -> q, (a, b) -> a));
    }

    private int parseAnswerIndex(String json) {
        try {
            JsonNode node = JsonHelper.readTree(objectMapper, json);
            return node != null ? node.path("index").asInt(0) : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    private String parseReferenceAnswer(String json) {
        try {
            JsonNode node = JsonHelper.readTree(objectMapper, json);
            return node != null ? node.path("text").asText("") : "";
        } catch (Exception e) {
            return "";
        }
    }

    private String normalizeAnswerMode(String raw) {
        if (raw == null || raw.isBlank()) return "END";
        String up = raw.trim().toUpperCase(Locale.ROOT);
        if ("INLINE".equals(up) || "NONE".equals(up) || "END".equals(up)) {
            return up;
        }
        return "END";
    }

    private double asDouble(Object v, double fallback) {
        if (v instanceof Number n) return n.doubleValue();
        if (v != null) {
            try {
                return Double.parseDouble(String.valueOf(v));
            } catch (Exception ignored) {
                // ignore
            }
        }
        return fallback;
    }

    private String safeStr(Object v) {
        return v == null ? "" : String.valueOf(v);
    }

    private String xmlEsc(String raw) {
        if (raw == null) return "";
        return raw.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&apos;");
    }
}
