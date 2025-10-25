import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerRect extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const ShimmerRect({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white10 : Colors.black12;
    final highlight = isDark ? Colors.white24 : Colors.black26;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerLine extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLine({
    super.key,
    required this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerRect(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}
