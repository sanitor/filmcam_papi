import 'package:flutter/material.dart';

class ScreenScale {
  ScreenScale(this.context);

  final BuildContext context;

  static const double referenceWidth = 375;

  double get scale {
    final w = MediaQuery.of(context).size.width;
    return (w / referenceWidth).clamp(0.6, 2.0);
  }

  double sp(double size) => size * scale;
  double padding(double p) => p * scale;

  double textScale(double size) => size * scale;
}
