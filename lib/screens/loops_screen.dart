import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'dart:async'; // Add this import for Timer
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/content_service.dart';
import '../services/local_database.dart';
import '../widgets/custom_bottom_nav.dart';
import '../providers/theme_provider.dart';
import '../services/language_service.dart';
import '../services/music_service.dart';
import '../services/share_service.dart';

class LoopsScreen extends StatefulWidget {
  final bool showBottomNav;
  final Map<String, dynamic>? arguments;
  final bool refreshContent; // Add this parameter
  
  const LoopsScreen({
    super.key, 
    this.showBottomNav = true, 
    this.arguments,
    this.refreshContent = false, // Default to false
  });

  @override
  State<LoopsScreen> createState() => _LoopsScreenState();
}

class _LoopsScreenState extends State<LoopsScreen> with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  // Remove old audio player related variables
  final ContentService _contentService = ContentService();
  final LanguageService _languageService = LanguageService();
  final MusicService _musicService = MusicService(); // Add music service
  final ShareService _shareService = ShareService();

  Map<String, bool> likedContent = {};
  List<Map<String, dynamic>> loops = [];
  int currentIndex = 0;
  bool isLoadingMore = false;
  late PageController _pageController;

  // Remove old music related variables - now handled by MusicService
  bool _showMuteIcon = false;
  AnimationController? _muteIconController;
  Animation<double>? _muteIconAnimation;

  // Separate animation controller for loading
  AnimationController? _loadingController;
  Animation<double>? _loadingAnimation;
  Animation<double>? _colorAnimation;
  bool _isDrawingComplete = false;

  final List<String> musicSearchTerms = [
    'ambient', 'piano', 'classical piano', 'meditation', 'study music',
    'nature sounds', 'cafe music', 'focus music', 'calm music',
    'peaceful', 'minimal', 'downtempo', 'atmospheric', 'spa music'
  ];

  // Flag to indicate if specific content is being shown
  bool _isShowingSpecificContent = false;
  Map<String, dynamic>? _specificContentData;

  // Add loading state for content generation
  bool isGeneratingContent = false;
  bool hasInitialContent = false;

  // Add these new variables for better focus management
  bool _isPageInFocus = true;
  bool _wasMusicPlayingBeforeUnfocus = false;
  bool _hasNavigatedAway = false;

  // Add route observer reference
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  // Add flag to track if content was loaded in this session
  bool _contentLoadedInThisSession = false;

  // Add flag to prevent multiple loads
  bool _isInitialLoadComplete = false;
  
  // Add ultra-fast loading variables
  bool _isPreloadingNextBatch = false;
  static const int _batchSize = 15; // Increased batch size
  static const int _maxCacheSize = 100; // Keep more items in memory
  
  // Background loading timer
  Timer? _backgroundLoadTimer;
  
  // Update these variables for better continuous loading
  static const int _initialLoadCount = 20; // Load 20 initially
  static const int _loadMoreCount = 10; // Load 10 more each time
  static const int _preloadTrigger = 7; // Start loading when 7 items left
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Initialize mute icon controller
    _muteIconController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _muteIconAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _muteIconController!, curve: Curves.easeInOut));
    
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
    
    // Initialize music service
    _initializeMusicService();
    
    // Start ultra-fast loading immediately
    _loadContentUltraFast();
    
    WidgetsBinding.instance.addObserver(this);
    
    // Start background loading timer
    _startBackgroundLoading();
    
    // Listen to language changes
    _languageService.addListener(_onLanguageChanged);
  }

  // Add music service initialization
  Future<void> _initializeMusicService() async {
    try {
      await _musicService.initialize();
      print('LoopsScreen: MusicService initialized');
    } catch (e) {
      print('LoopsScreen: Error initializing MusicService: $e');
    }
  }

  void _onLanguageChanged() {
    // Refresh content when language changes
    if (mounted) {
      setState(() => _contentLoadedInThisSession = false);
      _loadFreshContentOnEntry();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Register this screen with the route observer for navigation detection
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
    
    // Check for arguments passed from navigation
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args['showSpecificContent'] == true) {
        final contentData = args['contentData'] as Map<String, dynamic>;
        _showSpecificContent(contentData);
      } else if (args['refreshContent'] == true) {
        _loadFreshContentOnEntry();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        _musicService.pauseMusic();
        break;
      case AppLifecycleState.inactive:
        // Don't stop music when notification panel is pulled down
        // This state happens when notification panel is shown
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _handlePageUnfocus();
        break;
      case AppLifecycleState.resumed:
        if (_isPageInFocus && !_hasNavigatedAway && !_musicService.isMuted) {
          _musicService.resumeMusic();
        }
        break;
    }
  }

  // Add RouteAware methods to detect navigation
  @override
  void didPopNext() {
    // Called when returning to this screen from another screen
    super.didPopNext();
    _hasNavigatedAway = false;
    _handlePageFocus();
    
    // Only load fresh content if explicitly requested
    if (widget.refreshContent && !_isShowingSpecificContent) {
      setState(() => _contentLoadedInThisSession = false);
      _loadFreshContentOnEntry();
    }
  }

  @override
  void didPushNext() {
    // Called when navigating away from this screen to another screen
    super.didPushNext();
    _hasNavigatedAway = true;
    _handlePageUnfocus();
    
    // Stop music when navigating away
    _musicService.stopMusic();
  }

  @override
  void didPop() {
    // Called when this screen is popped
    super.didPop();
    _hasNavigatedAway = true;
    _handlePageUnfocus();
    
    // Stop music when screen is popped
    _musicService.stopMusic();
  }

  @override
  void didPush() {
    // Called when this screen is pushed
    super.didPush();
    _hasNavigatedAway = false;
    _handlePageFocus();
  }

  // Add method to load fresh content when entering the screen
  Future<void> _loadFreshContentOnEntry() async {
    if (isGeneratingContent || (_contentLoadedInThisSession && !widget.refreshContent)) return;
    
    setState(() {
      isGeneratingContent = true;
      loops.clear();
      currentIndex = 0;
      _contentLoadedInThisSession = true;
      _isInitialLoadComplete = true;
    });

    // Start the loading animation
    _loadingController?.repeat();

    try {
      // Clear existing cache completely
      _contentService.clearLoopsCache();
      _musicService.clearMusicCache();
      _musicService.clearContentMusicMappings(); // Clear content-music mappings
      
      // Load fresh music and content
      await _loadMusicCache();
      final articles = await _contentService.getLoopsContent(count: 10, forceRefresh: true);
      
      if (mounted) {
        setState(() {
          loops = articles.map((article) => {
            ...article,
            'backgroundColor': Colors.primaries[Random().nextInt(Colors.primaries.length)],
          }).toList();
          hasInitialContent = true;
          isGeneratingContent = false;
        });
        
        // Stop the loading animation
        _loadingController?.stop();
        _loadingController?.reset();
        
        _loadLikedStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isGeneratingContent = false;
        });
        // Stop the loading animation on error too
        _loadingController?.stop();
        _loadingController?.reset();
      }
    }
  }

  // Add method to clear content when exiting the screen
  void _clearContentOnExit() {
    if (mounted) {
      // Clear all content and cache
      _contentService.clearLoopsCache();
      _musicService.clearMusicCache();
      _musicService.clearContentMusicMappings(); // Clear content-music mappings
      
      setState(() {
        loops.clear();
        currentIndex = 0;
        hasInitialContent = false;
        _contentLoadedInThisSession = false;
      });
      
      print('Content cache cleared on exit');
    }
  }

  // Remove the old _generateAndCacheNewContent method and replace it
  Future<void> _generateAndCacheNewContent() async {
    await _loadFreshContentOnEntry();
  }

  void _loadInitialContent() async {
    // This method is now handled by _loadFreshContentOnEntry
    if (!_contentLoadedInThisSession && !hasInitialContent) {
      _loadFreshContentOnEntry();
    }
  }

  // Add these new music control methods
  void _pauseMusic() async {
    try {
      await _musicService.pauseMusic();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error pausing music: $e');
    }
  }

  void _resumeMusic() async {
    try {
      await _musicService.resumeMusic();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error resuming music: $e');
    }
  }

  void _stopMusic() async {
    try {
      await _musicService.stopMusic();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error stopping music: $e');
    }
  }

  // Add a force stop method for dispose
  void _forceStopMusic() async {
    try {
      await _musicService.stopMusic();
    } catch (e) {
      print('Error force stopping music: $e');
    }
  }

  void _playSpecificMusic(String musicUrl) async {
    // Only play if page is in focus, not muted, mounted, and hasn't navigated away
    if (!mounted || _hasNavigatedAway) return;
    
    try {
      await _musicService.playMusic(musicUrl);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _playMusicForContent(String contentId, String contentTitle) async {
    // Only play music if page is in focus, not muted, and hasn't navigated away
    if (mounted && _isPageInFocus && !_hasNavigatedAway) {
      try {
        // Get a specific song for this content and play it on repeat
        await _musicService.playMusicForContentOnRepeat(contentId, contentTitle);
        setState(() {});
      } catch (e) {
        print('Error playing music for content: $e');
      }
    }
  }

  // Add these new methods for handling page focus changes
  void _handlePageUnfocus() {
    if (!mounted) return;
    
    setState(() => _isPageInFocus = false);
    
    // Pause music when unfocusing the page
    _musicService.pauseMusic();
  }

  void _handlePageFocus() {
    if (!mounted) return;
    
    setState(() => _isPageInFocus = true);
    
    // Resume music if it was playing before losing focus and not muted
    if (_wasMusicPlayingBeforeUnfocus && !_musicService.isMuted && loops.isNotEmpty && currentIndex < loops.length && !_hasNavigatedAway) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isPageInFocus && !_hasNavigatedAway) {
          final currentLoop = loops[currentIndex];
          final contentId = _generateContentId(currentLoop);
          _playMusicForContent(contentId, currentLoop['title'] ?? 'Unknown');
        }
      });
    }
    
    // Reset the flag only if we're actually back on this screen
    if (!_hasNavigatedAway) {
      _wasMusicPlayingBeforeUnfocus = false;
    }
  }

  @override
  void dispose() {
    // Cancel background loading timer
    _backgroundLoadTimer?.cancel();
    // Unsubscribe from route observer
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    
    // Dispose music service
    _musicService.dispose();
    
    // Clear all content on dispose
    _clearContentOnExit();
    
    _pageController.dispose();
    _muteIconController?.dispose();
    _loadingController?.dispose();
    _languageService.removeListener(_onLanguageChanged);
    super.dispose();
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

  String _generateContentId(Map<String, dynamic> loop) {
    String title = loop['title'] ?? 'unknown';
    return 'content_${title.hashCode.abs()}';
  }

  void _showSpecificContent(Map<String, dynamic> contentData) {
    // Clear existing loops and show only the specific content
    setState(() {
      _isShowingSpecificContent = true;
      _specificContentData = contentData;
      loops.clear(); // Clear all existing content
      loops.add({
        ...contentData,
        'backgroundColor': Colors.primaries[0],
      });
      currentIndex = 0;
    });
    
    // Play music for this content if available
    final contentId = _generateContentId(contentData);
    _playMusicForContent(contentId, contentData['title'] ?? 'Unknown');
    
    // Schedule snack bar to show after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.play_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Now playing: ${contentData['title'] ?? 'Unknown'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _exitSpecificContentMode();
                  },
                  child: Text(
                    'Exit',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4A00E0),
            duration: const Duration(seconds: 10), // Show longer
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });
  }

  void _exitSpecificContentMode() {
    setState(() {
      _isShowingSpecificContent = false;
      _specificContentData = null;
      loops.clear();
      currentIndex = 0;
      _contentLoadedInThisSession = false;
    });
    
    // Load fresh content when exiting specific content mode
    _loadFreshContentOnEntry();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Returned to fresh loops'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadMusicCache() async {
     if (_musicService.isLoadingMusic) return;
     setState(() => _musicService.isLoadingMusic = true);
     
     try {
       while (_musicService.musicCache.length < 15 && mounted) {
         final randomTerm = musicSearchTerms[Random().nextInt(musicSearchTerms.length)];
         final url = await _fetchAppleMusicByTerm(randomTerm);
         if (url != null && !_musicService.musicCache.contains(url)) {
           _musicService.musicCache.add(url);
         }
         await Future.delayed(const Duration(milliseconds: 200));
       }
     } catch (e) {
       print('Error loading music cache: $e');
     } finally {
       if (mounted) setState(() => _musicService.isLoadingMusic = false);
     }
   }

  String? _getNextCachedMusic() {
    if (_musicService.musicCache.isEmpty) return null;
    _musicService.currentMusicIndex = (_musicService.currentMusicIndex + 1) % _musicService.musicCache.length;
    return _musicService.musicCache[_musicService.currentMusicIndex];
  }

  Future<String?> _fetchAppleMusicByTerm(String searchTerm) async {
    try {
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(searchTerm)}&media=music&limit=5&explicit=no'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final results = data['results'] as List;
          final randomResult = results[Random().nextInt(results.length)];
          return randomResult['previewUrl'];
        }
      }
    } catch (e) {
      print('Error fetching music: $e');
    }
    return null;
  }

  Future<void> _loadWikipediaReels() async {
    try {
      final articles = await _contentService.getLoopsContent(count: 8);
      
      if (mounted) {
        setState(() {
          loops = articles.map((article) => {
            ...article,
            'backgroundColor': Colors.primaries[loops.length % Colors.primaries.length],
          }).toList();
          hasInitialContent = true;
        });
        _loadLikedStatus();
        _loadMoreLoops();
      }
    } catch (e) {
      print('Error loading reels: $e');
    }
  }

  Future<void> _loadMoreLoops() async {
    // Don't load more loops if showing specific content or already loading
    if (_isShowingSpecificContent || isLoadingMore || isGeneratingContent) return;
    
    print('Loading more loops. Current count: ${loops.length}');
    setState(() => isLoadingMore = true);

    try {
      // Get more content from service
      final moreContent = await _contentService.loadMoreLoopsContent(
        count: loops.length + _loadMoreCount, 
        forceRefresh: false
      );
      
      if (moreContent.length > loops.length && mounted) {
        // Add only new content
        final newLoops = moreContent.skip(loops.length).map((article) => {
          ...article,
          'backgroundColor': Colors.primaries[Random().nextInt(Colors.primaries.length)],
        }).toList();
        
        setState(() {
          loops.addAll(newLoops);
          isLoadingMore = false;
        });
        
        print('Added ${newLoops.length} new loops. Total: ${loops.length}');
        _loadLikedStatus();
        
        // Keep cache manageable
        if (loops.length > _maxCacheSize) {
          setState(() {
            loops = loops.take(_maxCacheSize).toList();
            if (currentIndex >= loops.length) {
              currentIndex = loops.length - 1;
            }
          });
        }
      } else {
        setState(() => isLoadingMore = false);
      }
    } catch (e) {
      print('Error loading more loops: $e');
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  // Preload more content aggressively
  void _preloadMoreContent() async {
    if (_isPreloadingNextBatch || isGeneratingContent || _isShowingSpecificContent || isLoadingMore) return;
    
    print('Preloading more content. Current count: ${loops.length}');
    _isPreloadingNextBatch = true;
    
    try {
      final targetCount = loops.length + _loadMoreCount;
      final newContent = await _contentService.loadMoreLoopsContent(
        count: targetCount, 
        forceRefresh: false
      );
      
      if (mounted && newContent.length > loops.length) {
        final newLoops = newContent.skip(loops.length).map((article) => {
          ...article,
          'backgroundColor': Colors.primaries[Random().nextInt(Colors.primaries.length)],
        }).toList();
        
        setState(() {
          loops.addAll(newLoops);
          
          // Keep cache size manageable
          if (loops.length > _maxCacheSize) {
            loops = loops.take(_maxCacheSize).toList();
            if (currentIndex >= loops.length) {
              currentIndex = loops.length - 1;
            }
          }
        });
        
        print('Preloaded ${newLoops.length} loops. Total: ${loops.length}');
        _loadLikedStatus();
      }
    } catch (e) {
      print('Error preloading content: $e');
    } finally {
      _isPreloadingNextBatch = false;
    }
  }

  // Ultra-fast content loading
  Future<void> _loadContentUltraFast() async {
    if (isGeneratingContent) return;
    
    setState(() {
      isGeneratingContent = true;
      _loadingController?.repeat();
    });

    try {
      // Load initial batch with specific count
      final articles = await _contentService.getLoopsContent(
        count: _initialLoadCount, 
        forceRefresh: true
      );
      
      if (mounted && articles.isNotEmpty) {
        setState(() {
          loops = articles.map((article) => {
            ...article,
            'backgroundColor': Colors.primaries[Random().nextInt(Colors.primaries.length)],
          }).toList();
          hasInitialContent = true;
          isGeneratingContent = false;
          _contentLoadedInThisSession = true;
          _isInitialLoadComplete = true;
        });
        
        _loadingController?.stop();
        _loadingController?.reset();
        _loadLikedStatus();
        
        // Start music immediately
        if (loops.isNotEmpty) {
          _startMusicForCurrentContent();
        }
        
        // Preload more content in background
        Future.delayed(const Duration(milliseconds: 500), () {
          _preloadMoreContent();
        });
      }
    } catch (e) {
      print('Error in ultra-fast loading: $e');
      if (mounted) {
        setState(() {
          isGeneratingContent = false;
        });
        _loadingController?.stop();
        _loadingController?.reset();
      }
    }
  }

  // Load cached content first for instant display
  Future<List<Map<String, dynamic>>> _loadCachedContentFirst() async {
    try {
      // Check if we have valid cached content
      final cacheInfo = _contentService.getCacheInfo();
      if (cacheInfo['loops_cache_valid'] == true && cacheInfo['loops_cache_size'] > 0) {
        final content = await _contentService.getLoopsContent(count: _batchSize, forceRefresh: false);
        if (content.isNotEmpty) {
          return content.map((article) => {
            ...article,
            'backgroundColor': Colors.primaries[Random().nextInt(Colors.primaries.length)],
          }).toList();
        }
      }
    } catch (e) {
      print('Error loading cached content: $e');
    }
    return [];
  }

  // Load fresh content super fast
  Future<void> _loadFreshContentFast() async {
    setState(() {
      isGeneratingContent = true;
      loops.clear();
      currentIndex = 0;
      _contentLoadedInThisSession = true;
      _isInitialLoadComplete = true;
    });

    try {
      // Load music cache in parallel (non-blocking)
      _loadMusicCacheFast();
      
      // Get fresh content with timeout for speed
      final articles = await _contentService.getLoopsContent(
        count: _batchSize, 
        forceRefresh: true
      ).timeout(
        const Duration(seconds: 5), // Max 5 seconds wait
        onTimeout: () {
          // Fallback to cached content on timeout
          return _contentService.getLoopsContent(count: _batchSize, forceRefresh: false);
        },
      );
      
      if (mounted && articles.isNotEmpty) {
        setState(() {
          loops = articles.map((article) => {
            ...article,
            'backgroundColor': Colors.primaries[Random().nextInt(Colors.primaries.length)],
          }).toList();
          hasInitialContent = true;
          isGeneratingContent = false;
        });
        
        _loadingController?.stop();
        _loadingController?.reset();
        _loadLikedStatus();
        
        // Start music immediately
        _startMusicForCurrentContent();
      }
    } catch (e) {
      print('Error in fast loading: $e');
      if (mounted) {
        setState(() {
          isGeneratingContent = false;
        });
        _loadingController?.stop();
        _loadingController?.reset();
      }
    }
  }

  // Load fresh content in background without blocking UI
  void _loadFreshContentInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      try {
        final freshContent = await _contentService.getLoopsContent(
          count: _batchSize, 
          forceRefresh: true
        );
        
        if (mounted && freshContent.isNotEmpty) {
          // Replace content smoothly
          final newLoops = freshContent.map((article) => {
            ...article,
            'backgroundColor': Colors.primaries[Random().nextInt(Colors.primaries.length)],
          }).toList();
          
          setState(() {
            loops = newLoops;
          });
          
          _loadLikedStatus();
        }
      } catch (e) {
        print('Error loading fresh content in background: $e');
      }
    });
  }

  // Start background loading timer for continuous content refresh
  void _startBackgroundLoading() {
    _backgroundLoadTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !isGeneratingContent) {
        _preloadMoreContent();
      }
    });
  }

  // Fast music cache loading (non-blocking)
  void _loadMusicCacheFast() {
    if (_musicService.isLoadingMusic) return;
    
    // Don't block UI for music loading
    Future.microtask(() async {
      setState(() => _musicService.isLoadingMusic = true);
      
      try {
        // Load fewer tracks initially for speed
        while (_musicService.musicCache.length < 5 && mounted) {
          final randomTerm = musicSearchTerms[Random().nextInt(musicSearchTerms.length)];
          final url = await _fetchAppleMusicByTerm(randomTerm);
          if (url != null && !_musicService.musicCache.contains(url)) {
            _musicService.musicCache.add(url);
            
            // Start playing immediately when we get first track
            if (_musicService.musicCache.length == 1 && !_musicService.isMuted && loops.isNotEmpty) {
              _startMusicForCurrentContent();
            }
          }
          await Future.delayed(const Duration(milliseconds: 50)); // Faster loading
        }
        
        // Continue loading more in background
        _loadMoreMusicInBackground();
      } catch (e) {
        print('Error loading music cache fast: $e');
      } finally {
        if (mounted) setState(() => _musicService.isLoadingMusic = false);
      }
    });
  }

  // Load more music in background
  void _loadMoreMusicInBackground() {
    Future.delayed(const Duration(milliseconds: 200), () async {
      while (_musicService.musicCache.length < 15 && mounted) {
        try {
          final randomTerm = musicSearchTerms[Random().nextInt(musicSearchTerms.length)];
          final url = await _fetchAppleMusicByTerm(randomTerm);
          if (url != null && !_musicService.musicCache.contains(url)) {
            _musicService.musicCache.add(url);
          }
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('Error loading background music: $e');
          break;
        }
      }
    });
  }

  // Start music for current content immediately
  void _startMusicForCurrentContent() {
    if (loops.isNotEmpty && currentIndex < loops.length) {
      final currentLoop = loops[currentIndex];
      final contentId = _generateContentId(currentLoop);
      _musicService.playMusicForContentOnRepeat(contentId, currentLoop['title'] ?? 'Unknown');
    }
  }

  // Optimized page change handler
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
              if (isGeneratingContent)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeProvider.secondaryBackgroundColor, themeProvider.primaryBackgroundColor],
                    ),
                  ),
                  child: Center(
                    child: AnimatedBuilder(
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
                  ),
                )
              else if (loops.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeProvider.secondaryBackgroundColor, themeProvider.primaryBackgroundColor],
                    ),
                  ),
                  child: Center(
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
                          _languageService.getUIText('loading_ultra_fast_content'),
                          style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 16.sp)
                        ),
                      ],
                    ),
                  ),
                )
              else
                Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: loops.length,
                      onPageChanged: (index) {
                        if (mounted) {
                          setState(() => currentIndex = index);
                          
                          print('Page changed to index: $index of ${loops.length}');
                          
                          // Check if we need to load more content
                          final remaining = loops.length - index;
                          print('Remaining loops: $remaining');
                          
                          if (remaining <= _preloadTrigger && !isLoadingMore && !_isPreloadingNextBatch) {
                            print('Triggering load more content');
                            _loadMoreLoops();
                          }
                          
                          // Start music for new content
                          if (_isPageInFocus && !_hasNavigatedAway && loops.isNotEmpty && index < loops.length) {
                            final currentLoop = loops[index];
                            final contentId = _generateContentId(currentLoop);
                            _musicService.playMusicForContentOnRepeat(contentId, currentLoop['title'] ?? 'Unknown');
                          }
                        }
                      },
                      itemBuilder: (context, index) {
                        final loop = loops[index];
                        
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Background
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    themeProvider.loopsBackgroundColors[index % themeProvider.loopsBackgroundColors.length].withOpacity(0.3),
                                    themeProvider.primaryBackgroundColor.withOpacity(0.9),
                                  ],
                                ),
                              ),
                            ),

                            // Main content with faster image loading
                            GestureDetector(
                              onTap: () => _showContentBottomSheet(loop, themeProvider),
                              child: SizedBox(
                                width: double.infinity,
                                height: double.infinity,
                                child: loop['image'] != null
                                    ? Image.network(
                                        loop['image'],
                                        fit: BoxFit.cover,
                                        headers: {
                                          'Cache-Control': 'max-age=86400',
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return _buildFallbackContent(loop, themeProvider);
                                        },
                                        errorBuilder: (_, __, ___) => _buildFallbackContent(loop, themeProvider),
                                      )
                                    : _buildFallbackContent(loop, themeProvider),
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
                                    icon: (likedContent[loop['id'] ?? ''] ?? false) 
                                        ? HugeIcons.strokeRoundedFavourite 
                                        : HugeIcons.strokeRoundedFavourite,
                                    color: (likedContent[loop['id'] ?? ''] ?? false) ? Colors.red : themeProvider.primaryIconColor,
                                    label: _languageService.getUIText('like'),
                                    onTap: () => _toggleLike(loop),
                                    themeProvider: themeProvider,
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildActionButton(
                                    icon: HugeIcons.strokeRoundedShare01,
                                    color: themeProvider.primaryIconColor,
                                    label: _languageService.getUIText('share'),
                                    onTap: () => _shareLoopContent(loop),
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
                                        'Finity Loops',
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
                                    loop['title'] ?? 'Unknown Title',
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
                                    loop['extract'] ?? 'Tap to explore more content',
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
                                            '${loop['views'] ?? '0'} views',
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
                                      
                                      // Music status with loading indicator - SIMPLIFIED
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_musicService.isLoadingMusic)
                                            SizedBox(
                                              width: 16.sp,
                                              height: 16.sp,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                              ),
                                            )
                                          else
                                            Icon(
                                              _musicService.isMuted 
                                                  ? Icons.volume_off 
                                                  : _musicService.isPlaying 
                                                      ? Icons.music_note 
                                                      : Icons.music_off,
                                              color: _musicService.isMuted
                                                  ? Colors.grey
                                                  : _musicService.isPlaying 
                                                      ? Colors.green 
                                                      : themeProvider.secondaryTextColor,
                                              size: 16.sp,
                                            ),
                                        ],
                                      ),
                                      
                                      SizedBox(width: 12.w),
                                      
                                      // View More button with text
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _showContentBottomSheet(loop, themeProvider),
                                          borderRadius: BorderRadius.circular(16.r),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: themeProvider.viewMoreButtonBackgroundColor,
                                              borderRadius: BorderRadius.circular(12.r),
                                              border: Border.all(
                                                color: themeProvider.viewMoreButtonBorderColor,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.visibility,
                                                  color: themeProvider.primaryTextColor,
                                                  size: 12.sp,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  'View More',
                                                  style: TextStyle(
                                                    color: themeProvider.primaryTextColor,
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
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
                        );
                      },
                    ),
                    
                    // Loading indicator at bottom when loading more
                    if (isLoadingMore)
                      Positioned(
                        bottom: 150.h,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16.sp,
                                  height: 16.sp,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'Loading more...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

              // App bar overlay with refresh functionality
              SafeArea(
                child: Container(
                  height: 56.h,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                          SizedBox(width: 4.w),
                          Text(
                            'Loops',
                            style: TextStyle(
                              color: themeProvider.primaryTextColor,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Blinka',
                             
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_isShowingSpecificContent)
                            IconButton(
                              onPressed: _exitSpecificContentMode,
                              icon: Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, color: Colors.white, size: 16.sp),
                              ),
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
                          if (!_isShowingSpecificContent && !isGeneratingContent)
                            IconButton(
                              onPressed: () {
                                setState(() => _contentLoadedInThisSession = false);
                                _loadFreshContentOnEntry();
                              },
                              icon: Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedRefresh,
                                  color: Colors.white,
                                  size: 16.sp,
                                ),
                              ),
                            ),
                        ],
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
          bottomNavigationBar: widget.showBottomNav ? const CustomBottomNav(currentIndex: 1) : null,
        );
      },
    );
  }

  Widget _buildFallbackContent(Map<String, dynamic> loop, ThemeProvider themeProvider) {
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
            Text('Tap to explore', style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 18.sp)),
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

  // Add share method for loops
  void _shareLoopContent(Map<String, dynamic> loop) async {
    try {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // Ensure loop has proper structure for sharing
      final enrichedLoop = {
        ...loop,
        'title': loop['title'] ?? 'Unknown Title',
        'extract': loop['extract'] ?? 'No content available.',
        'url': loop['url'] ?? '', // Wikipedia URL
        'image': loop['image'],
        'app_name': 'Finity',
        'source': 'Wikipedia',
        'type': 'Finity Loops',
      };

      if (enrichedLoop['image'] != null && enrichedLoop['image'].toString().isNotEmpty) {
        await _shareService.shareContentWithImage(
          content: enrichedLoop,
          sharePositionOrigin: sharePositionOrigin,
          context: context,
        );
      } else {
        await _shareService.shareContent(
          content: enrichedLoop,
          sharePositionOrigin: sharePositionOrigin,
          context: context,
        );
      }
    } catch (e) {
      debugPrint('Error sharing loop content: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Content copied to clipboard'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showContentBottomSheet(Map<String, dynamic> loop, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
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
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: themeProvider.bottomSheetHandleColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Loop title
                        Text(
                          loop['title'] ?? 'Unknown Title',
                          style: TextStyle(
                            color: themeProvider.primaryTextColor,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        
                        // Loop image
                        if (loop['image'] != null && loop['image'].isNotEmpty)
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: Image.network(
                                  loop['image'],
                                  width: double.infinity,
                                  height: 200.h,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: double.infinity,
                                      height: 200.h,
                                      decoration: BoxDecoration(
                                        color: themeProvider.secondaryBackgroundColor,
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(themeProvider.primaryTextColor),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: double.infinity,
                                    height: 200.h,
                                    decoration: BoxDecoration(
                                      color: themeProvider.secondaryBackgroundColor,
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: themeProvider.tertiaryTextColor,
                                        size: 48.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20.h),
                            ],
                          ),
                        
                        // Main content from Wikipedia extract
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Content',
                              style: TextStyle(
                                color: themeProvider.primaryTextColor,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _getContentText(loop),
                              style: TextStyle(
                                color: themeProvider.secondaryTextColor,
                                fontSize: 16.sp,
                                height: 1.5,
                              ),
                            ),
                            SizedBox(height: 20.h),
                          ],
                        ),
                        
                        SizedBox(height: 4.h),
                        
                        // Action buttons with translated text
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _toggleLike(loop),
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedFavourite,
                                  color: Colors.white,
                                  size: 14.sp,
                                ),
                                label: Text(
                                  likedContent[loop['id'] ?? ''] == true 
                                      ? _languageService.getUIText('liked') 
                                      : _languageService.getUIText('like')
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: likedContent[loop['id'] ?? ''] == true ? Colors.red : Colors.blue,
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
                                onPressed: () => _shareLoopContent(loop),
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
                        if (loop['url'] != null && loop['url'].toString().isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _openWikipediaArticle(loop['url']),
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
          ),      );
  }

  // Add helper method to get content text with proper fallbacks
  String _getContentText(Map<String, dynamic> loop) {
    // Priority order: extract -> content -> fallback message
    if (loop['extract'] != null && loop['extract'].toString().isNotEmpty) {
      return loop['extract'].toString();
    } else if (loop['content'] != null && loop['content'].toString().isNotEmpty) {
      return loop['content'].toString();
    } else if (loop['description'] != null && loop['description'].toString().isNotEmpty) {
      return loop['description'].toString();
    } else {
      return 'No content available for this loop. Please try refreshing or check back later.';
    }
  }

  // Add missing methods after the existing methods

  Future<void> _loadLikedStatus() async {
    final Map<String, bool> status = {};
    for (final loop in loops) {
      status[loop['id'] ?? ''] = await _contentService.isContentLiked(loop['id'] ?? '');
    }
    if (mounted) setState(() => likedContent = status);
  }

  Future<void> _toggleLike(Map<String, dynamic> loop) async {
    final loopId = loop['id'] ?? '';
    final isCurrentlyLiked = likedContent[loopId] ?? false;
    
    setState(() {
      likedContent[loopId] = !isCurrentlyLiked;
      loop['likes'] = (loop['likes'] ?? 0) + (isCurrentlyLiked ? -1 : 1);
    });

    bool success = isCurrentlyLiked 
        ? await _contentService.unlikeContent(loopId)
        : await _contentService.likeContent(loop, ContentType.loop);

    if (!success) {
      setState(() {
        likedContent[loopId] = isCurrentlyLiked;
        loop['likes'] = (loop['likes'] ?? 0) + (isCurrentlyLiked ? 1 : -1);
      });
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
}

class InfinityProfilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Create gradient for the infinity symbol
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

    // Scale factors to match the SVG viewBox (120x120)
    final scaleX = size.width / 120;
    final scaleY = size.height / 120;

    final path = Path();

    // Fully expanded infinity shape
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

// Update the SplashInfinityPainter class
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

    // Scale factors to match the SVG viewBox (120x120)
    final scaleX = size.width / 120;
    final scaleY = size.height / 120;

    final path = Path();

    // Fully expanded infinity shape
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

    // Create animated path that draws from start to end
    final pathMetric = path.computeMetrics().first;
    final animatedPath = pathMetric.extractPath(0, pathMetric.length * animationValue);

    canvas.drawPath(animatedPath, paint);
    
    // Add a glowing effect at the drawing point
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