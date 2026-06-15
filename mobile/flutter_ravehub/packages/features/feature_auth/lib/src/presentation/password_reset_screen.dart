import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import 'view_models/password_reset_view_model.dart';

/// Forgot-password screen where the user enters their email to receive
/// a password-reset link.
class PasswordResetScreen extends StatefulWidget {
  /// Creates the [PasswordResetScreen].
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailController = TextEditingController();
  late final PasswordResetNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = PasswordResetNotifier();
    _notifier.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifier.removeListener(_rebuild);
    _notifier.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _notifier.state;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF1A1A2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),

              // Lock icon
              const Icon(
                Icons.lock_reset,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                lt('忘记密码', 'Forgot Password', 'パスワードリセット'),
                style: RaverTypography.headline(color: Colors.white),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  lt(
                    '输入您的注册邮箱，我们将发送重置链接',
                    'Enter your email to receive a reset link',
                    'リセットリンクを送信します',
                  ),
                  style: RaverTypography.body(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Email field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _notifier.setEmail,
                  decoration: InputDecoration(
                    hintText: lt('电子邮箱', 'Email Address', 'メールアドレス'),
                    hintStyle: const TextStyle(color: Colors.white38),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    state.errorMessage!,
                    style: RaverTypography.caption(color: Colors.redAccent),
                  ),
                ),

              // Success message
              if (state.isSuccess)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    lt('已发送！请检查邮箱', 'Sent! Check your email', '送信しました'),
                    style: RaverTypography.caption(color: Colors.greenAccent),
                  ),
                ),
              const SizedBox(height: 8),

              // Submit button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PrimaryButton(
                  label: lt('发送重置链接', 'Send Reset Link', 'リセットを送信'),
                  isLoading: state.isLoading,
                  isExpanded: true,
                  onPressed: _notifier.requestReset,
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
