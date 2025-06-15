import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/content_service.dart';
import '../services/local_database.dart';
import '../providers/theme_provider.dart';
import '../services/language_service.dart';
import '../services/music_service.dart';

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> contentData;
  
  const PlayerScreen({super.key, required this.contentData});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final ContentService _contentService = ContentService();
  final LanguageService _languageService = LanguageService();
  final MusicService _musicService = MusicService(); // Add music service
  
  bool isLiked = false;
  
  // Remove old audio player variables - now handled by MusicService

  // Animation for mute icon
  bool _showMuteIcon = false;
  AnimationController? _muteIconController;
  Animation<double>? _muteIconAnimation;

  final List<String> musicSearchTerms = [
    'ambient', 'piano', 'classical piano', 'meditation', 'study music',
    'nature sounds', 'cafe music', 'focus music', 'calm music',
    'peaceful', 'minimal', 'downtempo', 'atmospheric', 'spa music'
  ];

  @override
  void initState() {
    super.initState();
    _muteIconController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _muteIconAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _muteIconController!, curve: Curves.easeInOut));
    
    _initializeAudio();
    _loadContent();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _musicService.pauseMusic();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _musicService.dispose();
    _muteIconController?.dispose();
    super.dispose();
  }

  void _initializeAudio() async {
    await _musicService.initialize();
  }

  void _loadContent() async {
    _checkLikedStatus();
    
    // Start music immediately after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final contentId = widget.contentData['id'] ?? 'player_content';
        final contentTitle = widget.contentData['title'] ?? 'Unknown';
        _musicService.playMusicForContent(contentId, contentTitle);
      }
    });
  }

  void _checkLikedStatus() async {
    final liked = await _contentService.isContentLiked(widget.contentData['id'] ?? '');
    if (mounted) {
      setState(() {
        isLiked = liked;
      });
    }
  }

  void _toggleLike() async {
    final contentId = widget.contentData['id'] ?? '';
    final currentlyLiked = isLiked;
    
    setState(() {
      isLiked = !currentlyLiked;
      widget.contentData['likes'] = (widget.contentData['likes'] ?? 0) + (currentlyLiked ? -1 : 1);
    });

    bool success = currentlyLiked 
        ? await _contentService.unlikeContent(contentId)
        : await _contentService.likeContent(widget.contentData, ContentType.loop);

    if (!success) {
      setState(() {
        isLiked = currentlyLiked;
        widget.contentData['likes'] = (widget.contentData['likes'] ?? 0) + (currentlyLiked ? 1 : -1);
      });
    }
  }

  void _toggleMusic() async {
    try {
      if (_musicService.isPlaying) {
        print('Pausing music');
        await _musicService.pauseMusic();
      } else {
        print('Resuming/starting music');
        if (_musicService.currentMusicUrl != null) {
          // Resume current track
          await _musicService.resumeMusic();
        } else {
          // Start new music
          final contentId = widget.contentData['id'] ?? 'player_content';
          final contentTitle = widget.contentData['title'] ?? 'Unknown';
          await _musicService.playMusicForContent(contentId, contentTitle);
        }
      }
    } catch (e) {
      print('Error toggling music: $e');
    }
  }

  void _toggleMute() async {
    await _musicService.toggleMute();
    _showTemporaryMuteIcon();
  }

  void _showTemporaryMuteIcon() async {
    if (_muteIconController == null) return;
    setState(() => _showMuteIcon = true);
    await _muteIconController!.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    await _muteIconController!.reverse();
    setState(() => _showMuteIcon = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final gradientHeight = themeProvider.gradientHeight;
        final topGradientHeight = 200.0;
        
        return Scaffold(
          backgroundColor: themeProvider.primaryBackgroundColor,
          body: Stack(
            children: [
              // Main content
              Stack(
                fit: StackFit.expand,
                children: [
                  // Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeProvider.loopsBackgroundColors[0].withOpacity(0.3),
                          themeProvider.primaryBackgroundColor.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),

                  // Main content
                  GestureDetector(
                    onTap: () => _showContentBottomSheet(themeProvider),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: widget.contentData['image'] != null
                          ? Image.network(
                              widget.contentData['image'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackContent(themeProvider),
                            )
                          : _buildFallbackContent(themeProvider),
                    ),
                  ),

                  // Top gradient for text visibility
                  Positioned(
                    left: 0, right: 0, top: 0, height: topGradientHeight.h,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: themeProvider.topGradientColors,
                          stops: const [0.0, 0.15, 0.3, 0.5, 0.7, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Bottom gradient
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: gradientHeight.h,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: themeProvider.bottomGradientColors,
                          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Right action buttons
                  Positioned(
                    right: 12.w, bottom: 120.h,
                    child: Column(
                      children: [
                        _buildActionButton(
                          icon: HugeIcons.strokeRoundedFavourite,
                          color: isLiked ? Colors.red : themeProvider.primaryIconColor,
                          label: _languageService.getUIText('like'),
                          onTap: _toggleLike,
                          themeProvider: themeProvider,
                        ),
                        SizedBox(height: 16.h),
                        _buildActionButton(
                          icon: HugeIcons.strokeRoundedShare01,
                          color: themeProvider.primaryIconColor,
                          label: _languageService.getUIText('share'),
                          onTap: () {},
                          themeProvider: themeProvider,
                        ),
                      ],
                    ),
                  ),

                  // Bottom content
                  Positioned(
                    left: 16.w, right: 80.w, bottom: 20.h,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Profile section
                        Row(
                          children: [
                            SizedBox(
                              width: 32.w, height: 32.h,
                              child: CustomPaint(
                                size: Size(32.w, 32.h),
                                painter: InfinityProfilePainter(),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              _languageService.getUIText('finity_player'),
                              style: TextStyle(
                                color: themeProvider.primaryTextColor,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                shadows: [Shadow(color: themeProvider.primaryBackgroundColor.withOpacity(0.7), blurRadius: 2)],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        
                        AutoSizeText(
                          widget.contentData['title'] ?? 'Unknown Title',
                          style: TextStyle(
                            color: themeProvider.primaryTextColor,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: themeProvider.primaryBackgroundColor.withOpacity(0.8), blurRadius: 4)],
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 8.h),
                        AutoSizeText(
                          widget.contentData['extract'] ?? _languageService.getUIText('tap_to_explore'),
                          style: TextStyle(
                            color: themeProvider.primaryTextColor.withOpacity(0.8),
                            fontSize: 14.sp,
                            shadows: [Shadow(color: themeProvider.primaryBackgroundColor.withOpacity(0.8), blurRadius: 3)],
                          ),
                          maxLines: 3,
                        ),
                        SizedBox(height: 12.h),
                        
                        // Stats row
                        Row(
                          children: [
                            // Views count
                            Row(
                              children: [
                                Icon(
                                  Icons.visibility,
                                  color: themeProvider.secondaryTextColor,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${widget.contentData['views'] ?? '0'} ${_languageService.getUIText('views')}',
                                  style: TextStyle(
                                    color: themeProvider.secondaryTextColor,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    shadows: [Shadow(color: themeProvider.primaryBackgroundColor.withOpacity(0.8), blurRadius: 3)],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 16.w),
                            
                            // Music status
                            Row(
                              children: [
                                Icon(
                                  _musicService.isPlaying ? Icons.music_note : Icons.music_off,
                                  color: _musicService.isPlaying 
                                      ? Colors.green 
                                      : themeProvider.secondaryTextColor,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  _musicService.isPlaying 
                                      ? _languageService.getUIText('music_playing')
                                      : _languageService.getUIText('music_paused'),
                                  style: TextStyle(
                                    color: _musicService.isPlaying 
                                        ? Colors.green 
                                        : themeProvider.secondaryTextColor,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    shadows: [Shadow(color: themeProvider.primaryBackgroundColor.withOpacity(0.8), blurRadius: 3)],
                                  ),
                                ),
                              ],
                            ),
                            
                            Spacer(),
                            
                            // View More button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showContentBottomSheet(themeProvider),
                                borderRadius: BorderRadius.circular(16.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: themeProvider.viewMoreButtonBackgroundColor,
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: themeProvider.viewMoreButtonBorderColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _languageService.getUIText('view_more'),
                                        style: TextStyle(
                                          color: themeProvider.primaryTextColor,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          shadows: [Shadow(color: themeProvider.primaryBackgroundColor.withOpacity(0.8), blurRadius: 3)],
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: themeProvider.primaryTextColor,
                                        size: 10.sp,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // App bar overlay
              SafeArea(
                child: Container(
                  height: 56.h,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_back, color: Colors.white, size: 16.sp),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Row(
                            children: [
                              Text(
                                'Finity',
                                style: TextStyle(
                                  color: themeProvider.primaryTextColor,
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Curcive',
                                  shadows: [
                                    Shadow(
                                      color: themeProvider.isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Loops',
                                style: TextStyle(
                                  color: themeProvider.primaryTextColor,
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Blinka',
                                  shadows: [
                                    Shadow(
                                      color: themeProvider.isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _toggleMute,
                        icon: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                            icon: _musicService.isMuted ? HugeIcons.strokeRoundedVolumeOff : HugeIcons.strokeRoundedVolumeHigh,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Mute icon overlay
              if (_showMuteIcon && _muteIconAnimation != null)
                Positioned.fill(
                  child: Center(
                    child: FadeTransition(
                      opacity: _muteIconAnimation!,
                      child: Container(
                        width: 80.w, height: 80.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: themeProvider.muteIconBackgroundColor,
                          border: Border.all(
                            color: themeProvider.muteIconBorderColor,
                            width: 2
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeProvider.primaryBackgroundColor.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: _musicService.isMuted ? HugeIcons.strokeRoundedVolumeOff : HugeIcons.strokeRoundedVolumeHigh,
                            color: themeProvider.primaryIconColor,
                            size: 32.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackContent(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeProvider.loopsBackgroundColors[0].withOpacity(0.3),
            themeProvider.primaryBackgroundColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, color: themeProvider.tertiaryTextColor, size: 120.sp),
            SizedBox(height: 16.h),
            Text(_languageService.getUIText('tap_to_explore'), style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 18.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: HugeIcon(icon: icon, color: color, size: 20.sp),
          style: IconButton.styleFrom(
            backgroundColor: themeProvider.actionButtonBackgroundColor,
            shape: const CircleBorder(),
            elevation: 1,
            minimumSize: Size(32.w, 32.h),
            padding: EdgeInsets.all(6.w),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: themeProvider.primaryTextColor,
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: themeProvider.primaryBackgroundColor.withOpacity(0.8), blurRadius: 3)],
          ),
        ),
      ],
    );
  }

  void _showContentBottomSheet(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: themeProvider.bottomSheetGradientColors,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
              ),
              border: Border.all(color: themeProvider.bottomSheetBorderColor),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12.h),
                  width: 40.w, height: 4.h,
                  decoration: BoxDecoration(
                    color: themeProvider.bottomSheetHandleColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.contentData['title'] ?? 'Unknown Title',
                          style: TextStyle(
                            color: themeProvider.primaryTextColor,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        
                        // Featured image
                        if (widget.contentData['image'] != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16.r),
                            child: Image.network(
                              widget.contentData['image'],
                              width: double.infinity,
                              height: 200.h,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 200.h,
                                decoration: BoxDecoration(
                                  color: themeProvider.secondaryBackgroundColor,
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Center(
                                  child: Icon(Icons.image_not_supported, 
                                      color: themeProvider.tertiaryTextColor, size: 48.sp),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20.h),
                        ],
                        
                        // Summary
                        SelectableText(
                          widget.contentData['extract'] ?? 'No content available.',
                          style: TextStyle(
                            color: themeProvider.primaryTextColor.withOpacity(0.8),
                            fontSize: 15.sp,
                            height: 1.6,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 24.h),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _toggleLike,
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedFavourite,
                                  color: Colors.white,
                                  size: 14.sp,
                                ),
                                label: Text(isLiked ? _languageService.getUIText('liked') : _languageService.getUIText('like')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLiked ? Colors.red : Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                  padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                                  textStyle: TextStyle(fontSize: 12.sp),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedShare01,
                                  color: Colors.white,
                                  size: 14.sp,
                                ),
                                label: Text(_languageService.getUIText('share')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.secondaryTextColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                  padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                                  textStyle: TextStyle(fontSize: 12.sp),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        
                        // Visit Article button
                        if (widget.contentData['url'] != null && widget.contentData['url'].toString().isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _openWikipediaArticle(widget.contentData['url']),
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedGlobe,
                                color: Colors.white,
                                size: 14.sp,
                              ),
                              label: Text('Visit Wikipedia Article'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                                textStyle: TextStyle(fontSize: 12.sp),
                              ),
                            ),
                          ),
                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      );
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
}

class InfinityProfilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

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
    return false;
  }
}
