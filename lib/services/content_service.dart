import '../services/home_wikipedia_service.dart';
import '../services/loops_wikipedia_service.dart';
import '../services/local_database.dart';
import '../services/language_service.dart';
import 'dart:math';

class ContentService {
  static final ContentService _instance = ContentService._internal();
  factory ContentService() => _instance;
  ContentService._internal() {
    _languageService.addListener(_onLanguageChanged);
  }

  final HomeWikipediaService _homeWikipediaService = HomeWikipediaService();
  final LoopsWikipediaService _loopsWikipediaService = LoopsWikipediaService();
  final LocalDatabase _localDatabase = LocalDatabase();
  final LanguageService _languageService = LanguageService();
  
  List<Map<String, dynamic>> _cachedHomeContent = [];
  List<Map<String, dynamic>> _cachedLoopsContent = [];
  bool _isLoadingHome = false;
  bool _isLoadingLoops = false;

  // Handle language change
  void _onLanguageChanged() {
    // Clear caches when language changes
    _cachedHomeContent.clear();
    _cachedLoopsContent.clear();
    _homeWikipediaService.clearCache();
    _loopsWikipediaService.clearCache();
    print('ContentService: Cleared caches due to language change');
  }

  // Get content for home screen (Twitter-like feed)
  Future<List<Map<String, dynamic>>> getHomeContent({int count = 50, bool forceRefresh = false}) async {
    print('ContentService: getHomeContent called - count: $count, forceRefresh: $forceRefresh');
    
    try {
      final content = await _homeWikipediaService.getHomeContent(
        count: count, 
        forceRefresh: forceRefresh
      );
      
      // Start preloading more content in background if we're running low
      final cacheInfo = _homeWikipediaService.getCacheInfo();
      if (cacheInfo['cache_size'] < count + 40) {
        print('ContentService: Cache running low, starting background refresh');
        Future.microtask(() => _homeWikipediaService.loadMoreHomeContent(count: 50));
      }
      
      return content;
    } catch (e) {
      print('ContentService: Error getting home content: $e');
      return [];
    }
  }

  // Get content for loops screen (TikTok-like reels)
  Future<List<Map<String, dynamic>>> getLoopsContent({int count = 50, bool forceRefresh = false}) async {
    print('ContentService: getLoopsContent called - count: $count, forceRefresh: $forceRefresh');
    
    try {
      final content = await _loopsWikipediaService.getLoopsContent(count: count);
      
      // Start preloading more content in background if we're running low
      final cacheInfo = _loopsWikipediaService.getCacheInfo();
      if (cacheInfo['cache_size'] < count + 40) {
        print('ContentService: Loops cache running low, starting background refresh');
        Future.microtask(() => _loopsWikipediaService.loadMoreLoopsContent(count: 50));
      }
      
      return content;
    } catch (e) {
      print('ContentService: Error getting loops content: $e');
      return [];
    }
  }

  // Ultra-fast loops content loading with aggressive caching
  Future<List<Map<String, dynamic>>> getLoopsContentUltraFast({int count = 15, bool forceRefresh = false}) async {
    return await getLoopsContent(count: count, forceRefresh: forceRefresh);
  }

  // Background refresh without blocking UI
  void _refreshLoopsInBackground() async {
    if (_isLoadingLoops) return;
    _isLoadingLoops = true;
    
    try {
      await _loopsWikipediaService.loadMoreLoopsContent(count: 15);
    } catch (e) {
      print('Error in background loops refresh: $e');
    } finally {
      _isLoadingLoops = false;
    }
  }

  // Legacy method for backward compatibility
  Future<List<Map<String, dynamic>>> getContent({int count = 15, bool forceRefresh = false}) async {
    return await getHomeContent(count: count, forceRefresh: forceRefresh);
  }

  // Load more content for home with aggressive preloading
  Future<List<Map<String, dynamic>>> loadMoreHomeContent({int count = 50, bool forceRefresh = false}) async {
    return await _homeWikipediaService.loadMoreHomeContent(count: count);
  }

  // Load more content for loops with aggressive preloading
  Future<List<Map<String, dynamic>>> loadMoreLoopsContent({int count = 50, bool forceRefresh = false}) async {
    return await _loopsWikipediaService.loadMoreLoopsContent(count: count);
  }

  // Get cache information for debugging
  Map<String, dynamic> getCacheInfo() {
    final homeCache = _homeWikipediaService.getCacheInfo();
    final loopsCache = _loopsWikipediaService.getCacheInfo();
    
    return {
      'home_cache_size': homeCache['cache_size'],
      'home_cache_valid': homeCache['cache_valid'],
      'loops_cache_size': loopsCache['cache_size'], 
      'loops_cache_valid': loopsCache['cache_valid'],
      'home_is_loading': homeCache['is_loading'],
      'loops_is_loading': loopsCache['is_loading'],
    };
  }

  // Clear loops cache
  void clearLoopsCache() {
    _loopsWikipediaService.clearCache();
  }

  // Clear home cache  
  void clearHomeCache() {
    _homeWikipediaService.clearCache();
  }

  // Like content
  Future<bool> likeContent(Map<String, dynamic> content, ContentType type) async {
    try {
      final likedContent = LikedContent(
        id: content['id'] ?? '',
        title: content['title'] ?? '',
        extract: content['extract'] ?? '',
        imageUrl: content['image'],
        contentUrl: content['url'] ?? '',
        likes: content['likes'] ?? 0,
        views: content['views'] ?? '0',
        type: type,
        timestamp: DateTime.now(),
      );
      
      return await _localDatabase.insertLikedContent(likedContent);
    } catch (e) {
      print('Error liking content: $e');
      return false;
    }
  }

  // Unlike content
  Future<bool> unlikeContent(String contentId) async {
    try {
      return await _localDatabase.deleteLikedContent(contentId);
    } catch (e) {
      print('Error unliking content: $e');
      return false;
    }
  }

  // Check if content is liked
  Future<bool> isContentLiked(String contentId) async {
    try {
      return await _localDatabase.isContentLiked(contentId);
    } catch (e) {
      print('Error checking liked status: $e');
      return false;
    }
  }

  // Get all liked content
  Future<List<LikedContent>> getAllLikedContent() async {
    try {
      return await _localDatabase.getAllLikedContent();
    } catch (e) {
      print('Error getting all liked content: $e');
      return [];
    }
  }

  // Clear all liked content
  Future<bool> clearAllLikedContent() async {
    try {
      return await _localDatabase.clearAllLikedContent();
    } catch (e) {
      print('Error clearing all liked content: $e');
      return false;
    }
  }

  void dispose() {
    _languageService.removeListener(_onLanguageChanged);
  }
}
