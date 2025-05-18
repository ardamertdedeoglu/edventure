import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/search_result.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Add a program to user's favorites
  Future<bool> addToFavorites(String userId, SearchResult program) async {
    try {
      // Get current favorites first to check if it already exists
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      // Convert to Map and check if favorites array exists
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      List<dynamic> favorites = userData['favorites'] ?? [];
      
      // Check if program already exists in favorites
      bool alreadyExists = favorites.any((favorite) => favorite['id'] == program.id);
      if (alreadyExists) {
        return true; // Already in favorites, no need to add again
      }
      
      // Add to favorites array - use client-side timestamp instead of server timestamp
      await _firestore.collection('users').doc(userId).update({
        'favorites': FieldValue.arrayUnion([{
          'id': program.id,
          'title': program.title,
          'description': program.description,
          'similarity': program.similarity,
          'timestamp': DateTime.now().millisecondsSinceEpoch, // Use client timestamp instead
        }])
      });
      
      return true;
    } catch (e) {
      print('Error adding to favorites: $e');
      return false;
    }
  }
  
  // Remove a program from user's favorites
  Future<bool> removeFromFavorites(String userId, String programId) async {
    try {
      // Get current favorites to find the one to remove
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      // Convert to Map and check if favorites array exists
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      List<dynamic> favorites = userData['favorites'] ?? [];
      
      // Find the program to remove
      Map<String, dynamic>? programToRemove;
      for (var favorite in favorites) {
        if (favorite['id'] == programId) {
          programToRemove = Map<String, dynamic>.from(favorite);
          break;
        }
      }
      
      // If program found, remove it
      if (programToRemove != null) {
        await _firestore.collection('users').doc(userId).update({
          'favorites': FieldValue.arrayRemove([programToRemove])
        });
        return true;
      }
      
      return false; // Program not found in favorites
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }
  
  // Check if a program is in user's favorites
  Future<bool> isInFavorites(String userId, String programId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      // Convert to Map and check if favorites array exists
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      List<dynamic> favorites = userData['favorites'] ?? [];
      
      // Check if program exists in favorites
      return favorites.any((favorite) => favorite['id'] == programId);
    } catch (e) {
      print('Error checking favorites: $e');
      return false;
    }
  }
  
  // Get all user's favorite programs
  Future<List<SearchResult>> getFavorites(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      // Convert to Map and check if favorites array exists
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      List<dynamic> favorites = userData['favorites'] ?? [];
      
      // Convert to List<SearchResult>
      return favorites.map<SearchResult>((favorite) {
        return SearchResult(
          id: favorite['id'],
          title: favorite['title'],
          description: favorite['description'],
          similarity: favorite['similarity'] ?? 0.0,
        );
      }).toList();
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }
} 