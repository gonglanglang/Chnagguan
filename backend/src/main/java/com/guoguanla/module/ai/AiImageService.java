package com.guoguanla.module.ai;

import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.module.ai.dto.AiImageGenerateReq;
import com.guoguanla.module.ai.dto.AiImageTestReq;
import com.guoguanla.module.ai.vo.AiImageGenerateVO;
import com.guoguanla.module.ai.vo.AiImageTestVO;
import com.guoguanla.module.oss.AliyunOssService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AiImageService {

    private static final String DEFAULT_TEST_PROMPT =
            "a clean minimalist crystal lotus on calm water, soft studio lighting, crisp details";

    private final AiImageConfigService aiImageConfigService;
    private final OpenAiImageClient openAiImageClient;
    private final AliyunOssService aliyunOssService;

    public AiImageTestVO testConnection(AiImageTestReq req) {
        AiImageConfigService.RuntimeAiImageConfig saved = aiImageConfigService.loadRuntimeConfig();

        String baseUrl = (req != null && req.getBaseUrl() != null && !req.getBaseUrl().isBlank())
                ? req.getBaseUrl().trim()
                : saved.getBaseUrl();
        String apiKey = (req != null && req.getApiKey() != null && !req.getApiKey().isBlank() && !req.getApiKey().contains("****"))
                ? req.getApiKey().trim()
                : saved.getApiKey();
        String model = (req != null && req.getModel() != null && !req.getModel().isBlank())
                ? req.getModel().trim()
                : saved.getModel();
        int timeoutSec = (req != null && req.getTimeoutSec() != null)
                ? Math.max(10, Math.min(300, req.getTimeoutSec()))
                : saved.getTimeoutSec();

        String endpoint;
        String serviceOrigin;
        String size;
        try {
            endpoint = AiImageConfigService.resolveImagesGenerationsUrl(baseUrl);
            serviceOrigin = AiImageConfigService.resolveServiceOrigin(baseUrl);
            size = (req != null && req.getSize() != null && !req.getSize().isBlank())
                    ? AiImageConfigService.normalizeSize(req.getSize())
                    : saved.getDefaultSize();
        } catch (BizException e) {
            return AiImageTestVO.builder()
                    .ok(false)
                    .mode(Boolean.TRUE.equals(req != null ? req.getGenerateSample() : false) ? "GENERATE" : "HEALTH")
                    .model(model)
                    .errorMessage(e.getMessage())
                    .build();
        }

        boolean generateSample = req != null && Boolean.TRUE.equals(req.getGenerateSample());
        if (!generateSample) {
            OpenAiImageClient.HealthProbeResult probe = openAiImageClient.probeFlowHealth(serviceOrigin, apiKey, timeoutSec);
            return AiImageTestVO.builder()
                    .ok(probe.isOk())
                    .mode("HEALTH")
                    .latencyMs(probe.getLatencyMs())
                    .endpoint(endpoint)
                    .model(model)
                    .engineReady(probe.isEngineReady())
                    .accountCount(probe.getAccountCount())
                    .totalCredits(probe.getTotalCredits())
                    .message(probe.getSummary())
                    .errorMessage(probe.getErrorMessage())
                    .build();
        }

        String prompt = (req.getPrompt() != null && !req.getPrompt().isBlank())
                ? req.getPrompt().trim()
                : DEFAULT_TEST_PROMPT;

        long start = System.currentTimeMillis();
        try {
            OpenAiImageClient.ImageCallResult res = openAiImageClient.generateImages(
                    OpenAiImageClient.ImageCallRequest.builder()
                            .endpoint(endpoint)
                            .apiKey(apiKey)
                            .model(model)
                            .prompt(prompt)
                            .size(size)
                            .count(1)
                            .timeoutSec(timeoutSec)
                            .build()
            );
            OpenAiImageClient.RawImageItem first = res.getItems().get(0);
            return AiImageTestVO.builder()
                    .ok(true)
                    .mode("GENERATE")
                    .latencyMs(res.getLatencyMs())
                    .endpoint(endpoint)
                    .model(res.getModelUsed())
                    .message("试生图成功，返回 1 张图片（尺寸 " + size + "）")
                    .imageDataUrl(first.getDataUrl())
                    .imageUrl(first.getRemoteUrl())
                    .build();
        } catch (BizException e) {
            return AiImageTestVO.builder()
                    .ok(false)
                    .mode("GENERATE")
                    .latencyMs(System.currentTimeMillis() - start)
                    .endpoint(endpoint)
                    .model(model)
                    .errorMessage(e.getMessage())
                    .build();
        }
    }

    public AiImageGenerateVO generate(AiImageGenerateReq req, String baseOrigin) {
        AiImageConfigService.RuntimeAiImageConfig cfg = aiImageConfigService.loadRuntimeConfig();
        if (!cfg.isEnabled()) {
            throw new BizException(ErrorCode.AI_DISABLED, "AI 生图服务暂未开启，请先在系统设置中启用");
        }
        if (!cfg.isConfigured()) {
            throw new BizException(ErrorCode.AI_NOT_CONFIGURED, "AI 生图服务尚未配置完成，请先在系统设置中填写接口地址与模型");
        }

        String model = (req.getModel() != null && !req.getModel().isBlank())
                ? req.getModel().trim()
                : cfg.getModel();
        String size = (req.getSize() != null && !req.getSize().isBlank())
                ? AiImageConfigService.normalizeSize(req.getSize())
                : cfg.getDefaultSize();
        int count = req.getCount() == null ? 1 : Math.max(1, Math.min(4, req.getCount()));
        boolean saveToStorage = Boolean.TRUE.equals(req.getSaveToStorage());

        OpenAiImageClient.ImageCallResult res = openAiImageClient.generateImages(
                OpenAiImageClient.ImageCallRequest.builder()
                        .endpoint(cfg.getImagesGenerationsUrl())
                        .apiKey(cfg.getApiKey())
                        .model(model)
                        .prompt(req.getPrompt().trim())
                        .size(size)
                        .count(count)
                        .timeoutSec(cfg.getTimeoutSec())
                        .build()
        );

        List<AiImageGenerateVO.GeneratedImageItem> outItems = new ArrayList<>();
        for (int i = 0; i < res.getItems().size(); i++) {
            OpenAiImageClient.RawImageItem raw = res.getItems().get(i);
            String objectKey = "";
            String storedUrl = "";
            String storageType = "";
            if (saveToStorage && raw.getBytes() != null && raw.getBytes().length > 0) {
                AliyunOssService.UploadResult uploaded = aliyunOssService.uploadAiGeneratedImage(
                        raw.getBytes(), raw.getContentType(), baseOrigin
                );
                objectKey = uploaded.objectKey();
                storedUrl = uploaded.previewUrl();
                storageType = uploaded.storageType();
            }
            outItems.add(AiImageGenerateVO.GeneratedImageItem.builder()
                    .index(i)
                    .dataUrl(raw.getDataUrl())
                    .remoteUrl(raw.getRemoteUrl())
                    .objectKey(objectKey)
                    .storedUrl(storedUrl)
                    .storageType(storageType)
                    .contentType(raw.getContentType())
                    .build());
        }

        return AiImageGenerateVO.builder()
                .model(res.getModelUsed())
                .size(size)
                .endpoint(cfg.getImagesGenerationsUrl())
                .latencyMs(res.getLatencyMs())
                .images(outItems)
                .build();
    }
}
