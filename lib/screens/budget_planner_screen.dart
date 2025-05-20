import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  _BudgetPlannerScreenState createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  // Form controller
  final TextEditingController _requestController = TextEditingController();

  // State variables
  bool _isLoading = false;
  String _errorMessage = '';
  List<TravelRecommendation> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    await dotenv.load(fileName: ".env");
  }

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _generateRecommendations() async {
    final userRequest = _requestController.text.trim();
    if (userRequest.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen isteğinizi detaylı bir şekilde belirtin';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _recommendations = [];
    });

    // Define the backend URL
    // For Android Emulator, use 'http://10.0.2.2:PORT'
    // For iOS Simulator & physical devices on same Wi-Fi, use your machine's local IP: 'http://YOUR_MACHINE_IP:PORT'
    // Ensure your Node.js server is running and accessible.
    const String backendUrl =
        'http://10.0.2.2:3000/api/recommendations'; // Adjust if your port is different

    try {
      print(
        "Dart: Calling Node.js backend: $backendUrl with prompt: $userRequest",
      );

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'userPrompt': userRequest}),
      );

      print(
        "Dart: Received response from backend. Status: ${response.statusCode}",
      );
      // print("Dart: Response body: ${response.body}"); // Careful with logging large responses

      if (response.statusCode == 200) {
        final String recommendationsJsonString = response.body;
        List<dynamic> recommendationsList;
        try {
          recommendationsList = jsonDecode(recommendationsJsonString);
        } catch (e) {
          print(
            "Dart: Failed to decode JSON from Node.js backend: $recommendationsJsonString",
          );
          throw Exception("Invalid recommendation format from backend.");
        }

        List<TravelRecommendation> recommendations =
            recommendationsList
                .map((json) => TravelRecommendation.fromJson(json))
                .toList();

        if (recommendations.isEmpty && recommendationsJsonString == "[]") {
          print('Dart: Backend returned no recommendations (empty list).');
          _errorMessage =
              "İsteğinize uygun bir program bulunamadı. Lütfen farklı kriterler deneyin.";
        } else if (recommendations.isEmpty &&
            recommendationsJsonString != "[]") {
          print(
            'Dart: Backend returned valid JSON but it resulted in zero parsed recommendations.',
          );
          _errorMessage =
              "İlginç, planlayıcı bir şeyler buldu ama listeleyemedi.";
        }

        // Fallback logic might need adjustment or removal if backend is robust
        if (recommendations.isEmpty &&
            userRequest.isNotEmpty &&
            _errorMessage.startsWith("İsteğinize uygun")) {
          print(
            "Dart: No recommendations from backend, attempting fallback...",
          );
          // Option 1: Keep existing fallback that calls _analyzeUserRequest (which calls OpenAI directly)
          // This would mean your Flutter app still needs OpenAI key for this specific fallback.
          // Option 2: Remove this client-side fallback if the backend is expected to always provide something or an error.
          final analysisResult = await _analyzeUserRequest(
            userRequest,
          ); // This still calls OpenAI directly
          if (analysisResult != null) {
            recommendations = _generateFallbackRecommendations(analysisResult);
            if (recommendations.isNotEmpty &&
                _errorMessage.startsWith("İsteğinize uygun")) {
              _errorMessage =
                  "Size özel bir şey bulamadık, ancak bunlar ilginizi çekebilir.";
            }
          } else {
            recommendations = _generateFallbackRecommendations({
              'destination': 'USA',
              'budget': '3000',
              'currency': 'USD',
            });
            if (_errorMessage.startsWith("İsteğinize uygun"))
              _errorMessage =
                  "Size özel bir şey bulamadık, ancak bunlar ilginizi çekebilir.";
          }
        }

        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
          if (recommendations.isNotEmpty &&
              (_errorMessage.startsWith("API Anahtarı") == false &&
                  _errorMessage.startsWith("Critical error") == false)) {
            if (_errorMessage !=
                    "İsteğinize uygun bir program bulunamadı. Lütfen farklı kriterler deneyin." &&
                _errorMessage !=
                    "Size özel bir şey bulamadık, ancak bunlar ilginizi çekebilir." &&
                _errorMessage !=
                    "İlginç, planlayıcı bir şeyler buldu ama listeleyemedi.") {
              _errorMessage = '';
            }
          }
        });
      } else {
        print(
          'Dart: Error from backend: ${response.statusCode} - ${response.body}',
        );
        String errorMsg = 'Öneriler alınırken sunucu taraflı bir sorun oluştu.';
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson['error'] != null) {
            errorMsg += ' Detay: ${errorJson['error']}';
          }
        } catch (_) {
          // Ignore if body is not JSON
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      print(
        'Dart: Error in _generateRecommendations (HTTP/Network): ${e.toString()}',
      );
      // Consider if fallback is appropriate for network errors too
      final basicAnalysis = {
        'destination': 'USA',
        'budget': '3000',
        'currency': 'USD',
      };
      setState(() {
        // _recommendations = _generateFallbackRecommendations(basicAnalysis); // Optionally keep fallback on network error
        if (_errorMessage.isEmpty ||
            (_errorMessage.startsWith("API Anahtarı") == false &&
                _errorMessage.startsWith("Critical error") == false)) {
          _errorMessage =
              'Öneriler alınamadı. İnternet bağlantınızı kontrol edin veya daha sonra tekrar deneyin. (${e.toString().substring(0, (e.toString().length > 50) ? 50 : e.toString().length)}...)';
        }
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _analyzeUserRequest(String request) async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      final url = Uri.parse("https://api.openai.com/v1/chat/completions");
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "gpt-4",
          "messages": [
            {
              "role": "system",
              "content": """
              Sen bir Work & Travel bütçe planlaması yapan asistansın. Kullanıcıdan alınan Türkçe metni analiz ederek şu bilgileri çıkar:
              1. Hedef ülke veya bölge
              2. Kalış süresi (hafta veya ay olarak)
              3. Kullanıcının bütçesi
              4. Özel tercihler veya kriterler (konaklama, yemek, gezi vb.)
              
              Bu bilgileri JSON formatında şu şekilde döndür:
              {
                "destination": "Hedef ülke veya bölge",
                "duration": "Kalış süresi",
                "budget": "Bütçe miktarı (sayı olarak)",
                "currency": "Para birimi",
                "preferences": ["Tercih 1", "Tercih 2", ...]
              }
              
              Eğer bazı bilgiler metinde verilmemişse, "unknown" olarak işaretle.
              """,
            },
            {"role": "user", "content": request},
          ],
          "temperature": 0.3,
          "max_tokens": 500,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        try {
          return jsonDecode(content);
        } catch (e) {
          print('Error parsing JSON from content: $e');
          print('Content: $content');
          return null;
        }
      } else {
        print('OpenAI API Error: ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error analyzing user request: $e');
      return null;
    }
  }

  List<TravelRecommendation> _generateFallbackRecommendations(
    Map<String, dynamic> analysis,
  ) {
    String destination = analysis['destination'] ?? 'USA';
    String budget = analysis['budget']?.toString() ?? '3000';
    String currency = analysis['currency'] ?? 'USD';
    return [
      TravelRecommendation(
        title: 'California Summer Work Program (Fallback)',
        location: 'San Diego, California, USA',
        duration: '3 months',
        cost: '$budget $currency',
        description:
            'Experience the California lifestyle while working at beach resorts in San Diego. Includes accommodation near the beach, orientation program, and support throughout your stay.',
        features: ['Beach nearby', 'English practice', 'Resort work'],
        imageUrl: TravelRecommendation.USA_IMAGE,
      ),
      TravelRecommendation(
        title: 'Canadian Adventure Program (Fallback)',
        location: 'Vancouver, British Columbia, Canada',
        duration: '4 months',
        cost: '${(int.tryParse(budget) ?? 3000) * 1.2} $currency',
        description:
            'Work in the beautiful city of Vancouver while experiencing Canadian culture. Package includes job placement in hospitality, shared accommodation, and trips to natural parks.',
        features: ['Urban experience', 'Nature trips', 'Hospitality jobs'],
        imageUrl: TravelRecommendation.CANADA_IMAGE,
      ),
      TravelRecommendation(
        title: 'Australian Beach Experience (Fallback)',
        location: 'Gold Coast, Queensland, Australia',
        duration: '6 months',
        cost: '${(int.tryParse(budget) ?? 3000) * 1.5} $currency',
        description:
            'Live and work on Australia\'s famous Gold Coast. Job opportunities in tourism, retail, and hospitality. Program includes visa assistance and accommodation for the first month.',
        features: ['Surf lifestyle', 'Wildlife', 'Tourism jobs'],
        imageUrl: TravelRecommendation.AUSTRALIA_IMAGE,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF246EE9).withOpacity(0.05), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Introduction
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb, color: Colors.amber),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Yapay Zeka Destekli Bütçe Planlayıcı',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Doğal bir dille nerede ne kadar süre Work & Travel yapmak istediğinizi ve bütçenizi belirtin. Yapay zeka sizin için en uygun programları önerecek.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Input form
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İsteğinizi Belirtin',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _requestController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'Örnek: "Amerika\'da 3 ay çalışmak istiyorum ve 3000 dolar bütçem var. Konaklama dahil olsun ve plaja yakın olsun istiyorum.',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Color(0xFF246EE9),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color:
                                      _errorMessage.startsWith("API") ||
                                              _errorMessage.startsWith(
                                                "Critical",
                                              )
                                          ? Colors.red
                                          : Colors.orangeAccent.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isLoading ? null : _generateRecommendations,
                              icon:
                                  _isLoading
                                      ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : Icon(Icons.travel_explore_sharp),
                              label: Text(
                                _isLoading ? 'İşleniyor...' : 'Programları Bul',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF246EE9),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                textStyle: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Results
                  _isLoading
                      ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF246EE9)),
                            SizedBox(height: 16),
                            Text(
                              'Yapay zeka size özel programları arıyor...',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      )
                      : _recommendations.isEmpty &&
                          _errorMessage.isEmpty &&
                          !_isLoading // Added !_isLoading to prevent flash of this text
                      ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded, // Changed icon
                              size: 80,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'İsteğinizi belirtin ve programları arayın',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Column(
                        children:
                            _recommendations.map((recommendation) {
                              return _buildRecommendationCard(recommendation);
                            }).toList(),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(TravelRecommendation recommendation) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              recommendation.imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return Container(
                  height: 160,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF246EE9)),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Resim yükleme hatası: $error');
                return Container(
                  height: 160,
                  color: Colors.grey.shade300,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Görsel yüklenemedi',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recommendation.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          Text(
                            recommendation.location,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        recommendation.cost,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Süre: ${recommendation.duration}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  recommendation.description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 16),

                // Features
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.start,
                  children:
                      recommendation.features.map((feature) {
                        return Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                          labelPadding: EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 0.0,
                          ),
                          label: Text(
                            feature,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.blue.shade800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          backgroundColor: Colors.blue.shade50,
                        );
                      }).toList(),
                ),

                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Show details or contact information
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Bu özellik yakında aktif olacak'),
                      ),
                    );
                  },
                  icon: Icon(Icons.info_outline, color: Colors.white),
                  label: Text(
                    'Detayları Gör',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF246EE9),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    minimumSize: Size(double.infinity, 0),
                    textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TravelRecommendation {
  final String title;
  final String location;
  final String duration;
  final String cost;
  final String description;
  final List<String> features;
  final String imageUrl;

  static const String USA_IMAGE =
      'https://images.unsplash.com/photo-1501594907352-04cda38ebc29';
  static const String CANADA_IMAGE =
      'https://images.unsplash.com/photo-1503614472-8c93d56e92ce';
  static const String AUSTRALIA_IMAGE =
      'https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9';
  static const String EUROPE_IMAGE =
      'https://images.unsplash.com/photo-1490642914619-7955a3fd483c';
  static const String ASIA_IMAGE =
      'https://images.unsplash.com/photo-1493780474015-ba834fd0ce2f';
  static const String DEFAULT_IMAGE =
      'https://images.unsplash.com/photo-1507608616759-54f48f0af0ee';

  TravelRecommendation({
    required this.title,
    required this.location,
    required this.duration,
    required this.cost,
    required this.description,
    required this.features,
    required this.imageUrl,
  });

  factory TravelRecommendation.fromJson(Map<String, dynamic> json) {
    String cost = json['cost'] ?? 'Belirtilmemiş';
    if (cost.length > 20) {
      cost = '${cost.substring(0, 18)}...';
    }

    String location = (json['location'] ?? '').toLowerCase();
    String imageUrl =
        json['image_url'] ?? DEFAULT_IMAGE; // Use image_url from JSON first

    // Fallback image logic if image_url from JSON is one of the placeholders or missing
    // This ensures if the LLM provides a direct valid URL, it's used.
    // If it provides a placeholder, or no URL, then we map it.
    bool isPlaceholderUrl =
        imageUrl == 'USA_IMAGE_URL' ||
        imageUrl == 'CANADA_IMAGE_URL' ||
        imageUrl == 'AUSTRALIA_IMAGE_URL' ||
        imageUrl == 'EUROPE_IMAGE_URL' ||
        imageUrl == 'ASIA_IMAGE_URL' ||
        imageUrl == 'DEFAULT_IMAGE_URL' ||
        !imageUrl.startsWith('https');

    if (isPlaceholderUrl) {
      if (location.contains('abd') ||
          location.contains('amerika') ||
          location.contains('usa') ||
          location.contains('states')) {
        imageUrl = USA_IMAGE;
      } else if (location.contains('kanada') || location.contains('canada')) {
        imageUrl = CANADA_IMAGE;
      } else if (location.contains('avustralya') ||
          location.contains('australia')) {
        imageUrl = AUSTRALIA_IMAGE;
      } else if (location.contains('avrupa') || location.contains('europe')) {
        imageUrl = EUROPE_IMAGE;
      } else if (location.contains('asya') || location.contains('asia')) {
        imageUrl = ASIA_IMAGE;
      } else {
        imageUrl = DEFAULT_IMAGE;
      }
    }

    return TravelRecommendation(
      title: json['title'] ?? 'Program Başlığı',
      location: json['location'] ?? 'Belirtilmemiş Konum',
      duration: json['duration'] ?? 'Belirtilmemiş Süre',
      cost: cost,
      description:
          json['description'] ??
          'Program hakkında detaylı bilgi bulunmamaktadır.',
      features: List<String>.from(json['features'] ?? []),
      imageUrl: imageUrl,
    );
  }
}
