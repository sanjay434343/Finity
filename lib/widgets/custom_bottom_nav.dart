import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/language_service.dart';
import '../providers/theme_provider.dart';
import '../screens/search_screen.dart'; // Import the SearchScreen

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {

  void _onItemTapped(int index) {
    if (index == widget.currentIndex) return;
    
    // Add haptic feedback for navigation
    HapticFeedback.lightImpact();
    
    // Always use callback if provided (for MainScreen with PageView)
    if (widget.onTap != null) {
      widget.onTap!(index);
      return;
    }
    
    // Fallback to named routes only when no callback is provided
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/loops');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/search');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/liked');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageService>(
      builder: (context, themeProvider, languageService, child) {
        final isDark = themeProvider.isDarkMode;
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!, 
                width: 0.5,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: widget.currentIndex.clamp(0, 4), // Ensure index is within bounds
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark ? Colors.black : Colors.white,
            selectedItemColor: const Color(0xFF4A00E0),
            unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[600],
            showSelectedLabels: false,
            showUnselectedLabels: false,
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: CustomPaint(
                  size: Size(28.sp, 28.sp),
                  painter: HomeFlowIconPainter(
                    widget.currentIndex == 0,
                    isDark,
                  ),
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: CustomPaint(
                  size: Size(32.sp, 32.sp),
                  painter: InfinityIconPainter(
                    widget.currentIndex == 1,
                    isDark,
                  ),
                ),
                label: 'Loops',
              ),
              BottomNavigationBarItem(
                icon: CustomPaint(
                  size: Size(34.sp, 34.sp),
                  painter: SearchQuestionMarkPainter(
                    widget.currentIndex == 2,
                    isDark,
                  ),
                ),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: CustomPaint(
                  size: Size(30.sp, 30.sp),
                  painter: HeartIconPainter(
                    widget.currentIndex == 3,
                    isDark,
                  ),
                ),
                label: 'Liked',
              ),
              BottomNavigationBarItem(
                icon: CustomPaint(
                  size: Size(30.sp, 30.sp),
                  painter: SettingsIconPainter(
                    widget.currentIndex == 4,
                    isDark,
                  ),
                ),
                label: 'Settings',
              ),
            ],
            onTap: _onItemTapped,
          ),
        );
      },
    );
  }
}

class HomeFlowIconPainter extends CustomPainter {
  final bool isSelected;
  final bool isDark;

  HomeFlowIconPainter(this.isSelected, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isSelected) {
      // Sky blue gradient for flow icon
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF87CEEB),
          const Color(0xFF00BFFF),
          const Color(0xFF1E90FF),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      paint.shader = gradient.createShader(rect);
    } else {
      // Single color for unselected state
      paint.color = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    }

    // Scale factors to match the SVG viewBox (120x100)
    final scaleX = size.width / 120;
    final scaleY = size.height / 100;

    final path = Path();
    path.moveTo(10 * scaleX, 80 * scaleY);
    path.cubicTo(
      30 * scaleX, 20 * scaleY,
      50 * scaleX, 20 * scaleY,
      60 * scaleX, 50 * scaleY,
    );
    path.cubicTo(
      70 * scaleX, 80 * scaleY,
      90 * scaleX, 80 * scaleY,
      110 * scaleX, 20 * scaleY,
    );

    canvas.drawPath(path, paint);

    // Add end caps for selected state
    if (isSelected) {
      final capPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF1E90FF);
      
      canvas.drawCircle(
        Offset(10 * scaleX, 80 * scaleY), 
        1.5,
        capPaint
      );
      canvas.drawCircle(
        Offset(110 * scaleX, 20 * scaleY), 
        1.5,
        capPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is HomeFlowIconPainter &&
        (oldDelegate.isSelected != isSelected ||
         oldDelegate.isDark != isDark);
  }
}

class SearchQuestionMarkPainter extends CustomPainter {
  final bool isSelected;
  final bool isDark;

  SearchQuestionMarkPainter(this.isSelected, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    if (isSelected) {
      // Golden gradient for selected state
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFD700), // Gold
          const Color(0xFFF4B400), // Darker gold
          const Color(0xFFFF8C00), // Orange gold
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      paint.shader = gradient.createShader(rect);
    } else {
      paint.color = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    }

