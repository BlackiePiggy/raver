import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../data/registration_region_catalog.dart';
import 'view_models/register_view_model.dart';
import 'widgets/auth_legal_agreement_text.dart';

/// Registration screen for creating a new RaveHub account.
///
/// Features display-name availability checking, password strength hints,
/// and the RaveHub dark/purple theme.
class RegisterScreen extends ConsumerStatefulWidget {
  /// Creates the [RegisterScreen].
  ///
  /// [returnTo] is an optional deep-link path to redirect after registration.
  const RegisterScreen({super.key, this.returnTo});

  /// Optional path to navigate to after successful registration.
  final String? returnTo;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  RegistrationRegionCatalog _regionCatalog = RegistrationRegionCatalog.fallback;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    RegistrationRegionCatalog.load().then((catalog) {
      if (!mounted) return;
      setState(() => _regionCatalog = catalog);
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
    String? helperText,
    Color? helperColor,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: RaverTypography.body(size: 14, color: Colors.white60),
      helperText: helperText,
      helperStyle: RaverTypography.caption(
        size: 12,
        color: helperColor ?? Colors.white30,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD93636)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD93636), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _onRegister() async {
    final notifier = ref.read(registerProvider.notifier);
    final success = await notifier.register();
    if (success && mounted) {
      if (widget.returnTo != null) {
        context.go(widget.returnTo!);
      } else {
        context.go('/login');
      }
    }
  }

  Color _passwordStrengthColor(String? hint) {
    if (hint == null) return Colors.white30;
    return switch (hint) {
      'Too short (min 8 characters)' => const Color(0xFFD93636),
      'Weak' => const Color(0xFFE08B2D),
      'Fair' => const Color(0xFFE0C82D),
      'Good' => const Color(0xFF5EC269),
      'Strong' => const Color(0xFF1B9E5C),
      _ => Colors.white30,
    };
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerProvider);
    final notifier = ref.read(registerProvider.notifier);
    final accent = RaverColors.accent(Brightness.dark);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Dark gradient background ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A0A2E),
                  Color(0xFF0D0D1A),
                  Color(0xFF08080A),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // --- Decorative glow ---
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.2),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // --- Content ---
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // --- App bar ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),

                  // --- Scrollable form ---
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),

                          // --- Title ---
                          Text(
                            lt('创建账号', 'Create Account', 'アカウント作成'),
                            style: RaverTypography.headline(
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lt(
                              '加入RaveHub，发现电子音乐的世界',
                              'Join RaveHub and discover the world of EDM',
                              'RaveHubに参加して、EDMの世界を発見しよう',
                            ),
                            style: RaverTypography.body(
                              size: 14,
                              color: Colors.white38,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // --- Error message ---
                          if (state.errorMessage != null) ...[
                            _buildErrorBanner(state.errorMessage!),
                            const SizedBox(height: 16),
                          ],

                          // --- Display name ---
                          _buildDisplayNameField(state, notifier, accent),
                          const SizedBox(height: 18),

                          // --- Email ---
                          TextField(
                            controller: _emailController,
                            onChanged: notifier.setEmail,
                            keyboardType: TextInputType.emailAddress,
                            style: RaverTypography.body(
                              size: 15,
                              color: Colors.white,
                            ),
                            cursorColor: accent,
                            decoration: _inputDecoration(
                              label: lt('邮箱地址', 'Email Address', 'メールアドレス'),
                              accent: accent,
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // --- Password ---
                          TextField(
                            controller: _passwordController,
                            onChanged: notifier.setPassword,
                            obscureText: !state.passwordVisible,
                            style: RaverTypography.body(
                              size: 15,
                              color: Colors.white,
                            ),
                            cursorColor: accent,
                            decoration: _inputDecoration(
                              label: lt('密码', 'Password', 'パスワード'),
                              accent: accent,
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Colors.white38,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                onPressed: notifier.togglePasswordVisibility,
                                icon: Icon(
                                  state.passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                              ),
                              helperText: state.passwordStrengthHint,
                              helperColor: _passwordStrengthColor(
                                state.passwordStrengthHint,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // --- Confirm password ---
                          TextField(
                            controller: _confirmPasswordController,
                            onChanged: notifier.setConfirmPassword,
                            obscureText: !state.confirmPasswordVisible,
                            style: RaverTypography.body(
                              size: 15,
                              color: Colors.white,
                            ),
                            cursorColor: accent,
                            decoration: _inputDecoration(
                              label: lt('确认密码', 'Confirm Password', 'パスワード確認'),
                              accent: accent,
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Colors.white38,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                onPressed:
                                    notifier.toggleConfirmPasswordVisibility,
                                icon: Icon(
                                  state.confirmPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                              ),
                              helperText: state.confirmPassword.isNotEmpty &&
                                      !state.passwordsMatch
                                  ? lt('密码不匹配', 'Passwords do not match',
                                      'パスワードが一致しません')
                                  : null,
                              helperColor: const Color(0xFFD93636),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // --- Regional compliance ---
                          _buildRegionalComplianceFields(
                            state,
                            notifier,
                            accent,
                          ),

                          const SizedBox(height: 18),

                          // --- Home city ---
                          _buildHomeCityFields(state, notifier, accent),

                          const SizedBox(height: 24),

                          // --- Terms agreement ---
                          _buildTermsCheckbox(state, notifier, accent),

                          const SizedBox(height: 28),

                          // --- Register button ---
                          PrimaryButton(
                            label: lt('注册', 'Register', '新規登録'),
                            onPressed: state.canRegister ? _onRegister : null,
                            isLoading: state.isLoading,
                            isExpanded: true,
                          ),

                          const SizedBox(height: 20),

                          // --- Login link ---
                          Center(
                            child: TextButton(
                              onPressed: () => context.pop(),
                              child: Text.rich(
                                TextSpan(
                                  text: lt('已有账号？', 'Already have an account? ',
                                      'すでにアカウントをお持ちの方 '),
                                  style: RaverTypography.body(
                                    size: 14,
                                    color: Colors.white54,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: lt('登录', 'Login', 'ログイン'),
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
                ],
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

  Widget _buildDisplayNameField(
    RegisterState state,
    RegisterNotifier notifier,
    Color accent,
  ) {
    // Build the suffix widget based on availability status
    Widget? suffix;
    String? helper;
    Color? helperColor;

    if (state.isCheckingDisplayName) {
      suffix = const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
          ),
        ),
      );
    } else if (state.displayName.length >= 2) {
      if (state.displayNameCheckFailed) {
        suffix = const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.info_outline, color: Color(0xFFE0C82D), size: 20),
        );
        helper = lt(
          '暂时无法检查名称，提交时将再次校验',
          'Could not check now; registration will validate again',
          '現在確認できません。登録時に再確認します',
        );
        helperColor = const Color(0xFFE0C82D);
      } else if (state.isDisplayNameAvailable) {
        suffix = const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.check_circle, color: Color(0xFF1B9E5C), size: 20),
        );
        helper = lt('该名称可用', 'Name is available', '利用可能な名前です');
        helperColor = const Color(0xFF1B9E5C);
      } else {
        suffix = const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.cancel, color: Color(0xFFD93636), size: 20),
        );
        helper = lt('该名称已被使用', 'Name is already taken', 'この名前は既に使用されています');
        helperColor = const Color(0xFFD93636);
      }
    }

    return TextField(
      controller: _displayNameController,
      onChanged: notifier.setDisplayName,
      style: RaverTypography.body(size: 15, color: Colors.white),
      cursorColor: accent,
      maxLength: 24,
      decoration: _inputDecoration(
        label: lt('显示名称', 'Display Name', '表示名'),
        accent: accent,
        prefixIcon: const Icon(
          Icons.person_outline,
          color: Colors.white38,
          size: 20,
        ),
        suffixIcon: suffix,
        helperText: helper,
        helperColor: helperColor,
      ).copyWith(counterText: ''),
    );
  }

  Widget _buildRegionalComplianceFields(
    RegisterState state,
    RegisterNotifier notifier,
    Color accent,
  ) {
    final years = List<int>.generate(
      DateTime.now().year - 1900 + 1,
      (index) => DateTime.now().year - index,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: state.regionCode,
          dropdownColor: const Color(0xFF171721),
          iconEnabledColor: Colors.white54,
          style: RaverTypography.body(size: 15, color: Colors.white),
          decoration: _inputDecoration(
            label: lt('地区', 'Region', '地域'),
            accent: accent,
            prefixIcon: const Icon(
              Icons.public,
              color: Colors.white38,
              size: 20,
            ),
          ),
          items: [
            DropdownMenuItem(
              value: 'GLOBAL',
              child: Text(lt('全球', 'Global', 'グローバル')),
            ),
            DropdownMenuItem(
              value: 'JP',
              child: Text(lt('日本', 'Japan', '日本')),
            ),
          ],
          onChanged: (value) {
            if (value != null) notifier.setRegionCode(value);
          },
        ),
        if (state.requiresAgeDeclaration) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: state.birthYear,
            dropdownColor: const Color(0xFF171721),
            iconEnabledColor: Colors.white54,
            style: RaverTypography.body(size: 15, color: Colors.white),
            decoration: _inputDecoration(
              label: lt('出生年份', 'Birth Year', '生年'),
              accent: accent,
              prefixIcon: const Icon(
                Icons.cake_outlined,
                color: Colors.white38,
                size: 20,
              ),
              helperText: state.isAgeDeclarationValid
                  ? lt(
                      '仅用于年龄分级和未成年人保护',
                      'Used only for age rating and minor safety',
                      '年齢区分と未成年者保護のみに使用します',
                    )
                  : lt(
                      '未达到本地区最低年龄要求',
                      'You do not meet the minimum age requirement',
                      'この地域の最低年齢要件を満たしていません',
                    ),
              helperColor: state.isAgeDeclarationValid
                  ? Colors.white30
                  : const Color(0xFFD93636),
            ),
            items: [
              for (final year in years)
                DropdownMenuItem(value: year, child: Text('$year')),
            ],
            onChanged: (value) {
              if (value != null) notifier.setBirthYear(value);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildHomeCityFields(
    RegisterState state,
    RegisterNotifier notifier,
    Color accent,
  ) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final selectedCountry = _regionCatalog.country(state.homeCountryCode);
    final selectedRegion = _regionCatalog.region(
      countryCode: selectedCountry.code,
      regionCode: state.homeRegionCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('常驻城市', 'Home City', '居住都市'),
          style: RaverTypography.label(size: 13, color: Colors.white70),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedCountry.code,
          dropdownColor: const Color(0xFF171721),
          iconEnabledColor: Colors.white54,
          style: RaverTypography.body(size: 15, color: Colors.white),
          decoration: _inputDecoration(
            label: lt('国家/地区', 'Country/Region', '国/地域'),
            accent: accent,
            prefixIcon: const Icon(
              Icons.public,
              color: Colors.white38,
              size: 20,
            ),
          ),
          items: [
            for (final country in _regionCatalog.countries)
              DropdownMenuItem(
                value: country.code,
                child: Text(country.displayName(languageCode)),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            final country = _regionCatalog.country(value);
            final region = country.children.first;
            final city = region.children.first;
            notifier.setHomeCountry(
              countryCode: country.code,
              regionCode: region.code,
              cityCode: city.code,
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('home-region-${selectedCountry.code}'),
                initialValue: selectedRegion.code,
                dropdownColor: const Color(0xFF171721),
                iconEnabledColor: Colors.white54,
                style: RaverTypography.body(size: 15, color: Colors.white),
                decoration: _inputDecoration(
                  label: selectedCountry.regionLabel.isEmpty
                      ? lt('地区', 'Region', '地域')
                      : selectedCountry.regionLabel,
                  accent: accent,
                  prefixIcon: const Icon(
                    Icons.map_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                ),
                items: [
                  for (final region in selectedCountry.children)
                    DropdownMenuItem(
                      value: region.code,
                      child: Text(region.displayName(languageCode)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  final region = selectedCountry.children.firstWhere(
                    (item) => item.code == value,
                    orElse: () => selectedCountry.children.first,
                  );
                  notifier.setHomeRegion(
                    regionCode: region.code,
                    cityCode: region.children.first.code,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'home-city-${selectedCountry.code}-${selectedRegion.code}',
                ),
                initialValue: _regionCatalog
                    .city(
                      countryCode: selectedCountry.code,
                      regionCode: selectedRegion.code,
                      cityCode: state.homeCityCode,
                    )
                    .code,
                dropdownColor: const Color(0xFF171721),
                iconEnabledColor: Colors.white54,
                style: RaverTypography.body(size: 15, color: Colors.white),
                decoration: _inputDecoration(
                  label: selectedCountry.cityLabel.isEmpty
                      ? lt('城市', 'City', '市区町村')
                      : selectedCountry.cityLabel,
                  accent: accent,
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                ),
                items: [
                  for (final city in selectedRegion.children)
                    DropdownMenuItem(value: city.code, child: Text(city.name)),
                ],
                onChanged: (value) {
                  if (value != null) notifier.setHomeCity(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          lt(
            '会用于后续优先推荐你附近和同地区的活动。',
            'Used later to prioritize nearby and regional events.',
            '今後、近隣や同じ地域のイベント推薦に使われます。',
          ),
          style: RaverTypography.caption(size: 12, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox(
    RegisterState state,
    RegisterNotifier notifier,
    Color accent,
  ) {
    return Row(
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
          child: AuthLegalAgreementText(
            accent: accent,
          ),
        ),
      ],
    );
  }
}
