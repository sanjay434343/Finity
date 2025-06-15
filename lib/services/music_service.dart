import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isPlaying = false;
  String? _currentMusicUrl;
  String? _currentContentId;
  
  // Music cache
  final List<String> _musicCache = [];
  bool _isLoadingMusic = false;
  int _currentMusicIndex = -1;
  
  // Music search terms
  final List<String> _musicSearchTerms = [
    'ambient', 'piano', 'classical piano', 'meditation', 'study music',
    'nature sounds', 'cafe music', 'focus music', 'calm music',
    'peaceful', 'minimal', 'downtempo', 'atmospheric', 'spa music'
  ];

  // Map to store specific music URLs for each content
  final Map<String, String> _contentMusicMap = {};
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isPlaying => _isPlaying;
  bool get isLoadingMusic => _isLoadingMusic;
  String? get currentContentId => _currentContentId;
  String? get currentMusicUrl => _currentMusicUrl;
  int get cacheSize => _musicCache.length;
  List<String> get musicCache => _musicCache;
  int get currentMusicIndex => _currentMusicIndex;

  // Setters
  set isLoadingMusic(bool value) => _isLoadingMusic = value;
  set currentMusicIndex(int value) => _currentMusicIndex = value;

  // Initialize the music service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Stop any existing player first
      await dispose();
      
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer!.setVolume(0.3);
      
      // Set up listeners
      _audioPlayer!.onPlayerStateChanged.listen((PlayerState state) {
        _isPlaying = state == PlayerState.playing;
      });

      _audioPlayer!.onPlayerComplete.listen((_) {
        _isPlaying = false;
        // Auto-play next track if not muted
        if (!_isMuted && _currentContentId != null) {
          _playNextTrack();
        }
      });

      _isInitialized = true;
      print('MusicService: Initialized successfully');
      
      // Start loading music cache
      _loadMusicCache();
    } catch (e) {
      print('MusicService: Initialization error: $e');
      _isInitialized = false;
    }
  }

  // Dispose and cleanup
  Future<void> dispose() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }
      
      _isInitialized = false;
      _isPlaying = false;
      _currentMusicUrl = null;
      _currentContentId = null;
      
      print('MusicService: Disposed successfully');
    } catch (e) {
      print('MusicService: Dispose error: $e');
    }
  }

  // Force stop all audio
  Future<void> forceStopAll() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        _isPlaying = false;
        _currentMusicUrl = null;
        _currentContentId = null;
      }
      print('MusicService: Force stopped all audio');
    } catch (e) {
      print('MusicService: Force stop error: $e');
    }
  }

  // Play music for specific content
  Future<void> playMusicForContent(String contentId, String contentTitle) async {
    if (!_isInitialized || _isMuted) return;
    
    // If same content is already playing, don't restart
    if (_currentContentId == contentId && _isPlaying) {
      return;
    }
    
    try {
      // Stop current music first
      await forceStopAll();
      
      _currentContentId = contentId;
      
      // Get music URL for this content
      String? musicUrl = _getNextCachedMusic();
      if (musicUrl != null) {
        await _playSpecificMusic(musicUrl);
        print('MusicService: Playing music for content: $contentId');
      } else {
        print('MusicService: No music available for content: $contentId');
      }
    } catch (e) {
      print('MusicService: Error playing music for content: $e');
    }
  }

  // Play specific music URL
  Future<void> _playSpecificMusic(String musicUrl) async {
    if (!_isInitialized || _audioPlayer == null || _isMuted) return;
    
    try {
      await _audioPlayer!.stop();
      await _audioPlayer!.play(UrlSource(musicUrl));
      _currentMusicUrl = musicUrl;
      _isPlaying = true;
      print('MusicService: Started playing: $musicUrl');
    } catch (e) {
      print('MusicService: Error playing specific music: $e');
      _isPlaying = false;
    }
  }

  // Play music method
  Future<void> playMusic(String musicUrl) async {
    await _playSpecificMusic(musicUrl);
  }

  // Play next track in cache
  Future<void> _playNextTrack() async {
    String? nextUrl = _getNextCachedMusic();
    if (nextUrl != null) {
      await _playSpecificMusic(nextUrl);
    }
  }

  // Get next cached music
  String? _getNextCachedMusic() {
    if (_musicCache.isEmpty) return null;
    _currentMusicIndex = (_currentMusicIndex + 1) % _musicCache.length;
    return _musicCache[_currentMusicIndex];
  }

  // Toggle mute
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    
    if (_isMuted) {
      await pauseMusic();
    } else {
      await resumeMusic();
    }
    
    print('MusicService: Mute toggled to: $_isMuted');
  }

  // Pause music
  Future<void> pauseMusic() async {
    if (!_isInitialized || _audioPlayer == null) return;
    
    try {
      await _audioPlayer!.pause();
      _isPlaying = false;
      print('MusicService: Music paused');
    } catch (e) {
      print('MusicService: Error pausing music: $e');
    }
  }

  // Resume music
  Future<void> resumeMusic() async {
    if (!_isInitialized || _audioPlayer == null || _isMuted) return;
    
    try {
      if (_currentMusicUrl != null) {
        await _audioPlayer!.resume();
        _isPlaying = true;
        print('MusicService: Music resumed');
      } else if (_currentContentId != null) {
        // Start new music if no current URL
        String? musicUrl = _getNextCachedMusic();
        if (musicUrl != null) {
          await _playSpecificMusic(musicUrl);
        }
      }
    } catch (e) {
      print('MusicService: Error resuming music: $e');
    }
  }

  // Stop music
  Future<void> stopMusic() async {
    if (!_isInitialized || _audioPlayer == null) return;
    
    try {
      await _audioPlayer!.stop();
      _isPlaying = false;
      _currentMusicUrl = null;
      _currentContentId = null;
      print('MusicService: Music stopped');
    } catch (e) {
      print('MusicService: Error stopping music: $e');
    }
  }

  // Load music cache
  Future<void> _loadMusicCache() async {
    if (_isLoadingMusic) return;
    
    _isLoadingMusic = true;
    print('MusicService: Loading music cache...');
    
    try {
      // Load initial batch quickly
      while (_musicCache.length < 5) {
        final randomTerm = _musicSearchTerms[Random().nextInt(_musicSearchTerms.length)];
        final url = await _fetchAppleMusicByTerm(randomTerm);
        if (url != null && !_musicCache.contains(url)) {
          _musicCache.add(url);
          print('MusicService: Cached music track ${_musicCache.length}');
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Continue loading in background
      _loadMoreMusicInBackground();
    } catch (e) {
      print('MusicService: Error loading music cache: $e');
    } finally {
      _isLoadingMusic = false;
    }
  }

  // Load more music in background
  void _loadMoreMusicInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      while (_musicCache.length < 15) {
        try {
          final randomTerm = _musicSearchTerms[Random().nextInt(_musicSearchTerms.length)];
          final url = await _fetchAppleMusicByTerm(randomTerm);
          if (url != null && !_musicCache.contains(url)) {
            _musicCache.add(url);
            print('MusicService: Background cached music track ${_musicCache.length}');
          }
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('MusicService: Error loading background music: $e');
          break;
        }
      }
    });
  }

  // Fetch music from Apple Music API
  Future<String?> _fetchAppleMusicByTerm(String searchTerm) async {
    try {
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(searchTerm)}&media=music&limit=5&explicit=no'),
        headers: {'User-Agent': 'Finity-Music/1.0'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final results = data['results'] as List;
          final randomResult = results[Random().nextInt(results.length)];
          return randomResult['previewUrl'];
        }
      }
    } catch (e) {
      print('MusicService: Error fetching music: $e');
    }
    return null;
  }

  // New method to play music for specific content on repeat
  Future<void> playMusicForContentOnRepeat(String contentId, String contentTitle) async {
    if (isMuted || !isInitialized) return;
    
    try {
      // Check if this content already has a specific song assigned
      String? musicUrl = _contentMusicMap[contentId];
      
      // If no song assigned or current song is different, assign a new one
      if (musicUrl == null) {
        // Get a random song from cache for this content
        if (musicCache.isNotEmpty) {
          final randomIndex = contentId.hashCode.abs() % musicCache.length;
          musicUrl = musicCache[randomIndex];
          _contentMusicMap[contentId] = musicUrl; // Store the mapping
        } else {
          // If no cache, try to fetch a new song
          musicUrl = await _fetchRandomMusic();
          if (musicUrl != null) {
            _contentMusicMap[contentId] = musicUrl;
            if (!musicCache.contains(musicUrl)) {
              musicCache.add(musicUrl);
            }
          }
        }
      }
      
      // Only change music if we're switching to a different content
      if (_currentContentId != contentId && musicUrl != null) {
        _currentContentId = contentId;
        
        await _audioPlayer!.stop();
        await _audioPlayer!.setReleaseMode(ReleaseMode.loop); // Set to repeat the same song
        await _audioPlayer!.play(UrlSource(musicUrl));
        
        _isPlaying = true;
        print('Playing music for content: $contentTitle (repeating)');
      } else if (_currentContentId == contentId && !_isPlaying && musicUrl != null) {
        // Same content but music is not playing, resume it
        await _audioPlayer!.resume();
        _isPlaying = true;
      }
      
    } catch (e) {
      print('Error playing music for content on repeat: $e');
      _isPlaying = false;
    }
  }

  // Method to clear content music mappings when needed
  void clearContentMusicMappings() {
    _contentMusicMap.clear();
    _currentContentId = null;
  }

  // Update existing clearMusicCache method
  void clearMusicCache() {
    musicCache.clear();
    _contentMusicMap.clear(); // Also clear content mappings
    _currentContentId = null;
    currentMusicIndex = 0;
  }

  // Helper method to fetch random music
  Future<String?> _fetchRandomMusic() async {
    final searchTerms = [
      'ambient', 'piano', 'classical piano', 'meditation', 'study music',
      'nature sounds', 'cafe music', 'focus music', 'calm music',
      'peaceful', 'minimal', 'downtempo', 'atmospheric', 'spa music'
    ];
    
    try {
      final randomTerm = searchTerms[Random().nextInt(searchTerms.length)];
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(randomTerm)}&media=music&limit=5&explicit=no'),
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
      print('Error fetching random music: $e');
    }
    return null;
  }

  // Get service status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isMuted': _isMuted,
      'isPlaying': _isPlaying,
      'isLoadingMusic': _isLoadingMusic,
      'cacheSize': _musicCache.length,
      'currentContentId': _currentContentId,
      'currentMusicUrl': _currentMusicUrl,
    };
  }
}