    // Scale factors to match the SVG viewBox (120x120)
    final scaleX = size.width / 120;
    final scaleY = size.height / 120;

    // Create the question mark path
    final path = Path();
    
    // Curved part of question mark shaped like lens
    path.moveTo(60 * scaleX, 20 * scaleY);
    path.cubicTo(
      80 * scaleX, 20 * scaleY,
      85 * scaleX, 45 * scaleY,
      70 * scaleX, 55 * scaleY,
    );
    path.cubicTo(
      55 * scaleX, 65 * scaleY,
      60 * scaleX, 75 * scaleY,
      60 * scaleX, 80 * scaleY,
    );
    path.lineTo(50 * scaleX, 80 * scaleY);
    path.cubicTo(
      50 * scaleX, 70 * scaleY,
      47 * scaleX, 63 * scaleY,
      57 * scaleX, 55 * scaleY,
    );
    path.cubicTo(
      70 * scaleX, 45 * scaleY,
      65 * scaleX, 30 * scaleY,
      50 * scaleX, 30 * scaleY,
    );
    path.cubicTo(
      35 * scaleX, 30 * scaleY,
      35 * scaleX, 50 * scaleY,
      45 * scaleX, 50 * scaleY,
    );
    path.cubicTo(
      48 * scaleX, 50 * scaleY,
      50 * scaleX, 52 * scaleY,
      50 * scaleX, 55 * scaleY,
    );
    path.cubicTo(
      50 * scaleX, 58 * scaleY,
      48 * scaleX, 60 * scaleY,
      45 * scaleX, 60 * scaleY,
    );
    path.cubicTo(
      35 * scaleX, 60 * scaleY,
      30 * scaleX, 50 * scaleY,
      30 * scaleX, 40 * scaleY,
    );
    path.cubicTo(
      30 * scaleX, 25 * scaleY,
      45 * scaleX, 20 * scaleY,
      60 * scaleX, 20 * scaleY,
    );
    path.close();

    canvas.drawPath(path, paint);

    // Dot
    canvas.drawCircle(
      Offset(60 * scaleX, 95 * scaleY),
      7 * scaleX,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is SearchQuestionMarkPainter &&
        (oldDelegate.isSelected != isSelected ||
         oldDelegate.isDark != isDark);
  }
}

class HeartIconPainter extends CustomPainter {
  final bool isSelected;
  final bool isDark;

  HeartIconPainter(this.isSelected, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Scale factors to match the SVG viewBox (120x120)
    final scaleX = size.width / 120;
    final scaleY = size.height / 120;

    final path = Path();
    path.moveTo(60 * scaleX, 100 * scaleY);
    path.cubicTo(
      20 * scaleX, 70 * scaleY,
      20 * scaleX, 40 * scaleY,
      50 * scaleX, 30 * scaleY,
    );
    path.cubicTo(
      60 * scaleX, 28 * scaleY,
      70 * scaleX, 35 * scaleY,
      75 * scaleX, 45 * scaleY,
    );
    path.cubicTo(
      80 * scaleX, 35 * scaleY,
      90 * scaleX, 28 * scaleY,
      100 * scaleX, 35 * scaleY,
    );
    path.cubicTo(
      115 * scaleX, 45 * scaleY,
      100 * scaleX, 70 * scaleY,
      60 * scaleX, 100 * scaleY,
    );
    path.close();

    if (isSelected) {
      // Use pink to red gradient for selected state
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFF69B4),
          const Color(0xFFFF1493),
          const Color(0xFFDC143C),
          const Color(0xFFB22222),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      );
      
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      paint.shader = gradient.createShader(rect);
    } else {
      // Grey color for unselected state
      paint.color = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is HeartIconPainter &&
        (oldDelegate.isSelected != isSelected ||
         oldDelegate.isDark != isDark);
  }
}

class SettingsIconPainter extends CustomPainter {
  final bool isSelected;
  final bool isDark;

