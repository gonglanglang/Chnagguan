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
import '../../widgets/ggl_skin_widgets.dart';

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
  String _phone = '';
  String _email = '';

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
        setState(() {
          _nickname = profile.nickname;
          _phone = profile.phone;
          _email = profile.email;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _nickname = user.userInfo?.nickname ?? '';
          _phone = user.userInfo?.phone ?? '';
          _email = user.userInfo?.email ?? '';
        });
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
    final trimmedName = _nickname.trim();
    final trimmedPhone = _phone.trim();
    final trimmedEmail = _email.trim();
    if (trimmedName.isEmpty) {
      GglFeedback.warning(context, '昵称不能为空');
      return;
    }
    if (trimmedPhone.isNotEmpty &&
        !RegExp(r'^[0-9+\-]{6,20}$').hasMatch(trimmedPhone)) {
      GglFeedback.warning(context, '请输入正确的手机号格式');
      return;
    }
    if (trimmedEmail.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmedEmail)) {
      GglFeedback.warning(context, '请输入正确的邮箱地址格式');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<UserProvider>().updateProfile(
            nickname: trimmedName,
            phone: trimmedPhone,
            email: trimmedEmail,
          );
      if (!mounted) return;
      GglFeedback.success(context, '个人资料已保存');
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
      appBar: const GglAppBar(
        title: '个人资料',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (_loading) ...[
            const GglCardSkeleton(lines: 2),
            const SizedBox(height: 14),
            const GglCardSkeleton(lines: 5),
          ] else ...[
            // 头像卡片
            GglComicPanel(
              onTap: _chooseAvatar,
              child: Row(
                children: [
                  GglAvatar(
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

            // 基础资料（已移除「当前修仙境界」）
            GglComicPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReadonlyInfoRow(
                    label: '用户名',
                    value: info?.username ?? '--',
                  ),
                  const GglDivider(verticalPadding: 12),
                  _ReadonlyInfoRow(
                    label: '所在年级',
                    value: info?.gradeName ?? '--',
                  ),
                  const GglDivider(verticalPadding: 14),
                  GglInput(
                    label: '昵称',
                    value: _nickname,
                    placeholder: '请输入学生昵称',
                    onChanged: (v) => setState(() => _nickname = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 账号绑定：手机号与邮箱（暂无需验证码校验）
            GglComicPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '账号绑定',
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '填写后点击底部保存即可绑定',
                        style: TextStyle(
                          color: AppTheme.mutedText(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  const GglDivider(verticalPadding: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '手机绑定状态',
                        style: TextStyle(
                          color: AppTheme.mutedText(context),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GglStatusTag(
                        label: _phone.trim().isNotEmpty ? '已填写' : '未绑定',
                        variant: _phone.trim().isNotEmpty
                            ? WelkBadgeVariant.success
                            : WelkBadgeVariant.defaultStyle,
                        neutral: _phone.trim().isEmpty,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GglInput(
                    label: '绑定手机号',
                    value: _phone,
                    placeholder: '请输入手机号（选填，暂无需验证）',
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => setState(() => _phone = v),
                  ),
                  const GglDivider(verticalPadding: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '邮箱绑定状态',
                        style: TextStyle(
                          color: AppTheme.mutedText(context),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GglStatusTag(
                        label: _email.trim().isNotEmpty ? '已填写' : '未绑定',
                        variant: _email.trim().isNotEmpty
                            ? WelkBadgeVariant.success
                            : WelkBadgeVariant.defaultStyle,
                        neutral: _email.trim().isEmpty,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GglInput(
                    label: '绑定邮箱',
                    value: _email,
                    placeholder: '请输入邮箱地址（选填，暂无需验证）',
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) => setState(() => _email = v),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        color: colors.paper,
        child: SafeArea(
          top: false,
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
      ),
    );
  }
}

class _ReadonlyInfoRow extends StatelessWidget {
  const _ReadonlyInfoRow({
    required this.label,
    required this.value,
  });

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
    );
  }
}
