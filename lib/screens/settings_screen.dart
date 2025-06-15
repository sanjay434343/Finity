import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/language_service.dart';
import '../widgets/custom_bottom_nav.dart';
import '../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBottomNav;
  
  const SettingsScreen({super.key, this.showBottomNav = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late PageController _carouselController;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    
    _carouselController = PageController();
    
    // Start fade animation
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchGitHubProfile() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/users/sanjay434343'),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching GitHub profile: $e');
    }
    return null;
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'sanjay13649@gmail.com',
      query: 'subject=Finity App Feedback',
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch email';
      }
    } catch (e) {
      print('Error launching email: $e');
    }
  }

  Future<void> _launchGitHub() async {
    final Uri githubUri = Uri.parse('https://github.com/sanjay434343');
    
    try {
      if (await canLaunchUrl(githubUri)) {
        await launchUrl(githubUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch GitHub';
      }
    } catch (e) {
      print('Error launching GitHub: $e');
    }
  }

  Future<Map<String, dynamic>?> _checkForUpdates() async {
    try {
      // Get current app version with fallback
      String currentVersion = '1.0.1'; // Default fallback version matching build.gradle
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = packageInfo.version;
        print('Got package info version: $currentVersion');
      } catch (e) {
        print('Package info error, using fallback version: $e');
        // Use fallback version matching build.gradle
        currentVersion = '1.0.1';
      }
      
      // Fetch latest release from GitHub
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/sanjay434343/Finity/releases/latest'),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Finity-App',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final releaseData = json.decode(response.body);
        final latestVersion = releaseData['tag_name']?.replaceFirst('v', '') ?? '';
        final releaseNotes = releaseData['body'] ?? '';
        final publishedAt = releaseData['published_at'] ?? '';
        
        // Find APK download URL
        String? apkDownloadUrl;
        if (releaseData['assets'] != null) {
          final assets = releaseData['assets'] as List;
          for (final asset in assets) {
            final assetName = asset['name']?.toString().toLowerCase() ?? '';
            if (assetName.contains('apk') && assetName.contains('release')) {
              apkDownloadUrl = asset['browser_download_url'];
              break;
            }
          }
        }
        
        // Compare versions
        final isUpdateAvailable = _isNewerVersion(currentVersion, latestVersion);
        
        print('Version comparison: current=$currentVersion, latest=$latestVersion, updateAvailable=$isUpdateAvailable');
        
        return {
          'currentVersion': currentVersion,
          'latestVersion': latestVersion,
          'isUpdateAvailable': isUpdateAvailable,
          'releaseNotes': releaseNotes,
          'publishedAt': publishedAt,
          'downloadUrl': apkDownloadUrl,
          'releaseUrl': releaseData['html_url'],
        };
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
    return null;
  }

  bool _isNewerVersion(String currentVersion, String latestVersion) {
    try {
      // Clean version strings (remove 'v' prefix if present)
      final cleanCurrent = currentVersion.replaceFirst('v', '').trim();
      final cleanLatest = latestVersion.replaceFirst('v', '').trim();
      
      print('Comparing versions: "$cleanCurrent" vs "$cleanLatest"');
      
      // If versions are exactly the same, no update needed
      if (cleanCurrent == cleanLatest) {
        print('Versions are identical');
        return false;
      }
      
      final current = cleanCurrent.split('.').map((part) {
        final cleaned = part.replaceAll(RegExp(r'[^0-9]'), '');
        return cleaned.isEmpty ? 0 : int.parse(cleaned);
      }).toList();
      
      final latest = cleanLatest.split('.').map((part) {
        final cleaned = part.replaceAll(RegExp(r'[^0-9]'), '');
        return cleaned.isEmpty ? 0 : int.parse(cleaned);
      }).toList();
      
      // Ensure both versions have same length (pad with zeros)
      while (current.length < latest.length) current.add(0);
      while (latest.length < current.length) latest.add(0);
      
      print('Parsed versions: current=$current, latest=$latest');
      
      // Compare version components
      for (int i = 0; i < current.length; i++) {
        if (latest[i] > current[i]) {
          print('Update available: latest[${i}]=${latest[i]} > current[${i}]=${current[i]}');
          return true;
        } else if (latest[i] < current[i]) {
          print('Current version is newer: latest[${i}]=${latest[i]} < current[${i}]=${current[i]}');
          return false;
        }
      }
      
      print('Versions are equal after comparison');
      return false;
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }

  void _showUpdateDialog(BuildContext context, Map<String, dynamic> updateInfo, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.isDarkMode 
            ? const Color(0xFF1A1A2E) 
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.system_update,
                color: Colors.green,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Update Available',
                style: TextStyle(
                  color: themeProvider.primaryTextColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Version info
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode 
                      ? Colors.white.withOpacity(0.05) 
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current',
                          style: TextStyle(
                            color: themeProvider.tertiaryTextColor,
                            fontSize: 12.sp,
                          ),
                        ),
                        Text(
                          'v${updateInfo['currentVersion']}',
                          style: TextStyle(
                            color: themeProvider.primaryTextColor,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: themeProvider.tertiaryTextColor,
                      size: 20.sp,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Latest',
                          style: TextStyle(
                            color: themeProvider.tertiaryTextColor,
                            fontSize: 12.sp,
                          ),
                        ),
                        Text(
                          'v${updateInfo['latestVersion']}',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16.h),
              
              // Release notes
              if (updateInfo['releaseNotes']?.isNotEmpty == true) ...[
                Text(
                  'What\'s New:',
                  style: TextStyle(
                    color: themeProvider.primaryTextColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: 120.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode 
                        ? Colors.white.withOpacity(0.03) 
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: themeProvider.isDarkMode 
                          ? Colors.white.withOpacity(0.1) 
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      updateInfo['releaseNotes'],
                      style: TextStyle(
                        color: themeProvider.secondaryTextColor,
                        fontSize: 13.sp,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
              
              // Published date
              if (updateInfo['publishedAt']?.isNotEmpty == true)
                Text(
                  'Released: ${_formatReleaseDate(updateInfo['publishedAt'])}',
                  style: TextStyle(
                    color: themeProvider.tertiaryTextColor,
                    fontSize: 12.sp,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Later',
              style: TextStyle(
                color: themeProvider.secondaryTextColor,
                fontSize: 14.sp,
              ),
            ),
          ),
          if (updateInfo['downloadUrl'] != null)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _downloadUpdate(updateInfo['downloadUrl']);
              },
              icon: Icon(Icons.download, size: 18.sp),
              label: Text(
                'Download',
                style: TextStyle(fontSize: 14.sp),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                if (updateInfo['releaseUrl'] != null) {
                  await _launchUrl(updateInfo['releaseUrl']);
                }
              },
              icon: Icon(Icons.open_in_browser, size: 18.sp),
              label: Text(
                'View Release',
                style: TextStyle(fontSize: 14.sp),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showNoUpdateDialog(BuildContext context, String currentVersion, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.isDarkMode 
            ? const Color(0xFF1A1A2E) 
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.blue,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'You\'re Up to Date!',
                style: TextStyle(
                  color: themeProvider.primaryTextColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'You have the latest version of Finity (v$currentVersion).',
          style: TextStyle(
            color: themeProvider.secondaryTextColor,
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(
                color: const Color(0xFF4A00E0),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUpdate(String downloadUrl) async {
    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch download URL';
      }
    } catch (e) {
      print('Error downloading update: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  String _formatReleaseDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 30) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else {
        return 'Just released';
      }
    } catch (e) {
      return dateString;
    }
  }

  void _checkForUpdatesWithLoading(BuildContext context, ThemeProvider themeProvider, LanguageService languageService) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.isDarkMode 
            ? const Color(0xFF1A1A2E) 
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: const Color(0xFF4A00E0),
            ),
            SizedBox(height: 16.h),
            Text(
              'Checking for updates...',
              style: TextStyle(
                color: themeProvider.primaryTextColor,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final updateInfo = await _checkForUpdates();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (updateInfo != null) {
        if (updateInfo['isUpdateAvailable'] == true) {
          _showUpdateDialog(context, updateInfo, themeProvider);
        } else {
          _showNoUpdateDialog(context, updateInfo['currentVersion'], themeProvider);
        }
      } else {
        // Show error dialog
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: themeProvider.isDarkMode 
                  ? const Color(0xFF1A1A2E) 
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Text(
                'Check Failed',
                style: TextStyle(
                  color: themeProvider.primaryTextColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Unable to check for updates. Please check your internet connection and try again.',
                style: TextStyle(
                  color: themeProvider.secondaryTextColor,
                  fontSize: 14.sp,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: const Color(0xFF4A00E0),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      print('Error in update check: $e');
    }
  }

  Widget _buildSectionHeader(String title, ThemeProvider themeProvider) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
      child: AutoSizeText(
        title,
        style: TextStyle(
          color: themeProvider.secondaryTextColor,
          fontSize: 13.sp,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildThemeToggleCard(ThemeProvider themeProvider, LanguageService languageService) {
    return Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode 
            ? const Color(0xFF1A1A2E) 
            : Colors.white,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? Colors.white.withOpacity(0.08) 
              : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode 
                ? Colors.black.withOpacity(0.2) 
                : Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            // Theme Icon
            Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                color: const Color(0xFF4A00E0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Center(
                child: HugeIcon(
                  icon: themeProvider.isDarkMode 
                      ? HugeIcons.strokeRoundedMoon02 
                      : HugeIcons.strokeRoundedSun03,
                  color: const Color(0xFF4A00E0),
                  size: 16.sp,
                ),
              ),
            ),
            
            SizedBox(width: 12.w),
            
            // Theme Info
            Expanded(
              child: AutoSizeText(
                languageService.getUIText('theme'),
                style: TextStyle(
                  color: themeProvider.primaryTextColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // Theme Toggle Switch
            Transform.scale(
              scale: 0.8,
              child: Switch.adaptive(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
                activeColor: const Color(0xFF4A00E0),
                activeTrackColor: const Color(0xFF4A00E0).withOpacity(0.3),
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelectionCard(BuildContext context, ThemeProvider themeProvider, LanguageService languageService) {
    return Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode 
            ? const Color(0xFF1A1A2E) 
            : Colors.white,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? Colors.white.withOpacity(0.08) 
              : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode 
                ? Colors.black.withOpacity(0.2) 
                : Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLanguageSelectionBottomSheet(context, languageService, themeProvider),
          borderRadius: BorderRadius.circular(26.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                // Language Flag
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A00E0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Center(
                    child: Text(
                      languageService.currentLanguageFlag,
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ),
                
                SizedBox(width: 12.w),
                
                // Language Info
                Expanded(
                  child: AutoSizeText(
                    '${languageService.getUIText('language')} • ${languageService.currentLanguageName}',
                    style: TextStyle(
                      color: themeProvider.primaryTextColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Arrow Icon
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: themeProvider.tertiaryTextColor,
                  size: 16.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSelectionBottomSheet(BuildContext context, LanguageService languageService, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode 
              ? const Color(0xFF1A1A2E) 
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.symmetric(vertical: 8.h),
              width: 32.w,
              height: 3.h,
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                    ? Colors.white.withOpacity(0.3) 
                    : Colors.grey[400],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            
            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  AutoSizeText(
                    languageService.getUIText('select_language'),
                    style: TextStyle(
                      color: themeProvider.primaryTextColor,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      color: themeProvider.primaryIconColor,
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
            
            // Language list
            Container(
              constraints: BoxConstraints(maxHeight: 350.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: languageService.getSupportedLanguages().length,
                itemBuilder: (context, index) {
                  final language = languageService.getSupportedLanguages()[index];
                  final isSelected = language['code'] == languageService.currentLanguageCode;
                  
                  return Container(
                    height: 48.h,
                    margin: EdgeInsets.only(bottom: 6.h),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF4A00E0).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24.r),
                      border: isSelected 
                          ? Border.all(color: const Color(0xFF4A00E0), width: 1)
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          // Store navigator
                          final navigator = Navigator.of(bottomSheetContext);
                          
                          // Show loading indicator
                          showDialog(
                            context: bottomSheetContext,
                            barrierDismissible: false,
                            builder: (dialogContext) => Center(
                              child: Container(
                                padding: EdgeInsets.all(20.w),
                                decoration: BoxDecoration(
                                  color: themeProvider.isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: const Color(0xFF4A00E0)),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'Changing language...',
                                      style: TextStyle(
                                        color: themeProvider.primaryTextColor,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          
                          // Change language and wait for content refresh
                          await languageService.setLanguage(language['code']!);
                          
                          // Wait a bit for content to refresh
                          await Future.delayed(const Duration(milliseconds: 500));
                          
                          // Close loading dialog
                          if (bottomSheetContext.mounted) {
                            Navigator.of(bottomSheetContext).pop();
                          }
                          
                          // Close language selection
                          navigator.pop();
                        },
                        borderRadius: BorderRadius.circular(24.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Row(
                            children: [
                              // Flag
                              Text(
                                language['flag']!,
                                style: TextStyle(fontSize: 18.sp),
                              ),
                              
                              SizedBox(width: 12.w),
                              
                              // Language name
                              Expanded(
                                child: AutoSizeText(
                                  language['name']!,
                                  style: TextStyle(
                                    color: themeProvider.primaryTextColor,
                                    fontSize: 14.sp,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              
                              // Selected indicator
                              if (isSelected)
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                                  color: const Color(0xFF4A00E0),
                                  size: 16.sp,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard(ThemeProvider themeProvider, LanguageService languageService) {
    return Builder(
      builder: (BuildContext context) {
        return Column(
          children: [
            // App Info Card
            Container(
              height: 52.h,
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                    ? const Color(0xFF1A1A2E) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(26.r),
                border: Border.all(
                  color: themeProvider.isDarkMode 
                      ? Colors.white.withOpacity(0.08) 
                      : Colors.grey.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.isDarkMode 
                        ? Colors.black.withOpacity(0.2) 
                        : Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    // App Icon
                    Container(
                      width: 32.w,
                      height: 32.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6FF), Color(0xFF4A00E0)],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.all_inclusive,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 12.w),
                    
                    // App Info with fallback version handling
                    Expanded(
                      child: FutureBuilder<String>(
                        future: _getAppVersion(),
                        builder: (context, snapshot) {
                          final version = snapshot.data ?? '1.0.0';
                          return AutoSizeText(
                            'Finity • v$version',
                            style: TextStyle(
                              color: themeProvider.primaryTextColor,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 8.h),
            
            // Check for Updates Card
            Container(
              height: 52.h,
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                    ? const Color(0xFF1A1A2E) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(26.r),
                border: Border.all(
                  color: themeProvider.isDarkMode 
                      ? Colors.white.withOpacity(0.08) 
                      : Colors.grey.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.isDarkMode 
                        ? Colors.black.withOpacity(0.2) 
                        : Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _checkForUpdatesWithLoading(context, themeProvider, languageService),
                  borderRadius: BorderRadius.circular(26.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        // Update Icon
                        Container(
                          width: 32.w,
                          height: 32.h,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.system_update,
                              color: Colors.green,
                              size: 16.sp,
                            ),
                          ),
                        ),
                        
                        SizedBox(width: 12.w),
                        
                        // Update Text
                        Expanded(
                          child: AutoSizeText(
                            'Check for Updates',
                            style: TextStyle(
                              color: themeProvider.primaryTextColor,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                        // Arrow Icon
                        Icon(
                          Icons.arrow_forward_ios,
                          color: themeProvider.tertiaryTextColor,
                          size: 16.sp,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Add helper method to get app version with fallback matching build.gradle
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('Error getting package version: $e');
      return '1.0.1'; // Fallback version matching build.gradle
    }
  }

  Widget _buildLogoutCard(BuildContext context, ThemeProvider themeProvider, LanguageService languageService) {
    return Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode 
            ? const Color(0xFF1A1A2E) 
            : Colors.white,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? Colors.white.withOpacity(0.08) 
              : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode 
                ? Colors.black.withOpacity(0.2) 
                : Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogoutConfirmationDialog(context, themeProvider, languageService),
          borderRadius: BorderRadius.circular(26.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                // Logout Icon
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedLogout01,
                      color: Colors.red,
                      size: 16.sp,
                    ),
                  ),
                ),
                
                SizedBox(width: 12.w),
                
                // Logout Text
                Expanded(
                  child: AutoSizeText(
                    languageService.getUIText('logout'),
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                // Arrow Icon
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: Colors.red.withOpacity(0.7),
                  size: 16.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context, ThemeProvider themeProvider, LanguageService languageService) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: themeProvider.isDarkMode 
              ? const Color(0xFF1A1A2E) 
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            languageService.getUIText('logout'),
            style: TextStyle(
              color: themeProvider.primaryTextColor,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            languageService.getUIText('logout_confirmation'),
            style: TextStyle(
              color: themeProvider.secondaryTextColor,
              fontSize: 14.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                languageService.getUIText('cancel'),
                style: TextStyle(
                  color: themeProvider.secondaryTextColor,
                  fontSize: 14.sp,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performLogout(context);
              },
              child: Text(
                languageService.getUIText('logout'),
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performLogout(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Center(
              child: Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: const Color(0xFF4A00E0),
                      backgroundColor: themeProvider.secondaryTextColor.withOpacity(0.3),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Logging out...',
                      style: TextStyle(
                        color: themeProvider.primaryTextColor,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      // Get auth service and perform logout
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      
      // Wait a moment to ensure cleanup is complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Navigate to login screen and clear all previous routes
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
        
        // Show success message after navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Logged out successfully',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      print('Logout error: $e');
      
      // Close loading dialog on error
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  'Logout failed. Please try again.',
                  style: TextStyle(fontSize: 13.sp),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    }
  }

  void _reloadAppWithNewLanguage(BuildContext context) {
    // Simple navigation without forcing rebuilds
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    }
  }

  void _restartApp(BuildContext context) {
    // Simple navigation to home
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    }
  }

  Widget _buildDefaultDeveloperAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF4A00E0)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'S',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      );
  }

  Widget _buildStatItem(String label, String value, IconData icon, ThemeProvider themeProvider) {
    return Column(
      children: [
        HugeIcon(
          icon: icon,
          color: const Color(0xFF4A00E0),
          size: 16.sp,
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: themeProvider.primaryTextColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: themeProvider.tertiaryTextColor,
            fontSize: 10.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildDeveloperCard(ThemeProvider themeProvider, LanguageService languageService) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchGitHubProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDeveloperCardShimmer(themeProvider);
        }
        
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode 
                  ? const Color(0xFF1A1A2E) 
                  : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: themeProvider.isDarkMode 
                    ? Colors.white.withOpacity(0.08) 
                    : Colors.grey.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: themeProvider.isDarkMode 
                      ? Colors.black.withOpacity(0.2) 
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  // Developer Profile Header
                  Row(
                    children: [
                      // Profile Picture
                      Container(
                        width: 50.w,
                        height: 50.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF4A00E0),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: snapshot.hasData && snapshot.data!['avatar_url'] != null
                              ? Image.network(
                                  snapshot.data!['avatar_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildDefaultDeveloperAvatar(),
                                )
                              : _buildDefaultDeveloperAvatar(),
                        ),
                      ),
                      
                      SizedBox(width: 12.w),
                      
                      // Developer Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snapshot.hasData && snapshot.data!['name'] != null
                                  ? snapshot.data!['name']
                                  : 'Sanjay',
                              style: TextStyle(
                                color: themeProvider.primaryTextColor,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'App Developer',
                              style: TextStyle(
                                color: const Color(0xFF4A00E0),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (snapshot.hasData && snapshot.data!['location'] != null) ...[
                              SizedBox(height: 2.h),
                              Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedLocation01,
                                    color: themeProvider.tertiaryTextColor,
                                    size: 12.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    snapshot.data!['location'],
                                    style: TextStyle(
                                      color: themeProvider.tertiaryTextColor,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // Bio/Description
                  if (snapshot.hasData && snapshot.data!['bio'] != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode 
                            ? Colors.white.withOpacity(0.03) 
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        snapshot.data!['bio'],
                        style: TextStyle(
                          color: themeProvider.secondaryTextColor,
                          fontSize: 13.sp,
                          height: 1.4,
                        ),
                      ),
                    ),
                  
                  if (snapshot.hasData && snapshot.data!['bio'] != null)
                    SizedBox(height: 12.h),
                  
                  // Stats Row
                  if (snapshot.hasData)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Repos',
                            snapshot.data!['public_repos']?.toString() ?? '0',
                            HugeIcons.strokeRoundedGithub01,
                            themeProvider,
                          ),
                          _buildStatItem(
                            'Followers',
                            snapshot.data!['followers']?.toString() ?? '0',
                            HugeIcons.strokeRoundedUserMultiple,
                            themeProvider,
                          ),
                          _buildStatItem(
                            'Following',
                            snapshot.data!['following']?.toString() ?? '0',
                            HugeIcons.strokeRoundedUserAdd01,
                            themeProvider,
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: 12.h),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _launchEmail,
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedMail01,
                                    color: Colors.red,
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'Email',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _launchGitHub,
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: themeProvider.isDarkMode 
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: themeProvider.isDarkMode 
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.black.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedGithub,
                                    color: themeProvider.primaryTextColor,
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'GitHub',
                                    style: TextStyle(
                                      color: themeProvider.primaryTextColor,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

  Widget _buildDeveloperCardShimmer(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode 
            ? const Color(0xFF1A1A2E) 
            : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? Colors.white.withOpacity(0.08) 
              : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode 
                ? Colors.black.withOpacity(0.2) 
                : Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Header shimmer
            Row(
              children: [
                // Profile picture shimmer
                Container(
                  width: 50.w,
                  height: 50.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeProvider.isDarkMode 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.grey[300],
                  ),
                ),
                
                SizedBox(width: 12.w),
                
                // Text info shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100.w,
                        height: 16.h,
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: 80.w,
                        height: 12.h,
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode 
                              ? Colors.white.withOpacity(0.05) 
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: 60.w,
                        height: 10.h,
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode 
                              ? Colors.white.withOpacity(0.05) 
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16.h),
            
            // Bio shimmer
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                    ? Colors.white.withOpacity(0.03) 
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    width: 200.w,
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 12.h),
            
            // Stats shimmer
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatShimmer(themeProvider),
                  _buildStatShimmer(themeProvider),
                  _buildStatShimmer(themeProvider),
                ],
              ),
            ),
            
            SizedBox(height: 12.h),
            
            // Action buttons shimmer
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36.h,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Container(
                    height: 36.h,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatShimmer(ThemeProvider themeProvider) {
    return Column(
      children: [
        Container(
          width: 16.w,
          height: 16.h,
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode 
                ? Colors.white.withOpacity(0.1) 
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          width: 20.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode 
                ? Colors.white.withOpacity(0.05) 
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(height: 2.h),
        Container(
          width: 30.w,
          height: 10.h,
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode 
                ? Colors.white.withOpacity(0.05) 
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageService>(
      builder: (context, themeProvider, languageService, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: themeProvider.isDarkMode 
                ? Brightness.light 
                : Brightness.dark,
            statusBarBrightness: themeProvider.isDarkMode 
                ? Brightness.dark 
                : Brightness.light,
            systemNavigationBarColor: themeProvider.primaryBackgroundColor,
            systemNavigationBarIconBrightness: themeProvider.isDarkMode 
                ? Brightness.light 
                : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: themeProvider.primaryBackgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: AutoSizeText(
                languageService.getUIText('settings'),
                style: TextStyle(
                  color: themeProvider.primaryTextColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
              ),
            ),
            body: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appearance Section
                  _buildSectionHeader(languageService.getUIText('appearance'), themeProvider),
                  SizedBox(height: 8.h),
                  
                  // Theme Toggle Card
                  _buildThemeToggleCard(themeProvider, languageService),
                  
                  SizedBox(height: 8.h),
                  
                  // Language Selection Card
                  _buildLanguageSelectionCard(context, themeProvider, languageService),
                  
                  SizedBox(height: 20.h),
                  
                  // Developer Section
                  _buildSectionHeader('Developer', themeProvider),
                  SizedBox(height: 8.h),
                  
                  // Developer Card
                  _buildDeveloperCard(themeProvider, languageService),
                  
                  SizedBox(height: 20.h),
                  
                  // About Section
                  _buildSectionHeader(languageService.getUIText('about'), themeProvider),
                  SizedBox(height: 8.h),
                  
                  // App Info Card
                  _buildAppInfoCard(themeProvider, languageService),
                  
                  SizedBox(height: 20.h),
                  
                  // Account Section
                  _buildSectionHeader(languageService.getUIText('account'), themeProvider),
                  SizedBox(height: 8.h),
                  
                  // Logout Card
                  _buildLogoutCard(context, themeProvider, languageService),
                  
                  SizedBox(height: 20.h),
                ],
              ),
            ),
            bottomNavigationBar: widget.showBottomNav ? const CustomBottomNav(currentIndex: 3) : null,
          ),
        );
      },
    );
  }
}
