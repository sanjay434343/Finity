import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  bool _isFirebaseInitialized = false;
  bool _isAuthenticated = false;
  String? _currentUserId;
  String? _currentUserEmail;
  String? _currentUserName;
  String? _currentUserPhotoUrl;

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/userinfo.email',
    ],
  );

  AuthService({bool firebaseEnabled = false}) {
    _initializeFirebase(firebaseEnabled);
    _loadAuthState();
  }

  void _initializeFirebase(bool firebaseEnabled) {
    try {
      if (firebaseEnabled && Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
        _isFirebaseInitialized = true;
        print('AuthService: Firebase Auth initialized successfully');
      } else {
        _isFirebaseInitialized = false;
        print('AuthService: Firebase not available, using fallback auth only');
      }
    } catch (e) {
      print('AuthService: Firebase Auth initialization error: $e');
      _isFirebaseInitialized = false;
    }
  }

  // Getters
  User? get currentUser => _isFirebaseInitialized ? _auth?.currentUser : null;
  bool get isLoggedIn => _isFirebaseInitialized ? currentUser != null : _isAuthenticated;
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserName => _currentUserName;
  String? get currentUserPhotoUrl => _currentUserPhotoUrl;

  Future<void> _loadAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = prefs.getBool('isLoggedIn') ?? false;
      _currentUserId = prefs.getString('userId') ?? prefs.getString('uid');
      _currentUserEmail = prefs.getString('user_email');
      _currentUserName = prefs.getString('user_name');
      _currentUserPhotoUrl = prefs.getString('user_photo_url');
      
      print('Auth state loaded: authenticated=$_isAuthenticated, email=$_currentUserEmail, uid=$_currentUserId');
      
      // More lenient validation - only check if we have basic authentication
      if (_isAuthenticated && _currentUserId != null && _currentUserId!.isNotEmpty) {
        print('Valid authentication state found');
        notifyListeners();
        return;
      }
      
      // If authentication data is incomplete, clear it
      if (_isAuthenticated && (_currentUserId == null || _currentUserEmail == null)) {
        print('Authentication state invalid, clearing...');
        await _clearLocalState();
        return;
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading auth state: $e');
    }
  }

  // Add method to validate current authentication with more lenient criteria
  Future<bool> validateAuthentication() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final userId = prefs.getString('userId') ?? prefs.getString('uid');
      
      // Authentication is valid if logged in and has a user ID
      final isValid = isLoggedIn && userId != null && userId.isNotEmpty;
      
      print('Authentication validation: $isValid (isLoggedIn: $isLoggedIn, userId: $userId)');
      return isValid;
    } catch (e) {
      print('Error validating authentication: $e');
      return false;
    }
  }

  // Add method to get comprehensive auth status
  Future<Map<String, dynamic>> getAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final status = {
        'isAuthenticated': _isAuthenticated,
        'isLoggedIn': prefs.getBool('isLoggedIn') ?? false,
        'userId': _currentUserId,
        'storedUserId': prefs.getString('userId'),
        'storedUid': prefs.getString('uid'),
        'userEmail': _currentUserEmail,
        'userName': _currentUserName,
        'hasValidSession': await validateAuthentication(),
      };
      
      print('Auth status: $status');
      return status;
    } catch (e) {
      print('Error getting auth status: $e');
      return {'hasValidSession': false};
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    print('Starting Google Sign-In process...');
    print('Firebase initialized: $_isFirebaseInitialized');
    
    try {
      // Force account selection by signing out first (with error handling)
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
          print('Signed out from previous session');
        }
      } catch (e) {
        print('Sign out error (non-critical): $e');
      }
      
      // Try to disconnect to clear cached credentials (with error handling)
      try {
        await _googleSignIn.disconnect();
        print('Disconnected cached credentials');
      } catch (e) {
        print('Disconnect error (non-critical): $e');
      }
      
      // Trigger the authentication flow with account selection
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign-In was cancelled by user');
        return {'success': false, 'message': 'Sign-in was cancelled'};
      }

      print('Google account selected: ${googleUser.email}');
      print('User display name: ${googleUser.displayName}');
      print('User photo URL: ${googleUser.photoUrl}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Failed to get Google authentication tokens');
        return {'success': false, 'message': 'Failed to get authentication tokens'};
      }

      print('Google authentication tokens received successfully');

      // ALWAYS USE FALLBACK AUTHENTICATION (bypassing Firebase due to casting issues)
      print('Using fallback authentication due to Firebase casting issues');
      
      // Generate a unique UID from Google user ID and timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fallbackUid = 'finity_${googleUser.id}_$timestamp';
      
      _currentUserId = fallbackUid;
      _currentUserEmail = googleUser.email;
      _currentUserName = googleUser.displayName ?? '';
      _currentUserPhotoUrl = googleUser.photoUrl ?? '';
      
      // Store user information with fallback UID
      await _storeUserInfo(googleUser, fallbackUid);
      
      // Set authentication state
      _isAuthenticated = true;
      
      // Persist authentication state with fallback UID
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', _currentUserId!);
      await prefs.setString('user_email', _currentUserEmail!);
      await prefs.setString('user_name', _currentUserName!);
      await prefs.setString('user_display_name', _currentUserName!); // Store with both keys
      await prefs.setString('user_photo_url', _currentUserPhotoUrl!);
      await prefs.setString('uid', fallbackUid); // Store as 'uid' key
      await prefs.setString('user_uid', fallbackUid); // Store with both keys for compatibility
      await prefs.setString('fallback_uid', fallbackUid); // Store fallback UID
      
      notifyListeners();
      
      print('Fallback authentication completed successfully for ${_currentUserEmail}');
      print('Generated fallback UID: $fallbackUid');
      
      return {
        'success': true, 
        'message': 'Welcome ${_currentUserName}!',
        'user': {
          'id': _currentUserId,
          'email': _currentUserEmail,
          'name': _currentUserName,
          'photoUrl': _currentUserPhotoUrl,
          'uid': fallbackUid,
        }
      };
      
    } catch (e) {
      print('Google Sign-In error: $e');
      
      // Check for specific error types
      if (e.toString().contains('sign_in_canceled') || 
          e.toString().contains('cancelled') ||
          e.toString().contains('SIGN_IN_CANCELLED')) {
        return {'success': false, 'message': 'Sign-in cancelled by user'};
      }
      
      return {'success': false, 'message': 'Sign-in failed. Please check your internet connection and try again.'};
    }
  }

  Future<void> _storeUserInfo(GoogleSignInAccount googleUser, String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', googleUser.email);
      await prefs.setString('user_name', googleUser.displayName ?? '');
      await prefs.setString('user_display_name', googleUser.displayName ?? ''); // Store with both keys
      await prefs.setString('user_photo_url', googleUser.photoUrl ?? '');
      await prefs.setString('user_id', googleUser.id);
      await prefs.setString('uid', uid); // Store as 'uid' key
      await prefs.setString('user_uid', uid); // Store with both keys for compatibility
      await prefs.setString('fallback_uid', uid); // Store fallback UID
      
      print('User info stored in SharedPreferences with UID: $uid');
      print('Stored user_name: ${googleUser.displayName}');
      print('Stored user_email: ${googleUser.email}');
      print('Stored user_photo_url: ${googleUser.photoUrl}');
    } catch (e) {
      print('Error storing user info: $e');
    }
  }

  // Update getter for UID with fallback
  String? get firebaseUid {
    // Always return the current user ID as UID (fallback)
    return _currentUserId;
  }

  // Add getter for UID from SharedPreferences
  Future<String?> getStoredUid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('uid') ?? prefs.getString('fallback_uid');
    } catch (e) {
      print('Error getting stored UID: $e');
      return null;
    }
  }

  // Legacy login method for fallback
  Future<bool> login(String username, String password) async {
    if (username.isNotEmpty && password.length >= 4) {
      _isAuthenticated = true;
      _currentUserId = username;
      _currentUserEmail = username.contains('@') ? username : '$username@demo.com';
      _currentUserName = username;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', username);
      await prefs.setString('user_email', _currentUserEmail!);
      await prefs.setString('user_name', _currentUserName!);
      
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    try {
      print('Starting logout process...');
      
      // Sign out from Google (with error handling)
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
          print('Google sign-out completed');
        }
      } catch (e) {
        print('Google sign-out error (non-critical): $e');
        // Continue with logout even if Google sign-out fails
      }
      
      // Try to disconnect (with error handling)
      try {
        await _googleSignIn.disconnect();
        print('Google disconnect completed');
      } catch (e) {
        print('Google disconnect error (non-critical): $e');
        // Continue with logout even if disconnect fails
      }
      
      // Sign out from Firebase (with error handling)
      try {
        if (_isFirebaseInitialized && _auth != null) {
          await _auth!.signOut();
          print('Firebase sign-out completed');
        }
      } catch (e) {
        print('Firebase sign-out error (non-critical): $e');
        // Continue with logout even if Firebase sign-out fails
      }
      
      // Clear local state (this should always work)
      await _clearLocalState();
      
      print('Logout completed successfully');
    } catch (e) {
      print('Logout error: $e');
      // Always clear local state even if remote logout fails
      await _clearLocalState();
    }
  }

  Future<void> _clearLocalState() async {
    try {
      _isAuthenticated = false;
      _currentUserId = null;
      _currentUserEmail = null;
      _currentUserName = null;
      _currentUserPhotoUrl = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userId');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_display_name'); // Clear both keys
      await prefs.remove('user_photo_url');
      await prefs.remove('user_id');
      await prefs.remove('uid'); // Clear UID
      await prefs.remove('user_uid'); // Clear both UID keys
      await prefs.remove('fallback_uid'); // Clear fallback UID
      await prefs.remove('firebase_uid'); // Clear Firebase UID if exists
      // Note: Don't clear 'has_seen_onboarding' so user doesn't see onboarding again
      
      notifyListeners();
      print('Local auth state cleared including all UID keys');
    } catch (e) {
      print('Error clearing local state: $e');
    }
  }
}