  SettingsIconPainter(this.isSelected, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isSelected) {
      // Green to teal gradient for selected state (matching the SVG)
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF22C55E), // Emerald Green
          const Color(0xFF14B8A6), // Teal
        ],
        stops: const [0.0, 1.0],
      );
      
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      paint.shader = gradient.createShader(rect);
    } else {
      // Grey color for unselected state
      paint.color = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    }

    // Scale factors to match the SVG viewBox (24x24)
    final scaleX = size.width / 24;
    final scaleY = size.height / 24;

    // Draw center circle (from SVG: M12 15.5C13.933 15.5 15.5 13.933 15.5 12C15.5 10.067 13.933 8.5 12 8.5C10.067 8.5 8.5 10.067 8.5 12C8.5 13.933 10.067 15.5 12 15.5Z)
    final centerCircle = Path();
    centerCircle.addOval(Rect.fromCenter(
      center: Offset(12 * scaleX, 12 * scaleY),
      width: 7 * scaleX,  // radius 3.5 * 2
      height: 7 * scaleY,
    ));
    canvas.drawPath(centerCircle, paint);

    // Draw outer gear shape (from SVG path)
    final outerPath = Path();
    
    // Convert SVG path to Flutter Path
    // M19.4 15A1.65 1.65 0 0 0 20 13.6L21 12L20 10.4A1.65 1.65 0 0 0 19.4 9L17.7 8.6L17 7L15.4 6.6L14 5.6L12 6L10.4 5.6L9 6.6L8.3 7L6.6 8.6L5 9A1.65 1.65 0 0 0 4.6 10.4L4 12L4.6 13.6A1.65 1.65 0 0 0 5 15L6.6 15.4L7 17L8.3 17.4L9 18.4L10.4 19L12 18.6L13.6 19L15 18.4L15.7 17.4L17 17L17.7 15.4L19.4 15Z
    
    outerPath.moveTo(19.4 * scaleX, 15 * scaleY);
    
    // Simplified gear outline since the full SVG path is complex
    // Create 8 gear teeth around a circle
    final center = Offset(12 * scaleX, 12 * scaleY);
    final outerRadius = 9 * scaleX;
    final innerRadius = 7.5 * scaleX;
    
    // Create gear teeth
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (math.pi / 180);
      final nextAngle = ((i + 1) * 45) * (math.pi / 180);
      
      // Tooth outer point
      final outerX = center.dx + outerRadius * math.cos(angle);
      final outerY = center.dy + outerRadius * math.sin(angle);
      
      // Tooth side points
      final sideAngle1 = angle - (15 * math.pi / 180);
      final sideAngle2 = angle + (15 * math.pi / 180);
      
      final sideX1 = center.dx + innerRadius * math.cos(sideAngle1);
      final sideY1 = center.dy + innerRadius * math.sin(sideAngle1);
      
      final sideX2 = center.dx + innerRadius * math.cos(sideAngle2);
      final sideY2 = center.dy + innerRadius * math.sin(sideAngle2);
      
      if (i == 0) {
        outerPath.moveTo(sideX1, sideY1);
      } else {
        outerPath.lineTo(sideX1, sideY1);
      }
      
      outerPath.lineTo(outerX, outerY);
      outerPath.lineTo(sideX2, sideY2);
      
      // Connect to next tooth
      if (i < 7) {
        final nextSideAngle = nextAngle - (15 * math.pi / 180);
        final nextSideX = center.dx + innerRadius * math.cos(nextSideAngle);
        final nextSideY = center.dy + innerRadius * math.sin(nextSideAngle);
        
        // Draw arc between teeth
        final sweepAngle = nextSideAngle - sideAngle2;
        final rect = Rect.fromCircle(center: center, radius: innerRadius);
        outerPath.arcTo(rect, sideAngle2, sweepAngle, false);
      }
    }
    
    outerPath.close();
    canvas.drawPath(outerPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is SettingsIconPainter &&
        (oldDelegate.isSelected != isSelected ||
         oldDelegate.isDark != isDark);
  }
}

// Add the InfinityIconPainter back (it was removed in the previous version)
class InfinityIconPainter extends CustomPainter {
  final bool isSelected;
  final bool isDark;

  InfinityIconPainter(this.isSelected, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isSelected) {
      // Gradient for selected state
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
    } else {
      // Single color for unselected state
      paint.color = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    }

    // Scale factors to match the SVG viewBox (120x120)
    final scaleX = size.width / 120;
    final scaleY = size.height / 120;

    final path = Path();
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

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is InfinityIconPainter &&
        (oldDelegate.isSelected != isSelected ||
         oldDelegate.isDark != isDark);
  }
}
