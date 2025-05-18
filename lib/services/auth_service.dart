import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isNewUser = false; // Flag to track if the user is newly registered

  // Cached user data to avoid excessive Firestore reads
  Map<String, dynamic>? _cachedUserData;
  String? _cachedProfileImageUrl;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;
  bool get isNewUser => _isNewUser; // Getter for the new user flag

  // Constructor
  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Initialize - check if user is already logged in
  Future<void> initialize() async {
    _user = _auth.currentUser;
    
    // Reset the new user flag when initializing
    _isNewUser = false;
    
    notifyListeners();
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update user profile with display name
      await result.user!.updateDisplayName(name);
      
      // Force refresh to get the updated user data
      await result.user!.reload();
      
      // Update the user object
      _user = _auth.currentUser;
      
      // Create user document in Firestore with name
      await _firestore.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Store user data locally
      await _storeUserLocally(result.user!.uid, email, name);
      
      // Set new user flag
      _isNewUser = true;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _handleAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Beklenmeyen bir hata oluştu: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Reset new user flag for sign in
      _isNewUser = false;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _handleAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Beklenmeyen bir hata oluştu: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Reset the new user flag after the user has seen the welcome message
  void clearNewUserFlag() {
    _isNewUser = false;
    notifyListeners();
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      
      // Clear local user data
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      
      _user = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Çıkış yapılırken hata oluştu: ${e.toString()}';
      notifyListeners();
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _handleAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Şifre sıfırlama hatası: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Store user data locally
  Future<void> _storeUserLocally(String uid, String email, String name) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', uid);
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', name);
  }
  
  // Get ID token for API authentication
  Future<String?> getIdToken() async {
    if (_user == null) return null;
    return await _user!.getIdToken();
  }

  // Get user document from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    if (_user == null) return null;
    
    // Return cached data if available
    if (_cachedUserData != null) {
      return _cachedUserData;
    }
    
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _cachedUserData = doc.data() as Map<String, dynamic>?;
        return _cachedUserData;
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Get user's name from Firestore or Firebase Auth
  Future<String?> getUserName() async {
    if (_user == null) return null;
    
    try {
      // First try to get from Firestore
      final userData = await getUserData();
      if (userData != null && userData['name'] != null) {
        return userData['name'];
      }
      
      // If not in Firestore, get from Firebase Auth
      return _user!.displayName;
    } catch (e) {
      print('Error getting user name: $e');
      return _user?.displayName;
    }
  }

  // Get user's profile image URL from Firestore
  Future<String?> getUserProfileImageUrl() async {
    if (_user == null) return null;
    
    // Return cached URL if available
    if (_cachedProfileImageUrl != null) {
      return _cachedProfileImageUrl;
    }
    
    try {
      // Get user data from Firestore
      final userData = await getUserData();
      if (userData != null && userData['profileImageUrl'] != null) {
        _cachedProfileImageUrl = userData['profileImageUrl'] as String;
        return _cachedProfileImageUrl;
      }
      return null;
    } catch (e) {
      print('Error getting user profile image: $e');
      return null;
    }
  }

  // Notify listeners that the user profile has been updated
  void notifyProfileUpdated() {
    // Clear cached data so it will be refreshed on next request
    _cachedUserData = null;
    _cachedProfileImageUrl = null;
    
    // Notify all listeners (e.g., MainScreen, ProfileScreen)
    notifyListeners();
  }

  // Handle Firebase Auth errors
  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        _errorMessage = 'Böyle bir kullanıcı bulunamadı.';
        break;
      case 'wrong-password':
        _errorMessage = 'Şifre hatalı.';
        break;
      case 'email-already-in-use':
        _errorMessage = 'Bu e-posta adresi zaten kullanılıyor.';
        break;
      case 'weak-password':
        _errorMessage = 'Şifre çok zayıf.';
        break;
      case 'invalid-email':
        _errorMessage = 'Geçersiz e-posta adresi.';
        break;
      case 'network-request-failed':
        _errorMessage = 'Ağ hatası. İnternet bağlantınızı kontrol edin.';
        break;
      case 'too-many-requests':
        _errorMessage = 'Çok fazla istek gönderildi. Lütfen daha sonra tekrar deneyin.';
        break;
      default:
        _errorMessage = 'Bir hata oluştu: ${e.message}';
    }
  }
} 