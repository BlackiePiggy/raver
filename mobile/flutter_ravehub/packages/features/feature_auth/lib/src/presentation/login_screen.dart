import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import 'view_models/login_view_model.dart';

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
  const LoginScreen({super.key});

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
      labelStyle: RaverTypography.body(
        size: 14,
        color: Colors.white60,
      ),
      hintStyle: RaverTypography.body(
        size: 14,
        color: Colors.white30,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
        ),
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
      context.go('/');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    final notifier = ref.read(loginProvider.notifier);
    final accent = RaverColors.accent(Brightness.dark);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Dark gradient background (video substitute) ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A0A2E), // Deep purple-black
                  Color(0xFF0D0D1A), // Near-black
                  Color(0xFF08080A), // True dark
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // --- Decorative glow orbs ---
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.25),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6B42DB).withValues(alpha: 0.18),
                    const Color(0xFF6B42DB).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // --- Scrollable content ---
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: topPadding > 44 ? 32 : 48),

                    // --- Logo / brand ---
                    _buildBrandHeader(accent),

                    const SizedBox(height: 36),

                    // --- Error message ---
                    if (state.errorMessage != null) ...[
                      _buildErrorBanner(state.errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // --- Tab toggle: Email / SMS ---
                    if (!state.showPasswordLogin) ...[
                      _buildMethodTabs(state, notifier, accent),
                      const SizedBox(height: 24),

                      // --- Email login form ---
                      if (state.method == LoginMethod.email)
                        _buildEmailForm(state, notifier, accent),

                      // --- SMS login form ---
                      if (state.method == LoginMethod.sms)
                        _buildSmsForm(state, notifier, accent),

                      const SizedBox(height: 24),

                      // --- Login button ---
                      PrimaryButton(
                        label: lt('登录', 'Log In', 'ログイン'),
                        onPressed: state.canLogin ? _onLogin : null,
                        isLoading: state.isLoading &&
                            state.method != LoginMethod.password,
                        isExpanded: true,
                        height: 54,
                        borderRadius: 30,
                      ),

                      const SizedBox(height: 20),

                      // --- Divider with "or" ---
                      _buildOrDivider(),

                      const SizedBox(height: 16),

                      // --- Login with password toggle ---
                      Center(
                        child: TextButton(
                          onPressed: notifier.togglePasswordLogin,
                          child: Text(
                            lt('使用密码登录', 'Login with Password',
                                'パスワードでログイン'),
                            style: RaverTypography.label(
                              size: 14,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // --- Password login section ---
                    if (state.showPasswordLogin) ...[
                      _buildPasswordForm(state, notifier, accent),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: lt('登录', 'Log In', 'ログイン'),
                        onPressed: state.canLogin ? _onLogin : null,
                        isLoading: state.isLoading &&
                            state.method == LoginMethod.password,
                        isExpanded: true,
                        height: 54,
                        borderRadius: 30,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: notifier.togglePasswordLogin,
                          child: Text(
                            lt('使用验证码登录',
                                'Login with Verification Code',
                                '認証コードでログイン'),
                            style: RaverTypography.label(
                              size: 14,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // --- Terms agreement ---
                    _buildTermsCheckbox(state, notifier, accent),

                    const SizedBox(height: 24),

                    // --- Register link ---
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/register'),
                        child: Text.rich(
                          TextSpan(
                            text: lt('没有账号？', "Don't have an account? ",
                                'アカウントをお持ちでない方 '),
                            style: RaverTypography.body(
                              size: 14,
                              color: Colors.white54,
                            ),
                            children: [
                              TextSpan(
                                text: lt('注册', 'Register', '新規登録'),
                                style: RaverTypography.label(
                                  size: 14,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildBrandHeader(Color accent) {
    return Column(
      children: [
        // Glow icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: 0.35),
                accent.withValues(alpha: 0.0),
              ],
              radius: 0.8,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.music_note_rounded,
              size: 36,
              color: accent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          RaverTypography.appName,
          style: RaverTypography.brandFont(
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          lt('电子音乐社交平台', 'EDM Social Platform', 'EDMソーシャルプラットフォーム'),
          style: RaverTypography.caption(
            size: 13,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD93636).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFD93636).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFD93636), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: RaverTypography.caption(
                size: 13,
                color: const Color(0xFFFF6B6B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTabs(
    LoginState state,
    LoginNotifier notifier,
    Color accent,
  ) {
    final isEmail = state.method == LoginMethod.email;

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
              label: lt('邮箱登录', 'Email Login', 'メールログイン'),
              isSelected: isEmail,
              accent: accent,
              onTap: () => notifier.setMethod(LoginMethod.email),
            ),
          ),
          Expanded(
            child: _TabItem(
              label: lt('短信登录', 'SMS Login', 'SMSログイン'),
              isSelected: !isEmail,
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
        // Email field
        TextField(
          controller: _emailController,
          onChanged: notifier.setEmail,
          keyboardType: TextInputType.emailAddress,
          style: RaverTypography.body(size: 15, color: Colors.white),
          cursorColor: accent,
          decoration: _inputDecoration(
            label: lt('邮箱地址', 'Email Address', 'メールアドレス'),
            accent: accent,
            prefixIcon: Icon(Icons.email_outlined, color: Colors.white38, size: 20),
          ),
        ),
        const SizedBox(height: 14),

        // Send Code button
        _buildSendCodeButton(state, notifier, accent),

        const SizedBox(height: 14),

        // Verification code field
        TextField(
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
        ),
      ],
    );
  }

  Widget _buildSmsForm(
    LoginState state,
    LoginNotifier notifier,
    Color accent,
  ) {
    return Column(
      children: [
        // Phone number with country code
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code picker
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
            // Phone number field
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

        // Send Code button
        _buildSendCodeButton(state, notifier, accent),

        const SizedBox(height: 14),

        // Verification code field
        TextField(
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
        ),
      ],
    );
  }

  Widget _buildSendCodeButton(
    LoginState state,
    LoginNotifier notifier,
    Color accent,
  ) {
    final enabled = state.canSendCode;
    final inCooldown = state.cooldownSeconds > 0;

    final label = inCooldown
        ? lt('重新发送 (${state.cooldownSeconds}s)',
            'Resend (${state.cooldownSeconds}s)',
            '再送信 (${state.cooldownSeconds}s)')
        : state.codeSent
            ? lt('重新发送', 'Resend Code', '再送信')
            : lt('发送验证码', 'Send Code', 'コードを送信');

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: enabled ? () => notifier.sendCode() : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(
            color: enabled
                ? accent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledForegroundColor: Colors.white24,
        ),
        child: state.isLoading && !inCooldown
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              )
            : Text(
                label,
                style: RaverTypography.label(
                  size: 14,
                  color: enabled ? accent : Colors.white24,
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
            label: lt('用户名 / 邮箱', 'Username / Email',
                'ユーザー名 / メール'),
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

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            lt('或', 'or', 'または'),
            style: RaverTypography.caption(
              size: 13,
              color: Colors.white30,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
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
    return GestureDetector(
      onTap: notifier.toggleTermsAgreement,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: state.agreedToTerms,
              onChanged: (_) => notifier.toggleTermsAgreement(),
              activeColor: accent,
              checkColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: lt('我已阅读并同意 ', 'I agree to the ', '同意する '),
                style: RaverTypography.caption(
                  size: 12,
                  color: Colors.white38,
                ),
                children: [
                  TextSpan(
                    text: lt('用户协议', 'Terms of Service', '利用規約'),
                    style: RaverTypography.caption(
                      size: 12,
                      color: accent,
                    ),
                  ),
                  TextSpan(
                    text: lt(' 和 ', ' and ', ' と '),
                  ),
                  TextSpan(
                    text: lt('隐私政策', 'Privacy Policy', 'プライバシーポリシー'),
                    style: RaverTypography.caption(
                      size: 12,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          color: isSelected
              ? accent.withValues(alpha: 0.2)
              : Colors.transparent,
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
