import 'package:flutter/material.dart';

class GuideBoxClipper extends CustomClipper<Path> {
  final double boxSize;

  GuideBoxClipper({required this.boxSize});

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: boxSize,
        height: boxSize,
      ));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
