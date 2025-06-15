import 'dart:convert';
import 'dart:math';
import 'dart:async'; // Add this import for Timer
import 'package:http/http.dart' as http;
import 'language_service.dart';

class LoopsWikipediaService {
  static final LoopsWikipediaService _instance = LoopsWikipediaService._internal();
  factory LoopsWikipediaService() => _instance;
  LoopsWikipediaService._internal();

  static const Duration _timeout = Duration(milliseconds: 1000); // Faster timeout
  
  List<Map<String, dynamic>> _cachedReels = [];
  bool _isLoading = false;
  bool _isPreloading = false;
  DateTime? _lastCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 3);

  // Aggressive loading constants
  static const int _initialBatchSize = 25; // Slightly larger initial batch
  static const int _preloadBatchSize = 15; // Smaller preload batches for speed
  static const int _maxCacheSize = 200; // Larger cache for continuous scrolling
  static const int _preloadTrigger = 30; // Start preloading earlier

  // Preload cache for instant access
  List<Map<String, dynamic>> _preloadCache = [];

  final LanguageService _languageService = LanguageService();

  String get _randomUrl {
    final langCode = _languageService.wikipediaLanguageCode;
    return 'https://$langCode.wikipedia.org/api/rest_v1/page/random/summary';
  }

  Future<List<Map<String, dynamic>>> getLoopsContent({int count = 20}) async {
    print('LoopsWikipediaService: getLoopsContent called with count: $count');
    
    // Return cached reels immediately if available
    if (_cachedReels.length >= count && 
        _lastCacheTime != null && 
        DateTime.now().difference(_lastCacheTime!) < _cacheExpiry) {
      print('Returning cached loops content instantly: ${_cachedReels.length} reels');
      
      // Start preloading if running low
      if (_cachedReels.length - count < _preloadTrigger && !_isPreloading) {
        _startAggressivePreload();
      }
      
      return _cachedReels.take(count).toList();
    }

    if (_isLoading) {
      // Return whatever we have while loading
      return _cachedReels.take(min(count, _cachedReels.length)).toList();
    }

    return await _loadContentAggressively(count);
  }

  Future<List<Map<String, dynamic>>> _loadContentAggressively(int count) async {
    _isLoading = true;
    print('LoopsWikipediaService: Loading content aggressively...');

    try {
      final targetCount = max(count, _initialBatchSize);
      final futures = <Future<Map<String, dynamic>?>>[];
      
      // Create massive parallel requests for ultra-fast loading
      for (int i = 0; i < targetCount * 2; i++) {
        futures.add(_fetchLoopsReelFast());
      }

      // Wait for results with timeout
      final results = await Future.wait(futures, eagerError: false).timeout(
        const Duration(seconds: 4),
        onTimeout: () => futures.map((f) => null).toList(),
      );
      
      final reels = <Map<String, dynamic>>[];
      for (final reel in results) {
        if (reel != null && reels.length < targetCount) {
          reels.add(reel);
        }
      }

      if (reels.isNotEmpty) {
        _cachedReels = reels;
        _lastCacheTime = DateTime.now();
        print('Aggressively loaded ${reels.length} reels');
        
        // Start continuous preloading
        _startAggressivePreload();
      }
      
      return reels.take(count).toList();
    } catch (e) {
      print('Error loading aggressively: $e');
      return _cachedReels.take(count).toList();
    } finally {
      _isLoading = false;
    }
  }

  Future<List<Map<String, dynamic>>> loadMoreLoopsContent({int count = 30}) async {
    print('LoopsWikipediaService: loadMoreLoopsContent called with count: $count (current cache: ${_cachedReels.length})');
    
    // If we have enough cached content, return it immediately
    if (_cachedReels.length >= count) {
      print('Returning from cache: $count items');
      
      // Start preloading more if we're getting low
      if (_cachedReels.length - count < _preloadTrigger && !_isPreloading) {
        print('Starting preload as cache is getting low');
        _startAggressivePreload();
      }
      
      return _cachedReels.take(count).toList();
    }

    // If currently loading, return what we have and let loading continue
    if (_isLoading) {
      print('Currently loading, returning available items: ${_cachedReels.length}');
      return _cachedReels.toList();
    }

    // Need to load more content
    print('Need to load more content. Target: $count, Current: ${_cachedReels.length}');
    
    final additionalNeeded = count - _cachedReels.length + _preloadBatchSize;
    await _loadAdditionalContent(additionalNeeded);
    
    return _cachedReels.take(count).toList();
  }

  Future<void> _loadAdditionalContent(int additionalCount) async {
    if (_isLoading) return;
    
    _isLoading = true;
    print('Loading additional content: $additionalCount items');

    try {
      final futures = <Future<Map<String, dynamic>?>>[];
      
      // Create parallel requests for the additional content needed
      for (int i = 0; i < additionalCount * 2; i++) { // Request more than needed
        futures.add(_fetchLoopsReelFast());
      }

      final results = await Future.wait(futures, eagerError: false).timeout(
        const Duration(seconds: 5),
        onTimeout: () => futures.map((f) => null).toList(),
      );
      
      final newReels = <Map<String, dynamic>>[];
      for (final reel in results) {
        if (reel != null && newReels.length < additionalCount) {
          newReels.add(reel);
        }
      }

      if (newReels.isNotEmpty) {
        _cachedReels.addAll(newReels);
        
        // Manage cache size
        if (_cachedReels.length > _maxCacheSize) {
          _cachedReels = _cachedReels.take(_maxCacheSize).toList();
        }
        
        _lastCacheTime = DateTime.now();
        print('Added ${newReels.length} new reels (total: ${_cachedReels.length})');
      }
      
    } catch (e) {
      print('Error loading additional content: $e');
    } finally {
      _isLoading = false;
    }
  }

  void _startAggressivePreload() async {
    if (_isPreloading) return;
    
    _isPreloading = true;
    print('LoopsWikipediaService: Starting aggressive preload');
    
    Future.microtask(() async {
      try {
        final futures = <Future<Map<String, dynamic>?>>[];
        
        // Create parallel requests for preloading
        for (int i = 0; i < 30; i++) { // Reduced for faster response
          futures.add(_fetchLoopsReelFast());
        }

        final results = await Future.wait(futures, eagerError: false);
        
        final newReels = <Map<String, dynamic>>[];
        for (final reel in results) {
          if (reel != null && newReels.length < _preloadBatchSize) {
            newReels.add(reel);
          }
        }
        
        if (newReels.isNotEmpty) {
          _cachedReels.addAll(newReels);
          
          // Manage cache size
          if (_cachedReels.length > _maxCacheSize) {
            _cachedReels = _cachedReels.take(_maxCacheSize).toList();
          }
          
          _lastCacheTime = DateTime.now();
          print('Aggressively preloaded ${newReels.length} reels (total: ${_cachedReels.length})');
        }
        
      } catch (e) {
        print('Error in aggressive preload: $e');
      } finally {
        _isPreloading = false;
        
        // Schedule next preload if cache is still low
        if (_cachedReels.length < _maxCacheSize * 0.7) { // Preload when 70% full
          Future.delayed(const Duration(seconds: 5), () {
            if (!_isPreloading && _cachedReels.length < _maxCacheSize * 0.7) {
              _startAggressivePreload();
            }
          });
        }
      }
    });
  }

  // Ultra-fast reel fetching with reduced timeout
  Future<Map<String, dynamic>?> _fetchLoopsReelFast() async {
    try {
      final response = await http.get(
        Uri.parse(_randomUrl),
        headers: {
          'User-Agent': 'Finity-Loops/1.0 (https://example.com/contact)',
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (_isLoopsAppropriate(data)) {
          return _formatLoopsReelData(data);
        }
      }
    } catch (e) {
      // Silent failure for speed
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchLoopsReel() async {
    try {
      final response = await http.get(
        Uri.parse(_randomUrl),
        headers: {
          'User-Agent': 'Finity-Loops/1.0 (https://example.com/contact)',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Accept any random content - remove category filtering
        if (_isLoopsAppropriate(data)) {
          return _formatLoopsReelData(data);
        }
      }
    } catch (e) {
      print('Error fetching loops reel: $e');
    }
    return null;
  }

  bool _isLoopsAppropriate(Map<String, dynamic> data) {
    final extract = (data['extract'] ?? '').toString().toLowerCase();
    
    // Accept any content with reasonable length - no category filtering
    return extract.length > 80 && extract.length < 400;
  }

  Map<String, dynamic> _formatLoopsReelData(Map<String, dynamic> data) {
    final random = Random();
    final title = data['title'] ?? _getDefaultTitle();
    
    return {
      'id': 'loops_${data['pageid']?.toString() ?? random.nextInt(10000)}',
      'title': title,
      'extract': data['extract'] ?? _getDefaultExtract(),
      'image': data['thumbnail']?['source'] ?? 'https://picsum.photos/400/600?random=${random.nextInt(100)}',
      'url': data['content_urls']?['desktop']?['page'] ?? '',
      'likes': random.nextInt(2000) + 100,
      'views': '${(random.nextInt(100) + 10)}K',
      'avatar': title.isNotEmpty ? title[0].toUpperCase() : 'D',
      'username': _generateLoopsUsername(title),
      'time': _generateLoopsTime(),
      'type': 'loops_content',
      'language': _languageService.wikipediaLanguageCode,
    };
  }

  String _getDefaultTitle() {
    switch (_languageService.wikipediaLanguageCode) {
      case 'es': return 'Descubre';
      case 'fr': return 'Découvrir';
      case 'de': return 'Entdecken';
      case 'ta': return 'கண்டறியுங்கள்';
      case 'hi': return 'खोजें';
      case 'ar': return 'اكتشف';
      case 'zh': return '发现';
      case 'ja': return '発見';
      case 'ko': return '발견';
      default: return 'Discover';
    }
  }

  String _getDefaultExtract() {
    switch (_languageService.wikipediaLanguageCode) {
      case 'es': return 'Explora este tema fascinante y descubre algo nuevo.';
      case 'fr': return 'Explorez ce sujet fascinant et découvrez quelque chose de nouveau.';
      case 'de': return 'Erkunden Sie dieses faszinierende Thema und entdecken Sie etwas Neues.';
      case 'ta': return 'இந்த கவர்ச்சிகரமான தலைப்பை ஆராய்ந்து புதிதாக ஏதாவது கண்டறியுங்கள்.';
      case 'hi': return 'इस दिलचस्प विषय का अन्वेषण करें और कुछ नया खोजें।';
      case 'ar': return 'استكشف هذا الموضوع الرائع واكتشف شيئًا جديدًا.';
      case 'zh': return '探索这个迷人的话题，发现新的东西。';
      case 'ja': return 'この魅力的なトピックを探索し、新しいことを発見してください。';
      case 'ko': return '이 매혹적인 주제를 탐험하고 새로운 것을 발견하세요.';
      default: return 'Explore this fascinating topic and discover something new.';
    }
  }

  Map<String, dynamic> _getLoopsFallbackReel() {
    // Return null instead of mock content - only use Wikipedia data
    return {};
  }

  String _generateLoopsUsername(String title) {
    final cleanTitle = title.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(' ')
        .take(1)
        .join('');
    
    if (cleanTitle.length > 12) {
      return '${cleanTitle.substring(0, 8)}_wiki';
    }
    return cleanTitle.isNotEmpty ? '${cleanTitle}_random' : 'random_content';
  }

  String _generateLoopsTime() {
    final random = Random();
    final times = ['30s', '1m', '2m', '5m', '10m', '15m', '30m', '1h', '2h'];
    return times[random.nextInt(times.length)];
  }

  void clearCache() {
    _cachedReels.clear();
    _lastCacheTime = null;
    print('Loops Wikipedia cache cleared');
  }

  int get cacheSize => _cachedReels.length;
  bool get hasValidCache => _lastCacheTime != null && 
      DateTime.now().difference(_lastCacheTime!) < _cacheExpiry;

  // Add cache info method
  Map<String, dynamic> getCacheInfo() {
    return {
      'cache_size': _cachedReels.length,
      'is_loading': _isLoading,
      'is_preloading': _isPreloading,
      'cache_valid': hasValidCache,
    };
  }
}
