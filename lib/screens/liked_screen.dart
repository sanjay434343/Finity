import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:animations/animations.dart';
import '../services/local_database.dart';
import '../services/content_service.dart';
import '../services/language_service.dart';
import '../services/share_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/image_shimmer.dart';
import '../screens/player_screen.dart';

class LikedScreen extends StatefulWidget {
  final bool showBottomNav;
  
  const LikedScreen({super.key, this.showBottomNav = true});

  @override
  State<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends State<LikedScreen> with TickerProviderStateMixin {
  final LocalDatabase _localDatabase = LocalDatabase();
  final ContentService _contentService = ContentService();
  final LanguageService _languageService = LanguageService();
  final ShareService _shareService = ShareService();
  
  List<LikedContent> _allLikedContent = [];
  List<LikedContent> _filteredContent = [];
  bool _isLoading = true;
  ContentType _selectedFilter = ContentType.flow;

  @override
  void initState() {
    super.initState();
    _loadLikedContent();
  }

  Future<void> _loadLikedContent() async {
    setState(() => _isLoading = true);
    
    try {
      final content = await _localDatabase.getAllLikedContent();
      if (mounted) {
        setState(() {
          _allLikedContent = content;
          _filterContent();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading liked content: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterContent() {
    List<LikedContent> filtered = _allLikedContent;
    filtered = filtered.where((item) => item.type == _selectedFilter).toList();

    setState(() {
      _filteredContent = filtered;
    });
  }

  void _setFilter(ContentType filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _filterContent();
  }

  Future<void> _removeLikedContent(LikedContent content) async {
    final success = await _contentService.unlikeContent(content.id);
    if (success) {
      setState(() {
        _allLikedContent.removeWhere((item) => item.id == content.id);
      });
      _filterContent();
    }
  }

  Future<void> _clearAllLiked() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Provider.of<ThemeProvider>(context).isDarkMode 
            ? const Color(0xFF1A1A2E) 
            : Colors.white,
        title: Text(_languageService.getUIText('clear_all_liked')),
        content: Text(_languageService.getUIText('clear_all_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageService.getUIText('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_languageService.getUIText('clear_all'), 
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      final success = await _localDatabase.clearAllLikedContent();
      if (success && mounted) {
        setState(() {
          _allLikedContent.clear();
          _filteredContent.clear();
        });
      }
    }
  }

  void _shareLikedContent(LikedContent content) async {
    try {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      final shareableContent = {
        'title': content.title,
        'extract': content.extract,
        'url': content.contentUrl,
        'image': content.imageUrl,
        'app_name': 'Finity',
        'source': 'Wikipedia',
        'type': content.type == ContentType.flow ? 'Finity Flow' : 'Finity Loops',
        'likes': content.likes,
        'views': content.views,
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
      debugPrint('Error sharing liked content: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content copied to clipboard'),
            backgroundColor: Colors.green,
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
          appBar: AppBar(
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
                  'Hearts',
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
              if (_allLikedContent.isNotEmpty)
                IconButton(
                  onPressed: _clearAllLiked,
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete02,
                    color: Colors.red,
                    size: 22.sp,
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    _buildPillButton(
                      'Flow',
                      Icons.article,
                      ContentType.flow,
                      themeProvider,
                    ),
                    SizedBox(width: 12.w),
                    _buildPillButton(
                      'Loops',
                      Icons.play_circle,
                      ContentType.loop,
                      themeProvider,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildBody(themeProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillButton(String label, IconData icon, ContentType type, ThemeProvider themeProvider) {
    final isSelected = _selectedFilter == type;
    
    final translatedLabel = type == ContentType.flow 
        ? _languageService.getUIText('home')
        : _languageService.getUIText('loops');
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setFilter(type),
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF4A00E0) 
                : themeProvider.isDarkMode 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.grey[100],
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected 
                  ? const Color(0xFF4A00E0) 
                  : themeProvider.isDarkMode 
                      ? Colors.white.withOpacity(0.2) 
                      : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? Colors.white 
                    : themeProvider.primaryTextColor,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                translatedLabel,
                style: TextStyle(
                  color: isSelected 
                      ? Colors.white 
                      : themeProvider.primaryTextColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading) {
      return _buildLoadingState(themeProvider);
    }

    if (_allLikedContent.isEmpty) {
      return _buildEmptyState(themeProvider);
    }

    if (_filteredContent.isEmpty) {
      return _buildNoResultsState(themeProvider);
    }

    return RefreshIndicator(
      onRefresh: _loadLikedContent,
      backgroundColor: themeProvider.primaryBackgroundColor,
      color: const Color(0xFF4A00E0),
      child: _selectedFilter == ContentType.flow
          ? _buildFlowList(themeProvider)
          : _buildLoopsGrid(themeProvider),
    );
  }

  Widget _buildFlowList(ThemeProvider themeProvider) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: _filteredContent.length,
      itemBuilder: (context, index) {
        final content = _filteredContent[index];
        return _buildFlowContentCard(content, themeProvider);
      },
    );
  }

  Widget _buildLoopsGrid(ThemeProvider themeProvider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        itemCount: _filteredContent.length,
        itemBuilder: (context, index) {
          if (index >= _filteredContent.length) {
            return Container();
          }
          final content = _filteredContent[index];
          return _buildLoopGridCard(content, themeProvider);
        },
      ),
    );
  }

  Widget _buildLoadingState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFF4A00E0),
            backgroundColor: themeProvider.secondaryTextColor.withOpacity(0.3),
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
            icon: HugeIcons.strokeRoundedFavourite,
            color: themeProvider.tertiaryTextColor,
            size: 64.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            _selectedFilter == ContentType.flow 
                ? _languageService.getUIText('no_liked_flow_yet') 
                : _languageService.getUIText('no_liked_loops_yet'),
            style: TextStyle(
              color: themeProvider.primaryTextColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
          SizedBox(height: 8.h),
          Text(
            _selectedFilter == ContentType.flow 
                ? _languageService.getUIText('start_liking_flow_content')
                : _languageService.getUIText('start_liking_loops_content'),
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

  Widget _buildNoResultsState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFavourite,
            color: themeProvider.tertiaryTextColor,
            size: 64.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            _selectedFilter == ContentType.flow 
                ? _languageService.getUIText('no_flow_content_found') 
                : _languageService.getUIText('no_loops_content_found'),
            style: TextStyle(
              color: themeProvider.primaryTextColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
          SizedBox(height: 8.h),
          Text(
            _languageService.getUIText('try_switching_tabs'),
            style: TextStyle(
              color: themeProvider.secondaryTextColor,
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowContentCard(LikedContent content, ThemeProvider themeProvider) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
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
        padding: EdgeInsets.all(16.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      painter: InfinityProfilePainter(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      const Spacer(),
                      Text(
                        _formatDate(content.timestamp),
                        style: TextStyle(
                          color: themeProvider.secondaryTextColor,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      IconButton(
                        onPressed: () => _removeLikedContent(content),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedFavourite,
                          color: Colors.red,
                          size: 18.sp,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 32.w,
                          minHeight: 32.h,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  AutoSizeText(
                    content.title,
                    style: TextStyle(
                      color: themeProvider.primaryTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                      height: 1.3,
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 8.h),
                  AutoSizeText(
                    content.extract,
                    style: TextStyle(
                      color: themeProvider.primaryTextColor.withOpacity(0.8),
                      fontSize: 15.sp,
                      height: 1.4,
                    ),
                    maxLines: 4,
                  ),
                  if (content.imageUrl != null) ...[
                    SizedBox(height: 12.h),
                    ImageNetworkWithShimmer(
                      imageUrl: content.imageUrl!,
                      themeProvider: themeProvider,
                      borderRadius: 15,
                    ),
                  ],
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: themeProvider.isDarkMode 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.grey[200]!,
                        width: 0.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _shareLikedContent(content),
                        borderRadius: BorderRadius.circular(8.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedShare08,
                                color: themeProvider.secondaryIconColor,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              AutoSizeText(
                                _languageService.getUIText('share'),
                                style: TextStyle(
                                  color: themeProvider.secondaryTextColor,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoopGridCard(LikedContent content, ThemeProvider themeProvider) {
    const double maxHeight = 300.0;
    const double minHeight = 180.0;
    
    final titleLength = content.title.length;
    final extractLength = content.extract.length;
    final totalLength = titleLength + extractLength;
    
    final calculatedHeight = minHeight + (totalLength * 0.5).clamp(0.0, maxHeight - minHeight);
    final finalHeight = calculatedHeight.clamp(minHeight, maxHeight);

    return OpenContainer<bool>(
      transitionType: ContainerTransitionType.fade,
      transitionDuration: const Duration(milliseconds: 500),
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      middleColor: themeProvider.primaryBackgroundColor,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      closedBuilder: (context, action) => Container(
        height: finalHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: themeProvider.isDarkMode 
                  ? Colors.black.withOpacity(0.3) 
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Stack(
            children: [
              Positioned.fill(
                child: content.imageUrl != null
                    ? Image.network(
                        content.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackBackground(content, themeProvider),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildFallbackBackground(content, themeProvider);
                        },
                      )
                    : _buildFallbackBackground(content, themeProvider),
              ),
              Positioned(
                left: 0, right: 0, bottom: 0,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    _formatDate(content.timestamp),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutoSizeText(
                      content.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),
                    AutoSizeText(
                      content.extract,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11.sp,
                        height: 1.3,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedPlay,
                    color: Colors.white,
                    size: 16.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      openBuilder: (context, action) => PlayerScreen(
        contentData: {
          'id': content.id,
          'title': content.title,
          'extract': content.extract,
          'image': content.imageUrl,
          'url': content.contentUrl,
          'likes': content.likes,
          'views': content.views,
          'type': 'loops_content',
        },
      ),
    );
  }

  Widget _buildFallbackBackground(LikedContent content, ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeProvider.loopsBackgroundColors[0].withOpacity(0.6),
            themeProvider.primaryBackgroundColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.article_outlined,
          color: Colors.white.withOpacity(0.7),
          size: 60.sp,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class InfinityProfilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
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

    final scaleX = size.width / 140;
    final scaleY = size.height / 140;

    final path = Path();

    path.moveTo(125 * scaleX, 70 * scaleY);
    path.cubicTo(
      115 * scaleX, 100 * scaleY,
      85 * scaleX, 100 * scaleY,
      70 * scaleX, 70 * scaleY,
    );
    path.cubicTo(
      55 * scaleX, 40 * scaleY,
      30 * scaleX, 40 * scaleY,
      20 * scaleX, 60 * scaleY,
    );

    path.moveTo(20 * scaleX, 80 * scaleY);
    path.cubicTo(
      30 * scaleX, 100 * scaleY,
      55 * scaleX, 100 * scaleY,
      70 * scaleX, 70 * scaleY,
    );
    path.cubicTo(
      85 * scaleX, 40 * scaleY,
      115 * scaleX, 40 * scaleY,
      125 * scaleX, 70 * scaleY,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}