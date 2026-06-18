import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:raver_models/raver_models.dart';

import 'genre_theme_palette.dart';

class SunburstSector {
  SunburstSector({
    required this.node,
    required this.startAngle,
    required this.sweepAngle,
    required this.depth,
    required this.color,
  });

  final GenreSunburstNode node;
  final double startAngle;
  final double sweepAngle;
  final int depth;
  final Color color;
}

class GenreSunburstPainter extends CustomPainter {
  GenreSunburstPainter({
    required this.roots,
    required this.expandProgress,
    this.selectedId,
    this.maxDepth = 4,
    this.isDark = false,
  }) {
    _buildSectors();
  }

  final List<GenreSunburstNode> roots;
  final double expandProgress;
  final String? selectedId;
  final int maxDepth;
  final bool isDark;

  final List<SunburstSector> sectors = [];

  void _buildSectors() {
    sectors.clear();
    if (roots.isEmpty) return;

    final totalChildren = roots.fold<int>(
      0,
      (sum, n) => sum + _countLeaves(n),
    );

    double angle = -math.pi / 2;
    for (final root in roots) {
      final leaves = _countLeaves(root);
      final sweep = (leaves / totalChildren) * 2 * math.pi;
      _layoutNode(root, angle, sweep, 0);
      angle += sweep;
    }
  }

  int _countLeaves(GenreSunburstNode node) {
    final children = node.children;
    if (children == null || children.isEmpty) return 1;
    return children.fold<int>(0, (s, c) => s + _countLeaves(c));
  }

  void _layoutNode(
    GenreSunburstNode node,
    double startAngle,
    double sweepAngle,
    int depth,
  ) {
    if (depth >= maxDepth) return;

    final color = LearnGenreThemePalette.colorForGenre(
      node.name,
      hexColor: node.themeColor,
      depth: depth,
    );

    sectors.add(SunburstSector(
      node: node,
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      depth: depth,
      color: depth > 0
          ? LearnGenreThemePalette.lighten(color, depth * 0.08)
          : color,
    ));

    final children = node.children;
    if (children == null || children.isEmpty) return;

    final totalLeaves =
        children.fold<int>(0, (s, c) => s + _countLeaves(c));
    double childAngle = startAngle;
    for (final child in children) {
      final leaves = _countLeaves(child);
      final childSweep = (leaves / totalLeaves) * sweepAngle;
      _layoutNode(child, childAngle, childSweep, depth + 1);
      childAngle += childSweep;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 8;
    final ringWidth = maxRadius / (maxDepth + 0.5);

    for (final sector in sectors) {
      final innerR = ringWidth * (sector.depth + 0.5);
      final outerR = innerR + ringWidth;
      if (outerR <= 0) continue;

      final animatedSweep = sector.sweepAngle * expandProgress;
      if (animatedSweep <= 0) continue;

      final isSelected = sector.node.id == selectedId;
      final paint = Paint()
        ..color = isSelected
            ? sector.color
            : sector.color.withValues(alpha: isDark ? 0.85 : 0.9)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..addArc(
          Rect.fromCircle(center: center, radius: outerR),
          sector.startAngle,
          animatedSweep,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerR),
          sector.startAngle + animatedSweep,
          -animatedSweep,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      final borderPaint = Paint()
        ..color = isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(path, borderPaint);

      if (isSelected) {
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawPath(path, highlightPaint);
      }

      if (sector.sweepAngle > 0.15 && sector.depth < 2) {
        _drawLabel(canvas, center, innerR, outerR, sector);
      }
    }

    _drawCenterCircle(canvas, center, ringWidth * 0.5);
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    double innerR,
    double outerR,
    SunburstSector sector,
  ) {
    final midAngle = sector.startAngle + sector.sweepAngle / 2;
    final midR = (innerR + outerR) / 2;
    final pos = Offset(
      center.dx + midR * math.cos(midAngle),
      center.dy + midR * math.sin(midAngle),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: sector.node.name,
        style: TextStyle(
          color: _textColorOn(sector.color),
          fontSize: sector.depth == 0 ? 11 : 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: outerR - innerR - 4);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    double rotation = midAngle;
    if (rotation > math.pi / 2 && rotation < 3 * math.pi / 2) {
      rotation += math.pi;
    }
    canvas.rotate(rotation);
    canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawCenterCircle(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF1A1A2E) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    final borderPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);
  }

  Color _textColorOn(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  bool shouldRepaint(covariant GenreSunburstPainter oldDelegate) =>
      expandProgress != oldDelegate.expandProgress ||
      selectedId != oldDelegate.selectedId ||
      roots != oldDelegate.roots ||
      isDark != oldDelegate.isDark ||
      maxDepth != oldDelegate.maxDepth;

  SunburstSector? sectorAt(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 8;
    final ringWidth = maxRadius / (maxDepth + 0.5);

    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    double angle = math.atan2(dy, dx);
    if (angle < -math.pi / 2) angle += 2 * math.pi;

    for (final sector in sectors.reversed) {
      final innerR = ringWidth * (sector.depth + 0.5);
      final outerR = innerR + ringWidth;

      if (dist < innerR || dist > outerR) continue;

      double sStart = sector.startAngle;
      double sEnd = sStart + sector.sweepAngle;
      if (sStart < -math.pi) sStart += 2 * math.pi;
      if (sEnd < -math.pi) sEnd += 2 * math.pi;

      if (_angleInRange(angle, sector.startAngle, sector.sweepAngle)) {
        return sector;
      }
    }
    return null;
  }

  bool _angleInRange(double angle, double start, double sweep) {
    double normalizedAngle = (angle - start) % (2 * math.pi);
    if (normalizedAngle < 0) normalizedAngle += 2 * math.pi;
    return normalizedAngle <= sweep;
  }
}
