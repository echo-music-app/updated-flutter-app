import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.radius,
    this.imageProvider,
    this.backgroundColor,
    this.fallbackText,
    this.fallbackTextStyle,
  });

  final double radius;
  final ImageProvider<Object>? imageProvider;
  final Color? backgroundColor;
  final String? fallbackText;
  final TextStyle? fallbackTextStyle;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final fallback = fallbackText;
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ClipOval(
        child: imageProvider == null
            ? (fallback == null || fallback.isEmpty
                  ? null
                  : Text(fallback, style: fallbackTextStyle))
            : Image(
                image: imageProvider!,
                width: diameter,
                height: diameter,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
      ),
    );
  }
}
