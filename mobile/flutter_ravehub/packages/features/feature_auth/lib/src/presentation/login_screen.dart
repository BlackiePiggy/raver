import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import 'view_models/login_view_model.dart';
import 'widgets/auth_legal_agreement_text.dart';

/// A list of common country codes for the phone-number picker.
const _countryCodes = <(String, String)>[
  ('+86', '🇨🇳 China'),
  ('+1', '🇺🇸 United States'),
  ('+81', '🇯🇵 Japan'),
  ('+44', '🇬🇧 United Kingdom'),
  ('+82', '🇰🇷 South Korea'),
  ('+61', '🇦🇺 Australia'),
  ('+49', '🇩🇪 Germany'),
  ('+33', '🇫🇷 France'),
  ('+31', '🇳🇱 Netherlands'),
  ('+34', '🇪🇸 Spain'),
  ('+852', '🇭🇰 Hong Kong'),
  ('+886', '🇹🇼 Taiwan'),
  ('+65', '🇸🇬 Singapore'),
];

/// Login screen with dark gradient background, tab-based login methods,
/// and the RaveHub purple accent theme.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the [LoginScreen].
  const LoginScreen({super.key, this.returnTo});

  /// Optional path to navigate to after successful login.
  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _showManualLogin = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.fastLinearToSlowEaseIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecoration({
    required String label,
    required Color accent,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: RaverTypography.body(size: 14, color: Colors.white60),
      hintStyle: RaverTypography.body(size: 14, color: Colors.white30),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD93636)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD93636), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _onLogin() async {
    final notifier = ref.read(loginProvider.notifier);
    final success = await notifier.login();
    if (success && mounted) {
      context.go(widget.returnTo ?? '/');
    }
  }

  void _toggleManualLogin(LoginState state, LoginNotifier notifier) {
    if (!state.agreedToTerms) {
      notifier.setError(
        lt(
          '请先勾选并同意用户服务条款、用户协议和隐私政策。',
          'Please agree to the user terms, user agreement, and privacy policy first.',
          '先に利用規約、ユーザー契約、プライバシーポリシーに同意してください。',
        ),
      );
      return;
    }
    setState(() => _showManualLogin = !_showManualLogin);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    final notifier = ref.read(loginProvider.notifier);
    final accent = RaverColors.accent(Brightness.dark);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildIosLoginBackdrop(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          _buildTopActions(state),
                          const SizedBox(height: 24),
                          _buildIosLoginBody(state, notifier, accent),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (state.errorMessage != null)
            _buildFloatingNotice(state.errorMessage!, notifier),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildIosLoginBackdrop() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13091F), Color(0xFF090912), Color(0xFF020204)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _ConcertBackdropPainter()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.15, -0.2),
                  radius: 0.9,
                  colors: [
                    const Color(0xFF44D9D1).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8A000000),
                  Color(0x6B000000),
                  Color(0x8F000000),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActions(LoginState state) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: state.isLoading ? null : () => context.go('/discover'),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white.withValues(alpha: 0.9),
            iconSize: 22,
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          TextButton(
            onPressed: state.isLoading ? null : () => context.go('/discover'),
            child: Text(
              lt('先看看', 'Preview', '先に見る'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIosLoginBody(
    LoginState state,
    LoginNotifier notifier,
    Color accent,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          children: [
            const SizedBox(height: 18),
            _buildBrandHeader(),
            const SizedBox(height: 28),
            _buildTermsCheckbox(state, notifier, accent),
            const SizedBox(height: 12),
            _buildManualToggleButton(state, notifier),
            const SizedBox(height: 12),
            TextButton(
              onPressed:
                  state.isLoading ? null : () => context.push('/register'),
              child: Text(
                lt('注册新账号', 'Create New Account', '新規登録'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _showManualLogin
                  ? Padding(
                      key: const ValueKey('manual-login-panel'),
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildManualLoginPanel(state, notifier, accent),
                    )
                  : const SizedBox(key: ValueKey('manual-login-empty')),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildManualToggleButton(LoginState state, LoginNotifier notifier) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: TextButton(
        onPressed:
            state.isLoading ? null : () => _toggleManualLogin(state, notifier),
        style: TextButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.44),
          foregroundColor: Colors.white.withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
          ),
        ),
        child: state.isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                lt('邮箱或账号登录', 'Email or Account Sign In', 'メールまたはアカウントでログイン'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildManualLoginPanel(
    LoginState state,
    LoginNotifier notifier,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          _buildMethodTabs(state, notifier, accent),
          const SizedBox(height: 10),
          if (state.method == LoginMethod.email)
            _buildEmailForm(state, notifier, accent),
          if (state.method == LoginMethod.sms)
            _buildSmsForm(state, notifier, accent),
          if (state.method == LoginMethod.password)
            _buildPasswordForm(state, notifier, accent),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            width: double.infinity,
            child: TextButton(
              onPressed: state.canLogin ? _onLogin : null,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.20),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _manualSubmitTitle(state.method),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: state.isLoading ? null : () => context.push('/register'),
            child: Text(
              lt('还没有账号？注册', 'No account yet? Register', 'アカウントをお持ちでない方は登録'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _manualSubmitTitle(LoginMethod method) {
    return switch (method) {
      LoginMethod.email => lt('邮箱验证码登录', 'Email Code Sign In', 'メール認証でログイン'),
      LoginMethod.sms => lt('验证码登录', 'SMS Sign In', 'SMSでログイン'),
      LoginMethod.password => lt('账号登录', 'Sign In', 'アカウントでログイン'),
    };
  }

  Widget _buildFloatingNotice(String message, LoginNotifier notifier) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 58, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFFC26B),
                size: 17,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: notifier.clearError,
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.72),
                  size: 16,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return LayoutBuilder(
      builder: (context, _) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final logoWidth = math.max(180.0, screenWidth * (2 / 3));

        return Image.asset(
          'assets/login-center-brand.png',
          key: const ValueKey('login_center_brand_asset'),
          package: 'feature_auth',
          width: logoWidth,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackBrandHeader(),
        );
      },
    );
  }

  Widget _buildFallbackBrandHeader() {
    return Column(
      children: [
        Container(
          width: 102,
          height: 102,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.95),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'RH',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.42),
                fontSize: 40,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          RaverTypography.appName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMethodTabs(
    LoginState state,
    LoginNotifier notifier,
    Color accent,
  ) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabItem(
              label: lt('邮箱', 'Email', 'メール'),
              isSelected: state.method == LoginMethod.email,
              accent: accent,
              onTap: () => notifier.setMethod(LoginMethod.email),
            ),
          ),
          Expanded(
            child: _TabItem(
              label: lt('账号', 'Account', 'アカウント'),
              isSelected: state.method == LoginMethod.password,
              accent: accent,
              onTap: () => notifier.setMethod(LoginMethod.password),
            ),
          ),
          Expanded(
            child: _TabItem(
              label: lt('短信', 'SMS', 'SMS'),
              isSelected: state.method == LoginMethod.sms,
              accent: accent,
              onTap: () => notifier.setMethod(LoginMethod.sms),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm(
    LoginState state,
    LoginNotifier notifier,
    Color accent,
  ) {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          onChanged: notifier.setEmail,
          keyboardType: TextInputType.emailAddress,
          style: RaverTypography.body(size: 15, color: Colors.white),
          cursorColor: accent,
          decoration: _inputDecoration(
            label: lt('邮箱地址', 'Email Address', 'メールアドレス'),
            accent: accent,
            prefixIcon: Icon(
              Icons.email_outlined,
              color: Colors.white38,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCodeField(notifier, accent)),
            const SizedBox(width: 10),
            _buildInlineSendCodeButton(state, notifier),
          ],
        ),
      ],
    );
  }

  Widget _buildSmsForm(LoginState state, LoginNotifier notifier, Color accent) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _showCountryCodePicker(notifier, accent),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.countryCode,
                      style: RaverTypography.body(
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneController,
                onChanged: notifier.setPhone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: RaverTypography.body(size: 15, color: Colors.white),
                cursorColor: accent,
                decoration: _inputDecoration(
                  label: lt('手机号', 'Phone Number', '電話番号'),
                  accent: accent,
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCodeField(notifier, accent)),
            const SizedBox(width: 10),
            _buildInlineSendCodeButton(state, notifier),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeField(LoginNotifier notifier, Color accent) {
    return TextField(
      controller: _codeController,
      onChanged: notifier.setVerificationCode,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: RaverTypography.body(size: 15, color: Colors.white),
      cursorColor: accent,
      decoration: _inputDecoration(
        label: lt('验证码', 'Verification Code', '認証コード'),
        accent: accent,
        hintText: '000000',
        prefixIcon: Icon(Icons.lock_outline, color: Colors.white38, size: 20),
      ).copyWith(counterText: ''),
    );
  }

  Widget _buildInlineSendCodeButton(LoginState state, LoginNotifier notifier) {
    final enabled = state.canSendCode;
    final inCooldown = state.cooldownSeconds > 0;

    final label = inCooldown
        ? lt(
            '${state.cooldownSeconds}s',
            '${state.cooldownSeconds}s',
            '${state.cooldownSeconds}s',
          )
        : state.codeSent
            ? lt('重发', 'Resend', '再送信')
            : lt('发送', 'Send', '送信');

    return SizedBox(
      height: 50,
      child: TextButton(
        onPressed: enabled ? () => notifier.sendCode() : null,
        style: TextButton.styleFrom(
          minimumSize: const Size(78, 50),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: Colors.white.withValues(
            alpha: enabled ? 0.22 : 0.10,
          ),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: state.isLoading && !inCooldown
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildPasswordForm(
    LoginState state,
    LoginNotifier notifier,
    Color accent,
  ) {
    return Column(
      children: [
        // Username field
        TextField(
          controller: _usernameController,
          onChanged: notifier.setUsername,
          style: RaverTypography.body(size: 15, color: Colors.white),
          cursorColor: accent,
          decoration: _inputDecoration(
            label: lt('用户名 / 邮箱', 'Username / Email', 'ユーザー名 / メール'),
            accent: accent,
            prefixIcon: Icon(
              Icons.person_outline,
              color: Colors.white38,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Password field
        TextField(
          controller: _passwordController,
          onChanged: notifier.setPassword,
          obscureText: true,
          style: RaverTypography.body(size: 15, color: Colors.white),
          cursorColor: accent,
          decoration: _inputDecoration(
            label: lt('密码', 'Password', 'パスワード'),
            accent: accent,
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Colors.white38,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox(
    LoginState state,
    LoginNotifier notifier,
    Color accent,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: notifier.toggleTermsAgreement,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              state.agreedToTerms ? Icons.check_circle : Icons.circle_outlined,
              color: state.agreedToTerms
                  ? Colors.white.withValues(alpha: 0.96)
                  : Colors.white.withValues(alpha: 0.56),
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: AuthLegalAgreementText(accent: accent, compact: true),
        ),
      ],
    );
  }

  void _showCountryCodePicker(LoginNotifier notifier, Color accent) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lt('选择国家/地区', 'Select Country/Region', '国/地域を選択'),
                style: RaverTypography.title(size: 16, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _countryCodes.length,
                  itemBuilder: (_, index) {
                    final (code, name) = _countryCodes[index];
                    return ListTile(
                      title: Text(
                        name,
                        style: RaverTypography.body(
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                      trailing: Text(
                        code,
                        style: RaverTypography.body(
                          size: 15,
                          color: Colors.white54,
                        ),
                      ),
                      onTap: () {
                        notifier.setCountryCode(code);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab item
// ---------------------------------------------------------------------------

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: RaverMotion.normal,
        curve: RaverMotion.curve,
        height: 38,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color:
              isSelected ? accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: RaverMotion.fast,
            style: RaverTypography.label(
              size: 14,
              color: isSelected ? Colors.white : Colors.white54,
              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _ConcertBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF221039), Color(0xFF061721), Color(0xFF040407)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;
    final beams = [
      (
        const Color(0xFF8B5CF6),
        Offset(size.width * 0.08, size.height * 0.22),
        Offset(size.width * 0.62, size.height * 0.58),
      ),
      (
        const Color(0xFF44D9D1),
        Offset(size.width * 0.32, size.height * 0.14),
        Offset(size.width * 0.75, size.height * 0.62),
      ),
      (
        const Color(0xFFF88C3F),
        Offset(size.width * 0.85, size.height * 0.18),
        Offset(size.width * 0.34, size.height * 0.66),
      ),
    ];
    for (final beam in beams) {
      beamPaint.shader = LinearGradient(
        colors: [
          beam.$1.withValues(alpha: 0.0),
          beam.$1.withValues(alpha: 0.18),
          beam.$1.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromPoints(beam.$2, beam.$3));
      canvas.drawLine(beam.$2, beam.$3, beamPaint);
    }

    final crowdPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final baseY = size.height * 0.78;
    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i <= 42; i++) {
      final x = size.width * i / 42;
      final wave = math.sin(i * 1.7) * 18 + math.sin(i * 0.55) * 28;
      path.lineTo(x, baseY + wave);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, crowdPaint);

    final sparklePaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i < 80; i++) {
      final x = (math.sin(i * 12.9898) * 43758.5453).abs() % size.width;
      final y = (math.sin(i * 78.233) * 24634.6345).abs() % (size.height * 0.7);
      final r = 0.8 + (i % 3) * 0.45;
      canvas.drawCircle(Offset(x, y), r, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConcertBackdropPainter oldDelegate) => false;
}
