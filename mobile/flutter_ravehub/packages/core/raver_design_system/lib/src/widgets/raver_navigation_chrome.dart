import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/raver_motion.dart';
import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// A custom app-bar chrome with backdrop blur and scroll-responsive opacity.
///
/// As the user scrolls, the chrome transitions from transparent to a
/// frosted-glass fill, providing a seamless content-under-bar effect.
class RaverNavigationChrome extends StatelessWidget
    implements PreferredSizeWidget {
  /// Creates a [RaverNavigationChrome].
  const RaverNavigationChrome({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.trailing,
    this.scrollOffset = 0,
    this.opacityThreshold = 60,
    this.height = 56,
    this.blurSigma = 24,
    this.showBorder = true,
  });

  /// Title text displayed in the centre.
  final String? title;

  /// Optional custom title widget (takes precedence over [title]).
  final Widget? titleWidget;

  /// Leading widget (e.g. back button).
  final Widget? leading;

  /// Trailing widget (e.g. action buttons).
  final Widget? trailing;

  /// Current scroll offset used to interpolate the chrome opacity.
  /// Typically comes from a [ScrollController].
  final double scrollOffset;

  /// Scroll offset at which the chrome reaches full opacity.
  final double opacityThreshold;

  /// Height of the chrome bar (excludes status bar padding).
  final double height;

  /// Gaussian blur sigma for the backdrop filter.
  final double blurSigma;

  /// Whether to show a bottom border when scrolled.
  final bool showBorder;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final topPadding = MediaQuery.of(context).padding.top;

    // Interpolate opacity based on scroll position.
    final progress =
        (scrollOffset / opacityThreshold).clamp(0.0, 1.0);
    final chromeOpacity = progress;
    final borderOpacity = progress;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma * chromeOpacity,
          sigmaY: blurSigma * chromeOpacity,
        ),
        child: AnimatedContainer(
          duration: RaverMotion.fast,
          decoration: BoxDecoration(
            color: theme.card.withValues(
              alpha: 0.85 * chromeOpacity,
            ),
            border: showBorder
                ? Border(
                    bottom: BorderSide(
                      color: theme.cardBorder.withValues(
                        alpha: borderOpacity,
                      ),
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  // Leading
                  SizedBox(
                    width: 56,
                    child: leading ??
                        (Navigator.of(context).canPop()
                            ? IconButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 20,
                                  color: theme.primaryText,
                                ),
                              )
                            : null),
                  ),

                  // Title
                  Expanded(
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: title != null || titleWidget != null
                            ? 1.0
                            : 0.0,
                        duration: RaverMotion.fast,
                        child: titleWidget ??
                            (title != null
                                ? Text(
                                    title!,
                                    style: RaverTypography.title(
                                      color: theme.primaryText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : const SizedBox.shrink()),
                      ),
                    ),
                  ),

                  // Trailing
                  SizedBox(
                    width: 56,
                    child: trailing,
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
