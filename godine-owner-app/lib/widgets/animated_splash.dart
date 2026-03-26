import 'package:flutter/material.dart';

class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _gScale;
  late Animation<double> _gOpacity;
  late Animation<double> _triScale;
  late Animation<double> _triOpacity;
  late Animation<double> _goTranslateX;
  late Animation<double> _goOpacity;
  late Animation<double> _dineTranslateX;
  late Animation<double> _dineOpacity;
  late Animation<double> _groupOpacity;

  @override
  void initState() {
    super.initState();
    // Total duration: 2500ms (2000ms animation + 500ms pause loop)
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 2500),
    );

    // Step 1: 'G' scales and fades (0-600ms -> 0.0 to 0.24)
    _gScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.24, curve: Curves.easeOutBack),
      ),
    );
    _gOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.24, curve: Curves.easeOut),
      ),
    );

    // Step 2: Triangle spring (400-900ms -> 0.16 to 0.36)
    _triScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.36, curve: Curves.elasticOut),
      ),
    );
    _triOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.36, curve: Curves.easeOut),
      ),
    );

    // Step 3: 'GO' slides in (700-1200ms -> 0.28 to 0.48)
    _goTranslateX = Tween<double>(begin: -80.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _goOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.48, curve: Curves.easeOutCubic),
      ),
    );

    // Step 4: 'Dine' slides in (900-1400ms -> 0.36 to 0.56)
    _dineTranslateX = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.36, 0.56, curve: Curves.easeOutCubic),
      ),
    );
    _dineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.36, 0.56, curve: Curves.easeOutCubic),
      ),
    );

    // Step 6: Fade Out (1700-2000ms -> 0.68 to 0.80)
    _groupOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 68.0),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInQuad)), weight: 12.0),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 20.0),
    ]).animate(_controller);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        
        // Step 5: Logo Group Pulse (1400-1700ms -> 0.56 to 0.68)
        double currentGroupScale = 1.0;
        double progress = _controller.value;
        if (progress >= 0.56 && progress <= 0.62) {
          double t = (progress - 0.56) / 0.06;
          currentGroupScale = 1.0 + 0.04 * Curves.easeInOutQuad.transform(t);
        } else if (progress > 0.62 && progress <= 0.68) {
          double t = (progress - 0.62) / 0.06;
          currentGroupScale = 1.04 - 0.04 * Curves.easeInOutQuad.transform(t);
        }

        return Container(
          color: const Color(0xFF050505), // Using app background instead of white
          alignment: Alignment.center,
          child: Transform.scale(
            scale: currentGroupScale,
            child: Opacity(
              opacity: _groupOpacity.value,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: _gScale.value,
                          child: Opacity(
                            opacity: _gOpacity.value,
                            child: const Text(
                              'G',
                              style: TextStyle(
                                fontSize: 120,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFFFFF), // White 'G' for dark theme
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _triScale.value,
                          child: Opacity(
                            opacity: _triOpacity.value,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: CustomPaint(
                                size: const Size(30, 36),
                                painter: _TrianglePainter(color: const Color(0xFFADFF2F)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClipRect(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(_goTranslateX.value, 0),
                          child: Opacity(
                            opacity: _goOpacity.value,
                            child: const Text(
                              'GO',
                              style: TextStyle(
                                fontSize: 70,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFFFFFF), // White 'GO' for dark theme
                                height: 1.1,
                                letterSpacing: -2,
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(_dineTranslateX.value, 0),
                          child: Opacity(
                            opacity: _dineOpacity.value,
                            child: const Text(
                              'Dine',
                              style: TextStyle(
                                fontSize: 70,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFADFF2F),
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
