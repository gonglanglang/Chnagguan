package com.guoguanla;

import com.guoguanla.module.oss.AliyunOssService;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

class AliyunOssServiceTests {

    @Test
    void presignedGetUrlAndHmacSignatureShouldBeValidFormat() {
        AliyunOssService service = new AliyunOssService();
        ReflectionTestUtils.setField(service, "ossEnabled", true);
        ReflectionTestUtils.setField(service, "endpoint", "oss-cn-beijing.aliyuncs.com");
        ReflectionTestUtils.setField(service, "bucket", "chuangguan2026");
        ReflectionTestUtils.setField(service, "accessKeyId", "testAccessKeyId");
        ReflectionTestUtils.setField(service, "accessKeySecret", "testAccessKeySecret");

        assertTrue(service.isOssConfigured());
        String signed = service.resolveViewUrl("essay-answers/20261121/u5_QZ123_i0_abcd.png", "http://47.107.94.90");
        assertTrue(signed.startsWith("https://chuangguan2026.oss-cn-beijing.aliyuncs.com/essay-answers/20261121/u5_QZ123_i0_abcd.png?"));
        assertTrue(signed.contains("OSSAccessKeyId=testAccessKeyId"));
        assertTrue(signed.contains("Expires="));
        assertTrue(signed.contains("Signature="));

        // Relative /downloads fallback should resolve against baseOrigin
        assertEquals(
                "http://47.107.94.90/downloads/essay-answers/test.png",
                service.resolveViewUrl("/downloads/essay-answers/test.png", "http://47.107.94.90")
        );
    }
}
