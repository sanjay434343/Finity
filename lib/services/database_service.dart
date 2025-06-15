import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static const String _recentSearchesKey = 'recent_searches';
  static const String _trendingWordsKey = 'trending_words';
  static const String _searchCountKey = 'search_count';
  static const int _maxRecentSearches = 10;
  
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();
  DatabaseService._();

  // Get recent searches
  Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentSearchesJson = prefs.getStringList(_recentSearchesKey) ?? [];
      return recentSearchesJson;
    } catch (e) {
      print('Error getting recent searches: $e');
      return [];
    }
  }

  // Add search to recent searches
  Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentSearches = await getRecentSearches();
      
      // Remove if already exists to move to top
      recentSearches.remove(query);
      
      // Add to beginning
      recentSearches.insert(0, query);
      
      // Limit to max recent searches
      if (recentSearches.length > _maxRecentSearches) {
        recentSearches = recentSearches.take(_maxRecentSearches).toList();
      }
      
      await prefs.setStringList(_recentSearchesKey, recentSearches);
      
      // Update search count for trending
      await _updateSearchCount(query);
    } catch (e) {
      print('Error adding recent search: $e');
    }
  }

  // Clear recent searches
  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (e) {
      print('Error clearing recent searches: $e');
    }
  }

  // Remove specific recent search
  Future<void> removeRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentSearches = await getRecentSearches();
      recentSearches.remove(query);
      await prefs.setStringList(_recentSearchesKey, recentSearches);
    } catch (e) {
      print('Error removing recent search: $e');
    }
  }

  // Update search count for trending words
  Future<void> _updateSearchCount(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchCountJson = prefs.getString(_searchCountKey) ?? '{}';
      Map<String, dynamic> searchCount = json.decode(searchCountJson);
      
      // Increment count for this query
      searchCount[query] = (searchCount[query] ?? 0) + 1;
      
      await prefs.setString(_searchCountKey, json.encode(searchCount));
    } catch (e) {
      print('Error updating search count: $e');
    }
  }

  // Get trending words based on search frequency
  Future<List<String>> getTrendingWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchCountJson = prefs.getString(_searchCountKey) ?? '{}';
      Map<String, dynamic> searchCount = json.decode(searchCountJson);
      
      // Sort by count and get top trending words
      var sortedEntries = searchCount.entries.toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));
      
      List<String> trending = sortedEntries
          .take(6)
          .map((entry) => entry.key as String)
          .toList();
      
      // Add some default trending words if not enough data
      final defaultTrending = [
        'Science', 'Technology', 'History', 'Art', 'Literature', 'Music',
        'Philosophy', 'Mathematics', 'Physics', 'Biology'
      ];
      
      for (String word in defaultTrending) {
        if (!trending.contains(word) && trending.length < 10) {
          trending.add(word);
        }
      }
      
      return trending.take(10).toList();
    } catch (e) {
      print('Error getting trending words: $e');
      return ['Science', 'Technology', 'History', 'Art', 'Literature', 'Music'];
    }
  }

  // Get hint words for auto-completion
  Future<List<String>> getHintWords(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final recent = await getRecentSearches();
      final trending = await getTrendingWords();
      
      // Combine recent and trending words
      List<String> allWords = [...recent, ...trending];
      
      // Filter words that start with or contain the query
      List<String> hints = allWords
          .where((word) => 
              word.toLowerCase().contains(query.toLowerCase()) &&
              word.toLowerCase() != query.toLowerCase())
          .take(5)
          .toList();
      
      // Remove duplicates while preserving order
      hints = hints.toSet().toList();
      
      return hints;
    } catch (e) {
      print('Error getting hint words: $e');
      return [];
    }
  }
}
