package com.guoguanla;

import com.guoguanla.common.exception.BizException;
import com.guoguanla.module.oss.AliyunOssService;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class AliyunOssServiceTests {

    @Test
    void presignedGetUrlAndHmacSignatureShouldBeValidFormat() {
        AliyunOssService service = new AliyunOssService();
        ReflectionTestUtils.setField(service, "ossEnabled", true);
        ReflectionTestUtils.setField(service, "endpoint", "oss-cn-shenzhen.aliyuncs.com");
        ReflectionTestUtils.setField(service, "bucket", "chuangguang");
        ReflectionTestUtils.setField(service, "accessKeyId", "testAccessKeyId");
        ReflectionTestUtils.setField(service, "accessKeySecret", "testAccessKeySecret");

        assertTrue(service.isOssConfigured());
        String signed = service.resolveViewUrl("essay-answers/20261121/u5_QZ123_i0_abcd.png", "http://47.107.94.90");
        assertTrue(signed.startsWith("https://chuangguang.oss-cn-shenzhen.aliyuncs.com/essay-answers/20261121/u5_QZ123_i0_abcd.png?"));
        assertTrue(signed.contains("OSSAccessKeyId=testAccessKeyId"));
        assertTrue(signed.contains("Expires="));
        assertTrue(signed.contains("Signature="));

        // Relative /downloads fallback should resolve against baseOrigin
        assertEquals(
                "http://47.107.94.90/downloads/essay-answers/test.png",
                service.resolveViewUrl("/downloads/essay-answers/test.png", "http://47.107.94.90")
        );
    }

    @Test
    void presignedPartUploadUrlAndListPartsXmlShouldBeValid() throws Exception {
        AliyunOssService service = new AliyunOssService();
        ReflectionTestUtils.setField(service, "ossEnabled", true);
        ReflectionTestUtils.setField(service, "endpoint", "oss-cn-shenzhen.aliyuncs.com");
        ReflectionTestUtils.setField(service, "bucket", "chuangguang");
        ReflectionTestUtils.setField(service, "accessKeyId", "testAccessKeyId");
        ReflectionTestUtils.setField(service, "accessKeySecret", "testAccessKeySecret");

        String objectKey = "course-videos/20261122/lesson_test123.mp4";
        String uploadId = "0004B9894A22E5B1888A1E29F8236E2D";
        String partUrl = service.generatePresignedPartUploadUrl(objectKey, uploadId, 2, 3600);

        assertTrue(partUrl.startsWith("https://chuangguang.oss-cn-shenzhen.aliyuncs.com/" + objectKey + "?partNumber=2&uploadId=" + uploadId));
        URI uri = URI.create(partUrl);
        Map<String, String> query = new HashMap<>();
        for (String pair : uri.getRawQuery().split("&")) {
            int idx = pair.indexOf('=');
            if (idx > 0) {
                query.put(pair.substring(0, idx), URLDecoder.decode(pair.substring(idx + 1), StandardCharsets.UTF_8));
            }
        }
        assertEquals("2", query.get("partNumber"));
        assertEquals(uploadId, query.get("uploadId"));
        assertEquals("testAccessKeyId", query.get("OSSAccessKeyId"));
        assertNotNull(query.get("Expires"));

        String expectedStringToSign = "PUT\n\napplication/octet-stream\n"
                + query.get("Expires")
                + "\n/chuangguang/" + objectKey + "?partNumber=2&uploadId=" + uploadId;
        Mac mac = Mac.getInstance("HmacSHA1");
        mac.init(new SecretKeySpec("testAccessKeySecret".getBytes(StandardCharsets.UTF_8), "HmacSHA1"));
        String expectedSig = Base64.getEncoder().encodeToString(mac.doFinal(expectedStringToSign.getBytes(StandardCharsets.UTF_8)));
        assertEquals(expectedSig, query.get("Signature"));
        assertTrue(partUrl.contains("Signature=" + URLEncoder.encode(expectedSig, StandardCharsets.UTF_8)));

        String listPartsXml = """
                <?xml version="1.0" encoding="UTF-8"?>
                <ListPartsResult>
                  <Bucket>chuangguang</Bucket>
                  <Key>course-videos/20261122/lesson_test123.mp4</Key>
                  <UploadId>0004B9894A22E5B1888A1E29F8236E2D</UploadId>
                  <IsTruncated>true</IsTruncated>
                  <NextPartNumberMarker>2</NextPartNumberMarker>
                  <Part><PartNumber>1</PartNumber><ETag>"ETAG-111"</ETag><Size>5242880</Size></Part>
                  <Part><PartNumber>2</PartNumber><ETag>"ETAG-222"</ETag><Size>1024</Size></Part>
                </ListPartsResult>
                """;
        AliyunOssService.ListPartsPage parsed = AliyunOssService.parseListPartsXml(listPartsXml);
        assertTrue(parsed.truncated());
        assertEquals("2", parsed.nextMarker());
        assertEquals("\"ETAG-111\"", parsed.partETags().get(1));
        assertEquals("\"ETAG-222\"", parsed.partETags().get(2));
    }

    @Test
    void appApkDirectPutPresignAndKeySanitizationShouldWork() throws Exception {
        AliyunOssService service = new AliyunOssService();
        ReflectionTestUtils.setField(service, "ossEnabled", true);
        ReflectionTestUtils.setField(service, "endpoint", "oss-cn-shenzhen.aliyuncs.com");
        ReflectionTestUtils.setField(service, "bucket", "chuangguang");
        ReflectionTestUtils.setField(service, "accessKeyId", "testAccessKeyId");
        ReflectionTestUtils.setField(service, "accessKeySecret", "testAccessKeySecret");

        AliyunOssService.DirectPutInitResult init = service.initAppApkDirectUpload("app-v1.0.12.apk", "v1.0.12");
        assertTrue(init.directUpload());
        assertEquals("ALIYUN_OSS", init.storageType());
        assertEquals("app-releases/guoguanla-v1.0.12.apk", init.objectKey());
        assertEquals("application/vnd.android.package-archive", init.contentType());
        assertTrue(init.uploadUrl().startsWith("https://chuangguang.oss-cn-shenzhen.aliyuncs.com/app-releases/guoguanla-v1.0.12.apk?"));

        URI uri = URI.create(init.uploadUrl());
        Map<String, String> query = new HashMap<>();
        for (String pair : uri.getRawQuery().split("&")) {
            int idx = pair.indexOf('=');
            if (idx > 0) {
                query.put(pair.substring(0, idx), URLDecoder.decode(pair.substring(idx + 1), StandardCharsets.UTF_8));
            }
        }
        String expectedStringToSign = "PUT\n\napplication/vnd.android.package-archive\n"
                + query.get("Expires")
                + "\n/chuangguang/app-releases/guoguanla-v1.0.12.apk";
        Mac mac = Mac.getInstance("HmacSHA1");
        mac.init(new SecretKeySpec("testAccessKeySecret".getBytes(StandardCharsets.UTF_8), "HmacSHA1"));
        String expectedSig = Base64.getEncoder().encodeToString(mac.doFinal(expectedStringToSign.getBytes(StandardCharsets.UTF_8)));
        assertEquals(expectedSig, query.get("Signature"));

        assertThrows(BizException.class, () -> service.sanitizeAppApkKey("app-releases/../evil.apk"));
        assertThrows(BizException.class, () -> service.sanitizeAppApkKey("other-dir/app.apk"));
        assertThrows(BizException.class, () -> service.initAppApkDirectUpload("bad.exe", "1.0.0"));

        ReflectionTestUtils.setField(service, "customDomain", "dl.guoguanla.com");
        assertTrue(service.hasCustomDomain());
        assertTrue(service.resolveViewUrl("app-releases/guoguanla-v1.0.12.apk", "http://47.107.94.90")
                .startsWith("https://dl.guoguanla.com/app-releases/guoguanla-v1.0.12.apk?"));
    }
}
