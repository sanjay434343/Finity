import 'package:finity/screens/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/content_service.dart';
import '../services/language_service.dart';
import '../services/share_service.dart';
import '../services/local_database.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/image_shimmer.dart';
import '../widgets/custom_bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  final bool showBottomNav;
  
  const HomeScreen({super.key, this.showBottomNav = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ContentService _contentService = ContentService();
  final LanguageService _languageService = LanguageService();
  final ShareService _shareService = ShareService();
  
  List<Map<String, dynamic>> _homeContent = [];
  Map<String, bool> _likedContent = {};
  Map<String, bool> _expandedContent = {}; // Add this for tracking expanded state
  bool _isLoading = true;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;
  
  // Animation controller for loading
  AnimationController? _loadingController;
  Animation<double>? _loadingAnimation;
  Animation<double>? _colorAnimation;
  bool _isDrawingComplete = false;

  // Add gradient rotation animation controller
  AnimationController? _gradientRotationController;
  Animation<double>? _gradientRotationAnimation;
  
  get exception => null;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // Initialize loading animation controller
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _loadingController!, curve: Curves.easeInOut));
    
    _colorAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _loadingController!, curve: Curves.linear));

    _loadingController?.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isDrawingComplete) {
        setState(() {
          _isDrawingComplete = true;
        });
        // Start color animation after drawing is complete
        _loadingController?.duration = const Duration(seconds: 3);
        _loadingController?.repeat();
      }
    });
    
    // Initialize gradient rotation animation controller
    _gradientRotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _gradientRotationAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _gradientRotationController!, curve: Curves.linear));
    
    // Start the gradient rotation animation and repeat it
    _gradientRotationController?.repeat();
    
    _loadHomeContent();
    
    // Listen to language changes
    _languageService.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _loadingController?.dispose();
    _gradientRotationController?.dispose();
    _languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    // Refresh content when language changes
    if (mounted) {
      _loadHomeContent();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreContent();
    }
  }

  Future<void> _loadHomeContent() async {
    setState(() {
      _isLoading = true;
      _homeContent.clear();
    });
    
    _loadingController?.repeat();
    
    try {
      final content = await _contentService.getHomeContent(count: 15);
      
      if (mounted) {
        setState(() {
          _homeContent = content;
          _isLoading = false;
        });
        
        _loadingController?.stop();
        _loadingController?.reset();
        _loadLikedStatus();
      }
    } catch (e) {
      print('Error loading home content: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _loadingController?.stop();
        _loadingController?.reset();
      }
    }
  }

  Future<void> _loadMoreContent() async {
    if (_isLoadingMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final moreContent = await _contentService.loadMoreHomeContent(
        count: _homeContent.length + 10,
        forceRefresh: false
      );
      
      if (moreContent.length > _homeContent.length && mounted) {
        final newContent = moreContent.skip(_homeContent.length).toList();
        setState(() {
          _homeContent.addAll(newContent);
          _isLoadingMore = false;
        });
        _loadLikedStatus();
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      print('Error loading more content: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadLikedStatus() async {
    final Map<String, bool> status = {};
    for (final content in _homeContent) {
      status[content['id'] ?? ''] = await _contentService.isContentLiked(content['id'] ?? '');
    }
    if (mounted) setState(() => _likedContent = status);
  }

  Future<void> _toggleLike(Map<String, dynamic> content) async {
    final contentId = content['id'] ?? '';
    final isCurrentlyLiked = _likedContent[contentId] ?? false;
    
    setState(() {
      _likedContent[contentId] = !isCurrentlyLiked;
      content['likes'] = (content['likes'] ?? 0) + (isCurrentlyLiked ? -1 : 1);
    });

    bool success = isCurrentlyLiked 
        ? await _contentService.unlikeContent(contentId)
        : await _contentService.likeContent(content, ContentType.flow);

    if (!success) {
      setState(() {
        _likedContent[contentId] = isCurrentlyLiked;
        content['likes'] = (content['likes'] ?? 0) + (isCurrentlyLiked ? 1 : -1);
      });
    }
  }

  void _shareContent(Map<String, dynamic> content) async {
    try {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      final shareableContent = {
        ...content,
        'app_name': 'Finity',
        'source': 'Wikipedia',
        'type': 'Finity Flow',
      };

      if (shareableContent['image'] != null && shareableContent['image'].toString().isNotEmpty) {
        await _shareService.shareContentWithImage(
          content: shareableContent,
          sharePositionOrigin: sharePositionOrigin,
          context: context,
        );
      } else {
        await _shareService.shareContent(
          content: shareableContent,
          sharePositionOrigin: sharePositionOrigin,
          context: context,
        );
      }
    } catch (e) {
      debugPrint('Error sharing content: $e');
    }
  }

  void _openInPlayer(Map<String, dynamic> content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          contentData: content,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeProvider themeProvider) {
    return AppBar(
      backgroundColor: themeProvider.primaryBackgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 50.h,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Finity',
            style: TextStyle(
              color: themeProvider.primaryTextColor,
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Curcive',
            ),
          ),
          SizedBox(width: 7.w),
          Text(
            'Flow',
            style: TextStyle(
              color: themeProvider.primaryTextColor,
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Blinka',
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _loadHomeContent,
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedRefresh,
            color: themeProvider.primaryIconColor,
            size: 22.sp,
          ),
        ),
        // User profile picture from SharedPreferences
        FutureBuilder<Map<String, dynamic>?>(
          future: _getUserDataFromPrefs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: EdgeInsets.only(right: 16.w),
                child: Container(
                  width: 35.w,
                  height: 35.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4A00E0).withOpacity(0.1),
                    border: Border.all(
                      color: const Color(0xFF4A00E0).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 15.w,
                      height: 15.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF4A00E0),
                      ),
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              final userData = snapshot.data!;
              final photoUrl = userData['photoURL'] as String?;
              final displayName = userData['displayName'] as String? ?? 'User';
              
              // Debug logging for photo URL
              print('Home AppBar: Photo URL = $photoUrl');
              print('Home AppBar: Display Name = $displayName');
              print('Home AppBar: Photo URL length = ${photoUrl?.length}');
              print('Home AppBar: Photo URL valid = ${photoUrl != null && photoUrl.isNotEmpty}');
              
              return Padding(
                padding: EdgeInsets.only(right: 16.w),
                child: GestureDetector(
                  onTap: () {
                    _showProfileMenu(context, themeProvider, userData);
                  },
                  child: AnimatedBuilder(
                    animation: _gradientRotationAnimation!,
                    builder: (context, child) {
                      return Container(
                        width: 35.w,
                        height: 35.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: const [
                              Colors.blue,
                              Color.fromARGB(255, 215, 0, 253),
                              Colors.yellow,
                              Color.fromARGB(255, 255, 0, 162),
                              Color.fromARGB(255, 255, 17, 0),
                              Color.fromARGB(255, 4, 255, 13),
                              Colors.blue, // Complete the circle
                            ],
                            stops: const [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
                            transform: GradientRotation(_gradientRotationAnimation!.value * 2 * 3.14159),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4A00E0).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(3.w), // Increased padding for better centering
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: themeProvider.primaryBackgroundColor,
                            ),
                            child: ClipOval(
                              child: photoUrl != null && photoUrl.isNotEmpty
                                  ? Image.network(
                                      photoUrl,
                                      width: 29.w, // Adjusted size
                                      height: 29.h,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        print('Home AppBar: NetworkImage error: $exception');
                                        return _buildDefaultProfileAvatar(displayName, themeProvider);
                                      },
                                    )
                                  : _buildDefaultProfileAvatar(displayName, themeProvider),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
            
            // Fallback if no user data
            return Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Container(
                width: 35.w,
                height: 35.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A00E0).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFF4A00E0).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person,
                  color: const Color(0xFF4A00E0),
                  size: 18.sp,
                ),
              ),
              );
          },
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _getUserDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Use the correct keys that match what AuthService stores
      final uid = prefs.getString('uid') ?? prefs.getString('user_id') ?? prefs.getString('userId');
      final displayName = prefs.getString('user_name') ?? prefs.getString('user_display_name');
      final email = prefs.getString('user_email');
      final photoURL = prefs.getString('user_photo_url');
      
      // Debug logging to check what's stored
      print('Home: Retrieved user data from prefs:');
      print('  UID: $uid');
      print('  Display Name: $displayName');
      print('  Email: $email');
      print('  Photo URL: $photoURL');
      
      // Check if we have any user data (email or photoURL is enough)
      if (email != null || photoURL != null || uid != null) {
        return {
          'uid': uid ?? '',
          'displayName': displayName ?? 'User',
          'email': email ?? '',
          'photoURL': photoURL,
        };
      }
      
      return null;
    } catch (e) {
      print('Error getting user data from prefs: $e');
      return null;
    }
  }

  Widget _buildDefaultProfileAvatar(String displayName, ThemeProvider themeProvider) {
    return Container(
      color: const Color(0xFF4A00E0),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, ThemeProvider themeProvider, [Map<String, dynamic>? userData]) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: themeProvider.primaryBackgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.symmetric(vertical: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode 
                      ? Colors.white.withOpacity(0.3) 
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              
              // Profile header
              Text(
                'Profile',
                style: TextStyle(
                  color: themeProvider.primaryTextColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20.h),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: userData != null ? Future.value(userData) : _getUserDataFromPrefs(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFF4A00E0),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasData && snapshot.data != null) {
                        final user = snapshot.data!;
                        final photoUrl = user['photoURL'] as String?;
                        final displayName = user['displayName'] as String?;
                        final email = user['email'] as String? ?? '';
                        final uid = user['uid'] as String? ?? '';
                        
                        // Better name handling
                        String userName = 'User';
                        if (displayName != null && displayName.isNotEmpty && displayName != 'User') {
                          userName = displayName;
                        } else if (email.isNotEmpty) {
                          final emailParts = email.split('@');
                          if (emailParts.isNotEmpty && emailParts[0].isNotEmpty) {
                            userName = emailParts[0].replaceAll('.', ' ').replaceAll('_', ' ');
                            userName = userName.split(' ').map((word) => 
                              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : word
                            ).join(' ');
                          }
                        }
                        
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            children: [
                              // Large profile picture with static gradient border (to reduce animation lag)
                              Container(
                                width: 100.w,
                                height: 100.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.blue,
                                      Colors.purple,
                                      Colors.yellow,
                                      Colors.pink,
                                      Colors.red,
                                      Colors.green,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4A00E0).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  margin: EdgeInsets.all(4.w),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: themeProvider.primaryBackgroundColor,
                                  ),
                                  child: ClipOval(
                                    child: (photoUrl != null && photoUrl.isNotEmpty)
                                        ? Image.network(
                                            photoUrl,
                                            fit: BoxFit.cover,
                                            width: 92.w,
                                            height: 92.h,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(
                                                color: themeProvider.isDarkMode 
                                                    ? Colors.white.withOpacity(0.1) 
                                                    : Colors.grey[200],
                                                child: Center(
                                                  child: Text(
                                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                                    style: TextStyle(
                                                      color: const Color(0xFF4A00E0),
                                                      fontSize: 36.sp,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: const Color(0xFF4A00E0),
                                                child: Center(
                                                  child: Text(
                                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 36.sp,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: const Color(0xFF4A00E0),
                                            child: Center(
                                              child: Text(
                                                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 36.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20.h),
                              
                              // User name prominently displayed
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00C6FF), Color(0xFF4A00E0)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(15.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4A00E0).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Flexible(
                                      child: Text(
                                        userName,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // User details section
                              SizedBox(height: 20.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: themeProvider.isDarkMode 
                                      ? Colors.white.withOpacity(0.05) 
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: themeProvider.isDarkMode 
                                        ? Colors.white.withOpacity(0.1) 
                                        : Colors.grey[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Email section
                                    if (email.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(6.w),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8.r),
                                            ),
                                            child: HugeIcon(
                                              icon: HugeIcons.strokeRoundedMail01,
                                              color: Colors.blue,
                                              size: 16.sp,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Email Address',
                                                  style: TextStyle(
                                                    color: themeProvider.tertiaryTextColor,
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  email,
                                                  style: TextStyle(
                                                    color: themeProvider.primaryTextColor,
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    
                                    if (uid.isNotEmpty && email.isNotEmpty) ...[
                                      SizedBox(height: 16.h),
                                      Divider(
                                        color: themeProvider.isDarkMode 
                                            ? Colors.white.withOpacity(0.1) 
                                            : Colors.grey[300],
                                        height: 1,
                                      ),
                                      SizedBox(height: 16.h),
                                    ],
                                    
                                    // Account ID section
                                    if (uid.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(6.w),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8.r),
                                            ),
                                            child: HugeIcon(
                                              icon: HugeIcons.strokeRoundedUserAccount,
                                              color: Colors.green,
                                              size: 16.sp,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Account ID',
                                                  style: TextStyle(
                                                    color: themeProvider.tertiaryTextColor,
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  uid.length > 25 ? "${uid.substring(0, 25)}..." : uid,
                                                  style: TextStyle(
                                                    color: themeProvider.secondaryTextColor,
                                                    fontSize: 12.sp,
                                                    fontFamily: 'monospace',
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 24.h),
                              
                              // Profile actions
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.pushNamed(context, '/profile');
                                      },
                                      icon: HugeIcon(
                                        icon: HugeIcons.strokeRoundedUser,
                                        size: 18.sp,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        'View Profile',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4A00E0),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 14.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await _logout();
                                      },
                                      icon: HugeIcon(
                                        icon: HugeIcons.strokeRoundedLogout01,
                                        size: 18.sp,
                                        color: const Color(0xFF4A00E0),
                                      ),
                                      label: Text(
                                        'Logout',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF4A00E0),
                                        side: BorderSide(
                                          color: const Color(0xFF4A00E0),
                                          width: 1.5,
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: 14.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 40.h), // Extra bottom padding
                            ],
                          ),
                        );
                      }
                      
                      return Padding(
                        padding: EdgeInsets.all(40.w),
                        child: Column(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedUserRemove02,
                              color: themeProvider.tertiaryTextColor,
                              size: 48.sp,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No user data available',
                              style: TextStyle(
                                color: themeProvider.secondaryTextColor,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Please login again to view profile',
                              style: TextStyle(
                                color: themeProvider.tertiaryTextColor,
                                fontSize: 12.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Navigate to login
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // Add method to open Wikipedia article
  Future<void> _openWikipediaArticle(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open Wikipedia article'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error opening Wikipedia article: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening article: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          backgroundColor: themeProvider.primaryBackgroundColor,
          appBar: _buildAppBar(themeProvider),
          body: _buildBody(themeProvider),
          bottomNavigationBar: widget.showBottomNav ? const CustomBottomNav(currentIndex: 0) : null,
        );
      },
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading) {
      return _buildLoadingState(themeProvider);
    }

    if (_homeContent.isEmpty) {
      return _buildEmptyState(themeProvider);
    }

    return RefreshIndicator(
      onRefresh: _loadHomeContent,
      backgroundColor: themeProvider.primaryBackgroundColor,
      color: const Color(0xFF4A00E0),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: _homeContent.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _homeContent.length) {
            return _buildLoadingMoreIndicator(themeProvider);
          }
          
          final content = _homeContent[index];
          return _buildContentItem(content, themeProvider, index);
        },
      ),
    );
  }

  Widget _buildLoadingState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _loadingController!,
            builder: (context, child) {
              return CustomPaint(
                size: Size(120.w, 120.h),
                painter: SplashInfinityPainter(
                  _isDrawingComplete ? 1.0 : _loadingAnimation!.value,
                  _isDrawingComplete ? _colorAnimation!.value : 0.0,
                ),
              );
            },
          ),
          SizedBox(height: 16.h),
          Text(
            _languageService.getUIText('loading_content'),
            style: TextStyle(
              color: themeProvider.secondaryTextColor,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFileEmpty01,
            color: themeProvider.tertiaryTextColor,
            size: 64.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            _languageService.getUIText('no_content'),
            style: TextStyle(
              color: themeProvider.primaryTextColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _languageService.getUIText('tap_to_explore'),
            style: TextStyle(
              color: themeProvider.secondaryTextColor,
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(ThemeProvider themeProvider) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: CircularProgressIndicator(
          color: const Color(0xFF4A00E0),
          backgroundColor: themeProvider.secondaryTextColor.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildContentItem(Map<String, dynamic> content, ThemeProvider themeProvider, int index) {
    final isLiked = _likedContent[content['id']] ?? false;
    final contentId = content['id'] ?? '';
    final isExpanded = _expandedContent[contentId] ?? false;
    final extract = content['extract'] ?? 'No description available.';
    final shouldShowReadMore = extract.length > 200; // Show read more if content is longer than 200 characters
    
    return OpenContainer<bool>(
      transitionType: ContainerTransitionType.fade,
      transitionDuration: const Duration(milliseconds: 500),
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      middleColor: themeProvider.primaryBackgroundColor,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      closedBuilder: (context, action) => Container(
        decoration: BoxDecoration(
          color: themeProvider.primaryBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color: themeProvider.isDarkMode 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.grey[200]!,
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile section
              Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: themeProvider.primaryBackgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeProvider.isDarkMode 
                            ? Colors.white.withOpacity(0.2) 
                            : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: Size(24.w, 24.h),
                        painter: HomeInfinityProfilePainter(),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              // Content section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with like button
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00C6FF), Color(0xFF4A00E0)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: AutoSizeText(
                            'Finity Flow',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          _languageService.currentLanguageName,
                          style: TextStyle(
                            color: themeProvider.secondaryTextColor,
                            fontSize: 12.sp,
                          ),
                        ),
                        const Spacer(),
                        // Like button in top right
                        GestureDetector(
                          onTap: () => _toggleLike(content),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: isLiked 
                                  ? Colors.red.withOpacity(0.1) 
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedFavourite,
                              color: isLiked ? Colors.red : themeProvider.secondaryIconColor,
                              size: 20.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    
                    // Title
                    AutoSizeText(
                      content['title'] ?? 'Unknown Title',
                      style: TextStyle(
                        color: themeProvider.primaryTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                        height: 1.3,
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 8.h),
                    
                    // Extract/Description with read more functionality
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoSizeText(
                          extract,
                          style: TextStyle(
                            color: themeProvider.primaryTextColor.withOpacity(0.8),
                            fontSize: 15.sp,
                            height: 1.4,
                          ),
                          maxLines: isExpanded ? null : 4,
                          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                        if (shouldShowReadMore) ...[
                          SizedBox(height: 8.h),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _expandedContent[contentId] = !isExpanded;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A00E0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: const Color(0xFF4A00E0).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isExpanded ? 'Show Less' : 'Read More',
                                    style: TextStyle(
                                      color: const Color(0xFF4A00E0),
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedArrowDown01,
                                      color: const Color(0xFF4A00E0),
                                      size: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // Featured image with full view
                    if (content['image'] != null) ...[
                      SizedBox(height: 12.h),
                      AdaptiveImageWidget(
                        imageUrl: content['image'],
                        themeProvider: themeProvider,
                        borderRadius: 15,
                        enableZoom: true,
                      ),
                    ],
                    
                    SizedBox(height: 16.h),
                    
                    // Action buttons row - share and play only
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode 
                            ? Colors.white.withOpacity(0.05) 
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: themeProvider.isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey[200]!,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Share button
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _shareContent(content),
                                borderRadius: BorderRadius.circular(6.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 6.h),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedShare08,
                                        color: themeProvider.secondaryIconColor,
                                        size: 14.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      AutoSizeText(
                                        _languageService.getUIText('share'),
                                        style: TextStyle(
                                          color: themeProvider.secondaryTextColor,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Divider
                          Container(
                            width: 1,
                            height: 16.h,
                            color: themeProvider.isDarkMode 
                                ? Colors.white.withOpacity(0.1) 
                                : Colors.grey[300],
                          ),
                          
                          // Play button - opens in player
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openInPlayer(content),
                                borderRadius: BorderRadius.circular(6.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 6.h),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedPlay,
                                        color: Colors.orange,
                                        size: 14.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      AutoSizeText(
                                        'Play',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
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
                    ),
                    SizedBox(height: 6.h),
                    
                    // Visit Article button
                    if (content['url'] != null && content['url'].toString().isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(top: 4.h),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openWikipediaArticle(content['url']),
                            borderRadius: BorderRadius.circular(8.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedGlobe,
                                    color: Colors.orange,
                                    size: 14.sp,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'Visit Wikipedia Article',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12.sp,
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
              ),
            ],
          ),
        ),
      ),
      openBuilder: (context, action) => PlayerScreen(
        contentData: content,
      ),
    );
  }
}

// Home screen specific infinity profile painter
class HomeInfinityProfilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

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

    // Scale factors to match the splash screen infinity shape
    final scaleX = size.width / 120;
    final scaleY = size.height / 120;

    final path = Path();

    // Complete infinity shape like splash screen
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
    return false;
  }
}

// Loading animation painter
class SplashInfinityPainter extends CustomPainter {
  final double animationValue;
  final double colorAnimationValue;

  SplashInfinityPainter(this.animationValue, this.colorAnimationValue);

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

    Color currentColor;
    if (colorAnimationValue > 0) {
      // Calculate current color position (0-5.99...)
      final colorPosition = (colorAnimationValue * colors.length) % colors.length;
      final colorIndex = colorPosition.floor();
      final colorProgress = colorPosition - colorIndex;
      
      // Get current and next color
      final baseColor = colors[colorIndex];
      final nextColor = colors[(colorIndex + 1) % colors.length];
      
      // Interpolate between current and next color
      currentColor = Color.lerp(baseColor, nextColor, colorProgress)!;
    } else {
      currentColor = const Color(0xFF0072FF); // Default blue
    }

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        currentColor,
        currentColor.withOpacity(0.7),
        currentColor.withOpacity(0.9),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = gradient.createShader(rect);

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

    final pathMetric = path.computeMetrics().first;
    final animatedPath = pathMetric.extractPath(0, pathMetric.length * animationValue);

    canvas.drawPath(animatedPath, paint);
    
    if (animationValue > 0 && animationValue < 1) {
      final currentPoint = pathMetric.getTangentForOffset(pathMetric.length * animationValue)?.position;
      if (currentPoint != null) {
        final glowPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(currentPoint, 3, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
