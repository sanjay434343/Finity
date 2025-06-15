import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import '../services/search_service.dart';
import '../services/search_history_service.dart';
import '../services/language_service.dart';
import '../services/content_service.dart';
import '../services/share_service.dart';
import '../services/local_database.dart';
import '../providers/theme_provider.dart';
import '../widgets/image_shimmer.dart';
import '../screens/player_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool showBottomNav;
  
  const SearchScreen({super.key, this.showBottomNav = true});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final SearchHistoryService _historyService = SearchHistoryService();
  final LanguageService _languageService = LanguageService();
  final ContentService _contentService = ContentService();
  final ShareService _shareService = ShareService();
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _searchHistory = [];
  List<String> _searchSuggestions = [];
  List<String> _trendingSearches = [];
  Map<String, bool> _likedContent = {};
  List<Map<String, dynamic>> _savedContent = [];
  
  bool _isSearching = false;
  bool _showSuggestions = false;
  bool _hasSearched = false;
  String _currentQuery = '';
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _likeController;
  late AnimationController _splashController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  Map<String, bool> _expandedContent = {};
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _splashController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _splashController,
      curve: Curves.linear,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _splashController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _splashController,
      curve: Curves.easeInOut,
    ));
    
    _loadInitialData();
    _setupSearchListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fadeController.dispose();
    _likeController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      final query = _searchController.text;
      if (query != _currentQuery) {
        _currentQuery = query;
        if (query.isNotEmpty) {
          _getSuggestions(query);
          setState(() => _showSuggestions = true);
        } else {
          setState(() {
            _showSuggestions = false;
            _searchSuggestions.clear();
          });
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final history = await _historyService.getSearchHistory();
      final trending = await _searchService.getTrendingSearches();
      final savedContent = await _loadSavedContent();
      
      if (mounted) {
        setState(() {
          _searchHistory = history;
          _trendingSearches = trending;
          _savedContent = savedContent;
        });
      }
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadSavedContent() async {
    try {
      // Create mock saved content for demonstration
      return [
        {
          'id': 'saved_1',
          'title': 'Quantum Physics',
          'extract': 'The study of matter and energy at the smallest scales...',
          'image': 'https://example.com/quantum.jpg',
          'source': 'Wikipedia',
          'type': 'Search Result',
        },
        {
          'id': 'saved_2', 
          'title': 'Climate Change',
          'extract': 'Long-term shifts in global temperatures and weather patterns...',
          'image': null,
          'source': 'Wikipedia',
          'type': 'Search Result',
        },
      ];
    } catch (e) {
      print('Error loading saved content: $e');
      return [];
    }
  }

  Future<void> _getSuggestions(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      final suggestions = await _searchService.getSearchSuggestions(query);
      if (mounted && query == _currentQuery) {
        setState(() => _searchSuggestions = suggestions);
      }
    } catch (e) {
      print('Error getting suggestions: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _showSuggestions = false;
      _hasSearched = true;
    });
    
    _searchFocusNode.unfocus();
    _splashController.repeat();
    
    try {
      // Add to search history
      await _historyService.addSearchTerm(query);
      
      // Perform search
      final results = await _searchService.searchWikipedia(query, limit: 20);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        
        _splashController.stop();
        _fadeController.forward();
        _loadLikedStatus();
        
        // Update history list
        final updatedHistory = await _historyService.getSearchHistory();
        setState(() => _searchHistory = updatedHistory);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _splashController.stop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    _languageService.getUIText('search_error'),
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      }
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> content) async {
    // Better content ID handling to avoid type errors
    String contentId = '';
    if (content['id'] != null) {
      contentId = content['id'].toString();
    } else if (content['pageid'] != null) {
      contentId = content['pageid'].toString();
    } else {
      // Generate a fallback ID based on title
      contentId = (content['title'] ?? 'unknown').toString().replaceAll(' ', '_').toLowerCase();
    }
    
    if (contentId.isEmpty) return;
    
    final isCurrentlyLiked = _likedContent[contentId] ?? false;
    
    // Update UI immediately for better UX
    setState(() {
      _likedContent[contentId] = !isCurrentlyLiked;
    });

    // Trigger like animation
    _likeController.forward().then((_) {
      _likeController.reverse();
    });

    try {
      bool success;
      if (isCurrentlyLiked) {
        success = await _contentService.unlikeContent(contentId);
      } else {
        // Ensure we have proper content structure for saving with consistent ID types
        final contentToSave = {
          'id': contentId, // Use the string version consistently
          'title': content['title']?.toString() ?? 'Unknown Title',
          'extract': content['extract']?.toString() ?? content['description']?.toString() ?? '',
          'image': content['image']?.toString(),
          'source': 'Wikipedia',
          'type': 'Search Result',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'language': _languageService.currentLanguageCode,
          'pageid': content['pageid']?.toString(), // Ensure pageid is also string
          'url': content['url']?.toString(),
          'fullurl': content['fullurl']?.toString(),
        };
        success = await _contentService.likeContent(contentToSave, ContentType.flow);
      }

      // Revert if operation failed
      if (!success) {
        setState(() {
          _likedContent[contentId] = isCurrentlyLiked;
        });
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    isCurrentlyLiked ? 'Failed to unlike' : 'Failed to like',
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
          );
        }
      } else {
        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isCurrentlyLiked ? Icons.heart_broken : Icons.favorite,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    isCurrentlyLiked ? 'Removed from favorites' : 'Added to favorites',
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ],
              ),
              backgroundColor: isCurrentlyLiked ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _likedContent[contentId] = isCurrentlyLiked;
      });
      
      debugPrint('Error toggling like: $e');
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'Something went wrong. Please try again.',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      }
    }
  }

  Future<void> _loadLikedStatus() async {
    final Map<String, bool> status = {};
    for (final result in _searchResults) {
      // Consistent ID handling here too
      String contentId = '';
      if (result['id'] != null) {
        contentId = result['id'].toString();
      } else if (result['pageid'] != null) {
        contentId = result['pageid'].toString();
      } else {
        contentId = (result['title'] ?? 'unknown').toString().replaceAll(' ', '_').toLowerCase();
      }
      
      if (contentId.isNotEmpty) {
        status[contentId] = await _contentService.isContentLiked(contentId);
      }
    }
    if (mounted) setState(() => _likedContent = status);
  }

  Future<void> _shareContent(Map<String, dynamic> content) async {
    try {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      final shareableContent = {
        ...content,
        'app_name': 'Finity',
        'source': 'Wikipedia',
        'type': 'Search Result',
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

  // Update the method to open in player instead of loops
  void _openInPlayer(Map<String, dynamic> content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          contentData: content,
        ),
      ),
    );
  }

  Widget _buildHistoryChips(ThemeProvider themeProvider) {
    return Column(
      children: _searchHistory.take(8).map((term) {
        final index = _searchHistory.indexOf(term);
        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _searchController.text = term;
                _performSearch(term);
              },
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
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
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTime04,
                      color: themeProvider.secondaryIconColor,
                      size: 18.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        term,
                        style: TextStyle(
                          color: themeProvider.primaryTextColor,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _deleteSearchTerm(term),
                      child: Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete02,
                          color: themeProvider.secondaryIconColor,
                          size: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _deleteSearchTerm(String term) async {
    try {
      await _historyService.removeSearchTerm(term);
      final updatedHistory = await _historyService.getSearchHistory();
      if (mounted) {
        setState(() => _searchHistory = updatedHistory);
      }
    } catch (e) {
      print('Error deleting search term: $e');
    }
  }

  Future<void> _clearAllSearchHistory() async {
    try {
      await _historyService.clearSearchHistory();
      if (mounted) {
        setState(() => _searchHistory.clear());
      }
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }

  Widget _buildTrendingChips(ThemeProvider themeProvider) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: _trendingSearches.map((term) => GestureDetector(
        onTap: () {
          _searchController.text = term;
          _performSearch(term);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF4A00E0)],
            ),
            borderRadius: BorderRadius.circular(20.r),
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
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowUpRight01,
                color: Colors.white,
                size: 14.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                term,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          backgroundColor: themeProvider.primaryBackgroundColor,
          appBar: _buildAppBar(themeProvider),
          body: Column(
            children: [
              _buildSearchBar(themeProvider),
              Expanded(
                child: Stack(
                  children: [
                    if (_isSearching)
                      _buildLoadingState(themeProvider)
                    else if (_showSuggestions && _searchSuggestions.isNotEmpty)
                      _buildSuggestionsView(themeProvider)
                    else if (_hasSearched && _searchResults.isNotEmpty)
                      _buildSearchResults(themeProvider)
                    else if (_hasSearched && _searchResults.isEmpty)
                      _buildNoResultsState(themeProvider)
                    else
                      _buildInitialState(themeProvider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeProvider themeProvider) {
    return AppBar(
      backgroundColor: themeProvider.primaryBackgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 60.h,
      title: Text(
        'Finity Search',
        style: TextStyle(
          color: themeProvider.primaryTextColor,
          fontSize: 24.sp,
          fontWeight: FontWeight.bold,
          fontFamily: 'Blinka',
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(right: 16.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4A00E0).withOpacity(0.1),
                const Color(0xFF00C6FF).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(
              color: const Color(0xFF4A00E0).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _languageService.currentLanguageFlag,
                style: TextStyle(fontSize: 16.sp),
              ),
              SizedBox(width: 6.w),
              Text(
                _languageService.currentLanguageCode.toUpperCase(),
                style: TextStyle(
                  color: const Color(0xFF4A00E0),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeProvider themeProvider) {
    return Container(
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.r),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode 
              ? Colors.white.withOpacity(0.1) 
              : Colors.white,
          borderRadius: BorderRadius.circular(25.r),
          border: Border.all(
            color: themeProvider.isDarkMode 
                ? Colors.white.withOpacity(0.2) 
                : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: TextStyle(
            color: themeProvider.primaryTextColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: _languageService.getUIText('search_hint') ?? 'Search Wikipedia...',
            hintStyle: TextStyle(
              color: themeProvider.secondaryTextColor,
              fontSize: 16.sp,
            ),
            prefixIcon: Container(
              padding: EdgeInsets.all(12.w),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: const Color(0xFF4A00E0),
                size: 22.sp,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _showSuggestions = false;
                        _searchSuggestions.clear();
                        _searchResults.clear();
                        _hasSearched = false;
                      });
                    },
                    icon: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: themeProvider.secondaryIconColor,
                        size: 16.sp,
                      ),
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12.h),
          ),
          onSubmitted: _performSearch,
          textInputAction: TextInputAction.search,
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _splashController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(120.w, 120.h),
                painter: SplashInfinityPainter(_splashController.value),
              );
            },
          ),
          SizedBox(height: 16.h),
          Text(
            'Searching...',
            style: TextStyle(
              color: themeProvider.secondaryTextColor,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsView(ThemeProvider themeProvider) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _searchSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _searchSuggestions[index];
        return ListTile(
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: themeProvider.secondaryIconColor,
            size: 20.sp,
          ),
          title: Text(
            suggestion,
            style: TextStyle(
              color: themeProvider.primaryTextColor,
              fontSize: 16.sp,
            ),
          ),
          onTap: () {
            _searchController.text = suggestion;
            _performSearch(suggestion);
          },
        );
      },
    );
  }

  Widget _buildSearchResults(ThemeProvider themeProvider) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final result = _searchResults[index];
          return _buildSearchResultItem(result, themeProvider, index);
        },
      ),
    );
  }

  // Enhanced search result item with home page styling
  Widget _buildSearchResultItem(Map<String, dynamic> result, ThemeProvider themeProvider, int index) {
    // Consistent ID handling in UI as well
    String contentId = '';
    if (result['id'] != null) {
      contentId = result['id'].toString();
    } else if (result['pageid'] != null) {
      contentId = result['pageid'].toString();
    } else {
      contentId = (result['title'] ?? 'unknown').toString().replaceAll(' ', '_').toLowerCase();
    }
    
    final isLiked = _likedContent[contentId] ?? false;
    final isExpanded = _expandedContent[contentId] ?? false;
    final extract = result['extract'] ?? 'No description available.';
    final shouldShowReadMore = extract.length > 200; // Show read more if content is longer than 200 characters
    
    return Container(
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
            // Profile section (exactly like home page)
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
                      painter: SearchInfinityProfilePainter(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12.w),
            
            // Content section (exactly like home page)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row exactly like home page
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
                        child: Text(
                          'Finity Flow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
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
                      // Like button exactly like home page
                      GestureDetector(
                        onTap: () => _toggleLike(result),
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
                  
                  // Title (same styling as home page)
                  Text(
                    result['title'] ?? 'Unknown Title',
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
                      Text(
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
                  
                  // Featured image (same styling as home page)
                  if (result['image'] != null) ...[
                    SizedBox(height: 12.h),
                    AdaptiveImageWidget(
                      imageUrl: result['image'],
                      themeProvider: themeProvider,
                      borderRadius: 15,
                      enableZoom: true,
                    ),
                  ],
                  
                  SizedBox(height: 16.h),
                  
                  // Action buttons row (exactly like home page)
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
                    child: Row(
                      children: [
                        // Share button
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _shareContent(result),
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
                                    Text(
                                      _languageService.getUIText('share') ?? 'Share',
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
                        
                        // Divider
                        Container(
                          width: 1,
                          height: 20.h,
                          color: themeProvider.isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey[300],
                        ),
                        
                        // Play button
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openInPlayer(result),
                              borderRadius: BorderRadius.circular(8.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedPlay,
                                      color: Colors.orange,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Play',
                                      style: TextStyle(
                                        color: Colors.orange,
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
                      ],
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                color: color,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  color: color,
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

  Widget _buildNoResultsState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearchRemove,
            color: themeProvider.tertiaryTextColor,
            size: 64.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            _languageService.getUIText('no_results'),
            style: TextStyle(
              color: themeProvider.primaryTextColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _languageService.getUIText('search_try_different'),
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

  Widget _buildInitialState(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchHistory.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    color: themeProvider.primaryTextColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: _clearAllSearchHistory,
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: const Color(0xFF4A00E0),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildHistoryChips(themeProvider),
            SizedBox(height: 32.h),
          ],
          
          // Enhanced empty state when no history
          if (_searchHistory.isEmpty) ...[
            SizedBox(height: 100.h),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.grey[50],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF4A00E0).withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      color: const Color(0xFF4A00E0),
                      size: 32.sp,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'Discover Wikipedia',
                    style: TextStyle(
                      color: themeProvider.primaryTextColor,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    child: Text(
                      'Search for any topic and explore infinite knowledge',
                      style: TextStyle(
                        color: themeProvider.secondaryTextColor,
                        fontSize: 16.sp,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SearchInfinityProfilePainter extends CustomPainter {
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

class SplashInfinityPainter extends CustomPainter {
  final double animationValue;

  SplashInfinityPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
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
    final pathLength = pathMetric.length;
    
    final drawLength = pathLength * animationValue;
    final animatedPath = pathMetric.extractPath(0, drawLength);

    canvas.drawPath(animatedPath, paint);
    
    if (animationValue > 0 && animationValue < 1) {
      final currentPoint = pathMetric.getTangentForOffset(drawLength)?.position;
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
