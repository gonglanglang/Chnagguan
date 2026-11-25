import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/cache/global_cache.dart';
import '../../core/network/api_client.dart';
import '../../providers/user_provider.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skin_widgets.dart';
import '../../widgets/ggl_skeleton.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _initialLoading = false;
  bool _isRegister = false;
  bool _submitting = false;
  bool _showLoginPwd = false;
  bool _showRegisterPwd = false;
  bool _rememberAccount = true;

  String _loginAccount = '';
  String _loginPassword = '';

  String _regUsername = '';
  String _regNickname = '';
  String _regPassword = '';
  String _regGradeCode = '';

  @override
  void initState() {
    super.initState();
    final cache = context.read<GlobalCache>();
    _loginAccount = cache.rememberedAccount;
    _rememberAccount = true;

    final user = context.read<UserProvider>();
    if (user.homeSummary == null) {
      _initialLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGrades());
    }
  }

  Future<void> _loadGrades() async {
    try {
      await context.read<UserProvider>().loadHomeSummary();
    } catch (_) {
      // Fallback grades remain usable offline
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    final account = _loginAccount.trim();
    if (account.isEmpty || _loginPassword.isEmpty) {
      GglFeedback.warning(context, '请输入账号和密码');
      return;
    }

    final cache = context.read<GlobalCache>();
    final user = context.read<UserProvider>();
    await cache.setRememberedAccount(_rememberAccount ? account : '');

    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      await user.login(
        account: account,
        password: _loginPassword,
      );
      if (!mounted) return;
      GglFeedback.success(context, '登录成功');
      await user.loadHomeSummary();
      await user.refreshWrongCount();
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '登录失败'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleRegister() async {
    final username = _regUsername.trim();
    final nickname = _regNickname.trim();
    if (username.length < 3) {
      GglFeedback.warning(context, '用户名长度至少为 3 位');
      return;
    }
    if (nickname.isEmpty) {
      GglFeedback.warning(context, '请输入昵称');
      return;
    }
    if (_regPassword.length < 6) {
      GglFeedback.warning(context, '密码长度至少为 6 位');
      return;
    }
    if (_regGradeCode.isEmpty) {
      GglFeedback.warning(context, '请选择所在年级');
      return;
    }

    final user = context.read<UserProvider>();
    setState(() => _submitting = true);
    try {
      await user.register(
        username: username,
        password: _regPassword,
        nickname: nickname,
        gradeCode: _regGradeCode,
      );
      if (!mounted) return;
      GglFeedback.success(context, '注册成功');
      await user.loadHomeSummary();
      await user.refreshWrongCount();
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '注册失败'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _handleForgotPassword() {
    GglFeedback.alert(
      context,
      title: '找回密码提示',
      content: '请联系教研或系统管理员在后台重置学生登录密码。',
      buttonText: '知道了',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final grades = context.watch<UserProvider>().grades;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: GglAppBar(
        title: _isRegister ? '学生注册' : '账号登录',
        showBack: canPop,
        onBack: () => Navigator.of(context).pop(false),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _initialLoading
                  ? const Column(
                      children: [
                        GglSkeletonBox(height: 68, circle: true),
                        SizedBox(height: 16),
                        GglSkeletonBox(width: 180, height: 24),
                        SizedBox(height: 24),
                        GglCardSkeleton(lines: 4),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand header
                        Column(
                          children: [
                            Transform.rotate(
                              angle: -0.04,
                              child: GglComicPanel(
                                padding: EdgeInsets.zero,
                                shadowOffset: const Offset(4, 4),
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '欢迎来到过关啦',
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                fontFamilyFallback: AppTheme.cjkFontFallback,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '趣味闯关 + 视频课堂，每天进步一点',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // Mode switcher (Login / Register)
                        GglComicPanel(
                          color: colors.muted,
                          padding: const EdgeInsets.all(6),
                          shadowOffset: const Offset(2, 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ModeTabButton(
                                  label: '登录',
                                  active: !_isRegister,
                                  onTap: () =>
                                      setState(() => _isRegister = false),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _ModeTabButton(
                                  label: '注册',
                                  active: _isRegister,
                                  onTap: () =>
                                      setState(() => _isRegister = true),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (!_isRegister) ...[
                          // Login form
                          GglComicPanel(
                            child: Column(
                              children: [
                                GglInput(
                                  label: '用户名',
                                  value: _loginAccount,
                                  placeholder: '请输入用户名',
                                  onChanged: (v) =>
                                      setState(() => _loginAccount = v),
                                ),
                                const SizedBox(height: 14),
                                GglInput(
                                  label: '密码',
                                  value: _loginPassword,
                                  obscureText: !_showLoginPwd,
                                  onToggleObscure: () => setState(
                                    () => _showLoginPwd = !_showLoginPwd,
                                  ),
                                  placeholder: '请输入密码',
                                  onChanged: (v) =>
                                      setState(() => _loginPassword = v),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    GglCheckbox(
                                      value: _rememberAccount,
                                      label: '记住用户名',
                                      onChanged: (v) =>
                                          setState(() => _rememberAccount = v),
                                    ),
                                    TextButton(
                                      onPressed: _handleForgotPassword,
                                      child: Text(
                                        '忘记密码？',
                                        style: TextStyle(
                                          color: colors.ink,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          GglBlockButton(
                            label: _submitting ? '正在登录...' : '立即登录',
                            loading: _submitting,
                            size: WelkButtonSize.large,
                            onPressed: _handleLogin,
                          ),
                        ] else ...[
                          // Register form (grade mandatory, no demo accounts)
                          GglComicPanel(
                            child: Column(
                              children: [
                                GglInput(
                                  label: '用户名 *',
                                  value: _regUsername,
                                  placeholder: '3~16 位字母或数字',
                                  onChanged: (v) =>
                                      setState(() => _regUsername = v),
                                ),
                                const SizedBox(height: 14),
                                GglInput(
                                  label: '昵称 *',
                                  value: _regNickname,
                                  placeholder: '闯关时显示的名字',
                                  onChanged: (v) =>
                                      setState(() => _regNickname = v),
                                ),
                                const SizedBox(height: 14),
                                GglInput(
                                  label: '密码 *',
                                  value: _regPassword,
                                  obscureText: !_showRegisterPwd,
                                  onToggleObscure: () => setState(
                                    () => _showRegisterPwd = !_showRegisterPwd,
                                  ),
                                  placeholder: '至少 6 位',
                                  onChanged: (v) =>
                                      setState(() => _regPassword = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Mandatory Grade Picker (3 x 2 grid)
                          GglComicPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '所在年级',
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '*',
                                      style: TextStyle(
                                        color: colors.errorHover,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '自动匹配初始修仙境界',
                                      style: TextStyle(
                                        color: AppTheme.mutedText(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 2.35,
                                  ),
                                  itemCount: grades.length,
                                  itemBuilder: (context, idx) {
                                    final item = grades[idx];
                                    final selected =
                                        _regGradeCode == item.gradeCode;
                                    return GestureDetector(
                                      onTap: () => setState(
                                        () => _regGradeCode = item.gradeCode,
                                      ),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 130),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? colors.accent
                                              : colors.muted,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: colors.outline,
                                            width: colors.borderWidth,
                                          ),
                                          boxShadow: selected
                                              ? [
                                                  BoxShadow(
                                                    color: colors.shadow,
                                                    offset: const Offset(2, 2),
                                                  ),
                                                ]
                                              : const [],
                                        ),
                                        child: Text(
                                          item.gradeName,
                                          style: TextStyle(
                                            color: selected
                                                ? colors.onFill(colors.accent)
                                                : colors.ink,
                                            fontSize: 14,
                                            fontWeight: selected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          GglBlockButton(
                            label: _submitting ? '正在注册...' : '注册并开启修炼',
                            loading: _submitting,
                            size: WelkButtonSize.large,
                            onPressed: _handleRegister,
                          ),
                        ],

                        const SizedBox(height: 22),
                        Center(
                          child: Column(
                            children: [
                              TextButton(
                                onPressed: () {
                                  if (canPop) {
                                    Navigator.of(context).pop(false);
                                  }
                                },
                                child: Text(
                                  '先逛逛，游客试玩',
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '登录即表示同意《用户协议》与《隐私政策》',
                                style: TextStyle(
                                  color: AppTheme.mutedText(context),
                                  fontSize: 11.5,
                                ),
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
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: active
              ? Border.all(color: colors.outline, width: colors.borderWidth)
              : null,
          boxShadow: active
              ? [BoxShadow(color: colors.shadow, offset: const Offset(2, 2))]
              : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? colors.onFill(colors.accent)
                : AppTheme.mutedText(context),
            fontSize: 15,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
