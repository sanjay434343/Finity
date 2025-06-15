import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import 'splash_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _drawController;
  late AnimationController _colorController;
  
  // Configure Google Sign-In with proper scopes
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/userinfo.email',
    ],
  );

  @override
  void initState() {
    super.initState();
    _checkCurrentAuthStatus();
    
    // Initialize draw and color animations
    _drawController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _colorController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    // Start drawing animation first
    _drawController.forward().then((_) {
      // Once drawing is complete, start color cycling
      _colorController.repeat();
    });
  }

  @override
  void dispose() {
    _drawController.dispose();
    _colorController.dispose();
    super.dispose();
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

  Future<void> _checkCurrentAuthStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final authStatus = await authService.getAuthStatus();
    print('Login Screen - Current auth status: $authStatus');
    
    // If user is already authenticated, redirect to home
    if (authStatus['hasValidSession'] == true) {
      print('User already has valid session, redirecting to home');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Use AuthService to handle the sign-in
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.signInWithGoogle();
      
      if (result['success'] == true) {
        // Get the UID (always available with fallback)
        final uid = authService.firebaseUid ?? authService.currentUserId;
        print('Authentication successful with UID: $uid');
        
        // Verify authentication is complete
        final authStatus = await authService.getAuthStatus();
        print('Post-login auth status: $authStatus');
        
        // Navigate directly to home after successful login
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // Stay on login screen if authentication failed - only show if mounted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Authentication failed. Please try again.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Google Sign-In error: $e');
      
      // Stay on login screen for any errors - only show if mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: Please check your internet connection and try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _storeUserInfo(GoogleSignInAccount googleUser) async {
    try {
      // Store user info in shared preferences for later use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', googleUser.email);
      await prefs.setString('user_name', googleUser.displayName ?? '');
      await prefs.setString('user_photo_url', googleUser.photoUrl ?? '');
      await prefs.setString('user_id', googleUser.id);
      
      print('User info stored successfully');
    } catch (e) {
      print('Error storing user info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        _updateStatusBar();
        
        return Scaffold(
          backgroundColor: themeProvider.primaryBackgroundColor,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  // Top content with logo and text
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo using custom painter with color animation
                        AnimatedBuilder(
                          animation: Listenable.merge([_drawController, _colorController]),
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(120.w, 120.w),
                              painter: InfinityPainter(_drawController.value, _colorController.value),
                            );
                          },
                        ),
                        SizedBox(height: 8.h),
                        
                        // App Name
                        Text(
                          'Finity',
                          style: TextStyle(
                            fontSize: 36.sp,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF4A00E0),
                            fontFamily: 'Curcive',
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bottom content with button and terms
                  Column(
                    children: [
                      // Google Sign-In Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.grey[700],
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              side: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A00E0)),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 20.w,
                                      height: 20.w,
                                      decoration: const BoxDecoration(
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            'https://developers.google.com/identity/images/g-logo.png',
                                          ),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      
                      // Terms info
                      Text(
                        'By continuing, you agree to our Terms of Service and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: themeProvider.tertiaryTextColor,
                          height: 1.3,
                        ),
                      ),
                    ],
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

class InfinityPainter extends CustomPainter {
  final double drawProgress;
  final double colorProgress;

  InfinityPainter(this.drawProgress, this.colorProgress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Create animated gradient colors that cycle through different color combinations
    final gradientColors = _getAnimatedColors(colorProgress);
    
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradientColors,
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

    // Apply draw progress to stroke path
    final pathMetrics = path.computeMetrics();
    for (final pathMetric in pathMetrics) {
      final length = pathMetric.length;
      final drawLength = length * drawProgress;

      // Extract the sub-path for the current progress
      final subPath = pathMetric.extractPath(0, drawLength);
      canvas.drawPath(subPath, paint);
    }
  }

  List<Color> _getAnimatedColors(double t) {
    // Define multiple color sets to cycle through
    final colorSets = [
      [const Color(0xFF00C6FF), const Color(0xFF0072FF), const Color(0xFF4A00E0)], // Blue gradient
      [const Color(0xFFFF6B6B), const Color(0xFF4ECDC4), const Color(0xFF45B7D1)], // Red to blue
      [const Color(0xFF96CEB4), const Color(0xFFDDA0DD), const Color(0xFF98D8E8)], // Green to purple
      [const Color(0xFFFFD93D), const Color(0xFF6BCF7F), const Color(0xFF4D9DE0)], // Yellow to blue
      [const Color(0xFFE15759), const Color(0xFF76B900), const Color(0xFF9966CC)], // Red to purple
    ];

    // Calculate which color set to use and interpolation value
    final totalSets = colorSets.length;
    final setIndex = (t * totalSets).floor() % totalSets;
    final nextSetIndex = (setIndex + 1) % totalSets;
    final localT = (t * totalSets) % 1.0;

    // Interpolate between current and next color set
    final currentSet = colorSets[setIndex];
    final nextSet = colorSets[nextSetIndex];

    return [
      Color.lerp(currentSet[0], nextSet[0], localT)!,
      Color.lerp(currentSet[1], nextSet[1], localT)!,
      Color.lerp(currentSet[2], nextSet[2], localT)!,
    ];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
