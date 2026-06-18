import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

const _termsUrl = 'https://ravehub.top/legal/terms';
const _privacyUrl = 'https://ravehub.top/legal/privacy';

/// Inline legal agreement text with tappable Terms and Privacy links.
class AuthLegalAgreementText extends StatelessWidget {
  /// Creates an [AuthLegalAgreementText].
  const AuthLegalAgreementText({
    super.key,
    required this.accent,
    this.compact = false,
  });

  /// Accent color used for links.
  final Color accent;

  /// Whether to keep text to a single compact line when possible.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final baseStyle = RaverTypography.caption(
      size: compact ? 12 : 13,
      color: Colors.white.withValues(alpha: compact ? 0.38 : 0.84),
    );
    final linkStyle = baseStyle.copyWith(
      color: accent,
      fontWeight: FontWeight.w600,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: lt('我已阅读并同意 ', 'I agree to the ', '同意する ')),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _LegalLink(
              label: lt('用户协议', 'Terms of Service', '利用規約'),
              style: linkStyle,
              url: _termsUrl,
            ),
          ),
          TextSpan(text: lt(' 和 ', ' and ', ' と ')),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _LegalLink(
              label: lt('隐私政策', 'Privacy Policy', 'プライバシーポリシー'),
              style: linkStyle,
              url: _privacyUrl,
            ),
          ),
        ],
      ),
      maxLines: compact ? 1 : 3,
      overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.style,
    required this.url,
  });

  final String label;
  final TextStyle style;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        try {
          await UrlLauncherService.openExternalUrl(url);
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lt('无法打开链接', 'Unable to open link', 'リンクを開けません'),
              ),
            ),
          );
        }
      },
      child: Text(label, style: style),
    );
  }
}
