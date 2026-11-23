import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../providers/user_provider.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final user = context.read<UserProvider>();
    try {
      final profile = await user.loadUserInfo();
      if (mounted) {
        setState(() => _nickname = profile.nickname);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _nickname = user.userInfo?.nickname ?? '');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseAvatar() async {
    if (_uploadingAvatar) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked == null || !mounted) return;
      setState(() => _uploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      await context.read<UserProvider>().uploadAvatarBytes(
            bytes: bytes,
            filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
          );
      if (mounted) {
        GglFeedback.success(context, '头像已更新');
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '头像上传失败'));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _handleSave() async {
    final trimmed = _nickname.trim();
    if (trimmed.isEmpty) {
      GglFeedback.warning(context, '昵称不能为空');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<UserProvider>().updateProfile(nickname: trimmed);
      if (!mounted) return;
      GglFeedback.success(context, '资料已保存');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '保存失败'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final info = context.watch<UserProvider>().userInfo;
    final avatarUrl = info?.avatarUrl ?? '';

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: WelkAppBar(
        title: '个人资料',
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
          if (_loading) ...[
            const GglCardSkeleton(lines: 2),
            const SizedBox(height: 14),
            const GglCardSkeleton(lines: 4),
          ] else ...[
            // Avatar card
            GglComicPanel(
              onTap: _chooseAvatar,
              child: Row(
                children: [
                  WelkAvatar(
                    alt: info?.nickname ?? '用户头像',
                    size: WelkAvatarSize.large,
                    image:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '个人头像',
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '点击从相册选择照片更换头像',
                          style: TextStyle(
                            color: AppTheme.mutedText(context),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GglStatusTag(
                    label: _uploadingAvatar ? '上传中...' : '更换',
                    variant: WelkBadgeVariant.defaultStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Profile fields
            GglComicPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReadonlyInfoRow(
                    label: '用户名',
                    value: info?.username ?? '--',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: WelkDivider(variant: WelkDividerVariant.dashed),
                  ),
                  _ReadonlyInfoRow(
                    label: '所在年级',
                    value: info?.gradeName ?? '--',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: WelkDivider(variant: WelkDividerVariant.dashed),
                  ),
                  _ReadonlyInfoRow(
                    label: '当前修仙境界',
                    value: info?.realmName ?? '练气',
                    sub: '境界由进阶考核或管理员调整，不可自行更改',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: WelkDivider(variant: WelkDividerVariant.dashed),
                  ),
                  WelkInput(
                    label: '昵称',
                    value: _nickname,
                    placeholder: '请输入学生昵称',
                    onChanged: (v) => setState(() => _nickname = v),
                    endAction: _nickname.isNotEmpty
                        ? WelkInputAction(
                            icon: const Icon(Icons.close_rounded),
                            label: '清空昵称',
                            onPressed: () => setState(() => _nickname = ''),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: colors.paper,
            border: Border(
              top: BorderSide(color: colors.outline, width: colors.borderWidth),
            ),
          ),
          child: GglBlockButton(
            label: _saving ? '正在保存...' : '保存资料',
            loading: _saving,
            size: WelkButtonSize.large,
            onPressed: (_loading || _uploadingAvatar) ? null : _handleSave,
          ),
        ),
      ),
    );
  }
}

class _ReadonlyInfoRow extends StatelessWidget {
  const _ReadonlyInfoRow({
    required this.label,
    required this.value,
    this.sub,
  });

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: AppTheme.mutedText(context),
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(
            sub!,
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
