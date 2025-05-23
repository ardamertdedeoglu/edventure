import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/program.dart';
import '../models/search_result.dart';

class ProgramService {
  List<Program> _programs = [];
  
  // Load programs from JSON file
  Future<void> loadPrograms() async {
    try {
      final String response = await rootBundle.loadString('lib/data/programs.json');
      final List<dynamic> jsonData = json.decode(response) as List<dynamic>;
      
      _programs = jsonData
          .map((json) => Program.fromJson(json as Map<String, dynamic>))
          .toList();
      
      print('Loaded ${_programs.length} programs');
    } catch (e) {
      print('Error loading programs: $e');
      _programs = [];
    }
  }
  
  // Get all programs
  List<Program> getAllPrograms() {
    return _programs;
  }
  
  // Simple semantic search based on keyword matching
  List<SearchResult> searchPrograms(String query) {
    if (_programs.isEmpty) {
      return [];
    }
    
    final String normalizedQuery = query.toLowerCase();
    
    // Compute relevance scores
    final List<Map<String, dynamic>> scoredPrograms = _programs.map((program) {
      double score = _computeRelevanceScore(program, normalizedQuery);
      return {
        'program': program,
        'score': score,
      };
    }).toList();
    
    // Sort by score (descending)
    scoredPrograms.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    
    // Convert to search results (only items with a score > 0)
    return scoredPrograms
        .where((item) => (item['score'] as double) > 0)
        .map((item) {
          final program = item['program'] as Program;
          return SearchResult(
            id: program.title.hashCode.toString(),
            title: program.title,
            description: '${program.description}\n\nKonum: ${program.location} | Süre: ${program.duration} | Fiyat: \$${program.price} | Dil: ${program.language}',
            similarity: item['score'] as double,
          );
        })
        .toList();
  }
  
  // Compute relevance score between a program and a query
  double _computeRelevanceScore(Program program, String normalizedQuery) {
    // Simple scoring based on keyword presence in title and description
    double score = 0.0;
    
    // Check title (higher weight)
    if (program.title.toLowerCase().contains(normalizedQuery)) {
      score += 0.6;
    }
    
    // Check description
    if (program.description.toLowerCase().contains(normalizedQuery)) {
      score += 0.4;
    }
    
    // Check location
    if (program.location.toLowerCase().contains(normalizedQuery)) {
      score += 0.3;
    }
    
    // Check language
    if (program.language.toLowerCase().contains(normalizedQuery)) {
      score += 0.2;
    }
    
    // Check individual words in the query for partial matches
    final queryWords = normalizedQuery.split(' ')
        .where((word) => word.length > 2) // Ignore very short words
        .toList();
    
    for (final word in queryWords) {
      if (program.title.toLowerCase().contains(word)) {
        score += 0.3;
      }
      if (program.description.toLowerCase().contains(word)) {
        score += 0.2;
      }
      if (program.location.toLowerCase().contains(word)) {
        score += 0.1;
      }
      if (program.language.toLowerCase().contains(word)) {
        score += 0.1;
      }
    }
    
    // Normalize score to be between 0 and 1
    return score.clamp(0.0, 1.0);
  }
} 