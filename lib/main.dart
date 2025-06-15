import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:device_preview/device_preview.dart';
import 'providers/theme_provider.dart';
import 'services/language_service.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Disable Firebase initialization to avoid casting issues
  print('Skipping Firebase initialization due to casting issues - using fallback auth only');
  const firebaseInitialized = false;
  
  runApp(
    DevicePreview(
      enabled: false, // Set to false for production
      builder: (context) => MyApp(firebaseInitialized: firebaseInitialized),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;
  
  const MyApp({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
        ChangeNotifierProvider(create: (_) => AuthService(firebaseEnabled: firebaseInitialized)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp(
                title: 'Finity',
                debugShowCheckedModeBanner: false,
                theme: themeProvider.lightTheme,
                darkTheme: themeProvider.darkTheme,
                themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                locale: DevicePreview.locale(context),
                builder: DevicePreview.appBuilder,
                home: const SplashScreen(),
                onGenerateRoute: (settings) {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  
                  // Protected routes that require authentication
                  final protectedRoutes = ['/home', '/loops', '/liked', '/settings', '/player'];
                  
                  // Check authentication for protected routes
                  if (protectedRoutes.contains(settings.name) && !authService.isAuthenticated) {
                    print('Redirecting to login: ${settings.name} requires authentication');
                    return MaterialPageRoute(builder: (_) => const LoginScreen());
                  }
                  
                  switch (settings.name) {
                    case '/onboarding':
                      // Always show onboarding regardless of authentication status
                      return MaterialPageRoute(builder: (_) => const OnboardingScreen());
                    case '/login':
                      // Always show login when navigated to
                      return MaterialPageRoute(builder: (_) => const LoginScreen());
                    case '/home':
                      // Allow direct access to home if authenticated
                      print('Navigating to home. Authenticated: ${authService.isAuthenticated}');
                      return MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 0));
                    case '/loops':
                      return MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1));
                    case '/liked':
                      return MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 2));
                    case '/settings':
                      return MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 3));
                    case '/player':
                      final args = settings.arguments as Map<String, dynamic>?;
                      if (args != null) {
                        return MaterialPageRoute(builder: (_) => PlayerScreen(contentData: args));
                      }
                      return MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1));
                    default:
                      return MaterialPageRoute(builder: (_) => const SplashScreen());
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class InfinityAnimationPage extends StatefulWidget {
  const InfinityAnimationPage({super.key});

  @override
  State<InfinityAnimationPage> createState() => _InfinityAnimationPageState();
}

class _InfinityAnimationPageState extends State<InfinityAnimationPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(120, 120),
              painter: InfinityPainter(_animation.value),
            );
          },
        ),
      ),
    );
  }
}

class InfinityPainter extends CustomPainter {
  final double animationValue;

  InfinityPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Create gradient similar to the SVG
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF00C6FF),
        const Color(0xFF0072FF),
        const Color(0xFF4A00E0),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
