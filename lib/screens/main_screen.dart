import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/language_service.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_screen.dart';
import 'loops_screen.dart';
import 'search_screen.dart';
import 'liked_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onBottomNavTap(int index) {
    if (index != _currentIndex) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageService>(
      builder: (context, themeProvider, languageService, child) {
        return Scaffold(
          backgroundColor: themeProvider.primaryBackgroundColor,
          body: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              HomeScreen(showBottomNav: false),
              LoopsScreen(showBottomNav: false),
              SearchScreen(showBottomNav: false),
              LikedScreen(showBottomNav: false),
              SettingsScreen(showBottomNav: false),
            ],
          ),
          bottomNavigationBar: CustomBottomNav(
            currentIndex: _currentIndex,
            onTap: _onBottomNavTap,
          ),
        );
      },
    );
  }
}
