// lib/ui/glass_sheet.dart
// Reusable glass + 3D gradient bottom sheet kit
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

class GlassStyle {
  final double blurSigma; // 12–24 recommended
  final double cornerRadius; // 16–28
  final List<Color> gradientColors; // semi-transparent colors
  final List<double>? gradientStops; // null = even
  final Alignment begin;
  final Alignment end;
  final double borderWidth; // 0.5–1.5
  final Color borderColor; // low alpha
  final List<BoxShadow> shadows; // soft upwards shadow
  final bool addNoiseOverlay; // optional
  final double noiseOpacity; // 0.04–0.08
  final EdgeInsets padding;

  const GlassStyle({
    this.blurSigma = 20,
    this.cornerRadius = 22,
    required this.gradientColors,
    this.gradientStops,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.borderWidth = 1,
    required this.borderColor,
    this.shadows = const [],
    this.addNoiseOverlay = false,
    this.noiseOpacity = 0.06,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 16),
  });

  // Preset: balanced edit sheet
  factory GlassStyle.editSheet(ColorScheme cs) {
    return GlassStyle(
      blurSigma: 20,
      cornerRadius: 22,
      gradientColors: [
        cs.surface.withValues(alpha: 0.65), // frost tint
        cs.primary.withValues(alpha: 0.10), // brand tint
      ],
      gradientStops: const [0.1, 1.0],
      borderWidth: 1,
      borderColor: Colors.white.withValues(alpha: 0.12),
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, -6),
        ),
      ],
      addNoiseOverlay: false,
      noiseOpacity: 0.06,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    );
  }

  // Preset: stronger 3D depth
  factory GlassStyle.strong3D(ColorScheme cs) {
    return GlassStyle(
      blurSigma: 22,
      cornerRadius: 22,
      gradientColors: [
        cs.surface.withValues(alpha: 0.60),
        cs.primary.withValues(alpha: 0.12),
        cs.surfaceContainerHighest.withValues(alpha: 0.10),
      ],
      gradientStops: const [0.0, 0.65, 1.0],
      borderWidth: 1,
      borderColor: Colors.white.withValues(alpha: 0.14),
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 22,
          spreadRadius: 2,
          offset: const Offset(0, -10),
        ),
      ],
      addNoiseOverlay: false,
      noiseOpacity: 0.07,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
    );
  }
}

class GlassSheet extends StatelessWidget {
  final GlassStyle style;
  final Widget child;
  final Widget? dragHandle;

  const GlassSheet({
    super.key,
    required this.style,
    required this.child,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: style.begin,
          end: style.end,
          colors: style.gradientColors,
          stops: style.gradientStops,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(style.cornerRadius),
        ),
        border: Border.all(color: style.borderColor, width: style.borderWidth),
        boxShadow: style.shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(style.cornerRadius),
        ),
        child: Stack(
          children: [
            if (style.addNoiseOverlay)
              IgnorePointer(
                child: Opacity(
                  opacity: style.noiseOpacity,
                  // If you add a noise texture, keep the asset path below
                  // and add it to pubspec assets: assets/images/noise.png
                  child: Image.asset(
                    'assets/images/noise.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            Padding(
              padding: style.padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dragHandle ??
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(style.cornerRadius),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: style.blurSigma,
          sigmaY: style.blurSigma,
        ),
        child: decorated,
      ),
    );
  }
}
