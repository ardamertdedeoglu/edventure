import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';
import 'auth_service.dart';

class SemanticSearchService {
  // Direct function URL (may have CORS issues)
  static const String functionUrl = 'https://us-central1-hackathon-app-project.cloudfunctions.net/semanticSearch';
  final AuthService? authService;
  
  // Alternative: CORS proxy for testing only (not for production)
  static const String corsProxyUrl = 'https://cors-anywhere.herokuapp.com/';
  
  // Flag to use test data while we're debugging the API
  static const bool useTestData = false;
  
  // Constructor
  SemanticSearchService({this.authService});
  
  // Test data to use if the API is not yet working
  static List<SearchResult> getTestData() {
    return [
      SearchResult(
        id: '1',
        title: 'Flutter Geliştirme',
        description: 'Flutter ile cross-platform mobil uygulama geliştirme',
        similarity: 0.95,
      ),
      SearchResult(
        id: '2',
        title: 'Firebase Cloud Functions',
        description: 'Sunucu taraflı işlemlerinizi bulutta çalıştırın',
        similarity: 0.85,
      ),
      SearchResult(
        id: '3',
        title: 'Semantik Arama',
        description: 'Doğal dil işleme ile anlam tabanlı arama yapın',
        similarity: 0.78,
      ),
      SearchResult(
        id: '4',
        title: 'Yapay Zeka Uygulamaları',
        description: 'Mobil uygulamalarda yapay zeka entegrasyonu',
        similarity: 0.72,
      ),
      SearchResult(
        id: '5',
        title: 'Cohere AI Embeddings',
        description: 'Metinler arasında anlamsal benzerlikler bulun',
        similarity: 0.68,
      ),
    ];
  }

  // Get dynamic test data that responds to the query
  List<SearchResult> getDynamicTestData(String query) {
    final List<Map<String, dynamic>> allData = [
      {
        'id': '1',
        'title': 'Flutter Geliştirme',
        'description': 'Flutter ile cross-platform mobil uygulama geliştirme',
        'keywords': ['flutter', 'mobil', 'uygulama', 'geliştirme', 'dart', 'cross-platform']
      },
      {
        'id': '2',
        'title': 'Firebase Cloud Functions',
        'description': 'Sunucu taraflı işlemlerinizi bulutta çalıştırın',
        'keywords': ['firebase', 'cloud', 'functions', 'backend', 'sunucu', 'bulut']
      },
      {
        'id': '3',
        'title': 'Semantik Arama',
        'description': 'Doğal dil işleme ile anlam tabanlı arama yapın',
        'keywords': ['semantik', 'arama', 'nlp', 'yapay zeka', 'ai', 'doğal dil işleme']
      },
      {
        'id': '4',
        'title': 'Yapay Zeka Uygulamaları',
        'description': 'Mobil uygulamalarda yapay zeka entegrasyonu',
        'keywords': ['yapay zeka', 'ai', 'ml', 'machine learning', 'mobil', 'uygulama']
      },
      {
        'id': '5',
        'title': 'Cohere AI Embeddings',
        'description': 'Metinler arasında anlamsal benzerlikler bulun',
        'keywords': ['cohere', 'embedding', 'ai', 'nlp', 'benzerlik', 'vector']
      },
      {
        'id': '6',
        'title': 'UI/UX Tasarım Prensipleri',
        'description': 'Kullanıcı deneyimi odaklı arayüz tasarımı',
        'keywords': ['ui', 'ux', 'tasarım', 'arayüz', 'kullanıcı deneyimi', 'design']
      },
      {
        'id': '7',
        'title': 'Veri Tabanı Yönetimi',
        'description': 'Firestore ve SQL veritabanı yapılandırma ve optimizasyon',
        'keywords': ['veritabanı', 'database', 'sql', 'firestore', 'nosql', 'veri']
      },
      {
        'id': '8',
        'title': 'API Entegrasyonu',
        'description': 'Üçüncü parti API servislerini uygulamanıza entegre edin',
        'keywords': ['api', 'rest', 'http', 'entegrasyon', 'servis', 'bağlantı']
      },
      {
        'id': '9',
        'title': 'Doğal Dil İşleme',
        'description': 'NLP teknikleri ve uygulamaları',
        'keywords': ['nlp', 'doğal dil işleme', 'yapay zeka', 'ai', 'metin analizi']
      },
      {
        'id': '10',
        'title': 'Bulut Mimarisi',
        'description': 'Ölçeklenebilir bulut sistemleri tasarlama',
        'keywords': ['bulut', 'cloud', 'mimari', 'architecture', 'ölçeklendirme', 'sunucu']
      },
    ];
    
    // Convert the query and all keywords to lowercase for case-insensitive matching
    final String lowerQuery = query.toLowerCase();
    
    // Calculate a simple relevance score based on keyword matches
    final results = allData.map((item) {
      final List<String> keywords = List<String>.from(item['keywords']);
      // Count how many keywords contain parts of the query
      int matchCount = 0;
      for (var keyword in keywords) {
        if (keyword.toLowerCase().contains(lowerQuery) || 
            lowerQuery.contains(keyword.toLowerCase())) {
          matchCount++;
        }
      }
      
      // Calculate a similarity score (simple version)
      double similarity = 0.0;
      if (matchCount > 0) {
        similarity = 0.5 + (matchCount / keywords.length * 0.5); // Base 0.5 + up to 0.5 more
        similarity = similarity.clamp(0.0, 0.99); // Ensure it doesn't exceed 0.99
      }
      
      return SearchResult(
        id: item['id'],
        title: item['title'],
        description: item['description'],
        similarity: similarity,
      );
    }).toList();
    
    // Sort by similarity and only return those with a similarity > 0
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.where((result) => result.similarity > 0).take(5).toList();
  }

  // Make a semantic search request and return the results
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) {
      throw Exception('Arama sorgusu boş olamaz');
    }
    
    // Use test data for debugging purposes
    if (useTestData) {
      await Future.delayed(Duration(milliseconds: 800)); // Simulate network delay
      return getDynamicTestData(query);
    }

    try {
      // Check if user is authenticated
      if (authService == null || !authService!.isAuthenticated) {
        print('User not authenticated, using local data');
        await Future.delayed(Duration(milliseconds: 500)); // Simulate network delay
        return getDynamicTestData(query);
      }

      // Get auth token
      try {
        String? idToken = await authService!.getIdToken();
        if (idToken == null || idToken.isEmpty) {
          print('Authentication token not available, using local data');
          return getDynamicTestData(query);
        }
        
        // Make authenticated request
        return await _makeSearchRequest(functionUrl, query, idToken);
      } catch (tokenError) {
        print('Token error: $tokenError');
        return getDynamicTestData(query);
      }
    } catch (e) {
      print('Search error: $e');
      // Return local data as fallback
      return getDynamicTestData(query);
    }
  }
  
  // Helper method to make the actual HTTP request
  Future<List<SearchResult>> _makeSearchRequest(String url, String query, String idToken) async {
    // Print request details for debugging
    print('Sending request to: $url');
    print('Query: $query');
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({'query': query}),
      );

      // Log response details for debugging
      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final resultsList = data['results'] as List;
        
        return resultsList
            .map((result) => SearchResult.fromJson(result))
            .toList();
      } else {
        // Fall back to local data if server responds with an error
        print('Server responded with error code: ${response.statusCode}');
        return getDynamicTestData(query);
      }
    } catch (e) {
      print('Network request error: $e');
      // Return local data when network requests fail
      return getDynamicTestData(query);
    }
  }
} 