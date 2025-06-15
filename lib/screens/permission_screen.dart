import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../providers/theme_provider.dart';
import '../services/language_service.dart';
import '../services/auth_service.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin {
  final LanguageService _languageService = LanguageService();
  
  bool _isLoading = false;
  bool _permissionGranted = false;
  bool _permissionDenied = false;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkCurrentPermissionStatus();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
  }

  Future<void> _checkCurrentPermissionStatus() async {
    try {
      PermissionStatus status;
      
      // Check different permissions based on platform
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), check notification permission
        status = await Permission.notification.status;
      } else if (Platform.isIOS) {
        // For iOS, check notification permission
        status = await Permission.notification.status;
      } else {
        // For other platforms, assume granted
        status = PermissionStatus.granted;
      }
      
      if (mounted) {
        setState(() {
          _permissionGranted = status.isGranted;
          _permissionDenied = status.isDenied || status.isPermanentlyDenied;
        });
      }
      
      print('Current notification permission status: $status');
    } catch (e) {
      print('Error checking notification permission: $e');
      // If permission check fails, assume we need to request it
      if (mounted) {
        setState(() {
          _permissionGranted = false;
          _permissionDenied = false;
        });
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      PermissionStatus status;
      
      if (Platform.isAndroid) {
        // Request notification permission for Android
        status = await Permission.notification.request();
        print('Android notification permission result: $status');
        
        // Also check if we can use exact alarms (for scheduling notifications)
        if (status.isGranted) {
          final alarmStatus = await Permission.scheduleExactAlarm.status;
          print('Schedule exact alarm permission: $alarmStatus');
          
          if (alarmStatus.isDenied) {
            await Permission.scheduleExactAlarm.request();
          }
        }
      } else if (Platform.isIOS) {
        // Request notification permission for iOS
        status = await Permission.notification.request();
        print('iOS notification permission result: $status');
      } else {
        // For other platforms, assume granted
        status = PermissionStatus.granted;
      }
      
      if (mounted) {
        setState(() {
          _permissionGranted = status.isGranted;
          _permissionDenied = status.isDenied || status.isPermanentlyDenied;
          _isLoading = false;
        });
      }
      
      if (status.isGranted) {
        _showSuccessSnackBar();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        });
      } else if (status.isPermanentlyDenied) {
        _showSettingsDialog();
      } else if (status.isDenied) {
        // Show info about why notification is useful but continue
        _showPermissionDeniedInfo();
      }
    } catch (e) {
      print('Error requesting notification permission: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      _showErrorSnackBar();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      });
    }
  }

  void _showPermissionDeniedInfo() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'You can enable notifications later in Settings',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          action: SnackBarAction(
            label: 'Continue',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
        ),
      );
    }
    
    // Auto continue after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  void _showSuccessSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Notifications enabled!',
                style: TextStyle(fontSize: 14.sp),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
    }
  }

  void _showErrorSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Continuing without notifications',
            style: TextStyle(fontSize: 14.sp),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
    }
  }

  void _showSettingsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return AlertDialog(
            backgroundColor: themeProvider.isDarkMode 
                ? const Color(0xFF1A1A2E) 
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.settings,
                  color: const Color(0xFF4A00E0),
                  size: 24.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Permission Required',
                  style: TextStyle(
                    color: themeProvider.primaryTextColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications are blocked. To enable:',
                  style: TextStyle(
                    color: themeProvider.secondaryTextColor,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  '1. Open Settings\n2. Find Finity app\n3. Enable Notifications',
                  style: TextStyle(
                    color: themeProvider.primaryTextColor,
                    fontSize: 14.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _continueToApp();
                },
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: themeProvider.secondaryTextColor,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await openAppSettings();
                  // Give user time to change settings
                  await Future.delayed(const Duration(seconds: 2));
                  // Recheck permission status
                  if (mounted) {
                    await _checkCurrentPermissionStatus();
                    if (!_permissionGranted) {
                      _continueToApp();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A00E0),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Open Settings',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _continueToApp() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _skipPermission() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthService>(
      builder: (context, themeProvider, authService, child) {
        return Scaffold(
          backgroundColor: themeProvider.primaryBackgroundColor,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                children: [
                  // Header with user info
                  Row(
                    children: [
                      if (authService.currentUserName?.isNotEmpty == true)
                        Expanded(
                          child: Row(
                            children: [
                              if (authService.currentUserPhotoUrl?.isNotEmpty == true)
                                CircleAvatar(
                                  radius: 16.r,
                                  backgroundImage: NetworkImage(authService.currentUserPhotoUrl!),
                                  backgroundColor: const Color(0xFF4A00E0).withOpacity(0.1),
                                )
                              else
                                CircleAvatar(
                                  radius: 16.r,
                                  backgroundColor: const Color(0xFF4A00E0).withOpacity(0.1),
                                  child: Text(
                                    authService.currentUserName!.isNotEmpty 
                                        ? authService.currentUserName![0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      color: const Color(0xFF4A00E0),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  'Hi ${authService.currentUserName}!',
                                  style: TextStyle(
                                    color: themeProvider.primaryTextColor,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      TextButton(
                        onPressed: _skipPermission,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: themeProvider.secondaryTextColor,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo with notification icon
                            Container(
                              width: 120.w,
                              height: 120.h,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF), Color(0xFF4A00E0)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4A00E0).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.all_inclusive,
                                    size: 60.sp,
                                    color: Colors.white,
                                  ),
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: Container(
                                      padding: EdgeInsets.all(6.w),
                                      decoration: BoxDecoration(
                                        color: _permissionGranted 
                                            ? Colors.green 
                                            : Colors.orange,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: HugeIcon(
                                        icon: _permissionGranted 
                                            ? HugeIcons.strokeRoundedNotification03
                                            : HugeIcons.strokeRoundedNotification01,
                                        color: Colors.white,
                                        size: 16.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 48.h),
                            
                            // Title
                            AutoSizeText(
                              'Stay Updated',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.primaryTextColor,
                              ),
                              maxLines: 1,
                            ),
                            
                            SizedBox(height: 16.h),
                            
                            // Description
                            AutoSizeText(
                              'Get notified about new content and updates',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: themeProvider.secondaryTextColor,
                                height: 1.5,
                              ),
                              maxLines: 2,
                            ),
                            
                            SizedBox(height: 64.h),
                            
                            // Action Buttons
                            if (_permissionGranted)
                              _buildSuccessButton(themeProvider)
                            else
                              _buildPermissionButtons(themeProvider),
                          ],
                        ),
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

  Widget _buildPermissionButtons(ThemeProvider themeProvider) {
    return Column(
      children: [
        // Allow Notifications Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestNotificationPermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A00E0),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedNotification03,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'Enable Notifications',
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
        
        // Maybe Later Button
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isLoading ? null : _skipPermission,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Text(
              'Maybe Later',
              style: TextStyle(
                color: themeProvider.secondaryTextColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessButton(ThemeProvider themeProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _continueToApp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 20.sp),
            SizedBox(width: 12.w),
            Text(
              'Continue to Finity',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
