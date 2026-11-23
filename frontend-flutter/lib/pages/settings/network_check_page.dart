import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_config.dart';
import '../../app/app_theme.dart';
import '../../core/cache/global_cache.dart';
import '../../core/network/api_client.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';

class NetworkCheckPage extends StatefulWidget {
  const NetworkCheckPage({super.key});

  @override
  State<NetworkCheckPage> createState() => _NetworkCheckPageState();
}

class _NetworkCheckPageState extends State<NetworkCheckPage> {
  bool _testing = false;
  ({bool reachable, int? costMs, int? statusCode})? _result;

  Future<void> _startProbe() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _result = null;
    });
    final res = await context.read<ApiClient>().probeHomeSummary();
    if (mounted) {
      setState(() {
        _result = res;
        _testing = false;
      });
    }
  }

  Future<void> _switchEndpoint(String url, String label) async {
    final cache = context.read<GlobalCache>();
    final client = context.read<ApiClient>();
    await cache.setCustomApiBaseUrl(url);
    client.updateBaseUrl(url);
    if (mounted) {
      setState(() => _result = null);
      GglFeedback.success(context, '已切换接口至 $label');
    }
  }

  String _qualityLabel(({bool reachable, int? costMs, int? statusCode}) r) {
    if (!r.reachable) return '不可访问';
    final ms = r.costMs ?? 0;
    if (ms < 100) return '优秀';
    if (ms < 300) return '良好';
    if (ms < 500) return '一般';
    return '较差';
  }

  WelkBadgeVariant _qualityVariant(
    ({bool reachable, int? costMs, int? statusCode}) r,
  ) {
    if (!r.reachable) return WelkBadgeVariant.error;
    final ms = r.costMs ?? 0;
    if (ms < 100) return WelkBadgeVariant.success;
    if (ms < 300) return WelkBadgeVariant.info;
    if (ms < 500) return WelkBadgeVariant.warning;
    return WelkBadgeVariant.error;
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final activeBaseUrl = context.read<ApiClient>().baseUrl;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: WelkAppBar(
        title: '网络检测',
        centerTitle: true,
        layout: WelkAppBarLayout.comicStrip,
        leading: WelkIconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          label: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          GglComicPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前接口地址',
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeBaseUrl,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GglPillChip(
                      label: '本地联调 (8080)',
                      selected: activeBaseUrl == '${AppConfig.localOrigin}/api',
                      onTap: () => _switchEndpoint(
                        '${AppConfig.localOrigin}/api',
                        '本地服务',
                      ),
                    ),
                    GglPillChip(
                      label: '线上服务 (47.107)',
                      selected: activeBaseUrl == '${AppConfig.prodOrigin}/api',
                      onTap: () => _switchEndpoint(
                        '${AppConfig.prodOrigin}/api',
                        '线上服务',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '点击下方「开始测试」检测当前设备到后端接口的连接质量。',
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          GglBlockButton(
            label: _testing ? '正在探测接口...' : '开始测试',
            loading: _testing,
            icon: Icons.network_check_rounded,
            onPressed: _startProbe,
          ),
          const SizedBox(height: 16),
          if (_testing)
            const GglCardSkeleton(lines: 3)
          else if (_result != null)
            GglComicPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '测试结果',
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GglStatusTag(
                        label: _qualityLabel(_result!),
                        variant: _qualityVariant(_result!),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: WelkDivider(variant: WelkDividerVariant.dashed),
                  ),
                  _ResultLine(
                    label: '接口服务',
                    value: _result!.reachable ? '可访问' : '不可访问',
                  ),
                  const SizedBox(height: 10),
                  _ResultLine(
                    label: '响应耗时',
                    value: _result!.costMs == null
                        ? '--'
                        : '${_result!.costMs} ms',
                  ),
                  const SizedBox(height: 10),
                  _ResultLine(
                    label: 'HTTP 状态码',
                    value: _result!.statusCode?.toString() ?? '--',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.mutedText(context), fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: colors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
