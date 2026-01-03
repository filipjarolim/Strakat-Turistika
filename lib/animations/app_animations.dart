import 'package:flutter/material.dart';

class AppAnimations {
  // Durations
  static const Duration durationShort = Duration(milliseconds: 250);
  static const Duration durationMedium = Duration(milliseconds: 400);
  static const Duration durationLong = Duration(milliseconds: 600);
  static const Duration durationPageTransition = Duration(milliseconds: 500);

  // Curves
  static const Curve curveStandard = Curves.easeOutCubic; // Smoother natural feel
  static const Curve curveDecelerate = Curves.easeOutQuart;
  static const Curve curveAccelerate = Curves.easeInQuad;
  static const Curve curveBounce = Curves.elasticOut;
  static const Curve curveSpring = Curves.elasticOut;

  // Defaults
  static const Duration defaultDuration = durationMedium;
  static const Curve defaultCurve = curveStandard;
}
