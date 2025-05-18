class SearchResult {
  final String id;
  final String title;
  final String description;
  final double similarity;

  SearchResult({
    required this.id,
    required this.title,
    required this.description,
    required this.similarity,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'similarity': similarity,
    };
  }
} 