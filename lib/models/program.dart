class Program {
  final String title;
  final String description;
  final String location;
  final String duration;
  final double price;
  final String language;

  Program({
    required this.title,
    required this.description,
    required this.location,
    required this.duration,
    required this.price,
    required this.language,
  });

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      title: json['title'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      duration: json['duration'] as String,
      price: (json['price'] as num).toDouble(),
      language: json['language'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'duration': duration,
      'price': price,
      'language': language,
    };
  }

  // Convert a Program to a SearchResult
  Map<String, dynamic> toSearchData() {
    return {
      'id': title.hashCode.toString(),
      'title': title,
      'description': description,
      'metadata': {
        'location': location,
        'duration': duration,
        'price': price,
        'language': language
      }
    };
  }
} 