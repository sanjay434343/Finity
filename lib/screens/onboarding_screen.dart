import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'splash_screen.dart';
import '../providers/theme_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  late AnimationController _drawController;
  late AnimationController _colorController;
  
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        _updateStatusBar();
        
        return Scaffold(
          backgroundColor: themeProvider.primaryBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20.h),
                  // Logo using custom painter from splash screen
                  AnimatedBuilder(
                    animation: Listenable.merge([_drawController, _colorController]),
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(120.w, 120.w),
                        painter: InfinityPainter(_drawController.value, _colorController.value),
                      );
                    },
                  ),
                  SizedBox(height: 12.h),
                  
                  // App Name
                  AutoSizeText(
                    'Finity',
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF4A00E0),
                      fontFamily: 'Curcive',
                    ),
                    maxLines: 1,
                  ),
                  SizedBox(height: 16.h),
                  
                  // Tagline
                  AutoSizeText(
                    'Infinite Knowledge, Infinite Possibilities',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w500,
                      color: themeProvider.secondaryTextColor,
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 40.h),
                  
                  // Four Features with separate logos
                  _buildFeature(
                    Icons.article_outlined,
                    const Color(0xFF00C6FF),
                    'Explore Infinity Flow',
                    'Discover endless articles and knowledge from Wikipedia in an engaging format',
                    themeProvider,
                  ),
                  SizedBox(height: 20.h),
                  
                  _buildFeature(
                    Icons.play_circle_outline,
                    const Color(0xFF0072FF),
                    'Watch Infinity Loops',
                    'Experience content in short, digestible loops with background music',
                    themeProvider,
                  ),
                  SizedBox(height: 20.h),
                  
                  _buildFeature(
                    Icons.favorite_outline,
                    const Color(0xFFE91E63),
                    'Save Infinity Hearts',
                    'Like your favorite content and save it to your hearts collection',
                    themeProvider,
                  ),
                  SizedBox(height: 20.h),
                  
                  _buildFeature(
                    Icons.star_outline,
                    const Color(0xFF4A00E0),
                    'Find Infinity Picks',
                    'Curated selections and trending content picked just for you',
                    themeProvider,
                  ),
                  SizedBox(height: 60.h),
                  
                  // Get Started Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Mark onboarding as seen
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('has_seen_onboarding', true);
                        
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A00E0),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 2,
                      ),
                      child: AutoSizeText(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFeature(IconData icon, Color iconColor, String title, String description, ThemeProvider themeProvider) {
    return Row(
      children: [
        // Feature icon with colored background
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: iconColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24.sp,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoSizeText(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryTextColor,
                ),
                maxLines: 1,
              ),
              SizedBox(height: 4.h),
              AutoSizeText(
                description,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: themeProvider.secondaryTextColor,
                  height: 1.4,
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
