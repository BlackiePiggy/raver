import 'package:flutter/material.dart';

Widget buildWebRemoteCoverImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return Image.network(url, width: width, height: height, fit: fit);
}
