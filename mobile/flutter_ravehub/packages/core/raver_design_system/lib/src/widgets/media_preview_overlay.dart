import 'package:flutter/material.dart';

/// A full-screen overlay for previewing images and videos.
///
/// Supports pinch-to-zoom on images and vertical swipe-to-dismiss.
class MediaPreviewOverlay extends StatefulWidget {
  /// Creates a [MediaPreviewOverlay].
  const MediaPreviewOverlay({
    required this.mediaUrls,
    super.key,
    this.initialIndex = 0,
    this.heroTagPrefix,
  });

  /// URLs of the media items to preview.
  final List<String> mediaUrls;

  /// The index of the initially visible item.
  final int initialIndex;

  /// Optional prefix for Hero animation tags.
  final String? heroTagPrefix;

  /// Shows the overlay as a full-screen modal route.
  static Future<void> show(
    BuildContext context, {
    required List<String> mediaUrls,
    int initialIndex = 0,
    String? heroTagPrefix,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => MediaPreviewOverlay(
          mediaUrls: mediaUrls,
          initialIndex: initialIndex,
          heroTagPrefix: heroTagPrefix,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  State<MediaPreviewOverlay> createState() => _MediaPreviewOverlayState();
}

class _MediaPreviewOverlayState extends State<MediaPreviewOverlay> {
  late final PageController _pageController;
  late int _currentIndex;
  double _dragOffset = 0;
  double _opacity = 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      _opacity = (1 - (_dragOffset.abs() / 300)).clamp(0.4, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 100 ||
        details.velocity.pixelsPerSecond.dy.abs() > 800) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
        _opacity = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: _opacity),
      body: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Stack(
          children: [
            // Image page view
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.mediaUrls.length,
                onPageChanged: (index) =>
                    setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final url = widget.mediaUrls[index];
                  final heroTag = widget.heroTagPrefix != null
                      ? '${widget.heroTagPrefix}_$index'
                      : null;

                  Widget image = InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: Colors.white70,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  );

                  if (heroTag != null) {
                    image = Hero(tag: heroTag, child: image);
                  }

                  return image;
                },
              ),
            ),

            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // Page indicator
            if (widget.mediaUrls.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.mediaUrls.length,
                    (index) => Container(
                      width: index == _currentIndex ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _currentIndex
                            ? Colors.white
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
