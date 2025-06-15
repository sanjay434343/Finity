import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SearchHistoryService {
  static const String _historyKey = 'search_history';
  static const int _maxHistoryItems = 20;

  // Add search term to history
  Future<void> addSearchTerm(String term) async {
    if (term.trim().isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getSearchHistory();
      
      // Remove if already exists to avoid duplicates
      history.removeWhere((item) => item.toLowerCase() == term.toLowerCase());
      
      // Add to beginning
      history.insert(0, term.trim());
      
      // Keep only latest items
      if (history.length > _maxHistoryItems) {
        history.removeRange(_maxHistoryItems, history.length);
      }
      
      await prefs.setString(_historyKey, json.encode(history));
    } catch (e) {
      print('Error adding search term to history: $e');
    }
  }

  // Get search history
  Future<List<String>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        return historyList.cast<String>();
      }
      
      return [];
    } catch (e) {
      print('Error getting search history: $e');
      return [];
    }
  }

  // Remove specific term from history
  Future<void> removeSearchTerm(String term) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getSearchHistory();
      
      history.removeWhere((item) => item.toLowerCase() == term.toLowerCase());
      await prefs.setString(_historyKey, json.encode(history));
    } catch (e) {
      print('Error removing search term: $e');
    }
  }

  // Clear all search history
  Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }

  // Get filtered history based on query
  Future<List<String>> getFilteredHistory(String query) async {
    if (query.trim().isEmpty) return await getSearchHistory();
    
    final history = await getSearchHistory();
    final lowercaseQuery = query.toLowerCase();
    
    return history.where((term) => 
      term.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }
}
