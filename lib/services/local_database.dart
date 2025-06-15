import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

enum ContentType { flow, loop }

class LikedContent {
  final String id;
  final String title;
  final String extract;
  final String? imageUrl;
  final String contentUrl;
  final int likes;
  final String views;
  final ContentType type;
  final DateTime timestamp;

  LikedContent({
    required this.id,
    required this.title,
    required this.extract,
    this.imageUrl,
    required this.contentUrl,
    required this.likes,
    required this.views,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'extract': extract,
      'imageUrl': imageUrl,
      'contentUrl': contentUrl,
      'likes': likes,
      'views': views,
      'type': type.toString(),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory LikedContent.fromMap(Map<String, dynamic> map) {
    return LikedContent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      extract: map['extract'] ?? '',
      imageUrl: map['imageUrl'],
      contentUrl: map['contentUrl'] ?? '',
      likes: map['likes'] ?? 0,
      views: map['views'] ?? '0',
      type: map['type']?.toString().contains('flow') == true ? ContentType.flow : ContentType.loop,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }
}

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'finity.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE liked_content(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        extract TEXT NOT NULL,
        imageUrl TEXT,
        contentUrl TEXT NOT NULL,
        likes INTEGER NOT NULL DEFAULT 0,
        views TEXT NOT NULL DEFAULT '0',
        type TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // Create search history table
    await db.execute('''
      CREATE TABLE search_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // Create indices for better performance
    await db.execute('''
      CREATE INDEX idx_liked_content_type ON liked_content(type)
    ''');

    await db.execute('''
      CREATE INDEX idx_liked_content_timestamp ON liked_content(timestamp DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_search_history_timestamp ON search_history(timestamp DESC)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns or tables if needed
      try {
        await db.execute('ALTER TABLE liked_content ADD COLUMN views TEXT DEFAULT "0"');
      } catch (e) {
        // Column might already exist
        print('Error adding views column: $e');
      }
    }
  }

  // Liked Content Methods
  Future<bool> insertLikedContent(LikedContent content) async {
    try {
      final db = await database;
      await db.insert(
        'liked_content',
        content.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      print('Error inserting liked content: $e');
      return false;
    }
  }

  Future<bool> deleteLikedContent(String contentId) async {
    try {
      final db = await database;
      final result = await db.delete(
        'liked_content',
        where: 'id = ?',
        whereArgs: [contentId],
      );
      return result > 0;
    } catch (e) {
      print('Error deleting liked content: $e');
      return false;
    }
  }

  Future<bool> isContentLiked(String contentId) async {
    try {
      final db = await database;
      final result = await db.query(
        'liked_content',
        where: 'id = ?',
        whereArgs: [contentId],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking if content is liked: $e');
      return false;
    }
  }

  Future<List<LikedContent>> getAllLikedContent() async {
    try {
      final db = await database;
      final result = await db.query(
        'liked_content',
        orderBy: 'timestamp DESC',
      );
      return result.map((map) => LikedContent.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all liked content: $e');
      return [];
    }
  }

  Future<List<LikedContent>> getLikedContentByType(ContentType type) async {
    try {
      final db = await database;
      final result = await db.query(
        'liked_content',
        where: 'type = ?',
        whereArgs: [type.toString()],
        orderBy: 'timestamp DESC',
      );
      return result.map((map) => LikedContent.fromMap(map)).toList();
    } catch (e) {
      print('Error getting liked content by type: $e');
      return [];
    }
  }

  Future<bool> clearAllLikedContent() async {
    try {
      final db = await database;
      await db.delete('liked_content');
      return true;
    } catch (e) {
      print('Error clearing all liked content: $e');
      return false;
    }
  }

  Future<int> getLikedContentCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM liked_content');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('Error getting liked content count: $e');
      return 0;
    }
  }

  Future<int> getLikedContentCountByType(ContentType type) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM liked_content WHERE type = ?',
        [type.toString()],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('Error getting liked content count by type: $e');
      return 0;
    }
  }

  // Search History Methods
  Future<bool> insertSearchQuery(String query) async {
    if (query.trim().isEmpty) return false;
    
    try {
      final db = await database;
      
      // Remove duplicate if exists
      await db.delete(
        'search_history',
        where: 'query = ?',
        whereArgs: [query.trim()],
      );
      
      // Insert new query
      await db.insert(
        'search_history',
        {
          'query': query.trim(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      
      // Keep only last 50 searches
      final count = await db.rawQuery('SELECT COUNT(*) as count FROM search_history');
      final totalCount = Sqflite.firstIntValue(count) ?? 0;
      
      if (totalCount > 50) {
        await db.rawDelete('''
          DELETE FROM search_history 
          WHERE id NOT IN (
            SELECT id FROM search_history 
            ORDER BY timestamp DESC 
            LIMIT 50
          )
        ''');
      }
      
      return true;
    } catch (e) {
      print('Error inserting search query: $e');
      return false;
    }
  }

  Future<List<String>> getSearchHistory({int limit = 20}) async {
    try {
      final db = await database;
      final result = await db.query(
        'search_history',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return result.map((map) => map['query'] as String).toList();
    } catch (e) {
      print('Error getting search history: $e');
      return [];
    }
  }

  Future<bool> deleteSearchQuery(String query) async {
    try {
      final db = await database;
      final result = await db.delete(
        'search_history',
        where: 'query = ?',
        whereArgs: [query],
      );
      return result > 0;
    } catch (e) {
      print('Error deleting search query: $e');
      return false;
    }
  }

  Future<bool> clearSearchHistory() async {
    try {
      final db = await database;
      await db.delete('search_history');
      return true;
    } catch (e) {
      print('Error clearing search history: $e');
      return false;
    }
  }

  Future<List<String>> searchInHistory(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final db = await database;
      final result = await db.query(
        'search_history',
        where: 'query LIKE ?',
        whereArgs: ['%${query.trim()}%'],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return result.map((map) => map['query'] as String).toList();
    } catch (e) {
      print('Error searching in history: $e');
      return [];
    }
  }

  // Database maintenance methods
  Future<void> vacuum() async {
    try {
      final db = await database;
      await db.execute('VACUUM');
      print('Database vacuum completed');
    } catch (e) {
      print('Error vacuuming database: $e');
    }
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final db = await database;
      
      final likedCount = await db.rawQuery('SELECT COUNT(*) as count FROM liked_content');
      final searchCount = await db.rawQuery('SELECT COUNT(*) as count FROM search_history');
      
      final likedFlowCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM liked_content WHERE type LIKE ?',
        ['%flow%'],
      );
      
      final likedLoopCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM liked_content WHERE type LIKE ?',
        ['%loop%'],
      );
      
      return {
        'total_liked_content': Sqflite.firstIntValue(likedCount) ?? 0,
        'total_search_history': Sqflite.firstIntValue(searchCount) ?? 0,
        'liked_flow_content': Sqflite.firstIntValue(likedFlowCount) ?? 0,
        'liked_loop_content': Sqflite.firstIntValue(likedLoopCount) ?? 0,
        'database_path': await getDatabasesPath(),
      };
    } catch (e) {
      print('Error getting database info: $e');
      return {};
    }
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
