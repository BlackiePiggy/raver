// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

final Set<String> _registeredViewTypes = <String>{};

Widget buildWebRemoteCoverImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  final viewType = 'raver-remote-cover-${url.hashCode}-${fit.name}';

  if (_registeredViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return html.ImageElement()
        ..src = url
        ..setAttribute('loading', 'lazy')
        ..setAttribute('decoding', 'async')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.border = '0'
        ..style.objectFit = _objectFitCss(fit);
    });
  }

  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewType),
  );
}

String _objectFitCss(BoxFit fit) {
  switch (fit) {
    case BoxFit.fill:
      return 'fill';
    case BoxFit.contain:
      return 'contain';
    case BoxFit.cover:
      return 'cover';
    case BoxFit.fitWidth:
      return 'cover';
    case BoxFit.fitHeight:
      return 'cover';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
  }
}
