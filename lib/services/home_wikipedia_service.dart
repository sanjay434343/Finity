import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'language_service.dart';

class HomeWikipediaService {
  static final HomeWikipediaService _instance = HomeWikipediaService._internal();
  factory HomeWikipediaService() => _instance;
  HomeWikipediaService._internal();

  static const Duration _timeout = Duration(seconds: 3); // Faster timeout
  
  List<Map<String, dynamic>> _cachedArticles = [];
  Set<String> _usedArticleIds = {};
  bool _isLoading = false;
  bool _isPreloading = false;
  DateTime? _lastCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 10);
  int _requestCounter = 0;

  // Increased batch sizes for aggressive loading
  static const int _initialBatchSize = 50;
  static const int _preloadBatchSize = 50;
  static const int _maxCacheSize = 200; // Increased cache size
  static const int _preloadTrigger = 40; // Start preloading when 40 items consumed

  final LanguageService _languageService = LanguageService();

  String get _randomUrl {
    final langCode = _languageService.wikipediaLanguageCode;
    print('HomeWikipediaService: Using language code: $langCode');
    return 'https://$langCode.wikipedia.org/api/rest_v1/page/random/summary';
  }

  Future<List<Map<String, dynamic>>> getHomeContent({
    int count = 50, // Increased default count
    bool forceRefresh = false
  }) async {
    _requestCounter++;
    final currentLangCode = _languageService.wikipediaLanguageCode;
    
    print('HomeWikipediaService: getHomeContent called - count: $count, forceRefresh: $forceRefresh, cached: ${_cachedArticles.length}');
    
    // If force refresh is requested, always fetch new content
    if (forceRefresh) {
      print('HomeWikipediaService: Force refresh requested, fetching fresh content');
      return await _fetchFreshContent(count);
    }
    
    // Check if we have enough cached content
    if (_cachedArticles.length >= count && _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheExpiry) {
      print('HomeWikipediaService: Returning cached content: ${_cachedArticles.length} articles');
      final result = _getUniqueArticles(count);
      
      // Start preloading if we're running low on cache
      if (_cachedArticles.length - count < _preloadTrigger && !_isPreloading) {
        _startBackgroundPreload();
      }
      
      print('HomeWikipediaService: Processed ${result.length} articles from cache');
      return result;
    }

    print('HomeWikipediaService: Cache insufficient or expired, fetching fresh content');
    return await _fetchFreshContent(count);
  }

  Future<List<Map<String, dynamic>>> _fetchFreshContent(int count) async {
    if (_isLoading) {
      print('HomeWikipediaService: Already loading, waiting...');
      await Future.delayed(Duration(milliseconds: 500));
      return _getUniqueArticles(min(count, _cachedArticles.length));
    }

    _isLoading = true;
    print('HomeWikipediaService: Fetching fresh content, request #$_requestCounter');

    try {
      final newArticles = <Map<String, dynamic>>[];
      final targetCount = max(count, _initialBatchSize); // Always load at least initial batch size
      final maxAttempts = targetCount * 3; // Reduced attempts for speed
      int attempts = 0;
      
      // Use multiple parallel batches for faster loading
      while (newArticles.length < targetCount && attempts < maxAttempts) {
        final batchSize = min(20, targetCount - newArticles.length + 10); // Larger batches
        final futures = <Future<Map<String, dynamic>?>>[];
        
        for (int i = 0; i < batchSize; i++) {
          futures.add(_fetchSingleArticle());
        }

        final results = await Future.wait(futures, eagerError: false);
        
        for (final article in results) {
          if (article != null && 
              !_usedArticleIds.contains(article['id']) &&
              newArticles.length < targetCount) {
            newArticles.add(article);
            _usedArticleIds.add(article['id']);
          }
        }
        
        attempts += batchSize;
        
        // Smaller delay for faster loading
        if (newArticles.length < targetCount && attempts < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 100));
        }
      }

      // Add to cache and manage cache size
      if (newArticles.isNotEmpty) {
        _cachedArticles.addAll(newArticles);
        _manageCacheSize();
        _lastCacheTime = DateTime.now();
        
        // Start background preloading immediately
        _startBackgroundPreload();
      }
      
      print('HomeWikipediaService: Fetched ${newArticles.length} fresh articles (${_cachedArticles.length} total cached)');
      
      return _getUniqueArticles(count);
      
    } catch (e) {
      print('Error in _fetchFreshContent: $e');
      final fallbackResult = _getUniqueArticles(min(count, _cachedArticles.length));
      print('HomeWikipediaService: Returning ${fallbackResult.length} fallback articles');
      return fallbackResult;
    } finally {
      _isLoading = false;
    }
  }

  // New method for aggressive background preloading
  void _startBackgroundPreload() async {
    if (_isPreloading || _isLoading) return;
    
    _isPreloading = true;
    print('HomeWikipediaService: Starting background preload');
    
    Future.microtask(() async {
      try {
        final newArticles = <Map<String, dynamic>>[];
        final futures = <Future<Map<String, dynamic>?>>[];
        
        // Create 30 parallel requests for super fast loading
        for (int i = 0; i < 30; i++) {
          futures.add(_fetchSingleArticle());
        }
        
        final results = await Future.wait(futures, eagerError: false);
        
        for (final article in results) {
          if (article != null && 
              !_usedArticleIds.contains(article['id']) &&
              newArticles.length < _preloadBatchSize) {
            newArticles.add(article);
            _usedArticleIds.add(article['id']);
          }
        }
        
        if (newArticles.isNotEmpty && mounted()) {
          _cachedArticles.addAll(newArticles);
          _manageCacheSize();
          print('HomeWikipediaService: Background preloaded ${newArticles.length} articles');
        }
        
      } catch (e) {
        print('Error in background preload: $e');
      } finally {
        _isPreloading = false;
      }
    });
  }

  bool mounted() {
    return true; // Simple check for now
  }

  List<Map<String, dynamic>> _getUniqueArticles(int count) {
    final uniqueArticles = <Map<String, dynamic>>[];
    
    // Reset used IDs periodically to allow content recycling
    if (_usedArticleIds.length > 500) { // Increased threshold
      _usedArticleIds.clear();
      print('HomeWikipediaService: Reset used IDs for content recycling');
    }
    
    // First pass: get unused articles
    for (final article in _cachedArticles) {
      if (uniqueArticles.length >= count) break;
      
      if (!_usedArticleIds.contains(article['id'])) {
        uniqueArticles.add(article);
        _usedArticleIds.add(article['id']);
      }
    }
    
    // Second pass: if we need more, recycle old content
    if (uniqueArticles.length < count && _cachedArticles.isNotEmpty) {
      for (final article in _cachedArticles) {
        if (uniqueArticles.length >= count) break;
        
        if (!uniqueArticles.any((existing) => existing['id'] == article['id'])) {
          uniqueArticles.add(article);
        }
      }
    }
    
    print('HomeWikipediaService: Returning ${uniqueArticles.length} unique articles from ${_cachedArticles.length} cached');
    return uniqueArticles;
  }

  void _manageCacheSize() {
    // Keep larger cache for better performance
    if (_cachedArticles.length > _maxCacheSize) {
      _cachedArticles = _cachedArticles.skip(50).toList();
    }
    
    // Clean up old used IDs periodically
    if (_usedArticleIds.length > 600) {
      final idsToKeep = _cachedArticles.map((a) => a['id']).toSet();
      _usedArticleIds = _usedArticleIds.intersection(idsToKeep);
    }
  }

  Future<Map<String, dynamic>?> _fetchSingleArticle() async {
    try {
      final response = await http.get(
        Uri.parse(_randomUrl),
        headers: {
          'User-Agent': 'Finity-App/1.0 (https://finity.app/contact)',
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (_isContentAppropriate(data)) {
          return _formatArticleData(data);
        }
      }
    } catch (e) {
      print('Error fetching single article: $e');
    }
    return null;
  }

  bool _isContentAppropriate(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString();
    final extract = (data['extract'] ?? '').toString();
    
    // More lenient filtering - allow more content through
    final inappropriateKeywords = [
      'disambiguation', 'redirect', 'template:', 'category:',
      'user:', 'wikipedia:', 'file:', 'media:', 'special:'
    ];
    
    final titleLower = title.toLowerCase();
    if (inappropriateKeywords.any((keyword) => titleLower.contains(keyword))) {
      return false;
    }
    
    // Reduced minimum content length for more content variety
    final minLength = _getMinContentLength();
    if (extract.length < minLength) {
      return false;
    }
    
    // Ensure we have actual content, not just metadata
    return title.isNotEmpty && extract.isNotEmpty;
  }

  int _getMinContentLength() {
    // Reduced minimum lengths to get more content
    switch (_languageService.wikipediaLanguageCode) {
      case 'zh':
      case 'ja':
      case 'ko':
        return 30; // Reduced from 50
      case 'ar':
      case 'hi':
      case 'ta':
      case 'th':
        return 40; // Reduced from 70
      default:
        return 50; // Reduced from 80
    }
  }

  Map<String, dynamic> _formatArticleData(Map<String, dynamic> data) {
    final random = Random();
    final title = data['title'] ?? 'Unknown Article';
    final pageId = data['pageid']?.toString() ?? random.nextInt(999999).toString();
    
    return {
      'id': 'wiki_${pageId}_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'extract': data['extract'] ?? 'Content not available.',
      'image': data['thumbnail']?['source'],
      'url': data['content_urls']?['desktop']?['page'] ?? '',
      'likes': random.nextInt(1000) + 100,
      'views': _generateViews(),
      'avatar': title.isNotEmpty ? title[0].toUpperCase() : 'W',
      'username': 'Wikipedia',
      'time': _generateTime(),
      'type': 'wikipedia',
      'language': _languageService.wikipediaLanguageCode,
      'source': 'Wikipedia',
      'pageid': pageId,
    };
  }

  Future<List<Map<String, dynamic>>> loadMoreHomeContent({int count = 50}) async {
    // Check if we need to preload more
    if (_cachedArticles.length < count + _preloadTrigger && !_isPreloading) {
      _startBackgroundPreload();
    }
    
    return await getHomeContent(count: count, forceRefresh: false);
  }

  String _generateViews() {
    final random = Random();
    final viewCount = random.nextInt(50) + 5;
    return '${viewCount}K';
  }

  String _generateTime() {
    final random = Random();
    final times = ['2m', '8m', '15m', '25m', '45m', '1h', '2h', '3h', '5h', '8h'];
    return times[random.nextInt(times.length)];
  }

  void clearCache() {
    _cachedArticles.clear();
    _usedArticleIds.clear();
    _lastCacheTime = null;
    _requestCounter = 0;
    print('HomeWikipediaService: Cache and tracking cleared');
  }

  // Add method to force refresh content
  Future<List<Map<String, dynamic>>> forceRefreshContent({int count = 15}) async {
    print('HomeWikipediaService: Force refresh requested, clearing cache');
    _cachedArticles.clear();
    _usedArticleIds.clear();
    _lastCacheTime = null;
    _requestCounter = 0;
    return await _fetchFreshContent(count);
  }

  int get cacheSize => _cachedArticles.length;
  int get usedIdsCount => _usedArticleIds.length;
  bool get hasValidCache => _lastCacheTime != null && 
      DateTime.now().difference(_lastCacheTime!) < _cacheExpiry;

  // Add method to get cache status
  Map<String, dynamic> getCacheInfo() {
    return {
      'cache_size': _cachedArticles.length,
      'used_ids_count': _usedArticleIds.length,
      'is_loading': _isLoading,
      'is_preloading': _isPreloading,
      'cache_valid': hasValidCache,
    };
  }
}
