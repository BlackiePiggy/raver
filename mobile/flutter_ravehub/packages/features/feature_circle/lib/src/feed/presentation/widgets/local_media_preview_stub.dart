import 'package:flutter/widgets.dart';

Widget buildPlatformLocalImagePreview({
  required String path,
  required BoxFit fit,
  required Widget errorWidget,
}) {
  return Image.network(
    path,
    fit: fit,
    errorBuilder: (_, __, ___) => errorWidget,
  );
}
