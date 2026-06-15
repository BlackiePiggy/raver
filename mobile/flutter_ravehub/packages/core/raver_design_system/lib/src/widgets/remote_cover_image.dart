import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/raver_theme.dart';

/// A cached network image widget with Alibaba Cloud OSS URL processing.
///
/// Automatically appends OSS resize parameters to the URL for optimal
/// loading performance and memory usage.
class RemoteCoverImage extends StatelessWidget {
  /// Creates a [RemoteCoverImage].
  const RemoteCoverImage({
    required this.url,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor,
  });

  /// The original image URL.
  final String url;

  /// Layout width. Also used to compute the OSS resize parameter.
  final double? width;

  /// Layout height. Also used to compute the OSS resize parameter.
  final double? height;

  /// How the image should be inscribed into the layout bounds.
  final BoxFit fit;

  /// Optional border radius to clip the image.
  final BorderRadius? borderRadius;

  /// Colour used for the placeholder while the image is loading.
  final Color? placeholderColor;

  /// Appends Alibaba Cloud OSS image-processing parameters to [rawUrl].
  ///
  /// This produces a resized version of the image so the client does not
  /// download the full-resolution original.
  static String processOssUrl(
    String rawUrl, {
    double? targetWidth,
    double? targetHeight,
  }) {
    if (rawUrl.isEmpty) return rawUrl;

    // Only process URLs pointing at the known OSS bucket.
    if (!rawUrl.contains('oss-cn-') && !rawUrl.contains('aliyuncs.com')) {
      return rawUrl;
    }

    // Already has processing parameters.
    if (rawUrl.contains('x-oss-process=')) return rawUrl;

    final buffer = StringBuffer(rawUrl);
    buffer.write('?x-oss-process=image/resize');

    if (targetWidth != null) {
      buffer.write(',w_${targetWidth.toInt()}');
    }
    if (targetHeight != null) {
      buffer.write(',h_${targetHeight.toInt()}');
    }

    // Default quality and format optimisation.
    buffer.write('/quality,q_85/format,webp');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    // Compute physical pixel dimensions for the OSS resize.
    final physicalWidth =
        width != null ? (width! * devicePixelRatio) : null;
    final physicalHeight =
        height != null ? (height! * devicePixelRatio) : null;

    final processedUrl = processOssUrl(
      url,
      targetWidth: physicalWidth,
      targetHeight: physicalHeight,
    );

    final placeholder = Container(
      width: width,
      height: height,
      color: placeholderColor ?? theme.cardBorder,
    );

    Widget image = CachedNetworkImage(
      imageUrl: processedUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: theme.cardBorder,
        child: Icon(
          Icons.broken_image_outlined,
          color: theme.secondaryText,
          size: 24,
        ),
      ),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
