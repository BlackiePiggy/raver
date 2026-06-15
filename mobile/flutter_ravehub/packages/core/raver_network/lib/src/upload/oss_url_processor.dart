/// Preset avatar sizes for DJ profile images.
///
/// Corresponds to the iOS `DJAvatarSize` enum used in `AppConfig.resolvedURLString()`.
enum DJAvatarSize {
  /// The original, unresized avatar image.
  original(width: 0, height: 0),

  /// Medium avatar (200x200), suitable for profile pages.
  medium(width: 200, height: 200),

  /// Small avatar (80x80), suitable for list items and comments.
  small(width: 80, height: 80);

  const DJAvatarSize({required this.width, required this.height});

  /// The target width in pixels, or 0 for original size.
  final int width;

  /// The target height in pixels, or 0 for original size.
  final int height;
}

/// Utility for building Alibaba Cloud OSS image-processing URLs.
///
/// Ported from the iOS `AppConfig.resolvedURLString()` method. Appends OSS
/// image-processing parameters to a raw object URL so that the CDN returns a
/// resized, quality-adjusted, WebP-formatted image.
///
/// See: https://help.aliyun.com/document_detail/44688.html
class OssUrlProcessor {
  /// Processes a raw OSS [url] and appends resize / quality / format
  /// parameters.
  ///
  /// Parameters:
  ///  * [width] -- target width in pixels (required for resize).
  ///  * [height] -- target height in pixels (required for resize).
  ///  * [quality] -- JPEG/WebP quality, 1-100. Defaults to 80.
  ///
  /// If neither [width] nor [height] is provided, only the quality and format
  /// directives are appended.
  ///
  /// HTTP URLs are automatically upgraded to HTTPS.
  static String process(
    String url, {
    int? width,
    int? height,
    int quality = 80,
  }) {
    if (url.isEmpty) return url;

    // Upgrade HTTP to HTTPS.
    var processedUrl = _ensureHttps(url);

    // Build OSS image-processing pipeline.
    final segments = <String>[];

    if (width != null && width > 0 && height != null && height > 0) {
      segments.add('image/resize,m_fill,w_$width,h_$height');
    } else if (width != null && width > 0) {
      segments.add('image/resize,m_lfit,w_$width');
    } else if (height != null && height > 0) {
      segments.add('image/resize,m_lfit,h_$height');
    }

    segments.add('quality,Q_$quality');
    segments.add('format,webp');

    final processingQuery = segments.join('/');

    // Append as query parameter.
    if (processedUrl.contains('?')) {
      processedUrl = '$processedUrl&x-oss-process=$processingQuery';
    } else {
      processedUrl = '$processedUrl?x-oss-process=$processingQuery';
    }

    return processedUrl;
  }

  /// Returns a processed URL suitable for a DJ avatar at the given [size].
  ///
  /// For [DJAvatarSize.original], only HTTPS upgrade and format conversion
  /// are applied (no resize).
  static String djAvatar(String url, DJAvatarSize size) {
    if (size == DJAvatarSize.original) {
      return process(url);
    }

    return process(
      url,
      width: size.width,
      height: size.height,
    );
  }

  /// Converts an `http://` URL to `https://`. Leaves other schemes unchanged.
  static String _ensureHttps(String url) {
    if (url.startsWith('http://')) {
      return 'https://${url.substring(7)}';
    }
    return url;
  }
}
