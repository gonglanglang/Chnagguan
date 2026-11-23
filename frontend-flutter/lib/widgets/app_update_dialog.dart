import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';
import '../core/utils/update_utils.dart';
import '../providers/update_provider.dart';
import '../services/apk_installer.dart';
import 'ggl_comic_panel.dart';
import 'ggl_feedback.dart';

/// Global comic-styled in-app update overlay modal.
class AppUpdateOverlay extends StatelessWidget {
  const AppUpdateOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateProvider>();
    if (!update.visible) return const SizedBox.shrink();

    final colors = WelkTheme.of(context).resolveColors(context);
    final isDownloaded =
        !update.downloading && update.downloadedFilePath.isNotEmpty;

    final sizeSummary = update.totalBytes > 0
        ? '${UpdateUtils.formatUpdateByteSize(update.downloadedBytes)} / ${UpdateUtils.formatUpdateByteSize(update.totalBytes)}'
        : (update.downloadedBytes > 0
            ? '已下载 ${UpdateUtils.formatUpdateByteSize(update.downloadedBytes)}'
            : '正在连接下载服务...');

    return Positioned.fill(
      child: Material(
        color: const Color(0x88000000),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GglComicPanel(
                  padding: EdgeInsets.zero,
                  shadowOffset: const Offset(6, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header banner
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          border: Border(
                            bottom: BorderSide(
                              color: colors.outline,
                              width: colors.borderWidth,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '发现新版本',
                                    style: TextStyle(
                                      color: colors.onFill(colors.accent),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      fontFamilyFallback:
                                          AppTheme.cjkFontFallback,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'v${update.currentVersion} → v${update.latestVersion}',
                                    style: TextStyle(
                                      color: colors
                                          .onFill(colors.accent)
                                          .withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!update.forceUpdate && !update.downloading)
                              WelkIconButton.close(
                                dialog: true,
                                label: '关闭',
                                onPressed: update.dismiss,
                              ),
                          ],
                        ),
                      ),

                      // Body
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '更新内容',
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 160),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final note in update.noteList)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '• ',
                                              style: TextStyle(
                                                color: colors.ink,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                note,
                                                style: TextStyle(
                                                  color: colors.ink
                                                      .withValues(alpha: 0.86),
                                                  fontSize: 13.5,
                                                  height: 1.45,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            if (update.downloading || isDownloaded) ...[
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isDownloaded ? '安装包已就绪' : '正在应用内下载...',
                                    style: TextStyle(
                                      color: colors.ink,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${update.progress}%',
                                    style: TextStyle(
                                      color: colors.ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              GglProgressBar(
                                percent: update.progress / 100,
                                fillColor: isDownloaded
                                    ? colors.success
                                    : colors.accent,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                sizeSummary,
                                style: TextStyle(
                                  color: AppTheme.mutedText(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],

                            if (update.errorMsg.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colors.error.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colors.outline,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  update.errorMsg,
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Actions
                            if (update.downloading)
                              GglBlockButton(
                                label: '取消下载',
                                variant: WelkButtonVariant.secondary,
                                onPressed: update.cancelDownload,
                              )
                            else if (isDownloaded)
                              Row(
                                children: [
                                  Expanded(
                                    child: GglBlockButton(
                                      label: '重新下载',
                                      variant: WelkButtonVariant.secondary,
                                      size: WelkButtonSize.small,
                                      onPressed: () async {
                                        final msg = await update.reDownload();
                                        if (msg != null && context.mounted) {
                                          GglFeedback.info(context, msg);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GglBlockButton(
                                      label: '立即安装',
                                      variant: WelkButtonVariant.success,
                                      size: WelkButtonSize.small,
                                      onPressed: () async {
                                        final msg = await update
                                            .startDownloadOrInstall();
                                        if (msg != null && context.mounted) {
                                          GglFeedback.info(context, msg);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  if (!update.forceUpdate) ...[
                                    Expanded(
                                      child: GglBlockButton(
                                        label: '暂不更新',
                                        variant: WelkButtonVariant.secondary,
                                        size: WelkButtonSize.small,
                                        onPressed: update.dismiss,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: GglBlockButton(
                                      label: ApkInstaller
                                              .supportsInAppApkInstall
                                          ? (update.errorMsg.isNotEmpty
                                              ? '重新下载'
                                              : '立即更新')
                                          : '复制下载链接',
                                      variant: WelkButtonVariant.primary,
                                      size: WelkButtonSize.small,
                                      onPressed: () async {
                                        final msg = await update
                                            .startDownloadOrInstall();
                                        if (msg != null && context.mounted) {
                                          GglFeedback.success(context, msg);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
