package com.guoguanla;

import com.guoguanla.module.system.AppVersionService;
import com.guoguanla.module.system.vo.AppVersionVO;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AppVersionServiceTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private AppVersionService appVersionService;

    @Test
    void versionCheckEndpointShouldReturnLatestWithoutAuth() throws Exception {
        mockMvc.perform(get("/api/app/version/latest")
                        .param("currentVersion", "1.0.0")
                        .param("versionCode", "100"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.latestVersion").isNotEmpty())
                .andExpect(jsonPath("$.data.githubRepo").value("gonglanglang/Chnagguan"))
                .andExpect(jsonPath("$.data.hasUpdate").value(false));
    }

    @Test
    void adminVersionEndpointShouldRequireAuth() throws Exception {
        mockMvc.perform(get("/api/admin/app/version/latest"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void uploadApkAndCompareVersionShouldDetectUpdate() {
        MockMultipartFile apk = new MockMultipartFile(
                "file",
                "guoguanla-1.0.1.apk",
                "application/vnd.android.package-archive",
                "dummy-apk-content".getBytes(StandardCharsets.UTF_8)
        );
        AppVersionVO uploaded = appVersionService.uploadApk(
                apk,
                "1.0.1",
                101,
                "修复部分题目显示并优化体验",
                false,
                "http://47.107.94.90"
        );
        assertEquals("1.0.1", uploaded.getLatestVersion());
        assertEquals(101, uploaded.getLatestVersionCode());
        assertEquals("http://47.107.94.90/downloads/guoguanla-v1.0.1.apk", uploaded.getDownloadUrl());

        AppVersionVO olderClient = appVersionService.checkLatestVersion("1.0.0", 100, "http://47.107.94.90", false);
        assertTrue(olderClient.getHasUpdate());
        assertFalse(olderClient.getForceUpdate());

        AppVersionVO sameClient = appVersionService.checkLatestVersion("1.0.1", 101, "http://47.107.94.90", false);
        assertFalse(sameClient.getHasUpdate());
    }
}
