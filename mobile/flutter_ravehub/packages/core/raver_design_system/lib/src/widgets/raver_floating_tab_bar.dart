import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:raver_platform/raver_platform.dart';

import '../theme/raver_shadows.dart';
import '../theme/raver_theme.dart';

class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// The signature glassmorphic floating tab bar for RaveHub.
///
/// Matches iOS MainTabView pixel-for-pixel:
/// - barVisualHeight 66pt, HStack spacing 6, icon 16pt semibold, label 11pt
/// - Capsule selection pill with interactiveSpring(response:0.26, damping:0.86)
/// - Search button 56×56 with gradient + glow + depth shadows + 1pt stroke
class RaverFloatingTabBar extends StatelessWidget {
  const RaverFloatingTabBar({
    required this.selectedIndex,
    required this.onTap,
    required this.onSearchTap,
    super.key,
    this.inboxBadgeCount = 0,
    this.hideWhenKeyboardVisible = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSearchTap;
  final int inboxBadgeCount;
  final bool hideWhenKeyboardVisible;

  static const _tabs = [
    _TabItem(icon: Icons.explore_outlined, label: 'Discover'),
    _TabItem(icon: Icons.people_outline, label: 'Circle'),
    _TabItem(icon: Icons.notifications_outlined, label: 'Inbox'),
    _TabItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  // iOS: barVisualHeight 66, capsule borderRadius 33
  static const double _barHeight = 66;
  static const double _barBorderRadius = 33;
  // iOS: search button 56×56 visual
  static const double _searchButtonSize = 56;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final brightness = Theme.of(context).brightness;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    if (hideWhenKeyboardVisible && isKeyboardVisible) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding > 0 ? max(4, bottomPadding - 14) : 4,
      ),
      child: Container(
        height: _barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_barBorderRadius),
          boxShadow: RaverShadows.tabBar(brightness),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_barBorderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_barBorderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.tabBarChromeStart,
                    theme.tabBarChromeEnd,
                  ],
                ),
                border: _GradientBorder(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.tabBarStrokeLeading,
                      theme.tabBarStrokeTrailing,
                    ],
                  ),
                  width: 1,
                  borderRadius: BorderRadius.circular(_barBorderRadius),
                ),
              ),
              child: _TabBarContent(
                selectedIndex: selectedIndex,
                onTap: onTap,
                onSearchTap: onSearchTap,
                inboxBadgeCount: inboxBadgeCount,
                theme: theme,
                brightness: brightness,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBarContent extends StatelessWidget {
  const _TabBarContent({
    required this.selectedIndex,
    required this.onTap,
    required this.onSearchTap,
    required this.inboxBadgeCount,
    required this.theme,
    required this.brightness,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSearchTap;
  final int inboxBadgeCount;
  final RaverThemeData theme;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final slotWidth = totalWidth / 5; // 4 tabs + 1 search

        return Stack(
          children: [
            _SelectionIndicator(
              selectedIndex: selectedIndex,
              slotWidth: slotWidth,
              theme: theme,
            ),
            Row(
              children: [
                _buildTab(0, slotWidth),
                _buildTab(1, slotWidth),
                _buildSearchButton(slotWidth),
                _buildTab(2, slotWidth),
                _buildTab(3, slotWidth),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTab(int index, double width) {
    final tab = RaverFloatingTabBar._tabs[index];
    final isSelected = index == selectedIndex;
    void handleTap() {
      unawaited(HapticService.selectionClick());
      onTap(index);
    }

    return SizedBox(
      width: width,
      // iOS: tab item height 52pt (inner)
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handleTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    tab.icon,
                    key: ValueKey('${tab.label}_$isSelected'),
                    // iOS: icon 16pt semibold weight (size approximation)
                    size: 16,
                    color: isSelected ? Colors.white : theme.secondaryText,
                  ),
                ),
                // Badge on Inbox tab (index 2)
                if (index == 2 && inboxBadgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.86),
                          width: 1,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        inboxBadgeCount > 99 ? '99+' : '$inboxBadgeCount',
                        // iOS: badge text 9pt bold
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            // iOS: VStack spacing 3 between icon and label
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              // iOS: label 11pt semibold (selected) / medium (unselected)
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : theme.secondaryText,
                height: 1.0,
              ),
              child: Text(tab.label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton(double width) {
    void handleSearchTap() {
      unawaited(HapticService.mediumImpact());
      onSearchTap();
    }

    return SizedBox(
      width: width,
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: handleSearchTap,
          child: Semantics(
            key: const ValueKey('raver_floating_tab_bar_search_button'),
            button: true,
            label: 'Search',
            child: Container(
              width: RaverFloatingTabBar._searchButtonSize,
              height: RaverFloatingTabBar._searchButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.accent,
                    // iOS second stop: Color(red:0.31, green:0.22, blue:0.88)
                    const Color(0xFF4F38E0),
                  ],
                ),
                // iOS search button: 1pt white@0.32 stroke
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.32),
                  width: 1,
                ),
                boxShadow: [
                  // iOS: accent glow, radius 14, y 8
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.36),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                  // iOS: black depth, radius 10, y 6
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search,
                color: Colors.white,
                // iOS: 21pt bold
                size: 21,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated selection capsule that uses spring physics matching iOS
/// `.interactiveSpring(response: 0.26, dampingFraction: 0.86)`.
class _SelectionIndicator extends StatefulWidget {
  const _SelectionIndicator({
    required this.selectedIndex,
    required this.slotWidth,
    required this.theme,
  });

  final int selectedIndex;
  final double slotWidth;
  final RaverThemeData theme;

  @override
  State<_SelectionIndicator> createState() => _SelectionIndicatorState();
}

class _SelectionIndicatorState extends State<_SelectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _fromLeft = 0;
  double _toLeft = 0;

  // iOS: interactiveSpring(response: 0.26, dampingFraction: 0.86)
  static SpringDescription _spring() {
    const response = 0.26;
    const dampingFraction = 0.86;
    final omega = 2 * pi / response;
    return SpringDescription(
      mass: 1.0,
      stiffness: omega * omega,
      damping: 2 * dampingFraction * omega,
    );
  }

  double _targetLeft(int index, double slotWidth) {
    final slotIndex = switch (index) {
      0 => 0,
      1 => 1,
      2 => 3,
      3 => 4,
      _ => 0,
    };
    final indicatorWidth = slotWidth - 12;
    return slotIndex * slotWidth + (slotWidth - indicatorWidth) / 2;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this);
    _toLeft = _targetLeft(widget.selectedIndex, widget.slotWidth);
    _ctrl.value = _toLeft;
    _fromLeft = _toLeft;
  }

  @override
  void didUpdateWidget(_SelectionIndicator old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex ||
        old.slotWidth != widget.slotWidth) {
      _fromLeft = _ctrl.value;
      _toLeft = _targetLeft(widget.selectedIndex, widget.slotWidth);
      _ctrl.stop();
      final sim = SpringSimulation(_spring(), _fromLeft, _toLeft, 0);
      _ctrl.animateWith(sim);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Positioned(
          left: _ctrl.value,
          top: 6,
          bottom: 6,
          width: widget.slotWidth - 12,
          child: child!,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.theme.tabBarSelectionStart,
              widget.theme.tabBarSelectionEnd,
            ],
          ),
          // iOS: 1pt white selection stroke
          border: Border.all(
            color: widget.theme.tabBarSelectionStroke,
            width: 0.5,
          ),
        ),
      ),
    );
  }
}

class _GradientBorder extends BoxBorder {
  const _GradientBorder({
    required this.gradient,
    required this.width,
    required this.borderRadius,
  });

  final Gradient gradient;
  final double width;
  final BorderRadius borderRadius;

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final effectiveRadius = borderRadius ?? this.borderRadius;
    final rrect = effectiveRadius.toRRect(rect).deflate(width / 2);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawRRect(rrect, paint);
  }

  @override
  ShapeBorder scale(double t) => _GradientBorder(
        gradient: gradient,
        width: width * t,
        borderRadius: borderRadius * t,
      );
}
