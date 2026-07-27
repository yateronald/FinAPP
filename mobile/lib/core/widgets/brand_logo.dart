import 'package:flutter/material.dart';

/// Fynexa brand mark: the emblem image + optional "Fynexa" wordmark.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? textColor;
  const BrandLogo({super.key, this.size = 44, this.showText = true, this.textColor});

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'img/logo_mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
    );
    if (!showText) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.2),
        Text(
          'Fynexa',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: textColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
