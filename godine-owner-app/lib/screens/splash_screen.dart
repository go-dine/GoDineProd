import 'package:flutter/material.dart';
import '../widgets/brand_widgets.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _masterController;

  // Logo: scale + fade in
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Text: fade in + slide from right
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  // Whole splash: fade out at end
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // ── Logo appears (0 → 35%) ──────────────────────────────
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
      ),
    );

    // ── Text slides in from right (30% → 70%) ───────────────
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.30, 0.65, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.6, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    // ── Whole splash fades out (85% → 100%) ─────────────────
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );

    // Start animation, then navigate
    _masterController.forward().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthGate(),
            transitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _masterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _masterController,
      builder: (context, _) {
        return Opacity(
          opacity: _exitOpacity.value,
          child: Scaffold(
            backgroundColor: const Color(0xFF050505),
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Logo Icon ──────────────────────────────
                  Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: const GoDineIcon(size: 72),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ── "GoDine" text ──────────────────────────
                  ClipRect(
                    child: SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: const GoDineWordmark(fontSize: 52),
                      ),
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
