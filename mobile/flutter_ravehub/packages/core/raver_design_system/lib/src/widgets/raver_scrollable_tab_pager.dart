import 'package:flutter/material.dart';

import '../theme/raver_motion.dart';
import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// A horizontally scrollable tab bar with an animated underline indicator
/// and a [PageView] for swiping between tab content pages.
class RaverScrollableTabPager extends StatefulWidget {
  /// Creates a [RaverScrollableTabPager].
  const RaverScrollableTabPager({
    required this.tabs,
    required this.pages,
    super.key,
    this.initialIndex = 0,
    this.onPageChanged,
    this.tabPadding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// Labels for each tab.
  final List<String> tabs;

  /// Content widgets corresponding to each tab.
  final List<Widget> pages;

  /// The initially selected tab index.
  final int initialIndex;

  /// Called when the active page changes.
  final ValueChanged<int>? onPageChanged;

  /// Horizontal padding around each tab label.
  final EdgeInsets tabPadding;

  @override
  State<RaverScrollableTabPager> createState() =>
      _RaverScrollableTabPagerState();
}

class _RaverScrollableTabPagerState extends State<RaverScrollableTabPager>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _pageController = PageController(initialPage: widget.initialIndex);

    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _pageController.animateToPage(
        _tabController.index,
        duration: RaverMotion.normal,
        curve: RaverMotion.curve,
      );
    }
    widget.onPageChanged?.call(_tabController.index);
  }

  void _onPageSwiped(int index) {
    _tabController.animateTo(index);
    widget.onPageChanged?.call(index);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Column(
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.cardBorder,
                width: 0.5,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelPadding: widget.tabPadding,
            indicatorColor: theme.accent,
            // iOS: indicatorHeight 2.6
            indicatorWeight: 2.6,
            indicatorSize: TabBarIndicatorSize.label,
            // iOS: system 17pt regular for tab labels
            labelStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
            labelColor: theme.primaryText,
            unselectedLabelColor: theme.secondaryText,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            dividerColor: Colors.transparent,
            tabs: widget.tabs.map((label) => Tab(text: label)).toList(),
          ),
        ),

        // Page view
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageSwiped,
            children: widget.pages,
          ),
        ),
      ],
    );
  }
}
