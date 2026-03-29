import 'package:flutter/material.dart';

class GoDineIcon extends StatelessWidget {
  final double size;
  const GoDineIcon({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GIconPainter()),
    );
  }
}

class _GIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer black rounded rect (the "G" shell)
    final outerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final outerRRect =
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(w * 0.18));
    canvas.drawRRect(outerRRect, outerPaint);

    // White inner rounded rect (bottom-left portion)
    final innerPaint = Paint()..color = Colors.white;
    final innerL = w * 0.15;
    final innerT = h * 0.28;
    final innerW = w * 0.62;
    final innerH = h * 0.57;
    final innerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(innerL, innerT, innerW, innerH),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(innerRRect, innerPaint);

    // Lime-green gradient play triangle
    final triPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFCCFF00), Color(0xFF00FF44)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final cx = w * 0.30;
    final cy = h * 0.565;
    final triW = w * 0.32;
    final triH = h * 0.30;

    final triPath = Path()
      ..moveTo(cx, cy - triH / 2)
      ..lineTo(cx + triW, cy)
      ..lineTo(cx, cy + triH / 2)
      ..close();
    canvas.drawPath(triPath, triPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoDineWordmark extends StatelessWidget {
  final double fontSize;
  const GoDineWordmark({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          height: 1.0,
        ),
        children: [
          TextSpan(
            text: 'GO',
            style: TextStyle(
              color: const Color(0xFFF0F0EC),
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: 'Dine',
            style: TextStyle(
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [Color(0xFFCCFF00), Color(0xFF00E000)],
                ).createShader(Rect.fromLTWH(0, 0, 160, 70)),
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
