import 'dart:convert';
import 'package:http/http.dart' as http;
import 'language_service.dart';

class SearchService {
  final LanguageService _languageService = LanguageService();
  
  // Search Wikipedia articles in the selected language
  Future<List<Map<String, dynamic>>> searchWikipedia(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final languageCode = _languageService.wikipediaLanguageCode;
      final encodedQuery = Uri.encodeComponent(query.trim());
      
      // Use Wikipedia search API with language support
      final searchUrl = 'https://$languageCode.wikipedia.org/api/rest_v1/page/summary/$encodedQuery';
      final listUrl = 'https://$languageCode.wikipedia.org/w/api.php?action=query&list=search&srsearch=$encodedQuery&format=json&srlimit=$limit';
      
      print('Searching Wikipedia in language: $languageCode');
      print('Search URL: $listUrl');
      
      // First get search results list
      final listResponse = await http.get(
        Uri.parse(listUrl),
        headers: {
          'User-Agent': 'Finity/1.0 (https://finity.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (listResponse.statusCode != 200) {
        throw Exception('Search failed with status: ${listResponse.statusCode}');
      }

      final listData = json.decode(listResponse.body);
      final searchResults = listData['query']?['search'] as List? ?? [];
      
      if (searchResults.isEmpty) {
        print('No search results found for: $query');
        return [];
      }

      // Get detailed info for each result
      final List<Map<String, dynamic>> results = [];
      
      for (final result in searchResults.take(limit)) {
        try {
          final title = result['title'] as String? ?? '';
          final snippet = result['snippet'] as String? ?? '';
          
          if (title.isEmpty) continue;
          
          // Get page summary for the specific title
          final summaryUrl = 'https://$languageCode.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}';
          final summaryResponse = await http.get(
            Uri.parse(summaryUrl),
            headers: {
              'User-Agent': 'Finity/1.0 (https://finity.app)',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 5));

          Map<String, dynamic> articleData = {
            'id': title.hashCode.abs().toString(),
            'title': title,
            'extract': _cleanHtmlText(snippet),
            'url': 'https://$languageCode.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
            'language': languageCode,
            'source': 'Wikipedia',
            'type': 'search_result',
            'likes': 0,
            'views': 0,
          };

          if (summaryResponse.statusCode == 200) {
            final summaryData = json.decode(summaryResponse.body);
            
            // Update with detailed info
            articleData.addAll({
              'extract': summaryData['extract'] ?? _cleanHtmlText(snippet),
              'image': summaryData['thumbnail']?['source'],
              'description': summaryData['description'] ?? '',
            });
          }

          results.add(articleData);
          
          // Small delay to avoid overwhelming the API
          await Future.delayed(const Duration(milliseconds: 100));
          
        } catch (e) {
          print('Error processing search result: $e');
          continue;
        }
      }

      print('Search completed. Found ${results.length} results for: $query');
      return results;
      
    } catch (e) {
      print('Search error: $e');
      throw Exception('Search failed: ${e.toString()}');
    }
  }

  // Search suggestions for autocomplete
  Future<List<String>> getSearchSuggestions(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final languageCode = _languageService.wikipediaLanguageCode;
      final encodedQuery = Uri.encodeComponent(query.trim());
      
      final url = 'https://$languageCode.wikipedia.org/w/api.php?action=opensearch&search=$encodedQuery&limit=$limit&namespace=0&format=json';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Finity/1.0 (https://finity.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.length > 1 && data[1] is List) {
          return (data[1] as List).cast<String>().take(limit).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error getting search suggestions: $e');
      return [];
    }
  }

  // Clean HTML text from search snippets
  String _cleanHtmlText(String htmlText) {
    if (htmlText.isEmpty) return '';
    
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single space
        .trim();
  }

  // Get trending/popular search terms in the current language
  Future<List<String>> getTrendingSearches() async {
    try {
      final languageCode = _languageService.wikipediaLanguageCode;
      
      // Get popular pages for the language
      final url = 'https://$languageCode.wikipedia.org/api/rest_v1/metrics/pageviews/top/$languageCode.wikipedia/all-access/2024/01/01';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Finity/1.0 (https://finity.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = data['items']?[0]?['articles'] as List? ?? [];
        
        return articles
            .take(10)
            .map((article) => article['article'] as String? ?? '')
            .where((title) => title.isNotEmpty && !title.startsWith('Main_Page'))
            .map((title) => title.replaceAll('_', ' '))
            .toList();
      }
      
      // Fallback trending terms by language
      return _getFallbackTrendingTerms(languageCode);
      
    } catch (e) {
      print('Error getting trending searches: $e');
      return _getFallbackTrendingTerms(_languageService.wikipediaLanguageCode);
    }
  }

  // Fallback trending terms for different languages
  List<String> _getFallbackTrendingTerms(String languageCode) {
    final terms = <String, List<String>>{
      'en': ['Technology', 'Science', 'History', 'Geography', 'Literature', 'Art', 'Music', 'Sports'],
      'es': ['Tecnología', 'Ciencia', 'Historia', 'Geografía', 'Literatura', 'Arte', 'Música', 'Deportes'],
      'fr': ['Technologie', 'Science', 'Histoire', 'Géographie', 'Littérature', 'Art', 'Musique', 'Sports'],
      'de': ['Technologie', 'Wissenschaft', 'Geschichte', 'Geographie', 'Literatur', 'Kunst', 'Musik', 'Sport'],
      'it': ['Tecnologia', 'Scienza', 'Storia', 'Geografia', 'Letteratura', 'Arte', 'Musica', 'Sport'],
      'pt': ['Tecnologia', 'Ciência', 'História', 'Geografia', 'Literatura', 'Arte', 'Música', 'Esportes'],
      'ru': ['Технологии', 'Наука', 'История', 'География', 'Литература', 'Искусство', 'Музыка', 'Спорт'],
      'zh': ['技术', '科学', '历史', '地理', '文学', '艺术', '音乐', '体育'],
      'ja': ['技術', '科学', '歴史', '地理', '文学', '芸術', '音楽', 'スポーツ'],
      'ko': ['기술', '과학', '역사', '지리', '문학', '예술', '음악', '스포츠'],
      'ar': ['تكنولوجيا', 'علوم', 'تاريخ', 'جغرافيا', 'أدب', 'فن', 'موسيقى', 'رياضة'],
      'hi': ['प्रौद्योगिकी', 'विज्ञान', 'इतिहास', 'भूगोल', 'साहित्य', 'कला', 'संगीत', 'खेल'],
      'ta': ['தொழில்நுட்பம்', 'அறிவியல்', 'வரலாறு', 'புவியியல்', 'இலக்கியம்', 'கலை', 'இசை', 'விளையாட்டு'],
    };
    
    return terms[languageCode] ?? terms['en']!;
  }
}
