// ShareCardGenerator -- renders an off-screen event share card and captures
// it as a PNG image via RepaintBoundary.toImage().
//
// Usage:
//   final bytes = await ShareCardGenerator.capture(
//     EventShareCard(
//       title: event.name,
//       dateLabel: '2026-07-12',
//       venueLabel: 'Berghain, Berlin',
//       coverImageUrl: event.coverImageUrl,
//     ),
//   );
//   // Write bytes to a temp file, then share via ShareService.shareImage()

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Captures a widget tree as a PNG image without requiring it to be mounted
/// in the live widget hierarchy.
///
/// Uses a headless [RenderRepaintBoundary] pipeline:
///   1. Build an element tree for the given [card] widget.
///   2. Perform layout at a fixed [size].
///   3. Paint into an [OffsetLayer] and convert to [ui.Image].
///   4. Encode as PNG and return [Uint8List].
class ShareCardGenerator {
  ShareCardGenerator._();

  /// Captures [card] as a PNG at the given [pixelRatio].
  ///
  /// The widget is laid out at [size] logical pixels, producing an image of
  /// `size * pixelRatio` physical pixels.
  static Future<Uint8List> capture({
    required Widget card,
    double pixelRatio = 3.0,
    Size size = const Size(390, 520),
  }) async {
    // Wrap in a MediaQuery + Directionality so the widget tree can resolve
    // text direction and media queries without a full MaterialApp ancestor.
    final widget = MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: card,
      ),
    );

    final repaintBoundary = RenderRepaintBoundary();

    final renderView = _createRenderView(size, repaintBoundary);

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: widget,
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    buildOwner.finalizeTree();

    if (byteData == null) {
      throw StateError('ShareCardGenerator: failed to encode image as PNG');
    }

    return byteData.buffer.asUint8List();
  }

  static RenderView _createRenderView(
    Size size,
    RenderRepaintBoundary child,
  ) {
    final view = RenderView(
      view: ui.PlatformDispatcher.instance.implicitView!,
      child: child,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        devicePixelRatio: 1.0,
      ),
    );
    return view;
  }
}

// ---------------------------------------------------------------------------
// EventShareCard -- the visual layout of the shareable card
// ---------------------------------------------------------------------------

/// A self-contained widget that renders an event share card.
///
/// The card layout:
///   - Dark gradient background (dark navy -> black)
///   - Event cover image (top half, full-width)
///   - Event title (bold 24pt, white)
///   - Date + venue row (accent purple, 13pt)
///   - RAVEHUB wordmark (bottom-right, subtle)
///   - Accent-colour gradient border stroke
class EventShareCard extends StatelessWidget {
  /// Creates an [EventShareCard].
  const EventShareCard({
    required this.title,
    required this.dateLabel,
    required this.venueLabel,
    super.key,
    this.coverImageUrl,
  });

  /// Event name / title.
  final String title;

  /// Pre-formatted date string (e.g. "Jul 12, 2026").
  final String dateLabel;

  /// Venue name and city (e.g. "Berghain, Berlin").
  final String venueLabel;

  /// Optional cover image URL. When `null`, a dark placeholder is shown.
  final String? coverImageUrl;

  // -- Palette constants (avoids importing RaverColors for portability) -------

  static const _accentPurple = Color(0xFF8B5CF6);
  static const _gradientTop = Color(0xFF1A1A2E);
  static const _gradientBottom = Color(0xFF000000);
  static const _placeholderColor = Color(0xFF2A2A3E);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 390,
      height: 520,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_gradientTop, _gradientBottom],
        ),
        border: Border.all(
          color: _accentPurple.withValues(alpha: 0.4),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover image area
          _buildCoverArea(),

          // Info section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Futura',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Date row
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: _accentPurple, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: _accentPurple,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Venue row
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: _accentPurple, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          venueLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Wordmark
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      'RAVEHUB',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
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

  Widget _buildCoverArea() {
    if (coverImageUrl != null && coverImageUrl!.isNotEmpty) {
      return SizedBox(
        height: 260,
        child: Image.network(
          coverImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      height: 260,
      color: _placeholderColor,
      child: const Center(
        child: Icon(Icons.music_note, color: Colors.white24, size: 48),
      ),
    );
  }
}
