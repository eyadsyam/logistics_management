import 'dart:math';
import 'package:flutter/material.dart';

/// Responsive utility that scales dimensions relative to a reference device.
///
/// Reference device: 375 × 812 (iPhone 13 mini — standard design target).
/// All dimensions passed to [w], [h], [sp] are in "design pixels" and get
/// scaled proportionally to the current device.
///
/// Usage:
/// ```dart
/// final r = Responsive(context);
/// Text('Hello', style: TextStyle(fontSize: r.sp(14)));
/// SizedBox(width: r.w(16));
/// Container(height: r.h(48));
/// ```
class Responsive {
  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  final double _scaleWidth;
  final double _scaleHeight;
  final double _scaleFactor;

  Responsive(BuildContext context)
    : _scaleWidth = MediaQuery.sizeOf(context).width / _designWidth,
      _scaleHeight = MediaQuery.sizeOf(context).height / _designHeight,
      _scaleFactor = min(
        MediaQuery.sizeOf(context).width / _designWidth,
        MediaQuery.sizeOf(context).height / _designHeight,
      );

  /// Width-based scaling (paddings, margins, widths).
  double w(double size) => size * _scaleWidth;

  /// Height-based scaling (vertical paddings, heights).
  double h(double size) => size * _scaleHeight;

  /// Font / icon scaling (uses min of width and height scale so text
  /// never overflows on narrow OR short devices).
  double sp(double size) => size * _scaleFactor;

  /// Returns the current screen width.
  double get screenWidth => _designWidth * _scaleWidth;

  /// Returns the current screen height.
  double get screenHeight => _designHeight * _scaleHeight;

  /// Returns true if the device has a small screen (width < 360dp).
  bool get isSmall => screenWidth < 360;

  /// Returns true if the device is a tablet (width >= 600dp).
  bool get isTablet => screenWidth >= 600;
}
