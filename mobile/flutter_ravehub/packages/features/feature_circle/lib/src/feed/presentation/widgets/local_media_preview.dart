import 'package:flutter/widgets.dart';

import 'local_media_preview_stub.dart'
    if (dart.library.io) 'local_media_preview_io.dart';

Widget buildLocalImagePreview({
  required String path,
  required BoxFit fit,
  required Widget errorWidget,
}) {
  return buildPlatformLocalImagePreview(
    path: path,
    fit: fit,
    errorWidget: errorWidget,
  );
}
