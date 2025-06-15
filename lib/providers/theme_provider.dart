import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  static const String _themeKey = 'isDarkMode';
  
  // Add language service reference
  final LanguageService _languageService = LanguageService();
  LanguageService get languageService => _languageService;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
    _languageService.initialize();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  void setTheme(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  // Light Theme
  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    
    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: false,
    ),

    // Text Theme
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
      bodySmall: TextStyle(color: Colors.black54),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(
      color: Colors.black87,
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Bottom Navigation Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      elevation: 8,
    ),

    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
    ),
  );

  // Dark Theme
  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.black,
    
    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),

    // Text Theme
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white70),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(
      color: Colors.white,
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1A2E),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Bottom Navigation Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1A1A2E),
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      elevation: 8,
    ),

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Color(0xFF1A1A2E),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
  );

  // Loops Screen Specific Colors
  List<Color> get loopsBackgroundColors => _isDarkMode 
    ? [
        const Color(0xFF1A1A2E), 
        const Color(0xFF16213E), 
        const Color(0xFF0F3460),
        const Color(0xFF533483), 
        const Color(0xFF2E1A47), 
        const Color(0xFF1A2E42),
      ]
    : [
        const Color(0xFFF5F7FA), 
        const Color(0xFFE8F4FD), 
        const Color(0xFFF0F8FF),
        const Color(0xFFF8F9FA), 
        const Color(0xFFEDF2F7), 
        const Color(0xFFF7FAFC),
      ];

  // Gradient Colors for App Bar
  List<Color> get appBarGradientColors => _isDarkMode
    ? [
        Colors.black.withOpacity(0.7),
        Colors.black.withOpacity(0.3),
        Colors.transparent,
      ]
    : [
        Colors.white.withOpacity(0.9),
        Colors.white.withOpacity(0.7),
        Colors.white.withOpacity(0.3),
        Colors.transparent,
      ];

  // Bottom Gradient Colors
  List<Color> get bottomGradientColors => _isDarkMode
    ? [
        Colors.transparent,
        Colors.black.withOpacity(0.1),
        Colors.black.withOpacity(0.3),
        Colors.black.withOpacity(0.6),
        Colors.black.withOpacity(0.8),
        Colors.black.withOpacity(0.95),
      ]
    : [
        Colors.transparent,
        Colors.white.withOpacity(0.1),
        Colors.white.withOpacity(0.3),
        Colors.white.withOpacity(0.6),
        Colors.white.withOpacity(0.8),
        Colors.white.withOpacity(0.95),
      ];

  // Gradient Heights
  double get gradientHeight => 300.0; // Increased from 200 to 300

  // Top Gradient Colors (increased intensity - darker at top, more gradual fade)
  List<Color> get topGradientColors => _isDarkMode
    ? [
        Colors.black.withOpacity(0.85),  // Increased from 0.6 to 0.85
        Colors.black.withOpacity(0.7),   // Increased from 0.4 to 0.7
        Colors.black.withOpacity(0.5),   // Increased from 0.25 to 0.5
        Colors.black.withOpacity(0.3),   // Increased from 0.15 to 0.3
        Colors.black.withOpacity(0.15),  // Increased from 0.05 to 0.15
        Colors.black.withOpacity(0.05),  // Added extra step
        Colors.transparent,
      ]
    : [
        Colors.white.withOpacity(0.85),  // Increased from 0.6 to 0.85
        Colors.white.withOpacity(0.7),   // Increased from 0.4 to 0.7
        Colors.white.withOpacity(0.5),   // Increased from 0.25 to 0.5
        Colors.white.withOpacity(0.3),   // Increased from 0.15 to 0.3
        Colors.white.withOpacity(0.15),  // Increased from 0.05 to 0.15
        Colors.white.withOpacity(0.05),  // Added extra step
        Colors.transparent,
      ];

  // Text Colors
  Color get primaryTextColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryTextColor => _isDarkMode ? Colors.white70 : Colors.black54;
  Color get tertiaryTextColor => _isDarkMode ? Colors.white54 : (Colors.grey[600] ?? Colors.grey);

  // Icon Colors
  Color get primaryIconColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryIconColor => _isDarkMode ? Colors.white70 : Colors.black54;

  // Background Colors
  Color get primaryBackgroundColor => _isDarkMode ? Colors.black : Colors.white;
  Color get secondaryBackgroundColor => _isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F7FA);

  // Action Button Colors
  Color get actionButtonBackgroundColor => _isDarkMode 
    ? Colors.black.withOpacity(0.3) 
    : Colors.white.withOpacity(0.9);

  // View More Button Colors
  Color get viewMoreButtonBackgroundColor => _isDarkMode 
    ? Colors.white.withOpacity(0.2) 
    : Colors.black.withOpacity(0.1);
  
  Color get viewMoreButtonBorderColor => _isDarkMode 
    ? Colors.white.withOpacity(0.3) 
    : Colors.black.withOpacity(0.2);

  // Mute Icon Colors
  Color get muteIconBackgroundColor => _isDarkMode 
    ? Colors.black.withOpacity(0.7) 
    : Colors.white.withOpacity(0.9);
  
  Color get muteIconBorderColor => _isDarkMode 
    ? Colors.white.withOpacity(0.8) 
    : Colors.black.withOpacity(0.2);

  // Profile Card Colors
  Color get profileCardBackgroundColor => _isDarkMode 
    ? Colors.white.withOpacity(0.9) 
    : Colors.white;
  
  Color get profileCardBorderColor => _isDarkMode 
    ? Colors.white.withOpacity(0.1) 
    : Colors.grey.withOpacity(0.2);

  // Bottom Sheet Colors
  List<Color> get bottomSheetGradientColors => _isDarkMode
    ? [
        const Color(0xFF1A1A2E).withOpacity(0.1),
        Colors.black.withOpacity(0.8),
        Colors.black.withOpacity(0.9),
      ]
    : [
        const Color(0xFFF5F7FA).withOpacity(0.1),
        Colors.white.withOpacity(0.95),
        Colors.white,
      ];

  Color get bottomSheetBorderColor => _isDarkMode 
    ? Colors.white.withOpacity(0.1) 
    : Colors.grey.withOpacity(0.2);

  Color get bottomSheetHandleColor => _isDarkMode 
    ? Colors.white.withOpacity(0.3) 
    : Colors.grey.withOpacity(0.4);

  get scaffoldBackgroundColor => null;
}
