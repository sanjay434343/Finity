import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<double> _colorAnimation;
  bool _isDrawingComplete = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isDrawingComplete) {
        setState(() {
          _isDrawingComplete = true;
        });
        // Start color animation after drawing is complete
        _animationController.duration = const Duration(seconds: 3);
        _animationController.repeat();
      }
    });

    _animationController.forward();
    
    // Check authentication status after animation starts
    _checkAuthenticationStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStatusBar();
  }

  void _updateStatusBar() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    if (themeProvider.isDarkMode) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
    } else {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ));
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    // Wait for minimum splash duration
    await Future.delayed(const Duration(seconds: 5));
    
    if (!mounted) return;
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final authStatus = await authService.getAuthStatus();
      
      print('Splash: Auth status check - ${authStatus}');
      
      // If user is authenticated, go directly to home
      if (authStatus['hasValidSession'] == true) {
        print('Splash: User is authenticated, navigating to home');
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }
      
      // Check if user has seen onboarding before
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      
      if (hasSeenOnboarding) {
        print('Splash: User has seen onboarding, navigating to login');
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        print('Splash: First time user, navigating to onboarding');
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } catch (e) {
      print('Splash: Error checking auth status: $e');
      // Fallback to onboarding on error
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        _updateStatusBar();
        
        return Scaffold(
          backgroundColor: themeProvider.primaryBackgroundColor,
          body: Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(120, 120),
                  painter: InfinityPainter(
                    _isDrawingComplete ? 1.0 : _animation.value,
                    _isDrawingComplete ? _colorAnimation.value : 0.0,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class InfinityPainter extends CustomPainter {
  final double animationValue;
  final double colorAnimationValue;

  InfinityPainter(this.animationValue, this.colorAnimationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Color cycling: blue -> violet -> yellow -> pink -> red -> green
    final colors = [
      const Color(0xFF0072FF), // Blue
      const Color(0xFF8A2BE2), // Violet
      const Color(0xFFFFD700), // Yellow
      const Color(0xFFFF69B4), // Pink
      const Color(0xFFFF0000), // Red
      const Color(0xFF00FF00), // Green
    ];

    // Calculate current color position (0-5.99...)
    final colorPosition = (colorAnimationValue * colors.length) % colors.length;
    final colorIndex = colorPosition.floor();
    final colorProgress = colorPosition - colorIndex;
    
    // Get current and next color
    final currentColor = colors[colorIndex];
    final nextColor = colors[(colorIndex + 1) % colors.length];
    
    // Interpolate between current and next color
    final animatedColor = Color.lerp(currentColor, nextColor, colorProgress)!;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        animatedColor,
        animatedColor.withOpacity(0.7),
        animatedColor.withOpacity(0.9),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = gradient.createShader(rect);

    // Scale factors to match the SVG viewBox (120x120)
    final scaleX = size.width / 120;
    final scaleY = size.height / 120;

    final path = Path();

    // Fully expanded infinity shape
    path.moveTo(10 * scaleX, 60 * scaleY);
    path.cubicTo(
      10 * scaleX, 20 * scaleY,
      50 * scaleX, 20 * scaleY,
      60 * scaleX, 60 * scaleY,
    );
    path.cubicTo(
      70 * scaleX, 100 * scaleY,
      110 * scaleX, 100 * scaleY,
      110 * scaleX, 60 * scaleY,
    );
    path.cubicTo(
      110 * scaleX, 20 * scaleY,
      70 * scaleX, 20 * scaleY,
      60 * scaleX, 60 * scaleY,
    );
    path.cubicTo(
      50 * scaleX, 100 * scaleY,
      10 * scaleX, 100 * scaleY,
      10 * scaleX, 60 * scaleY,
    );
    path.close();

    // Create animated path that draws from start to end
    final pathMetric = path.computeMetrics().first;
    final animatedPath = pathMetric.extractPath(0, pathMetric.length * animationValue);

    canvas.drawPath(animatedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
