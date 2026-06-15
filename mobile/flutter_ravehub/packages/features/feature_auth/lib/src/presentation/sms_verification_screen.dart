import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// The number of digits in a verification code.
const _codeLength = 6;

/// A dedicated SMS / email verification code input screen.
///
/// Displays six individual digit boxes with auto-advance and
/// auto-submit behaviour.
class SmsVerificationScreen extends ConsumerStatefulWidget {
  /// Creates a [SmsVerificationScreen].
  ///
  /// [destination] is the masked phone number or email shown to the user.
  /// [onVerified] is called with the 6-digit code when submitted.
  const SmsVerificationScreen({
    required this.destination,
    super.key,
    this.onVerified,
  });

  /// The phone number or email the code was sent to (for display).
  final String destination;

  /// Called when the user submits a complete 6-digit code.
  /// If null, the screen navigates back with the code as result.
  final ValueChanged<String>? onVerified;

  @override
  ConsumerState<SmsVerificationScreen> createState() =>
      _SmsVerificationScreenState();
}

class _SmsVerificationScreenState extends ConsumerState<SmsVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  bool _isVerifying = false;
  String? _errorMessage;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Auto-focus the first field after the frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
    _startCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Cooldown
  // ---------------------------------------------------------------------------

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _cooldownTimer?.cancel();
        }
      });
    });
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0) return;
    // TODO: call auth API to resend code
    _startCooldown();
  }

  // ---------------------------------------------------------------------------
  // Code input handling
  // ---------------------------------------------------------------------------

  void _onDigitChanged(int index, String value) {
    setState(() => _errorMessage = null);

    if (value.length == 1 && index < _codeLength - 1) {
      // Advance to next field
      _focusNodes[index + 1].requestFocus();
    }

    // Check if all digits are filled
    final code = _controllers.map((c) => c.text).join();
    if (code.length == _codeLength) {
      _submitCode(code);
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      // Move to previous field on backspace when current is empty
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _submitCode(String code) async {
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      if (widget.onVerified != null) {
        widget.onVerified!(code);
      } else {
        // TODO: verify code via auth API
        await Future<void>.delayed(const Duration(seconds: 1));
        if (mounted) {
          context.pop(code);
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = e.toString();
          // Clear all fields for retry
          for (final c in _controllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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

          SafeArea(
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

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),

                        // --- Title ---
                        Text(
                          lt('输入验证码', 'Enter Verification Code',
                              '認証コードを入力'),
                          style: RaverTypography.headline(
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          lt(
                            '验证码已发送至 ${widget.destination}',
                            'A code has been sent to ${widget.destination}',
                            '${widget.destination} にコードを送信しました',
                          ),
                          style: RaverTypography.body(
                            size: 14,
                            color: Colors.white54,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- Error message ---
                        if (_errorMessage != null) ...[
                          _buildErrorBanner(_errorMessage!),
                          const SizedBox(height: 20),
                        ],

                        // --- Code input boxes ---
                        _buildCodeInputRow(accent),

                        const SizedBox(height: 32),

                        // --- Verifying indicator ---
                        if (_isVerifying)
                          Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // --- Resend button ---
                        Center(
                          child: TextButton(
                            onPressed:
                                _resendCooldown <= 0 ? _resendCode : null,
                            child: Text(
                              _resendCooldown > 0
                                  ? lt(
                                      '重新发送 (${_resendCooldown}s)',
                                      'Resend Code (${_resendCooldown}s)',
                                      '再送信 (${_resendCooldown}s)',
                                    )
                                  : lt('重新发送验证码', 'Resend Code',
                                      'コードを再送信'),
                              style: RaverTypography.label(
                                size: 14,
                                color: _resendCooldown > 0
                                    ? Colors.white24
                                    : accent,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // --- Hint ---
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            lt(
                              '没有收到验证码？请检查垃圾邮件文件夹',
                              "Didn't receive a code? Check your spam folder",
                              'コードが届かない場合は迷惑メールフォルダをご確認ください',
                            ),
                            textAlign: TextAlign.center,
                            style: RaverTypography.caption(
                              size: 12,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildCodeInputRow(Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_codeLength, (index) {
        final hasValue = _controllers[index].text.isNotEmpty;
        final isFocused = _focusNodes[index].hasFocus;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 6,
              right: index == _codeLength - 1 ? 0 : 6,
            ),
            child: KeyboardListener(
              focusNode: FocusNode(), // wrapper; real focus is on the TextField
              onKeyEvent: (event) => _onKeyEvent(index, event),
              child: AnimatedContainer(
                duration: RaverMotion.fast,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: hasValue ? 0.12 : 0.06,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFocused
                        ? accent
                        : hasValue
                            ? accent.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.1),
                    width: isFocused ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    onChanged: (value) {
                      // Handle paste (multi-character input)
                      if (value.length > 1) {
                        _handlePaste(value, index);
                        return;
                      }
                      _onDigitChanged(index, value);
                    },
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: RaverTypography.headline(
                      size: 24,
                      color: Colors.white,
                    ),
                    cursorColor: accent,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Handles a paste event that puts multiple digits into one field.
  void _handlePaste(String pasted, int startIndex) {
    final digits = pasted.replaceAll(RegExp(r'[^0-9]'), '');
    for (var i = 0; i < digits.length && (startIndex + i) < _codeLength; i++) {
      _controllers[startIndex + i].text = digits[i];
    }

    // Focus the next empty field or the last one
    final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
    if (nextEmpty >= 0 && nextEmpty < _codeLength) {
      _focusNodes[nextEmpty].requestFocus();
    } else {
      _focusNodes[_codeLength - 1].requestFocus();
    }

    // Check if code is complete
    final code = _controllers.map((c) => c.text).join();
    if (code.length == _codeLength) {
      _submitCode(code);
    }
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
}
